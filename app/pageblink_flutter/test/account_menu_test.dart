import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/account/account.dart';
import 'package:pageblink_flutter/features/account/account_menu.dart';
import 'package:pageblink_flutter/features/demo/demo.dart';
import 'package:pageblink_flutter/main.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

/// The account block of the real shell (an unreachable server: every other
/// call fails quietly) and its menu / sheet.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    app.client = Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager();
  });

  var signedOut = 0;
  setUp(() {
    signedOut = 0;
    signOutCall = () async => signedOut++;
    accountInfoCall = () async =>
        AccountInfo(email: 'minji@example.com', isDemo: false);
    demoStatusCall = () async => DemoStatus(enabled: true, isDemo: false);
  });
  tearDown(() {
    signOutCall = null;
    accountInfoCall = null;
    demoStatusCall = null;
  });

  Future<void> pump(WidgetTester t, Size size, {String lang = 'en'}) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: Locale(lang),
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (c, child) => PbBackground(child: child!),
        home: const HomeShell(),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  }

  const desktop = Size(1440, 900);
  const tablet = Size(800, 700);
  const phone = Size(390, 844);

  final row = find.byType(AccountRow);
  final avatarButton = find.byType(AccountAvatarButton);

  group('sidebar (>= 1024)', () {
    testWidgets('shows initial and email, no sign-out row', (t) async {
      await pump(t, desktop);
      expect(find.descendant(of: row, matching: find.text('M')), findsOne);
      expect(
        find.descendant(of: row, matching: find.text('minji@example.com')),
        findsOne,
      );
      // Sign out is in the menu now, not in the sidebar.
      expect(find.text('Sign out'), findsNothing);
      expect(avatarButton, findsNothing);
    });

    testWidgets('the row is 52 high with a chevron', (t) async {
      await pump(t, desktop);
      expect(
        t
            .getSize(
              find.descendant(
                of: row,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .height,
        52,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(AppIcons.expand)),
        findsOne,
      );
    });

    testWidgets('email unknown: My account and a person icon', (t) async {
      accountInfoCall = () async => throw Exception('offline');
      await pump(t, desktop);
      expect(
        find.descendant(of: row, matching: find.text('My account')),
        findsOne,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(AppIcons.account)),
        findsOne,
      );
    });

    testWidgets('demo: Demo account and the shared chip, no email', (t) async {
      accountInfoCall = () async => AccountInfo(isDemo: true);
      await pump(t, desktop);
      expect(
        find.descendant(of: row, matching: find.text('Demo account')),
        findsOne,
      );
      expect(
        find.descendant(of: row, matching: find.text('Shared account')),
        findsOne,
      );
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('demo known from demo.status() alone', (t) async {
      accountInfoCall = () async => throw Exception('offline');
      demoStatusCall = () async => DemoStatus(enabled: true, isDemo: true);
      await pump(t, desktop);
      expect(
        find.descendant(of: row, matching: find.text('Demo account')),
        findsOne,
      );
    });

    testWidgets('12 above and 12 below the divider', (t) async {
      await pump(t, desktop);
      final column = t.widget<Column>(
        find.ancestor(of: row, matching: find.byType(Column)).first,
      );
      final i = column.children.indexWhere((w) => w is AccountRow);
      expect(i, greaterThan(3));
      double? gap(Widget w) => w is SizedBox ? w.height : null;
      expect(gap(column.children[i - 1]), 12);
      expect(column.children[i - 2], isA<Divider>());
      expect(gap(column.children[i - 3]), 12);
      expect(column.children[i - 4], isA<Spacer>());
    });

    testWidgets('the menu opens upward, ends above the row', (t) async {
      await pump(t, desktop);
      final rowRect = t.getRect(
        find.descendant(of: row, matching: find.byType(AnimatedContainer)),
      );
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('Signed in as'), findsOne);
      final menu = t.getRect(find.byType(Material).last);
      expect(menu.bottom, lessThanOrEqualTo(rowRect.top));
      expect(menu.bottom, greaterThan(rowRect.top - 16));
      expect(menu.width, 272);
      // Account name in the menu and in the row.
      expect(find.text('minji@example.com'), findsNWidgets(2));
    });

    testWidgets('sign out from the menu', (t) async {
      await pump(t, desktop);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('Sign up'), findsNothing);
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      expect(signedOut, 1);
      expect(find.text('Signed in as'), findsNothing);
    });

    testWidgets('demo menu: note, Sign up, Sign out', (t) async {
      accountInfoCall = () async => AccountInfo(isDemo: true);
      await pump(t, desktop);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('Demo account'), findsNWidgets(2));
      expect(find.text('Shared account'), findsNWidgets(2));
      expect(find.textContaining('Other visitors can see'), findsOne);
      expect(find.text('Sign up'), findsWidgets);
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      expect(signedOut, 1);
    });

    testWidgets('a long email stays on one line', (t) async {
      accountInfoCall = () async => AccountInfo(
        email:
            'a.very.long.address.that.keeps.going@some-long-domain.example.com',
        isDemo: false,
      );
      await pump(t, desktop);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('keyboard: Enter opens, Esc closes', (t) async {
      await pump(t, desktop);
      final inner = t.element(
        find.descendant(of: row, matching: find.byType(AnimatedContainer)),
      );
      Focus.of(inner).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Signed in as'), findsOne);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Signed in as'), findsNothing);
      expect(signedOut, 0);
    });

    testWidgets('semantics: button named with the account', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, desktop);
      expect(
        find.bySemanticsLabel('Account: minji@example.com'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Korean labels', (t) async {
      await pump(t, desktop, lang: 'ko');
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('로그인한 계정'), findsOne);
      expect(find.text('로그아웃'), findsOne);
    });
  });

  group('AppBar (< 1024)', () {
    for (final size in const [tablet, phone]) {
      testWidgets(
        'avatar instead of the sign-out icon at ${size.width.toInt()}',
        (
          t,
        ) async {
          await pump(t, size);
          expect(avatarButton, findsOne);
          expect(
            find.descendant(of: avatarButton, matching: find.text('M')),
            findsOne,
          );
          expect(find.byIcon(AppIcons.signOut), findsNothing);
          // Settings stays.
          expect(find.byIcon(AppIcons.settings), findsOne);
          // 48 hit area, 32 avatar.
          expect(t.getSize(avatarButton), const Size(48, 48));
          expect(
            t.getSize(
              find.descendant(
                of: avatarButton,
                matching: find.byType(AccountAvatar),
              ),
            ),
            const Size(32, 32),
          );
          expect(row, findsNothing);
        },
      );
    }

    testWidgets('tablet: a menu under the avatar, sign out works', (t) async {
      await pump(t, tablet);
      await t.tap(avatarButton);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final menu = t.getRect(find.byType(Material).last);
      expect(
        menu.top,
        greaterThanOrEqualTo(
          t
              .getRect(
                find.descendant(
                  of: avatarButton,
                  matching: find.byType(AccountAvatar),
                ),
              )
              .bottom,
        ),
      );
      expect(menu.right, lessThanOrEqualTo(800));
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      expect(signedOut, 1);
    });

    testWidgets('phone: a bottom sheet with avatar 48 and a 56 row', (t) async {
      await pump(t, phone);
      await t.tap(avatarButton);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOne);
      expect(find.text('Signed in as'), findsOne);
      expect(
        t.getSize(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(AccountAvatar),
          ),
        ),
        const Size(48, 48),
      );
      final signOutRow = find.ancestor(
        of: find.text('Sign out'),
        matching: find.byType(ListTile),
      );
      expect(t.getSize(signOutRow).height, 56);
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      expect(signedOut, 1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('phone demo: note and Sign up in the sheet', (t) async {
      accountInfoCall = () async => AccountInfo(isDemo: true);
      await pump(t, phone);
      await t.tap(avatarButton);
      await t.pumpAndSettle();
      expect(find.textContaining('Other visitors can see'), findsOne);
      expect(find.text('Sign up'), findsWidgets);
      expect(find.text('Shared account'), findsOne);
    });

    testWidgets('keyboard: Enter opens, Esc closes the sheet', (t) async {
      await pump(t, phone);
      final inner = t.element(
        find.descendant(of: avatarButton, matching: find.byType(AccountAvatar)),
      );
      Focus.of(inner).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOne);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  test('the account is forgotten between sessions', () {
    accountInfo.value = AccountInfo(email: 'x@example.com', isDemo: false);
    resetAccountInfo();
    expect(accountInfo.value, isNull);
  });
}
