import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/text_wrap.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_markers.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:pageblink_flutter/features/ask/ask_sources.dart';
import 'package:pageblink_flutter/features/ask/ask_suggestions.dart';
import 'package:pageblink_flutter/features/demo/demo.dart' show demoStatus;

Citation _c(int i, {String title = 'Doc', String kind = 'pdf'}) => Citation(
  index: i,
  documentId: i,
  documentTitle: '$title $i',
  kind: kind,
  page: i,
  quote: 'q',
);

/// The ⚡n marker is a WidgetSpan pill keyed `cite-marker-n`.
Future<void> _tapMarker(WidgetTester tester, int n) =>
    tester.tap(find.byKey(ValueKey('cite-marker-$n')).first);

BoxShadow? _glow(WidgetTester tester, int n) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(ValueKey('source-chip-$n')),
  );
  final shadows = (box.decoration as ShapeDecoration).shadows;
  return shadows == null || shadows.isEmpty ? null : shadows.first;
}

/// The row's own box (the keyed halo layer ignores pointers).
Future<void> _tapRow(WidgetTester tester, int n) => tester.tap(
  find
      .ancestor(
        of: find.byKey(ValueKey('source-chip-$n')),
        matching: find.byType(Stack),
      )
      .first,
);

Color _inner(WidgetTester tester, int n) {
  final stack = find
      .ancestor(
        of: find.byKey(ValueKey('source-chip-$n')),
        matching: find.byType(Stack),
      )
      .first;
  return tester
      .widget<Material>(
        find.descendant(of: stack, matching: find.byType(Material)).first,
      )
      .color!;
}

/// The row's resting colour: the neutral `rowFill`, for every kind.
Color _paper(WidgetTester tester, int n) => SourceTones.of(
  tester.element(find.byKey(ValueKey('source-chip-$n'))),
).rowFill;

