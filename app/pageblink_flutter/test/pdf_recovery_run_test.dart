import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/ocr_text.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/pdf_recovery.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/recovery_backend.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/recovery_merge.dart';

/// Looks like a PDF with form fields to the cheap check.
final _bytes = Uint8List.fromList('/AcroForm'.codeUnits);

/// A PDF with no form fields at all.
final _plainBytes = Uint8List.fromList('%PDF-1.4 plain'.codeUnits);

/// A page of text a recognizer "found": one line, one word per character run.
OcrPageData _ocr(String text) => OcrPageData([
  OcrLine(0, [OcrWord(text, 0, 0, 200, 20, 88)], 88),
]);

class _FakeDoc implements RecoveryDocument {
  _FakeDoc(this.texts, {this.badRender = const {}});

  final List<String> texts;
  final Set<int> badRender;
  int rendered = 0;
  bool disposed = false;

  @override
  int get pageCount => texts.length;

  @override
  Future<String> pageText(int page) async => texts[page - 1];

  @override
  Future<RenderedPage?> render(int page) async {
    rendered++;
    if (badRender.contains(page)) return null;
    // The fake recognizer reads the page number back from the first pixel.
    return RenderedPage(Uint8List.fromList([page, 0, 0, 255]), 1, 1, 150);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeBackend implements RecoveryBackend {
  _FakeBackend({
    this.supported = true,
    this.forms = const {},
    this.formsError,
    this.ocrError,
    this.ocrText = _defaultOcr,
    this.ocrDelay,
  });

  static String _defaultOcr(int page) => 'recognized text on page $page';

  final bool supported;
  final Map<int, List<String>> forms;
  final Object? formsError;
  final Object? Function(int page)? ocrError;
  final String Function(int page) ocrText;
  final Future<void> Function(int page)? ocrDelay;

  final calls = <String>[];
  final dpis = <int>[];
  int prepareOcrCalls = 0;
  Object? prepareOcrError;
  Completer<void>? hang;

  @override
  bool get isSupported => supported;

  @override
  Future<void> prepareForms() async {
    calls.add('prepareForms');
    if (formsError != null) throw formsError!;
  }

  @override
  Future<Map<int, List<String>>> readForms(
    Uint8List pdf,
    List<int> pages,
  ) async {
    calls.add('readForms($pages)');
    return {
      for (final e in forms.entries)
        if (pages.contains(e.key)) e.key: e.value,
    };
  }

  @override
  Future<void> prepareOcr(void Function(double) onProgress) async {
    prepareOcrCalls++;
    if (prepareOcrCalls == 1) calls.add('prepareOcr');
    if (prepareOcrError != null) throw prepareOcrError!;
    onProgress(0.5);
    onProgress(1);
  }

  @override
  Future<OcrPageData> ocrPage(
    Uint8List bgra,
    int width,
    int height,
    int dpi,
  ) async {
    final page = bgra[0];
    calls.add('ocr($page)');
    dpis.add(dpi);
    await ocrDelay?.call(page);
    final h = hang;
    if (h != null) await h.future;
    final err = ocrError?.call(page);
    if (err != null) throw err;
    return _ocr(ocrText(page));
  }

  @override
  void abort() {
    calls.add('abort');
    final h = hang;
    if (h != null && !h.isCompleted) h.completeError(StateError('aborted'));
  }

  @override
  void dispose() => calls.add('dispose');
}

PdfRecovery _recovery(
  _FakeBackend backend,
  _FakeDoc doc, {
  int maxPages = 50,
}) => PdfRecovery(
  backend: backend,
  opener: (_, _) async => doc,
  maxPages: maxPages,
);

Future<(List<RecoveryProgress>, RecoveryOutcome)> _run(
  PdfRecovery r,
  RecoveryPlan plan, {
  RecoveryCancel? cancel,
}) async {
  final events = await r.recover(_bytes, plan, cancel: cancel).toList();
  expect(events.last.phase, RecoveryPhase.done);
  expect(events.where((e) => e.phase == RecoveryPhase.done), hasLength(1));
  return (events, events.last.outcome!);
}

void main() {
  group('analyze', () {
    test(
      'counts visible characters per page and never loads an engine',
      () async {
        final backend = _FakeBackend();
        final doc = _FakeDoc(['  ', 'a' * 40, '${'x' * 29}\n ', '']);
        final plan = await _recovery(backend, doc).analyze(_bytes);
        expect(plan.visibleChars, [0, 40, 29, 0]);
        expect(plan.candidates, [1, 3, 4]);
        expect(doc.disposed, isTrue);
        expect(backend.calls, isEmpty);
      },
    );

    test('the page limit applies', () async {
      final doc = _FakeDoc(List.filled(7, ''));
      final plan = await _recovery(
        _FakeBackend(),
        doc,
        maxPages: 5,
      ).analyze(_bytes);
      expect(plan.candidates, [1, 2, 3, 4, 5]);
      expect(plan.overLimit, [6, 7]);
    });
  });

  group('recover', () {
    test('a text PDF: nothing is prepared, nothing is rendered', () async {
      final backend = _FakeBackend();
      final doc = _FakeDoc(['a' * 100, 'b' * 100]);
      final r = _recovery(backend, doc);
      final plan = await r.analyze(_bytes);
      final (events, outcome) = await _run(r, plan);
      expect(events, hasLength(1));
      expect(outcome.pages, isEmpty);
      expect(outcome.failed, isEmpty);
      expect(backend.calls, isEmpty);
      expect(doc.rendered, 0);
    });

    test('form values come first and spare those pages the OCR', () async {
      final backend = _FakeBackend(
        forms: {
          1: ['서울 여행 계획', '3박 4일'],
        },
      );
      final doc = _FakeDoc(['', '', 'a' * 100]);
      final r = _recovery(backend, doc);
      final (events, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.pages.map((p) => (p.page, p.source)), [
        (1, 'form'),
        (2, 'ocr'),
      ]);
      expect(outcome.pages.first.text, '서울 여행 계획\n3박 4일');
      expect(outcome.pages.first.confidence, isNull);
      expect(outcome.pages.last.confidence, 88);
      expect(backend.dpis, [
        150,
      ], reason: 'the page dpi reaches the recognizer');
      expect(backend.calls, [
        'prepareForms',
        'readForms([1, 2])',
        'prepareOcr',
        'ocr(2)',
      ]);
      // phases advance: forms, preparing, ocr, done
      final phases = [for (final e in events) e.phase];
      expect(phases.first, RecoveryPhase.forms);
      expect(
        phases.indexOf(RecoveryPhase.preparing),
        greaterThan(phases.indexOf(RecoveryPhase.forms)),
      );
      expect(phases.last, RecoveryPhase.done);
      expect(events.last.handled, 2);
      expect(events.last.total, 2);
    });

    test(
      'every page read from a form: the OCR engine is never loaded',
      () async {
        final backend = _FakeBackend(
          forms: {
            1: ['abcdefghijkl'],
          },
        );
        final r = _recovery(backend, _FakeDoc(['']));
        final (_, outcome) = await _run(r, await r.analyze(_bytes));
        expect(outcome.pages.single.source, 'form');
        expect(backend.calls.where((c) => c.contains('prepareOcr')), isEmpty);
      },
    );

    test('a form value shorter than 10 characters is not enough', () async {
      final backend = _FakeBackend(
        forms: {
          1: ['yes'],
        },
      );
      final r = _recovery(backend, _FakeDoc(['']));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.pages.single.source, 'ocr');
    });

    test('a form page keeps the few characters its own text had', () async {
      final backend = _FakeBackend(
        forms: {
          1: ['a long enough value'],
        },
      );
      final r = _recovery(backend, _FakeDoc(['Page 1']));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.pages.single.text, 'Page 1\na long enough value');
    });

    test('a PDF without form fields never loads the form reader', () async {
      final backend = _FakeBackend(
        forms: {
          1: ['would be found'],
        },
      );
      final r = _recovery(backend, _FakeDoc(['']));
      final plan = await r.analyze(_plainBytes);
      final events = await r.recover(_plainBytes, plan).toList();
      expect(events.last.outcome!.pages.single.source, 'ocr');
      expect(backend.calls, isNot(contains('prepareForms')));
    });

    test('a broken form reader does not stop OCR', () async {
      final backend = _FakeBackend(formsError: StateError('no pdf.js'));
      final r = _recovery(backend, _FakeDoc(['']));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.pages.single.source, 'ocr');
    });

    test('one page failing leaves the others (partial success)', () async {
      final backend = _FakeBackend(
        ocrError: (p) => p == 2 ? StateError('boom') : null,
      );
      final doc = _FakeDoc(['', '', ''], badRender: {3});
      final r = _recovery(backend, doc);
      final (events, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.pages.map((p) => p.page), [1]);
      expect(
        outcome.failed.map((i) => (i.page, i.reason)),
        [(2, RecoveryFailure.ocr), (3, RecoveryFailure.render)],
      );
      expect(events.last.handled, 3);
      // each page produced its own event
      expect(events.where((e) => e.issue != null), hasLength(2));
      expect(events.where((e) => e.recovered != null), hasLength(1));
    });

    test('a timeout is told apart and the next page still runs', () async {
      final backend = _FakeBackend(
        ocrError: (p) => p == 1 ? StateError('timeout') : null,
      );
      final r = _recovery(backend, _FakeDoc(['', '']));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.failed.single.reason, RecoveryFailure.timeout);
      expect(outcome.pages.single.page, 2);
      expect(backend.prepareOcrCalls, greaterThan(1), reason: 'restarted');
    });

