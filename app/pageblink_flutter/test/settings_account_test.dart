import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/app_version.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/account/account.dart';
import 'package:pageblink_flutter/features/account/account_menu.dart';
import 'package:pageblink_flutter/features/ask/ask_chat.dart';
import 'package:pageblink_flutter/features/settings/settings_screen.dart';

const _id = '7f3c91ab-0000-4000-8000-0123456789a91e';

AskHistoryStatus _status({bool admin = false}) => AskHistoryStatus(
  enabled: true,
  questionLimit: 10,
  visibleMinutes: 30,
  retentionDays: 30,
  questionMaxChars: 2000,
  isAdmin: admin,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  var signedOut = 0;
  setUp(() {
    signedOut = 0;
    resetHistoryStatus();
    resetAccountInfo();
    accountInfo.value = AccountInfo(email: 'minji@example.com', isDemo: false);
    accountIdCall = () => _id;
    signOutCall = () async => signedOut++;
  });
  tearDown(() {
    accountIdCall = null;
    signOutCall = null;
    resetAccountInfo();
  });

  Future<void> pump(WidgetTester t, {String lang = 'en'}) async {
    t.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: Locale(lang),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SettingsScreen(embedded: false, onClose: () {}),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
  }

  final version = find.text('PageBlink v$appVersion');
  // The row's copy button (the 7th tap also shows an 'Account ID' snackbar).
  final idRow = find.byTooltip('Copy account ID');

  Future<void> tapVersion(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.tap(version);
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('account group at the top: identity and sign out', (t) async {
    await pump(t);
    final account = t.getTopLeft(find.text('Account')).dy;
    expect(account, lessThan(t.getTopLeft(find.text('Language')).dy));
    expect(find.text('Signed in as'), findsOne);
    expect(find.text('minji@example.com'), findsOne);
    expect(find.text('M'), findsOne);
    // The sign-out row is inside the group, above the language section.
    expect(
      t.getTopLeft(find.text('Sign out')).dy,
      lessThan(t.getTopLeft(find.text('Language')).dy),
    );
    await t.tap(find.text('Sign out'));
    await t.pump();
    expect(signedOut, 1);
  });

  testWidgets('both groups are 16-radius paper with a hairline', (t) async {
    await pump(t);
    final groups = t
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.shape is RoundedRectangleBorder)
        .map((m) => m.shape! as RoundedRectangleBorder)
        .where((s) => s.borderRadius == BorderRadius.circular(16))
        .toList();
    expect(groups.length, 2);
    expect(groups.every((s) => s.side.width == 1), isTrue);
  });

  testWidgets('language radios still switch', (t) async {
    await pump(t);
    expect(find.byType(RadioListTile<String>), findsNWidgets(3));
  });

  testWidgets('demo account: identity without email, never an ID', (
    t,
  ) async {
    accountInfo.value = AccountInfo(isDemo: true);
    historyStatus.value = _status(admin: true);
    await pump(t);
    expect(find.text('Demo account'), findsOne);
    expect(find.text('Shared account'), findsOne);
    expect(find.text('minji@example.com'), findsNothing);
    // Never an account ID for the demo account, even for an admin.
    expect(idRow, findsNothing);
    await tapVersion(t, 7);
    expect(idRow, findsNothing);
  });

  group('account ID row', () {
    testWidgets('hidden for a regular account', (t) async {
      historyStatus.value = _status();
      await pump(t);
      expect(idRow, findsNothing);
      expect(find.byTooltip('Copy account ID'), findsNothing);
      expect(find.textContaining('Share your account ID'), findsNothing);
    });

    testWidgets('visible for an admin: short value, hint, copy', (t) async {
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
      historyStatus.value = _status(admin: true);
      await pump(t);
      expect(idRow, findsOne);
      expect(find.text('7f3c91ab…a91e'), findsOne);
      expect(find.textContaining('Share your account ID'), findsOne);
      await t.tap(find.byIcon(AppIcons.copy));
      await t.pump();
      expect(copied, [_id]);
      expect(find.text('Copied account ID'), findsOne);
    });

    test('the shortened value: 8 chars, ellipsis, last 4', () {
      expect(shortAccountId(_id), '7f3c91ab…a91e');
      expect(shortAccountId('abc'), 'abc');
    });

    testWidgets('appears after the admin status arrives', (t) async {
      await pump(t);
      expect(idRow, findsNothing);
      historyStatus.value = _status(admin: true);
      await t.pump();
      expect(idRow, findsOne);
    });

    testWidgets('no id (not signed in): no row', (t) async {
      accountIdCall = () => null;
      historyStatus.value = _status(admin: true);
      await pump(t);
      expect(idRow, findsNothing);
    });
  });

  group('7 taps on the version line', () {
    testWidgets('the version line: muted label at the bottom', (t) async {
      await pump(t);
      expect(version, findsOne);
      expect(find.text('PageBlink v1.0.0'), findsOne);
      expect(
        t.getTopLeft(version).dy,
        greaterThan(t.getTopLeft(find.text('Language')).dy),
      );
    });

    testWidgets('6 taps do nothing, the 7th reveals the row', (t) async {
      await pump(t);
      await tapVersion(t, 6);
      expect(idRow, findsNothing);
      await tapVersion(t, 1);
      expect(idRow, findsOne);
      expect(find.byTooltip('Copy account ID'), findsOne);
      // Stays for the visit, more taps change nothing.
      await tapVersion(t, 3);
      expect(idRow, findsOne);
    });

    testWidgets('the count starts over after 3 s idle', (t) async {
      await pump(t);
      await tapVersion(t, 6);
      await t.pump(const Duration(seconds: 4));
      await tapVersion(t, 1);
      expect(idRow, findsNothing);
      await tapVersion(t, 5);
      expect(idRow, findsNothing);
      await tapVersion(t, 1);
      expect(idRow, findsOne);
    });

    testWidgets('taps spread under 3 s apart still count', (t) async {
      await pump(t);
      for (var i = 0; i < 7; i++) {
        await t.tap(version);
        await t.pump(const Duration(milliseconds: 2500));
      }
      expect(idRow, findsOne);
    });

    testWidgets('not persisted: a new visit hides it again', (t) async {
      await pump(t);
      await tapVersion(t, 7);
      expect(idRow, findsOne);
      await t.pumpWidget(const SizedBox()); // leave and come back
      await pump(t);
      expect(idRow, findsNothing);
    });
  });

  test('app version: just the version unless a build id is injected', () {
    const build = String.fromEnvironment('APP_BUILD');
    expect(appVersion, build.isEmpty ? '1.0.0' : '1.0.0 · $build');
  });
}
