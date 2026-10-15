import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/pane_header.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/link_popover.dart';
import 'package:pageblink_flutter/features/notes/live_check_layer.dart';
import 'package:pageblink_flutter/features/notes/live_code_layer.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

/// note-editor-spacing spec §8.2 (T1-T10): measured metrics of the editor's
/// rhythm and gutters, the end air of option B, and the overlay layers on the
/// new geometry. Ahem font (tests), view DPR 1.0.
Future<LiveMarkdownController> _pump(
  WidgetTester t, {
  required double width,
  double height = 900,
  TargetPlatform platform = TargetPlatform.macOS,
  String? highlight,
  double textScale = 1.0,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  if (textScale != 1.0) {
    t.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light).copyWith(platform: platform),
      home: Scaffold(
        body: NoteEditorView(
          embedded: true,
          highlight: highlight,
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pump();
  return t.widget<EditableText>(find.byType(EditableText).last).controller
      as LiveMarkdownController;
}

Future<void> _set(
  WidgetTester t,
  TextEditingController c,
  String text, [
  int? caret,
]) async {
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? 0),
  );
  await t.pump();
  await t.pump();
}

/// Left edge of the 680 column (centered in the pane).
double _columnLeft(double pane) => (pane - (pane < 680 ? pane : 680)) / 2;

Finder get _title => find.byType(EditableText).first;
Finder get _body => find.byType(EditableText).last;
Finder get _heading => find.byKey(const ValueKey('heading-button'));

RenderEditable _render(WidgetTester t) =>
    t.state<EditableTextState>(_body).renderEditable;

RenderBox _stack(WidgetTester t) => t.renderObject<RenderBox>(
  find
      .ancestor(
        of: find.byType(LiveCodeBackLayer),
        matching: find.byType(Stack),
      )
      .first,
);

ScrollController _scroll(WidgetTester t) =>
    t.widget<EditableText>(_body).scrollController as ScrollController;

/// Scrolls to the end and returns: field bottom - bottom of the last line.
Future<double> _endGap(WidgetTester t, String text) async {
  final s = _scroll(t);
  s.jumpTo(s.position.maxScrollExtent);
  await t.pump();
  final r = _render(t);
  final last = r.getLocalRectForCaret(TextPosition(offset: text.length));
  return t.getBottomLeft(_body).dy - r.localToGlobal(last.bottomLeft).dy;
}

String _lines(int n) => [for (var i = 0; i < n; i++) 'line $i'].join('\n');

void main() {
  group('T1 gutter', () {
    for (final (pane, gutter) in [
      (390.0, 20.0),
      (559.0, 20.0),
      (560.0, 24.0),
      (719.0, 24.0),
      (720.0, 32.0),
      (1100.0, 32.0),
    ]) {
      testWidgets('pane $pane: text line at the column edge + $gutter', (
        t,
      ) async {
        await _pump(t, width: pane);
        final left = _columnLeft(pane);
        expect(t.getTopLeft(_body).dx - left, closeTo(gutter, 0.01));
        expect(t.getTopLeft(_title).dx - left, closeTo(gutter, 0.01));
        // T4: the first toolbar icon is on the same line.
        expect(
          t.getTopLeft(find.byIcon(AppIcons.heading)).dx - left,
          closeTo(gutter, 0.01),
        );
      });
    }
  });

  group('T2 title top', () {
    for (final (pane, h, top) in [
      (390.0, 900.0, 24.0),
      (559.0, 900.0, 24.0),
      (720.0, 900.0, 32.0),
      (1100.0, 900.0, 32.0),
      (1100.0, 500.0, 16.0), // short window
    ]) {
      testWidgets('pane $pane, height $h: header -> title $top', (t) async {
        await _pump(t, width: pane, height: h);
        final header = t.getBottomLeft(find.byType(PaneHeader)).dy;
        expect(t.getTopLeft(_title).dy - header, closeTo(top, 0.01));
      });
    }
  });

  testWidgets(
    'T3 desktop: toolbar -> rule 0 -> 24 air -> body (25), title -> toolbar 8',
    (t) async {
      await _pump(t, width: 724);
      final bar = t.getBottomLeft(_heading).dy;
      expect(t.getTopLeft(_body).dy - bar, closeTo(25, 0.01));
      // title text -> toolbar 8 (the field's bottom padding), no extra gap
      expect(
        t.getTopLeft(_heading).dy - t.getBottomLeft(_title).dy,
        closeTo(8, 0.01),
      );
    },
  );

  testWidgets('T3 phone: title -> body 25 (toolbar below the body)', (t) async {
    await _pump(t, width: 390, platform: TargetPlatform.android);
    final titleField = t.getBottomLeft(find.byType(TextField).first).dy;
    expect(t.getTopLeft(_body).dy - titleField, closeTo(25, 0.01));
    // toolbar sits under the body; first icon on the gutter line
    expect(
      t.getTopLeft(find.byIcon(AppIcons.heading)).dy,
      greaterThan(t.getBottomLeft(_body).dy - 1),
    );
    expect(t.getTopLeft(find.byIcon(AppIcons.heading)).dx, closeTo(20, 0.01));
  });

  group('T5 end air (option B)', () {
    for (final (pane, h, air) in [
      (390.0, 900.0, 64.0),
      (600.0, 900.0, 96.0),
      (1100.0, 900.0, 120.0),
      (1100.0, 500.0, 48.0),
    ]) {
      testWidgets('pane $pane, height $h: >= $air under the last line', (
        t,
      ) async {
        final c = await _pump(t, width: pane, height: h);
        final text = _lines(120);
        await _set(t, c, text, text.length);
        final gap = await _endGap(t, text);
        expect(gap, greaterThanOrEqualTo(air - 0.01));
        // the range is exactly the air (plus the line's own leading), not more
        expect(gap, lessThan(air + 30));
      });
    }

    testWidgets('class change at runtime follows (air 120 -> 64)', (t) async {
      final c = await _pump(t, width: 1100);
      final text = _lines(120);
      await _set(t, c, text, text.length);
      expect(await _endGap(t, text), greaterThanOrEqualTo(120));
      t.view.physicalSize = const Size(390, 900);
      await t.pump();
      await t.pump();
      final gap = await _endGap(t, text);
      expect(gap, greaterThanOrEqualTo(64 - 0.01));
      expect(gap, lessThan(64 + 30)); // not the old 120
    });
  });

  testWidgets('T6 a note that fits does not scroll', (t) async {
    final c = await _pump(t, width: 724);
    await _set(t, c, _lines(3));
    expect(_scroll(t).position.maxScrollExtent, 0);
    await _set(t, c, '');
    expect(_scroll(t).position.maxScrollExtent, 0);
  });

  test('T7 gutter - overlayClear >= code block bleed, all classes', () {
    for (final p in [320.0, 559.0, 560.0, 719.0, 720.0, 1100.0]) {
      for (final short in [false, true]) {
        final sp = NoteSpacing.of(p, short: short);
        expect(sp.gutter - NoteSpacing.overlayClear, greaterThanOrEqualTo(12));
        expect(sp.bodyInset, sp.gutter - NoteSpacing.overlayClear);
      }
    }
  });

  testWidgets('T8 citation banner: 16 from the header, 16 to the title', (
    t,
  ) async {
    await _pump(t, width: 724, highlight: 'cited passage');
    // the painted box (the Container's own rect would include its margin)
    final banner = find
        .ancestor(
          of: find.textContaining('⚡'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final header = t.getBottomLeft(find.byType(PaneHeader)).dy;
    final rect = t.getRect(banner);
    expect(rect.top - header, closeTo(16, 0.01));
    expect(t.getTopLeft(_title).dy - rect.bottom, closeTo(16, 0.01));
    // box is gutter - 12 from the column edge, its text on the gutter line
    final left = _columnLeft(724);
    expect(rect.left - left, closeTo(32 - 12, 0.01));
    expect(
      t.getTopLeft(find.textContaining('⚡')).dx - left,
      closeTo(32, 0.01),
    );
    expect(NoteSpacing.bannerRadius, 12);
    final deco = t.widget<DecoratedBox>(banner).decoration as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(12));
  });

  for (final (name, platform, width) in [
    ('desktop', TargetPlatform.macOS, 724.0),
    // the PaneHeader row (not part of this change) overflows at 1.5x on a
    // desktop below ~600; 640 is the narrowest tested here.
    ('narrow desktop', TargetPlatform.macOS, 640.0),
    ('tablet', TargetPlatform.android, 900.0),
  ]) {
    testWidgets('T9 text scale 1.5 ($name $width): no exception, no overlap', (
      t,
    ) async {
      final c = await _pump(
        t,
        width: width,
        height: 800,
        platform: platform,
        textScale: 1.5,
      );
      await _set(t, c, _lines(60));
      expect(t.takeException(), isNull);
      // short (800 / 1.5 < 600): top tightens to 16 on every class
      final header = t.getBottomLeft(find.byType(PaneHeader)).dy;
      expect(t.getTopLeft(_title).dy - header, closeTo(16, 0.01));
      final bar = t.getBottomLeft(_heading).dy;
      expect(t.getTopLeft(_body).dy - bar, closeTo(16 + 1, 0.01));
    });
  }

  group('T10 rule under the toolbar', () {
    Finder rule() => find.byKey(const ValueKey('note-hairline'));

    for (final w in [640.0, 724.0, 1100.0]) {
      testWidgets('desktop $w: full-width 1px rule, 0 gap, always visible', (
        t,
      ) async {
        final c = await _pump(t, width: w);
        // no fade wrapper: the rule is there at rest and while scrolled
        expect(
          find.descendant(of: rule(), matching: find.byType(AnimatedOpacity)),
          findsNothing,
        );
        final r = t.getRect(rule());
        expect(r.height, 1);
        expect(r.left, 0); // pane edge to pane edge, not the 680 column
        expect(r.width, w);
        // right under the toolbar, nothing in between
        final bar = t.getRect(find.byType(SingleChildScrollView).first);
        expect(r.top, closeTo(bar.bottom, 0.01));
        // painted with the hairline token
        final fill = t.widget<ColoredBox>(
          find.descendant(of: rule(), matching: find.byType(ColoredBox)),
        );
        expect(
          fill.color,
          buildPbTheme(Brightness.light).extension<Pb>()!.hairline,
        );
        // still there when scrolled
        await _set(t, c, _lines(120));
        _scroll(t).jumpTo(80);
        await t.pump();
        expect(t.getRect(rule()), r);
      });
    }

    testWidgets('air is the field top padding: rule -> field = 1 + gap, '
        'first glyph line starts 24 under the rule', (t) async {
      await _pump(t, width: 724);
      final r = t.getRect(rule());
      final box = t.getRect(find.byType(TextField).last);
      expect(box.top, closeTo(r.bottom, 0.01));
      expect(t.getTopLeft(_body).dy - box.top, closeTo(24, 0.01));
      // header / title / toolbar / body stay in this order, no overlap
      final bar = t.getRect(find.byType(SingleChildScrollView).first);
      expect(t.getBottomLeft(_title).dy, lessThanOrEqualTo(bar.top + 0.01));
    });

    testWidgets('scrolled text slides under the rule (field clip is off, '
        'a ClipRect at the rule takes over)', (t) async {
      final c = await _pump(t, width: 724);
      await _set(t, c, _lines(120));
      final box = t.getRect(find.byType(TextField).last);
      final clip = find.ancestor(
        of: find.byType(TextField).last,
        matching: find.byType(ClipRect),
      );
      expect(clip, findsWidgets);
      expect(t.getRect(clip.first).top, closeTo(box.top, 0.01));
      expect(t.widget<EditableText>(_body).clipBehavior, Clip.none);
      final before = t.getTopLeft(_body).dy;
      _scroll(t).jumpTo(10);
      await t.pump();
      // the editable box does not move; its text does (up by the offset)
      expect(t.getTopLeft(_body).dy, closeTo(before, 0.01));
      final first = _render(
        t,
      ).getLocalRectForCaret(const TextPosition(offset: 0));
      expect(first.top, closeTo(-10, 0.5));
    });

    testWidgets('phone: no toolbar under the title, rule shows only scrolled', (
      t,
    ) async {
      final c = await _pump(t, width: 390, platform: TargetPlatform.android);
      double opacity() => t
          .widget<AnimatedOpacity>(
            find.descendant(of: rule(), matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      await _set(t, c, _lines(120));
      expect(opacity(), 0);
      final s = _scroll(t);
      s.jumpTo(0.4); // below the threshold: no flicker
      await t.pump();
      expect(opacity(), 0);
      s.jumpTo(40);
      await t.pump();
      expect(opacity(), 1);
      // the 120ms fade really paints (the widget value is only the target)
      await t.pumpAndSettle();
      final fade = t.renderObject<RenderAnimatedOpacity>(
        find.descendant(of: rule(), matching: find.byType(AnimatedOpacity)),
      );
      expect(fade.opacity.value, 1);
      s.jumpTo(0);
      await t.pump();
      expect(opacity(), 0);
    });

    testWidgets('phone: the bar has a hairline above it', (t) async {
      await _pump(t, width: 390, platform: TargetPlatform.android);
      final top = find.byKey(const ValueKey('note-toolbar-top-rule'));
      expect(top, findsOneWidget);
      final deco = t.widget<DecoratedBox>(top).decoration as BoxDecoration;
      expect(
        (deco.border! as Border).top.color,
        buildPbTheme(Brightness.light).extension<Pb>()!.hairline,
      );
      // directly above the bar's icons, below the body
      expect(
        t.getTopLeft(top).dy,
        greaterThanOrEqualTo(
          t.getBottomLeft(find.byType(TextField).last).dy - 0.01,
        ),
      );
      // wide layouts have no such rule
      await _pump(t, width: 724);
      expect(find.byKey(const ValueKey('note-toolbar-top-rule')), findsNothing);
    });
  });

  group('layers follow the new geometry', () {
    testWidgets('checkbox: line box starts at the field top, on the gutter', (
      t,
    ) async {
      final c = await _pump(t, width: 724);
      await _set(t, c, '- [ ] one\n- [x] two\n');
      final targets = checkBoxTargets(_render(t), _stack(t), c.checks);
      expect(targets, hasLength(2));
      final first = targets.first.rect;
      // stack = field box: the first line starts [bodyGap] (24) under the
      // rule (the field's top padding), not at the theme's 14 -> 19+ from it
      expect(first.top, inInclusiveRange(24, 24 + 8));
      // text line (gutter 32) in stack coordinates (stack = column + 8)
      expect(first.left, closeTo(32 - 8, 0.01));
      // the 18px box is centered on the line: rect.center.dy is the line mid
      final r = _render(t);
      final line = r.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      final mid = r.localToGlobal(line.first.toRect().center).dy;
      expect(
        t
            .renderObject<RenderBox>(find.byType(LiveCheckLayer))
            .localToGlobal(
              Offset(0, first.center.dy),
            )
            .dy,
        closeTo(mid, 0.6),
      );
    });

    testWidgets('checkbox and fence follow the text when scrolled', (t) async {
      final c = await _pump(t, width: 724, height: 500);
      final text = '${_lines(40)}\n- [ ] todo\n```\ncode\n```\n${_lines(40)}';
      await _set(t, c, text);
      final s = _scroll(t);
      final off = text.indexOf('- [ ]');
      final r = _render(t);
      s.jumpTo(r.getLocalRectForCaret(TextPosition(offset: off)).top - 100);
      await t.pump();
      final box = checkBoxTargets(r, _stack(t), c.checks).single.rect;
      final line = r.getBoxesForSelection(
        TextSelection(baseOffset: off, extentOffset: off + 1),
      );
      final mid = r.localToGlobal(line.first.toRect().center).dy;
      expect(
        t
            .renderObject<RenderBox>(find.byType(LiveCheckLayer))
            .localToGlobal(Offset(0, box.center.dy))
            .dy,
        closeTo(mid, 0.6),
      );
      final fence = fenceTargets(r, _stack(t), c.fences).single.rect;
      expect(fence.top, greaterThan(box.center.dy)); // the line after the todo
    });

    testWidgets('code block bleed stays inside the stack at every class', (
      t,
    ) async {
      for (final (pane, gutter) in [
        (390.0, 20.0),
        (600.0, 24.0),
        (900.0, 32.0),
      ]) {
        final c = await _pump(t, width: pane);
        await _set(t, c, '```\ncode\n```\n');
        final targets = fenceTargets(_render(t), _stack(t), c.fences);
        expect(targets, hasLength(1));
        final rect = targets.single.rect;
        // gutter - 8 (field padding) - 12 (bleed): 0 on a phone, exactly fits
        expect(rect.left, closeTo(gutter - 8 - kFenceBleed, 0.01));
        expect(rect.left, greaterThanOrEqualTo(-0.01));
        // and, in the window, at least overlayClear from the column edge
        final global = t.getTopLeft(find.byType(LiveCodeBackLayer)).dx;
        expect(global + rect.left, greaterThanOrEqualTo(_columnLeft(pane) + 8));
      }
    });

    testWidgets('link popover stays inside the phone width', (t) async {
      final c = await _pump(
        t,
        width: 390,
        platform: TargetPlatform.android,
      );
      const text = '[docs](https://example.com/a) now';
      await _set(t, c, text, 3);
      await t.pump(const Duration(milliseconds: 50));
      final pop = find.byType(LinkPopover);
      expect(pop, findsOneWidget);
      final rect = t.getRect(pop);
      expect(rect.left, greaterThanOrEqualTo(8 - 0.01));
      expect(rect.right, lessThanOrEqualTo(390 - 8 + 0.01));
    });
  });

  // The air above the text is the field's top padding, so text is visible
  // [air] above the editable's top (the screen's ClipRect cuts it at the rule).
  // The layers must be cut at the same line, not at the editable's top.
  group('air band: layers are cut where the text is cut', () {
    const air = 24.0;

    /// Editable box in stack coordinates.
    Rect view(WidgetTester t) => MatrixUtils.transformRect(
      _render(t).getTransformTo(_stack(t)),
      Offset.zero & _render(t).size,
    );

    RenderObject paint(WidgetTester t, Type layer) => t.renderObject(
      find.descendant(
        of: find.byType(layer),
        matching: find.byType(CustomPaint),
      ),
    );

    /// Scrolls so the line box of `[from, to)` ends 2 px above the editable's
    /// top: inside the air (a line is 24.4 px, the air 24: its top is cut).
    Future<double> scrollLineIntoAir(WidgetTester t, int from, int to) async {
      final box = _render(t)
          .getBoxesForSelection(
            TextSelection(baseOffset: from, extentOffset: to),
          )
          .first
          .toRect();
      _scroll(t).jumpTo(box.bottom + 2); // bottom edge now at -2
      await t.pump();
      return box.height;
    }

    testWidgets('checkbox: drawn and pressable above the editable, cut at '
        'the rule, gone once its line leaves the air', (t) async {
      final c = await _pump(t, width: 724);
      await _set(t, c, '- [ ] one\n${_lines(60)}');
      await scrollLineIntoAir(t, 0, 1);
      final r = _render(t), st = _stack(t);
      // read without the air: the item is "before the viewport" (the bug)
      expect(checkBoxTargets(r, st, c.checks), isEmpty);
      final box = checkBoxTargets(r, st, c.checks, topAir: air).single.rect;
      expect(box.center.dy, inExclusiveRange(0, air)); // under the rule
      // clip: editable top - air = the rule (stack top), nothing above it
      final v = view(t);
      expect(v.top - air, closeTo(0, 0.01));
      expect(
        paint(t, LiveCheckLayer),
        paints
          ..clipRect(rect: Rect.fromLTRB(v.left, 0, v.right, v.bottom))
          ..rrect(),
      );
      // pressable there
      await t.tapAt(st.localToGlobal(box.center));
      await t.pump();
      expect(c.text, startsWith('- [x] one'));
      // one line more and it is above the rule: not read, not drawn, no hit
      _scroll(t).jumpTo(_scroll(t).offset + 60);
      await t.pump();
      expect(checkBoxTargets(r, st, c.checks, topAir: air), isEmpty);
      expect(paint(t, LiveCheckLayer), isNot(paints..rrect()));
      await t.tapAt(st.localToGlobal(Offset(box.center.dx, 2)));
      await t.pump();
      expect(c.text, startsWith('- [x] one'));
    });

    testWidgets('code block: fill reaches the rule with the text, corners '
        'of a block that continues are cut there', (t) async {
      final c = await _pump(t, width: 724);
      await _set(t, c, '```py\ncode\nmore\n```\n${_lines(60)}');
      final end = c.text.indexOf('```\n', 5) + 3;
      await scrollLineIntoAir(t, end - 1, end);
      final r = _render(t), st = _stack(t);
      expect(fenceTargets(r, st, c.fences), isEmpty); // the bug
      final rect = fenceTargets(r, st, c.fences, topAir: air).single.rect;
      final v = view(t);
      // continues above the viewport: top is past the clip, not at its edge
      expect(rect.top, closeTo(v.top - air - 40, 0.01));
      expect(rect.bottom, inExclusiveRange(0, v.top + air));
      expect(
        paint(t, LiveCodeBackLayer),
        paints
          ..clipRect(
            rect: Rect.fromLTRB(
              v.left - kFenceBleed,
              0, // the rule, not v.top (24 below it)
              v.right + kFenceBleed,
              v.bottom,
            ),
          )
          ..rrect(),
      );
      // the line after the block's end has left the air: no block
      _scroll(t).jumpTo(_scroll(t).offset + 60);
      await t.pump();
      expect(fenceTargets(r, st, c.fences, topAir: air), isEmpty);
    });

    testWidgets('copy button: on a head line in the air it shows, presses '
        'and copies; one line later it is gone', (t) async {
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = await _pump(t, width: 724);
      await _set(t, c, '```py\ncode\n```\n${_lines(60)}');
      await scrollLineIntoAir(t, 0, 5);
      final r = _render(t), st = _stack(t);
      expect(fenceTargets(r, st, c.fences).single.head, isNull); // the bug
      final tg = fenceTargets(r, st, c.fences, topAir: air).single;
      final btn = copyButtonRect(tg)!;
      expect(btn.center.dy, inExclusiveRange(0, air));
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(1, 1));
      await g.moveTo(st.localToGlobal(tg.rect.center));
      await t.pump();
      await g.moveTo(st.localToGlobal(btn.center));
      await t.pump();
      await t.pump();
      final ui = t.widget<LiveCodeBackLayer>(find.byType(LiveCodeBackLayer)).ui;
      expect(ui.overButton, isTrue);
      await g.down(st.localToGlobal(btn.center));
      await t.pump(const Duration(milliseconds: 40));
      await g.up();
      await t.pump();
      expect(copied, ['code']);
      await t.pump(const Duration(seconds: 2));
      // head line above the rule: no button, nothing to press
      _scroll(t).jumpTo(_scroll(t).offset + 60);
      await t.pump();
      final gone = fenceTargets(r, st, c.fences, topAir: air);
      expect(gone.isEmpty || copyButtonRect(gone.single) == null, isTrue);
      await g.removePointer();
    });
  });
}
