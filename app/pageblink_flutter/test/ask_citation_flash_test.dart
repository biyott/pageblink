import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// The ⚡n marker is a text span, so tap the paragraph at its offset.
Future<void> _tapMarker(WidgetTester tester, int n) async {
  final rich = find.byWidgetPredicate(
    (w) =>
        w is RichText &&
        w.text.toPlainText(includeSemanticsLabels: false).contains('⚡$n'),
  );
  final box = tester.renderObject<RenderParagraph>(rich.first);
  final text = box.text.toPlainText(includeSemanticsLabels: false);
  final at = text.indexOf('⚡$n');
  final rects = box.getBoxesForSelection(
    TextSelection(baseOffset: at, extentOffset: at + 2),
  );
  await tester.tapAt(box.localToGlobal(rects.first.toRect().center));
}

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
    }) async {
      final turn = AskTurn('q')
        ..answer.write(answer)
        ..citations[1] = _c(1)
        ..citations[2] = _c(2, kind: 'note');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(Brightness.light),
          supportedLocales: supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SingleChildScrollView(
                child: AskTurnView(turn, onBlink: onBlink ?? (_, _) {}),
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
      await t.pump(const Duration(milliseconds: 225)); // first peak
      expect(_glow(t, 1), isNotNull);
      expect(_glow(t, 2), isNull);
      await t.pump(const Duration(milliseconds: 225)); // trough
      await t.pump(const Duration(milliseconds: 225)); // second peak
      expect(_glow(t, 1), isNotNull);
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
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
      await t.pump(const Duration(milliseconds: 225));
      expect(_glow(t, 3), isNotNull);
      await t.pumpAndSettle();
    });

    testWidgets('tapping again restarts the pulse', (t) async {
      await pump(t, answer: '[1]');
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 450)); // trough
      expect(_glow(t, 1), isNull);
      await _tapMarker(t, 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 225));
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
      await t.pumpAndSettle();
      expect(_glow(t, 1), isNull);
    });

    testWidgets('tapping the source chip still calls onBlink', (t) async {
      Citation? opened;
      await pump(t, answer: '[1] [2]', onBlink: (all, c) => opened = c);
      await t.tap(find.textContaining('2 · Doc 2'));
      expect(opened?.index, 2);
      await t.pumpAndSettle();
    });
  });
}
