import 'dart:math';

import 'package:pageblink_server/src/rag/line_chunker.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:test/test.dart';

String _noWs(String s) => s.replaceAll(RegExp(r'\s+'), '');

/// Every note chunk is a verbatim, ordered, non-overlapping slice of [body].
void _expectSlices(String body, List<LineChunk> chunks, {String? reason}) {
  var prevEnd = 0;
  for (final (i, c) in chunks.indexed) {
    expect(c.ordinal, i, reason: reason);
    expect(body.substring(c.start, c.end), c.text, reason: reason);
    expect(c.text, c.text.trim(), reason: reason);
    expect(c.text, isNotEmpty, reason: reason);
    expect(c.start, greaterThanOrEqualTo(prevEnd), reason: reason);
    prevEnd = c.end;
  }
}

List<String> _texts(List<LineChunk> cs) => [for (final c in cs) c.text];

void main() {
  group('note rules', () {
    test('one chunk per list item, headings are the path', () {
      const body =
          '# Q4 launch plan\n\n'
          '## Numbers\n- **Budget:** 12M\n- **Date:** Nov 18\n\n'
          '## To do\n- [x] Book the rota\n- [ ] Finalize the notes\n';
      final cs = chunkNote(body, docTitle: 'Q4 launch plan');
      expect(_texts(cs), [
        '- **Budget:** 12M',
        '- **Date:** Nov 18',
        '- [x] Book the rota',
        '- [ ] Finalize the notes',
      ]);
      expect(
        [for (final c in cs) c.path],
        [
          'Numbers',
          'Numbers',
          'To do',
          'To do',
        ],
      );
      _expectSlices(body, cs);
    });

    test('a heading that is not the document title joins the path', () {
      const body = '# Plan\n## A\n### B\n- item number one\n';
      expect(chunkNote(body, docTitle: 'Other').single.path, 'Plan > A > B');
      expect(chunkNote(body, docTitle: 'Plan').single.path, 'A > B');
    });

    test('checklist markers and CRLF are kept; offsets index the body', () {
      const body =
          '## Todo\r\n- [ ] Buy coffee beans\r\n- [x] Call Sam back\r\n';
      final cs = chunkNote(body);
      expect(_texts(cs), ['- [ ] Buy coffee beans', '- [x] Call Sam back']);
      _expectSlices(body, cs);
    });

    test('nested list: each item a chunk, parent text only in the path', () {
      const body =
          '## Trip\n'
          '- Pack the bags\n'
          '  - Passport and tickets\n'
          '  - Chargers and cables\n'
          '- Book the hotel\n';
      final cs = chunkNote(body);
      expect(_texts(cs), [
        '- Pack the bags',
        '- Passport and tickets',
        '- Chargers and cables',
        '- Book the hotel',
      ]);
      expect(cs[1].path, 'Trip > Pack the bags');
      expect(cs[3].path, 'Trip');
      _expectSlices(body, cs);
    });

    test('an indented continuation stays with its list item', () {
      const body = '- Write the report\n  due on Friday\n- Send it out today\n';
      expect(_texts(chunkNote(body)), [
        '- Write the report\n  due on Friday',
        '- Send it out today',
      ]);
    });

    test('quote lines and table rows are one block each', () {
      const body =
          '> Ship the onboarding\n> before the freeze\n\n'
          '| Name | Role |\n|---|---|\n| Mina | Lead |\n';
      final cs = chunkNote(body);
      expect(_texts(cs), [
        '> Ship the onboarding\n> before the freeze',
        '| Name | Role |\n|---|---|\n| Mina | Lead |',
      ]);
      expect([for (final c in cs) c.kind], ['quote', 'table']);
    });

    test('a long table splits on row boundaries only', () {
      final rows = [for (var i = 0; i < 20; i++) '| row $i | some cell text |'];
      final body = rows.join('\n');
      final cs = chunkNote(body);
      expect(cs.length, greaterThan(1));
      for (final c in cs) {
        expect(c.text.length, lessThanOrEqualTo(300));
        for (final line in c.text.split('\n')) {
          expect(rows, contains(line));
        }
      }
      expect(_texts(cs).join('\n'), body);
    });

    test('a code fence is one chunk up to 600 chars, then splits by line', () {
      const small = '```dart\nvar x = 1;\nvar y = 2;\n```';
      expect(_texts(chunkNote('Run:\n\n$small\n')), ['Run:', small]);

      final big =
          '```\n${List.filled(40, 'echo "line of shell code"').join('\n')}\n```';
      final cs = chunkNote(big);
      expect(cs.length, greaterThan(1));
      for (final c in cs) {
        expect(c.text.length, lessThanOrEqualTo(600));
        expect(c.kind, 'code');
      }
      _expectSlices(big, cs);
    });

    test('a fence is not parsed as markdown inside', () {
      const body = '```\n# not a heading\n- not a list\n```\n';
      final cs = chunkNote(body);
      expect(cs, hasLength(1));
      expect(cs.single.text, body.trim());
    });

    test('items under 6 visible chars merge with the next same-path item', () {
      const body = '## A\n- ok\n- no\n- A real item with text\n';
      expect(_texts(chunkNote(body)), ['- ok\n- no\n- A real item with text']);
    });

    test('a short last item merges back; other paths do not merge', () {
      expect(_texts(chunkNote('## A\n- A real item with text\n- ok\n')), [
        '- A real item with text\n- ok',
      ]);
      final cs = chunkNote('## A\n- ok\n## B\n- A real item with text\n');
      expect(_texts(cs), ['- ok', '- A real item with text']);
    });

    test('exactly 6 visible chars stays alone', () {
      final cs = chunkNote('## A\n- abcdef\n- A real item with text\n');
      expect(_texts(cs), ['- abcdef', '- A real item with text']);
    });

    test('a line over 300 chars splits into sentences, at most 300', () {
      final long = List.generate(
        14,
        (i) => 'This is sentence number $i of a very long paragraph line.',
      ).join(' ');
      expect(long.length, greaterThan(300));
      final body = '## Long\n$long\n';
      final cs = chunkNote(body);
      expect(cs.length, greaterThan(1));
      for (final c in cs) {
        expect(c.text.length, lessThanOrEqualTo(300));
        expect(c.text, endsWith('.'));
      }
      _expectSlices(body, cs);
      // exactly 300 is not split
      final exact = 'x' * 300;
      expect(chunkNote(exact), hasLength(1));
      expect(chunkNote('${'x' * 149} ${'y' * 150}'), hasLength(1));
      expect(chunkNote('${'x' * 150} ${'y' * 150}'), hasLength(2));
    });

    test('a 650-char Korean line without spaces is cut hard, no overlap', () {
      final body = '가' * 650;
      final cs = chunkNote(body);
      expect(cs.map((c) => c.text.length), [300, 300, 50]);
      _expectSlices(body, cs);
    });

    test('hard cuts never split a surrogate pair', () {
      final body = '😀' * 400; // 800 UTF-16 units, no whitespace
      final cs = chunkNote(body);
      for (final c in cs) {
        expect(c.text.length.isEven, isTrue);
        expect(c.text.length, lessThanOrEqualTo(300));
      }
      expect(_texts(cs).join(), body);
    });

    test('empty bodies, rules and empty items give no chunks', () {
      expect(chunkNote(''), isEmpty);
      expect(chunkNote('  \n\n  '), isEmpty);
      expect(chunkNote('---\n***\n- [ ]\n>\n'), isEmpty);
      expect(chunkNote('# Hi').map((c) => c.text), ['# Hi']);
    });

    test('a note over 20,000 chars packs adjacent lines (< 300 chars)', () {
      final b = StringBuffer();
      for (var h = 0; h < 40; h++) {
        b.writeln('## Section $h');
        for (var i = 0; i < 40; i++) {
          b.writeln('- [ ] item ${h * 40 + i}: do the thing number $i');
        }
        b.writeln();
      }
      final body = b.toString();
      expect(body.length, greaterThan(largeNoteChars));
      final packed = chunkNote(body, docTitle: 'Big');
      final lines = chunkNote(
        body,
        docTitle: 'Big',
        rules: const ChunkRules(),
      );
      expect(lines.length, 1600);
      expect(packed.length, lessThan(lines.length ~/ 4));
      for (final c in packed) {
        expect(c.text.length, lessThanOrEqualTo(300));
      }
      _expectSlices(body, packed);
    });
  });

  group('invariants', () {
    test('every sample note and PDF page, all languages', () {
      for (final p in SamplePacks.all) {
        for (final n in p.notes) {
          final cs = chunkNote(n.body, docTitle: n.title);
          expect(cs, isNotEmpty, reason: n.title);
          _expectSlices(n.body, cs, reason: '${p.id}: ${n.title}');
        }
        for (final (i, page) in (p.pdf?.pages ?? const <String>[]).indexed) {
          final cs = chunkPdfPage(i + 1, page);
          expect(cs, isNotEmpty, reason: '${p.id} p${i + 1}');
          for (final c in cs) {
            expect(_noWs(page), contains(_noWs(c.text)));
            expect(_noWs(page.substring(c.start, c.end)), _noWs(c.text));
          }
        }
      }
    });

    test('sample chunk counts (design 029 §7.1)', () {
      int notes(SamplePack p, int i) =>
          chunkNote(p.notes[i].body, docTitle: p.notes[i].title).length;
      expect(notes(SamplePacks.demoEn, 0), 10); // tour
      expect(notes(SamplePacks.demoEn, 1), 11); // Q4 launch plan
      expect(notes(SamplePacks.demoEn, 2), 9); // weekly sync
      expect(notes(SamplePacks.demoKo, 0), 10);
      expect(notes(SamplePacks.demoKo, 1), 11);
      expect(notes(SamplePacks.demoKo, 2), 9);
      expect(notes(SamplePacks.signupEn, 0), 8);
      expect(notes(SamplePacks.signupKo, 0), 8);
      final pdf = SamplePacks.demoEn.pdf!;
      final cs = chunkPdfPages([
        for (final (i, t) in pdf.pages.indexed) (page: i + 1, text: t),
      ]);
      expect(cs, hasLength(19));
      expect(
        [for (var p = 1; p <= 3; p++) cs.where((c) => c.page == p).length],
        [
          7,
          6,
          6,
        ],
      );
    });

    test('fuzz: markdown-like bodies (fixed seed)', () {
      final frag = [
        '# Title', '## Section', '### Sub', '- item one', '- [ ] todo', //
        '- [x] done', '  - nested item', '1. first', '2) second',
        '> quote line', '> second quote', '---', '***', '| a | b |',
        '|---|---|', '| 1 | 2 |', '```dart', 'var x = 1;', '```', '', '',
        'Plain paragraph with a sentence. Another one! And a third? 3.14 is pi, v1.2.3 ok.',
        '한국어 문장입니다. 두 번째 문장이에요? 세 번째!', 'x', '- ', '#', '> ',
        'Dr. Kim met Mr. Lee at 5 p.m. on Nov. 18.', 'A' * 700, '가' * 650,
        'word ' * 90, '   indented para', '\ttab item',
        '- [ ] ${'긴 항목 ' * 60}', '😀' * 200, '- ${'😀' * 30}',
      ];
      final rnd = Random(29);
      var total = 0;
      for (var iter = 0; iter < 2000; iter++) {
        final n = 1 + rnd.nextInt(14);
        final eol = rnd.nextBool() ? '\n' : '\r\n';
        final body =
            List.generate(n, (_) => frag[rnd.nextInt(frag.length)]).join(eol) +
            (rnd.nextBool() ? eol : '');
        final cs = chunkNote(body, docTitle: 'Title');
        _expectSlices(body, cs, reason: body);
        for (final c in cs) {
          total++;
          if (c.kind != 'code' && c.kind != 'table') {
            expect(c.text.length, lessThanOrEqualTo(300), reason: c.kind);
          }
          expect(c.text.length, lessThanOrEqualTo(700));
        }
        for (final c in chunkPdfPage(1, body)) {
          total++;
          expect(_noWs(body), contains(_noWs(c.text)));
          expect(c.text.length, lessThanOrEqualTo(340));
          expect(c.text, isNotEmpty);
        }
      }
      expect(total, greaterThan(10000));
    });
  });

  group('pdf rules', () {
    List<String> ends(String s) {
      final out = <String>[];
      var from = 0;
      for (final e in sentenceEnds(s)) {
        out.add(s.substring(from, e).trim());
        from = e;
      }
      return out;
    }

    test('sentence split: Latin, Korean, full-width, marks', () {
      expect(ends('One. Two! Three? Four'), ['One.', 'Two!', 'Three?', 'Four']);
      expect(ends('저장하세요. 검색됩니다. 질문하세요?'), [
        '저장하세요.',
        '검색됩니다.',
        '질문하세요?',
      ]);
      expect(ends('문장입니다。다음 문장입니다。'), ['문장입니다。', '다음 문장입니다。']);
      expect(ends('He said "stop." Then left.'), [
        'He said "stop."',
        'Then left.',
      ]);
    });

    test('decimals, versions, abbreviations and list numbers are kept', () {
      expect(ends('Pi is 3.14 and v1.2.3 works. Next.'), [
        'Pi is 3.14 and v1.2.3 works.',
        'Next.',
      ]);
      expect(ends('Ask Dr. Kim, e.g. now. Done.'), [
        'Ask Dr. Kim, e.g. now.',
        'Done.',
      ]);
      expect(ends('See Fig. 3 for details. Next.'), [
        'See Fig. 3 for details.',
        'Next.',
      ]);
      expect(ends('1. First 2. Second. Third.'), [
        '1. First 2. Second.',
        'Third.',
      ]);
      expect(ends('Meet J. Smith at noon. Bye.'), [
        'Meet J. Smith at noon.',
        'Bye.',
      ]);
    });

    test('sentences pack to ~120 chars, never over 300', () {
      final text = List.generate(
        20,
        (i) => 'Sentence $i has some words in it.',
      ).join(' ');
      final cs = chunkPdfPage(1, text);
      expect(cs.length, greaterThan(3));
      for (final c in cs.take(cs.length - 1)) {
        expect(c.text.length, inInclusiveRange(100, 300));
        expect(c.text, endsWith('.'));
      }
      final wide = chunkPdfPage(
        1,
        text,
        rules: const ChunkRules(targetChars: 300),
      );
      expect(wide.length, lessThan(cs.length));
      for (final c in wide) {
        expect(c.text.length, lessThanOrEqualTo(340));
      }
    });

    test('hard-wrapped lines are reflowed with single spaces', () {
      const text =
          'PageBlink reads the text page by page,\n'
          'so an answer can point to the exact page.\n';
      final c = chunkPdfPage(1, text).single;
      expect(
        c.text,
        'PageBlink reads the text page by page, so an answer can point to the exact page.',
      );
      expect(text.substring(c.start, c.end).replaceAll('\n', ' '), c.text);
    });

    test('a blank line and a bullet end a paragraph', () {
      const text =
          'First paragraph is here and it is long enough to stand alone fine.\n\n'
          'Second paragraph is here and it is long enough to stand alone too.\n'
          '- A bullet line that is also long enough to stand alone as a chunk.\n';
      final cs = chunkPdfPage(1, text);
      expect(cs, hasLength(3));
      expect(cs[2].text, startsWith('- A bullet'));
    });

    test('a short heading-like paragraph joins the next paragraph', () {
      const text =
          'Short title\n\n'
          'The paragraph that follows the title has plenty of words in it.\n';
      final cs = chunkPdfPage(1, text);
      expect(cs.single.text, startsWith('Short title The paragraph'));
    });

    test('pages stay apart; ordinals run across pages', () {
      final cs = chunkPdfPages([
        (page: 1, text: 'Page one has a sentence. And a second one here.'),
        (page: 2, text: ''),
        (page: 3, text: 'Page three is last. It has two sentences as well.'),
      ]);
      expect({for (final c in cs) c.page}, {1, 3});
      expect(
        [for (final c in cs) c.ordinal],
        [for (var i = 0; i < cs.length; i++) i],
      );
      expect(cs.first.text, startsWith('Page one'));
      expect(cs.last.text, startsWith('Page three'));
    });

    test('over 60,000 chars the target rises to 300 (fewer chunks)', () {
      expect(pdfTargetFor(60000), 120);
      expect(pdfTargetFor(60001), 300);
      final page = List.generate(
        500,
        (i) => 'The quick brown fox $i jumps over the lazy dog.',
      ).join(' ');
      expect(page.length * 4, greaterThan(largePdfChars));
      expect(page.length, lessThan(largePdfChars));
      final smallDoc = chunkPdfPages([(page: 1, text: page)]);
      final largeDoc = chunkPdfPages([
        for (var p = 1; p <= 4; p++) (page: p, text: page),
      ]);
      final sameStart = largeDoc.where((c) => c.page == 1).toList();
      expect(sameStart.length, lessThan(smallDoc.length));
      for (final c in largeDoc) {
        expect(c.text.length, lessThanOrEqualTo(340));
      }
    });
  });

  group('embedding title', () {
    test('document title, then the path', () {
      expect(embeddingTitle('Plan', ''), 'Plan');
      expect(embeddingTitle('Plan', 'A > B'), 'Plan > A > B');
    });

    test('is at most 120 chars and keeps the nearest headings', () {
      final t = embeddingTitle('T' * 50, '${'a' * 60} > ${'b' * 40} > Near');
      expect(t.length, lessThanOrEqualTo(120));
      expect(t, startsWith('…'));
      expect(t, endsWith('Near'));
      expect(embeddingTitle('x', 'y' * 200).length, lessThanOrEqualTo(120));
    });

    test('parent list items are cut at 40 chars in the path', () {
      final cs = chunkNote(
        '## L\n- ${'가' * 60}\n  - child item with text\n',
      );
      expect(cs[1].path, 'L > ${'가' * 40}…');
    });

    test('a pipe cannot break the Gemini title split; Hangul is NFC', () {
      expect(embeddingTitle('A | B', 'C | D'), 'A / B > C / D');
      expect(embeddingTitle('한', ''), '한');
    });

    test('truncation never leaves half a surrogate pair', () {
      final t = embeddingTitle('Doc', '😀' * 100);
      expect(t.length, lessThanOrEqualTo(120));
      expect(t.codeUnitAt(1) & 0xFC00, 0xD800);
    });
  });
}
