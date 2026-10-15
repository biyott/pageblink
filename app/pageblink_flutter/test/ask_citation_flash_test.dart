import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_markers.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';

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
    }) async {
      final turn = AskTurn('q')
        ..answer.write(answer)
        ..done = done;
      for (var i = 1; i <= count; i++) {
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

    testWidgets('tapping ⚡1 pulses source 1 only, then settles', (t) async {
      await pump(t, answer: '첫째 [1] 그리고 둘째 [2].');
      expect(_glow(t, 1), isNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 160)); // start delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 280)); // first peak (1.0)
      expect(_glow(t, 1), isNotNull);
      expect(_glow(t, 2), isNull);
      await t.pump(const Duration(milliseconds: 480)); // trough (0.35, not off)
      expect(_glow(t, 1), isNotNull);
      await t.pump(const Duration(milliseconds: 300)); // second peak (0.75)
      expect(_glow(t, 1), isNotNull);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
    });

    testWidgets('glow: alpha 30%, blur 20, spread 0, offset (0, 2)', (t) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 440)); // peak, g = 1
      final s = _glow(t, 1)!;
      expect(s.blurRadius, 20);
      expect(s.spreadRadius, 0);
      expect(s.offset, const Offset(0, 2));
      expect(s.color.a, closeTo(0.30, 0.01));
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

      final rest = fill(1);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120)); // ack peak
      expect(fill(1), isNot(rest));
      expect(fill(2), rest);
      await t.pumpAndSettle();
      expect(fill(1), rest);
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

    testWidgets('tapping again restarts the pulse', (t) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(_glow(t, 1), isNotNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 160)); // back in the delay
      expect(_glow(t, 1), isNull);
      await t.pump(const Duration(milliseconds: 280));
      expect(_glow(t, 1), isNotNull);
      await t.pumpAndSettle();
    });

    testWidgets('reduced motion: held highlight, no ramp', (t) async {
      await pump(t, answer: '[1]', reduced: true);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final g = _glow(t, 1)!;
      await t.pump(const Duration(milliseconds: 300));
      expect(_glow(t, 1)!.color, g.color);
      await t.pump(const Duration(milliseconds: 800));
      expect(_glow(t, 1), isNotNull); // still held at 1100ms
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
    });

    testWidgets('tapping the source row still calls onBlink', (t) async {
      Citation? opened;
      await pump(t, answer: '[1] [2]', onBlink: (all, c) => opened = c);
      await t.tap(find.byKey(const ValueKey('source-chip-2')));
      expect(opened?.index, 2);
      await t.pumpAndSettle();
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
      expect(_glow(t, 5), isNull);
      expect(find.text('Show fewer'), findsOneWidget);
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
}
