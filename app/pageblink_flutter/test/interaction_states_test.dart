import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/pb_interactive.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/app/visitor_key.dart';
import 'package:pageblink_flutter/features/ask/ask_chat.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The interaction states of the real Ask components, measured on pixels of
// the real widgets under the real theme (the audit found hover and focus at
// 0% for the show-fewer toggle and the two composer pills: their ink was
// painted under a translucent face).

final _boundary = GlobalKey();

/// RGBA of the whole host.
Future<ByteData> _shot(WidgetTester t) async {
  late ByteData raw;
  await t.runAsync(() async {
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    raw = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return raw;
}

/// Share of pixels in [r] that differ from [a] by more than 4/255 in some
/// channel, and the largest difference.
({double share, int max}) _diff(ByteData a, ByteData b, int w, Rect r) {
  var n = 0, c = 0, mx = 0;
  for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
    for (var x = r.left.floor(); x < r.right.ceil(); x++) {
      final i = (y * w + x) * 4;
      var d = 0;
      for (var k = 0; k < 3; k++) {
        d = [d, (a.getUint8(i + k) - b.getUint8(i + k)).abs()].reduce(
          (p, q) => p > q ? p : q,
        );
      }
      n++;
      if (d > 4) c++;
      if (d > mx) mx = d;
    }
  }
  return (share: c / n, max: mx);
}

/// Largest channel difference between two pixels.
int _delta(Color a, Color b) => [
  ((a.r - b.r) * 255).abs().round(),
  ((a.g - b.g) * 255).abs().round(),
  ((a.b - b.b) * 255).abs().round(),
].reduce((p, q) => p > q ? p : q);

Color _px(ByteData d, int w, double x, double y) {
  final i = (y.round() * w + x.round()) * 4;
  return Color.fromARGB(
    255,
    d.getUint8(i),
    d.getUint8(i + 1),
    d.getUint8(i + 2),
  );
}

Citation _c(int i) => Citation(
  index: i,
  documentId: i,
  documentTitle: 'Doc $i',
  kind: i.isEven ? 'note' : 'pdf',
  page: i,
  quote: 'q',
);

Widget _host(Brightness br, Widget child, {bool reduced = false}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildPbTheme(br),
      locale: const Locale('en'),
      supportedLocales: supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: c!,
      ),
      home: RepaintBoundary(
        key: _boundary,
        child: PbBackground(child: Scaffold(body: child)),
      ),
    );

PbRingPainter _ringOf(WidgetTester t, Finder inside) =>
    t
            .widget<CustomPaint>(
              find
                  .descendant(of: inside, matching: find.byKey(pbFocusRingKey))
                  .first,
            )
            .foregroundPainter!
        as PbRingPainter;

Finder _toggle() => find.byKey(const ValueKey('sources-toggle'));

