import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';

/// Inline formats on block selections (several lines, list items, quotes,
/// fences): each line's text part is wrapped, prefixes are not, and the same
/// press again takes it off. Plus the pure button-state functions.
TextEditingValue _v(String text, [int a = 0, int? b]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: a, extentOffset: b ?? a),
);

/// Whole text selected.
TextEditingValue _all(String text) => _v(text, 0, text.length);

String _sel(TextEditingValue v) =>
    v.text.substring(v.selection.start, v.selection.end);

void main() {
  const markers = ['**', '_', '~~'];

  group('wrap each line text, never the prefix', () {
    // (name, source, expected with marker m)
    final cases = <(String, String, String Function(String))>[
      ('one line', 'hello world', (m) => '${m}hello world$m'),
      ('paragraph lines', 'one\ntwo', (m) => '${m}one$m\n${m}two$m'),
      (
        'blank line between is skipped',
        'one\n\ntwo',
        (m) => '${m}one$m\n\n${m}two$m',
      ),
      ('bullets', '- a\n- b', (m) => '- ${m}a$m\n- ${m}b$m'),
      ('star bullet', '* a\n* b', (m) => '* ${m}a$m\n* ${m}b$m'),
      ('ordered', '1. a\n2. b', (m) => '1. ${m}a$m\n2. ${m}b$m'),
      ('checklist', '- [ ] a\n- [x] b', (m) => '- [ ] ${m}a$m\n- [x] ${m}b$m'),
      ('nested indent', '- a\n  - b', (m) => '- ${m}a$m\n  - ${m}b$m'),
      ('quote', '> a\n> b', (m) => '> ${m}a$m\n> ${m}b$m'),
      ('quoted list', '> - a\n> - b', (m) => '> - ${m}a$m\n> - ${m}b$m'),
      ('heading', '# Title\nbody', (m) => '# ${m}Title$m\n${m}body$m'),
      ('indented line', '    code-ish', (m) => '    ${m}code-ish$m'),
      (
        'fence untouched',
        'a\n```\nx\n```\nb',
        (m) => '${m}a$m\n```\nx\n```\n${m}b$m',
      ),
      ('rule untouched', 'a\n---\nb', (m) => '${m}a$m\n---\n${m}b$m'),
      ('trailing space trimmed', 'a b  ', (m) => '${m}a b$m  '),
      ('CRLF', 'a\r\nb', (m) => '${m}a$m\r\n${m}b$m'),
    ];
    for (final m in markers) {
      for (final (name, src, want) in cases) {
        test('$m: $name', () {
          final on = toggleInline(_all(src), m);
          expect(on.text, want(m));
          expect(inlineState(on, m), isTrue, reason: 'state after wrap');
          // same press again: back to the source
          final off = toggleInline(on, m);
          expect(off.text, src);
          expect(inlineState(off, m), isFalse);
        });
      }
    }

    test('selection from mid line to mid line', () {
      final v = toggleInline(_v('hello world\nfoo bar', 6, 15), '**');
      expect(v.text, 'hello **world**\n**foo** bar');
      expect(_sel(v), 'world**\n**foo');
    });

    test('whole-line selection that ends with its newline', () {
      final v = toggleInline(_v('- a\nnext', 0, 4), '**');
      expect(v.text, '- **a**\nnext');
    });

    test('partly formatted: wrap the rest, never double-wrap', () {
      var v = toggleInline(_all('**a**\nb'), '**');
      expect(v.text, '**a**\n**b**');
      v = toggleInline(v, '**'); // now all bold: take it off
      expect(v.text, 'a\nb');
    });

    test('markers of the other kinds stay and nest', () {
      final v = toggleInline(_all('- **a**\n- b'), '_');
      expect(v.text, '- _**a**_\n- _b_');
      expect(inlineState(v, '_'), isTrue);
      expect(toggleInline(v, '_').text, '- **a**\n- b');
    });

    test('inside code or only a rule: nothing to wrap', () {
      final t = '```\nx\n```';
      expect(toggleInline(_all(t), '**').text, t);
      expect(toggleInline(_all('---'), '**').text, '---');
      expect(toggleInline(_all('- '), '**').text, '- ');
    });
  });

  group('caret and one word keep working', () {
    test('caret inserts a pair, again removes it', () {
      final v = toggleInline(_v('ab', 1), '**');
      expect(v.text, 'a****b');
      expect(v.selection.baseOffset, 3);
      expect(toggleInline(v, '**').text, 'ab');
    });

    test('word in the middle of a list item', () {
      final v = toggleInline(_v('- say hi now', 6, 8), '**');
      expect(v.text, '- say **hi** now');
      expect(_sel(v), 'hi');
    });

    test('caret in bold text takes the bold off', () {
      expect(toggleInline(_v('a **bc** d', 6), '**').text, 'a bc d');
    });

    test('selection spanning the markers of one pair', () {
      expect(toggleInline(_v('a **b** c', 2, 7), '**').text, 'a b c');
    });

    test('formatted words in the selection merge into one pair', () {
      final v = toggleInline(_v('**a** and **b**', 0, 15), '**');
      expect(v.text, '**a and b**');
      expect(toggleInline(v, '**').text, 'a and b');
    });
  });

  group('code', () {
    test('one line is inline code, again removes it', () {
      final on = toggleCode(_v('say hi', 4, 6));
      expect(on.text, 'say `hi`');
      expect(codeState(on), isTrue);
      expect(toggleCode(on).text, 'say hi');
    });

    test('several lines become a fenced block, again unwraps', () {
      const src = '- a\n- b';
      final on = toggleCode(_all(src));
      expect(on.text, '```\n- a\n- b\n```');
      expect(codeState(on), isTrue);
      final off = toggleCode(on);
      expect(off.text, src);
      expect(codeState(off), isFalse);
    });

    test('caret or one line inside a fence unwraps the whole block', () {
      const t = 'x\n```\none\ntwo\n```\ny';
      final v = toggleCode(_v(t, 8)); // caret in "one"
      expect(v.text, 'x\none\ntwo\ny');
      expect(toggleCode(_v(t, 6, 9)).text, 'x\none\ntwo\ny'); // the fence line
      expect(codeState(_v(t, 8)), isTrue);
    });

    test('an unclosed fence unwraps to the end', () {
      expect(toggleCode(_v('a\n```\nb\nc', 6)).text, 'a\nb\nc');
    });

    test('inline code inside bold, and state of neighbours', () {
      final v = toggleCode(_v('**a b**', 2, 5));
      expect(v.text, '**`a b`**');
      expect(inlineState(v, '**'), isTrue);
      expect(inlineState(v, '`'), isTrue);
    });
  });

  group('link', () {
    test('one selection becomes [text]() with the caret in the parens', () {
      final v = toggleLink(_v('see docs', 4, 8));
      expect(v.text, 'see [docs]()');
      expect(v.selection, const TextSelection.collapsed(offset: 11));
      expect(linkState(v), isTrue);
    });

    test('list items: each text gets its link, caret in the first', () {
      final v = toggleLink(_all('- a\n- bb'));
      expect(v.text, '- [a]()\n- [bb]()');
      expect(v.selection, const TextSelection.collapsed(offset: 6));
      // all are links now: the same press removes them, text stays selected
      final off = toggleLink(_all(v.text));
      expect(off.text, '- a\n- bb');
      expect(linkState(off), isFalse);
    });

    test('quote and paragraph lines', () {
      expect(toggleLink(_all('> a\n> b')).text, '> [a]()\n> [b]()');
      expect(toggleLink(_all('a\n\nb')).text, '[a]()\n\n[b]()');
    });

    test('part linked: link the rest, then all off', () {
      var v = toggleLink(_all('[a](u)\nb'));
      expect(v.text, '[a](u)\n[b]()');
      v = toggleLink(_all(v.text));
      expect(v.text, 'a\nb');
    });

    test('fence lines are skipped', () {
      expect(
        toggleLink(_all('a\n```\nx\n```')).text,
        '[a]()\n```\nx\n```',
      );
    });

    test('bare URL and caret behave as before', () {
      expect(
        toggleLink(_v('go https://a.com now', 8)).text,
        'go [https://a.com](https://a.com) now',
      );
      expect(toggleLink(_v('', 0)).text, '[]()');
      expect(toggleLink(_v('[t](u) z', 1)).text, 't z');
    });
  });

  group('formatState', () {
    test('reads the selection against the parser', () {
      var s = formatState(_v('a **b** _c_ ~~d~~ `e` [f](u)', 4, 5));
      expect(s.bold, isTrue);
      expect(s.italic, isFalse);
      s = formatState(_v('a **b** _c_ ~~d~~ `e` [f](u)', 9, 10));
      expect(s.italic, isTrue);
      s = formatState(_v('a **b** _c_ ~~d~~ `e` [f](u)', 14, 15));
      expect(s.strike, isTrue);
      s = formatState(_v('a **b** _c_ ~~d~~ `e` [f](u)', 19, 20));
      expect(s.code, isTrue);
      s = formatState(_v('a **b** _c_ ~~d~~ `e` [f](u)', 23, 24));
      expect(s.link, isTrue);
      expect(s.bold, isFalse);
    });

    test('plain text and all-plain blocks are off', () {
      final s = formatState(_all('a\nb'));
      expect(
        (s.bold, s.italic, s.strike, s.code, s.link),
        (
          false,
          false,
          false,
          false,
          false,
        ),
      );
    });

    test('a block is on only if every line is', () {
      expect(inlineState(_all('**a**\n**b**'), '**'), isTrue);
      expect(inlineState(_all('**a**\nb'), '**'), isFalse);
      expect(inlineState(_all('- **a**\n- **b**'), '**'), isTrue);
    });
  });
}
