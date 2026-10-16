import 'dart:async';
import 'dart:typed_data';

import 'ocr_text.dart';
import 'page_detect.dart';
import 'pdfrx_document.dart';
import 'recovery_backend.dart';
import 'recovery_backend_stub.dart'
    if (dart.library.js_interop) 'recovery_backend_web.dart';
import 'recovery_models.dart';

export 'recovery_models.dart';

/// Reads the pages of a PDF whose text layer is empty, on this device only:
/// first the values of form fields (exact), then OCR of the rendered page.
/// Nothing is sent anywhere, and the engines are downloaded only when
/// [recover] actually needs them.
///
/// ```dart
/// final recovery = PdfRecovery();
/// final plan = await recovery.analyze(bytes);
/// if (plan.needed /* ask the user */) {
///   await for (final p in recovery.recover(bytes, plan, cancel: cancel)) {
///     // p.phase, p.handled / p.total; p.outcome on the last event
///   }
/// }
/// ```
class PdfRecovery {
  PdfRecovery({
    RecoveryBackend? backend,
    RecoveryDocumentOpener? opener,
    this.maxPages = kRecoveryMaxPages,
    this.minChars = kRecoveryMinVisibleChars,
    this.maxConsecutiveFailures = 3,
  }) : _backend = backend ?? createRecoveryBackend(),
       _opener = opener ?? _defaultOpener;

  final RecoveryBackend _backend;
  final RecoveryDocumentOpener _opener;

  /// At most this many candidate pages are read per document.
  final int maxPages;

  /// Pages with fewer visible characters are candidates.
  final int minChars;

  /// Recognition that fails this many pages in a row stops the run; a broken
  /// engine would otherwise burn the per-page time limit on every page.
  final int maxConsecutiveFailures;

  /// False where recovery cannot run at all (not a web build). [analyze] still
  /// works; [recover] ends at once with every page failed as unsupported.
  bool get isSupported => _backend.isSupported;

  static Future<RecoveryDocument> _defaultOpener(
    Uint8List bytes,
    String name,
  ) async {
    return openWithPdfrx(bytes, name);
  }

  /// Which pages have no readable text layer. Reads only the text layer; does
  /// not load any recovery engine. Throws what the PDF engine throws when the
  /// file cannot be opened.
  Future<RecoveryPlan> analyze(
    Uint8List bytes, {
    String name = 'document.pdf',
  }) async {
    final doc = await _opener(bytes, name);
    try {
      return planRecovery(
        [
          for (var p = 1; p <= doc.pageCount; p++)
            visibleCharCount(await doc.pageText(p)),
        ],
        minChars: minChars,
        maxPages: maxPages,
      );
    } finally {
      await doc.dispose();
    }
  }

  /// [analyze] from page texts already extracted (no second pass over the PDF).
  RecoveryPlan planFromTexts(Iterable<String> pageTexts) => planRecovery(
    [for (final t in pageTexts) visibleCharCount(t)],
    minChars: minChars,
    maxPages: maxPages,
  );

  /// Recovers the pages of [plan].candidates. Single-subscription stream; the
  /// last event is [RecoveryPhase.done] with the outcome. Cancelling [cancel]
  /// (or the subscription) stops it and keeps finished pages. The run never
  /// throws: problems become [RecoveryOutcome.failed] entries.
  Stream<RecoveryProgress> recover(
    Uint8List bytes,
    RecoveryPlan plan, {
    String name = 'document.pdf',
    RecoveryCancel? cancel,
  }) {
    final cancelToken = cancel ?? RecoveryCancel();
    late final StreamController<RecoveryProgress> out;
    out = StreamController<RecoveryProgress>(
      onListen: () => unawaited(
        _run(bytes, plan, name, cancelToken, out).whenComplete(out.close),
      ),
      onCancel: cancelToken.cancel,
    );
    return out.stream;
  }

  /// Frees the engines' workers and memory. Safe to call at any time.
  void dispose() => _backend.dispose();

