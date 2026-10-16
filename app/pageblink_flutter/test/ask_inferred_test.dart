import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';

Citation _c(int i, {bool? inferred}) => Citation(
  index: i,
  documentId: i,
  documentTitle: 'Plan $i',
  kind: 'note',
  page: 1,
  quote: '- [ ] Finalize the release notes',
  quoteStart: 20 * i,
  inferred: inferred,
);

Finder _dashed(int n) => find.byKey(ValueKey('source-dashed-$n'));
Finder _marker(int n) => find.byKey(ValueKey('cite-marker-$n'));
Finder _label(String s) => find.text(s);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(
    WidgetTester t, {
    required String answer,
    required List<Citation> citations,
    String lang = 'en',
    void Function(List<Citation>, Citation)? onBlink,
  }) async {
    t.view
      ..physicalSize = const Size(800, 900)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final turn = AskTurn('q')
      ..answer.write(answer)
      ..done = true;
    for (final c in citations) {
      turn.citations[c.index] = c;
    }
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: Locale(lang),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AskTurnView(turn, onBlink: onBlink ?? (_, _) {}),
          ),
        ),
      ),
    );
  }

  testWidgets('inferred sources: dashed rows with a label, no text chips', (
    t,
  ) async {
    await pump(
      t,
      answer: '- Finalize the release notes\n- Send the beta invite emails',
      citations: [_c(1, inferred: true), _c(2, inferred: true)],
    );
    expect(_dashed(1), findsOneWidget);
    expect(_dashed(2), findsOneWidget);
    expect(_label('Related source (auto-linked)'), findsNWidgets(2));
    expect(_marker(1), findsNothing);
    expect(_marker(2), findsNothing);
    // the same list, and the same row, as a direct source
    expect(find.byKey(const ValueKey('source-chip-1')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('direct sources look as before', (t) async {
    await pump(
      t,
      answer: 'Finalize the release notes [1] and more [2].',
      citations: [_c(1), _c(2, inferred: false)],
    );
    expect(_dashed(1), findsNothing);
    expect(_dashed(2), findsNothing);
    expect(_label('Related source (auto-linked)'), findsNothing);
    expect(_marker(1), findsOneWidget);
    expect(_marker(2), findsOneWidget);
  });

  testWidgets('a mix: only the inferred row is dashed and labelled', (t) async {
    await pump(
      t,
      answer: 'Finalize the release notes [1].',
      citations: [_c(1), _c(2, inferred: true)],
    );
    expect(_dashed(1), findsNothing);
    expect(_dashed(2), findsOneWidget);
    expect(_label('Related source (auto-linked)'), findsOneWidget);
    expect(_marker(1), findsOneWidget);
    expect(_marker(2), findsNothing);
  });

  testWidgets('tapping an inferred row opens it like any source', (t) async {
    Citation? opened;
    List<Citation>? all;
    await pump(
      t,
      answer: 'Finalize the release notes',
      citations: [_c(1, inferred: true), _c(2, inferred: true)],
      onBlink: (a, c) {
        all = a;
        opened = c;
      },
    );
    await t.tap(find.text('Plan 2'));
    await t.pump();
    expect(opened?.index, 2);
    expect(opened?.inferred, isTrue);
    // the quote and offset that drive the highlight arrive intact
    expect(opened?.quote, '- [ ] Finalize the release notes');
    expect(opened?.quoteStart, 40);
    expect(all, hasLength(2));
    await t.pumpAndSettle();
  });

  testWidgets('screen readers hear the label; mouse users get a tooltip', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(
      t,
      answer: 'Finalize the release notes',
      citations: [_c(1, inferred: true)],
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Source 1: Plan 1, note\. Related source \(auto-linked\)'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Related source (auto-linked)',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Korean wording', (t) async {
    await pump(
      t,
      answer: '릴리스 노트 마무리',
      citations: [_c(1, inferred: true)],
      lang: 'ko',
    );
    expect(_label('관련 출처 (자동 연결)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('narrow screen and large text: no overflow', (t) async {
    t.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final turn = AskTurn('q')
      ..answer.write('x')
      ..done = true;
    turn.citations[1] = _c(1, inferred: true);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.dark),
        locale: const Locale('ko'),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: AskTurnView(turn, onBlink: (_, _) {}),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
