import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/locale_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/demo/demo.dart';
import 'package:pageblink_flutter/features/demo/demo_widgets.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';
import 'package:pageblink_flutter/screens/sign_in_screen.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _plain(String s) => s.replaceAll('⁠', '');

DemoLimitException _limit(DemoLimitReason r, [int? limit]) =>
    DemoLimitException(reason: r, limit: limit);

Widget _app(Widget home, {String lang = 'en'}) => MaterialApp(
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
  home: home,
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    app.client = Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager();
    await (FontLoader(pbSansFamily)
          ..addFont(rootBundle.load('assets/fonts/Pretendard-400-subset.otf')))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    localeController.value = null;
    demoStatusCall = null;
    demoSignInCall = null;
    demoSignUpRequested = false;
    resetDemoStatus();
  });

  tearDown(() {
    demoStatusCall = null;
    demoSignInCall = null;
  });

  group('demoLimitText', () {
    test('one sentence per reason, English and Korean', () {
      expect(
        demoLimitText(L.en, _limit(DemoLimitReason.createLimit, 5)),
        contains('up to 5 notes or PDFs'),
      );
      expect(
        _plain(demoLimitText(L.ko, _limit(DemoLimitReason.createLimit, 5))),
        contains('최대 5개'),
      );
      expect(
        demoLimitText(L.en, _limit(DemoLimitReason.askLimit, 50)),
        contains('limit of 50 questions'),
      );
      expect(
        _plain(demoLimitText(L.ko, _limit(DemoLimitReason.askLimit, 50))),
        contains('50회'),
      );
      expect(
        demoLimitText(L.en, _limit(DemoLimitReason.sampleLocked)),
        contains("Sample items can't be edited or deleted"),
      );
      expect(
        _plain(demoLimitText(L.ko, _limit(DemoLimitReason.sampleLocked))),
        contains('샘플 자료는 수정하거나 삭제할 수 없어요'),
      );
      expect(
        demoLimitText(L.en, _limit(DemoLimitReason.projectLocked)),
        contains("Projects can't be created or joined"),
      );
      expect(
        _plain(demoLimitText(L.ko, _limit(DemoLimitReason.projectLocked))),
        contains('프로젝트를 만들거나 초대할 수 없어요'),
      );
    });

    test('a missing limit never prints "null"', () {
      for (final r in DemoLimitReason.values) {
        expect(demoLimitText(L.en, _limit(r)), isNot(contains('null')));
        expect(demoLimitText(L.ko, _limit(r)), isNot(contains('null')));
      }
    });

    test('only count limits offer Sign up', () {
      expect(demoLimitOffersSignUp(_limit(DemoLimitReason.createLimit)), true);
      expect(demoLimitOffersSignUp(_limit(DemoLimitReason.askLimit)), true);
      expect(
        demoLimitOffersSignUp(_limit(DemoLimitReason.sampleLocked)),
        false,
      );
      expect(
        demoLimitOffersSignUp(_limit(DemoLimitReason.projectLocked)),
        false,
      );
    });
  });

  group('uploads', () {
    UploadApi api(Object error) => UploadApi(
      extractPages: (bytes, name) async => [PageText(page: 1, text: 'hi')],
      upload: (title, pages, hash, projectId) async => throw error,
      storeOriginal: (id, bytes) async => true,
    );

    test(
      'a DemoLimitException becomes a demoLimit outcome with its text',
      () async {
        final report = await uploadPdfs(
          [
            PickedPdf.bytes(
              'a.pdf',
              Uint8List.fromList(utf8.encode('%PDF-1.7\nx')),
            ),
          ],
          api: api(_limit(DemoLimitReason.createLimit, 5)),
        );
        final o = report.outcomes.single;
        expect(o.kind, UploadKind.demoLimit);
        expect(o.isFailure, isTrue);
        expect(uploadReasonText(L.en, o), contains('up to 5 notes or PDFs'));
      },
    );
  });

  group('fetchDemoStatus', () {
    test('a failing call is null, not an exception', () async {
      demoStatusCall = () async => throw Exception('old server');
      expect(await fetchDemoStatus(), isNull);
    });

    testWidgets('a call that never answers is null after the timeout', (
      tester,
    ) async {
      demoStatusCall = () => Completer<DemoStatus>().future;
      final result = fetchDemoStatus();
      await tester.pump(demoStatusTimeout + const Duration(seconds: 1));
      expect(await result, isNull);
    });
  });

  group('session status', () {
    test('refresh keeps the last value when a read fails', () async {
      demoStatusCall = () async =>
          DemoStatus(enabled: true, isDemo: true, createRemaining: 3);
      await refreshDemoStatus();
      expect(demoStatus.value?.createRemaining, 3);
      demoStatusCall = () async => throw Exception('offline');
      await refreshDemoStatus();
      expect(demoStatus.value?.createRemaining, 3);
    });

    test('a regular account is asked once', () async {
      var calls = 0;
      demoStatusCall = () async {
        calls++;
        return DemoStatus(enabled: true, isDemo: false);
      };
      await refreshDemoStatus();
      await refreshDemoStatus();
      await refreshDemoStatus();
      expect(calls, 1);
    });
  });

  group('SignInScreen demo button', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(800, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SignInScreen(child: SizedBox())));
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('shown when the server says enabled', (tester) async {
      demoStatusCall = () async => DemoStatus(enabled: true);
      await pumpScreen(tester);
      expect(find.text('Try the demo'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('Korean label', (tester) async {
      demoStatusCall = () async => DemoStatus(enabled: true);
      tester.view
        ..physicalSize = const Size(800, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const SignInScreen(child: SizedBox()), lang: 'ko'),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('데모 체험하기'), findsOneWidget);
    });

    testWidgets('hidden when the flag is off', (tester) async {
      demoStatusCall = () async => DemoStatus(enabled: false);
      await pumpScreen(tester);
      expect(find.text('Try the demo'), findsNothing);
    });

    testWidgets('hidden, and the screen still works, when status fails', (
      tester,
    ) async {
      demoStatusCall = () async => throw Exception('404 old server');
      await pumpScreen(tester);
      expect(find.text('Try the demo'), findsNothing);
      expect(find.text('Sign In with email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden while the status call is still pending', (
      tester,
    ) async {
      final pending = Completer<DemoStatus>();
      demoStatusCall = () => pending.future;
      await pumpScreen(tester);
      expect(find.text('Try the demo'), findsNothing);
      expect(find.text('Sign In with email'), findsOneWidget);
      // Let the timeout fire so no timer outlives the test.
      await tester.pump(demoStatusTimeout + const Duration(seconds: 1));
    });

    testWidgets('loading, failure text, then retry succeeds', (tester) async {
      demoStatusCall = () async => DemoStatus(enabled: true);
      var attempts = 0;
      final gate = Completer<void>();
      demoSignInCall = () async {
        attempts++;
        if (attempts == 1) {
          await gate.future;
          throw Exception('500');
        }
      };
      await pumpScreen(tester);

      await tester.tap(find.text('Try the demo'));
      await tester.pump();
      expect(find.text('Opening the demo…'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Try the demo'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              _plain(w.data ?? '').contains("Couldn't open the demo"),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Try the demo'));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              _plain(w.data ?? '').contains("Couldn't open the demo"),
        ),
        findsNothing,
      );
    });

    testWidgets('after Sign up the card opens on the registration form', (
      tester,
    ) async {
      demoStatusCall = () async => throw Exception('off');
      demoSignUpRequested = true;
      await pumpScreen(tester);
      expect(demoSignUpRequested, isFalse);
      expect(find.text('Sign Up with email'), findsOneWidget);
      expect(find.text('Sign In with email'), findsNothing);
    });
  });

  group('layout with the demo button (small windows, big text)', () {
    for (final lang in ['en', 'ko']) {
      for (final size in const [
        Size(360, 480),
        Size(390, 844),
        Size(800, 500),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          testWidgets(
            '$lang ${size.width.toInt()}x${size.height.toInt()} x$scale',
            (
              tester,
            ) async {
              demoStatusCall = () async => DemoStatus(enabled: true);
              tester.view
                ..physicalSize = size
                ..devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final base = buildPbTheme(Brightness.light);
              await tester.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(lang),
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
                    data: MediaQuery.of(
                      c,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: PbBackground(child: child!),
                  ),
                  home: const SignInScreen(child: SizedBox()),
                ),
              );
              await tester.pump(const Duration(milliseconds: 700));
              final button = find.byType(OutlinedButton);
              expect(button, findsOneWidget);
              await tester.ensureVisible(button);
              await tester.pump();
              expect(
                tester.getRect(button).bottom,
                lessThanOrEqualTo(size.height),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('DemoBanner', () {
    testWidgets('mode, items left, sign up and the notice', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: DemoBanner(
              status: DemoStatus(
                enabled: true,
                isDemo: true,
                createLimit: 5,
                createRemaining: 3,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Demo mode'), findsOneWidget);
      expect(find.textContaining('3 of 5 new items left'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);

      await tester.tap(find.byTooltip('About demo mode'));
      await tester.pumpAndSettle();
      expect(find.textContaining("don't enter personal"), findsOneWidget);
      expect(find.textContaining('24 hours'), findsOneWidget);
    });

    testWidgets('narrow phone with large text does not overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: _app(
            Scaffold(
              body: DemoBanner(
                status: DemoStatus(
                  enabled: true,
                  isDemo: true,
                  createLimit: 5,
                  createRemaining: 0,
                ),
              ),
            ),
            lang: 'ko',
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('demoBlocksCreate', () {
    late BuildContext ctx;
    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('not a demo session: never blocks, never asks', (
      tester,
    ) async {
      await pumpHost(tester);
      var calls = 0;
      demoStatusCall = () async {
        calls++;
        return DemoStatus(enabled: true);
      };
      expect(await demoBlocksCreate(ctx), isFalse);
      expect(calls, 0);
    });

    testWidgets('slots left: lets it through', (tester) async {
      await pumpHost(tester);
      demoStatus.value = DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 2,
      );
      expect(await demoBlocksCreate(ctx), isFalse);
    });

    testWidgets('full: asks again, then shows the limit with Sign up', (
      tester,
    ) async {
      await pumpHost(tester);
      demoStatus.value = DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 0,
      );
      demoStatusCall = () async => DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 0,
      );
      late bool blocked;
      unawaited(demoBlocksCreate(ctx).then((v) => blocked = v));
      await tester.pump();
      await tester.pump();
      expect(blocked, isTrue);
      expect(find.textContaining('up to 5 notes or PDFs'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
    });

    testWidgets('full on screen, but another visitor freed a slot', (
      tester,
    ) async {
      await pumpHost(tester);
      demoStatus.value = DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 0,
      );
      demoStatusCall = () async => DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 1,
      );
      expect(await demoBlocksCreate(ctx), isFalse);
      expect(demoStatus.value?.createRemaining, 1);
      expect(find.textContaining('up to 5'), findsNothing);
    });

    testWidgets('full and the server is unreachable: the server decides', (
      tester,
    ) async {
      await pumpHost(tester);
      demoStatus.value = DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 0,
      );
      demoStatusCall = () async => throw Exception('offline');
      expect(await demoBlocksCreate(ctx), isFalse);
    });
  });
}
