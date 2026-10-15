import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';

/// Research 024 stages 2 and 3, pure part: fenced block ranges, block styling
/// and the link edit functions.
const _plainCode = TextStyle(fontFamily: 'm', fontSize: 14);
const _styles = LiveStyles(
  code: TextStyle(
    fontFamily: 'm',
    fontSize: 14,
    backgroundColor: Color(0x11000000),
  ),
  fence: _plainCode,
);

TextEditingValue _v(String text, [int? a, int? b]) => TextEditingValue(
  text: text,
  selection: a == null
      ? const TextSelection.collapsed(offset: -1)
      : TextSelection(baseOffset: a, extentOffset: b ?? a),
);

void main() {
  group('fenceBlocks', () {
    test('closed block: ranges, language, body', () {
      const t = 'intro\n```dart\nfinal a = 1;\n\nb();\n```\nafter';
      final f = fenceBlocks(t);
      expect(f, hasLength(1));
      final b = f.single;
      expect(b.lang, 'dart');
      expect(t.substring(b.start, b.openEnd), '```dart');
      expect(t.substring(b.closeStart, b.end), '```');
      expect(t.substring(b.start, b.end), '```dart\nfinal a = 1;\n\nb();\n```');
      expect(fenceBody(t, b), 'final a = 1;\n\nb();');
    });

    test('no language, tildes, extra info words', () {
      expect(fenceBlocks('```\na\n```').single.lang, '');
      expect(fenceBlocks('~~~sh\nls\n~~~').single.lang, 'sh');
      expect(fenceBlocks('``` js  title="x"\n1\n```').single.lang, 'js');
      expect(fenceBlocks('  ```py\nx\n  ```').single.lang, 'py');
    });

    test('unclosed block runs to the end of the text', () {
      const t = 'a\n```\ncode\nmore';
      final b = fenceBlocks(t).single;
      expect(b.closeStart, -1);
      expect(b.end, t.length);
      expect(fenceBody(t, b), 'code\nmore');
      // a trailing newline stays part of the body
      const t2 = '```\nx\n';
      expect(fenceBody(t2, fenceBlocks(t2).single), 'x\n');
    });

    test('empty blocks have an empty body', () {
      const t = '```\n```';
      expect(fenceBody(t, fenceBlocks(t).single), '');
      const u = '```';
      final b = fenceBlocks(u).single;
      expect(b.end, 3);
      expect(fenceBody(u, b), '');
    });

    test('several blocks, one-line ```x``` is inline code', () {
      const t = '```a\n1\n```\n\n~~~b\n2\n~~~\n```x``` inline';
      final f = fenceBlocks(t);
      expect([for (final b in f) b.lang], ['a', 'b']);
      expect(f[0].end < f[1].start, isTrue);
    });

    test('a longer or other fence does not close it (CommonMark)', () {
      const t = '````\n```\nstill code\n```\n````\nafter';
      final f = fenceBlocks(t);
      expect(f, hasLength(1));
      expect(t.substring(f.single.start, f.single.end), t.substring(0, 28));
      expect(t.substring(f.single.closeStart, f.single.end), '````');
    });

    test('CRLF: the body has no carriage returns', () {
      const t = '```\r\na\r\nb\r\n```';
      expect(fenceBody(t, fenceBlocks(t).single), 'a\nb');
    });
  });

  group('block styling', () {
    const t =
        'x `inline` y\n```dart\n**not bold** [a](b)\n- [ ] no box\n```\nz';

    test('fence lines carry no background with blocks, inline code does', () {
      for (final blocks in [false, true]) {
        final runs = parseLiveRuns(t, _styles, blocks: blocks);
        String of(LiveRun r) => t.substring(r.start, r.end);
        final inline = runs.firstWhere((r) => of(r) == 'inline');
        expect(inline.style.backgroundColor, const Color(0x11000000));
        final body = runs.firstWhere((r) => of(r).contains('**not bold**'));
        expect(
          body.style.backgroundColor,
          blocks ? isNull : const Color(0x11000000),
          reason: 'blocks=$blocks',
        );
        final open = runs.firstWhere((r) => of(r) == '```dart');
        expect(
          open.style.backgroundColor,
          blocks ? isNull : const Color(0x11000000),
        );
        // text unchanged either way
        expect(runs.map(of).join(), t.substring(0, t.length));
      }
    });

    test('no inline format, link, or checkbox inside a block', () {
      final p = parseLive(t, _styles, boxes: true, blocks: true);
      expect(p.checks, isEmpty); // `- [ ]` in a fence is not an item
      final inside = p.runs.where((r) {
        final s = t.substring(r.start, r.end);
        return s.contains('not bold') || s.contains('no box');
      });
      for (final r in inside) {
        expect(r.kind, LiveKind.text);
        expect(r.style.fontWeight, isNull);
        expect(r.style.decoration, isNull);
      }
      expect(
        parseLive(t, _styles).fences.single.lang,
        'dart',
      );
    });

    test('LiveStyles.fenceStyle falls back to code', () {
      expect(const LiveStyles().fenceStyle, const LiveStyles().code);
      expect(_styles.fenceStyle, _plainCode);
      expect(const LiveStyles() == const LiveStyles(), isTrue);
      expect(_styles == const LiveStyles(), isFalse);
    });

    test('controller exposes fences for the current text', () {
      final c = LiveMarkdownController(
        text: '```a\nx\n```',
        styleOf: (_, _) => _styles,
        blocks: true,
      );
      expect(c.fences.single.lang, 'a');
      c.text = 'none';
      expect(c.fences, isEmpty);
      c.text = '```b\n';
      expect(c.fences.single.lang, 'b');
      c.dispose();
    });
  });

  group('link edit functions', () {
    test('linkTarget: link, selection, caret, several lines, code', () {
      const t = 'see [docs](https://a.co) and more';
      final inLink = linkTarget(_v(t, 8))!;
      expect(inLink.link!.url, 'https://a.co');
      expect(linkTarget(_v(t, 4))!.link, isNotNull); // at the edge: still it
      final word = linkTarget(_v(t, 25, 28))!; // "and"
      expect(word.link, isNull);
      expect(t.substring(word.start, word.end), 'and');
      final caret = linkTarget(_v(t, 0))!;
      expect((caret.start, caret.end, caret.link), (0, 0, null));
      expect(linkTarget(_v('a\nb', 0, 3)), isNull); // several parts
      expect(linkTarget(_v('```\nx\n```', 5)), isNull); // fenced code
    });

    test('setLink wraps a part, caret behind it', () {
      final r = setLink(_v('go home now', 3, 7), 3, 7, 'home', 'https://a.co');
      expect(r.text, 'go [home](https://a.co) now');
      expect(r.selection, const TextSelection.collapsed(offset: 23));
    });

    test('setLink: empty label becomes the URL, brackets and breaks go', () {
      expect(
        setLink(_v(''), 0, 0, '', 'https://a.co').text,
        '[https://a.co](https://a.co)',
      );
      expect(
        setLink(_v(''), 0, 0, 'a [b]\nc', 'https://a.co').text,
        '[a b c](https://a.co)',
      );
    });

    test('setLink encodes spaces and unbalanced parentheses', () {
      expect(
        setLink(_v(''), 0, 0, 'x', 'https://a.co/a b').text,
        '[x](https://a.co/a%20b)',
      );
      expect(
        setLink(_v(''), 0, 0, 'x', 'https://a.co/f)').text,
        '[x](https://a.co/f%29)',
      );
      // balanced stays: the live parser reads it as one link
      final r = setLink(_v(''), 0, 0, 'x', 'https://a.co/a_(b)');
      expect(r.text, '[x](https://a.co/a_(b))');
      expect(linkTarget(_v(r.text, 2))!.link!.url, 'https://a.co/a_(b)');
    });

    test(
      'setLink replaces a link, keeping a title when the URL is the same',
      () {
        const t = 'a [t](https://a.co "Title") b';
        final link = linkTarget(_v(t, 4))!.link!;
        final same = setLink(
          _v(t),
          link.start,
          link.end,
          'new',
          'https://a.co',
          link: link,
        );
        expect(same.text, 'a [new](https://a.co "Title") b');
        final other = setLink(
          _v(t),
          link.start,
          link.end,
          't',
          'https://b.co',
          link: link,
        );
        expect(other.text, 'a [t](https://b.co) b');
      },
    );

    test('setLink promotes an autolink to [text](url)', () {
      const t = 'go <https://a.co> now';
      final link = linkTarget(_v(t, 6))!.link!;
      expect(isBracketLink(t, link), isFalse);
      expect(linkLabel(t, link), 'https://a.co');
      final r = setLink(
        _v(t),
        link.start,
        link.end,
        'site',
        'https://a.co',
        link: link,
      );
      expect(r.text, 'go [site](https://a.co) now');
    });

    test('removeLink keeps the label and the caret place', () {
      const t = 'a [docs](https://a.co) b';
      final link = linkTarget(_v(t, 5))!.link!;
      final r = removeLink(_v(t, 6), link);
      expect(r.text, 'a docs b');
      expect(r.selection, const TextSelection.collapsed(offset: 5));
      expect(removeLink(_v(t, 21), link).selection.baseOffset, 6);
      // autolinks have no marker: unchanged
      const u = 'go https://a.co';
      expect(removeLink(_v(u, 6), linkTarget(_v(u, 6))!.link!).text, u);
    });
  });

  group('Code button rows', () {
    test('caret on an empty line: fenced block, caret on the middle line', () {
      final r = toggleCode(_v('', 0));
      expect(r.text, '```\n\n```');
      expect(r.selection, const TextSelection.collapsed(offset: 4));
      expect(fenceBlocks(r.text), hasLength(1));
      final m = toggleCode(_v('a\n\nb', 2));
      expect(m.text, 'a\n```\n\n```\nb');
      expect(m.selection, const TextSelection.collapsed(offset: 6));
      // whitespace only counts as empty
      expect(toggleCode(_v('x\n   ', 4)).text, 'x\n```\n\n```');
    });

    test('caret on a non-empty line: an inline pair, caret between', () {
      final r = toggleCode(_v('ab', 1));
      expect(r.text, 'a``b');
      expect(r.selection, const TextSelection.collapsed(offset: 2));
    });

    test('inside inline code the caret takes it off', () {
      expect(toggleCode(_v('x `hi` y', 4)).text, 'x hi y');
    });

    test('selection in one line: inline code, again takes it off', () {
      final on = toggleCode(_v('say hi', 4, 6));
      expect(on.text, 'say `hi`');
      expect(toggleCode(on).text, 'say hi');
    });

    test('selection across lines: fence; inside a fence: unwrap', () {
      final on = toggleCode(_v('a\nb', 0, 3));
      expect(on.text, '```\na\nb\n```');
      expect(toggleCode(_v(on.text, 4, 7)).text, 'a\nb');
    });

    test('caret on an empty line inside a fence unwraps the block', () {
      expect(toggleCode(_v('```\n\n```', 4)).text, '');
      expect(toggleCode(_v('a\n```\nx\n\ny\n```', 8)).text, 'a\nx\n\ny');
    });
  });
}
