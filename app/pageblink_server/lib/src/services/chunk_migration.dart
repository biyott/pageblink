import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../providers/embedding_provider.dart';
import '../rag/embedding_spec.dart';
import '../rag/index_chunks.dart';
import '../rag_endpoints/document_endpoint.dart' show friendlyIndexingError;
import 'chunk_indexer.dart';
import 'index_config.dart';
import 'rag_services.dart';

/// Runs [body] with a short-lived session (`Serverpod.withSession`).
typedef SessionScope =
    Future<R> Function<R>(Future<R> Function(Session session) body);

/// What happened to one document.
enum MigrationOutcome {
  /// Chunks replaced, tag updated.
  ok,

  /// Edited, deleted, failed or already current while embedding: discarded.
  changed,

  /// PDF without stored page text (indexed before `doc_page`): old chunks stay.
  noSource,

  /// PDF with no text under the new rules: old chunks stay.
  noText,
}

class MigrationReport {
  /// Documents that needed work when the run began.
  int pending = 0;
  int ok = 0;
  int skipped = 0;
  int failed = 0;

  /// Stopped early: repeated failures or an authentication error.
  bool aborted = false;
}

/// Re-indexes documents whose chunks follow older rules or an older embedding
/// model (design 029 §9): `status = 'ready' AND embeddingModel <> tag`.
///
/// Not `_index`/`reindex`: those mark a document `failed` on error, bump
/// `updatedAt` (re-ordering every user's list), set `indexing`, and refuse
/// demo samples. This job embeds first with no lock, then replaces the chunks
/// of one document in one transaction that also re-checks the document is
/// unchanged. `status`, `updatedAt`, `version` and `contentHash` are never
/// written, so there is no progress state: the predicate is the state.
class ChunkMigration {
  static bool _running = false;

  /// Starts the job in the background when `REINDEX_ON_BOOT` is on. Returns
  /// the run (never throws), or null when it does not start: flag off,
  /// `maintenance` role, or already running. Call after `pod.start()`.
  static Future<MigrationReport>? start(Serverpod pod, {SessionScope? scope}) {
    if (pod.config.role.name == 'maintenance') return null;
    if (!IndexConfig.reindexOnBootForPod(pod) || _running) return null;
    _running = true;
    return run(scope ?? pod.withSession).whenComplete(() => _running = false);
  }

