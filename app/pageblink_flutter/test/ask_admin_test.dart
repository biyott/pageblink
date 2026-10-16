import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_chat.dart';
import 'package:pageblink_flutter/features/settings/admin_history_screen.dart';
import 'package:pageblink_flutter/features/settings/settings_screen.dart';

AskHistoryStatus _status({bool admin = false, bool enabled = true}) =>
    AskHistoryStatus(
      enabled: enabled,
      questionLimit: 10,
      visibleMinutes: 30,
      retentionDays: 30,
      questionMaxChars: 2000,
      isAdmin: admin,
    );

AskAdminSession _session(
  int id, {
  String owner = 'u-1',
  bool fallback = false,
}) => AskAdminSession(
  id: id,
  ownerId: owner,
  ownerLabel: owner,
  isDemo: false,
  hidden: id == 3,
  title: 'Title $id',
  locale: 'ko',
  questionCount: 1,
  createdAt: DateTime.utc(2026, 10, 16, 1),
  lastActiveAt: DateTime.utc(2026, 10, 16, 2),
  messages: [
    AskMessageView(
      seq: 1,
      question: 'Question $id?',
      answer: 'Answer $id.',
      status: 'done',
      citations: [
        Citation(
          index: 1,
          documentId: 4,
          documentTitle: 'Doc $id',
          page: 1,
          quote: 'q',
        ),
      ],
      modelId: 'm/one',
      fallback: fallback,
      createdAt: DateTime.utc(2026, 10, 16, 2),
    ),
  ],
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    resetHistoryStatus();
    accountIdCall = () => 'user-uuid-1';
  });

  tearDown(() {
    accountIdCall = null;
    askAdminListCall = null;
  });

  Future<void> pump(WidgetTester t, Widget home, {String lang = 'en'}) async {
    t.view
      ..physicalSize = const Size(800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: Locale(lang),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: home),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
  }

  Widget settings() => SettingsScreen(embedded: false, onClose: () {});

  testWidgets('copy my account ID copies the signed-in user id', (t) async {
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(t, settings());
    await t.tap(find.text('Copy my account ID'));
    await t.pump();
    expect(copied, ['user-uuid-1']);
    expect(find.text('Copied account ID'), findsOneWidget);
  });

  testWidgets('no account id: no copy tile', (t) async {
    accountIdCall = () => null;
    await pump(t, settings());
    expect(find.text('Copy my account ID'), findsNothing);
  });

  testWidgets('history on: the permanent notice line; off: nothing', (t) async {
    historyStatus.value = _status();
    await pump(t, settings());
    expect(
      find.textContaining('kept on the server for 30 days'),
      findsOneWidget,
    );
    expect(find.text('Conversation history'), findsNothing);

    historyStatus.value = _status(enabled: false, admin: true);
    await t.pump();
    expect(find.textContaining('kept on the server'), findsNothing);
    expect(find.text('Conversation history'), findsNothing);
  });

  testWidgets('the admin tile shows only for an admin', (t) async {
    historyStatus.value = _status(admin: true);
    await pump(t, settings(), lang: 'ko');
    expect(find.text('대화 기록'), findsOneWidget);
    expect(find.text('내 계정 ID 복사'), findsOneWidget);
  });

  testWidgets('admin list: models, expand, filters, load more', (t) async {
    final filters = <AskAdminFilter>[];
    askAdminListCall = (f) async {
      filters.add(f);
      final first = f.beforeId == null;
      return AskAdminPage(
        items: first
            ? [_session(3), _session(2, fallback: true)]
            : [_session(1)],
        nextBeforeActiveAt: first ? DateTime.utc(2026, 10, 16, 2) : null,
        nextBeforeId: first ? 2 : null,
        models: [AskModelStat(modelId: 'm/one', answers: 5, fallbacks: 2)],
      );
    };
    historyStatus.value = _status(admin: true);
    await pump(t, settings());
    await t.tap(find.text('Conversation history'));
    await t.pumpAndSettle();

    expect(
      find.textContaining('May contain personal note content'),
      findsOneWidget,
    );
    expect(find.text('m/one: 5 (2 fallback)'), findsOneWidget);
    expect(find.text('Title 3'), findsOneWidget);
    expect(find.textContaining('Hidden'), findsOneWidget);
    // collapsed: no answers yet
    expect(find.text('Answer 2.'), findsNothing);
    await t.tap(find.text('Title 2'));
    await t.pumpAndSettle();
    expect(find.text('Question 2?'), findsOneWidget);
    expect(find.text('Answer 2.'), findsOneWidget);
    expect(find.text('[1] Doc 2'), findsOneWidget);
    expect(find.textContaining('fallback model'), findsOneWidget);

    // keyset cursor
    await t.ensureVisible(find.byKey(const ValueKey('admin-more')));
    await t.tap(find.byKey(const ValueKey('admin-more')));
    await t.pumpAndSettle();
    expect(filters.last.beforeId, 2);
    expect(filters.last.beforeActiveAt, DateTime.utc(2026, 10, 16, 2));
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-more')), findsNothing);

    // user id filter
    await t.enterText(find.byKey(const ValueKey('admin-user')), ' u-9 ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(filters.last.userId, 'u-9');
    expect(filters.last.beforeId, isNull);
    expect(find.text('Title 1'), findsNothing);

    // period chip
    await t.tap(find.byKey(const ValueKey('period-d7')));
    await t.pumpAndSettle();
    expect(filters.last.from, isNotNull);
    final age = DateTime.now().toUtc().difference(filters.last.from!);
    expect(age.inDays, 7);
    await t.tap(find.byKey(const ValueKey('period-all')));
    await t.pumpAndSettle();
    expect(filters.last.from, isNull);
  });

  testWidgets('admin list: failure message, empty message', (t) async {
    askAdminListCall = (_) async => throw Exception('403');
    await pump(t, const AdminHistoryPage());
    await t.pumpAndSettle();
    expect(find.text("Couldn't load the list."), findsOneWidget);

    askAdminListCall = (_) async => AskAdminPage(items: [], models: []);
    await t.tap(find.byKey(const ValueKey('period-today')));
    await t.pumpAndSettle();
    expect(find.text('No conversations found'), findsOneWidget);
  });
}
