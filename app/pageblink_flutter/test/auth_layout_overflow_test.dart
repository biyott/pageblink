import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/screens/email_sign_in.dart';
import 'package:pageblink_flutter/screens/sign_in_screen.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

const _sizes = [
  Size(360, 480),
  Size(360, 640),
  Size(390, 844),
  Size(800, 500),
  Size(1280, 720),
];
const _scales = [1.0, 1.5, 2.0];
const _keyboards = [0.0, 300.0]; // bottom viewInsets, logical px

Widget _app(Widget home, {required double scale, required String lang}) {
  final base = buildPbTheme(Brightness.light);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(lang),
    // flutter_test has no Fraunces; the bundled Pretendard subset covers Latin
    // and Hangul, so use it for every style (close to real widths).
    theme: base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: pbSansFamily),
    ),
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: PbBackground(child: child!),
    ),
    home: home,
  );
}

/// The real card around any step of the email flow, in the same scroll shell
/// as SignInScreen (the controller of SignInScreen itself is private).
class _CardHarness extends StatelessWidget {
  const _CardHarness(this.controller);
  final EmailAuthController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SignInCard(
          compact: MediaQuery.sizeOf(context).width < 600,
          signIn: pageBlinkLocalized(
            context.l,
            PageBlinkEmailSignIn(controller: controller),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    app.client = Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager();
    await (FontLoader(pbSansFamily)
          ..addFont(rootBundle.load('assets/fonts/Pretendard-400-subset.otf')))
        .load();
  });

  /// Primary button must be scrollable into the part of the window that the
  /// keyboard leaves free, and nothing may have thrown (overflow included).
  Future<void> expectUsable(WidgetTester tester, Size size, double kb) async {
    expect(tester.takeException(), isNull);
    final button = find.byType(ElevatedButton).first;
    await tester.ensureVisible(button);
    await tester.pump();
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height - kb));
    expect(tester.takeException(), isNull);
  }

  void setView(WidgetTester tester, Size size, double kb) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..viewInsets = FakeViewPadding(bottom: kb);
    addTearDown(tester.view.reset);
  }

  group('SignInScreen (real screen, login step)', () {
    for (final lang in ['en', 'ko']) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          for (final kb in _keyboards) {
            testWidgets(
              '$lang ${size.width.toInt()}x${size.height.toInt()} x$scale kb${kb.toInt()}',
              (tester) async {
                setView(tester, size, kb);
                await tester.pumpWidget(
                  _app(
                    const SignInScreen(child: SizedBox()),
                    scale: scale,
                    lang: lang,
                  ),
                );
                await tester.pump(const Duration(milliseconds: 700));
                await expectUsable(tester, size, kb);
              },
            );
          }
        }
      }
    }
  });

  group('SignInCard x every email-flow step', () {
    for (final step in EmailFlowScreen.values) {
      for (final lang in ['en', 'ko']) {
        for (final size in _sizes) {
          for (final scale in _scales) {
            for (final kb in _keyboards) {
              testWidgets(
                '${step.name} $lang ${size.width.toInt()}x${size.height.toInt()} x$scale kb${kb.toInt()}',
                (tester) async {
                  setView(tester, size, kb);
                  final c = EmailAuthController(
                    client: app.client,
                    startScreen: EmailFlowScreen.login,
                    passwordRequirements: pageBlinkPasswordRequirements(
                      lang == 'ko' ? L.ko : L.en,
                    ),
                  )..navigateTo(step);
                  addTearDown(c.dispose);
                  await tester.pumpWidget(
                    _app(_CardHarness(c), scale: scale, lang: lang),
                  );
                  await tester.pump(const Duration(milliseconds: 700));
                  await expectUsable(tester, size, kb);
                },
              );
            }
          }
        }
      }
    }
  });
}