/// The row's rainbow ring painter, null while the row shows no ring.
RainbowRingPainter? _ring(WidgetTester tester, int n) {
  final f = find.byKey(ValueKey('source-ring-$n'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<CustomPaint>(f).painter as RainbowRingPainter;
}

/// The thin ring around the `⚡n` pill.
RainbowRingPainter _markerRing(WidgetTester tester, int n) {
  final f = find.descendant(
    of: find.byKey(ValueKey('cite-marker-$n')).first,
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is RainbowRingPainter,
    ),
  );
  return tester.widget<CustomPaint>(f).painter as RainbowRingPainter;
}

List<BoxShadow> _halo(WidgetTester tester, int n) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(ValueKey('source-chip-$n')),
  );
  return ((box.decoration as ShapeDecoration).shadows ?? const [])
      .cast<BoxShadow>();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('renderMarkers', () {
    test('space before the marker; after only when no punctuation follows', () {
      expect(renderMarkers('a [1].'), 'a  [1].');
      expect(renderMarkers('a[1]다음'), 'a [1] 다음');
      expect(renderMarkers('끝[2]'), '끝 [2]');
      expect(renderMarkers('[1][2]다음'), ' [1]  [2] 다음');
      expect(renderMarkers('x [1] y'), 'x  [1] y');
      expect(renderMarkers('no markers [x] [123]'), 'no markers [x] [123]');
    });

    test('full-width 【n】 and ［n］ become the same [n] marker', () {
      expect(renderMarkers('a【1】다음'), 'a [1] 다음');
      expect(renderMarkers('끝［2］.'), '끝 [2].');
      expect(renderMarkers('【1】【2】'), ' [1]  [2]');
      expect(renderMarkers('【x】 [1】 【123】'), '【x】 [1】 【123】');
    });
  });

  group('citation flash', () {
    Future<AskTurn> pump(
      WidgetTester tester, {
      required String answer,
      bool reduced = false,
      void Function(List<Citation>, Citation)? onBlink,
      int count = 2,
      bool done = false,
      double width = 800,
      double textScale = 1,
      Brightness brightness = Brightness.light,
      Locale? locale,
      String title = 'Doc',
      AskTurn? same,
    }) async {
      final turn = same ?? AskTurn('q')
        ..answer.write(answer)
        ..done = done;
      for (var i = 1; i <= count && same == null; i++) {
        turn.citations[i] = _c(i, kind: i == 2 ? 'note' : 'pdf', title: title);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(brightness),
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: reduced,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: AskTurnView(turn, onBlink: onBlink ?? (_, _) {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return turn;
    }

    testWidgets('tapping ⚡1 pulses source 1 only, then keeps its ring', (
      t,
    ) async {
      await pump(t, answer: '첫째 [1] 그리고 둘째 [2].');
      expect(_glow(t, 1), isNull);
      expect(_ring(t, 1), isNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // inside the delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 20 + 200)); // first rise done
      expect(_glow(t, 1), isNotNull);
      expect(_glow(t, 2), isNull);
      expect(_inner(t, 1), isNot(_paper(t, 1)));
      await t.pump(const Duration(milliseconds: 340)); // trough
      expect(_glow(t, 1), isNotNull);
      await t.pump(const Duration(milliseconds: 220)); // second peak
      expect(_glow(t, 1), isNotNull);
      await t.pump(const Duration(milliseconds: 560)); // settle done
      await t.pumpAndSettle();
      // No end: the ring is still there, the inside is back to rowFill.
      expect(_glow(t, 1), isNotNull);
      expect(_ring(t, 1)!.strength, 1);
      expect(_inner(t, 1), _paper(t, 1));
      expect(_glow(t, 2), isNull);
      await t.pump(const Duration(seconds: 30));
      expect(_glow(t, 1), isNotNull);
      expect(_ring(t, 1)!.strength, 1);
    });

    testWidgets('a model that writes 【1】 and ［2］ still gets its chips', (
      t,
    ) async {
      await pump(t, answer: '첫째【1】 그리고 둘째［2］.');
      expect(_glow(t, 1), isNull);
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      expect(_ring(t, 1), isNotNull);
      expect(_ring(t, 2), isNull);
      await _tapMarker(t, 2);
      await t.pumpAndSettle();
      expect(_ring(t, 2), isNotNull);
    });

    testWidgets('resting ring: 12 pastel hues closed, one neutral shadow', (
      t,
    ) async {
      for (final b in Brightness.values) {
        final tones = b == Brightness.dark
            ? SourceTones.dark
            : SourceTones.light;
        await pump(t, answer: '[1]', brightness: b);
        await _tapMarker(t, 1);
        await t.pumpAndSettle();
        final r = _ring(t, 1)!;
        expect(r.colors, hasLength(13), reason: '$b');
        expect(r.colors.first, r.colors.last, reason: '$b closed');
        expect(r.colors, tones.rainbowClosed, reason: '$b palette');
        expect({...tones.rainbow}, hasLength(12), reason: '$b distinct');
        expect(r.strength, 1);
        expect(r.sweep, 0);
        expect(r.tightAlpha, tones.ringTight);
        expect(r.wideAlpha, tones.ringWide);
        // One shadow, no hue.
        final h = _halo(t, 1);
        expect(h, hasLength(1), reason: '$b');
        expect(HSLColor.fromColor(h.single.color).saturation, 0);
        expect(_inner(t, 1), _paper(t, 1));
      }
      // Light and dark tell the hues apart (dark is a step lighter).
      expect(SourceTones.light.rainbow, isNot(SourceTones.dark.rainbow));
    });

    testWidgets('the beats follow the timeline (not monotonic)', (t) async {
      expect(sourceFx(0).halo, 0);
      expect(sourceFx(0.05).fill, 0); // 72ms, in the delay
      double at(double ms) => ms / sourceFlashDuration.inMilliseconds;
      final peak = sourceFx(at(320)); // 120 + 200
      final trough = sourceFx(at(660)); // + 340
      final peak2 = sourceFx(at(880)); // + 220
      expect(peak.fill, closeTo(1, 0.01));
      expect(peak.halo, closeTo(0.55, 0.01));
      expect(trough.fill, closeTo(0.35, 0.01));
      expect(trough.halo, closeTo(0.30, 0.01));
      expect(peak2.fill, closeTo(0.85, 0.01));
      expect(peak2.halo, closeTo(0.60, 0.01));
      final mid = sourceFx(at(880 + 238)); // light at its brightest
      expect(mid.bloomAlpha, closeTo(1, 0.01));
      expect(mid.bloom, inInclusiveRange(0.5, 1));
      expect(mid.fill, lessThan(peak2.fill));
      expect(mid.halo, inInclusiveRange(0.6, 1));
      expect(mid.sweep, lessThan(0)); // still turning
      final end = sourceFx(1);
      expect(end.fill, 0);
      expect(end.bloomAlpha, 0);
      expect(end.halo, 1);
      expect(end.sweep, 0);
      // 120 + 200 + 340 + 220 + 560.
      expect(sourceFlashDuration.inMilliseconds, 1440);
      expect(sourceFlashLead.inMilliseconds, 120);
      // The same source again: the ring never leaves 1.0.
      for (final ms in <double>[0, 100, 320, 660, 880, 1100, 1440]) {
        expect(sourceFx(at(ms), replay: true).halo, 1, reason: '$ms');
      }
    });

    testWidgets('at the end of the first rise: fill 1 and ring 0.55', (
      t,
    ) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120 + 200));
      expect(sourceFx(320 / 1440).fill, closeTo(1, 0.01));
      expect(_ring(t, 1)!.strength, closeTo(0.55, 0.02));
      expect(_halo(t, 1), hasLength(1)); // one neutral shadow while picked
      await t.pumpAndSettle();
    });

    testWidgets('the centre-out light is drawn only during the settle', (
      t,
    ) async {
      await pump(t, answer: '[1]');
      int blooms() => t
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find
                  .ancestor(
                    of: find.byKey(const ValueKey('source-chip-1')),
                    matching: find.byType(Stack),
                  )
                  .first,
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((b) {
            final d = b.decoration;
            return d is BoxDecoration && d.gradient is RadialGradient;
          })
          .length;
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120 + 200 + 340 + 220 + 100));
      expect(blooms(), 1);
      await t.pumpAndSettle();
      expect(blooms(), 0);
    });

    testWidgets('picking another source fades the old ring out in 200ms', (
      t,
    ) async {
      await pump(t, answer: '[1] [2]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_ring(t, 1)!.strength, 1);
      await _tapMarker(t, 2);
      await t.pump();
      // Not at once: it is still there and going out.
      expect(_ring(t, 1)!.strength, closeTo(1, 0.01));
      await t.pump(const Duration(milliseconds: 100));
      final mid = _ring(t, 1)!.strength;
      expect(mid, inExclusiveRange(0.0, 1.0));
      expect(_ring(t, 2), isNull); // the new row is still in its 120ms delay
      await t.pump(const Duration(milliseconds: 50));
      expect(_ring(t, 1)!.strength, lessThan(mid));
      expect(_ring(t, 2)!.strength, greaterThan(0)); // 150ms: it has begun
      await t.pump(const Duration(milliseconds: 60)); // 210ms: old ring gone
      expect(_ring(t, 1), isNull);
      expect(_glow(t, 1), isNull);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
      expect(_glow(t, 2), isNotNull);
      // Row tap: same effect.
      await _tapRow(t, 1);
      await t.pump();
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_glow(t, 2), isNull);
    });

    testWidgets('the picked number\'s marker rests a little deeper', (t) async {
      await pump(t, answer: '[1] [2]');
      Color fill(int n) {
        final box = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(ValueKey('cite-marker-$n')).first,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as ShapeDecoration).color!;
      }

      final tones = SourceTones.light;
      final rest = fill(1), rest2 = fill(2);
      expect(rest, tones.pill);
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      // Black 14% over the pill, never accent.
      expect(
        fill(1),
        Color.alphaBlend(
          const Color(0xFF000000).withValues(alpha: 0.14),
          tones.pill,
        ),
      );
      // The light pill is translucent (tile tone): deeper = more alpha.
      expect(fill(1).a, greaterThan(rest.a));
      expect(fill(2), rest2);
      expect(_markerRing(t, 1).strength, closeTo(0.65, 0.001));
      expect(_markerRing(t, 2).strength, 0);
      await _tapMarker(t, 2);
      await t.pumpAndSettle();
      expect(fill(1), rest);
      expect(fill(2), isNot(rest2));
      expect(_markerRing(t, 1).strength, 0);
      expect(_markerRing(t, 2).strength, closeTo(0.65, 0.001));
    });

    testWidgets('another turn in the same slot starts without a halo', (
      t,
    ) async {
      final first = await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      final second = AskTurn('q2')
        ..answer.write('[1]')
        ..done = true
        ..citations[1] = _c(1);
      expect(identical(first, second), isFalse);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskTurnView(second, onBlink: (_, _) {}),
            ),
          ),
        ),
      );
      expect(_glow(t, 1), isNull);
      expect(t.takeException(), isNull);
    });

    testWidgets('a rebuild of the same turn keeps the halo', (t) async {
      final turn = await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      turn.answer.write(' more');
      await pump(t, answer: '', same: turn);
      expect(_glow(t, 1), isNotNull);
      expect(find.textContaining('more', findRichText: true), findsOneWidget);
    });

    testWidgets('the pressed marker answers with a short ack, then rests', (
      t,
    ) async {
      await pump(t, answer: '[1] [2]');
      Color fill(int n) {
        final box = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(ValueKey('cite-marker-$n')).first,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as ShapeDecoration).color!;
      }

      double scale(int n) => t
          .widget<Transform>(
            find
                .descendant(
                  of: find.byKey(ValueKey('cite-marker-$n')).first,
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();

      final rest = fill(1), rest2 = fill(2);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120)); // ack peak
      expect(scale(1), closeTo(1.08, 0.001));
      expect(_markerRing(t, 1).strength, closeTo(1, 0.001));
      // The light pill is translucent (tile tone): deeper = more alpha.
      expect(fill(1).a, greaterThan(rest.a));
      expect(scale(2), 1);
      expect(fill(2), rest2);
      await t.pumpAndSettle();
      // The ack is over; what stays is the picked tint, nowhere near accent.
      expect(scale(1), 1);
      expect(fill(1), isNot(t.element(find.byType(Scaffold)).pb.accent));
      expect(fill(1), isNot(rest)); // picked: deeper, but still grey
      expect(fill(2), rest2);
    });

    testWidgets('unknown number does nothing and does not throw', (t) async {
      await pump(t, answer: '있는 [1] 없는 [7]');
      await _tapMarker(t, 7);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
      expect(t.takeException(), isNull);
    });

    testWidgets('a citation that arrives later makes the marker work', (
      t,
    ) async {
      final turn = await pump(t, answer: '나중 [3]');
      await _tapMarker(t, 3);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      turn.citations[3] = _c(3);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskTurnView(turn, onBlink: (_, _) {}),
            ),
          ),
        ),
      );
      await _tapMarker(t, 3);
      await t.pump();
      await t.pump(const Duration(milliseconds: 440));
      expect(_glow(t, 3), isNotNull);
      await t.pumpAndSettle();
    });

    testWidgets('tapping again mid-pulse restarts it', (t) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(_glow(t, 1), isNotNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // back in the delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 20 + 200));
      expect(_glow(t, 1), isNotNull);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
    });

    testWidgets('tapping the picked source again replays from its ring', (
      t,
    ) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // in the delay
      expect(_glow(t, 1), isNotNull); // never goes out
      expect(_ring(t, 1)!.strength, 1);
      expect(_inner(t, 1), _paper(t, 1));
      await t.pump(const Duration(milliseconds: 20 + 200));
      expect(_inner(t, 1), isNot(_paper(t, 1))); // played again
      expect(_ring(t, 1)!.strength, 1);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_inner(t, 1), _paper(t, 1));
    });

    testWidgets('reduced motion: resting ring at once, no ramp or fade', (
      t,
    ) async {
      await pump(t, answer: '[1] [2]', reduced: true);
      await _tapMarker(t, 1);
      await t.pump();
      expect(_glow(t, 1), isNotNull);
      expect(_ring(t, 1)!.strength, 1);
      expect(_ring(t, 1)!.sweep, 0);
      expect(_inner(t, 1), _paper(t, 1));
      await t.pump(const Duration(milliseconds: 300));
      expect(_ring(t, 1)!.strength, 1);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_halo(t, 1), hasLength(1));
      // Another source: the old ring is gone at once, the new one is settled.
      await _tapMarker(t, 2);
      await t.pump();
      expect(_ring(t, 1), isNull);
      expect(_ring(t, 2)!.strength, 1);
      await t.pumpAndSettle();
    });

    testWidgets('the ring spills 8px vertically, 12 (1 column) / 8 (2) wide', (
      t,
    ) async {
      for (final (w, side) in [(390.0, 12.0), (800.0, 8.0)]) {
        await pump(t, answer: '[1]', width: w);
        await _tapMarker(t, 1);
        await t.pumpAndSettle();
        final clip = t.widget<ClipPath>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('source-chip-1')),
                matching: find.byType(ClipPath),
              )
              .first,
        );
        final size = t.getSize(find.byKey(const ValueKey('source-chip-1')));
        final b = clip.clipper!.getClip(size).getBounds();
        expect(b.top, closeTo(-8, 0.01), reason: 'width $w');
        expect(b.bottom, closeTo(size.height + 8, 0.01), reason: 'width $w');
        expect(b.left, closeTo(-side, 0.01), reason: 'width $w');
        expect(b.right, closeTo(size.width + side, 0.01), reason: 'width $w');
        // The row is 8px from the next one: no overlap with its inside.
      }
    });

    testWidgets('selected is true at once for the row and the marker only', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await pump(t, answer: '[1] [2]', locale: const Locale('en'));
      SemanticsNode row(int n) => t.getSemantics(
        find.bySemanticsLabel(
          n == 1 ? 'Source 1: Doc 1, PDF page 1' : 'Source 2: Doc 2, note',
        ),
      );
      SemanticsNode marker(int n) =>
          t.getSemantics(find.bySemanticsLabel('Source $n').first);
      expect(row(1), isNot(isSemantics(isSelected: true)));
      await _tapMarker(t, 1);
      await t.pump(); // before the animation has started
      expect(row(1), isSemantics(isSelected: true));
      expect(marker(1), isSemantics(isSelected: true));
      expect(row(2), isNot(isSemantics(isSelected: true)));
      expect(marker(2), isNot(isSemantics(isSelected: true)));
      await t.pumpAndSettle();
      await _tapRow(t, 2);
      await t.pump();
      expect(row(2), isSemantics(isSelected: true));
      expect(marker(2), isSemantics(isSelected: true));
      expect(row(1), isNot(isSemantics(isSelected: true)));
      expect(marker(1), isNot(isSemantics(isSelected: true)));
      await t.pumpAndSettle();
      h.dispose();
    });

    testWidgets('tapping the source row still calls onBlink', (t) async {
      Citation? opened;
      await pump(t, answer: '[1] [2]', onBlink: (all, c) => opened = c);
      await _tapRow(t, 2);
      expect(opened?.index, 2);
      await t.pumpAndSettle();
      expect(_glow(t, 2), isNotNull);
      expect(_glow(t, 1), isNull);
    });
  });

  group('sources list', () {
    Future<AskTurn> pumpTurn(
      WidgetTester t, {
      required int count,
      required bool done,
      double width = 390,
      double textScale = 1,
      Brightness brightness = Brightness.light,
      Locale? locale,
      String Function(int i)? title,
      String answer = '[1]',
    }) async {
      final turn = AskTurn('q')
        ..answer.write(answer)
        ..done = done;
      for (var i = 1; i <= count; i++) {
        turn.citations[i] = Citation(
          index: i,
          documentId: i,
          documentTitle: title?.call(i) ?? 'Doc $i',
          kind: i.isEven ? 'note' : 'pdf',
          page: i + 2,
          quote: 'q',
        );
      }
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(brightness),
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: AskTurnView(turn, onBlink: (_, _) {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return turn;
    }

    Finder row(int n) => find.byKey(ValueKey('source-chip-$n'));

    testWidgets('4 sources show all, no toggle', (t) async {
      await pumpTurn(t, count: 4, done: true);
      for (var i = 1; i <= 4; i++) {
        expect(row(i), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('sources-toggle')), findsNothing);
    });

    testWidgets('5 sources: 3 rows + "Show 2 more"; tap unfolds, again folds', (
      t,
    ) async {
      await pumpTurn(t, count: 5, done: true);
      expect(row(3), findsOneWidget);
      expect(row(4), findsNothing);
      expect(find.text('Show 2 more'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sources-toggle')));
      await t.pumpAndSettle();
      expect(row(5), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sources-toggle')));
      await t.pumpAndSettle();
      expect(row(4), findsNothing);
    });

    testWidgets('while streaming (not done) nothing is folded', (t) async {
      await pumpTurn(t, count: 5, done: false);
      expect(row(5), findsOneWidget);
      expect(find.byKey(const ValueKey('sources-toggle')), findsNothing);
    });

    testWidgets('a marker for a folded source unfolds first, then flashes', (
      t,
    ) async {
      await pumpTurn(t, count: 5, done: true, answer: '다섯째 [5]');
      expect(row(5), findsNothing);
      await _tapMarker(t, 5);
      await t.pump(); // unfold
      await t.pump(); // frame after unfold, flash armed
      expect(row(5), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      expect(_glow(t, 5), isNotNull);
      expect(_glow(t, 1), isNull);
      await t.pumpAndSettle();
      expect(_glow(t, 5), isNotNull); // keeps its ring
      expect(find.text('Show fewer'), findsOneWidget);
      // Fold: the row is gone, the pick is kept; unfold shows it again.
      await t.tap(find.byKey(const ValueKey('sources-toggle')));
      await t.pumpAndSettle();
      expect(row(5), findsNothing);
      await t.tap(find.byKey(const ValueKey('sources-toggle')));
      await t.pumpAndSettle();
      expect(_glow(t, 5), isNotNull);
      expect(_inner(t, 5), _paper(t, 5));
    });

    testWidgets('1 column below 488 inner width, 2 columns from it', (t) async {
      for (final w in [380.0, 390.0, 560.0]) {
        await pumpTurn(t, count: 2, done: true, width: w);
        expect(
          t.getTopLeft(row(2)).dx,
          t.getTopLeft(row(1)).dx,
          reason: 'width $w',
        );
      }
      // inner = 600 * 0.92 - 32 = 520 >= 488
      await pumpTurn(t, count: 2, done: true, width: 600);
      expect(t.getTopLeft(row(2)).dx, greaterThan(t.getTopLeft(row(1)).dx));
      expect(t.getTopLeft(row(2)).dy, t.getTopLeft(row(1)).dy);
    });

    testWidgets('long titles ellipsize without overflow (widths x scales)', (
      t,
    ) async {
      final long = List.filled(12, '매우 긴 문서 제목 Quarterly Budget').join(' ');
      for (final w in [320.0, 380.0, 390.0, 600.0]) {
        for (final s in [1.0, 1.5]) {
          await pumpTurn(
            t,
            count: 6,
            done: true,
            width: w,
            textScale: s,
            title: (_) => long,
            answer: '[1] [2]',
          );
          expect(t.takeException(), isNull, reason: 'width $w scale $s');
          expect(t.getSize(row(1)).height, lessThan(120), reason: '$w $s');
        }
      }
    });

    testWidgets('secondary line follows the language', (t) async {
      await pumpTurn(t, count: 2, done: true, locale: const Locale('ko'));
      expect(find.text('PDF · 3쪽'), findsOneWidget);
      expect(find.text('노트'), findsOneWidget);
      await pumpTurn(t, count: 2, done: true, locale: const Locale('en'));
      expect(find.text('PDF · Page 3'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
    });

    testWidgets('semantic labels: "출처 1: 제목, PDF 3쪽" / "Source 2: …, note"', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await pumpTurn(t, count: 2, done: true, locale: const Locale('ko'));
      expect(find.bySemanticsLabel('출처 1: Doc 1, PDF 3쪽'), findsOneWidget);
      expect(find.bySemanticsLabel('출처 2: Doc 2, 노트'), findsOneWidget);
      await pumpTurn(t, count: 2, done: true, locale: const Locale('en'));
      expect(
        find.bySemanticsLabel('Source 1: Doc 1, PDF page 3'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Source 2: Doc 2, note'), findsOneWidget);
      h.dispose();
    });

    testWidgets('dark theme builds; marker pill is no taller than 18', (
      t,
    ) async {
      await pumpTurn(
        t,
        count: 5,
        done: true,
        brightness: Brightness.dark,
        answer: '글 [1] [2]',
      );
      expect(t.takeException(), isNull);
      final size = t.getSize(find.byKey(const ValueKey('cite-marker-1')).first);
      expect(size.height, lessThanOrEqualTo(18));
    });
  });

  group('source colours (neutral rows, slate pill with a yellow bolt)', () {
    Future<AskTurn> pumpKinds(
      WidgetTester t,
      List<Citation> cs, {
      Brightness brightness = Brightness.light,
      String answer = '[1] [2] [3]',
      AskTurn? same,
    }) async {
      final turn = same ?? AskTurn('q')
        ..answer.write(answer)
        ..done = true;
      if (same == null) {
        for (final c in cs) {
          turn.citations[c.index] = c;
        }
      }
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(brightness),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AskTurnView(turn, onBlink: (_, _) {}),
            ),
          ),
        ),
      );
      await t.pumpAndSettle(); // the rows' Material animates a theme change
      return turn;
    }

    Citation cite(int i, int doc, String kind) => Citation(
      index: i,
      documentId: doc,
      documentTitle: 'Doc $doc',
      kind: kind,
      page: 1,
      quote: 'q',
    );

    Color markerFill(WidgetTester t, int n) {
      final box = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(ValueKey('cite-marker-$n')).first,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as ShapeDecoration).color!;
    }

    BoltPainter bolt(WidgetTester t, int n) =>
        t
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byKey(ValueKey('cite-marker-$n')).first,
                        matching: find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is BoltPainter,
                        ),
                      )
                      .first,
                )
                .painter
            as BoltPainter;

    testWidgets('notes and PDFs share one neutral row colour: rowFill', (
      t,
    ) async {
      for (final b in Brightness.values) {
        final tones = b == Brightness.dark
            ? SourceTones.dark
            : SourceTones.light;
        // Documents 5 and 8 used to land on different pastels.
        await pumpKinds(t, [
          cite(1, 5, 'note'),
          cite(2, 8, 'note'),
          cite(3, 5, 'pdf'),
        ], brightness: b);
        for (final n in [1, 2, 3]) {
          expect(_inner(t, n), tones.rowFill, reason: '$b row $n');
        }
      }
      // Light is opaque (a neighbour's glow does not show through).
      expect(SourceTones.light.rowFill.a, 1);
    });

    testWidgets('the kind shows in the icon and the second line only', (
      t,
    ) async {
      await pumpKinds(t, [cite(1, 5, 'note'), cite(2, 8, 'pdf')]);
      Finder icons(int n) => find.descendant(
        of: find.ancestor(
          of: find.byKey(ValueKey('source-chip-$n')),
          matching: find.byType(Stack),
        ),
        matching: find.byType(Icon),
      );
      IconData kindIcon(int n) => t.widget<Icon>(icons(n).at(0)).icon!;
      expect(kindIcon(1), isNot(kindIcon(2)));
      expect(t.widget<Icon>(icons(1).at(0)).size, 14);
      expect(t.widget<Icon>(icons(1).at(0)).color, SourceTones.light.sub);
      expect(find.text('노트'), findsNothing); // default locale is English
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('PDF · Page 1'), findsOneWidget);
    });

    testWidgets('a picked row settles back to rowFill', (t) async {
      for (final n in [1, 2]) {
        await pumpKinds(t, [cite(1, 5, 'note'), cite(2, 3, 'pdf')]);
        final rest = _inner(t, n);
        await _tapMarker(t, n);
        await t.pump();
        await t.pump(const Duration(milliseconds: 120 + 200));
        await t.pump(const Duration(milliseconds: 250)); // past the fade
        expect(_inner(t, n), isNot(rest));
        await t.pumpAndSettle();
        expect(_inner(t, n), rest);
        expect(_glow(t, n), isNotNull);
      }
    });

    testWidgets('the border of a picked row stays at the selected grey', (
      t,
    ) async {
      for (final b in Brightness.values) {
        final tones = b == Brightness.dark
            ? SourceTones.dark
            : SourceTones.light;
        await pumpKinds(t, [cite(1, 5, 'note')], answer: '[1]', brightness: b);
        Color border() {
          final stack = find
              .ancestor(
                of: find.byKey(const ValueKey('source-chip-1')),
                matching: find.byType(Stack),
              )
              .first;
          final m = t.widget<Material>(
            find.descendant(of: stack, matching: find.byType(Material)).first,
          );
          return ((m.shape as RoundedRectangleBorder).side).color;
        }

        expect(border(), tones.rowBorder, reason: '$b');
        await _tapMarker(t, 1);
        await t.pumpAndSettle();
        expect(border(), tones.rowBorderSelected, reason: '$b');
      }
    });

    testWidgets('the pulse only rises towards rowPulse', (t) async {
      await pumpKinds(t, [cite(1, 5, 'note')], answer: '[1]');
      const tones = SourceTones.light;
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120 + 200)); // peak, fill 1.0
      // The Material animates colour changes: let it catch up (still inside
      // the 340ms dip, where the fill is between 1.0 and 0.35).
      await t.pump(const Duration(milliseconds: 100));
      final c = _inner(t, 1);
      // Between rowFill and rowPulse on every channel (no detour).
      for (final ch in [
        (tones.rowFill.r, tones.rowPulse.r, c.r),
        (tones.rowFill.g, tones.rowPulse.g, c.g),
        (tones.rowFill.b, tones.rowPulse.b, c.b),
      ]) {
        final lo = ch.$1 < ch.$2 ? ch.$1 : ch.$2;
        final hi = ch.$1 < ch.$2 ? ch.$2 : ch.$1;
        expect(ch.$3, inInclusiveRange(lo - 0.01, hi + 0.01));
      }
      await t.pumpAndSettle();
    });

    testWidgets('every pill is the same slate with a yellow bolt', (t) async {
      for (final b in Brightness.values) {
        final tones = b == Brightness.dark
            ? SourceTones.dark
            : SourceTones.light;
        // 1 and 2 arrived (note, PDF); 3 has no source yet.
        await pumpKinds(t, [
          cite(1, 5, 'note'),
          cite(2, 3, 'pdf'),
        ], brightness: b);
        for (final n in [1, 2, 3]) {
          expect(markerFill(t, n), tones.pill, reason: '$b $n');
          expect(bolt(t, n).color, tones.bolt, reason: '$b $n');
        }
        // Slate: a grey with a hair of blue.
        final f = markerFill(t, 1);
        expect(f, tones.pill);
        expect(f.b - f.r, lessThan(0.08), reason: '$b');
        // The bolt is yellow (hue 35..55), not orange.
        final hue = HSLColor.fromColor(tones.bolt).hue;
        expect(hue, inInclusiveRange(35, 55), reason: '$b $hue');
        // The digit is the tone's own (dark ink on light), 12 / w600.
        final digit = t.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('cite-marker-1')).first,
                matching: find.text('1'),
              )
              .first,
        );
        expect(digit.style!.color, tones.digit, reason: '$b');
        expect(digit.style!.fontSize, 12);
        expect(digit.style!.fontWeight, FontWeight.w600);
      }
    });

    testWidgets('the source row badge matches the pill', (t) async {
      await pumpKinds(t, [cite(1, 5, 'note')], answer: '[1]');
      final badge = t.widget<Container>(
        find
            .descendant(
              of: find.ancestor(
                of: find.byKey(const ValueKey('source-chip-1')),
                matching: find.byType(Stack),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (badge.decoration as BoxDecoration).color,
        SourceTones.light.pill,
      );
    });

    testWidgets('a source arriving later does not recolour its pill', (
      t,
    ) async {
      final turn = await pumpKinds(t, [cite(1, 5, 'note')], answer: '[1] [2]');
      final before = markerFill(t, 2);
      turn.citations[2] = cite(2, 3, 'pdf');
      await pumpKinds(t, const [], same: turn);
      await t.pump();
      expect(markerFill(t, 2), before);
      expect(markerFill(t, 1), before);
    });

    test('contrast: digit, bolt, secondary text, title, selected border', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      for (final dark in [false, true]) {
        final pb = dark ? Pb.dark : Pb.light;
        final tones = dark ? SourceTones.dark : SourceTones.light;
        // The answer bubble is glassStrong over the page gradient; test every
        // stop (rows add their own face on top).
        for (final page in [pb.bgStart, pb.bgMid, pb.bgEnd]) {
          final bubble = Color.alphaBlend(pb.glassStrong, page);
          final row = Color.alphaBlend(tones.rowFill, bubble);
          final pulse = Color.alphaBlend(tones.rowPulse, bubble);
          for (final bg in [row, pulse]) {
            expect(
              contrastRatio(pb.ink, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'title $dark $bg',
            );
            expect(
              contrastRatio(tones.sub, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'sub $dark $bg',
            );
          }
          // The state signal: the selected border against the bubble, and
          // the row's own face for the part inside the border.
          expect(
            contrastRatio(tones.rowBorderSelected, bubble),
            greaterThanOrEqualTo(3),
            reason: 'selected border $dark $page',
          );
          // The badge digit on the pill, over the bubble and over a row face.
          for (final under in [bubble, row, pulse]) {
            expect(
              contrastRatio(tones.digit, Color.alphaBlend(tones.pill, under)),
              greaterThanOrEqualTo(4.5),
              reason: 'badge $dark $under',
            );
          }
        }
        // Pill states: rest, hover, press, picked, ack (composited over the
        // bubble: the light pill is translucent). Pressing only darkens, so
        // the digit and the bolt get better, never worse.
        final bubble = Color.alphaBlend(pb.glassStrong, pb.bgMid);
        final m = tones.markerAlpha;
        final states = [
          for (final a in [0.0, m.hover, m.press, m.picked, m.ack])
            Color.alphaBlend(
              Color.alphaBlend(
                tones.markerOverlay.withValues(alpha: a),
                tones.pill,
              ),
              bubble,
            ),
        ];
        for (final f in states) {
          expect(
            contrastRatio(tones.digit, f),
            greaterThanOrEqualTo(4.5),
            reason: 'digit $dark $f',
          );
          // Graphic object: 3:1. Light: the bolt's dark outline carries the
          // shape (a yellow fill alone is ~1.3:1 on the pale pill).
          expect(
            contrastRatio(tones.boltOutline ?? tones.bolt, f),
            greaterThanOrEqualTo(3),
            reason: 'bolt $dark $f',
          );
        }
        // The pill is told apart from the bubble (light: a tile is a quiet
        // 1.17:1 step, which is what the client asked for).
        expect(
          contrastRatio(states.first, bubble),
          greaterThanOrEqualTo(dark ? 1.5 : 1.1),
        );
      }
      // Light pill IS the sidebar tile tone (client: "grey chip still too
      // dark; as light as the tier icon background"): one value, `Pb.tile`.
      const light = SourceTones.light;
      expect(light.pill, Pb.light.tile);
      // A step darker than the row face, so the badge shows inside the row
      // (never inverted), over every page stop.
      for (final page in [Pb.light.bgStart, Pb.light.bgMid, Pb.light.bgEnd]) {
        final bubble = Color.alphaBlend(Pb.light.glassStrong, page);
        final row = Color.alphaBlend(light.rowFill, bubble);
        final pulse = Color.alphaBlend(light.rowPulse, bubble);
        for (final face in [bubble, row, pulse]) {
          expect(
            Color.alphaBlend(light.pill, face).computeLuminance(),
            lessThan(face.computeLuminance()),
          );
        }
      }
      expect(light.boltOutline, isNotNull);
      expect(SourceTones.dark.boltOutline, isNull);
      // Neutral: no orange/yellow in the pill (ink tint, not blue, not warm).
      expect((light.pill.r - light.pill.b).abs(), lessThan(0.08));
      {}
    });
  });

  group('the end state is the rest colour (no residual whiteness)', () {
    // d509b49: the centre-out light was pure white at 80% (light) / 30% (dark),
    // spread over the whole row and only reached 0 at the very last frame, so
    // the inside ended brighter than it rested (dark: ~2x). Here the light is a
    // soft neutral, capped, and out before the settle ends.
    const pad = 24.0, rowW = 300.0;
    final citation = _c(1);

    Future<(Uint8List, int, Size)> shot(
      WidgetTester t,
      Brightness b,
      SourceFx fx,
    ) async {
      final key = GlobalKey();
      final pb = b == Brightness.dark ? Pb.dark : Pb.light;
      final bubble = Color.alphaBlend(pb.glassStrong, pb.bgMid);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(b),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: bubble,
                  child: Padding(
                    padding: const EdgeInsets.all(pad),
                    child: SizedBox(
                      width: rowW,
                      child: SourceRow(
                        citation: citation,
                        fx: fx,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1)); // the Material catches up
      final rowSize = t.getSize(find.byType(Material).last);
      late Uint8List bytes;
      late int width;
      await t.runAsync(() async {
        final r =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await r.toImage(pixelRatio: 1);
        width = img.width;
        bytes = (await img.toByteData())!.buffer.asUint8List();
      });
      return (bytes, width, rowSize);
    }

    List<int> px(Uint8List d, int w, int x, int y) {
      final o = (y * w + x) * 4;
      return [d[o], d[o + 1], d[o + 2]];
    }

    /// Whole pixels inside the row, 2px in from its border (text and icons
    /// included, they are identical in every state).
    Iterable<(int, int)> inside(Size row) sync* {
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, pad, row.width, row.height),
        const Radius.circular(14),
      ).deflate(2);
      for (var y = pad.toInt(); y < (pad + row.height).toInt(); y++) {
        for (var x = pad.toInt(); x < (pad + row.width).toInt(); x++) {
          if (rr.contains(Offset(x + 0.5, y + 0.5))) yield (x, y);
        }
      }
    }

    for (final b in Brightness.values) {
      testWidgets('settled row interior == rest, ring only outside ($b)', (
        t,
      ) async {
        final (rest, w, row) = await shot(t, b, SourceFx.none);
        final (done, _, _) = await shot(t, b, SourceFx.settled);
        // The row's face is the rest colour at the centre and in the corners.
        final tones = b == Brightness.dark
            ? SourceTones.dark
            : SourceTones.light;
        final pb = b == Brightness.dark ? Pb.dark : Pb.light;
        final face = Color.alphaBlend(
          tones.rowFill,
          Color.alphaBlend(pb.glassStrong, pb.bgMid),
        );
        int ch(double v) => (v * 255).round();
        for (final p in [
          (pad.toInt() + 6, pad.toInt() + 6), // corner
          (pad.toInt() + rowW.toInt() - 7, pad.toInt() + 6),
          (pad.toInt() + 6, pad.toInt() + row.height.toInt() - 7),
          (pad.toInt() + 150, pad.toInt() + 5), // top middle
        ]) {
          final c = px(done, w, p.$1, p.$2);
          expect(c[0], closeTo(ch(face.r), 1), reason: '$b $p r');
          expect(c[1], closeTo(ch(face.g), 1), reason: '$b $p g');
          expect(c[2], closeTo(ch(face.b), 1), reason: '$b $p b');
        }
        // Every pixel inside the row is the same as at rest (1/255).
        var worst = 0;
        for (final (x, y) in inside(row)) {
          final a = px(rest, w, x, y), c = px(done, w, x, y);
          for (var k = 0; k < 3; k++) {
            worst = worst > (a[k] - c[k]).abs() ? worst : (a[k] - c[k]).abs();
          }
        }
        expect(worst, lessThanOrEqualTo(1), reason: '$b interior differs');
        // The ring is really there: pixels just outside differ from the page.
        var outside = 0;
        for (var x = pad.toInt(); x < pad + rowW; x += 7) {
          final above = px(done, w, x, pad.toInt() - 4);
          final plain = px(rest, w, x, pad.toInt() - 4);
          if ((above[0] - plain[0]).abs() +
                  (above[1] - plain[1]).abs() +
                  (above[2] - plain[2]).abs() >
              6) {
            outside++;
          }
        }
        expect(outside, greaterThan(10), reason: '$b ring missing outside');
      });

      testWidgets('the light never makes the row whiter than the cap ($b)', (
        t,
      ) async {
        // Out before the settle ends, at every step after it.
        expect(
          sourceFx((880 + 560 * 0.85) / 1440).bloomAlpha,
          closeTo(0, 1e-9),
        );
        expect(
          sourceFx((880 + 560 * 0.95) / 1440).bloomAlpha,
          closeTo(0, 1e-9),
        );
        final (rest, w, row) = await shot(t, b, SourceFx.none);
        final bg = px(rest, w, pad.toInt() + 6, pad.toInt() + 6);
        // Cap: rest + 6% white (light), + 12% (dark: its pulse is a lighter
        // step by design).
        final k = b == Brightness.dark ? 0.12 : 0.06;
        final cap = [for (final v in bg) v + (255 - v) * k];
        for (var ms = 880.0; ms <= 1440; ms += 40) {
          final (img, _, _) = await shot(t, b, sourceFx(ms / 1440));
          for (final (x, y) in inside(row)) {
            final a = px(rest, w, x, y);
            if (a[0] != bg[0] || a[1] != bg[1] || a[2] != bg[2]) continue;
            final c = px(img, w, x, y);
            for (var i = 0; i < 3; i++) {
              expect(
                c[i],
                lessThanOrEqualTo(cap[i] + 1),
                reason: '$b ${ms}ms ($x,$y) ch$i',
              );
            }
          }
        }
        // The last frame is the rest colour.
        final (end, _, _) = await shot(t, b, sourceFx(1));
        for (final (x, y) in inside(row)) {
          final a = px(rest, w, x, y), c = px(end, w, x, y);
          for (var i = 0; i < 3; i++) {
            expect((a[i] - c[i]).abs(), lessThanOrEqualTo(1));
          }
        }
      });

      testWidgets(
        'marker pill: settled is rest darkened 14%, never lighter ($b)',
        (
          t,
        ) async {
          final key = GlobalKey();
          final pb = b == Brightness.dark ? Pb.dark : Pb.light;
          final tones = b == Brightness.dark
              ? SourceTones.dark
              : SourceTones.light;
          final turn = AskTurn('q')
            ..answer.write('[1]')
            ..done = true
            ..citations[1] = _c(1);
          await t.pumpWidget(
            MaterialApp(
              theme: buildPbTheme(b),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                      color: Color.alphaBlend(pb.glassStrong, pb.bgMid),
                      child: SizedBox(
                        width: 360,
                        child: AskTurnView(turn, onBlink: (_, _) {}),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          Future<List<int>> pill() async {
            final box = t.getRect(find.byKey(const ValueKey('cite-marker-1')));
            final origin = t.getTopLeft(find.byKey(key));
            // 2px of hit padding, then 2px into the stadium: left of the bolt.
            final x = (box.left - origin.dx + 2 + 2).round();
            final y = (box.center.dy - origin.dy).round();
            late Uint8List bytes;
            late int width;
            await t.runAsync(() async {
              final r =
                  key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final img = await r.toImage(pixelRatio: 1);
              width = img.width;
              bytes = (await img.toByteData())!.buffer.asUint8List();
            });
            return px(bytes, width, x, y);
          }

          int ch(double v) => (v * 255).round();
          // The light pill is translucent: what is painted is it over the
          // answer bubble (glassStrong again, on top of the box above).
          final bubble = Color.alphaBlend(
            pb.glassStrong,
            Color.alphaBlend(pb.glassStrong, pb.bgMid),
          );
          final base = Color.alphaBlend(tones.pill, bubble);
          final rest = await pill();
          expect(rest[0], closeTo(ch(base.r), 1));
          expect(rest[2], closeTo(ch(base.b), 1));
          await _tapMarker(t, 1);
          await t.pumpAndSettle();
          final done = await pill();
          final want = Color.alphaBlend(
            tones.markerOverlay.withValues(alpha: tones.markerAlpha.picked),
            base,
          );
          expect(done[0], closeTo(ch(want.r), 1));
          expect(done[1], closeTo(ch(want.g), 1));
          expect(done[2], closeTo(ch(want.b), 1));
          for (var i = 0; i < 3; i++) {
            expect(done[i], lessThanOrEqualTo(rest[i]), reason: 'ch$i');
          }
        },
      );
    }
  });

  group('example question cards', () {
    testWidgets('show keep-all text but send the plain string (no U+2060)', (
      t,
    ) async {
      const wj = '⁠';
      final sent = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          locale: const Locale('ko'),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: AskEmptyHint(includePersonal: false, onPick: sent.add),
          ),
        ),
      );
      final questions = L.ko.askSuggestions;
      for (final q in questions) {
        expect(q.contains(wj), isFalse, reason: 'source string is plain');
        // Hangul words are kept whole on screen.
        expect(find.text(q), findsNothing);
        expect(find.text(keepAllKorean(q)), findsOneWidget);
      }
      for (final q in questions) {
        await t.tap(find.text(keepAllKorean(q)));
      }
      expect(sent, questions);
      for (final q in sent) {
        expect(q.contains(wj), isFalse);
      }
    });

    testWidgets('demo status arriving late drops the general questions', (
      t,
    ) async {
      final hint = SampleHint(
        packId: 'demo-en',
        locale: 'en',
        questions: ['When is the launch, and what is the budget?'],
      );
      addTearDown(() {
        demoStatus.value = null;
        sampleHints.value = const [];
      });
      demoStatus.value = null;
      sampleHints.value = [hint];
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: AskEmptyHint(includePersonal: true, onPick: (_) {}),
          ),
        ),
      );
      expect(find.text(hint.questions.first), findsOneWidget);
      expect(find.text(L.en.askSuggestions.first), findsOneWidget);
      demoStatus.value = DemoStatus(enabled: true, isDemo: true);
      await t.pump();
      expect(find.text(hint.questions.first), findsOneWidget);
      expect(find.text(L.en.askSuggestions.first), findsNothing);
    });

    testWidgets('hints arriving late come first; a project scope has none', (
      t,
    ) async {
      final hint = SampleHint(
        packId: 'signup-en',
        locale: 'en',
        questions: ['What is due today?'],
      );
      addTearDown(() => sampleHints.value = const []);
      sampleHints.value = const [];
      Future<void> pump(bool includePersonal) => t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: AskEmptyHint(
              includePersonal: includePersonal,
              onPick: (_) {},
            ),
          ),
        ),
      );
      await pump(true);
      expect(find.text(hint.questions.first), findsNothing);
      sampleHints.value = [hint];
      await t.pump();
      expect(find.text(hint.questions.first), findsOneWidget);
      await pump(false);
      expect(find.text(hint.questions.first), findsNothing);
      expect(find.text(L.en.askSuggestions.first), findsOneWidget);
    });

    testWidgets('English questions are untouched', (t) async {
      final sent = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: AskEmptyHint(includePersonal: false, onPick: sent.add),
          ),
        ),
      );
      final q = L.en.askSuggestions.first;
      await t.tap(find.text(q));
      expect(sent, [q]);
    });
  });
}
