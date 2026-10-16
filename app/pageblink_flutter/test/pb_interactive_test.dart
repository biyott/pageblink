import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/pb_interactive.dart';
import 'package:pageblink_flutter/app/theme.dart';

// PbInteractive / PbFocusRing: the shared interaction states (hover 6%,
// pressed 12%, ring from the keyboard only, instant with reduced motion).

const _face = ValueKey('face');

/// The tint the face shows: the builder paints `pbTint` into a Container.
Color _tint(WidgetTester t) => t.widget<Container>(find.byKey(_face)).color!;

PbRingPainter _ring(WidgetTester t, [Finder? within]) {
  final f = find.descendant(
    of: within ?? find.byType(PbInteractive),
    matching: find.byKey(pbFocusRingKey),
  );
  return t.widget<CustomPaint>(f.first).foregroundPainter as PbRingPainter;
}

Future<void> _pump(
  WidgetTester t,
  Brightness br, {
  VoidCallback? onTap,
  bool reduced = false,
  bool expanded = false,
  String? label,
}) => t.pumpWidget(
  MaterialApp(
    theme: buildPbTheme(br),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: PbInteractive(
          onTap: onTap,
          label: label,
          expanded: expanded ? true : null,
          minHit: const Size(120, 44),
          builder: (context, s) => Container(
            key: _face,
            width: 120,
            height: 32,
            color: pbTint(context.pb, s),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final br in [Brightness.light, Brightness.dark]) {
    final pb = br == Brightness.light ? Pb.light : Pb.dark;

    testWidgets('$br: hover 6%, pressed 12%, from nothing at rest', (t) async {
      var taps = 0;
      await _pump(t, br, onTap: () => taps++);
      expect(_tint(t), Colors.transparent);
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      await g.moveTo(t.getCenter(find.byKey(_face)));
      await t.pump();
      expect(_tint(t), pb.hover);
      expect(pb.hover.a, closeTo(0.06, 0.005));
      await g.down(t.getCenter(find.byKey(_face)));
      await t.pump();
      expect(_tint(t), pb.press);
      expect(pb.press.a, closeTo(0.12, 0.005));
      await g.up();
      await t.pump();
      expect(taps, 1);
      await g.moveTo(Offset.zero);
      await t.pump();
      expect(_tint(t), Colors.transparent);
    });

    testWidgets('$br: ring from Tab, none from a mouse click', (t) async {
      var taps = 0;
      await _pump(t, br, onTap: () => taps++);
      expect(_ring(t).visible, isFalse);
      // A click: taps, but focus (and the ring) does not move.
      await t.tap(find.byKey(_face));
      await t.pump();
      expect(taps, 1);
      expect(_ring(t).visible, isFalse, reason: 'no ring after a click');
      // Tab: the ring, in the ring colour, 2px + 2px gap.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final ring = _ring(t);
      expect(ring.visible, isTrue);
      expect(ring.color, pb.focusRing);
      expect(ring.width, 2);
      expect(ring.offset, 2);
      // Enter and Space press it.
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(taps, 2);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(taps, 3);
    });
  }

  testWidgets('disabled: no states, no tab stop, basic cursor', (t) async {
    await _pump(t, Brightness.light);
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(t.getCenter(find.byKey(_face)));
    await t.pump();
    expect(_tint(t), Colors.transparent);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring(t).visible, isFalse);
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('enabled: click cursor', (t) async {
    await _pump(t, Brightness.light, onTap: () {});
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(t.getCenter(find.byKey(_face)));
    await t.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('pressed scales to 0.97 in 80 ms; instant with reduced motion', (
    t,
  ) async {
    await _pump(t, Brightness.light, onTap: () {});
    final g = await t.startGesture(t.getCenter(find.byKey(_face)));
    await t.pump();
    var s = t.widget<AnimatedScale>(find.byType(AnimatedScale).first);
    expect(s.scale, 0.97);
    expect(s.duration, const Duration(milliseconds: 80));
    await g.up();
    await t.pump();

    await _pump(t, Brightness.light, onTap: () {}, reduced: true);
    final g2 = await t.startGesture(t.getCenter(find.byKey(_face)));
    await t.pump();
    s = t.widget<AnimatedScale>(find.byType(AnimatedScale).first);
    expect(s.scale, 1, reason: 'no scale with reduced motion');
    expect(s.duration, Duration.zero);
    await g2.up();
    // The 120 ms colour transition is instant too.
    expect(pbFast(t.element(find.byKey(_face))), Duration.zero);
  });

  testWidgets('semantics: button, name, expanded, focusable, tap', (t) async {
    final handle = t.ensureSemantics();
    await _pump(
      t,
      Brightness.light,
      onTap: () {},
      label: 'Answer model: Auto',
      expanded: true,
    );
    expect(
      t.getSemantics(find.byType(PbInteractive)),
      matchesSemantics(
        label: 'Answer model: Auto',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasExpandedState: true,
        isExpanded: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'PbFocusRing: lights for its own control, not for one inside it',
    (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: PbFocusRing(
                radius: 16,
                child: Card(
                  child: InkWell(
                    onTap: () {},
                    child: SizedBox(
                      width: 200,
                      height: 100,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      bool lit() =>
          (t
                      .widget<CustomPaint>(find.byKey(pbFocusRingKey).first)
                      .foregroundPainter
                  as PbRingPainter)
              .visible;
      expect(lit(), isFalse);
      await t.sendKeyEvent(LogicalKeyboardKey.tab); // the card
      await t.pump();
      expect(lit(), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.tab); // the button inside it
      await t.pump();
      expect(lit(), isFalse, reason: 'the inner button has its own ring');
      // Touch mode: a focused control shows no ring.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await t.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'android');
      await t.pump();
      expect(lit(), isFalse);
    },
  );
}
