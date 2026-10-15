import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/locale_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/screens/sign_in_screen.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wired like main.dart: MaterialApp.locale follows [localeController].
Widget _app({double scale = 1.0}) => ValueListenableBuilder<Locale?>(
  valueListenable: localeController,
  builder: (context, chosen, _) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: chosen,
    theme: buildPbTheme(Brightness.light),
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    localeResolutionCallback: (locale, supported) =>
        chosen ?? const Locale('en'),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: PbBackground(child: child!),
    ),
    home: const SignInScreen(child: SizedBox()),
  ),
);

/// Form titles use keepAll (U+2060 joiners) in Korean.
Finder _text(String s) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('⁠', '') == s,
);

Future<void> _choose(WidgetTester tester, String item) async {
  await tester.tap(
    find.byTooltip(L.en.changeLanguage).evaluate().isNotEmpty
        ? find.byTooltip(L.en.changeLanguage)
        : find.byTooltip(L.ko.changeLanguage),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(CheckedPopupMenuItem<String>, item),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    app.client = Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    localeController.value = null;
  });

  testWidgets('picking 한국어 switches the sign-in copy and the controller', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 700));
    expect(_text('Sign In with email'), findsOneWidget);

    await _choose(tester, '한국어');
    expect(localeController.value, const Locale('ko'));
    expect(_text('이메일로 로그인'), findsOneWidget);
    expect(_text('Sign In with email'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('pageblink.locale'),
      'ko',
    );

    await _choose(tester, 'English');
    expect(localeController.value, const Locale('en'));
    expect(_text('Sign In with email'), findsOneWidget);
  });

  testWidgets('system default clears the saved choice', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await localeController.choose(const Locale('ko'));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 700));

    await _choose(tester, L.ko.languageSystem);
    expect(localeController.value, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('pageblink.locale'),
      isNull,
    );
  });

  group('menu open, no overflow', () {
    for (final size in const [
      Size(360, 480),
      Size(390, 844),
      Size(1280, 720),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} x$scale', (
          tester,
        ) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_app(scale: scale));
          await tester.pump(const Duration(milliseconds: 700));
          final b = find.byTooltip(L.en.changeLanguage);
          expect(tester.getSize(b).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(b).width, greaterThanOrEqualTo(44));
          await tester.tap(b);
          await tester.pumpAndSettle();
          expect(find.text('English'), findsWidgets);
          expect(find.text(L.en.languageSystem), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
