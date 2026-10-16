import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/features/notes/cite_layer.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/open_item/open_item_view.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/viewer/cite_bar.dart';
import 'package:pageblink_flutter/features/viewer/citation_sheet.dart';
import 'package:pageblink_flutter/features/viewer/pdf_cite.dart';
import 'package:pdfrx/pdfrx.dart' show PdfRect;

/// Cited-passage display (research 027, U2): quote matching, the line block
/// and its merge, the scroll target, the bar, the editor wiring (open, scroll,
/// pulse, step, dismiss, typing), the PDF line rectangles, the neutral
/// selection color and the sheet's theme colors.

Document _note(String body) => Document(
  id: 7,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Cited',
  body: body,
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

String _line(int i) => 'line ${i.toString().padLeft(2, '0')} aaa';
String _lines(int n) => [for (var i = 1; i <= n; i++) _line(i)].join('\n');

Future<LiveMarkdownController> _pump(
  WidgetTester t, {
  required String body,
  String? highlight,
  int? number,
  int? start,
  List<CiteRef> related = const [],
  bool reduced = false,
  Brightness brightness = Brightness.light,
  double height = 900,
}) async {
  t.view.physicalSize = Size(1200, height);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(
        brightness,
      ).copyWith(platform: TargetPlatform.macOS),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Scaffold(
        body: NoteEditorView(
          note: _note(body),
          embedded: true,
          highlight: highlight,
          highlightNumber: number,
          highlightStart: start,
          relatedCites: related,
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pump();
  return t.widget<EditableText>(find.byType(EditableText).last).controller
      as LiveMarkdownController;
}

final _back = find.byKey(const ValueKey('cite-back'));
final _barFinder = find.byKey(const ValueKey('cite-bar'));

int _argb(Color c) => c.toARGB32();

/// What the cite layer drew in its last paint: (rect, color) per RRect.
List<(Rect, Color)> _drawn(WidgetTester t) {
  final out = <(Rect, Color)>[];
  final m = paints
    ..something((name, args) {
      if (name == #drawRRect) {
        out.add(((args[0] as RRect).outerRect, (args[1] as Paint).color));
      }
      return false;
    });
  (m as Matcher).matches(t.renderObject(_back), {});
  return out;
}

/// Global rect of the line boxes of `[a, b)` in the body field.
Rect _boxes(WidgetTester t, int a, int b) {
  final r = t
      .state<EditableTextState>(find.byType(EditableText).last)
      .renderEditable;
  Rect? u;
  for (final box in r.getBoxesForSelection(
    TextSelection(baseOffset: a, extentOffset: b),
  )) {
    final g = box.toRect().shift(r.localToGlobal(Offset.zero));
    u = u == null ? g : u.expandToInclude(g);
  }
  return u!;
}

ScrollableState _scroll(WidgetTester t) => t.state<ScrollableState>(
  find
      .descendant(
        of: find.byType(TextField).last,
        matching: find.byType(Scrollable),
      )
      .first,
);

void main() {
  group('matching', () {
    const body =
        '# Trip\n- **Pack** the _bag_\n- [ ] book  tickets\n\nThe quick  brown\nfox jumps.';

    test('exact', () {
      expect(findQuote(body, 'Pack** the'), isNotNull);
      final r = findQuote(body, '- [ ] book')!;
      expect(body.substring(r.start, r.end), '- [ ] book');
    });

    test('whitespace differences', () {
      final r = findQuote(body, 'book tickets')!;
      expect(body.substring(r.start, r.end), 'book  tickets');
      final q = findQuote(body, 'The quick brown fox jumps.')!;
      expect(body.substring(q.start, q.end), 'The quick  brown\nfox jumps.');
    });

    test('markdown symbols: kept in the quote, or cut by its first words', () {
      // a chunk keeps the markers, so the quote matches exactly
      final r = findQuote(body, '**Pack** the _bag_')!;
      expect(body.substring(r.start, r.end), '**Pack** the _bag_');
      // a quote that lacks them does not match as a whole ...
      expect(findQuote(body, 'Pack the bag'), isNull);
      // ... but a long quote is found by its first 5 words when they match
      final p = findQuote(
        body,
        'The quick brown fox jumps. Then something that was edited away',
      )!;
      expect(body.substring(p.start, p.end), 'The quick  brown\nfox jumps.');
    });

    test('not found', () {
      expect(findQuote(body, 'absent passage entirely'), isNull);
      expect(findQuote(body, '   '), isNull);
      expect(findQuote('', 'x'), isNull);
    });

    test(
      'controller: quoteRange follows the text, cached by text and quote',
      () {
        final c = LiveMarkdownController(
          text: 'a\nsecond line\nz',
          styleOf: (_, base) => const LiveStyles(),
        );
        expect(c.quoteRange, isNull);
        c.quote = 'second line';
        expect(c.quoteRange, const TextRange(start: 2, end: 13));
        c.text = 'new first\nsecond line\nz';
        expect(c.quoteRange, const TextRange(start: 10, end: 21));
        c.text = 'gone';
        expect(c.quoteRange, isNull);
        c.dispose();
      },
    );
  });

  group('quoteStart', () {
    const body = 'same line\nother\nsame line\nend';

    test('locateQuote uses the offset when it still matches', () {
      // the second of two equal lines
      expect(
        locateQuote(body, 'same line', start: 16),
        const TextRange(start: 16, end: 25),
      );
      // no offset or a stale one: the first match, as findQuote
      expect(
        locateQuote(body, 'same line'),
        const TextRange(start: 0, end: 9),
      );
      expect(
        locateQuote(body, 'same line', start: 3),
        const TextRange(start: 0, end: 9),
      );
      expect(locateQuote(body, 'same line', start: 999), isNotNull);
      expect(locateQuote(body, 'absent', start: 2), isNull);
    });

    test('controller: the offset picks the line, edits fall back', () {
      final c = LiveMarkdownController(
        text: body,
        styleOf: (_, base) => const LiveStyles(),
      );
      c.setQuote('same line', start: 16);
      expect(c.quoteRange, const TextRange(start: 16, end: 25));
      c.text = 'x$body'; // the body changed: offset no longer matches
      expect(c.quoteRange, const TextRange(start: 1, end: 10));
      c.dispose();
    });

    test('citations whose lines touch are one block, others stay apart', () {
      const t = 'l1 aaa\nl2 bbb\nl3 ccc\nl4 ddd\nl5 eee\nl6 fff';
      final c = LiveMarkdownController(
        text: t,
        styleOf: (_, base) => const LiveStyles(),
      );
      // l2 with l3 (adjacent) and l3-l4 (overlapping that): one block l2..l4
      c.setQuote(
        'l2 bbb',
        also: [(quote: 'l3 ccc', start: null), (quote: 'l4 ddd', start: 21)],
      );
      expect(c.quoteRange, const TextRange(start: 7, end: 27));
      // l6 is two lines away: not joined
      c.setQuote('l2 bbb', also: [(quote: 'l6 fff', start: null)]);
      expect(c.quoteRange, const TextRange(start: 7, end: 13));
      c.dispose();
    });
  });

  group('line block geometry', () {
    test('citeLineRange widens to whole lines', () {
      const t = 'aaa\nbbb ccc ddd\neee\nfff';
      // inside one line
      expect(
        citeLineRange(t, const TextRange(start: 8, end: 11)),
        const TextRange(start: 4, end: 15),
      );
      // across lines
      expect(
        citeLineRange(t, const TextRange(start: 6, end: 17)),
        const TextRange(start: 4, end: 19),
      );
      // first and last line of the text
      expect(
        citeLineRange(t, const TextRange(start: 1, end: 2)),
        const TextRange(start: 0, end: 3),
      );
      expect(
        citeLineRange(t, const TextRange(start: 21, end: 23)),
        const TextRange(start: 20, end: 23),
      );
      // the whole text
      expect(
        citeLineRange(t, TextRange(start: 0, end: t.length)),
        TextRange(start: 0, end: t.length),
      );
      // CRLF: the line ends before the \r
      expect(
        citeLineRange('ab\r\ncd', const TextRange(start: 0, end: 1)),
        const TextRange(start: 0, end: 2),
      );
    });

    test('line boxes merge into one block over the text area', () {
      final r = citeBlockRect(
        const [
          Rect.fromLTRB(30, 100, 180, 127), // short first line
          Rect.fromLTRB(20, 127, 400, 154), // wide middle line
          Rect.fromLTRB(20, 154, 90, 181), // short last line
        ],
        left: 8,
        right: 700,
      )!;
      expect(r, const Rect.fromLTRB(8, 96, 700, 185));
      expect(citeBlockRect(const [], left: 0, right: 10), isNull);
    });

    test('scroll target: centered, top-aligned when taller, clamped', () {
      double target(double top, double h, {double max = 1000}) =>
          citeScrollTarget(
            top: top,
            height: h,
            viewport: 400,
            min: 0,
            max: max,
          );
      expect(target(600, 40), 600 - 180); // centered
      expect(target(50, 40), 0); // clamped at the top
      expect(target(950, 40, max: 700), 700); // clamped at the end
      expect(target(300, 900), 300 - 16); // taller than the view: top + air
    });
  });

  group('editor', () {
    testWidgets('only the cited line is a block; text and selection intact', (
      t,
    ) async {
      final body = _lines(12);
      final c = await _pump(
        t,
        body: body,
        highlight: 'line 04',
        number: 1,
        reduced: true,
      );
      c.selection = const TextSelection(baseOffset: 2, extentOffset: 9);
      await t.pump();
      expect(c.text, body); // the text is never touched
      expect(c.selection, const TextSelection(baseOffset: 2, extentOffset: 9));
      final drawn = _drawn(t);
      expect(drawn, hasLength(2)); // fill + rail
      final line = _boxes(
        t,
        body.indexOf('line 04'),
        body.indexOf('\nline 05'),
      );
      final origin = t.getTopLeft(_back);
      final fill = drawn.first.$1.shift(origin);
      expect(fill.top, closeTo(line.top - 4, 0.6));
      expect(fill.bottom, closeTo(line.bottom + 4, 0.6));
      expect(fill.left, lessThan(line.left)); // reaches past the text (bleed)
      expect(_argb(drawn.first.$2), _argb(Pb.light.citeFill));
      expect(_argb(drawn.last.$2), _argb(Pb.light.citeEdge));
      expect(drawn.last.$1.width, 3);
    });

    testWidgets('several lines are one block', (t) async {
      final body = _lines(12);
      await _pump(
        t,
        body: body,
        highlight: '${_line(4)}\n${_line(5)}\n${_line(6)}',
        reduced: true,
      );
      final drawn = _drawn(t);
      expect(drawn, hasLength(2)); // not one box per line
      final line = _boxes(
        t,
        body.indexOf('line 04'),
        body.indexOf('\nline 07'),
      );
      final fill = drawn.first.$1.shift(t.getTopLeft(_back));
      expect(fill.top, closeTo(line.top - 4, 0.6));
      expect(fill.bottom, closeTo(line.bottom + 4, 0.6));
    });

    testWidgets('a quote that is the whole note is one block', (t) async {
      final body = _lines(6);
      await _pump(t, body: body, highlight: body, reduced: true);
      final drawn = _drawn(t);
      expect(drawn, hasLength(2));
      final all = _boxes(t, 0, body.length);
      final fill = drawn.first.$1.shift(t.getTopLeft(_back));
      expect(fill.top, closeTo(all.top - 4, 0.6));
      expect(fill.bottom, closeTo(all.bottom + 4, 0.6));
    });

    testWidgets('pulse: 28% to 12% over 600 ms, none when reduced', (t) async {
      await _pump(t, body: _lines(6), highlight: _line(2));
      expect(
        _argb(_drawn(t).first.$2),
        _argb(Pb.light.citePulse),
      ); // first frame
      await t.pump(const Duration(milliseconds: 300));
      final mid = _drawn(t).first.$2;
      expect(mid.a, lessThan(Pb.light.citePulse.a));
      expect(mid.a, greaterThan(Pb.light.citeFill.a));
      await t.pump(const Duration(milliseconds: 400));
      expect(_argb(_drawn(t).first.$2), _argb(Pb.light.citeFill));
    });

    testWidgets('disableAnimations: resting fill from the first frame', (
      t,
    ) async {
      await _pump(t, body: _lines(6), highlight: _line(2), reduced: true);
      expect(_argb(_drawn(t).first.$2), _argb(Pb.light.citeFill));
    });

    testWidgets('dark theme uses the dark tokens', (t) async {
      await _pump(
        t,
        body: _lines(6),
        highlight: _line(2),
        reduced: true,
        brightness: Brightness.dark,
      );
      final d = _drawn(t);
      expect(_argb(d.first.$2), _argb(Pb.dark.citeFill));
      expect(_argb(d.last.$2), _argb(Pb.dark.citeEdge));
    });

    testWidgets('source mode paints the block too', (t) async {
      final c = await _pump(
        t,
        body: _lines(8),
        highlight: _line(3),
        reduced: true,
      );
      c.live = false;
      await t.pump();
      expect(_drawn(t), hasLength(2));
      expect(c.text, _lines(8));
    });

    testWidgets('opens scrolled to the cited block, centered', (t) async {
      final body = _lines(80);
      await _pump(
        t,
        body: body,
        highlight: _line(60),
        number: 1,
        reduced: true,
        height: 700,
      );
      await t.pump();
      expect(_scroll(t).position.pixels, greaterThan(0));
      final line = _boxes(
        t,
        body.indexOf('line 60'),
        body.indexOf('\nline 61'),
      );
      final view = t.getRect(find.byType(EditableText).last);
      expect(view.top, lessThan(line.top));
      expect(line.bottom, lessThan(view.bottom));
      expect(line.center.dy, closeTo(view.center.dy, 14));
    });

    testWidgets('a block taller than the field is top-aligned', (t) async {
      final body = _lines(80);
      await _pump(t, body: body, highlight: body, reduced: true, height: 700);
      await t.pump();
      // whole note: already at the top, nothing to scroll
      expect(_scroll(t).position.pixels, 0);
    });

    testWidgets('quoteStart paints the second of two equal lines', (t) async {
      final body = [
        for (var i = 1; i <= 6; i++) i == 2 || i == 5 ? 'same line' : _line(i),
      ].join('\n');
      final second = body.lastIndexOf('same line');
      await _pump(
        t,
        body: body,
        highlight: 'same line',
        start: second,
        reduced: true,
      );
      final drawn = _drawn(t);
      expect(drawn, hasLength(2));
      final line = _boxes(t, second, second + 9);
      final fill = drawn.first.$1.shift(t.getTopLeft(_back));
      expect(fill.top, closeTo(line.top - 4, 0.6));
    });

    testWidgets('citations on touching lines draw one block', (t) async {
      final body = _lines(10);
      await _pump(
        t,
        body: body,
        highlight: _line(4),
        number: 1,
        related: [
          (number: 1, quote: _line(4), start: null),
          (number: 2, quote: _line(5), start: null),
          (number: 3, quote: _line(9), start: null),
        ],
        reduced: true,
      );
      final drawn = _drawn(t);
      expect(drawn, hasLength(2)); // one block (fill + rail)
      final lines = _boxes(
        t,
        body.indexOf('line 04'),
        body.indexOf('\nline 06'),
      );
      final fill = drawn.first.$1.shift(t.getTopLeft(_back));
      expect(fill.top, closeTo(lines.top - 4, 0.6));
      expect(fill.bottom, closeTo(lines.bottom + 4, 0.6));
    });

    testWidgets('an old ~900 char chunk as the quote is still one block', (
      t,
    ) async {
      final body = _lines(80);
      final chunk = body.substring(0, 900);
      await _pump(t, body: body, highlight: chunk, number: 1, reduced: true);
      await t.pump();
      expect(_drawn(t), hasLength(2));
    });

    testWidgets('bar: number, label, no steps for a single citation', (
      t,
    ) async {
      await _pump(
        t,
        body: _lines(6),
        highlight: _line(2),
        number: 3,
        reduced: true,
      );
      expect(_barFinder, findsOneWidget);
      expect(find.byType(CiteBar), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('cite-number'))).data,
        '3',
      );
      expect(find.text('Evidence for the answer'), findsOneWidget);
      expect(find.byKey(const ValueKey('cite-next')), findsNothing);
    });

    testWidgets('quote not found: the bar carries the quote, no block', (
      t,
    ) async {
      await _pump(
        t,
        body: _lines(3),
        highlight: 'something the note never said',
        number: 1,
        reduced: true,
      );
      expect(_drawn(t), isEmpty);
      expect(
        find.textContaining('something the note never said'),
        findsOneWidget,
      );
    });

    testWidgets('steps between the citations of the note in place', (t) async {
      final body = _lines(80);
      final c = await _pump(
        t,
        body: body,
        highlight: _line(3),
        number: 1,
        related: [
          (number: 2, quote: _line(70), start: null),
          (number: 1, quote: _line(3), start: null),
        ],
        reduced: true,
        height: 700,
      );
      await t.pump();
      expect(c.quote, _line(3));
      expect(
        t.widget<Text>(find.byKey(const ValueKey('cite-position'))).data,
        '1/2',
      );
      // first: previous disabled
      expect(
        t
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const ValueKey('cite-previous')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      final before = _scroll(t).position.pixels;
      await t.tap(find.byKey(const ValueKey('cite-next')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(c.quote, _line(70));
      expect(
        t.widget<Text>(find.byKey(const ValueKey('cite-number'))).data,
        '2',
      );
      expect(_scroll(t).position.pixels, greaterThan(before));
      expect(c.text, body);
      await t.tap(find.byKey(const ValueKey('cite-previous')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(c.quote, _line(3));
    });

    testWidgets('the close button hides block and bar', (t) async {
      final c = await _pump(
        t,
        body: _lines(8),
        highlight: _line(3),
        number: 1,
        reduced: true,
      );
      await t.tap(find.byKey(const ValueKey('cite-dismiss')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_barFinder, findsNothing);
      expect(c.quote, isNull);
      expect(
        t
            .widget<AnimatedOpacity>(
              find.ancestor(of: _back, matching: find.byType(AnimatedOpacity)),
            )
            .opacity,
        0,
      );
    });

    testWidgets('typing turns the highlight off; the caret does not', (
      t,
    ) async {
      final c = await _pump(
        t,
        body: _lines(8),
        highlight: _line(3),
        number: 1,
        reduced: true,
      );
      c.selection = const TextSelection.collapsed(offset: 4);
      await t.pump();
      expect(_barFinder, findsOneWidget); // moving the caret keeps it
      await t.enterText(find.byType(EditableText).last, 'edited');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_barFinder, findsNothing);
      expect(c.text, 'edited');
      expect(c.quote, isNull);
    });

    test('relatedNoteCites keeps this note only', () {
      Citation cite(int i, int doc, String kind) => Citation(
        index: i,
        documentId: doc,
        documentTitle: 't',
        kind: kind,
        page: 1,
        quote: 'q$i',
        quoteStart: i * 10,
      );
      final all = [
        cite(1, 7, 'note'),
        cite(2, 8, 'note'),
        cite(3, 7, 'note'),
        cite(4, 7, 'pdf'),
      ];
      expect(relatedNoteCites(all.first, all), [
        (number: 1, quote: 'q1', start: 10),
        (number: 3, quote: 'q3', start: 30),
      ]);
    });
  });

  group('theme', () {
    test('selection is a neutral blue-grey, not the violet accent', () {
      for (final b in Brightness.values) {
        final theme = buildPbTheme(b);
        final pb = b == Brightness.light ? Pb.light : Pb.dark;
        expect(theme.textSelectionTheme.selectionColor, pb.selection);
        final s = pb.selection;
        // grey with a blue lean: b >= r, r and g close, low saturation
        expect(s.b, greaterThanOrEqualTo(s.r));
        expect((s.r - s.g).abs(), lessThan(0.1));
        expect(
          math.max(s.r, math.max(s.g, s.b)) - math.min(s.r, math.min(s.g, s.b)),
          lessThan(0.3),
        );
        expect(s.a, inInclusiveRange(0.18, 0.30));
      }
    });

    testWidgets('a TextField paints that selection color', (t) async {
      for (final b in Brightness.values) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildPbTheme(b),
            home: const Scaffold(body: TextField()),
          ),
        );
        final pb = b == Brightness.light ? Pb.light : Pb.dark;
        await t.tap(find.byType(TextField)); // the color is set while focused
        await t.pump();
        expect(
          t.widget<EditableText>(find.byType(EditableText)).selectionColor,
          pb.selection,
        );
      }
    });

    // WCAG relative luminance / contrast, on the panel the editor sits on.
    double lum(Color c) {
      double f(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double cr(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

    test('contrast on the editor panel (research 027 values)', () {
      // glassStrong over the gradient stops, light and dark.
      final light = [
        for (final g in const [0xFFEDE6FA, 0xFFF7E8EE, 0xFFFFE9DC])
          over(Pb.light.glassStrong, Color(g)),
      ];
      final dark = [
        for (final g in const [0xFF1E1830, 0xFF251C27, 0xFF2A1F1C])
          over(Pb.dark.glassStrong, Color(g)),
      ];
      for (final (pb, panels) in [(Pb.light, light), (Pb.dark, dark)]) {
        for (final p in panels) {
          final fill = over(pb.citeFill, p);
          final pulse = over(pb.citePulse, p);
          final sel = over(pb.selection, p);
          final selOnFill = over(pb.selection, fill);
          expect(cr(pb.ink, fill), greaterThanOrEqualTo(4.5));
          expect(cr(pb.ink, pulse), greaterThanOrEqualTo(4.5));
          expect(cr(pb.ink, sel), greaterThanOrEqualTo(4.5));
          expect(cr(pb.ink, selOnFill), greaterThanOrEqualTo(4.5));
          // the rail carries the non-text contrast (WCAG 1.4.11)
          expect(cr(pb.citeEdge, p), greaterThanOrEqualTo(3));
          // the selection stays visible against the resting block
          expect(cr(selOnFill, fill), greaterThan(1.3));
        }
      }
    });
  });

  group('sheet', () {
    for (final b in Brightness.values) {
      testWidgets('uses theme tokens in $b mode', (t) async {
        final pb = b == Brightness.light ? Pb.light : Pb.dark;
        await t.pumpWidget(
          MaterialApp(
            theme: buildPbTheme(b),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCitationSheet(
                    context,
                    [
                      Citation(
                        index: 1,
                        documentId: 7,
                        documentTitle: 'Doc',
                        kind: 'note',
                        page: 1,
                        quote: 'cited words here',
                      ),
                    ],
                    0,
                    onOpen: (_) {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final text = t.widget<Text>(find.text('cited words here'));
        expect(text.style?.color, pb.ink);
        final block = t.widget<Container>(
          find.byKey(const ValueKey('sheet-quote')),
        );
        expect((block.decoration as BoxDecoration).color, pb.citeFill);
        // no hard-coded light paper behind the passage
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    const Color(0xFFF7F3EA),
          ),
          findsNothing,
        );
      });
    }
  });

  group('pdf lines', () {
    // PDF coordinates: y up, top > bottom. 10pt characters, 12pt apart.
    PdfRect ch(double x, double y) => PdfRect(x, y + 10, x + 6, y);

    test('characters group into lines in reading order', () {
      final chars = [
        for (var i = 0; i < 5; i++) ch(10.0 + i * 6, 700), // line 1
        PdfRect.empty, // a line break has no box
        for (var i = 0; i < 3; i++) ch(10.0 + i * 6, 686), // line 2
      ];
      final lines = pdfLineRects(chars, 0, chars.length);
      expect(lines, hasLength(2));
      expect(lines[0], const PdfRect(10, 710, 40, 700));
      expect(lines[1], const PdfRect(10, 696, 28, 686));
    });

    test('a sub-range, and a far box (second column) starts a new line', () {
      final chars = [
        for (var i = 0; i < 4; i++) ch(10.0 + i * 6, 700),
        ch(300, 700), // other column, same baseline
        ch(306, 700),
      ];
      final lines = pdfLineRects(chars, 2, chars.length);
      expect(lines, hasLength(2));
      expect(lines[0], const PdfRect(22, 710, 34, 700));
      expect(lines[1], const PdfRect(300, 710, 312, 700));
    });

    test('findQuoteLoose: whitespace anywhere, mapped back to the text', () {
      const text = 'a  광안\r\n리 브런치,  바다\n가 보인다.';
      final r = findQuoteLoose(text, '광안리 브런치, 바다가 보인다.')!;
      expect(text.substring(r.start, r.end), '광안\r\n리 브런치,  바다\n가 보인다.');
      expect(findQuoteLoose(text, '   '), isNull);
      expect(findQuoteLoose(text, '없는 문장'), isNull);
      // a sentence group from the server (lines joined by spaces)
      const page = '• 숙소 1박\n• 식비 약 10만 원\n• 합계 약 52만 원';
      final g = findQuoteLoose(page, '숙소 1박 • 식비 약 10만 원')!;
      expect(page.substring(g.start, g.end), '숙소 1박\n• 식비 약 10만 원');
    });

    test('pdfCiteLines: whitespace-tolerant search on the page text', () {
      const text = 'Alpha beta\r\ngamma delta epsilon';
      final chars = [
        for (var i = 0; i < text.length; i++)
          text[i] == '\r' || text[i] == '\n'
              ? PdfRect.empty
              : ch(10.0 + (i % 12) * 6, i < 12 ? 700 : 686),
      ];
      final lines = pdfCiteLines(text, chars, 'beta gamma delta')!;
      expect(lines, hasLength(2)); // spans the line break
      expect(pdfLinesBounds(lines), isNotNull);
      expect(pdfCiteLines(text, chars, 'not on this page at all'), isNull);
    });
  });
}
