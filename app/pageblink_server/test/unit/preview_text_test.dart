import 'package:pageblink_server/src/rag/preview_text.dart';
import 'package:test/test.dart';

typedef P = ({int page, String text});
P p(int page, String text) => (page: page, text: text);

void main() {
  const body1 =
      'The orientation starts at nine and ends at noon on Monday. '
      'Bring your badge.';

  group('pdfPreview', () {
    test('a short text of the first real page is returned as is', () {
      expect(pdfPreview([p(1, body1)]), body1);
    });

    test('lines and runs of spaces become single spaces', () {
      expect(
        pdfPreview([
          p(
            1,
            'Orientation starts\r\nat   nine\n\n  on Monday morning, bring a badge.\n',
          ),
        ]),
        'Orientation starts at nine on Monday morning, bring a badge.',
      );
    });

    test('pages are taken in page order, not list order', () {
      expect(pdfPreview([p(2, 'b' * 50), p(1, 'a' * 50)]), 'a' * 50);
    });

    test('a cover with a short title is skipped for the first body page', () {
      expect(
        pdfPreview([p(1, 'Annual Report\n2026'), p(2, ''), p(3, body1)]),
        body1,
      );
    });

    test('a Korean cover is skipped; 39 visible characters are not enough', () {
      final cover = '가' * 39;
      final body = '신입 사원 오리엔테이션은 월요일 아침 아홉 시에 시작해 정오에 끝나며, 신분증을 꼭 지참해 주세요.';
      expect(pdfPreview([p(1, cover), p(2, body)]), body);
      expect(pdfPreview([p(1, '가' * 40)]), '가' * 40);
    });

    test('no page with 40 visible characters gives an empty string', () {
      expect(pdfPreview([]), '');
      expect(pdfPreview([p(1, ''), p(2, '  \n ')]), '');
      expect(pdfPreview([p(1, 'Short title'), p(2, '- 2 -')]), '');
    });

    test('page numbers are dropped, in every common form', () {
      for (final n in [
        '3',
        '- 3 -',
        '– 3 –',
        'Page 3',
        'page 3 of 9',
        'p. 3',
        '3 / 9',
        '3쪽',
        '제 3 페이지',
      ]) {
        expect(pdfPreview([p(1, '$n\n$body1\n$n')]), body1, reason: n);
      }
    });

    test('a number inside a sentence stays', () {
      const t = 'Page 3 of the contract lists 12 items and 4 appendices.';
      expect(pdfPreview([p(1, t)]), t);
    });

    test('running heads and footers (digits ignored) are dropped', () {
      String page(int n, String body) =>
          'ACME Report 2026\n$body\nConfidential - $n';
      final pages = [
        p(1, page(1, body1)),
        p(2, page(2, 'Second page body text that is long enough to count.')),
        p(3, page(3, 'Third page body text that is long enough to count.')),
        p(4, page(4, 'Fourth page body text that is long enough to count.')),
      ];
      expect(pdfPreview(pages), body1);
    });

    test('a head that opens only one of many pages stays', () {
      final pages = [
        p(1, 'Orientation guide for new staff\n$body1'),
        for (var i = 2; i <= 8; i++)
          p(i, 'Other page $i with enough words to be real text here.'),
      ];
      expect(pdfPreview(pages), startsWith('Orientation guide for new staff'));
    });

    test('dotted leader lines are dropped', () {
      expect(
        pdfPreview([
          p(1, 'Intro ........ 3\n$body1\nAppendix . . . . . . 9'),
        ]),
        body1,
      );
    });

    test('a contents page is skipped as a whole', () {
      const toc =
          'Contents\n'
          '1. Introduction ........ 3\n'
          '2. Schedule and rooms ........ 5\n'
          '3. Travel ........ 8\n'
          '4. 연락처 · · · · · · 12\n'
          '5. Index ………… 15';
      expect(pdfPreview([p(1, toc), p(2, body1)]), body1);
    });

    test('form and OCR pages are read like any other text', () {
      expect(
        pdfPreview([
          p(1, ''),
          p(
            2,
            'Name: Jane Doe\nDepartment: Finance and Accounting\nStart: 2026-11-02',
          ),
        ]),
        'Name: Jane Doe Department: Finance and Accounting Start: 2026-11-02',
      );
    });

    test('text of exactly 240 characters is not cut', () {
      final t = '${'word ' * 47}word!!'; // 47*5 + 6 = 241
      final exact = t.substring(0, 240);
      expect(pdfPreview([p(1, exact)]), exact);
    });

    test('a longer English text is cut at a word with an ellipsis', () {
      final t = List.generate(60, (i) => 'word${i % 10}x').join(' ');
      final out = pdfPreview([p(1, t)]);
      expect(out.length, lessThanOrEqualTo(240));
      expect(out, endsWith('…'));
      final last = out.substring(0, out.length - 1).split(' ').last;
      expect(last, matches(RegExp(r'^word\dx$')), reason: 'whole words only');
      expect(t, startsWith(out.substring(0, out.length - 1)));
    });

    test('a Korean text is cut at a space and the dangling comma goes', () {
      final t = List.generate(80, (i) => '오리엔테이션은,').join(' ');
      final out = pdfPreview([p(1, t)]);
      expect(out.length, lessThanOrEqualTo(240));
      expect(out, endsWith('오리엔테이션은…'));
    });

    test('CJK text without spaces is cut after its punctuation', () {
      final t = List.generate(40, (i) => '新入社員の研修は月曜日に始まります。').join();
      final out = pdfPreview([p(1, t)]);
      expect(out.length, lessThanOrEqualTo(240));
      expect(out, endsWith('始まります…'));
    });

    test('a long unbroken run is cut hard, never inside an emoji', () {
      final t = '😀' * 200;
      final out = pdfPreview([p(1, t)]);
      expect(out.length, lessThanOrEqualTo(240));
      expect(out, endsWith('😀…'));
      expect(out.runes.every((r) => r == 0x1F600 || r == 0x2026), isTrue);
    });
  });
}
