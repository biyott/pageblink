import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag/preview_text.dart';
import 'chunk_migration.dart' show SessionScope;

class PreviewReport {
  /// PDFs without a preview when the run began.
  int pending = 0;

  /// Got a text preview.
  int filled = 0;

  /// Got `''`: no readable page (or no stored page text).
  int empty = 0;

  /// Failed, or another instance / a re-index filled it first.
  int skipped = 0;
}

/// Fills `Document.preview` of PDFs indexed before the column existed:
/// `kind = 'pdf' AND status = 'ready' AND preview IS NULL`. Reads the stored
/// `DocPage` text only (no embedding, no network). Writes only `preview`, and
/// only while it is still null, so `status`, `updatedAt`, `version` and
/// `contentHash` (the demo sample marker) are untouched and several instances
/// can run it at once. The predicate is the state: a finished run leaves
/// nothing pending.
class PreviewBackfill {
  static bool _running = false;

  /// Starts the job in the background. Returns the run (never throws), or
  /// null for the `maintenance` role or when already running. Call after
  /// `pod.start()`.
  static Future<PreviewReport>? start(Serverpod pod, {SessionScope? scope}) {
    if (pod.config.role.name == 'maintenance' || _running) return null;
    _running = true;
    return run(scope ?? pod.withSession).whenComplete(() => _running = false);
  }

  static Expression<dynamic> _todo(DocumentTable t) =>
      t.kind.equals('pdf') & t.status.equals('ready') & t.preview.equals(null);

  /// One pass over every pending PDF, [batch] at a time. Never throws.
  static Future<PreviewReport> run(
    SessionScope scope, {
    int batch = 50,
    void Function(String) log = _log,
  }) async {
    final report = PreviewReport();
    try {
      report.pending = await scope((s) => Document.db.count(s, where: _todo));
      log('preview-backfill: start pending=${report.pending}');
      var cursor = 0;
      while (report.pending > 0) {
        final ids = await scope(
          (s) async => [
            for (final d in await Document.db.find(
              s,
              where: (t) => _todo(t) & (t.id > cursor),
              orderBy: (t) => t.id,
              limit: batch,
            ))
              d.id!,
          ],
        );
        if (ids.isEmpty) break;
        for (final id in ids) {
          cursor = id;
          try {
            final filled = await scope((s) => fill(s, id));
            if (filled == null) {
              report.skipped++;
            } else if (filled.isEmpty) {
              report.empty++;
            } else {
              report.filled++;
            }
          } catch (e) {
            report.skipped++;
            // No content in the log: the id and the error type only.
            log('preview-backfill: doc=$id fail(${e.runtimeType})');
          }
        }
      }
    } catch (e) {
      stderr.writeln('preview-backfill: stopped (${e.runtimeType})');
    }
    log(
      'preview-backfill: done filled=${report.filled} empty=${report.empty} '
      'skipped=${report.skipped}',
    );
    return report;
  }

  /// Writes the preview of [id] if it is still null and returns it, or
  /// returns null when the row is no longer pending (filled elsewhere,
  /// re-indexed, deleted). The conditional update is what makes two
  /// instances safe.
  static Future<String?> fill(Session session, int id) async {
    final rows = await DocPage.db.find(
      session,
      where: (t) => t.documentId.equals(id),
      orderBy: (t) => t.page,
    );
    final preview = pdfPreview([
      for (final r in rows) (page: r.page, text: r.text),
    ]);
    final done = await Document.db.updateWhere(
      session,
      columnValues: (t) => [t.preview(preview)],
      where: (t) => t.id.equals(id) & t.preview.equals(null),
    );
    return done.isEmpty ? null : preview;
  }

  static void _log(String line) => stdout.writeln(line);
}
