import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/rag/page_source.dart';
import 'package:test/test.dart';

void main() {
  group('normalizePageSource', () {
    test('keeps the known values, drops everything else', () {
      expect(normalizePageSource('form'), 'form');
      expect(normalizePageSource('ocr'), 'ocr');
      expect(normalizePageSource(null), isNull);
      expect(normalizePageSource('ai'), isNull);
      expect(normalizePageSource('OCR'), isNull);
      expect(normalizePageSource(''), isNull);
    });

    test('normalizePages rewrites only the unknown ones', () {
      final out = normalizePages([
        PageText(page: 1, text: 'a', source: 'ocr'),
        PageText(page: 2, text: 'b', source: 'evil'),
        PageText(page: 3, text: 'c'),
      ]);
      expect([for (final p in out) p.source], ['ocr', null, null]);
      expect([for (final p in out) p.text], ['a', 'b', 'c']);
    });
  });

  group('keepRecoveredPages', () {
    final stored = [
      DocPage(documentId: 1, page: 1, text: 'original one'),
      DocPage(documentId: 1, page: 2, text: 'ocr two', source: 'ocr'),
      DocPage(documentId: 1, page: 3, text: 'form three', source: 'form'),
      DocPage(documentId: 1, page: 4, text: '  ', source: 'ocr'),
    ];

    test('blank pages without a source get the recovered text back', () {
      final out = keepRecoveredPages([
        PageText(page: 1, text: ''),
        PageText(page: 2, text: ''),
        PageText(page: 3, text: ' \n '),
        PageText(page: 4, text: ''),
      ], stored);
      expect([for (final p in out) p.text], ['', 'ocr two', 'form three', '']);
      expect([for (final p in out) p.source], [null, 'ocr', 'form', null]);
    });

    test(
      'a footer-only page (under 30 visible characters) counts as blank',
      () {
        final out = keepRecoveredPages([
          PageText(page: 2, text: 'Page 2 of 9'),
          PageText(page: 3, text: '- 3 -   '),
        ], stored);
        expect(out[0].text, 'ocr two');
        expect(out[0].source, 'ocr');
        expect(out[1].text, 'form three');
        expect(out[1].source, 'form');
      },
    );

    test('a real text layer (30 visible characters) wins over stored OCR', () {
      final thirty = 'a' * 30;
      final out = keepRecoveredPages([
        PageText(page: 2, text: thirty),
        PageText(page: 3, text: '${'b' * 29} '),
      ], stored);
      expect(out[0].text, thirty);
      expect(out[0].source, isNull);
      expect(out[1].text, 'form three', reason: '29 visible: still a footer');
    });

    test('text the client sent wins, with or without a source', () {
      final out = keepRecoveredPages([
        PageText(page: 2, text: 'fresh original text of a real text layer'),
        PageText(page: 3, text: 'fresh ocr', source: 'ocr'),
        PageText(page: 5, text: ''),
      ], stored);
      expect(out[0].text, 'fresh original text of a real text layer');
      expect(out[0].source, isNull);
      expect(out[1].text, 'fresh ocr');
      expect(out[1].source, 'ocr');
      expect(out[2].text, '');
    });

    test('nothing recovered: the incoming list is returned as is', () {
      final incoming = [PageText(page: 1, text: '')];
      expect(
        identical(
          keepRecoveredPages(incoming, [
            DocPage(documentId: 1, page: 1, text: 'x'),
          ]),
          incoming,
        ),
        isTrue,
      );
    });
  });
}