    test(
      'a blank result is a failure of kind empty, not an engine fault',
      () async {
        final backend = _FakeBackend(ocrText: (p) => '.');
        final doc = _FakeDoc(List.filled(6, ''));
        final r = _recovery(backend, doc);
        final (_, outcome) = await _run(r, await r.analyze(_bytes));
        expect(outcome.failed, hasLength(6));
        expect(
          outcome.failed.every((i) => i.reason == RecoveryFailure.empty),
          isTrue,
        );
        expect(backend.calls.where((c) => c.startsWith('ocr')), hasLength(6));
      },
    );

    test('three engine failures in a row stop the run', () async {
      final backend = _FakeBackend(ocrError: (_) => StateError('crash'));
      final r = _recovery(backend, _FakeDoc(List.filled(8, '')));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(backend.calls.where((c) => c.startsWith('ocr')), hasLength(3));
      expect(outcome.failed, hasLength(8));
      expect(outcome.pages, isEmpty);
    });

    test(
      'an engine that cannot load fails every OCR page, keeps forms',
      () async {
        final backend = _FakeBackend(
          forms: {
            1: ['values of the form'],
          },
        )..prepareOcrError = StateError('offline');
        final r = _recovery(backend, _FakeDoc(['', '', '']));
        final (_, outcome) = await _run(r, await r.analyze(_bytes));
        expect(outcome.pages.single.page, 1);
        expect(outcome.failed.map((i) => (i.page, i.reason)), [
          (2, RecoveryFailure.engineLoad),
          (3, RecoveryFailure.engineLoad),
        ]);
      },
    );

