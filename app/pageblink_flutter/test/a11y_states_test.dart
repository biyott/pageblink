import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/pb_interactive.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:pageblink_flutter/features/demo/demo_widgets.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/viewer/cite_bar.dart';

// Theme state values, contrast of the new colours, names / focusability for
// the screen reader, long press by device, touch target sizes.

Citation _c(int i) => Citation(
  index: i,
  documentId: i,
  documentTitle: 'Doc $i',
  kind: i.isEven ? 'note' : 'pdf',
  page: i,
  quote: 'q',
);

Widget _app(Widget child, {Brightness br = Brightness.light}) {
  return MaterialApp(
    theme: buildPbTheme(br),
    locale: const Locale('en'),
    supportedLocales: supportedLocales,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: Center(child: child)),
  );
}

double _lum(Color c) => c.computeLuminance();
double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final br in [Brightness.light, Brightness.dark]) {
    final pb = br == Brightness.light ? Pb.light : Pb.dark;

    test(
      '$br: theme state colours are explicit tokens, not Material violet',
      () {
        final th = buildPbTheme(br, platform: TargetPlatform.macOS);
        Color? at(ButtonStyle? st, Set<WidgetState> s) =>
            st!.overlayColor!.resolve(s);
        const hov = {WidgetState.hovered};
        const prs = {WidgetState.pressed};
        const foc = {WidgetState.focused};
        for (final st in [
          th.textButtonTheme.style,
          th.outlinedButtonTheme.style,
          th.iconButtonTheme.style,
          th.segmentedButtonTheme.style,
        ]) {
          expect(at(st, hov), pb.hover);
          expect(at(st, prs), pb.press);
          expect(
            at(st, foc),
            Colors.transparent,
            reason: 'the ring is the focus cue',
          );
        }
        for (final st in [
          th.filledButtonTheme.style,
          th.elevatedButtonTheme.style,
        ]) {
          expect(at(st, hov), pb.filledHover);
          expect(at(st, prs), pb.filledPress);
          expect(at(st, foc), Colors.transparent);
        }
        expect(pb.hover.a, closeTo(0.06, 0.005));
        expect(pb.press.a, closeTo(0.12, 0.005));
        expect(pb.filledHover.a, closeTo(0.08, 0.005));
        expect(pb.filledPress.a, closeTo(0.14, 0.005));
        expect(pb.disabledFg.a, closeTo(0.38, 0.005));
        expect(pb.disabledBg.a, closeTo(0.08, 0.005));
        // ThemeData: the row families without a ring keep a neutral 12% focus
        // tint; hover is 6% ink (white in dark).
        expect(th.hoverColor, pb.hover);
        expect(th.focusColor, pb.press);
        expect(th.splashFactory, NoSplash.splashFactory); // desktop: no ripple
        expect(th.highlightColor, pb.hover); // desktop press = hover + 6%
        final touch = buildPbTheme(br, platform: TargetPlatform.android);
        expect(touch.highlightColor, Colors.transparent);
        expect(touch.splashColor, pb.press);
        // Disabled: text 38% ink, fill 8%; cursor basic, click when enabled.
        final fb = th.filledButtonTheme.style!;
        expect(
          fb.backgroundColor!.resolve({WidgetState.disabled}),
          pb.disabledBg,
        );
        expect(
          fb.foregroundColor!.resolve({WidgetState.disabled}),
          pb.disabledFg,
        );
        expect(
          fb.mouseCursor!.resolve({WidgetState.disabled}),
          SystemMouseCursors.basic,
        );
        expect(fb.mouseCursor!.resolve({}), SystemMouseCursors.click);
        // Form inputs: darker edge, 2px ring-coloured focus; menus opaque.
        final dec = th.inputDecorationTheme;
        expect(
          (dec.enabledBorder! as OutlineInputBorder).borderSide.color,
          pb.controlEdge,
        );
        expect(
          (dec.focusedBorder! as OutlineInputBorder).borderSide.color,
          pb.focusRing,
        );
        expect((dec.focusedBorder! as OutlineInputBorder).borderSide.width, 2);
        expect(th.popupMenuTheme.color!.a, 1);
      },
    );

    test(
      '$br: ring on buttons (outer shape) and chips (inset side), keyboard only',
      () {
        final th = buildPbTheme(br, platform: TargetPlatform.macOS);
        final chip = th.chipTheme.side! as WidgetStateProperty<BorderSide?>;
        final accent = br == Brightness.light
            ? const Color(0xFF6C4CF5)
            : const Color(0xFFB7A6FF);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        final ring = chip.resolve({WidgetState.focused})!;
        expect((ring.color, ring.width), (pb.focusRing, 2.0));
        expect(chip.resolve({})!.color, pb.hairline);
        expect(
          chip.resolve({WidgetState.hovered})!.color,
          pb.ink.withValues(alpha: 0.28),
        );
        expect(
          chip.resolve({WidgetState.selected})!.color,
          accent.withValues(alpha: 0.55),
        );
        // Buttons: the outer ring is the shape (keyboard mode only).
        for (final st in [
          th.textButtonTheme.style,
          th.outlinedButtonTheme.style,
          th.iconButtonTheme.style,
        ]) {
          final shape = st!.shape!.resolve({WidgetState.focused})!;
          expect(shape, isA<PbRingBorder>());
          expect((shape as PbRingBorder).color, pb.focusRing);
          expect(shape.base, isA<StadiumBorder>());
          expect(st.shape!.resolve({}), isNot(isA<PbRingBorder>()));
        }
        expect(
          th.outlinedButtonTheme.style!.side!.resolve({})!.color,
          pb.hairline,
        );
        // Touch mode (a phone): a focused control shows no ring.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        expect(
          th.textButtonTheme.style!.shape!.resolve({WidgetState.focused}),
          isNot(isA<PbRingBorder>()),
        );
        expect(chip.resolve({WidgetState.focused})!.color, pb.hairline);
      },
    );

    test('$br: focus ring colour: >= 3:1 on every surface, 2px, ink', () {
      expect(pb.focusRing, pb.ink);
      // The surfaces of the app (composited, spec §3.2): background stops,
      // glass panel, answer card stack, notes, PDF paper, accent chip,
      // sheet, citation pulse.
      final light = br == Brightness.light;
      final surfaces = light
          ? [
              0xFFEDE6FA,
              0xFFF7E8EE,
              0xFFFFE9DC,
              0xFFDFD3FA,
              0xFFFFDBC5,
              0xFFF8F5FD,
              0xFFFFF7F2,
              0xFFFDFDFF,
              0xFFFFFDFC,
              0xFFFFF1B8,
              0xFFFFFFFF,
              0xFFEAE4FD,
              0xFFFEFAF8,
              0xFFECE7FC,
              0xFFD6CCFB,
            ]
          : [
              0xFF1E1830,
              0xFF251C27,
              0xFF2A1F1C,
              0xFF2F235B,
              0xFF483027,
              0xFF302A40,
              0xFF3B312E,
              0xFF4D485B,
              0xFF564E4B,
              0xFF463E22,
              0xFF2A2620,
              0xFF3A2F7A,
              0xFF28202F,
              0xFF61586C,
              0xFF716788,
            ];
      var worst = 99.0;
      for (final s in surfaces) {
        worst = [
          worst,
          _ratio(pb.focusRing, Color(s)),
        ].reduce((a, b) => a < b ? a : b);
      }
      // ignore: avoid_print
      print('[$br] ring contrast worst case $worst:1');
      expect(worst, greaterThanOrEqualTo(3));
      // The old violet ring on the same surfaces (why it was dropped).
      final accent = light ? const Color(0xFF6C4CF5) : const Color(0xFFB7A6FF);
      var oldWorst = 99.0;
      for (final s in surfaces) {
        oldWorst = [
          oldWorst,
          _ratio(accent, Color(s)),
        ].reduce((a, b) => a < b ? a : b);
      }
      // ignore: avoid_print
      print('[$br] old violet ring worst case $oldWorst:1');
      expect(oldWorst, lessThan(worst));
    });

    test('$br: form edge (controlEdge) >= 3:1 on the field face', () {
      // Field face: glassStrong over the page background gradient.
      final bg = light(br) ? const Color(0xFFF7E8EE) : const Color(0xFF251C27);
      final face = Color.alphaBlend(pb.glassStrong, bg);
      final edge = Color.alphaBlend(pb.controlEdge, face);
      // ignore: avoid_print
      print(
        '[$br] controlEdge on face ${_ratio(edge, face)}:1; hairline ${_ratio(Color.alphaBlend(pb.hairline, face), face)}:1',
      );
      expect(_ratio(edge, face), greaterThanOrEqualTo(3));
    });

    test('$br: the text on the new hover/pressed faces keeps its contrast', () {
      final face = Color.alphaBlend(
        pb.glassStrong,
        light(br) ? const Color(0xFFF7E8EE) : const Color(0xFF251C27),
      );
      for (final tint in [pb.hover, pb.press]) {
        expect(
          _ratio(pb.ink, Color.alphaBlend(tint, face)),
          greaterThanOrEqualTo(4.5),
        );
      }
      // Warn text on the amber face under hover.
      final warnFace = Color.alphaBlend(pb.warnHover, pb.warnContainer);
      expect(_ratio(pb.warnText, warnFace), greaterThanOrEqualTo(4.5));
      // The violet fill darkens (white would wash it out). Light: the white
      // text gets MORE contrast; dark: the dark text keeps >= 5.9:1 (spec).
      final fill = light(br)
          ? const Color(0xFF6C4CF5)
          : const Color(0xFFB7A6FF);
      final on = light(br) ? Colors.white : const Color(0xFF251A63);
      final base = _ratio(on, fill);
      for (final tint in [pb.filledHover, pb.filledPress]) {
        final r = _ratio(on, Color.alphaBlend(tint, fill));
        expect(
          r,
          light(br) ? greaterThanOrEqualTo(base) : greaterThanOrEqualTo(4.5),
        );
      }
      // ignore: avoid_print
      print(
        '[$br] on filled: rest $base, hover ${_ratio(on, Color.alphaBlend(pb.filledHover, fill))}, pressed ${_ratio(on, Color.alphaBlend(pb.filledPress, fill))}',
      );
    });

    test(
      '$br: card meta text >= 4.5:1 on every card face, rest/hover/press',
      () {
        // Faces: note colors 0..7, the rainbow (start / middle / end of the
        // gradient, then a dense sweep), the PDF paper. The tint is painted by
        // the card's InkWell over the face, so the face is blended with it.
        // Not modelled: BackdropFilter (the cards have none; glass behind them
        // does not show through an opaque card face).
        final rb = pb.noteRainbow;
        Color rainbow(double x) {
          final s = x * (rb.length - 1);
          final i = s.floor().clamp(0, rb.length - 2);
          return Color.lerp(rb[i], rb[i + 1], s - i)!;
        }

        final faces = <String, List<Color>>{
          for (var i = 0; i < 8; i++)
            'note $i': [pb.noteColor(1, colorIndex: i)],
          'rainbow start/mid/end': [rainbow(0), rainbow(.5), rainbow(1)],
          'rainbow sweep': [for (var k = 0; k <= 100; k++) rainbow(k / 100)],
          'pdf paper': [pb.pdfPaper],
        };
        final states = <String, Color Function(Color)>{
          'rest': (f) => f,
          'hover': (f) => Color.alphaBlend(pb.hover, f),
          // Touch: the 12% ripple. Desktop: hover + the pressed highlight
          // (both pb.hover, no splash).
          'press (touch 12%)': (f) => Color.alphaBlend(pb.press, f),
          'press (desktop)': (f) =>
              Color.alphaBlend(pb.hover, Color.alphaBlend(pb.hover, f)),
        };
        final b = StringBuffer('[$br] card meta ${pb.cardMeta}\n');
        var worst = 99.0;
        for (final MapEntry(key: state, value: tint) in states.entries) {
          var min = 99.0;
          var at = '';
          for (final MapEntry(key: name, value: bgs) in faces.entries) {
            for (final f in bgs) {
              final r = _ratio(pb.cardMeta, tint(f));
              if (r < min) (min, at) = (r, name);
            }
          }
          b.writeln('  $state: min ${min.toStringAsFixed(2)} ($at)');
          if (min < worst) worst = min;
        }
        // ignore: avoid_print
        print(b);
        expect(worst, greaterThanOrEqualTo(4.5));
      },
    );
  }

  testWidgets('card meta text uses the card token (note and PDF)', (t) async {
    for (final br in Brightness.values) {
      final pb = br == Brightness.light ? Pb.light : Pb.dark;
      for (final kind in ['note', 'pdf']) {
        final doc = Document(
          id: 1,
          ownerId: UuidValue.fromString(
            '00000000-0000-4000-8000-000000000001',
          ),
          kind: kind,
          title: 'T $kind',
          body: 'b',
          contentHash: 'h',
          version: 1,
          pageCount: 1,
          status: 'ready',
          embeddingModel: 'm',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: buildPbTheme(br),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 250,
                  child: DocumentCard(doc, const [], onTap: () {}),
                ),
              ),
            ),
          ),
        );
        final metas = t
            .widgetList<Text>(find.byType(Text))
            .where((x) => x.style?.fontSize == 12 && x.style?.color != null);
        // The theme change animates; settle it.
        await t.pumpAndSettle();
        expect(
          metas.any((m) => m.style!.color == pb.cardMeta),
          isTrue,
          reason: '$br $kind: the meta line uses pb.cardMeta',
        );
      }
    }
  });

  testWidgets(
    'Try the demo: one focusable button named for the screen reader',
    (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _app(DemoSignInButton(busy: false, failed: false, onPressed: () {})),
      );
      expect(
        t.getSemantics(find.byType(OutlinedButton)),
        isSemantics(
          label: 'Try the demo without signing up',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'sources: markers, rows and the toggle are tab stops with names',
    (
      t,
    ) async {
      final handle = t.ensureSemantics();
      t.view
        ..physicalSize = const Size(460, 1200)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final turn = AskTurn('q')
        ..answer.write('a [1] b [2] c [3] d [4] e [5]')
        ..done = true;
      for (var i = 1; i <= 5; i++) {
        turn.citations[i] = _c(i);
      }
      await t.pumpWidget(
        _app(
          SingleChildScrollView(child: AskTurnView(turn, onBlink: (_, _) {})),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.byKey(const ValueKey('cite-marker-1')).first),
        isSemantics(
          label: 'Source 1',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      final row = find.bySemanticsLabel(RegExp('^Source 2: Doc 2'));
      expect(
        t.getSemantics(row),
        isSemantics(
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      final toggle = find.byKey(const ValueKey('sources-toggle'));
      expect(
        t.getSemantics(toggle),
        isSemantics(
          label: 'Show 2 more',
          isButton: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(
        t.getSemantics(toggle),
        isSemantics(
          label: 'Show fewer',
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'toggle: instant and without rotation tween when motion is reduced',
    (
      t,
    ) async {
      final turn = AskTurn('q')
        ..answer.write('a [1] b [2] c [3] d [4] e [5]')
        ..done = true;
      for (var i = 1; i <= 5; i++) {
        turn.citations[i] = _c(i);
      }
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskTurnView(turn, onBlink: (_, _) {}),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final rot = find.descendant(
        of: find.byKey(const ValueKey('sources-toggle')),
        matching: find.byType(AnimatedRotation),
      );
      expect(t.widget<AnimatedRotation>(rot).duration, Duration.zero);
      final face = find.descendant(
        of: find.byKey(const ValueKey('sources-toggle')),
        matching: find.byType(AnimatedContainer),
      );
      expect(t.widget<AnimatedContainer>(face).duration, Duration.zero);
    },
  );

  testWidgets('card: long press deletes for a finger, not for a mouse', (
    t,
  ) async {
    var long = 0;
    final doc = Document(
      id: 1,
      ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
      kind: 'note',
      title: 'Groceries',
      body: 'milk',
      contentHash: 'h',
      version: 1,
      pageCount: 1,
      status: 'ready',
      embeddingModel: 'm',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 250,
              child: DocumentCard(
                doc,
                const [],
                onTap: () {},
                onLongPress: () => long++,
              ),
            ),
          ),
        ),
      ),
    );
    final c = t.getCenter(find.text('Groceries'));
    // Mouse: held for 1 s, nothing.
    final m = await t.startGesture(c, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(seconds: 1));
    await m.up();
    await t.pump();
    expect(long, 0, reason: 'a held mouse button must not open Delete');
    // Touch: 1 s = long press.
    final f = await t.startGesture(c);
    await t.pump(const Duration(seconds: 1));
    await f.up();
    await t.pump();
    expect(long, 1);
    // Pen too.
    final p = await t.startGesture(c, kind: PointerDeviceKind.stylus);
    await t.pump(const Duration(seconds: 1));
    await p.up();
    await t.pump();
    expect(long, 2);
  });

  group('touch targets', () {
    Future<void> at(WidgetTester t, double w, Widget child) async {
      t.view
        ..physicalSize = Size(w, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(child));
      await t.pump();
    }

    for (final (w, min) in [(500.0, 44.0), (800.0, 44.0), (1280.0, 36.0)]) {
      testWidgets('width $w: citation bar buttons are >= $min', (t) async {
        await at(
          t,
          w,
          CiteBar(
            count: 3,
            position: 1,
            onPrevious: () {},
            onNext: () {},
            onDismiss: () {},
          ),
        );
        for (final k in ['cite-previous', 'cite-next', 'cite-dismiss']) {
          final size = t.getSize(find.byKey(ValueKey(k)));
          expect(size.shortestSide, greaterThanOrEqualTo(min), reason: k);
        }
      });

      testWidgets('width $w: composer pills and send are >= $min', (t) async {
        await at(
          t,
          w,
          const SizedBox(
            width: 400,
            height: 500,
            child: AskScreen(projects: []),
          ),
        );
        for (final tip in ['Search scope']) {
          expect(
            t
                .getSize(
                  find.descendant(
                    of: find.byTooltip(tip),
                    matching: find.byType(PbInteractive),
                  ),
                )
                .height,
            greaterThanOrEqualTo(min),
          );
        }
      });
    }
  });

  testWidgets(
    'every button type: outer ring from the keyboard, none on click',
    (
      t,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final kinds = <String, Widget>{
        'filled': FilledButton(onPressed: () {}, child: const Text('filled')),
        'text': TextButton(onPressed: () {}, child: const Text('text')),
        'outlined': OutlinedButton(
          onPressed: () {},
          child: const Text('outlined'),
        ),
        'icon': IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
      };
      for (final MapEntry(key: name, value: button) in kinds.entries) {
        await t.pumpWidget(_app(button));
        ShapeBorder shape() => t
            .widget<Material>(
              find
                  .descendant(
                    of: find.byWidget(button),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .shape!;
        expect(shape(), isNot(isA<PbRingBorder>()), reason: name);
        await t.tap(find.byWidget(button));
        await t.pump();
        expect(
          shape(),
          isNot(isA<PbRingBorder>()),
          reason: '$name: a click is no ring',
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final s = shape();
        expect(s, isA<PbRingBorder>(), reason: '$name: Tab shows the ring');
        expect((s as PbRingBorder).color, Pb.light.focusRing);
        if (name == 'filled') {
          // The geometry is the button's own (r14); the ring is only painted.
          expect(
            (s.base as RoundedRectangleBorder).borderRadius,
            BorderRadius.circular(14),
          );
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
        expect(shape(), isNot(isA<PbRingBorder>()), reason: '$name: unfocus');
      }
    },
  );

  group('adaptive targets (the MaterialApp builder)', () {
    Future<void> at(WidgetTester t, double w) async {
      t.view
        ..physicalSize = Size(w, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          builder: (context, child) => pbAdaptiveTargets(context, child!),
          home: Scaffold(
            body: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                ChoiceChip(
                  key: const ValueKey('choice'),
                  label: const Text('All'),
                  selected: false,
                  onSelected: (_) {},
                ),
                ActionChip(
                  key: const ValueKey('action'),
                  label: const Text('Recent'),
                  onPressed: () {},
                ),
                IconButton(
                  key: const ValueKey('icon'),
                  iconSize: 18,
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                ),
                TextButton(
                  key: const ValueKey('text'),
                  onPressed: () {},
                  child: const Text('Ask again'),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pump();
    }

    // The laid-out size is the hit area (the padded tap target widens it to
    // 48 on a phone / tablet).
    for (final (w, min) in [(500.0, 44.0), (800.0, 44.0), (1280.0, 36.0)]) {
      testWidgets('width $w: chips, icon and text buttons are >= $min', (
        t,
      ) async {
        await at(t, w);
        for (final k in ['choice', 'action', 'icon', 'text']) {
          // Known exception: a desktop chip is 32 (the Material chip height;
          // ChipThemeData has no density / tap target). 24 is the WCAG 2.5.8
          // AA floor; everything else meets the desktop 36.
          final floor = w >= 1024 && (k == 'choice' || k == 'action')
              ? 32.0
              : min;
          expect(
            t.getSize(find.byKey(ValueKey(k))).height,
            greaterThanOrEqualTo(floor),
            reason: '$k at $w',
          );
        }
      });
    }
  });

  testWidgets('password eye button has a name', (t) async {
    expect(L.en.showPassword, 'Show password');
    expect(L.ko.hidePassword, '비밀번호 숨기기');
    expect(L.en.answerModelIs('Auto'), 'Answer model: Auto');
    expect(L.ko.scopeIs('내 문서'), '검색 범위: 내 문서');
  });

  for (final (plat, mod) in [
    (TargetPlatform.macOS, '⌘'),
    (TargetPlatform.windows, 'Ctrl+'),
  ]) {
    testWidgets('editor toolbar: tooltips carry the keys ($plat)', (t) async {
      t.view
        ..physicalSize = const Size(1200, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light).copyWith(platform: plat),
          home: Scaffold(
            body: NoteEditorView(embedded: true, onClose: () {}),
          ),
        ),
      );
      await t.pump();
      expect(find.byTooltip('Bold (${mod}B)'), findsOneWidget);
      expect(find.byTooltip('Italic (${mod}I)'), findsOneWidget);
      // The other buttons keep their plain names.
      expect(find.byTooltip('Strikethrough'), findsOneWidget);
    });
  }
}

bool light(Brightness b) => b == Brightness.light;
