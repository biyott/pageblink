import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/upload_controller.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';
import 'package:pageblink_flutter/features/documents/upload_tray.dart';

Document _doc(int id, {String status = 'ready', String? lastError}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  title: 't$id',
  contentHash: 'h$id',
  version: 1,
  pageCount: 5,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PickedPdf _pdf(String name) => PickedPdf.bytes(
  name,
  Uint8List.fromList(utf8.encode('%PDF-1.7 $name')),
);

void main() {
  late Map<String, Completer<Document>> gates;
  late UploadController controller;
  int ids = 0;

  Future<void> pumpTray(
    WidgetTester t, {
    Future<Document> Function(int)? reindex,
    bool reduceMotion = true,
  }) async {
    gates = {};
    ids = 0;
    controller = UploadController(
      api: UploadApi(
        extractPages: (b, n) async => [PageText(page: 1, text: n)],
        upload: (title, pages, hash, projectId) =>
            (gates[title] ??= Completer<Document>()).future,
        storeOriginal: (id, bytes) async => true,
      ),
      reindex: reindex,
    );
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: UploadScope(
          controller: controller,
          child: const Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: UploadTray(),
            ),
          ),
        ),
      ),
    );
  }

  void finish(String title, {String status = 'ready', String? error}) =>
      gates[title]!.complete(_doc(++ids, status: status, lastError: error));

  testWidgets('hidden until there is something to show', (t) async {
    await pumpTray(t);
    expect(find.byType(Material), findsWidgets);
    expect(find.text('Waiting'), findsNothing);
    expect(find.byIcon(AppIcons.close), findsNothing);
  });

  testWidgets('progress per file: stage text, count, cancel on queued only', (
    t,
  ) async {
    await pumpTray(t);
    controller.enqueue([_pdf('a.pdf'), _pdf('b.pdf'), _pdf('c.pdf')]);
    await t.pump();
    await t.pump();
    expect(find.text('Adding 3 PDFs · 1/3'), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('Indexing · 1 page'), findsOneWidget);
    expect(find.text('Waiting'), findsNWidgets(2));
    // x = cancel on the two queued rows + the header's x (dismiss) + chevron.
    expect(find.byTooltip('Cancel'), findsNWidgets(2));

    await t.tap(find.byTooltip('Cancel').last);
    await t.pump();
    expect(find.text('c.pdf'), findsNothing);
    expect(find.text('Adding 2 PDFs · 1/2'), findsOneWidget);

    finish('a');
    await t.pump();
    await t.pump();
    expect(find.text('Added · 5 pages'), findsOneWidget);
    expect(find.text('Adding 2 PDFs · 2/2'), findsOneWidget);
    finish('b');
    await t.pump();
    await t.pump();
    expect(find.text('Added 2 PDFs'), findsOneWidget);
    expect(find.byIcon(AppIcons.done), findsNWidgets(2));
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('done rows auto-close after 5 s; the tray disappears', (t) async {
    await pumpTray(t);
    controller.enqueue([_pdf('a.pdf')]);
    await t.pump();
    await t.pump();
    finish('a');
    await t.pump();
    await t.pump();
    expect(find.text('Added 1 PDF'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Added 1 PDF'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Added 1 PDF'), findsNothing);
    expect(find.text('a.pdf'), findsNothing);
  });

  testWidgets('failed row: reason, Retry works, dismiss closes', (t) async {
    await pumpTray(t);
    controller.enqueue([_pdf('a.pdf'), _pdf('b.pdf')]);
    await t.pump();
    await t.pump();
    gates['a']!.completeError(TimeoutException('x'));
    await t.pump();
    await t.pump();
    finish('b');
    await t.pump();
    await t.pump();
    expect(find.text('1 added · 1 need attention'), findsOneWidget);
    expect(find.textContaining('may still be processing'), findsOneWidget);
    // Failures are kept; the successful row left on its own.
    await t.pump(const Duration(seconds: 6));
    expect(find.text('b.pdf'), findsNothing);
    expect(find.text('a.pdf'), findsOneWidget);

    gates.remove('a');
    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pump();
    await t.pump();
    expect(find.text('Indexing · 1 page'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    finish('a');
    await t.pump();
    await t.pump();
    expect(find.text('Added 1 PDF'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('index failure (card created): Retry re-indexes that card', (
    t,
  ) async {
    final reindexed = <int>[];
    await pumpTray(
      t,
      reindex: (id) async {
        reindexed.add(id);
        return _doc(id);
      },
    );
    controller.enqueue([_pdf('a.pdf')]);
    await t.pump();
    await t.pump();
    finish('a', status: 'failed', error: 'quota');
    await t.pump();
    await t.pump();
    expect(
      find.textContaining('usage quota has been reached'),
      findsOneWidget,
    );
    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pump();
    await t.pump();
    expect(reindexed, [1]);
    expect(find.text('Added 1 PDF'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('closing hides a running tray; collapse keeps only the header', (
    t,
  ) async {
    await pumpTray(t);
    controller.enqueue([_pdf('a.pdf')]);
    await t.pump();
    await t.pump();
    await t.tap(find.byTooltip('Collapse'));
    await t.pump();
    expect(find.text('a.pdf'), findsNothing);
    expect(find.text('Adding 1 PDF · 1/1'), findsOneWidget);
    await t.tap(find.byTooltip('Expand'));
    await t.pump();
    expect(find.text('a.pdf'), findsOneWidget);
    await t.tap(find.byTooltip('Dismiss'));
    await t.pump();
    expect(find.text('a.pdf'), findsNothing);
    // The upload went on.
    finish('a');
    await t.pump();
    await t.pump();
    expect(controller.rows.single.state, RowState.done);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('rows fit a phone-width tray without overflow', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpTray(t);
    controller.enqueue(
      [_pdf('a-very-long-file-name-that-keeps-going-and-going.pdf')],
      rejected: const [RejectedFile('another-very-long-name-document.docx')],
    );
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    finish('a-very-long-file-name-that-keeps-going-and-going');
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('failed row shows a selectable diagnostic line', (t) async {
    controller = UploadController(
      api: UploadApi(
        extractPages: (b, n) async =>
            throw StateError('Failed to open document: FORMAT (3)'),
        upload: (title, pages, hash, projectId) => Completer<Document>().future,
        storeOriginal: (id, bytes) async => true,
      ),
    );
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: UploadScope(
          controller: controller,
          child: const Scaffold(
            body: Align(alignment: Alignment.bottomRight, child: UploadTray()),
          ),
        ),
      ),
    );
    controller.enqueue([_pdf('a.pdf')]);
    await t.pump();
    await t.pump();
    expect(find.text("This PDF is damaged and can't be read"), findsOneWidget);
    expect(
      find.text('Diagnostic: StateError: Failed to open document: FORMAT (3)'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