  Future<void> _run(
    Uint8List bytes,
    RecoveryPlan plan,
    String name,
    RecoveryCancel cancel,
    StreamController<RecoveryProgress> out,
  ) async {
    final pages = <int, RecoveredPage>{};
    final failed = <int, RecoveryFailure>{};
    final total = plan.candidates.length;
    final unsubscribe = cancel.onCancel(_backend.abort);

    void emit(
      RecoveryPhase phase, {
      double? prepare,
      int? page,
      RecoveredPage? recovered,
      RecoveryPageIssue? issue,
    }) {
      if (out.isClosed) return;
      out.add(
        RecoveryProgress(
          phase: phase,
          total: total,
          handled: pages.length + failed.length,
          prepare: prepare,
          page: page,
          recovered: recovered,
          issue: issue,
        ),
      );
    }

    void fail(int page, RecoveryFailure why) {
      failed[page] = why;
      emit(
        RecoveryPhase.ocr,
        page: page,
        issue: RecoveryPageIssue(page, why),
      );
    }

    RecoveryDocument? doc;
    try {
      if (!_backend.isSupported) {
        for (final p in plan.candidates) {
          failed[p] = RecoveryFailure.unsupported;
        }
        return;
      }
      if (plan.candidates.isEmpty) return;

      // Stage 1: form field values.
      var remaining = [...plan.candidates];
      emit(RecoveryPhase.forms);
      try {
        if (!mayHaveForms(bytes)) throw const _NoForms();
        await _backend.prepareForms();
        if (cancel.isCancelled) return;
        final values = await _backend.readForms(bytes, remaining);
        if (cancel.isCancelled) return;
        final original = <int, String>{};
        if (values.isNotEmpty) {
          doc = await _opener(bytes, name);
          for (final p in values.keys) {
            if (p >= 1 && p <= doc.pageCount) {
              original[p] = await doc.pageText(p);
            }
          }
          await doc.dispose();
          doc = null;
        }
        for (final entry in values.entries) {
          final own = visibleCharCount(entry.value.join());
          final r = own < kRecoveryMinResultChars
              ? null
              : recoveredOrNull(
                  page: entry.key,
                  text: formPageText(original[entry.key] ?? '', entry.value),
                  source: PageSource.form,
                );
          if (r == null || !remaining.contains(entry.key)) continue;
          pages[entry.key] = r;
          remaining.remove(entry.key);
          emit(RecoveryPhase.forms, page: entry.key, recovered: r);
        }
      } catch (_) {
        // No forms, or the form reader failed (it is optional): OCR is next.
        doc?.dispose();
        doc = null;
      }
      if (cancel.isCancelled || remaining.isEmpty) return;

      // Stage 2: OCR, one page at a time.
      emit(RecoveryPhase.preparing, prepare: 0);
      try {
        await _backend.prepareOcr(
          (f) => emit(RecoveryPhase.preparing, prepare: f),
        );
      } catch (_) {
        if (!cancel.isCancelled) {
          for (final p in remaining) {
            failed[p] = RecoveryFailure.engineLoad;
          }
        }
        return;
      }
      if (cancel.isCancelled) return;
      doc = await _opener(bytes, name);

      var streak = 0;
      for (var i = 0; i < remaining.length; i++) {
        final page = remaining[i];
        if (cancel.isCancelled) return;
        emit(RecoveryPhase.ocr, page: page);
        RecoveryFailure? why;
        RecoveredPage? got;
        try {
          if (page > doc.pageCount) {
            why = RecoveryFailure.render;
          } else {
            final img = await doc.render(page);
            if (cancel.isCancelled) return;
            if (img == null) {
              why = RecoveryFailure.render;
            } else {
              await _backend.prepareOcr((_) {}); // restarts after a failure
              final data = await _backend.ocrPage(
                img.bgra,
                img.width,
                img.height,
                img.dpi,
              );
              got = recoveredOrNull(
                page: page,
                text: ocrPageText(data),
                source: PageSource.ocr,
                confidence: ocrConfidence(data),
              );
              if (got == null) why = RecoveryFailure.empty;
            }
          }
        } catch (e) {
          if (cancel.isCancelled) return;
          why = '$e'.contains('timeout')
              ? RecoveryFailure.timeout
              : RecoveryFailure.ocr;
        }
        if (got != null) {
          pages[page] = got;
          streak = 0;
          emit(RecoveryPhase.ocr, page: page, recovered: got);
          continue;
        }
        fail(page, why!);
        // A blank page is a result, not an engine problem.
        streak = why == RecoveryFailure.empty ? 0 : streak + 1;
        if (streak >= maxConsecutiveFailures) {
          for (final p in remaining.skip(i + 1)) {
            failed[p] = why;
          }
          return;
        }
      }
    } catch (_) {
      // Anything unexpected ends the run with what is already recovered.
    } finally {
      unsubscribe();
      await doc?.dispose();
      final list = pages.values.toList()
        ..sort((a, b) => a.page.compareTo(b.page));
      if (!out.isClosed) {
        out.add(
          RecoveryProgress(
            phase: RecoveryPhase.done,
            total: total,
            handled: pages.length + failed.length,
            outcome: RecoveryOutcome(
              pages: list,
              failed: [
                for (final e in failed.entries)
                  RecoveryPageIssue(e.key, e.value),
              ]..sort((a, b) => a.page.compareTo(b.page)),
              skippedOverLimit: plan.overLimit,
              canceled: cancel.isCancelled,
            ),
          ),
        );
      }
    }
  }
}

/// Not an error: the PDF has no form fields, so the form reader stays unloaded.
class _NoForms implements Exception {
  const _NoForms();
}
