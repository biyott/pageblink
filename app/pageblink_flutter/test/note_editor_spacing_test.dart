import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('T3 desktop: toolbar -> body 25, title -> toolbar 8', (t) async {
    await _pump(t, width: 724);
    final bar = t.getBottomLeft(_heading).dy;
    expect(t.getTopLeft(_body).dy - bar, closeTo(25, 0.01));
    // title text -> toolbar 8 (the field's bottom padding), no extra gap
    expect(
      t.getTopLeft(_heading).dy - t.getBottomLeft(_title).dy,
      closeTo(8, 0.01),
    );
  });

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

  testWidgets('T10 hairline shows only while scrolled', (t) async {
    final c = await _pump(t, width: 724);
    double opacity() => t
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(const ValueKey('note-hairline')),
            matching: find.byType(AnimatedOpacity),
          ),
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
      find.descendant(
        of: find.byKey(const ValueKey('note-hairline')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.opacity.value, 1);
    s.jumpTo(0);
    await t.pump();
    expect(opacity(), 0);
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
      // contentPadding.top is 0: the first line starts at the field top
      // (a theme padding of 14 would put this at 19+)
      expect(first.top, inInclusiveRange(0, 8));
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
}
