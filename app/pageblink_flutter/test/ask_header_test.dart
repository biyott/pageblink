import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/pb_interactive.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/app/visitor_key.dart';
import 'package:pageblink_flutter/features/ask/ask_chat.dart';
import 'package:pageblink_flutter/features/ask/ask_header.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Ask header (`[Recent v] [+ New chat]`), the recent-chats popover /
// sheet, the question counter and the limit card. Server calls are replaced.

AskHistoryStatus _status({bool enabled = true}) => AskHistoryStatus(
  enabled: enabled,
  questionLimit: 10,
  visibleMinutes: 30,
  retentionDays: 30,
  questionMaxChars: 2000,
  isAdmin: false,
);

AskMessageView _msg(int seq, String q) => AskMessageView(
  seq: seq,
  question: q,
  answer: 'Answer.',
  status: 'done',
  citations: const [],
  createdAt: DateTime.utc(2026, 10, 16),
);

AskSessionView _view(int id, String q, {int count = 1}) => AskSessionView(
  id: id,
  title: q,
  questionCount: count,
  questionLimit: 10,
  lastActiveAt: DateTime.now().toUtc(),
  messages: [_msg(1, q)],
);

AskSessionSummary _sum(int id, String title, int n, int minutesAgo) =>
    AskSessionSummary(
      id: id,
      title: title,
      questionCount: n,
      lastActiveAt: DateTime.now().toUtc().subtract(
        Duration(minutes: minutesAgo),
      ),
    );

Stream<AnswerEvent> _answer(int id, int count) => Stream.fromIterable([
  AnswerEvent(
    type: 'session',
    sessionId: id,
    questionCount: count,
    questionLimit: 10,
  ),
  AnswerEvent(type: 'token', text: 'Reply $count.'),
  AnswerEvent(type: 'done'),
]);

const _recentKey = ValueKey('ask-recent');
const _newKey = ValueKey('ask-new-chat');

/// 400 ms: the popover's exit animation is 150 ms after the call returns.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// [size] is the window; at >= 1024 the screen sits in the real 380 column.
Future<void> _pump(
  WidgetTester t, {
  Size size = const Size(800, 1000),
  String lang = 'en',
  Brightness br = Brightness.light,
  double scale = 1,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  const ask = AskScreen(projects: []);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(br),
      locale: Locale(lang),
      supportedLocales: supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(
        body: size.width >= 1024
            ? const Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 380, child: ask),
              )
            : ask,
      ),
    ),
  );
  await _settle(t);
}

Future<void> _send(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField), q);
  await t.pump();
  await t.tap(find.byIcon(AppIcons.send));
  await _settle(t);
}

PbRingPainter _ring(WidgetTester t, Finder within) =>
    t
            .widget<CustomPaint>(
              find
                  .descendant(of: within, matching: find.byKey(pbFocusRingKey))
                  .first,
            )
            .foregroundPainter
        as PbRingPainter;

bool _focused(WidgetTester t, Finder within) => _ring(t, within).visible;

Finder _row(int id) => find.byKey(ValueKey('recent-$id'));
Finder _pick(int id) =>
    find.descendant(of: _row(id), matching: find.byType(PbInteractive)).first;
Finder _hide(int id) =>
    find.descendant(of: _row(id), matching: find.byType(PbInteractive)).last;
Finder _hideIcon(int id) =>
    find.descendant(of: _row(id), matching: find.byIcon(AppIcons.hideChat));

