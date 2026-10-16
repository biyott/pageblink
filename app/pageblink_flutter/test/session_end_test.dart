import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/locale_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/auth/session_end.dart';
import 'package:pageblink_flutter/screens/sign_in_screen.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SessionGuard', () {
    late bool signedIn;
    late int validations;
    late Future<void> Function() onValidate;
    late bool demo;
    late DateTime clock;
    late ValueNotifier<SessionEnd?> notice;
    late SessionGuard guard;

    setUp(() {
      signedIn = true;
      validations = 0;
      demo = false;
      clock = DateTime(2026, 10, 16, 12);
      notice = ValueNotifier(null);
      // The library signs the device out when the refresh token is refused.
      onValidate = () async => signedIn = false;
      guard = SessionGuard(
        isSignedIn: () => signedIn,
        validate: () async {
          validations++;
          await onValidate();
        },
        isDemo: () => demo,
        notice: notice,
        now: () => clock,
      );
    });

    test('a 401 that ends the session leaves the expired notice', () async {
      await guard.onUnauthorized();
      expect(validations, 1);
      expect(signedIn, isFalse);
      expect(notice.value, SessionEnd.expired);
    });

    test('a demo session gets the demo wording', () async {
      demo = true;
      await guard.onUnauthorized();
      expect(notice.value, SessionEnd.demo);
    });

    test('signed out already (a public call): ignored', () async {
      signedIn = false;
      await guard.onUnauthorized();
      expect(validations, 0);
      expect(notice.value, isNull);
    });

    test('handled once: concurrent 401s validate once, later ones are '
        'ignored once signed out', () async {
      await Future.wait([
        guard.onUnauthorized(),
        guard.onUnauthorized(),
        guard.onUnauthorized(),
      ]);
      await guard.onUnauthorized();
      expect(validations, 1);
    });

    test('a network error is not a reason to sign out', () async {
      onValidate = () async => throw Exception('offline');
      await guard.onUnauthorized();
      expect(signedIn, isTrue);
      expect(notice.value, isNull);
    });

    test('a session that is still valid stays; repeats wait out the '
        'cooldown', () async {
      onValidate = () async {};
      await guard.onUnauthorized();
      await guard.onUnauthorized();
      expect(validations, 1);
      expect(notice.value, isNull);
      clock = clock.add(const Duration(seconds: 31));
      await guard.onUnauthorized();
      expect(validations, 2);
    });
  });

  group('AppClient', () {
    // No auth manager here: a 401 stays a 401 (no refresh and retry).
    app.AppClient make(int status, void Function() onUnauthorized) =>
        app.AppClient(
          'http://localhost:8080/',
          httpClientOverride: MockClient(
            (_) async => http.Response('', status),
          ),
          onUnauthorized: onUnauthorized,
        );

    test(
      'a 401 of an authenticated call is reported, and still thrown',
      () async {
        var reported = 0;
        final c = make(401, () => reported++);
        await expectLater(c.demo.status(), throwsA(anything));
        expect(reported, 1);
      },
    );

    test('a call without credentials, or another failure, is not', () async {
      var reported = 0;
      final c = make(401, () => reported++);
      await expectLater(
        c.callServerEndpoint<Object?>(
          'demo',
          'status',
          {},
          authenticated: false,
        ),
        throwsA(anything),
      );
      final c500 = make(500, () => reported++);
      await expectLater(c500.demo.status(), throwsA(anything));
      expect(reported, 0);
    });
  });

  group('notice on the sign-in screen', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      app.client = app.AppClient('http://localhost:8080/')
        ..authSessionManager = FlutterAuthSessionManager();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      localeController.value = null;
      sessionEnded.value = null;
    });
    tearDown(() => sessionEnded.value = null);

    Widget screen(String lang) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      theme: buildPbTheme(Brightness.light),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (c, child) => PbBackground(child: child!),
      home: const SignInScreen(child: SizedBox()),
    );

    Future<void> pump(WidgetTester t, String lang) async {
      t.view
        ..physicalSize = const Size(800, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(screen(lang));
      await t.pump(const Duration(milliseconds: 700));
    }

    Finder text(String s) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').replaceAll('⁠', '') == s,
    );

    testWidgets('nothing without a forced sign-out', (t) async {
      await pump(t, 'en');
      expect(find.byType(SessionEndNotice), findsNothing);
    });

    testWidgets('expired session, English, can be dismissed', (t) async {
      await pump(t, 'en');
      sessionEnded.value = SessionEnd.expired;
      await t.pump();
      expect(
        text('Your session has expired. Please sign in again.'),
        findsOneWidget,
      );
      await t.tap(find.byTooltip(L.en.dismiss));
      await t.pump();
      expect(find.byType(SessionEndNotice), findsNothing);
      expect(sessionEnded.value, isNull);
    });

    testWidgets('demo session, Korean', (t) async {
      await pump(t, 'ko');
      sessionEnded.value = SessionEnd.demo;
      await t.pump();
      expect(text('데모 세션이 끝났어요. 다시 체험해 보세요'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('expired session, Korean', (t) async {
      await pump(t, 'ko');
      sessionEnded.value = SessionEnd.expired;
      await t.pump();
      expect(text('세션이 만료되어 다시 로그인이 필요해요'), findsOneWidget);
    });

    testWidgets('narrow screen: no overflow', (t) async {
      t.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      sessionEnded.value = SessionEnd.demo;
      await t.pumpWidget(screen('ko'));
      await t.pump(const Duration(milliseconds: 700));
      expect(find.byType(SessionEndNotice), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