  /// One pass over every stale document. Never throws.
  static Future<MigrationReport> run(
    SessionScope scope, {
    Duration pause = const Duration(milliseconds: 1500),
    List<Duration> backoff = const [
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 120),
    ],
    int maxConsecutiveFailures = 5,
    Future<void> Function(Duration) sleep = _sleep,
    void Function(String) log = _log,
  }) async {
    final report = MigrationReport();
    final clock = Stopwatch()..start();
    try {
      final (:embedder, :tag, :version) = await scope((s) async {
        final version = IndexConfig.chunkerVersion(s);
        final embedder = RagServices.embedding(s);
        return (
          embedder: embedder,
          tag: ChunkSpec.tag(embedder.modelId, version),
          version: version,
        );
      });
      report.pending = await scope(
        (s) => Document.db.count(s, where: (t) => _stale(t, tag)),
      );
      log('chunk-migration: start tag=$tag pending=${report.pending}');

      var cursor = 0;
      var consecutive = 0;
      outer:
      while (true) {
        final batch = await scope(
          (s) => Document.db.find(
            s,
            where: (t) => _stale(t, tag) & (t.id > cursor),
            orderBy: (t) => t.id,
            limit: 20,
          ),
        );
        if (batch.isEmpty) break;
        for (final doc in batch) {
          cursor = doc.id!;
          while (true) {
            final took = Stopwatch()..start();
            try {
              final (outcome, before, after) = await scope(
                (s) => reembed(s, doc.id!, embedder, tag, version),
              );
              consecutive = 0;
              switch (outcome) {
                case MigrationOutcome.ok:
                  report.ok++;
                  log(
                    'chunk-migration: doc=${doc.id} kind=${doc.kind} '
                    'chunks $before->$after ok '
                    '${(took.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                  );
                case MigrationOutcome.changed:
                  report.skipped++;
                  log('chunk-migration: doc=${doc.id} skip(changed)');
                case MigrationOutcome.noSource:
                  report.skipped++;
                  log('chunk-migration: doc=${doc.id} skip(no_source)');
                case MigrationOutcome.noText:
                  report.skipped++;
                  log('chunk-migration: doc=${doc.id} skip(no_text)');
              }
              break;
            } catch (e) {
              final code = friendlyIndexingError(e);
              consecutive++;
              if (code == 'auth' || consecutive >= maxConsecutiveFailures) {
                report.failed++;
                report.aborted = true;
                log(
                  'chunk-migration: doc=${doc.id} fail($code) '
                  'consecutive=$consecutive, stopping',
                );
                break outer;
              }
              if (const {'rate', 'quota', 'outage', 'timeout'}.contains(code)) {
                final wait =
                    backoff[(consecutive - 1).clamp(0, backoff.length - 1)];
                log(
                  'chunk-migration: doc=${doc.id} fail($code) '
                  'backoff ${wait.inSeconds}s',
                );
                await sleep(wait);
                continue; // same document again
              }
              report.failed++;
              log('chunk-migration: doc=${doc.id} fail($code), next');
              break;
            }
          }
          await sleep(pause);
        }
      }
    } catch (e, st) {
      report.aborted = true;
      stderr.writeln('chunk-migration: stopped: $e\n$st');
    }
    log(
      'chunk-migration: done ok=${report.ok} skipped=${report.skipped} '
      'failed=${report.failed} aborted=${report.aborted} '
      'elapsed=${clock.elapsed.inSeconds}s',
    );
    return report;
  }

  static Expression<dynamic> _stale(DocumentTable t, String tag) =>
      t.status.equals('ready') & t.embeddingModel.notEquals(tag);

  /// Re-chunks and re-embeds document [id] and swaps its chunks, or leaves
  /// everything untouched. Returns the outcome with the old and new chunk
  /// counts. Throws the embedder's exception on failure.
  static Future<(MigrationOutcome, int, int)> reembed(
    Session session,
    int id,
    EmbeddingProvider embedder,
    String tag,
    int version,
  ) async {
    final doc = await Document.db.findById(session, id);
    if (doc == null || doc.status != 'ready' || doc.embeddingModel == tag) {
      return (MigrationOutcome.changed, 0, 0);
    }
    List<({int page, String text})> pages;
    if (doc.kind == 'note') {
      // The body, not DocPage: ask recomputes chunks from the body.
      pages = [(page: 1, text: doc.body ?? '')];
    } else {
      final rows = await DocPage.db.find(
        session,
        where: (t) => t.documentId.equals(id),
        orderBy: (t) => t.page,
      );
      if (rows.isEmpty) return (MigrationOutcome.noSource, 0, 0);
      pages = [for (final r in rows) (page: r.page, text: r.text)];
    }
    final chunks = buildIndexChunks(
      kind: doc.kind,
      title: doc.title,
      pages: pages,
      version: version,
    );
    if (doc.kind != 'note' && chunks.isEmpty) {
      return (MigrationOutcome.noText, 0, 0);
    }
    final before = await DocChunk.db.count(
      session,
      where: (t) => t.documentId.equals(id),
    );
    // No lock is held while the embedding provider is slow.
    final vectors = await ChunkIndexer.vectorsFor(embedder, chunks, tag);

    final outcome = await session.db.transaction((tx) async {
      // Locks the row and re-checks it in one statement.
      final locked = await Document.db.updateWhere(
        session,
        columnValues: (t) => [t.embeddingModel(tag)],
        where: (t) =>
            t.id.equals(id) &
            t.status.equals('ready') &
            t.version.equals(doc.version) &
            t.contentHash.equals(doc.contentHash) &
            t.title.equals(doc.title) &
            t.embeddingModel.notEquals(tag),
        transaction: tx,
      );
      if (locked.isEmpty) return MigrationOutcome.changed;
      await ChunkIndexer.replace(session, tx, doc, chunks, tag, vectors);
      return MigrationOutcome.ok;
    });
    return (
      outcome,
      before,
      outcome == MigrationOutcome.ok ? chunks.length : before,
    );
  }

  static Future<void> _sleep(Duration d) => Future<void>.delayed(d);
  static void _log(String line) => stdout.writeln(line);
}
