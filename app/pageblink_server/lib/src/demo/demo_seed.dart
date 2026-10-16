import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag_endpoints/document_endpoint.dart';
import '../services/document_cleanup.dart';
import 'demo_config.dart';
import 'demo_guard.dart';
import 'demo_samples.dart';
import 'demo_user.dart';

/// Provisions the demo account at boot and seeds its sample documents through
/// the normal `DocumentEndpoint` (indexing and retry logic reused, not copied).
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
      // Off: create, seed and purge nothing. Only look the user up, so a demo
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
        await DemoUser.ensure(s);
        await DemoGuard.purgeExpired(s);
      });
      stdout.writeln('demo enabled: user ready, seeding in background');
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
    final demoId = DemoUser.demoUserId;
    if (debugDisabled || demoId == null || _running) return;
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
              s.updateAuthenticated(
                AuthenticationInfo(
                  demoId.toString(),
                  const {},
                  authId: demoSeedAuthId,
                ),
              );
              await run(s, demoId);
            } catch (e, st) {
              s.log(
                'demo seed failed',
                level: LogLevel.error,
                exception: e,
                stackTrace: st,
              );
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

  /// Creates what is missing and re-indexes failed or stuck samples.
  /// [session] must be authenticated as the demo user (seed id).
  static Future<void> run(Session session, UuidValue demoId) async {
    final endpoint = DocumentEndpoint();

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

    for (final note in DemoSamples.notes) {
      await ensureDoc(
        note.hash,
        () => endpoint.saveNote(session, null, note.title, note.body, null),
      );
    }

    final pdf = await ensureDoc(
      DemoSamples.pdfHash,
      () => endpoint.upload(
        session,
        DemoSamples.pdfTitle,
        [
          for (var i = 0; i < DemoSamples.pdfPages.length; i++)
            PageText(page: i + 1, text: DemoSamples.pdfPages[i]),
        ],
        DemoSamples.pdfHash,
        null,
      ),
    );
    if (pdf.storagePath == null) await _storeOriginal(session, pdf);
  }

  /// Stores the original PDF like `confirmPdfUpload` would (`pdfs/<id>.pdf`).
  /// Without it the PDF is text-only: citations work, the viewer cannot open.
  static Future<void> _storeOriginal(Session session, Document pdf) async {
    final file = File(DemoSamples.pdfAsset);
    if (!file.existsSync()) {
      session.log(
        'demo sample PDF missing at ${DemoSamples.pdfAsset} (text-only)',
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