    test('pages over the limit are reported, not read', () async {
      final backend = _FakeBackend();
      final doc = _FakeDoc(List.filled(5, ''));
      final r = _recovery(backend, doc, maxPages: 3);
      final plan = await r.analyze(_bytes);
      final (events, outcome) = await _run(r, plan);
      expect(outcome.skippedOverLimit, [4, 5]);
      expect(outcome.pages.map((p) => p.page), [1, 2, 3]);
      expect(events.last.total, 3);
    });

    test('an unsupported platform fails everything at once', () async {
      final backend = _FakeBackend(supported: false);
      final r = _recovery(backend, _FakeDoc(['', '']));
      final (_, outcome) = await _run(r, await r.analyze(_bytes));
      expect(outcome.failed.map((i) => i.reason), [
        RecoveryFailure.unsupported,
        RecoveryFailure.unsupported,
      ]);
      expect(backend.calls, isEmpty);
    });

    test('progress counts pages as they finish', () async {
      final backend = _FakeBackend();
      final r = _recovery(backend, _FakeDoc(['', '', '']));
      final (events, _) = await _run(r, await r.analyze(_bytes));
      final recovered = events.where((e) => e.recovered != null).toList();
      expect([for (final e in recovered) e.handled], [1, 2, 3]);
      expect([for (final e in recovered) e.page], [1, 2, 3]);
      final prepare = [
        for (final e in events)
          if (e.phase == RecoveryPhase.preparing) e.prepare,
      ];
      expect(prepare, containsAllInOrder([0, 0.5, 1]));
    });
  });

  group('cancel', () {
    test(
      'before the start: nothing is loaded and the outcome says canceled',
      () async {
        final backend = _FakeBackend();
        final cancel = RecoveryCancel()..cancel();
        final r = _recovery(backend, _FakeDoc(['', '']));
        final (_, outcome) = await _run(
          r,
          await r.analyze(_bytes),
          cancel: cancel,
        );
        expect(outcome.canceled, isTrue);
        expect(outcome.pages, isEmpty);
        expect(backend.calls.where((c) => c.startsWith('ocr')), isEmpty);
      },
    );

    test('between pages: finished pages are kept, the rest not read', () async {
      // The fake recognizer finishes page 2 although cancel arrived during it
      // (a real engine is aborted and fails the page): a finished page is kept.
      final cancel = RecoveryCancel();
      final backend = _FakeBackend(
        ocrDelay: (p) async {
          if (p == 2) cancel.cancel();
        },
      );
      final r = _recovery(backend, _FakeDoc(['', '', '', '']));
      final (_, outcome) = await _run(
        r,
        await r.analyze(_bytes),
        cancel: cancel,
      );
      expect(outcome.canceled, isTrue);
      expect(outcome.pages.map((p) => p.page), [1, 2]);
      expect(backend.calls.where((c) => c.startsWith('ocr')), [
        'ocr(1)',
        'ocr(2)',
      ]);
      expect(backend.calls, contains('abort'));
    });

    test('in the middle of a page: the engine is aborted at once', () async {
      final cancel = RecoveryCancel();
      final backend = _FakeBackend()..hang = Completer<void>();
      final r = _recovery(backend, _FakeDoc(['', '']));
      final plan = await r.analyze(_bytes);
      final done = r.recover(_bytes, plan, cancel: cancel).toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cancel.cancel();
      final events = await done.timeout(const Duration(seconds: 2));
      final outcome = events.last.outcome!;
      expect(outcome.canceled, isTrue);
      expect(outcome.pages, isEmpty);
      expect(outcome.failed, isEmpty, reason: 'a stop is not a failure');
      expect(backend.calls, contains('abort'));
    });

    test('cancelling the subscription stops the work', () async {
      final backend = _FakeBackend(ocrDelay: (_) async {});
      final r = _recovery(backend, _FakeDoc(['', '', '']));
      final plan = await r.analyze(_bytes);
      await for (final e in r.recover(_bytes, plan)) {
        if (e.recovered != null) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        backend.calls.where((c) => c.startsWith('ocr')).length,
        lessThan(3),
      );
    });
  });

  group('merge into extracted pages', () {
    final pages = [
      PageText(page: 1, text: 'real text of page one, long enough to count'),
      PageText(page: 2, text: ''),
      PageText(page: 3, text: ''),
    ];

    test(
      'mergeRecovered replaces only recovered pages and sets the source',
      () {
        final merged = mergeRecovered(pages, const [
          RecoveredPage(page: 3, text: 'from the form', source: 'form'),
        ]);
        expect(merged.map((p) => p.source), [null, null, 'form']);
        expect(merged[2].text, 'from the form');
        expect(merged[0].text, pages[0].text);
        expect(merged[1].text, '');
      },
    );

    test('a text PDF comes back as the same list, nothing asked', () async {
      final backend = _FakeBackend();
      var asked = false;
      final got = await recoverPages(
        [PageText(page: 1, text: 'x' * 100)],
        _bytes,
        'a.pdf',
        RecoveryHook(
          _recovery(backend, _FakeDoc(['x'])),
          approve: (_) async => asked = true,
        ),
      );
      expect(got.single.source, isNull);
      expect(asked, isFalse);
      expect(backend.calls, isEmpty);
    });

    test('declining leaves the pages as they were', () async {
      final backend = _FakeBackend();
      final got = await recoverPages(
        pages,
        _bytes,
        'a.pdf',
        RecoveryHook(
          _recovery(backend, _FakeDoc(['a', 'b', 'c'])),
          approve: (plan) async {
            expect(plan.candidates, [2, 3]);
            return false;
          },
        ),
      );
      expect(identical(got, pages), isTrue);
      expect(backend.calls, isEmpty);
    });

    test('approved: recovered pages come back with their source', () async {
      final seen = <RecoveryPhase>[];
      final got = await recoverPages(
        pages,
        _bytes,
        'a.pdf',
        RecoveryHook(
          _recovery(_FakeBackend(), _FakeDoc(['a', 'b', 'c'])),
          onProgress: (p) => seen.add(p.phase),
        ),
      );
      expect(got.map((p) => p.source), [null, 'ocr', 'ocr']);
      expect(got[1].text, 'recognized text on page 2');
      expect(seen.last, RecoveryPhase.done);
    });

    test('nothing could be read: the pages come back unchanged', () async {
      final backend = _FakeBackend(supported: false);
      final got = await recoverPages(
        pages,
        _bytes,
        'a.pdf',
        RecoveryHook(_recovery(backend, _FakeDoc(['a', 'b', 'c']))),
      );
      expect(identical(got, pages), isTrue);
    });
  });

  test(
    'the platform stub reports itself unsupported and does not throw',
    () async {
      // flutter test runs on the VM: the default backend is the stub.
      final r = PdfRecovery(opener: (_, _) async => _FakeDoc(['', '']));
      expect(r.isSupported, isFalse);
      final plan = await r.analyze(_bytes);
      final (_, outcome) = await _run(r, plan);
      expect(
        outcome.failed.every((i) => i.reason == RecoveryFailure.unsupported),
        isTrue,
      );
    },
  );
}
