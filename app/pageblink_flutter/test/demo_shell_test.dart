import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/demo/demo.dart';
import 'package:pageblink_flutter/features/demo/demo_widgets.dart';
import 'package:pageblink_flutter/main.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

/// The real shell with an unreachable server: every call fails quietly, the
/// banner comes from `demo.status()` only.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    app.client = Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager();
  });

  tearDown(() => demoStatusCall = null);

  Future<void> pump(WidgetTester t, Size size) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        locale: const Locale('en'),
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

  for (final size in const [Size(390, 844), Size(800, 700), Size(1440, 900)]) {
    testWidgets('banner above the layout at ${size.width.toInt()} px', (
      t,
    ) async {
      demoStatusCall = () async => DemoStatus(
        enabled: true,
        isDemo: true,
        createLimit: 5,
        createRemaining: 4,
      );
      await pump(t, size);
      expect(find.byType(DemoBanner), findsOneWidget);
      expect(find.textContaining('4 of 5 new items left'), findsOneWidget);
      // The shell is still there, under the banner.
      expect(find.text('Notes'), findsWidgets);
      expect(
        t.getRect(find.byType(DemoBanner)).top,
        0,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no banner for a regular account', (t) async {
    demoStatusCall = () async => DemoStatus(enabled: true, isDemo: false);
    await pump(t, const Size(390, 844));
    expect(find.byType(DemoBanner), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('no banner when status fails (old server)', (t) async {
    demoStatusCall = () async => throw Exception('404');
    await pump(t, const Size(1440, 900));
    expect(find.byType(DemoBanner), findsNothing);
    expect(t.takeException(), isNull);
  });
}
