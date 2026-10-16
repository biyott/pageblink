import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/app/visitor_key.dart';
import 'package:pageblink_flutter/features/ask/ask_chat.dart';
import 'package:pageblink_flutter/features/ask/ask_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

AskHistoryStatus _status({
  bool enabled = true,
  int limit = 10,
  int days = 30,
  int maxChars = 2000,
}) => AskHistoryStatus(
  enabled: enabled,
  questionLimit: limit,
  visibleMinutes: 30,
  retentionDays: days,
  questionMaxChars: maxChars,
  isAdmin: false,
);

AskMessageView _msg(
  int seq,
  String q, {
  String a = 'Answer.',
  String status = 'done',
  List<Citation> citations = const [],
}) => AskMessageView(
  seq: seq,
  question: q,
  answer: a,
  status: status,
  citations: citations,
  createdAt: DateTime.utc(2026, 10, 16),
);

AskSessionView _view(
  int id,
  List<AskMessageView> messages, {
  int? count,
  int limit = 10,
}) => AskSessionView(
  id: id,
  title: messages.first.question,
  questionCount: count ?? messages.length,
  questionLimit: limit,
  lastActiveAt: DateTime.now().toUtc(),
  messages: messages,
);

Citation _cite(int i) => Citation(
  index: i,
  documentId: i,
  documentTitle: 'Plan $i',
  kind: 'note',
  page: 1,
  quote: 'Finalize the release notes',
  quoteStart: 3,
);

/// session + token + done, as the server streams a normal answer.
Stream<AnswerEvent> _answer(int id, int count, {int limit = 10}) =>
    Stream.fromIterable([
      AnswerEvent(
        type: 'session',
        sessionId: id,
        questionCount: count,
        questionLimit: limit,
      ),
      AnswerEvent(type: 'token', text: 'Reply $count.'),
      AnswerEvent(type: 'done'),
    ]);

