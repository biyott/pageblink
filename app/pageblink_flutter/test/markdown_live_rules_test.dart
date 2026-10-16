import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';

/// Rule coverage for research 023 stages 1 and 2: every role gets its own
/// colour so a run's style names what the parser decided.
const _plain = TextStyle();
const _s = LiveStyles(
  h1: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
  h4: TextStyle(fontWeight: FontWeight.w500),
  marker: TextStyle(color: Color(0xFF000001)),
  bold: TextStyle(fontWeight: FontWeight.w700),
  italic: TextStyle(fontStyle: FontStyle.italic),
  code: TextStyle(fontFamily: 'mono'),
  quote: TextStyle(color: Color(0xFF000002)),
  link: TextStyle(
    color: Color(0xFF000003),
    decoration: TextDecoration.underline,
  ),
  checked: TextStyle(
    color: Color(0xFF000004),
    decoration: TextDecoration.lineThrough,
  ),
  bullet: TextStyle(color: Color(0xFF000010)),
  number: TextStyle(color: Color(0xFF000011)),
  todo: TextStyle(color: Color(0xFF000012)),
  done: TextStyle(color: Color(0xFF000013)),
  strike: TextStyle(decoration: TextDecoration.lineThrough),
);

/// `[text, style]` pairs of the parse.
List<(String, TextStyle)> _runs(String text) => [
  for (final r in parseLiveRuns(text, _s))
    (text.substring(r.start, r.end), r.style),
];

/// Style of the run that contains [part] (first occurrence).
TextStyle _at(String text, String part) {
  final i = text.indexOf(part);
  expect(i, greaterThanOrEqualTo(0), reason: '"$part" not in "$text"');
  return parseLiveRuns(
    text,
    _s,
  ).firstWhere((r) => r.start <= i && i < r.end).style;
}

/// Text covered by runs whose style equals [style] exactly.
String _covered(String text, TextStyle style) => [
  for (final r in parseLiveRuns(text, _s))
    if (r.style == style) text.substring(r.start, r.end),
].join('|');

final _code = _plain.merge(_s.code);
final _markerCode = _s.marker.merge(_s.code);

TextEditingValue _v(String text, [int? a, int? b]) => TextEditingValue(
  text: text,
  selection: a == null
      ? const TextSelection.collapsed(offset: -1)
      : TextSelection(baseOffset: a, extentOffset: b ?? a),
);

/// Types Enter at `|` in [src] (the caret) and returns the formatted value.
TextEditingValue _enter(String src) {
  final p = src.indexOf('|');
  final text = src.replaceFirst('|', '');
  final old = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: p),
  );
  final neu = TextEditingValue(
    text: text.replaceRange(p, p, '\n'),
    selection: TextSelection.collapsed(offset: p + 1),
  );
  return continueList(old, neu);
}

/// Result with `|` at the caret, for readable expectations.
String _shown(TextEditingValue v) =>
    v.text.replaceRange(v.selection.baseOffset, v.selection.baseOffset, '|');

