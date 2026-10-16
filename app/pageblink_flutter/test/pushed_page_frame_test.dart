import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/settings/admin_history_screen.dart';

const _red = Color(0xFFFF0000);
const _shell = ValueKey('shell');

/// A pushed page must be opaque: while it slides in, nothing of the screen
/// below shows through (the app's Scaffolds are transparent).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => askAdminListCall = null);

  Future<int> redPixelsRightOf(WidgetTester t, double left) async {
    final boundary =
        t.renderObject(find.byKey(_shell)) as RenderRepaintBoundary;
    final image = (await t.runAsync(boundary.toImage))!;
    final data = (await t.runAsync(image.toByteData))!;
    var n = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = left.ceil(); x < image.width; x++) {
        final i = (y * image.width + x) * 4;
        if (data.getUint8(i) > 200 &&
            data.getUint8(i + 1) < 60 &&
            data.getUint8(i + 2) < 60) {
          n++;
        }
      }
    }
    return n;
  }

  Future<void> check(
    WidgetTester t, {
    required double width,
    required Brightness brightness,
    required bool framed,
  }) async {
    t.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    askAdminListCall = (_) async => AskAdminPage(items: [], models: []);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(brightness).copyWith(platform: TargetPlatform.iOS),
        locale: const Locale('en'),
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // The shell paints the gradient behind the navigator.
        builder: (context, child) => RepaintBoundary(
          key: _shell,
          child: PbBackground(child: child!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('UNDERLAY'),
                  Container(width: 60, height: 200, color: _red),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => framed
                            ? const AdminHistoryPage()
                            // The old page: a bare, transparent Scaffold.
                            : const Scaffold(body: Text('bare')),
                      ),
                    ),
                    child: const Text('go'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(await redPixelsRightOf(t, 0), greaterThan(0));
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    // Mid-slide: the page covers the right part of the screen.
    final page = framed ? find.byType(PbPage) : find.text('bare');
    final left = t.getTopLeft(framed ? page : find.byType(Scaffold).last).dx;
    expect(left, greaterThan(0));
    expect(left, lessThan(width - 100));
    final bleed = await redPixelsRightOf(t, left + 1);
    if (framed) {
      expect(bleed, 0, reason: 'underlay shows through the sliding page');
    } else {
      expect(bleed, greaterThan(0), reason: 'control: a bare Scaffold leaks');
    }
    await t.pumpAndSettle();
  }

  for (final b in Brightness.values) {
    for (final w in [360.0, 800.0, 1440.0]) {
      testWidgets('AdminHistoryPage is opaque while sliding: $w ${b.name}', (
        t,
      ) async {
        await check(t, width: w, brightness: b, framed: true);
      });
    }
  }

  testWidgets('control: a bare transparent Scaffold route leaks', (t) async {
    await check(t, width: 800, brightness: Brightness.light, framed: false);
  });
}