/// The drawn face of the toggle (the keyed finder is the larger hit area).
Rect _face(WidgetTester t, Finder f) => t.getRect(
  find.descendant(of: f, matching: find.byType(AnimatedContainer)).first,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final br in [Brightness.light, Brightness.dark]) {
    final pb = br == Brightness.light ? Pb.light : Pb.dark;

    testWidgets('$br: show-fewer toggle: hover, press, ring, underline', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(460, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final turn = AskTurn('q')
        ..answer.write('a [1] b [2] c [3] d [4] e [5] f [6]')
        ..done = true;
      for (var i = 1; i <= 6; i++) {
        turn.citations[i] = _c(i);
      }
      await t.pumpWidget(
        _host(
          br,
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AskTurnView(turn, onBlink: (_, _) {}),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(_toggle()); // expand: it now reads "Show fewer"
      await t.pumpAndSettle();
      final face = _face(t, _toggle());
      final rest = await _shot(t);

      // Hover: before, 0% of the face changed (light) / max 8 (dark).
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(1, 1));
      await g.moveTo(face.center);
      await t.pumpAndSettle();
      final hover = await _shot(t);
      final h = _diff(rest, hover, 460, face.deflate(2));
      // ignore: avoid_print
      print(
        '[$br] toggle hover: ${(h.share * 100).round()}% changed, max ${h.max}',
      );
      expect(h.share, greaterThan(0.5), reason: 'hover must show on the face');
      expect(h.max, greaterThanOrEqualTo(10));

      // Pressed is stronger than hover.
      await g.down(face.center);
      await t.pump(); // starts the colour transition
      await t.pump(const Duration(milliseconds: 200));
      final press = await _shot(t);
      final at = Offset(face.left + 6, face.center.dy); // empty padding
      final dh = _delta(
        _px(rest, 460, at.dx, at.dy),
        _px(hover, 460, at.dx, at.dy),
      );
      final dp = _delta(
        _px(rest, 460, at.dx, at.dy),
        _px(press, 460, at.dx, at.dy),
      );
      // ignore: avoid_print
      print('[$br] toggle point: hover Δ$dh, pressed Δ$dp');
      expect(dh, greaterThanOrEqualTo(10));
      expect(dp, greaterThan(dh), reason: 'pressed 12% > hover 6%');
      await g.cancel();
      await t.pumpAndSettle(); // (the tap toggled it back; expand again)
      await g.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      if (find.text('Show fewer').evaluate().isEmpty) {
        await t.tap(_toggle());
        await t.pumpAndSettle();
      }
      await g.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();

      // Keyboard: Tab until the toggle has focus; the ring appears around the
      // face (2px gap, 2px stroke), in the ring colour.
      final shot0 = await _shot(t);
      expect(_ringOf(t, _toggle()).visible, isFalse);
      for (var i = 0; i < 20 && !_ringOf(t, _toggle()).visible; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(_ringOf(t, _toggle()).visible, isTrue);
      final shot1 = await _shot(t);
      final f2 = _face(t, _toggle());
      // The stroke sits 2..4px above the face: some pixel of that column
      // is (nearly) the ring colour, and none was before the Tab.
      int nearest(ByteData d) => [
        for (var dy = 1; dy <= 5; dy++)
          _delta(_px(d, 460, f2.center.dx, f2.top - dy), pb.focusRing),
      ].reduce((p, q) => p < q ? p : q);
      expect(nearest(shot1), lessThanOrEqualTo(8), reason: 'ring pixel');
      expect(nearest(shot0), greaterThan(60), reason: 'no ring before');
    });

    testWidgets('$br: example question card: hover, press, ring from Tab', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(500, 700)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var picked = 0;
      await t.pumpWidget(
        _host(
          br,
          AskEmptyHint(onPick: (_) => picked++, includePersonal: false),
        ),
      );
      await t.pumpAndSettle();
      final card = find.byType(PbInteractive).first;
      final r = t.getRect(card);
      final rest = await _shot(t);
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(1, 1));
      await g.moveTo(r.center);
      await t.pumpAndSettle();
      final hoverShot = await _shot(t);
      final h = _diff(rest, hoverShot, 500, r.deflate(4));
      // ignore: avoid_print
      print(
        '[$br] suggestion hover: ${(h.share * 100).round()}% changed, max ${h.max}',
      );
      expect(h.share, greaterThan(0.5));
      expect(h.max, greaterThanOrEqualTo(8));
      await g.down(r.center);
      await t.pump(); // starts the colour transition
      await t.pump(const Duration(milliseconds: 200));
      final at = Offset(r.left + 8, r.center.dy);
      final press = await _shot(t);
      final dh = _delta(
        _px(rest, 500, at.dx, at.dy),
        _px(hoverShot, 500, at.dx, at.dy),
      );
      final dp = _delta(
        _px(rest, 500, at.dx, at.dy),
        _px(press, 500, at.dx, at.dy),
      );
      // ignore: avoid_print
      print('[$br] suggestion point: hover Δ$dh, pressed Δ$dp');
      expect(dh, greaterThanOrEqualTo(8));
      expect(dp, greaterThan(dh));
      await g.up();
      expect(picked, 1);
      await g.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_ringOf(t, card).visible, isTrue);
      expect(_ringOf(t, card).color, pb.focusRing);
    });
  }

  // ── The Ask composer ────────────────────────────────────────────────────
  group('composer', () {
    final models = [
      LlmModel(id: 'm1', label: 'Model One', provider: 'p', free: true),
      LlmModel(id: 'm2', label: 'Model Two', provider: 'p', free: false),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      resetVisitorKey();
      resetNotice();
      resetHistoryStatus();
      historyStatusCall = () async => AskHistoryStatus(
        enabled: false,
        questionLimit: 10,
        visibleMinutes: 30,
        retentionDays: 30,
        questionMaxChars: 2000,
        isAdmin: false,
      );
      askRestoreCall = (_) async => AskRestore(recent: []);
      modelListCall = () async => models;
    });
    tearDown(() {
      historyStatusCall = null;
      askRestoreCall = null;
      modelListCall = null;
    });

    Future<void> pumpAsk(WidgetTester t, Brightness br) async {
      t.view
        ..physicalSize = const Size(700, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_host(br, const AskScreen(projects: [])));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    /// The pill under the tooltip [tip]: its PbInteractive and drawn face.
    Finder pillOf(String tip) => find.descendant(
      of: find.byTooltip(tip),
      matching: find.byType(PbInteractive),
    );
    Finder faceOf(String tip) => find.descendant(
      of: pillOf(tip),
      matching: find.byType(AnimatedContainer),
    );

    for (final br in [Brightness.light, Brightness.dark]) {
      final pb = br == Brightness.light ? Pb.light : Pb.dark;

      testWidgets('$br: scope + model pills hover, press, ring, names', (
        t,
      ) async {
        final handle = t.ensureSemantics();
        await pumpAsk(t, br);
        expect(
          find.bySemanticsLabel(RegExp('^Search scope: ')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Answer model: Auto'), findsOneWidget);
        final g = await t.createGesture(kind: PointerDeviceKind.mouse);
        await g.addPointer(location: const Offset(1, 1));
        for (final (name, tip) in [
          ('scope', 'Search scope'),
          ('model', 'Answer model'),
        ]) {
          final face = t.getRect(faceOf(tip).first);
          final rest = await _shot(t);
          final at = Offset(face.left + 8, face.center.dy);
          await g.moveTo(face.center);
          await t.pump();
          await t.pump(const Duration(milliseconds: 200));
          final hover = await _shot(t);
          await g.down(face.center);
          await t.pump();
          await t.pump(const Duration(milliseconds: 200));
          final press = await _shot(t);
          final dh = _delta(
            _px(rest, 700, at.dx, at.dy),
            _px(hover, 700, at.dx, at.dy),
          );
          final dp = _delta(
            _px(rest, 700, at.dx, at.dy),
            _px(press, 700, at.dx, at.dy),
          );
          // ignore: avoid_print
          print('[$br] $name pill: hover Δ$dh, pressed Δ$dp (audit: Δ1 / Δ1)');
          expect(dh, greaterThanOrEqualTo(8), reason: '$name hover');
          expect(dp, greaterThan(dh), reason: '$name pressed');
          await g.cancel(); // a press that is not a tap
          await g.moveTo(const Offset(1, 1));
          await t.pumpAndSettle();
        }
        handle.dispose();
      });

      testWidgets('$br: Tab reaches scope, field, send, model; ring on each', (
        t,
      ) async {
        await pumpAsk(t, br);
        await t.enterText(find.byType(TextField), 'hello');
        await t.pump();
        final seen = <String>[];
        for (var i = 0; i < 6; i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
          for (final e in find.byType(PbInteractive).evaluate()) {
            final ring = _ringOf(t, find.byWidget(e.widget));
            if (ring.visible) {
              expect(ring.color, pb.focusRing);
              seen.add('pill');
            }
          }
          for (final e in find.byType(PbFocusRing).evaluate()) {
            final p =
                t
                        .widget<CustomPaint>(
                          find
                              .descendant(
                                of: find.byWidget(e.widget),
                                matching: find.byKey(pbFocusRingKey),
                              )
                              .first,
                        )
                        .foregroundPainter!
                    as PbRingPainter;
            if (p.visible) seen.add('ring');
          }
        }
        expect(seen, contains('pill'));
      });

      testWidgets('$br: send button: dark overlay, ring, off look, hint', (
        t,
      ) async {
        final handle = t.ensureSemantics();
        await pumpAsk(t, br);
        final send = find.byType(IconButton).last;
        // Off: nothing typed.
        expect(t.widget<IconButton>(send).onPressed, isNull);
        expect(
          t.getSemantics(send),
          isSemantics(
            hint: 'Type a question to send it',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        await t.enterText(find.byType(TextField), 'hello');
        await t.pump();
        expect(t.widget<IconButton>(send).onPressed, isNotNull);
        final style = t.widget<IconButton>(send).style!;
        Color? overlay(Set<WidgetState> s) => style.overlayColor!.resolve(s);
        expect(overlay({WidgetState.hovered}), pb.filledHover);
        expect(overlay({WidgetState.pressed}), pb.filledPress);
        expect(overlay({WidgetState.focused}), Colors.transparent);
        expect(
          style.backgroundColor!.resolve({WidgetState.disabled}),
          pb.disabledBg,
        );
        // Hover darkens the violet fill (pixel, left of the arrow).
        final r = t.getRect(send);
        final rest = await _shot(t);
        final g = await t.createGesture(kind: PointerDeviceKind.mouse);
        await g.addPointer(location: const Offset(1, 1));
        await g.moveTo(r.center);
        await t.pumpAndSettle();
        final hover = await _shot(t);
        await g.down(r.center);
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        final press = await _shot(t);
        final at = Offset(r.left + 6, r.center.dy);
        final dh = _delta(
          _px(rest, 700, at.dx, at.dy),
          _px(hover, 700, at.dx, at.dy),
        );
        final dp = _delta(
          _px(rest, 700, at.dx, at.dy),
          _px(press, 700, at.dx, at.dy),
        );
        // ignore: avoid_print
        print(
          '[$br] send: hover Δ$dh, pressed Δ$dp (audit: hover Δ12 white wash)',
        );
        expect(dh, greaterThanOrEqualTo(8));
        expect(dp, greaterThan(dh));
        await g.cancel();
        await g.moveTo(const Offset(1, 1));
        await t.pumpAndSettle();
        // Ring: Tab until the send button shows its outer ring (the theme's
        // ring shape: painted outside, the circle itself unchanged).
        ShapeBorder shape() => t
            .widget<Material>(
              find.descendant(of: send, matching: find.byType(Material)).first,
            )
            .shape!;
        expect(shape(), isNot(isA<PbRingBorder>()));
        for (var i = 0; i < 25 && shape() is! PbRingBorder; i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
        }
        expect(shape(), isA<PbRingBorder>());
        expect((shape() as PbRingBorder).color, pb.focusRing);
        handle.dispose();
      });

      testWidgets('$br: the question field shows focus on the panel', (
        t,
      ) async {
        await pumpAsk(t, br);
        final host = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(PbFocusRing),
            )
            .first;
        PbRingPainter ring() =>
            t
                    .widget<CustomPaint>(
                      find
                          .descendant(
                            of: host,
                            matching: find.byKey(pbFocusRingKey),
                          )
                          .first,
                    )
                    .foregroundPainter!
                as PbRingPainter;
        expect(ring().visible, isFalse);
        // A mouse click into the field: a text field is focused to type, so
        // the ring shows on click too (the one exception to "keyboard only").
        await t.tap(find.byType(TextField));
        await t.pump();
        expect(ring().visible, isTrue);
        expect(ring().color, pb.focusRing);
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
        expect(ring().visible, isFalse);
      });
    }

    testWidgets('model pill: menu marks the current item, chevron turns', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await pumpAsk(t, Brightness.light);
      final model = find.bySemanticsLabel('Answer model: Auto');
      expect(
        t.getSemantics(model),
        matchesSemantics(
          label: 'Answer model: Auto',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasSelectedState: true,
          hasExpandedState: true,
          isExpanded: false,
          tooltip: 'Answer model',
        ),
      );
      await t.tap(model);
      await t.pumpAndSettle();
      // (Below a modal menu the pill's own node is hidden from the tree.)
      expect(t.widget<PbInteractive>(pillOf('Answer model')).expanded, isTrue);
      expect(
        t
            .widget<AnimatedRotation>(
              find.descendant(
                of: pillOf('Answer model'),
                matching: find.byType(AnimatedRotation),
              ),
            )
            .turns,
        0.5,
      );
      // Auto is the current one; Model One is not.
      Finder item(String text) => find
          .ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
          )
          .first;
      final auto = item('Auto · rotates free models');
      expect(auto, findsOneWidget);
      expect(
        t.getSemantics(auto),
        isSemantics(
          role: ui.SemanticsRole.menuItemRadio,
          isChecked: true,
          hasCheckedState: true,
          isButton: true,
        ),
      );
      final one = item('Model One');
      expect(
        t.getSemantics(one),
        isSemantics(
          role: ui.SemanticsRole.menuItemRadio,
          isChecked: false,
          hasCheckedState: true,
          isButton: true,
        ),
      );
      await t.tap(one);
      await t.pumpAndSettle();
      // Closed again, and the pill now names the model.
      expect(find.bySemanticsLabel('Answer model: Model One'), findsOneWidget);
      expect(t.widget<PbInteractive>(pillOf('Answer model')).expanded, isFalse);
      handle.dispose();
    });

    testWidgets('scope pill with nothing selected: warn face and text', (
      t,
    ) async {
      await pumpAsk(t, Brightness.light);
      const pb = Pb.light;
      await t.tap(pillOf('Search scope'));
      await t.pumpAndSettle();
      await t.tap(find.text('My documents'));
      await t.pumpAndSettle();
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      final face = faceOf('Search scope');
      BoxDecoration deco() =>
          t.widget<AnimatedContainer>(face).decoration! as BoxDecoration;
      expect(deco().color, pb.warnContainer);
      final text = t.widget<Text>(
        find.descendant(of: face, matching: find.byType(Text)),
      );
      expect(
        text.style!.color,
        pb.warnText,
        reason: 'warnText 5.75:1, not warn 4.5:1',
      );
      final g = await t.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: const Offset(1, 1));
      await g.moveTo(t.getCenter(face));
      await t.pump();
      expect(deco().color, Color.alphaBlend(pb.warnHover, pb.warnContainer));
    });
  });
}