void main() {
  final requests = <AskRequest>[];

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
  });

  tearDown(() {
    historyStatusCall = null;
    askRestoreCall = null;
    askOpenCall = null;
    askHideCall = null;
    askStreamCall = null;
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester t, {Size size = const Size(800, 1000)}) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: const Locale('en'),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: AskScreen(projects: [])),
      ),
    );
    await settle(t);
  }

  Future<void> send(WidgetTester t, String q) async {
    await t.enterText(find.byType(TextField), q);
    await t.pump();
    await t.tap(find.byIcon(AppIcons.send));
    await settle(t);
  }

  Finder countChip(String s) => find.descendant(
    of: find.byKey(const ValueKey('ask-count')),
    matching: find.textContaining(s),
  );

  testWidgets('restore: turns, source chips and markers come back', (t) async {
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [
        _msg(1, 'What is the plan?', a: 'Do it [1].', citations: [_cite(1)]),
        _msg(2, 'And then?', a: 'Related text.', citations: [_cite(2)]),
      ]),
    );
    await pump(t);
    expect(find.text('What is the plan?'), findsOneWidget);
    expect(find.text('And then?'), findsOneWidget);
    expect(find.byKey(const ValueKey('cite-marker-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('source-chip-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('source-chip-2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cite-marker-1')));
    await settle(t);
    expect(t.takeException(), isNull);
    // restored counts
    expect(countChip('Question 2/10'), findsOneWidget);
  });

  testWidgets('no current conversation: the example questions show', (t) async {
    await pump(t);
    expect(find.byType(AskEmptyHint), findsOneWidget);
  });

  testWidgets('a cut-off turn offers Ask again, which only fills the input', (
    t,
  ) async {
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [
        _msg(1, 'Lost question?', a: 'Half an ans', status: 'interrupted'),
      ]),
    );
    await pump(t);
    expect(find.text('This answer was cut off.'), findsOneWidget);
    expect(find.text('Half an ans'), findsOneWidget);
    await t.tap(find.text('Ask again'));
    await t.pump();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Lost question?',
    );
    expect(requests, isEmpty);
  });

  testWidgets('a turn the server is still finishing is re-read, then cut off', (
    t,
  ) async {
    var opens = 0;
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [_msg(1, 'Slow?', a: 'part', status: 'streaming')]),
    );
    askOpenCall = (id, _) async {
      opens++;
      return _view(5, [_msg(1, 'Slow?', a: 'part', status: 'streaming')]);
    };
    await pump(t);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(seconds: 2));
    }
    expect(opens, 5);
    expect(find.text('This answer was cut off.'), findsOneWidget);
  });

  testWidgets('new conversation sends 0, then the id; New starts over', (
    t,
  ) async {
    await pump(t);
    await send(t, 'Q1');
    expect(requests.last.sessionId, 0);
    expect(requests.last.visitorKey, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    await send(t, 'Q2');
    expect(requests.last.sessionId, 7);
    expect(find.text('Q1'), findsOneWidget);
    expect(countChip('Question 2/10'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('ask-new-chat')));
    await settle(t);
    expect(find.text('Q1'), findsNothing);
    expect(find.byKey(const ValueKey('ask-count')), findsNothing);
    await send(t, 'Q3');
    expect(requests.last.sessionId, 0);
  });

  testWidgets('counter: emphasis near the limit, input blocked at it', (
    t,
  ) async {
    await pump(t);
    askStreamCall = (r) {
      requests.add(r);
      return _answer(7, 7);
    };
    await send(t, 'Q1');
    expect(countChip('Question 7/10'), findsOneWidget);
    expect(find.byIcon(AppIcons.warning), findsNothing);

    askStreamCall = (r) => _answer(7, 8);
    await send(t, 'Q2');
    expect(countChip('Question 8/10'), findsOneWidget);
    expect(countChip('2 left'), findsOneWidget);
    expect(find.byIcon(AppIcons.warning), findsWidgets);
    expect(find.byKey(const ValueKey('ask-limit-banner')), findsNothing);

    askStreamCall = (r) => _answer(7, 10);
    await send(t, 'Q3');
    final banner = find.byKey(const ValueKey('ask-limit-banner'));
    expect(banner, findsOneWidget);
    // the card ends the thread (inside the list, not the input panel)
    expect(
      find.descendant(of: find.byType(ListView), matching: banner),
      findsOneWidget,
    );
    expect(countChip('Question 10/10'), findsOneWidget);
    expect(find.textContaining('asked 10 questions'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Start a new conversation'), findsOneWidget);
    // the banner's button starts over
    await t.tap(
      find.descendant(of: banner, matching: find.text('New chat')),
    );
    await settle(t);
    expect(banner, findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('the limit is the server\'s: 5 here', (t) async {
    historyStatusCall = () async => _status(limit: 5);
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [
        _msg(1, 'a'),
        _msg(2, 'b'),
        _msg(3, 'c'),
      ], limit: 5),
    );
    await pump(t);
    expect(countChip('Question 3/5'), findsOneWidget);
    expect(countChip('2 left'), findsOneWidget);
  });

  testWidgets('expired: starts a new conversation once, with the same text', (
    t,
  ) async {
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [_msg(1, 'Earlier')]),
    );
    await pump(t);
    askStreamCall = (r) {
      requests.add(r);
      return r.sessionId == 5
          ? Stream.error(AskLimitException(reason: AskLimitReason.expired))
          : _answer(9, 1);
    };
    await send(t, 'Later');
    expect(requests.map((r) => r.sessionId), [5, 0]);
    expect(requests.map((r) => r.question), ['Later', 'Later']);
    expect(find.text('Earlier'), findsNothing);
    expect(find.text('Later'), findsOneWidget);
    expect(
      find.text('That conversation expired, so this starts a new one.'),
      findsOneWidget,
    );
  });

  testWidgets('expired twice does not loop', (t) async {
    await pump(t);
    askStreamCall = (r) {
      requests.add(r);
      return Stream.error(AskLimitException(reason: AskLimitReason.expired));
    };
    await send(t, 'Q');
    // sessionId 0 asked: expired makes no sense, shown as a failure, no resend
    expect(requests, hasLength(1));
    expect(
      find.text('Could not get an answer. Please try again shortly.'),
      findsOneWidget,
    );
  });

  testWidgets('busy: hint, and the question goes back to the input', (t) async {
    await pump(t);
    askStreamCall = (r) {
      requests.add(r);
      return Stream.error(AskLimitException(reason: AskLimitReason.busy));
    };
    await send(t, 'Quick one');
    expect(find.textContaining('still being written'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Quick one',
    );
    expect(find.text('Quick one'), findsOneWidget); // only in the input
  });

  testWidgets('question limit refusal: banner, text returns to the input', (
    t,
  ) async {
    await pump(t);
    askStreamCall = (r) => Stream.error(
      AskLimitException(reason: AskLimitReason.questionLimit, limit: 10),
    );
    await send(t, 'One more');
    expect(find.byKey(const ValueKey('ask-limit-banner')), findsOneWidget);
    // the only turn was dropped: a thread with just the card, no examples
    expect(find.byType(AskEmptyHint), findsNothing);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'One more',
    );
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    // its button starts over: the examples come back
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ask-limit-banner')),
        matching: find.text('New chat'),
      ),
    );
    await settle(t);
    expect(find.byType(AskEmptyHint), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-limit-banner')), findsNothing);
  });

  for (final off in <String, Future<AskHistoryStatus> Function()>{
    'flag off': () async => _status(enabled: false),
    'status fails': () async => throw Exception('404'),
  }.entries) {
    testWidgets('${off.key}: no new UI, ask sends no session', (t) async {
      historyStatusCall = off.value;
      askStreamCall = (r) {
        requests.add(r);
        return Stream.fromIterable([
          AnswerEvent(type: 'token', text: 'Old style.'),
          AnswerEvent(type: 'done'),
        ]);
      };
      await pump(t);
      expect(find.byKey(const ValueKey('ask-recent')), findsNothing);
      expect(find.byKey(const ValueKey('ask-new-chat')), findsNothing);
      expect(find.byKey(const ValueKey('ask-count')), findsNothing);
      expect(find.byTooltip('New question'), findsNothing); // 800 wide: none
      expect(find.textContaining('kept on the server'), findsNothing);
      await send(t, 'Q');
      expect(requests.single.sessionId, isNull);
      expect(requests.single.visitorKey, isNull);
      expect(find.text('Old style.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-count')), findsNothing);
      // the input is not capped
      expect(
        t.widget<TextField>(find.byType(TextField)).inputFormatters,
        isNull,
      );
    });
  }

  testWidgets('the input stops at the server\'s question length', (t) async {
    historyStatusCall = () async => _status(maxChars: 10);
    await pump(t);
    await t.enterText(find.byType(TextField), 'x' * 30);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      hasLength(10),
    );
  });

  testWidgets('the notice shows once, closes, and stays closed', (t) async {
    historyStatusCall = () async => _status(days: 14);
    await pump(t);
    expect(
      find.textContaining('kept on the server for 14 days'),
      findsOneWidget,
    );
    await t.tap(find.byTooltip('Dismiss'));
    await settle(t);
    expect(find.textContaining('kept on the server'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool('pb.askNoticeDismissed'),
      isTrue,
    );

    // a fresh screen (a reload) reads the saved flag
    resetNotice();
    resetHistoryStatus();
    await t.pumpWidget(const SizedBox());
    await pump(t);
    expect(find.textContaining('kept on the server'), findsNothing);
  });

  testWidgets('recent list: rows, hide with confirmation, open', (t) async {
    final now = DateTime.now().toUtc();
    var recent = [
      AskSessionSummary(
        id: 5,
        title: 'Plan talk',
        questionCount: 3,
        lastActiveAt: now.subtract(const Duration(minutes: 12)),
      ),
      AskSessionSummary(
        id: 6,
        title: 'Budget',
        questionCount: 1,
        lastActiveAt: now,
      ),
    ];
    askRestoreCall = (_) async => AskRestore(recent: recent);
    askOpenCall = (id, _) async =>
        id == 6 ? _view(6, [_msg(1, 'Budget')]) : null;
    final hidden = <int>[];
    askHideCall = (id, _) async => hidden.add(id);
    await pump(t);
    await t.tap(find.byKey(const ValueKey('ask-recent')));
    await settle(t);
    expect(find.text('Plan talk'), findsOneWidget);
    expect(find.textContaining('Question 3/10 · 12 min ago'), findsOneWidget);
    expect(find.textContaining('Shown for 30 minutes'), findsOneWidget);
    expect(find.textContaining('kept on the server for 30 days'), findsWidgets);

    // hide one: the icon asks first, Cancel changes nothing
    Finder hideIcon(int id) => find.descendant(
      of: find.byKey(ValueKey('recent-$id')),
      matching: find.byIcon(AppIcons.hideChat),
    );
    await t.tap(hideIcon(5));
    await settle(t);
    expect(find.text('Hide this chat from the list?'), findsOneWidget);
    expect(hidden, isEmpty);
    await t.tap(find.byKey(const ValueKey('hide-cancel')));
    await settle(t);
    expect(find.text('Hide this chat from the list?'), findsNothing);
    expect(hidden, isEmpty);
    expect(find.text('Plan talk'), findsOneWidget);

    // ... and Hide does it
    await t.tap(hideIcon(5));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('hide-confirm')));
    await settle(t);
    expect(hidden, [5]);
    expect(find.text('Plan talk'), findsNothing);

    // open the other
    await t.tap(find.byKey(const ValueKey('recent-6')));
    await settle(t);
    expect(find.byType(AskTurnView), findsOneWidget); // now the turn
    expect(countChip('Question 1/10'), findsOneWidget);
    expect(find.text('Plan talk'), findsNothing); // the popover is closed
  });

  testWidgets('opening a conversation that is gone says so', (t) async {
    recent() => AskRestore(
      recent: [
        AskSessionSummary(
          id: 5,
          title: 'Old',
          questionCount: 1,
          lastActiveAt: DateTime.now().toUtc(),
        ),
      ],
    );
    askRestoreCall = (_) async => recent();
    askOpenCall = (id, _) async => null;
    await pump(t);
    await t.tap(find.byKey(const ValueKey('ask-recent')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('recent-5')));
    await settle(t);
    expect(
      find.text('That conversation is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('a restore that fails still lets you ask', (t) async {
    askRestoreCall = (_) async => throw Exception('boom');
    await pump(t);
    expect(
      find.text("Couldn't load your recent conversation."),
      findsOneWidget,
    );
    await send(t, 'Q');
    expect(requests.single.sessionId, 0);
    expect(find.text('Reply 1.'), findsOneWidget);
  });

  testWidgets('works on a phone width without overflow', (t) async {
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [_msg(1, 'Q')], count: 9),
    );
    await pump(t, size: const Size(360, 780));
    expect(countChip('Question 9/10'), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-recent')), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-new-chat')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Korean labels', (t) async {
    askRestoreCall = (_) async => AskRestore(
      recent: [],
      current: _view(5, [_msg(1, 'Q')], count: 8),
    );
    t.view
      ..physicalSize = const Size(800, 1000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: const Locale('ko'),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: AskScreen(projects: [])),
      ),
    );
    await settle(t);
    expect(countChip('질문 8/10'), findsOneWidget);
    expect(countChip('2개 남음'), findsOneWidget);
    expect(find.text('새 대화'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').replaceAll('\u2060', '').contains('서버에 30일 동안 보관돼요'),
      ),
      findsOneWidget,
    );
  });
}