void main() {
  final requests = <AskRequest>[];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // The real bundled fonts: widths (and so the "New chat" folding) are
    // the ones users get, not the test font's (as wide as tall).
    final sans = FontLoader(pbSansFamily);
    for (final w in [400, 500, 600]) {
      sans.addFont(rootBundle.load('assets/fonts/Pretendard-$w-subset.otf'));
    }
    await sans.load();
    await (FontLoader('NotoSerifKRSubset')
          ..addFont(rootBundle.load('assets/fonts/NotoSerifKR-600-subset.ttf')))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetVisitorKey();
    resetNotice();
    resetHistoryStatus();
    requests.clear();
    historyStatusCall = () async => _status();
    askRestoreCall = (_) async => AskRestore(recent: []);
    askStreamCall = (r) {
      requests.add(r);
      return _answer(7, requests.length);
    };
    modelListCall = () async => [
      LlmModel(id: 'm1', label: 'Model One', provider: 'p', free: true),
    ];
  });

  tearDown(() {
    historyStatusCall = null;
    askRestoreCall = null;
    askOpenCall = null;
    askHideCall = null;
    askStreamCall = null;
    modelListCall = null;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  void twoChats() {
    askRestoreCall = (_) async => AskRestore(
      recent: [
        _sum(5, 'Plan talk', 3, 12),
        _sum(6, 'Budget for the next quarter and who signs it off', 8, 21),
      ],
      current: _view(5, 'Plan talk', count: 3),
    );
    askOpenCall = (id, _) async =>
        id == 6 ? _view(6, 'Budget', count: 8) : _view(5, 'Plan talk');
  }

  group('header buttons', () {
    for (final (w, title) in [(1280.0, true), (800.0, false), (390.0, false)]) {
      testWidgets(
        'history on at $w: Recent + New chat, title only on desktop',
        (
          t,
        ) async {
          await _pump(t, size: Size(w, 900));
          expect(find.byKey(_recentKey), findsOneWidget);
          expect(find.byKey(_newKey), findsOneWidget);
          expect(find.text('Recent'), findsOneWidget);
          expect(find.text('New chat'), findsOneWidget);
          expect(find.text('Ask'), title ? findsOneWidget : findsNothing);
          // no old header icon, no bar over the input
          expect(find.byTooltip('New question'), findsNothing);
          expect(find.byType(ActionChip), findsNothing);
          // Recent comes first, then New chat; both on the header line
          expect(
            t.getTopLeft(find.byKey(_recentKey)).dx,
            lessThan(t.getTopLeft(find.byKey(_newKey)).dx),
          );
          expect(
            t.getRect(find.byKey(_recentKey)).bottom,
            lessThan(t.getTopLeft(find.byType(TextField)).dy),
          );
          expect(t.takeException(), isNull);
        },
      );
    }

    for (final off in <String, Future<AskHistoryStatus> Function()>{
      'flag off': () async => _status(enabled: false),
      'status fails': () async => throw Exception('404'),
    }.entries) {
      testWidgets('${off.key}: the original header (desktop icon only)', (
        t,
      ) async {
        historyStatusCall = off.value;
        askStreamCall = (r) => Stream.fromIterable([
          AnswerEvent(type: 'token', text: 'Old style.'),
          AnswerEvent(type: 'done'),
        ]);
        await _pump(t, size: const Size(1280, 900));
        for (final k in [_recentKey, _newKey, const ValueKey('ask-count')]) {
          expect(find.byKey(k), findsNothing);
        }
        expect(find.text('Ask'), findsOneWidget);
        final icon = find.widgetWithIcon(IconButton, AppIcons.newQuestion);
        expect(find.byTooltip('New question'), findsOneWidget);
        expect(t.widget<IconButton>(icon).onPressed, isNull); // empty chat
        await _send(t, 'Q');
        expect(t.widget<IconButton>(icon).onPressed, isNotNull);
        await t.tap(icon);
        await t.pump();
        expect(find.text('Old style.'), findsNothing);

        // below 1024 there was no header, and still is none
        await _pump(t, size: const Size(390, 800));
        expect(find.byTooltip('New question'), findsNothing);
        expect(find.byKey(_recentKey), findsNothing);
        expect(find.text('Ask'), findsNothing);
      });
    }

    testWidgets('New chat on a fresh screen: no call, cursor in the input', (
      t,
    ) async {
      await _pump(t);
      await t.tap(find.byKey(_newKey));
      await _settle(t);
      expect(requests, isEmpty);
      expect(find.byType(AskEmptyHint), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('New chat while an answer streams cuts it and starts over', (
      t,
    ) async {
      final open = StreamController<AnswerEvent>();
      addTearDown(open.close);
      askStreamCall = (r) {
        requests.add(r);
        return open.stream;
      };
      await _pump(t);
      await _send(t, 'Slow one');
      open.add(AnswerEvent(type: 'token', text: 'half'));
      await _settle(t);
      expect(find.text('Slow one'), findsOneWidget);
      await t.tap(find.byKey(_newKey));
      await _settle(t);
      expect(find.text('Slow one'), findsNothing);
      expect(find.byType(AskEmptyHint), findsOneWidget);
    });

    testWidgets('limit card: the thread ends with it, the input is off', (
      t,
    ) async {
      askRestoreCall = (_) async => AskRestore(
        recent: [],
        current: _view(5, 'Last one', count: 10),
      );
      await _pump(t);
      final card = find.byKey(const ValueKey('ask-limit-banner'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListView), matching: card),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(card).dy,
        greaterThan(t.getTopLeft(find.text('Last one')).dy),
      );
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text('Start a new conversation'), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-count')), findsOneWidget);
      // the card's button and the header's both start over, input focused
      await t.tap(
        find.descendant(of: card, matching: find.byType(FilledButton)),
      );
      await _settle(t);
      expect(card, findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(
        t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('a hint sits between thread and panel, not inside it', (
      t,
    ) async {
      await _pump(t);
      askStreamCall = (r) =>
          Stream.error(AskLimitException(reason: AskLimitReason.busy));
      await _send(t, 'Quick');
      final hint = find.textContaining('still being written');
      expect(hint, findsOneWidget);
      expect(
        find.ancestor(of: hint, matching: find.byType(GlassPanel)),
        findsNothing,
      );
      expect(
        t.getBottomLeft(hint).dy,
        lessThanOrEqualTo(t.getTopLeft(find.byType(GlassPanel)).dy),
      );
    });
  });

  group('counter', () {
    testWidgets('under the input, opposite the model pill; emphasis from 8', (
      t,
    ) async {
      await _pump(t);
      // none before the first question
      expect(find.byKey(const ValueKey('ask-count')), findsNothing);
      askStreamCall = (r) => _answer(7, 3);
      await _send(t, 'Q1');
      final counter = find.byKey(const ValueKey('ask-count'));
      final pill = find.text('Auto');
      Text text() => t.widget<Text>(
        find.descendant(of: counter, matching: find.byType(Text)),
      );
      expect(text().data, 'Question 3/10');
      expect(text().style!.fontSize, 12);
      expect(
        find.descendant(of: counter, matching: find.byIcon(AppIcons.warning)),
        findsNothing,
      );
      // same line as the pill, to its right, below the input
      expect(
        (t.getCenter(counter).dy - t.getCenter(pill).dy).abs(),
        lessThan(8),
      );
      expect(t.getTopLeft(counter).dx, greaterThan(t.getBottomRight(pill).dx));
      expect(
        t.getCenter(counter).dy,
        greaterThan(t.getCenter(find.byType(TextField)).dy),
      );
      // it is plain text: no button, no chip, no border
      expect(
        find.descendant(of: counter, matching: find.byType(PbInteractive)),
        findsNothing,
      );

      askStreamCall = (r) => _answer(7, 8);
      await _send(t, 'Q2');
      expect(text().data, 'Question 8/10 · 2 left');
      expect(text().style!.fontWeight, FontWeight.w700);
      expect(text().style!.color, Pb.light.warnText);
      expect(
        find.descendant(of: counter, matching: find.byIcon(AppIcons.warning)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ask-limit-banner')), findsNothing);
      // the counter did not add a line: the panel is no taller than before
      // (checked above by the shared row), and the input stays on
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      askStreamCall = (r) => _answer(7, 10);
      await _send(t, 'Q3');
      expect(text().data, 'Question 10/10');
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byKey(const ValueKey('ask-limit-banner')), findsOneWidget);
    });
  });

  group('recent chats', () {
    testWidgets(
      'desktop: a 340 popover under the button, right edges aligned',
      (
        t,
      ) async {
        twoChats();
        await _pump(t, size: const Size(1280, 900));
        await t.tap(find.byKey(_recentKey));
        await _settle(t);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        final list = t.getRect(find.byType(AskRecentList));
        final button = t.getRect(find.byKey(_recentKey));
        expect(list.width, 340);
        expect(list.top, greaterThanOrEqualTo(button.bottom));
        expect(
          list.right,
          closeTo(t.getRect(find.byKey(_newKey)).right, 1),
        );
        // the Ask column is 380 wide, at the right edge of the window
        expect(list.left, greaterThanOrEqualTo(1280 - 380));
        expect(
          t.widget<PbInteractive>(find.byKey(_recentKey)).expanded,
          isTrue,
        );
        expect(t.takeException(), isNull);
        // a pick that is the open chat only closes it
        await t.tap(_pick(5));
        await _settle(t);
        expect(find.byType(AskRecentList), findsNothing);
        expect(
          t.widget<PbInteractive>(find.byKey(_recentKey)).expanded,
          isFalse,
        );
      },
    );

    testWidgets('tablet: a 360 popover, not a dialog', (t) async {
      twoChats();
      await _pump(t, size: const Size(768, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      final list = t.getRect(find.byType(AskRecentList));
      expect(list.width, 360);
      expect(
        list.top,
        greaterThanOrEqualTo(t.getRect(find.byKey(_recentKey)).bottom),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('phone: a bottom sheet with 44px hide buttons always shown', (
      t,
    ) async {
      twoChats();
      await _pump(t, size: const Size(390, 800));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      for (final id in [5, 6]) {
        expect(t.getSize(_hide(id)).shortestSide, greaterThanOrEqualTo(44));
        expect(t.getSize(_pick(id)).height, greaterThanOrEqualTo(56));
        final fade = t.widget<AnimatedOpacity>(
          find.descendant(of: _row(id), matching: find.byType(AnimatedOpacity)),
        );
        expect(fade.opacity, 1);
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('the open chat is marked three ways, not by colour alone', (
      t,
    ) async {
      twoChats();
      await _pump(t, size: const Size(1280, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      Finder within(int id, Finder f) =>
          find.descendant(of: _row(id), matching: f);
      expect(within(5, find.byIcon(AppIcons.check)), findsOneWidget);
      expect(within(5, find.text('Current')), findsOneWidget);
      expect(within(6, find.byIcon(AppIcons.check)), findsNothing);
      expect(within(6, find.text('Current')), findsNothing);
      // the face of the open row
      final face = t.widget<Container>(
        within(5, find.byType(Container)).first,
      );
      expect(
        (face.decoration as BoxDecoration).color,
        Pb.light.accentContainer,
      );
      expect(t.widget<PbInteractive>(_pick(5)).selected, isTrue);
      expect(t.widget<PbInteractive>(_pick(6)).selected, isFalse);
      // row 6 is at 8/10: the warn mark
      expect(within(6, find.byIcon(AppIcons.warning)), findsOneWidget);
      expect(within(5, find.byIcon(AppIcons.warning)), findsNothing);
      // two-line titles
      expect(
        within(6, find.textContaining('Budget for the next')),
        findsOneWidget,
      );
    });

    testWidgets('hide shows on hover and focus, always on the open chat', (
      t,
    ) async {
      twoChats();
      await _pump(t, size: const Size(1280, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      double shown(int id) => t
          .widget<AnimatedOpacity>(
            find.descendant(
              of: _row(id),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(shown(5), 1); // the open chat
      expect(shown(6), 0);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(_pick(6)));
      await _settle(t);
      expect(shown(6), 1);
      await mouse.moveTo(const Offset(1, 1));
      await _settle(t);
      expect(shown(6), 0);
    });

    testWidgets('hide: asks in the row, Cancel keeps it, Hide hides it', (
      t,
    ) async {
      twoChats();
      final hidden = <int>[];
      askHideCall = (id, _) async => hidden.add(id);
      await _pump(t, size: const Size(1280, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      await t.tap(_hideIcon(6));
      await _settle(t);
      expect(find.text('Hide this chat from the list?'), findsOneWidget);
      expect(find.textContaining('Budget for the next'), findsOneWidget);
      expect(hidden, isEmpty);
      await t.tap(find.byKey(const ValueKey('hide-cancel')));
      await _settle(t);
      expect(find.text('Hide this chat from the list?'), findsNothing);
      expect(hidden, isEmpty);
      expect(_row(6), findsOneWidget);
      await t.tap(_hideIcon(6));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('hide-confirm')));
      await _settle(t);
      expect(hidden, [6]);
      expect(_row(6), findsNothing);
      expect(_row(5), findsOneWidget); // the popover stays for the others
    });

    testWidgets('hiding the open chat starts a new one and closes the list', (
      t,
    ) async {
      twoChats();
      final hidden = <int>[];
      askHideCall = (id, _) async => hidden.add(id);
      await _pump(t, size: const Size(1280, 900));
      expect(find.text('Plan talk'), findsOneWidget); // the thread
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      await t.tap(_hideIcon(5));
      await _settle(t);
      expect(
        find.text(
          'This is the chat you are viewing. Hiding it starts a new chat.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('hide-confirm')));
      await _settle(t);
      expect(hidden, [5]);
      expect(find.byType(AskRecentList), findsNothing);
      expect(find.byType(AskTurnView), findsNothing);
      expect(find.byType(AskEmptyHint), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-count')), findsNothing);
    });

    testWidgets('empty list: opens anyway, says why, keeps the footer', (
      t,
    ) async {
      await _pump(t, size: const Size(768, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(find.text('No chats in the last 30 minutes'), findsOneWidget);
      expect(
        find.textContaining('Shown for 30 minutes after your last question'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Hidden chats are still kept on the server for 30 days',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Korean copy', (t) async {
      twoChats();
      await _pump(t, size: const Size(1280, 900), lang: 'ko');
      expect(find.text('최근 대화'), findsOneWidget); // the button
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(find.text('최근 대화'), findsNWidgets(2)); // + the popover title
      expect(find.text('현재'), findsOneWidget);
      expect(find.textContaining('질문 3/10 · 12분 전'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '')
                  .replaceAll('⁠', '')
                  .contains('목록에서 숨겨도 서버에는 30일 보관돼요'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the list is re-read on open', (t) async {
      var calls = 0;
      askRestoreCall = (_) async {
        calls++;
        return AskRestore(recent: [_sum(5, 'Fresh', 1, 1)]);
      };
      await _pump(t);
      final before = calls;
      expect(find.text('Fresh'), findsNothing);
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(calls, before + 1);
      expect(find.text('Fresh'), findsOneWidget);
    });
  });

  group('keyboard', () {
    setUp(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });

    testWidgets('Tab: Recent, then New chat; Enter opens on the open chat', (
      t,
    ) async {
      twoChats();
      await _pump(t, size: const Size(768, 900));
      final recent = find.byKey(_recentKey), fresh = find.byKey(_newKey);
      for (var i = 0; i < 8 && !_focused(t, recent); i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
      }
      expect(_focused(t, recent), isTrue);
      expect(_focused(t, fresh), isFalse);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_focused(t, fresh), isTrue);
      expect(_focused(t, recent), isFalse);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      expect(_focused(t, recent), isTrue);

      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(t);
      expect(find.byType(AskRecentList), findsOneWidget);
      expect(_focused(t, _pick(5)), isTrue); // the open chat
      expect(_ring(t, _pick(5)).width, 2);
    });

    testWidgets(
      'up/down move between rows; Esc closes, focus returns to the button',
      (
        t,
      ) async {
        twoChats();
        await _pump(t, size: const Size(768, 900));
        await t.tap(find.byKey(_recentKey));
        await _settle(t);
        expect(_focused(t, _pick(5)), isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(_focused(t, _row(6)), isTrue);
        expect(_focused(t, _row(5)), isFalse);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(t);
        expect(find.byType(AskRecentList), findsNothing);
        expect(_focused(t, find.byKey(_recentKey)), isTrue);
      },
    );

    testWidgets('left/right goes pick <-> hide on one row', (t) async {
      twoChats();
      await _pump(t, size: const Size(768, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(_focused(t, _pick(5)), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(_focused(t, _hide(5)), isTrue);
      expect(_focused(t, _pick(5)), isFalse);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(_focused(t, _pick(5)), isTrue);
    });

    testWidgets(
      'Enter on a row opens it; the confirm row: Cancel has focus, Esc cancels',
      (
        t,
      ) async {
        twoChats();
        final hidden = <int>[];
        askHideCall = (id, _) async => hidden.add(id);
        await _pump(t, size: const Size(768, 900));
        await t.tap(find.byKey(_recentKey));
        await _settle(t);
        // hide button by keyboard
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown); // row 6
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight); // its hide
        await t.pump();
        expect(_focused(t, _hide(6)), isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(t);
        final cancel = find.byKey(const ValueKey('hide-cancel'));
        expect(cancel, findsOneWidget);
        expect(_focused(t, cancel), isTrue);
        // Esc cancels the question only; the list stays
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(t);
        expect(cancel, findsNothing);
        expect(find.byType(AskRecentList), findsOneWidget);
        expect(hidden, isEmpty);
        expect(_focused(t, _hide(6)), isTrue); // back on the button
        // the second Esc closes the list
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(t);
        expect(find.byType(AskRecentList), findsNothing);

        // Enter on a row opens that chat
        await t.tap(find.byKey(_recentKey));
        await _settle(t);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(t);
        expect(find.byType(AskRecentList), findsNothing);
        expect(find.text('Budget'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });

  group('keyboard hide', () {
    testWidgets('Tab to Hide, Enter: hidden, focus on, no error', (t) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      twoChats();
      final hidden = <int>[];
      askHideCall = (id, _) async => hidden.add(id);
      await _pump(t, size: const Size(768, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown); // row 6
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight); // its hide button
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(t);
      final confirm = find.byKey(const ValueKey('hide-confirm'));
      expect(_focused(t, find.byKey(const ValueKey('hide-cancel'))), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.tab); // Cancel -> Hide
      await t.pump();
      expect(_focused(t, confirm), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(t);
      expect(hidden, [6]);
      expect(_row(6), findsNothing);
      expect(find.byType(AskRecentList), findsOneWidget);
      expect(t.takeException(), isNull);
      // focus did not fall out of the list: it is on the open chat
      expect(_focused(t, _pick(5)), isTrue);
    });
  });

  group('semantics', () {
    testWidgets('desktop: hide buttons are named even while not shown', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      twoChats();
      await _pump(t, size: const Size(1280, 900));
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      // not hovered, not the open chat: drawn at 0 opacity
      expect(
        t
            .widget<AnimatedOpacity>(
              find.descendant(
                of: _row(6),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );
      expect(
        t.getSemantics(_hide(6)),
        isSemantics(
          label:
              'Hide from list: Budget for the next quarter and who signs it off',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('buttons, rows, hide and the confirmation are named', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      twoChats();
      await _pump(t, size: const Size(768, 900));
      expect(
        t.getSemantics(find.byKey(_recentKey)),
        isSemantics(
          label: 'Recent chats',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      expect(
        t.getSemantics(find.byKey(_newKey)),
        isSemantics(label: 'New chat', isButton: true, hasTapAction: true),
      );
      expect(
        find.bySemanticsLabel('3 of 10 questions used in this conversation'),
        findsOneWidget,
      );
      await t.tap(find.byKey(_recentKey));
      await _settle(t);
      expect(
        t.getSemantics(_pick(5)),
        isSemantics(
          label: 'Plan talk, Question 3/10 · 12 min ago, current chat',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        t.getSemantics(_pick(6)),
        isSemantics(
          label:
              'Budget for the next quarter and who signs it off, Question 8/10 · 21 min ago',
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      expect(
        t.getSemantics(_hide(6)),
        isSemantics(
          label:
              'Hide from list: Budget for the next quarter and who signs it off',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await t.tap(_hideIcon(6));
      await _settle(t);
      expect(
        t.getSemantics(find.text('Hide this chat from the list?')),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('icon-only New chat keeps its name', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, size: const Size(320, 1500), lang: 'ko', scale: 2);
      expect(find.text('새 대화'), findsNothing); // folded to the icon
      expect(find.byTooltip('새 대화'), findsOneWidget);
      expect(find.bySemanticsLabel('새 대화'), findsOneWidget);
      expect(t.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('Ask again names what it does and only fills the input', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      askRestoreCall = (_) async => AskRestore(
        recent: [],
        current: AskSessionView(
          id: 5,
          title: 'Lost',
          questionCount: 1,
          questionLimit: 10,
          lastActiveAt: DateTime.now().toUtc(),
          messages: [
            AskMessageView(
              seq: 1,
              question: 'Lost?',
              answer: 'Half',
              status: 'interrupted',
              citations: const [],
              createdAt: DateTime.utc(2026, 10, 16),
            ),
          ],
        ),
      );
      await _pump(t);
      expect(
        t.getSemantics(find.text('Ask again')),
        isSemantics(
          label: 'Ask again',
          hint: 'Fills the question box',
          isButton: true,
        ),
      );
      await t.tap(find.text('Ask again'));
      await t.pump();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Lost?',
      );
      expect(requests, isEmpty);
      handle.dispose();
    });
  });

  group('layout', () {
    for (final lang in ['en', 'ko']) {
      for (final scale in [1.0, 2.0]) {
        for (final (w, h) in [
          (1280.0, 800.0),
          (768.0, 1024.0),
          (390.0, 844.0),
          (320.0, 700.0),
        ]) {
          testWidgets('$lang x$scale at ${w}x$h: header, popover fit', (
            t,
          ) async {
            twoChats();
            // The old "kept on the server" banner wraps to many lines at x2
            // and (on a clean HEAD too) overflows a 320x700 window by itself.
            SharedPreferences.setMockInitialValues({
              'pb.askNoticeDismissed': true,
            });
            await _pump(t, size: Size(w, h), lang: lang, scale: scale);
            expect(t.takeException(), isNull);
            await t.tap(find.byKey(_recentKey));
            await _settle(t);
            expect(find.byType(AskRecentList), findsOneWidget);
            expect(t.takeException(), isNull);
            // the open list stays on screen
            final r = t.getRect(find.byType(AskRecentList));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(w));
            // the confirmation fits too
            await t.tap(_hideIcon(6));
            await _settle(t);
            expect(find.byKey(const ValueKey('hide-confirm')), findsOneWidget);
            expect(t.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('the header fits the 380 column in both languages', (t) async {
      for (final lang in ['en', 'ko']) {
        await _pump(t, size: const Size(1280, 900), lang: lang);
        final col = t.getRect(find.byType(AskHeader));
        expect(col.width, 380);
        expect(
          t.getRect(find.byKey(_newKey)).right,
          lessThanOrEqualTo(col.right),
        );
        expect(
          t.getRect(find.byKey(_recentKey)).left,
          greaterThan(col.left + 100),
        );
        expect(find.text(lang == 'en' ? 'New chat' : '새 대화'), findsOneWidget);
        expect(t.takeException(), isNull);
      }
    });
  });

  group('light and dark', () {
    for (final br in [Brightness.light, Brightness.dark]) {
      final pb = br == Brightness.light ? Pb.light : Pb.dark;
      testWidgets(
        '$br: header pills, open row and confirmation use the tokens',
        (
          t,
        ) async {
          twoChats();
          await _pump(t, size: const Size(1280, 900), br: br);
          Color? face(Finder f) {
            final c = find
                .descendant(of: f, matching: find.byType(AnimatedContainer))
                .first;
            return ((t.widget<AnimatedContainer>(c).decoration)
                    as BoxDecoration)
                .color;
          }

          // the New chat pill is the accent container, tinted by nothing at rest
          expect(
            face(find.byKey(_newKey)),
            Color.alphaBlend(Colors.transparent, pb.accentContainer),
          );
          await t.tap(find.byKey(_recentKey));
          await _settle(t);
          final row = t.widget<Container>(
            find
                .descendant(of: _row(5), matching: find.byType(Container))
                .first,
          );
          expect((row.decoration as BoxDecoration).color, pb.accentContainer);
          await t.tap(_hideIcon(6));
          await _settle(t);
          final confirm = find
              .ancestor(
                of: find.byKey(const ValueKey('hide-confirm')),
                matching: find.byType(Container),
              )
              .evaluate()
              .map((e) => e.widget as Container)
              .firstWhere(
                (c) =>
                    c.decoration is BoxDecoration &&
                    (c.decoration as BoxDecoration).color == pb.warnContainer,
              );
          expect((confirm.decoration as BoxDecoration).border, isNotNull);
          expect(t.takeException(), isNull);
        },
      );
    }
  });
}
