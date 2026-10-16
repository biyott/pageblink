import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag_endpoints/document_endpoint.dart';
import '../sample/sample_pack.dart';
import '../services/document_cleanup.dart';
import 'demo_config.dart';
import 'demo_guard.dart';
import 'demo_user.dart';

/// Provisions the demo accounts at boot and seeds their sample documents
/// through the normal `DocumentEndpoint` (indexing and retry logic reused, not
/// copied). Accounts are seeded one after the other, so more languages do not
/// make the embedding calls run in parallel.
class DemoSeed {
  static bool _running = false;

  /// Tests only: `startBackground` does nothing (it would write outside the
  /// test's rolled-back transaction).
  static bool debugDisabled = false;
  static DateTime? _lastStart;

  /// Call after `pod.start()` (migrations run inside `start()`; research 026
  /// D1). Never throws: a failed demo must not take the server down.
  static Future<void> boot(Serverpod pod) async {
    // Only `maintenance` does not serve requests; monolith and serverless do.
    if (pod.config.role.name == 'maintenance') return;
    if (!DemoConfig.enabledForPod(pod)) {
      // Off: create, seed and purge nothing. Only look the users up, so a demo
      // session that is still alive (14-day refresh token) stays under the
      // guards instead of becoming an unlimited account.
      try {
        await pod.withSession(DemoUser.load);
      } catch (e) {
        stderr.writeln('demo user lookup failed (demo disabled): $e');
      }
      return;
    }
    try {
      await pod.withSession((s) async {
        await DemoUser.ensureAll(s);
        await DemoGuard.purgeExpired(s);
      });
      stdout.writeln('demo enabled: users ready, seeding in background');
      startBackground(pod);
    } catch (e, st) {
      stderr.writeln('demo boot failed: $e\n$st');
    }
  }

  /// Seeds in the background (indexing embeds, so it is slow). Single flight
  /// and at most once per [minGap] unless [force], so `signIn` can call it
  /// as a self-heal without hammering a broken embedding service.
  static void startBackground(
    Serverpod pod, {
    bool force = true,
    Duration minGap = const Duration(minutes: 10),
  }) {
    final targets = Map.of(DemoUser.accounts);
    if (debugDisabled || targets.isEmpty || _running) return;
    final now = DateTime.now();
    final last = _lastStart;
    if (!force && last != null && now.difference(last) < minGap) return;
    _running = true;
    _lastStart = now;
    // The session is opened INSIDE the closure so it outlives this call, and
    // every error is caught here: an unhandled async error would end the
    // process (research 026 R-B).
    unawaited(
      pod
          .withSession((s) async {
            try {
              for (final MapEntry(key: demoId, value: pack)
                  in targets.entries) {
                // One account failing must not keep the others unseeded.
                try {
                  s.updateAuthenticated(
                    AuthenticationInfo(
                      demoId.toString(),
                      const {},
                      authId: demoSeedAuthId,
                    ),
                  );
                  await run(s, demoId, pack);
                } catch (e, st) {
                  s.log(
                    'demo seed failed (${pack.id})',
                    level: LogLevel.error,
                    exception: e,
                    stackTrace: st,
                  );
                }
              }
            } finally {
              _running = false;
            }
          })
          .catchError((Object e) {
            _running = false;
            stderr.writeln('demo seed session failed: $e');
          }),
    );
  }

  /// Creates what is missing in one demo account and re-indexes failed or
  /// stuck samples. First removes samples of earlier releases
  /// ([SamplePacks.demoLegacy]) with their chunks, pages and PDF file; once
  /// they are gone this is a no-op. [session] must be authenticated as
  /// [demoId] with the seed id; [pack] is that account's pack.
  static Future<void> run(
    Session session,
    UuidValue demoId,
    SamplePack pack,
  ) async {
    final endpoint = DocumentEndpoint();

    final old = await Document.db.find(
      session,
      where: (t) =>
          t.ownerId.equals(demoId) &
          t.contentHash.inSet(SamplePacks.demoLegacy),
    );
    if (old.isNotEmpty) {
      await DocumentCleanup.deleteFiles(session, old.map((d) => d.storagePath));
      await session.db.transaction(
        (tx) => DocumentCleanup.deleteRows(session, {
          for (final d in old) d.id!,
        }, transaction: tx),
      );
    }

    Future<Document?> existing(String hash) => Document.db.findFirstRow(
      session,
      where: (t) =>
          t.ownerId.equals(demoId) &
          t.projectId.equals(null) &
          t.contentHash.equals(hash),
    );

    Future<Document> ensureDoc(
      String hash,
      Future<Document> Function() create,
    ) async {
      final doc = await existing(hash);
      if (doc == null) return create();
      final retry =
          doc.status == 'failed' ||
          isStaleIndexing(doc.status, doc.updatedAt, DateTime.now().toUtc());
      return retry ? endpoint.reindex(session, doc.id!) : doc;
    }

    final samplePdf = pack.pdf!;
    for (final note in pack.notes) {
      await ensureDoc(
        note.hash,
        () => endpoint.saveNote(session, null, note.title, note.body, null),
      );
    }

    final pdf = await ensureDoc(
      samplePdf.hash,
      () => endpoint.upload(
        session,
        samplePdf.title,
        [
          for (var i = 0; i < samplePdf.pages.length; i++)
            PageText(page: i + 1, text: samplePdf.pages[i]),
        ],
        samplePdf.hash,
        null,
      ),
    );
    if (pdf.storagePath == null) await _storeOriginal(session, pdf, samplePdf);
  }

  /// Stores the original PDF like `confirmPdfUpload` would (`pdfs/<id>.pdf`).
  /// Without it the PDF is text-only: citations work, the viewer cannot open.
  static Future<void> _storeOriginal(
    Session session,
    Document pdf,
    SamplePdf sample,
  ) async {
    final file = File(sample.assetPath);
    if (!file.existsSync()) {
      session.log(
        'demo sample PDF missing at ${sample.assetPath} (text-only)',
        level: LogLevel.warning,
      );
      return;
    }
    final bytes = await file.readAsBytes();
    final path = 'pdfs/${pdf.id}.pdf';
    await session.storage.storeFile(
      storageId: DocumentCleanup.storageId,
      path: path,
      byteData: ByteData.sublistView(bytes),
    );
    await Document.db.updateRow(session, pdf.copyWith(storagePath: path));
  }
}
