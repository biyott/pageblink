import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/demo/demo.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

Document _doc(int id, String status) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Doc $id',
  body: 'body $id',
  contentHash: 'h$id',
  version: 1,
  pageCount: 1,
  status: status,
  lastError: status == 'failed' ? 'timeout' : null,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.now().toUtc(),
);

int _pdfPicks = 0;

Future<void> _pump(WidgetTester t, BoardApi api) async {
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _pdfPicks = 0;
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: DocumentsScreen(
          projects: const [],
          boardApi: api,
          pickPdfs: () async {
            _pdfPicks++;
            return const [];
          },
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

DemoStatus _full() => DemoStatus(
  enabled: true,
  isDemo: true,
  createLimit: 5,
  createRemaining: 0,
);

void main() {
  setUp(() {
    demoStatusCall = null;
    resetDemoStatus();
  });

  testWidgets('full demo: New note and Upload PDF show the limit, '
      'and do not start', (t) async {
    demoStatus.value = _full();
    demoStatusCall = () async => _full();
    await _pump(
      t,
      BoardApi(
        list: () async => [_doc(1, 'ready')],
        reindex: (id) async => _doc(id, 'ready'),
        delete: (id) async {},
      ),
    );

    await t.tap(find.text('Upload PDF'));
    await t.pumpAndSettle();
    expect(_pdfPicks, 0);
    expect(find.textContaining('up to 5 notes or PDFs'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);

    ScaffoldMessenger.of(t.element(find.text('New note'))).clearSnackBars();
    await t.pumpAndSettle();
    await t.tap(find.text('New note'));
    await t.pumpAndSettle();
    expect(find.textContaining('up to 5 notes or PDFs'), findsOneWidget);
  });

  testWidgets('a regular account is never gated', (t) async {
    await _pump(
      t,
      BoardApi(
        list: () async => [_doc(1, 'ready')],
        reindex: (id) async => _doc(id, 'ready'),
        delete: (id) async {},
      ),
    );
    await t.tap(find.text('Upload PDF'));
    await t.pumpAndSettle();
    expect(_pdfPicks, 1);
  });

  testWidgets('a locked sample on re-index says so, not "could not re-index"', (
    t,
  ) async {
    await _pump(
      t,
      BoardApi(
        list: () async => [_doc(1, 'failed')],
        reindex: (id) async =>
            throw DemoLimitException(reason: DemoLimitReason.sampleLocked),
        delete: (id) async {},
      ),
    );
    await t.tap(find.widgetWithText(TextButton, 'Retry').first);
    await t.pumpAndSettle();
    expect(find.textContaining("Sample items can't be edited"), findsOneWidget);
    expect(find.text("Couldn't re-index. Try again."), findsNothing);
  });
}
