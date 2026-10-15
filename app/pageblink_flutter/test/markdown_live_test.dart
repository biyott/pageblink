import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';

const _base = TextStyle(fontSize: 16);
const _styles = LiveStyles();

/// Concatenated text of the span's children, and leaf-level sanity.
String _joined(TextSpan s) =>
    s.children!.map((c) => (c as TextSpan).text).join();

TextEditingValue _v(String text, [int? a, int? b]) => TextEditingValue(
  text: text,
  selection: a == null
      ? const TextSelection.collapsed(offset: -1)
      : TextSelection(baseOffset: a, extentOffset: b ?? a),
);

void main() {
  group('span text == input', () {
    final samples = <String>[
      '',
      'plain text',
      '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n####### not',
      '**bold** and *italic* and _under_ and `code` and [t](http://u)',
      '한글 **굵게** _기울임_ `코드` # 해시 [링크](주소)',
      '이모지 😀 **😀 bold** 👨‍👩‍👧 `🚀` > 인용',
      '> quote\n> > nested\n- item\n* item\n+ item\n1. one\n2) two',
      '- [ ] todo\n- [x] done\n  - [X] indented',
      'unclosed **bold and *italic and `code and [link](',
      '2 * 3 * 4 and snake_case_name and a_b_',
      '```dart\nfinal a = **x**;\n# not heading\n```\nafter **bold**',
      '```\nunterminated fence **x**\n',
      'trailing newline\n',
      '\n\n\n',
      r'escaped \*not italic\* and \`not code\`',
      '***bold italic*** and **a *b* c**',
      '![img](u) and [a](b)(c)',
      '#nospace\n# \n#\n>no space',
    ];
    for (final s in samples) {
      test(s.replaceAll('\n', r'\n'), () {
        final span = liveMarkdownSpan(s, _base, _styles);
        expect(_joined(span), s);
        final runs = parseLiveRuns(s, _styles);
        var pos = 0;
        for (final r in runs) {
          expect(r.start, pos);
          expect(r.end, greaterThan(r.start));
          pos = r.end;
        }
        expect(pos, s.length);
      });
    }

    test('styles apply and markers are kept', () {
      const text = '# Title\n**b** `c`';
      final runs = parseLiveRuns(text, _styles);
      String of(LiveRun r) => text.substring(r.start, r.end);
      final byText = {for (final r in runs) of(r): r.style};
      expect(byText['# ']!.color, _styles.marker.color);
      expect(byText['Title']!.fontSize, _styles.h1.fontSize);
      expect(byText['b']!.fontWeight, FontWeight.w700);
      expect(byText['c']!.fontSize, _styles.code.fontSize);
    });

    test('code fence disables inline rules', () {
      const text = '```\n**x**\n```';
      final runs = parseLiveRuns(text, _styles);
      expect(runs.any((r) => r.style.fontWeight == FontWeight.w700), isFalse);
    });
  });

  group('IME composing', () {
    test('underline preserved; cut through a styled run keeps text intact', () {
      const text = '한글 **굵게 입력**';
      // composing covers "글 **굵" - starts in plain, ends inside bold.
      final comp = TextRange(start: 1, end: text.indexOf('굵') + 1);
      final span = liveMarkdownSpan(text, _base, _styles, composing: comp);
      expect(_joined(span), text);
      var underlined = '';
      for (final c in span.children!.cast<TextSpan>()) {
        if (c.style?.decoration == TextDecoration.underline) {
          underlined += c.text!;
        }
      }
      expect(underlined, text.substring(comp.start, comp.end));
    });

    test('composing at every boundary keeps the invariant', () {
      const text = '# 제목 **굵게**\n- [x] `코드` [링크](u) 😀';
      for (var a = 0; a < text.length; a++) {
        for (var b = a + 1; b <= text.length; b += 3) {
          final span = liveMarkdownSpan(
            text,
            _base,
            _styles,
            composing: TextRange(start: a, end: b),
            highlight: TextRange(start: b ~/ 2, end: b),
          );
          expect(_joined(span), text);
        }
      }
    });

    testWidgets('controller.buildTextSpan honours value.composing', (t) async {
      final c = LiveMarkdownController(
        text: '가나 **다라**',
        styleOf: (_, _) => _styles,
      );
      c.value = c.value.copyWith(
        selection: const TextSelection.collapsed(offset: 5),
        composing: const TextRange(start: 3, end: 5),
      );
      late TextSpan span;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = c.buildTextSpan(
                context: context,
                style: _base,
                withComposing: true,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(_joined(span), c.text);
      expect(
        span.children!.cast<TextSpan>().any(
          (s) => s.style?.decoration == TextDecoration.underline,
        ),
        isTrue,
      );
      // Source mode: stock behaviour, still the same text.
      c.live = false;
      late TextSpan plain;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              plain = c.buildTextSpan(
                context: context,
                style: _base,
                withComposing: true,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain.toPlainText(), c.text);
    });
  });

  group('toggles', () {
    test('heading: set, replace, remove, body', () {
      var v = setHeading(_v('hello', 2), 2);
      expect(v.text, '## hello');
      expect(v.selection.baseOffset, 5);
      v = setHeading(v, 3); // replace
      expect(v.text, '### hello');
      v = setHeading(v, 3); // same level -> off
      expect(v.text, 'hello');
      expect(v.selection.baseOffset, 2);
      v = setHeading(setHeading(v, 1), 0); // body
      expect(v.text, 'hello');
      expect(headingLevel(setHeading(v, 2)), 2);
    });

    test('heading under quote and on several lines', () {
      var v = setHeading(_v('> quote', 3), 1);
      expect(v.text, '> # quote');
      v = setHeading(_v('a\n\nb', 0, 4), 2);
      expect(v.text, '## a\n\n## b');
      expect(setHeading(v, 2).text, 'a\n\nb');
    });

    test('bullet / checklist / quote round trip', () {
      const src = 'one\ntwo';
      for (final f in [toggleBullet, toggleCheck, toggleQuote]) {
        final on = f(_v(src, 0, src.length));
        expect(on.text, isNot(src));
        expect(f(on).text, src);
      }
      expect(toggleBullet(_v('x', 0)).text, '- x');
      expect(toggleCheck(_v('x', 0)).text, '- [ ] x');
      expect(toggleQuote(_v('x', 0)).text, '> x');
      // conversions
      expect(toggleCheck(_v('- x', 3)).text, '- [ ] x');
      expect(toggleBullet(_v('- [ ] x', 7)).text, '- x');
      expect(toggleBullet(_v('1. x', 4)).text, '- x');
      expect(toggleCheck(_v('- [x] x', 7)).text, 'x');
    });

    test('selection follows prefix edits', () {
      final v = toggleQuote(_v('abc\ndef', 5, 7)); // "ef"
      expect(v.text, 'abc\n> def');
      expect(v.text.substring(v.selection.start, v.selection.end), 'ef');
    });

    test('bold: wrap, unwrap by selection and by caret, empty pair', () {
      var v = toggleInline(_v('say hi now', 4, 6), '**');
      expect(v.text, 'say **hi** now');
      expect(v.text.substring(v.selection.start, v.selection.end), 'hi');
      v = toggleInline(v, '**'); // inside pair -> remove
      expect(v.text, 'say hi now');
      expect(v.text.substring(v.selection.start, v.selection.end), 'hi');
      v = toggleInline(_v('a **b** c', 2, 7), '**'); // selection has markers
      expect(v.text, 'a b c');
      v = toggleInline(_v('ab', 1), '`');
      expect(v.text, 'a``b');
      expect(v.selection.baseOffset, 2);
      v = toggleInline(v, '`');
      expect(v.text, 'ab');
      expect(v.selection.baseOffset, 1);
      v = toggleInline(_v('a **bc** d', 6), '**'); // caret inside word
      expect(v.text, 'a bc d');
    });

    test('italic uses _ and survives round trip', () {
      final on = toggleInline(_v('x', 0, 1), '_');
      expect(on.text, '_x_');
      expect(toggleInline(on, '_').text, 'x');
    });

    test('link: wrap, caret in parens, unlink', () {
      var v = toggleLink(_v('see docs', 4, 8));
      expect(v.text, 'see [docs]()');
      expect(v.selection.baseOffset, v.text.length - 1);
      v = toggleLink(_v('[docs](u) x', 3));
      expect(v.text, 'docs x');
      v = toggleLink(_v('', 0));
      expect(v.text, '[]()');
      expect(v.selection.baseOffset, 1);
    });

    test('invalid selection acts at end of text', () {
      expect(toggleBullet(_v('a\nb')).text, 'a\n- b');
      expect(toggleInline(_v('a'), '**').text, 'a****');
    });
  });

  group('quote highlight', () {
    test('finds exact, whitespace-tolerant and prefix matches', () {
      const body = 'intro\nThe quick  brown\nfox jumps over **the** lazy dog';
      expect(
        findQuote(body, 'quick  brown'),
        const TextRange(start: 10, end: 22),
      );
      final r = findQuote(body, 'The quick brown fox jumps')!;
      expect(body.substring(r.start, r.end), 'The quick  brown\nfox jumps');
      // quote lacks the markers: first 8 words still locate it
      final p = findQuote(
        body,
        'The quick brown fox jumps over the lazy dog',
      );
      expect(p, isNotNull);
      expect(findQuote(body, 'absent words'), isNull);
      expect(findQuote(body, '  '), isNull);
    });

    test('highlight overlay keeps text and adds background', () {
      const text = 'a **bold** quote here';
      final hl = findQuote(text, 'bold** quote')!;
      final span = liveMarkdownSpan(text, _base, _styles, highlight: hl);
      expect(_joined(span), text);
      final tinted = span.children!
          .cast<TextSpan>()
          .where((s) => s.style?.backgroundColor == _styles.highlight)
          .map((s) => s.text)
          .join();
      expect(tinted, 'bold** quote');
    });
  });

  test('10k chars parse + span build time (reported)', () {
    final line =
        '# 제목 줄\n본문 **굵게** 와 _기울임_ 그리고 `code` 그리고 [링크](http://x) 이어서 쓴다.\n'
        '- [ ] 할 일 항목 하나\n> 인용문 한 줄\n';
    final text = List.filled(
      10000 ~/ line.length + 1,
      line,
    ).join().substring(0, 10000);
    liveMarkdownSpan(text, _base, _styles); // warm up
    final sw = Stopwatch()..start();
    const n = 20;
    for (var i = 0; i < n; i++) {
      liveMarkdownSpan(text, _base, _styles);
    }
    final ms = sw.elapsedMicroseconds / n / 1000;
    // ignore: avoid_print
    print('10k chars: ${ms.toStringAsFixed(2)} ms per span build (JIT/test)');
    expect(ms, lessThan(16));
  });
}
