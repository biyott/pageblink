import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/ocr_text.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/page_detect.dart';
import 'package:pageblink_flutter/features/documents/pdf_recovery/recovery_models.dart';

/// Words laid out left to right, 20 px tall, with the given gaps before each.
OcrLine _line(List<(String, int)> words, {int conf = 90, int region = 0}) {
  var x = 100;
  final out = <OcrWord>[];
  for (final (t, gap) in words) {
    x += gap;
    final w = t.runes.length * 20;
    out.add(OcrWord(t, x, 200, x + w, 220, conf));
    x += w;
  }
  return OcrLine(region, out, conf);
}

void main() {
  group('visibleCharCount', () {
    test('counts letters, not spaces or control characters', () {
      expect(visibleCharCount(''), 0);
      expect(visibleCharCount(' \n\t  ​﻿'), 0);
      expect(visibleCharCount('가나 다\n'), 3);
      expect(visibleCharCount('a b'), 2);
      expect(visibleCharCount('\u0001\u0002ab'), 2);
    });

    test('replacement and private-use characters are not text', () {
      expect(visibleCharCount('���'), 0);
      expect(visibleCharCount(''), 0);
      expect(visibleCharCount('ab�'), 2);
    });

    test('counts a character outside the BMP once', () {
      expect(visibleCharCount('😀'), 1);
    });
  });

  group('mayHaveForms', () {
    Uint8List b(String s) => Uint8List.fromList(latin1.encode(s));

    test('a catalog with /AcroForm may have forms', () {
      expect(
        mayHaveForms(b('%PDF-1.4\n1 0 obj<</AcroForm 5 0 R>>endobj')),
        isTrue,
      );
    });

    test('compressed object streams could hide it', () {
      expect(
        mayHaveForms(b('%PDF-1.5\n4 0 obj<</Type/ObjStm>>stream')),
        isTrue,
      );
    });

    test('a plain scan has none, and tiny or empty data is safe', () {
      expect(
        mayHaveForms(b('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj')),
        isFalse,
      );
      expect(mayHaveForms(b('Acro')), isFalse);
      expect(mayHaveForms(Uint8List(0)), isFalse);
    });

    test('found at the very end of the file', () {
      expect(mayHaveForms(b('${'x' * 1000}AcroForm')), isTrue);
    });
  });

  group('planRecovery', () {
    test('a page under 30 visible characters is a candidate', () {
      final plan = planRecovery([29, 30, 31, 0, 5000]);
      expect(plan.candidates, [1, 4]);
      expect(plan.overLimit, isEmpty);
      expect(plan.pageCount, 5);
      expect(plan.needed, isTrue);
      expect(plan.allPagesEmpty, isFalse);
    });

    test('a text PDF needs nothing', () {
      final plan = planRecovery([120, 3000, 45]);
      expect(plan.needed, isFalse);
      expect(plan.candidates, isEmpty);
    });

    test('a scan has every page as a candidate', () {
      final plan = planRecovery([0, 0, 3]);
      expect(plan.allPagesEmpty, isTrue);
    });

    test('an empty document is not a scan', () {
      final plan = planRecovery(const []);
      expect(plan.needed, isFalse);
      expect(plan.allPagesEmpty, isFalse);
    });

    test('the page limit keeps the first pages and reports the rest', () {
      final plan = planRecovery(List.filled(60, 0));
      expect(plan.candidates, List.generate(50, (i) => i + 1));
      expect(plan.overLimit, List.generate(10, (i) => i + 51));
    });

    test('the limit counts candidate pages, not document pages', () {
      final texts = [for (var i = 0; i < 120; i++) i.isEven ? 100 : 0];
      final plan = planRecovery(texts);
      expect(plan.candidates, hasLength(50));
      expect(plan.overLimit, hasLength(10));
      expect(plan.candidates.first, 2);
    });

    test('limits are parameters', () {
      final plan = planRecovery([0, 0, 0], minChars: 1, maxPages: 2);
      expect(plan.candidates, [1, 2]);
      expect(plan.overLimit, [3]);
      expect(planRecovery([1, 0], minChars: 1).candidates, [2]);
    });
  });

  group('restoreLineSpaces', () {
    test('glues Hangul syllables Tesseract split, keeps real word gaps', () {
      // letter gaps ~10 px (0.5 of 20), here made small; word gaps ~16+ px
      final line = _line([
        ('이번', 0),
        ('워', 24),
        ('크', 6),
        ('숍', 6),
        ('은', 6),
        ('2026', 24),
        ('년', 4),
      ]);
      expect(restoreLineSpaces(line), '이번 워크숍은 2026년');
    });

    test('a number then a unit is glued, a number then a number is not', () {
      expect(
        restoreLineSpaces(_line([('11', 0), ('월', 3), ('14', 24), ('일', 3)])),
        '11월 14일',
      );
      expect(restoreLineSpaces(_line([('Nov', 0), ('18', 4)])), 'Nov 18');
    });

    test('Latin words keep their spaces however close', () {
      expect(
        restoreLineSpaces(_line([('Dana', 0), ('Whitfield', 2)])),
        'Dana Whitfield',
      );
    });

    test('a comma after a word is glued', () {
      expect(restoreLineSpaces(_line([('시작하며', 0), (',', 5)])), '시작하며,');
    });

    test('a far gap keeps the space even between syllables', () {
      expect(restoreLineSpaces(_line([('가', 0), ('나', 40)])), '가 나');
    });

    test('empty and blank words are dropped', () {
      expect(restoreLineSpaces(const OcrLine(0, [], 0)), '');
      expect(restoreLineSpaces(_line([(' ', 0), ('가', 5)])), '가');
    });
  });

  group('cleanOcrLines', () {
    test('table borders and rules become nothing', () {
      expect(
        cleanOcrLines(['| 시간 | 세션 |', '-----', '=====  ', '___', 'ㅣ']),
        ['시간 세션'],
      );
    });

    test('lines that are mostly specks go', () {
      expect(cleanOcrLines(['~ . \' ` ,', '© ㄷ', 'ok text', '"']), ['ok text']);
      expect(cleanOcrLines(['a']), isEmpty);
    });

    test('a short doubtful line goes, a short confident one stays', () {
      expect(cleanOcrLines(['abc de'], confidences: [20]), isEmpty);
      expect(cleanOcrLines(['abc de'], confidences: [85]), ['abc de']);
      expect(
        cleanOcrLines(['a longer line that is doubtful'], confidences: [20]),
        ['a longer line that is doubtful'],
      );
    });

    test('keeps numbers and Korean and collapses spaces', () {
      expect(cleanOcrLines(['  10:00   커피    검색 기초 ']), ['10:00 커피 검색 기초']);
    });
  });

  group('ocrPageText', () {
    test('regions keep their order and lines join with newlines', () {
      final data = OcrPageData([
        _line([('왼쪽', 0), ('단', 20)], region: 1),
        _line([('오른쪽', 0), ('단', 20)], region: 2),
      ]);
      expect(ocrPageText(data), '왼쪽 단\n오른쪽 단');
    });

    test('a blank page reads as empty text', () {
      expect(ocrPageText(const OcrPageData([])), '');
      expect(
        ocrPageText(
          OcrPageData([
            _line([('.', 0)]),
          ]),
        ),
        '',
      );
    });

    test('confidence is weighted by word length', () {
      final data = OcrPageData([
        OcrLine(0, [
          const OcrWord('abcdefgh', 0, 0, 10, 10, 90),
          const OcrWord('x', 0, 0, 10, 10, 10),
        ], 80),
      ]);
      expect(ocrConfidence(data), 81);
      expect(ocrConfidence(const OcrPageData([])), isNull);
    });
  });

  test('OcrPageData.fromJson reads what the page script returns', () {
    final json = jsonEncode({
      'lines': [
        {
          'r': 1,
          'c': 77,
          'b': [1, 2, 3, 4],
          'w': [
            {
              't': '안녕',
              'b': [10, 20, 30, 40],
              'c': 91,
            },
          ],
        },
      ],
      'regions': 2,
      'skew': 1.5,
    });
    final data = OcrPageData.fromJson(json);
    expect(data.regions, 2);
    expect(data.skew, 1.5);
    expect(data.lines.single.region, 1);
    expect(data.lines.single.conf, 77);
    final w = data.lines.single.words.single;
    expect(
      [w.text, w.x0, w.y0, w.x1, w.y1, w.conf],
      ['안녕', 10, 20, 30, 40, 91],
    );
    expect(OcrPageData.fromJson('{}').lines, isEmpty);
  });

  group('formPageText / recoveredOrNull', () {
    test('values only, one per line; the page\'s own text comes first', () {
      expect(formPageText('', ['서울', '', ' 부산 ']), '서울\n부산');
      expect(formPageText('머리글 abc', ['값']), '머리글 abc\n값');
      expect(formPageText('  ', ['값']), '값');
    });

    test('under 10 visible characters is no result', () {
      expect(
        recoveredOrNull(page: 1, text: '123456789', source: PageSource.ocr),
        isNull,
      );
      expect(
        recoveredOrNull(page: 1, text: '1234567890', source: PageSource.ocr),
        isNotNull,
      );
      expect(
        recoveredOrNull(page: 1, text: '12345 6789', source: PageSource.form),
        isNull,
        reason: 'spaces do not count',
      );
    });
  });
}