void main() {
  group('span text == input (new rules)', () {
    final samples = <String>[
      '~~strike~~ and ~~ not~~ and ~~open',
      '~~**bold strike**~~ and [~~link~~](u)',
      '[t](https://a.com/x_(y)) and [u](a(b(c)d)e)',
      '[t](u "title") [t](<https://a.com/a b>) [](x) [x]()',
      'see https://a.com/x, or (https://a.com/y). <https://b.com> HTTP://C.COM',
      'a_https://x.com_b and https://x.com/a_b_c_ and 한글https://x.com',
      '---\n***\n___\n* * *\n- - -\n--\n**\n****',
      '- a\n  - b\n    - c\n\t- d\n1. e\n   2. f\n10) g',
      '- [ ] a\n- [x] b\n- [ ]\n- [x]c\n-\n- \n1.\n- [ ]  two spaces',
      '> a\n> > b\n>> c\n> - [x] d\n> ---\n>',
      '```x```\nnext **b**\n```',
      '```js\ncode\n```trailing\nstill\n```\nafter',
      '````\n```\ninner\n```\n````\nafter **b**',
      '~~~\n```\nstill code\n~~~\n```\nnot closed **x**',
      '- item\n    ```\n    **x**\n    ```\n- next',
      '``a`b`` and ```` ```x``` ```` and `` ` ``',
      r'\*a\* \~~b~~ \[a](b) \` \\ **\*x\*** trailing\',
      '***x*** and __y__ and _z_ and ___w___',
      '`a\nb` and **a\nb** and ~~a\nb~~',
      '# 한글 제목 **굵게** ~~취소~~ [링크](https://a.com) 😀\n- [x] 완료 `코드`',
      '#\n# \n  # x\n   # y\n    # z\n####### no',
      'https://a.com/한글/경로 and <https://a.com/한글>',
      '[a](b)[c](d)[e](f)https://g.com~~h~~',
    ];
    for (final text in samples) {
      test(text.replaceAll('\n', r'\n'), () {
        final runs = parseLiveRuns(text, _s);
        var pos = 0;
        for (final r in runs) {
          expect(r.start, pos);
          expect(r.end, greaterThan(r.start));
          pos = r.end;
        }
        expect(pos, text.length);
        // every composing range (IME) and a highlight keep text exact
        for (var a = 0; a < text.length; a++) {
          for (var b = a + 1; b <= text.length; b++) {
            final span = liveMarkdownSpan(
              text,
              const TextStyle(),
              _s,
              composing: TextRange(start: a, end: b),
              highlight: TextRange(start: a ~/ 2, end: b),
            );
            final joined = span.children!
                .map((c) => (c as TextSpan).text)
                .join();
            expect(joined, text);
          }
        }
      });
    }
  });

  group('headings (one regex for parser and toggle)', () {
    test('indent rule is the same on both sides', () {
      for (final (src, level) in [
        ('# x', 1),
        (' # x', 1),
        ('   # x', 1),
        ('    # x', 0),
        ('\t# x', 0),
        ('#x', 0),
        ('####### x', 0),
        ('###### x', 6),
        ('#', 1),
      ]) {
        expect(headingLevel(_v(src, 0)), level, reason: src);
        if (src.contains('x')) {
          final styled = _at(src, 'x');
          expect(styled == _s.h1 || styled == _s.h4, level > 0, reason: src);
        }
      }
    });

    test('indented heading toggles off cleanly instead of nesting', () {
      expect(setHeading(_v('  # x', 0), 1).text, 'x');
      expect(setHeading(_v('  # x', 0), 2).text, '## x');
      expect(setHeading(_v('   ## x', 0), 0).text, 'x');
    });

    test('H4-H6 report their own level, never body', () {
      expect(headingLevel(_v('#### x', 0)), 4);
      expect(headingLevel(_v('##### x', 0)), 5);
    });

    test('setHeading clamps to 0..3; legacy #### is replaced, not kept', () {
      expect(setHeading(_v('x', 0), 6).text, '### x');
      expect(setHeading(_v('x', 0), 4).text, '### x');
      expect(setHeading(_v('x', 0), -1).text, 'x');
      expect(setHeading(_v('#### x', 0), 3).text, '### x');
      expect(setHeading(_v('#### x', 0), 0).text, 'x');
      expect(setHeading(_v('### x', 0), 5).text, 'x'); // clamped to 3 = toggle
    });

    test('multi-line state: same level / body / mixed / blanks skipped', () {
      expect(headingLevel(_v('# a\n# b', 0, 7)), 1);
      expect(headingLevel(_v('a\nb', 0, 3)), 0);
      expect(headingLevel(_v('# a\n## b', 0, 8)), -1);
      expect(headingLevel(_v('a\n# b', 0, 5)), -1);
      expect(headingLevel(_v('# a\n\n# b', 0, 8)), 1);
      expect(headingLevel(_v('> # a', 0)), 1);
    });

    test('state follows the lines the toggle changes, not just the first', () {
      const src = 'a\n# b';
      final v = _v(src, 0, src.length);
      expect(headingLevel(v), -1);
      // pressing H1 on a mixed selection sets H1 on all
      final all = setHeading(v, 1);
      expect(all.text, '# a\n# b');
      expect(headingLevel(all), 1);
      // pressing H1 again clears all
      expect(setHeading(all, 1).text, 'a\nb');
    });

    test('selection ending after a newline does not touch the next line', () {
      expect(headingLevel(_v('# a\nb', 0, 4)), 1);
    });

    test('plain -> heading, level change, same level -> body', () {
      var v = setHeading(_v('hi', 1), 1);
      expect(v.text, '# hi');
      v = setHeading(v, 3);
      expect(v.text, '### hi');
      v = setHeading(v, 3);
      expect(v.text, 'hi');
    });
  });

  group('lists and checkboxes', () {
    test('bullet marker: accent, text plain', () {
      for (final m in ['-', '*', '+']) {
        expect(_runs('$m item'), [('$m ', _s.bullet), ('item', _plain)]);
      }
    });

    test('numbers: accent, text plain', () {
      expect(_runs('1. a'), [('1. ', _s.number), ('a', _plain)]);
      expect(_runs('10) a'), [('10) ', _s.number), ('a', _plain)]);
    });

    test('unchecked box gets its own state colour', () {
      expect(_runs('- [ ] todo'), [
        ('- ', _s.bullet),
        ('[ ] ', _s.todo),
        ('todo', _plain),
      ]);
    });

    test('checked box: done colour, text struck and muted', () {
      expect(_runs('- [x] done'), [
        ('- ', _s.bullet),
        ('[x] ', _s.done),
        ('done', _s.checked),
      ]);
      expect(_at('- [X] done', '[X]'), _s.done);
    });

    test('box without trailing space is still a box', () {
      expect(_runs('- [ ]'), [('- ', _s.bullet), ('[ ]', _s.todo)]);
      expect(_runs('- [x]'), [('- ', _s.bullet), ('[x]', _s.done)]);
    });

    test('"[x]text" and "[]" are not boxes', () {
      expect(_runs('- [x]text'), [('- ', _s.bullet), ('[x]text', _plain)]);
      expect(_runs('- [] a'), [('- ', _s.bullet), ('[] a', _plain)]);
    });

    test('empty items keep their marker styled', () {
      expect(_runs('- '), [('- ', _s.bullet)]);
      expect(_runs('-\nx'), [('-', _s.bullet), ('\nx', _plain)]);
      expect(_runs('1.'), [('1.', _s.number)]);
    });

    test('"-text" and "1.5" are not lists', () {
      expect(_runs('-text'), [('-text', _plain)]);
      expect(_runs('1.5 kg'), [('1.5 kg', _plain)]);
    });

    test('nested items: same marker colour, indent left as typed', () {
      for (final src in ['  - a', '    - a', '\t- a']) {
        final r = _runs(src);
        expect(r.first.$2, _plain, reason: src); // the indent
        expect(_at(src, '- '), _s.bullet, reason: src);
        expect(r.map((e) => e.$1).join(), src);
      }
    });

    test('numbered list keeps every number styled', () {
      const t = '1. a\n2. b\n10. c';
      expect(_covered(t, _s.number), '1. |2. |10. ');
    });

    test('list in quote and inline in item', () {
      expect(_at('> - [x] x', '- '), _s.bullet);
      expect(_at('> - [x] x', '> '), _s.marker);
      expect(
        _at('- **b**', 'b').fontWeight,
        FontWeight.w700,
      );
    });

    test('rules are not list items', () {
      for (final r in [
        '---',
        '***',
        '___',
        '* * *',
        '- - -',
        '****',
        '  ---',
      ]) {
        expect(_runs(r), [(r, _s.marker)], reason: r);
      }
      for (final r in ['--', '**', '-- -']) {
        expect(_at(r, r[0]), isNot(_s.bullet), reason: r);
      }
    });

    test('rule in a quote', () {
      expect(_runs('> ---'), [('> ---', _s.marker)]);
    });
  });

  group('code', () {
    test('one-line ```x``` is inline code, not a fence', () {
      const t = '```x```\nnext **b**';
      expect(_at(t, 'b').fontWeight, FontWeight.w700);
      expect(_at(t, 'x'), _code);
      expect(_at(t, 'next'), _plain);
    });

    test('fence closes only on the same character, long enough', () {
      // ``` is not closed by ~~~
      const a = '```\ncode\n~~~\nstill\n```\nafter **b**';
      expect(_at(a, 'still'), _code);
      expect(_at(a, 'after '), _plain);
      expect(_at(a, 'b').fontWeight, FontWeight.w700);
      // a 4-fence is not closed by ```
      const b = '````\n```\ninner **x**\n```\n````\nafter';
      expect(_at(b, 'inner'), _code);
      expect(_at(b, 'after'), _plain);
      // closer may be longer
      const c = '```\nx\n`````\nafter';
      expect(_at(c, 'after'), _plain);
    });

    test('closer must be bare; language tag allowed on the opener', () {
      const t = '```dart\na\n```trailing\nstill\n```\nafter';
      expect(_at(t, '```dart'), _markerCode);
      expect(_at(t, 'still'), _code);
      expect(_at(t, 'after'), _plain);
    });

    test('no closing fence: code to the end of the document', () {
      const t = '```\na **b**\nc';
      expect(_covered(t, _code), contains('a **b**'));
      expect(_at(t, 'c'), _code);
    });

    test('fence lines and body: marker + code, inline rules off', () {
      const t = '```\n**x**\n```';
      expect(_at(t, '**x**'), _code);
      expect(_covered(t, _markerCode), '```|```');
    });

    test('indented fence inside a list item', () {
      const t = '- item\n    ```\n    **x**\n    ```\n- next';
      expect(_at(t, '**x**'), _code);
      expect(_at(t, 'next'), _plain);
      expect(_at(t, '- next'), _s.bullet);
    });

    test('inline code: double backticks, literal backtick inside', () {
      const t = '``a`b`` x';
      expect(_at(t, 'a`b'), _code);
      expect(_at(t, 'x'), _plain);
    });

    test('inline code is per line; unmatched run is literal', () {
      const t = '`a\nb`';
      expect(_runs(t).map((e) => e.$2).toSet(), {_plain});
    });

    test('code button on several lines fences the whole lines', () {
      const src = 'one\ntwo';
      final v = toggleCode(_v(src, 1, 6)); // "ne\ntw"
      expect(v.text, '```\none\ntwo\n```');
      expect(v.text.substring(v.selection.start, v.selection.end), src);
      // and the live parser paints it as code
      expect(_at(v.text, 'one'), _code);
      expect(_at(v.text, 'two'), _code);
      // second press unwraps
      expect(toggleCode(_v(v.text, 0, v.text.length)).text, src);
    });

    test('code button on one line stays inline; on none inserts a pair', () {
      expect(toggleCode(_v('say hi', 4, 6)).text, 'say `hi`');
      expect(toggleCode(_v('ab', 1)).text, 'a``b');
      // a selection that only ends with its newline is still one line
      expect(toggleCode(_v('hi\nnext', 0, 3)).text, '`hi`\nnext');
    });

    test('fence length avoids backticks in the content', () {
      final v = toggleCode(_v('a ```b\nc', 0, 8));
      expect(v.text.startsWith('````\n'), isTrue);
    });

    test('already-inline multi-line pair is unwrapped, not fenced', () {
      expect(toggleCode(_v('`a\nb`', 0, 5)).text, 'a\nb');
    });
  });

  group('links', () {
    test('balanced parentheses in the URL', () {
      const t = '[t](https://a.com/x_(y)) after';
      expect(_covered(t, _s.marker), '[|](https://a.com/x_(y))');
      expect(_at(t, 't'), _s.link);
      expect(_at(t, 'after'), _plain);
      final l = linkAt(t, 2)!;
      expect(l.url, 'https://a.com/x_(y)');
      expect(t.substring(l.start, l.end), '[t](https://a.com/x_(y))');
    });

    test('unbalanced paren stops at the first closing one', () {
      const t = '[t](a(b) tail';
      expect(_at(t, 'tail'), _plain);
    });

    test('bold / italic / code inside link text overlay the link style', () {
      for (final (src, part, check)
          in <(String, String, bool Function(TextStyle))>[
            ('[**b** x](u)', 'b', (s) => s.fontWeight == FontWeight.w700),
            ('[_i_](u)', 'i', (s) => s.fontStyle == FontStyle.italic),
            ('[`c`](u)', 'c', (s) => s.fontFamily == 'mono'),
          ]) {
        final st = _at(src, part);
        expect(st.color, _s.link.color, reason: src);
        expect(st.decoration, TextDecoration.underline, reason: src);
        expect(check(st), isTrue, reason: src);
      }
    });

    test('title and <angle> destination', () {
      expect(linkAt('[t](https://x.com "title")', 2)!.url, 'https://x.com');
      expect(linkAt('[t](<https://x.com/a>)', 2)!.url, 'https://x.com/a');
    });

    test('images are not links', () {
      expect(linkAt('![a](https://x.com)', 3), isNull);
      expect(_runs('![a](u)'), [('![a](u)', _plain)]);
    });

    test('safeLinkUri allows http, https, mailto only', () {
      for (final ok in [
        'http://a.com',
        'https://a.com/x?y=1#z',
        'HTTPS://A.COM',
        'mailto:me@a.com',
        'https://a.com/한글',
      ]) {
        expect(safeLinkUri(ok), isNotNull, reason: ok);
      }
      for (final bad in [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'java\tscript:alert(1)',
        'data:text/html;base64,AAAA',
        'file:///etc/passwd',
        'vbscript:x',
        'ftp://a.com',
        'tel:123',
        '/relative/path',
        'a.html',
        '//a.com',
        'www.a.com',
        '',
        'https://',
        'https://a.com/a b',
        'mailto:',
        'http://a.com\nx',
      ]) {
        expect(safeLinkUri(bad), isNull, reason: '"$bad"');
      }
    });

    test('bare URL: link style, trailing punctuation left out', () {
      const t = 'see https://a.com/x, ok';
      expect(_at(t, 'https://a.com/x'), _s.link);
      expect(_at(t, ', ok'), _plain);
      expect(_covered(t, _s.link), 'https://a.com/x');
    });

    test('bare URL: closing paren only when unbalanced', () {
      expect(_covered('(https://a.com/x)', _s.link), 'https://a.com/x');
      expect(_covered('https://a.com/a_(b)', _s.link), 'https://a.com/a_(b)');
      expect(_covered('go https://a.com.', _s.link), 'https://a.com');
      expect(_covered('"https://a.com"!', _s.link), 'https://a.com');
    });

    test('bare URL keeps its underscores out of italic', () {
      const t = 'https://a.com/a_b_c';
      expect(_runs(t), [(t, _s.link)]);
    });

    test('bare URL: not glued to a word, scheme case-insensitive', () {
      expect(_covered('xhttps://a.com', _s.link), '');
      expect(_covered('HTTP://A.COM', _s.link), 'HTTP://A.COM');
      expect(_covered('www.a.com', _s.link), '');
      expect(_covered('http://', _s.link), '');
    });

    test('<autolink> keeps angle brackets as markers', () {
      const t = '<https://a.com> x';
      expect(_runs(t), [
        ('<', _s.marker),
        ('https://a.com', _s.link),
        ('>', _s.marker),
        (' x', _plain),
      ]);
      expect(linkAt(t, 5)!.url, 'https://a.com');
    });

    test('URL inside link text is not double-parsed', () {
      const t = '[https://a.com](https://b.com)';
      expect(linkAt(t, 3)!.url, 'https://b.com');
    });

    test('linkAt: strictly inside, several links, code, fence', () {
      const t = '[a](https://x.com) and [b](mailto:m@x.com)';
      expect(linkAt(t, 0), isNull); // before "["
      expect(linkAt(t, 1)!.url, 'https://x.com');
      expect(linkAt(t, 17)!.url, 'https://x.com');
      expect(linkAt(t, t.indexOf('[b') + 1)!.url, 'mailto:m@x.com');
      expect(linkAt(t, 18), isNull); // right after ")"
      expect(linkAt(t, 20), isNull);
      expect(linkAt('`[a](https://x.com)`', 4), isNull);
      expect(linkAt('```\n[a](https://x.com)\n```', 8), isNull);
      expect(linkAt('x\n[a](https://x.com)', 5)!.url, 'https://x.com');
      expect(linkAt('abc', 99), isNull);
    });
  });

  group('link toggle agrees with the parser', () {
    test('unlinks a URL with parentheses completely', () {
      final v = toggleLink(_v('[t](https://a.com/x_(y)) z', 1));
      expect(v.text, 't z');
      expect(v.text.substring(v.selection.start, v.selection.end), 't');
    });

    test('bare and <angle> URLs become real links, nothing mangled', () {
      var v = toggleLink(_v('go https://a.com/p now', 10));
      expect(v.text, 'go [https://a.com/p](https://a.com/p) now');
      expect(linkAt(v.text, 5)!.url, 'https://a.com/p');
      v = toggleLink(_v('<https://a.com>', 5));
      expect(v.text, '[https://a.com](https://a.com)');
    });

    test('plain text and fenced text still wrap', () {
      expect(toggleLink(_v('see docs', 4, 8)).text, 'see [docs]()');
      // inside a fence there are no links: the toggle just inserts a pair
      final v = toggleLink(_v('```\nhttps://a.com\n```', 8));
      expect(v.text, contains('[]()'));
      expect(v.text, isNot(contains('](https')));
    });
  });

  group('inline rules', () {
    test('strikethrough', () {
      const t = 'a ~~b~~ c';
      expect(_runs(t), [
        ('a ', _plain),
        ('~~', _s.marker),
        ('b', _s.strike),
        ('~~', _s.marker),
        (' c', _plain),
      ]);
    });

    test('strikethrough needs non-space edges and a closer', () {
      expect(_runs('~~ b~~'), [('~~ b~~', _plain)]);
      expect(_runs('~~b ~~'), [('~~b ~~', _plain)]);
      expect(_runs('~~open'), [('~~open', _plain)]);
    });

    test('strikethrough nests with bold and keeps a link underline', () {
      final s = _at('~~**b**~~', 'b');
      expect(s.fontWeight, FontWeight.w700);
      expect(s.decoration, TextDecoration.lineThrough);
      final l = _at('[~~x~~](u)', 'x');
      expect(l.color, _s.link.color);
      expect(
        l.decoration!.contains(TextDecoration.underline) &&
            l.decoration!.contains(TextDecoration.lineThrough),
        isTrue,
      );
    });

    test('~~~ at line start is a fence, not a strike', () {
      expect(_at('~~~\nx\n~~~', 'x'), _code);
    });

    test('strike toggle: wrap, unwrap, round trip', () {
      final on = toggleInline(_v('hi', 0, 2), '~~');
      expect(on.text, '~~hi~~');
      expect(toggleInline(on, '~~').text, 'hi');
    });

    test('***x*** is bold and italic together', () {
      final s = _at('***x***', 'x');
      expect(s.fontWeight, FontWeight.w700);
      expect(s.fontStyle, FontStyle.italic);
      expect(_covered('***x***', _s.marker), '***|***');
    });

    test('__x__ is bold, _x_ italic', () {
      expect(_at('__x__', 'x').fontWeight, FontWeight.w700);
      expect(_at('_x_', 'x').fontStyle, FontStyle.italic);
      expect(_at('snake_case_name', 'case').fontStyle, isNot(FontStyle.italic));
    });

    test('escaped markers do not start styles', () {
      expect(_runs(r'\*a\*'), [(r'\*a\*', _plain)]);
      expect(_at(r'\**a*', 'a').fontStyle, FontStyle.italic);
      expect(_runs(r'\~~a~~'), [(r'\~~a~~', _plain)]);
      expect(_runs(r'\[a](b)'), [(r'\[a](b)', _plain)]);
      expect(_runs(r'\`a`'), [(r'\`a`', _plain)]);
      expect(_runs(r'\\*a*').length, greaterThan(1)); // escaped backslash
    });

    test('quote: every line and nested markers', () {
      const t = '> a\n> > b\n>c';
      expect(_covered(t, _s.marker), '> |> > |>');
      expect(_covered(t, _s.quote), 'a|b|c');
    });
  });

  group('numbered list toggle', () {
    test('numbers each selected line, second press removes', () {
      const src = 'a\nb\nc';
      final on = toggleOrdered(_v(src, 0, src.length));
      expect(on.text, '1. a\n2. b\n3. c');
      expect(toggleOrdered(on).text, src);
    });

    test('converts bullets and checklists; one line', () {
      expect(toggleOrdered(_v('- x', 3)).text, '1. x');
      expect(toggleOrdered(_v('x', 0)).text, '1. x');
      expect(toggleBullet(_v('1. x', 4)).text, '- x');
    });
  });

  group('Enter continues the list', () {
    test('bullets keep their own marker', () {
      expect(_shown(_enter('- a|')), '- a\n- |');
      expect(_shown(_enter('* a|')), '* a\n* |');
      expect(_shown(_enter('+ a|')), '+ a\n+ |');
    });

    test('numbers count up and keep the delimiter', () {
      expect(_shown(_enter('1. a|')), '1. a\n2. |');
      expect(_shown(_enter('9. a|')), '9. a\n10. |');
      expect(_shown(_enter('3) a|')), '3) a\n4) |');
    });

    test('checklist continues unchecked', () {
      expect(_shown(_enter('- [ ] a|')), '- [ ] a\n- [ ] |');
      expect(_shown(_enter('- [x] a|')), '- [x] a\n- [ ] |');
    });

    test('quote, nested quote and quoted list', () {
      expect(_shown(_enter('> a|')), '> a\n> |');
      expect(_shown(_enter('> > a|')), '> > a\n> > |');
      expect(_shown(_enter('> - a|')), '> - a\n> - |');
    });

    test('indentation is kept', () {
      expect(_shown(_enter('  - a|')), '  - a\n  - |');
      expect(_shown(_enter('    1. a|')), '    1. a\n    2. |');
      expect(_shown(_enter('\t- a|')), '\t- a\n\t- |');
    });

    test('empty item ends the list: prefix removed, no new line', () {
      expect(_shown(_enter('- a\n- |')), '- a\n|');
      expect(_shown(_enter('1. a\n2. |')), '1. a\n|');
      expect(_shown(_enter('- [ ] |')), '|');
      expect(_shown(_enter('> a\n> |')), '> a\n|');
      expect(_shown(_enter('  - a\n  - |')), '  - a\n|');
      expect(_shown(_enter('- [x] |')), '|');
      expect(_shown(_enter('- [ ]|')), '|');
      expect(_shown(_enter('- [x]text|')), '- [x]text\n- |');
      expect(_shown(_enter('- |\nafter')), '|\nafter');
    });

    test('caret mid-line splits the item', () {
      expect(_shown(_enter('- ab|cd')), '- ab\n- |cd');
      expect(_shown(_enter('1. ab|cd\n2. x')), '1. ab\n2. |cd\n2. x');
    });

    test('plain line, caret before the marker text, rule: plain newline', () {
      expect(_shown(_enter('hello|')), 'hello\n|');
      expect(_shown(_enter('|- a')), '\n|- a');
      expect(_shown(_enter('-| a')), '-\n| a');
      expect(_shown(_enter('- - -|')), '- - -\n|');
      expect(_shown(_enter('---|')), '---\n|');
      expect(_shown(_enter('1.5 kg|')), '1.5 kg\n|');
      expect(_shown(_enter('a|')), 'a\n|');
    });

    test('not inside a code fence, but works after it', () {
      expect(_shown(_enter('```\n- a|\n```')), '```\n- a\n|\n```');
      expect(_shown(_enter('```\n- a\n```\n- b|')), '```\n- a\n```\n- b\n- |');
      expect(_shown(_enter('```\n- |')), '```\n- \n|');
      expect(_shown(_enter('```x```\n- a|')), '```x```\n- a\n- |');
    });

    test('never while composing (old or new value)', () {
      const text = '- 안녕';
      final neu = TextEditingValue(
        text: '$text\n',
        selection: const TextSelection.collapsed(offset: 5),
      );
      final plain = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(continueList(plain, neu).text, '- 안녕\n- ');
      final oldComposing = plain.copyWith(
        composing: const TextRange(start: 2, end: 4),
      );
      expect(continueList(oldComposing, neu), neu);
      final newComposing = neu.copyWith(
        composing: const TextRange(start: 2, end: 4),
      );
      expect(continueList(plain, newComposing), newComposing);
    });

    test('never when a selection is replaced by the newline', () {
      const old = TextEditingValue(
        text: '- ab',
        selection: TextSelection(baseOffset: 2, extentOffset: 4),
      );
      const neu = TextEditingValue(
        text: '- \n',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(continueList(old, neu), neu);
    });

    test(
      'only a single typed newline: paste, delete, other chars untouched',
      () {
        const old = TextEditingValue(
          text: '- a',
          selection: TextSelection.collapsed(offset: 3),
        );
        for (final t in ['- a\n\n', '- ab', '- ', '- a\nb', '- a\r\n']) {
          final neu = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
          expect(continueList(old, neu), neu, reason: t);
        }
        // newline typed somewhere other than at the old caret
        const moved = TextEditingValue(
          text: '\n- a',
          selection: TextSelection.collapsed(offset: 1),
        );
        expect(continueList(old, moved), moved);
      },
    );

    test('invalid selections are left alone', () {
      const neu = TextEditingValue(
        text: '- a\n',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(continueList(const TextEditingValue(text: '- a'), neu), neu);
    });

    test('formatter delegates to continueList', () {
      const f = ListContinuationFormatter();
      final old = TextEditingValue(
        text: '- a',
        selection: const TextSelection.collapsed(offset: 3),
      );
      final neu = TextEditingValue(
        text: '- a\n',
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(f.formatEditUpdate(old, neu).text, '- a\n- ');
    });
  });

  test('perf: 10k chars with every new rule parse in well under a frame', () {
    const line =
        '# 제목\n~~취소~~ **굵게** [링크](https://a.com/x_(y)) https://b.com/c.\n'
        '- [x] 완료 `code`\n1. 번호\n> 인용\n---\n```\ncode\n```\n';
    final text = List.filled(
      10000 ~/ line.length + 1,
      line,
    ).join().substring(0, 10000);
    parseLiveRuns(text, _s); // warm up
    final sw = Stopwatch()..start();
    const n = 20;
    for (var i = 0; i < n; i++) {
      parseLiveRuns(text, _s);
    }
    final ms = sw.elapsedMicroseconds / n / 1000;
    // ignore: avoid_print
    print('10k chars, all rules: ${ms.toStringAsFixed(2)} ms per parse');
    expect(ms, lessThan(16));
  });
}
