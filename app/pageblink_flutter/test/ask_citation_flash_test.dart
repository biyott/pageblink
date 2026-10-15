import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_markers.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:pageblink_flutter/features/ask/ask_sources.dart';

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

/// The row's resting colour: the neutral `chipBg`, for every kind.
Color _paper(WidgetTester tester, int n) =>
    tester.element(find.byKey(ValueKey('source-chip-$n'))).pb.chipBg;

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

    testWidgets('tapping ⚡1 pulses source 1 only, then keeps its halo', (
      t,
    ) async {
      await pump(t, answer: '첫째 [1] 그리고 둘째 [2].');
      expect(_glow(t, 1), isNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 140)); // start delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 245)); // first peak (1.0)
      expect(_glow(t, 1), isNotNull);
      expect(_glow(t, 2), isNull);
      expect(_inner(t, 1), isNot(_paper(t, 1)));
      await t.pump(const Duration(milliseconds: 420)); // trough (0.35)
      expect(_glow(t, 1), isNotNull);
      await t.pump(const Duration(milliseconds: 262)); // second peak (0.85)
      expect(_glow(t, 1), isNotNull);
      await t.pump(const Duration(milliseconds: 473)); // bloom done
      await t.pumpAndSettle();
      // No end: the halo is still there, the inside is back to chipBg.
      expect(_glow(t, 1), isNotNull);
      expect(_inner(t, 1), _paper(t, 1));
      expect(_glow(t, 2), isNull);
      await t.pump(const Duration(seconds: 30));
      expect(_glow(t, 1), isNotNull);
    });

    testWidgets('resting halo: four cool hues (violet..sky), faint', (t) async {
      for (final b in Brightness.values) {
        await pump(t, answer: '[1]', brightness: b);
        await _tapMarker(t, 1);
        await t.pumpAndSettle();
        final h = _halo(t, 1);
        expect(h, hasLength(4), reason: '$b');
        expect({for (final s in h) s.color.toARGB32()}, hasLength(4));
        expect({for (final s in h) s.offset}, hasLength(4));
        for (final s in h) {
          expect(s.color.a, inInclusiveRange(0.08, 0.40), reason: '$b');
          expect(s.blurRadius, 20);
          // No pink, orange or yellow: hue 195..275 (sky to violet).
          final hue = HSLColor.fromColor(s.color).hue;
          expect(hue, inInclusiveRange(195, 275), reason: '$b $hue');
        }
        expect(_inner(t, 1), _paper(t, 1));
      }
    });

    testWidgets('the beats follow the timeline (not monotonic)', (t) async {
      expect(sourceFx(0).halo, 0);
      expect(sourceFx(0.05).fill, 0); // 77ms, in the delay
      double at(double ms) => ms / sourceFlashDuration.inMilliseconds;
      final peak = sourceFx(at(385)); // 140 + 245
      final trough = sourceFx(at(805)); // + 420
      final peak2 = sourceFx(at(1067)); // + 262
      expect(peak.fill, closeTo(1, 0.01));
      expect(trough.fill, closeTo(0.35, 0.01));
      expect(peak2.fill, closeTo(0.85, 0.01));
      final mid = sourceFx(at(1067 + 236)); // half-way through the bloom
      expect(mid.bloomAlpha, closeTo(1, 0.01));
      expect(mid.bloom, inInclusiveRange(0.5, 1));
      expect(mid.fill, lessThan(peak2.fill));
      final end = sourceFx(1);
      expect(end.fill, 0);
      expect(end.bloomAlpha, 0);
      expect(end.halo, 1);
      expect(end.rainbow, 1);
      // 12.5% faster than the 1760ms it replaces.
      expect(sourceFlashDuration.inMilliseconds, 1540);
    });

    testWidgets('the centre-out light is drawn only during the bloom', (
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
      await t.pump(const Duration(milliseconds: 140 + 245 + 420 + 262 + 100));
      expect(blooms(), 1);
      await t.pumpAndSettle();
      expect(blooms(), 0);
    });

    testWidgets('picking another source moves the halo (marker and row)', (
      t,
    ) async {
      await pump(t, answer: '[1] [2]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      await _tapMarker(t, 2);
      await t.pump();
      expect(_glow(t, 1), isNull); // gone at once
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
      expect(_glow(t, 2), isNotNull);
      // Row tap: same effect; and the marker of the picked number is deeper.
      await _tapRow(t, 1);
      await t.pump();
      expect(_glow(t, 2), isNull);
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

      final rest = fill(1), rest2 = fill(2);
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      expect(fill(1), isNot(rest));
      expect(fill(2), rest2);
      await _tapMarker(t, 2);
      await t.pumpAndSettle();
      expect(fill(1), rest);
      expect(fill(2), isNot(rest2));
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

    testWidgets('glow: one purple glow at the first peak, offset (0, 2)', (
      t,
    ) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 140 + 245));
      final h = _halo(t, 1);
      expect(h, hasLength(4));
      for (final s in h) {
        expect(s.blurRadius, 20);
        expect(s.spreadRadius, 0);
        expect(s.offset, const Offset(0, 2));
        expect(
          s.color.withValues(alpha: 1),
          h.first.color.withValues(alpha: 1),
        );
      }
      await t.pumpAndSettle();
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

      final rest = fill(1), rest2 = fill(2);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120)); // ack peak
      expect(fill(1), isNot(rest));
      expect(fill(2), rest2);
      await t.pumpAndSettle();
      // The ack is over; what stays is the picked tint, nowhere near accent.
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
      await t.pump(const Duration(milliseconds: 140)); // back in the delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 245));
      expect(_glow(t, 1), isNotNull);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
    });

    testWidgets('tapping the picked source again replays from its halo', (
      t,
    ) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pumpAndSettle();
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // in the delay
      expect(_glow(t, 1), isNotNull); // never goes out
      expect(_inner(t, 1), _paper(t, 1));
      await t.pump(const Duration(milliseconds: 40 + 245));
      expect(_inner(t, 1), isNot(_paper(t, 1))); // played again
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_inner(t, 1), _paper(t, 1));
    });

    testWidgets('reduced motion: resting halo at once, no ramp', (t) async {
      await pump(t, answer: '[1]', reduced: true);
      await _tapMarker(t, 1);
      await t.pump();
      expect(_glow(t, 1), isNotNull);
      final c = _halo(t, 1).map((s) => s.color).toList();
      expect(_inner(t, 1), _paper(t, 1));
      await t.pump(const Duration(milliseconds: 300));
      expect(_halo(t, 1).map((s) => s.color).toList(), c);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNotNull);
      expect(_halo(t, 1), hasLength(4));
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
      expect(_glow(t, 5), isNotNull); // keeps its halo
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

  group('source colours (neutral rows, grey pill with a yellow bolt)', () {
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

    Icon bolt(WidgetTester t, int n) => t.widget<Icon>(
      find
          .descendant(
            of: find.byKey(ValueKey('cite-marker-$n')).first,
            matching: find.byType(Icon),
          )
          .first,
    );

    testWidgets('notes and PDFs share one neutral row colour: chipBg', (
      t,
    ) async {
      for (final b in Brightness.values) {
        // Documents 5 and 8 used to land on different pastels.
        await pumpKinds(t, [
          cite(1, 5, 'note'),
          cite(2, 8, 'note'),
          cite(3, 5, 'pdf'),
        ], brightness: b);
        final pb = buildPbTheme(b).extension<Pb>()!;
        for (final n in [1, 2, 3]) {
          expect(_inner(t, n), pb.chipBg, reason: '$b row $n');
        }
      }
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
      expect(find.text('노트'), findsNothing); // default locale is English
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('PDF · Page 1'), findsOneWidget);
    });

    testWidgets('a picked row settles back to chipBg', (t) async {
      for (final n in [1, 2]) {
        await pumpKinds(t, [cite(1, 5, 'note'), cite(2, 3, 'pdf')]);
        final rest = _inner(t, n);
        await _tapMarker(t, n);
        await t.pump();
        await t.pump(const Duration(milliseconds: 140 + 245));
        await t.pump(const Duration(milliseconds: 250)); // past the fade
        expect(_inner(t, n), isNot(rest));
        await t.pumpAndSettle();
        expect(_inner(t, n), rest);
        expect(_glow(t, n), isNotNull);
      }
    });

    testWidgets('the pulse only rises towards accentContainer', (t) async {
      await pumpKinds(t, [cite(1, 5, 'note')], answer: '[1]');
      final pb = t.element(find.byType(Scaffold)).pb;
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 140 + 245)); // peak, fill 1.0
      // The Material animates colour changes: let it catch up (still inside
      // the 420ms dip, where the fill is between 1.0 and 0.35).
      await t.pump(const Duration(milliseconds: 100));
      final c = _inner(t, 1);
      // Between chipBg and accentContainer on every channel (no detour).
      for (final ch in [
        (pb.chipBg.r, pb.accentContainer.r, c.r),
        (pb.chipBg.g, pb.accentContainer.g, c.g),
        (pb.chipBg.b, pb.accentContainer.b, c.b),
      ]) {
        final lo = ch.$1 < ch.$2 ? ch.$1 : ch.$2;
        final hi = ch.$1 < ch.$2 ? ch.$2 : ch.$1;
        expect(ch.$3, inInclusiveRange(lo - 0.01, hi + 0.01));
      }
      await t.pumpAndSettle();
    });

    testWidgets('every pill is the same grey with a yellow bolt', (t) async {
      for (final b in Brightness.values) {
        final dark = b == Brightness.dark;
        // 1 and 2 arrived (note, PDF); 3 has no source yet.
        await pumpKinds(t, [
          cite(1, 5, 'note'),
          cite(2, 3, 'pdf'),
        ], brightness: b);
        final pb = buildPbTheme(b).extension<Pb>()!;
        for (final n in [1, 2, 3]) {
          expect(markerFill(t, n), citeMarkerFill(dark: dark), reason: '$b $n');
          expect(bolt(t, n).color, citeMarkerBolt(dark: dark), reason: '$b $n');
        }
        // Grey: no hue of its own beyond a hair.
        final f = markerFill(t, 1);
        expect((f.r - f.b).abs(), lessThan(0.08), reason: '$b');
        // The bolt is yellow/amber (hue 35..55), not orange or red.
        final hue = HSLColor.fromColor(citeMarkerBolt(dark: dark)).hue;
        expect(hue, inInclusiveRange(35, 55), reason: '$b $hue');
        // Digit is ink.
        final digit = t.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('cite-marker-1')).first,
                matching: find.text('1'),
              )
              .first,
        );
        expect(digit.style!.color, pb.ink, reason: '$b');
      }
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

    test('contrast: row text, pill digit and bolt (pure functions)', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      for (final dark in [false, true]) {
        final pb = dark ? Pb.dark : Pb.light;
        // The answer bubble is glassStrong over the page gradient; test every
        // stop (rows add chipBg on top).
        for (final page in [pb.bgStart, pb.bgMid, pb.bgEnd]) {
          final bubble = Color.alphaBlend(pb.glassStrong, page);
          final row = Color.alphaBlend(pb.chipBg, bubble);
          final pulse = pb.accentContainer;
          final sub = subInkFor(pb, dark: dark);
          for (final bg in [row, pulse]) {
            expect(contrastRatio(pb.ink, bg), greaterThanOrEqualTo(4.5));
            expect(
              contrastRatio(Color.alphaBlend(sub, bg), bg),
              greaterThanOrEqualTo(4.5),
              reason: 'sub $dark $bg',
            );
          }
          expect(
            contrastRatio(pb.onAccentContainer, pb.accentContainer),
            greaterThanOrEqualTo(4.5),
            reason: 'badge $dark',
          );
        }
        final fill = citeMarkerFill(dark: dark);
        final picked = citeMarkerPicked(pb, fill);
        for (final f in [fill, picked]) {
          expect(
            contrastRatio(pb.ink, f),
            greaterThanOrEqualTo(4.5),
            reason: 'digit $dark',
          );
          // Graphic object: 3:1 where a yellow can reach it (dark). On the
          // light grey a yellow tops out near 2:1 (3:1 needs a brown), so the
          // light bolt is held at its measured 1.8:1 (picked) and the digit carries it.
          expect(
            contrastRatio(citeMarkerBolt(dark: dark), f),
            greaterThanOrEqualTo(dark ? 3 : 1.8),
            reason: 'bolt $dark',
          );
        }
        // The pill is told apart from the bubble by 1.1:1 at least.
        final bubble = Color.alphaBlend(pb.glassStrong, pb.bgMid);
        expect(contrastRatio(fill, bubble), greaterThanOrEqualTo(1.1));
      }
    });
  });
}
