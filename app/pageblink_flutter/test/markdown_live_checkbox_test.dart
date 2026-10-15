import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';

/// Research 024 stage 0/1: checklist prefixes reported by the parser, the
/// transparent marker spans, and the pure check toggles.
const _base = TextStyle(fontSize: 16);
const _styles = LiveStyles();

String _joined(TextSpan s) =>
    s.children!.map((c) => (c as TextSpan).text).join();

TextEditingValue _v(String text, [int? a, int? b]) => TextEditingValue(
  text: text,
  selection: a == null
      ? const TextSelection.collapsed(offset: -1)
      : TextSelection(baseOffset: a, extentOffset: b ?? a),
);

List<String> _markers(String text) => [
  for (final m in checkMarkers(text)) text.substring(m.start, m.end),
];

void main() {
  group('checkMarkers (parser)', () {
    test('prefix range: bullet through the space after the box', () {
      expect(_markers('- [ ] todo'), ['- [ ] ']);
      expect(_markers('- [x] done\n- [X] caps'), ['- [x] ', '- [X] ']);
      final m = checkMarkers('- [x] a').single;
      expect((m.start, m.boxStart, m.end, m.done), (0, 2, 6, true));
    });

    test('indent, other bullets, numbers and quotes', () {
      expect(_markers('  - [ ] a'), ['- [ ] ']);
      expect(checkMarkers('  - [ ] a').single.start, 2);
      expect(_markers('* [ ] a\n+ [x] b\n1. [ ] c'), [
        '* [ ] ',
        '+ [x] ',
        '1. [ ] ',
      ]);
      expect(_markers('> - [x] q'), ['- [x] ']);
      expect(_markers('\t- [ ] tab'), ['- [ ] ']);
    });

    test('empty item and a box without a following space', () {
      expect(_markers('- [ ]'), ['- [ ]']);
      expect(_markers('- [x]text'), isEmpty); // not a box
      expect(_markers('- []'), isEmpty);
      expect(_markers('[ ] bare'), isEmpty); // no list marker
    });

    test('plain lists and fenced code have none', () {
      expect(_markers('- a\n1. b\n> c'), isEmpty);
      expect(_markers('```\n- [ ] in code\n```\n- [ ] out'), ['- [ ] ']);
      expect(_markers('```\n- [ ] unclosed'), isEmpty);
    });

    test(
      'marker runs only with boxes; without them the pieces are as before',
      () {
        const t = '- [ ] a\n- [x] b';
        expect(
          parseLiveRuns(t, _styles).any((r) => r.kind == LiveKind.checkMarker),
          isFalse,
        );
        String piece(LiveRun r) => t.substring(r.start, r.end);
        // the muted bullet / box pieces (existing rules tests pin the styles)
        final plain = parseLiveRuns(t, _styles).map(piece).toList();
        expect(plain.first, '- ');
        expect(plain[1], '[ ] ');
        expect(plain.join(), t);

        final runs = parseLiveRuns(t, _styles, boxes: true);
        final marked = runs.where((r) => r.kind == LiveKind.checkMarker);
        expect(marked.map(piece), ['- [ ] ', '- [x] ']);
        // hidden by colour only: not folded, not resized
        for (final r in marked) {
          expect(r.style.color, const Color(0x00000000));
          expect(r.style.fontSize, isNull);
          expect(r.style.letterSpacing, isNull);
        }
        // the done item keeps the struck, muted text style
        final done = runs.firstWhere((r) => piece(r) == 'b');
        expect(done.style.decoration, TextDecoration.lineThrough);
      },
    );

    test('runs stay contiguous and the checks agree with the paint', () {
      const t = '# h\n- [ ] one\n  - [x] two `c`\n> - [ ] q\n```\n- [ ] x\n```';
      for (final boxes in [false, true]) {
        final p = parseLive(t, _styles, boxes: boxes);
        var pos = 0;
        for (final r in p.runs) {
          expect(r.start, pos);
          expect(r.end, greaterThan(r.start));
          pos = r.end;
        }
        expect(pos, t.length);
        expect(p.checks.length, 3);
        if (boxes) {
          final kinds = p.runs
              .where((r) => r.kind == LiveKind.checkMarker)
              .map((r) => (r.start, r.end))
              .toList();
          expect(kinds, [for (final m in p.checks) (m.start, m.end)]);
        }
      }
    });
  });

  group('span text == input (boxes, composing)', () {
    final samples = <String>[
      '',
      '- [ ] todo',
      '- [x] done\n  - [X] nested\n> - [ ] quoted',
      '- [ ]\n- [x]\n1. [ ] n',
      '한글 - [ ] 체크 `코드`\n- [x] 완료 **굵게** 😀',
      '```\n- [ ] code\n```\n- [ ] after',
      '- [ ] 안녕 [링크](http://a.b) _x_',
    ];
    for (final s in samples) {
      test(s.replaceAll('\n', r'\n'), () {
        final runs = parseLiveRuns(s, _styles, boxes: true);
        expect(_joined(runsToSpan(s, runs, _base)), s);
        for (var a = 0; a < s.length; a++) {
          for (var b = a + 1; b <= s.length; b += 2) {
            final span = runsToSpan(
              s,
              runs,
              _base,
              composing: TextRange(start: a, end: b),
              highlight: TextRange(start: b ~/ 2, end: b),
            );
            expect(_joined(span), s);
          }
        }
      });
    }

    test('no span carries a recognizer (RenderEditable semantics rule)', () {
      const t = '- [ ] a\n- [x] b';
      final span = runsToSpan(t, parseLiveRuns(t, _styles, boxes: true), _base);
      for (final k in span.children!.cast<TextSpan>()) {
        expect(k.recognizer, isNull);
      }
    });

    test('a composing cut through a marker keeps the kind of both halves', () {
      const t = '- [ ] a';
      final runs = parseLiveRuns(t, _styles, boxes: true);
      expect(runs.where((r) => r.kind == LiveKind.checkMarker).length, 1);
      final cut = runsToSpan(
        t,
        runs,
        _base,
        composing: const TextRange(start: 1, end: 4),
      );
      expect(_joined(cut), t);
    });
  });

  group('controller', () {
    testWidgets('boxes / live switch the marker colour, text is the same', (
      t,
    ) async {
      final c = LiveMarkdownController(
        text: '- [ ] a\n- [x] b',
        styleOf: (_, _) => _styles,
      );
      addTearDown(c.dispose);
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      List<TextSpan> kids() =>
          c
              .buildTextSpan(context: ctx, withComposing: false)
              .children
              ?.cast<TextSpan>() ??
          const [];
      bool hidden(TextSpan k) => k.style?.color == const Color(0x00000000);

      expect(kids().any(hidden), isFalse); // default: the muted pieces
      c.boxes = true;
      final shown = kids();
      expect(shown.where(hidden).map((k) => k.text), ['- [ ] ', '- [x] ']);
      expect(shown.map((k) => k.text).join(), c.text);
      c.live = false; // source mode: the stock plain controller
      expect(kids(), isEmpty);
      expect(
        c.buildTextSpan(context: ctx, withComposing: false).toPlainText(),
        c.text,
      );
      c.live = true;
      expect(kids().where(hidden).length, 2);
    });

    test('checks follow the text (also without a build)', () {
      final c = LiveMarkdownController(
        text: '- [ ] a',
        styleOf: (_, _) => _styles,
      );
      addTearDown(c.dispose);
      expect(c.checks.map((m) => m.done), [false]);
      c.text = '- [x] a\n- [ ] b';
      expect(c.checks.map((m) => m.done), [true, false]);
    });
  });

  group('checkMarkerAt', () {
    test('inside, at both ends, outside', () {
      final items = checkMarkers('x\n- [ ] a');
      expect(checkMarkerAt(items, 2)?.start, 2);
      expect(checkMarkerAt(items, 5)?.start, 2);
      expect(checkMarkerAt(items, 8), isNotNull); // end of the prefix
      expect(checkMarkerAt(items, 9), isNull);
      expect(checkMarkerAt(items, 0), isNull);
    });
  });

  group('checkState / toggleDone / toggleCheckAt', () {
    test('state: none, some, all', () {
      const t = '- [ ] a\n- [x] b\nplain\n- [x] c';
      expect(checkState(_v(t, 0, 0)), (any: true, allDone: false));
      expect(checkState(_v(t, 8, 8)), (any: true, allDone: true)); // line b
      expect(checkState(_v(t, 0, 15)), (any: true, allDone: false));
      expect(checkState(_v(t, 16, 21)), (any: false, allDone: false)); // plain
      expect(checkState(_v(t, 16, t.length)), (any: true, allDone: true));
      expect(checkState(_v('a\nb', 0, 3)), (any: false, allDone: false));
      expect(checkState(_v(t)), (any: true, allDone: true)); // no selection
    });

    test('a selection ending right after a newline spares the next line', () {
      const t = '- [x] a\n- [ ] b';
      expect(checkState(_v(t, 0, 8)), (any: true, allDone: true));
    });

    test('state ignores fenced code', () {
      const t = '```\n- [ ] a\n```';
      expect(checkState(_v(t, 0, t.length)).any, isFalse);
    });

    test('toggleDone: all done -> all cleared, else all done', () {
      const t = '- [ ] a\n- [x] b\nplain\n- [ ] c';
      var r = toggleDone(_v(t, 0, t.length));
      expect(r.text, '- [x] a\n- [x] b\nplain\n- [x] c');
      expect(r.selection, const TextSelection(baseOffset: 0, extentOffset: 29));
      r = toggleDone(r);
      expect(r.text, '- [ ] a\n- [ ] b\nplain\n- [ ] c');
    });

    test('toggleDone on a caret acts on its line only; non-check: no-op', () {
      const t = '- [ ] a\n- [ ] b\nplain';
      var r = toggleDone(_v(t, 10));
      expect(r.text, '- [ ] a\n- [x] b\nplain');
      expect(r.selection, const TextSelection.collapsed(offset: 10));
      expect(toggleDone(_v(t, 18)).text, t);
    });

    test('toggleDone turns [X] off and leaves other lines alone', () {
      const t = '- [X] a\n- [ ] b';
      expect(toggleDone(_v(t, 0, 3)).text, '- [ ] a\n- [ ] b');
    });

    test('toggleCheckAt flips one box, keeps selection and length', () {
      const t = '- [ ] a\n  - [x] b\n- [X] c';
      final v = _v(t, 3, 12);
      var r = toggleCheckAt(v, 0);
      expect(r.text, '- [x] a\n  - [x] b\n- [X] c');
      expect(r.selection, v.selection);
      r = toggleCheckAt(r, 10); // indented item starts at 10
      expect(r.text, '- [x] a\n  - [ ] b\n- [X] c');
      r = toggleCheckAt(r, 18);
      expect(r.text, '- [x] a\n  - [ ] b\n- [ ] c');
      expect(toggleCheckAt(r, 3).text, r.text); // not a marker start
      expect(r.text.length, t.length);
    });
  });
}
