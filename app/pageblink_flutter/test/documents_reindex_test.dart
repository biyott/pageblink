import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

Document _doc(
  int id,
  String status, {
  String? lastError,
  String kind = 'pdf',
}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: kind,
  title: 'Doc $id',
  body: kind == 'note' ? 'body $id' : null,
  contentHash: 'h$id',
  version: 1,
  pageCount: 2,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.now().toUtc(),
);

/// A board whose server lives in memory; `reindex` waits on a gate per id.
class _Server {
  _Server(this.docs);
  List<Document> docs;
  final calls = <int>[];
  final gates = <int, Completer<void>>{};
  final Set<int> stillFailing = {};

  BoardApi get api => BoardApi(
    list: () async => List.of(docs),
    delete: (id) async {},
    reindex: (id) async {
      calls.add(id);
      await (gates[id] ??= Completer<void>()).future;
      final i = docs.indexWhere((d) => d.id == id);
      final failing = stillFailing.contains(id);
      docs[i] = docs[i].copyWith(
        status: failing ? 'failed' : 'ready',
        lastError: failing ? 'timeout' : null,
      );
      return docs[i];
    },
  );

  void open(int id) => (gates[id] ??= Completer<void>()).complete();
}

Future<void> _pump(WidgetTester t, _Server s) async {
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light),
      // The dot pulses forever; settle needs it still.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: DocumentsScreen(
        projects: const [],
        boardApi: s.api,
        pickPdfs: () async => const [],
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  late _Server server;
  setUp(() {
    server = _Server([
      _doc(1, 'failed', lastError: 'quota'),
      _doc(2, 'failed', lastError: 'timeout', kind: 'note'),
      _doc(3, 'failed', lastError: 'no_source'),
      _doc(4, 'indexing'),
      _doc(5, 'ready', kind: 'note'),
    ]);
  });

  testWidgets('no banner; one inline link counts only retryable failures', (
    t,
  ) async {
    await _pump(t, server);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('Re-index all'), findsNothing);
    // 3 failed in total (chip), 2 worth retrying (link).
    expect(find.text('3 needs attention'), findsOneWidget);
    expect(find.text('Retry 2 failed'), findsOneWidget);
    // Per-card links: ids 1 and 2 only (no_source has none).
    expect(find.widgetWithText(TextButton, 'Retry'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('the link does not move the grid (fixed row)', (t) async {
    await _pump(t, server);
    final withLink = t.getTopLeft(find.text('Doc 1')).dy;
    server.docs = [
      for (final d in server.docs) d.copyWith(status: 'ready', lastError: null),
    ];
    await t.drag(find.byType(GridView), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(find.textContaining('Retry '), findsNothing);
    expect(t.getTopLeft(find.text('Doc 1')).dy, withLink);
  });

  testWidgets('re-index locks only its own card', (t) async {
    await _pump(t, server);
    await t.tap(find.widgetWithText(TextButton, 'Retry').first);
    await t.pump();
    expect(server.calls, [1]);
    // Card 1 says so; other cards, the menu and upload stay live.
    expect(find.text('Re-indexing'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(
      t.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pump();
    expect(server.calls, [1, 2]);
    expect(find.text('Re-indexing'), findsNWidgets(2));

    server
      ..open(1)
      ..open(2);
    await t.pumpAndSettle();
    expect(find.text('Re-indexing'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    expect(find.text('Indexed: Doc 1'), findsOneWidget); // first snackbar
  });

  testWidgets('bulk retry runs the retryable ones in order and sums up', (
    t,
  ) async {
    server.stillFailing.add(2);
    await _pump(t, server);
    await t.tap(find.text('Retry 2 failed'));
    await t.pump();
    expect(find.text('Retrying…'), findsOneWidget);
    expect(find.text('Retry 2 failed'), findsNothing);
    // One after another; the no_source card is never touched.
    expect(server.calls, [1]);
    server.open(1);
    await t.pump();
    await t.pump();
    expect(server.calls, [1, 2]);
    server.open(2);
    await t.pumpAndSettle();
    expect(server.calls, [1, 2]);
    expect(find.text('1 indexed · 1 still failing'), findsOneWidget);
    expect(find.text('Retrying…'), findsNothing);
    // 2 is still failing and retryable -> the link stays, with the new count.
    expect(find.text('Retry 1 failed'), findsOneWidget);
  });

  testWidgets('all succeed: plain count snackbar, link gone', (t) async {
    await _pump(t, server);
    await t.tap(find.text('Retry 2 failed'));
    await t.pump();
    server
      ..open(1)
      ..open(2);
    await t.pumpAndSettle();
    expect(find.text('2 re-indexed'), findsOneWidget);
    expect(find.textContaining('Retry '), findsNothing);
  });

  testWidgets('a thrown error shows a fixed text, never the raw error', (
    t,
  ) async {
    final s = _Server([_doc(1, 'failed', lastError: 'quota')]);
    final api = BoardApi(
      list: () async => List.of(s.docs),
      delete: (id) async {},
      reindex: (id) async => throw StateError('embedding timeout 504 secret'),
    );
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: DocumentsScreen(projects: const [], boardApi: api),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Retry'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't re-index. Try again."), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });
}
