import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/open_item_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

/// Header "..." menu of the note editor: re-index and delete. The server is a
/// fake HTTP client behind the real generated `Client`.
final _l = L.en;

/// `(endpoint method, JSON args)` of every request, in order.
final _calls = <(String, Map<String, dynamic>)>[];

/// What the fake server answers; tests set these.
Document? _reindexResult;
Document Function(Map<String, dynamic> args)? _saveResult;
bool _failReindex = false;

/// Holds the reindex answer while set (to look at the in-flight state).
Completer<void>? _gate;

Document _doc({
  int id = 7,
  String title = 'Groceries',
  String body = 'milk',
  String status = 'ready',
  String? lastError,
}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: title,
  body: body,
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

http.Response _json(Object? v) =>
    http.Response(jsonEncode(v), 200, headers: {'content-type': 'text/json'});

Future<http.Response> _server(http.Request r) async {
  final method = r.url.pathSegments.last;
  final args = r.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(r.body) as Map<String, dynamic>;
  _calls.add((method, args));
  switch (method) {
    case 'reindex':
      await _gate?.future;
      if (_failReindex) {
        return http.Response('internal secret detail: stack at x.dart', 500);
      }
      return _json(_reindexResult!.toJson());
    case 'saveNote':
      return _json(_saveResult!(args).toJson());
    case 'delete':
      return http.Response('null', 200);
  }
  return http.Response('', 404);
}

List<String> get _methods => [for (final c in _calls) c.$1];

Future<void> _pump(
  WidgetTester t, {
  Document? note,
  OpenItemController? controller,
  VoidCallback? onClose,
}) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox()); // fresh editor state
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: NoteEditorView(
          note: note,
          embedded: true,
          onClose: onClose ?? () {},
          controller: controller,
        ),
      ),
    ),
  );
  await t.pump();
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.byIcon(AppIcons.more));
  await t.pumpAndSettle();
}

Future<void> _choose(WidgetTester t, String label) async {
  await _open(t);
  await t.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    ),
  );
  await t.pumpAndSettle();
}

final _warn = find.byKey(const ValueKey('index-failed'));
final _running = find.byKey(const ValueKey('index-running'));

void main() {
  setUpAll(() {
    app.client = Client(
      'http://localhost:8080/',
      httpClientOverride: MockClient(_server),
    );
  });

  setUp(() {
    _calls.clear();
    _reindexResult = null;
    _saveResult = null;
    _failReindex = false;
    _gate = null;
  });

  group('menu', () {
    testWidgets('a new note has no menu and no delete button', (t) async {
      await _pump(t);
      expect(find.byIcon(AppIcons.more), findsNothing);
      expect(find.byIcon(AppIcons.delete), findsNothing);
    });

    testWidgets('a stored note: Re-index and Delete', (t) async {
      await _pump(t, note: _doc());
      expect(find.byIcon(AppIcons.delete), findsNothing); // moved into the menu
      await _open(t);
      expect(find.text(_l.reindex), findsOneWidget);
      expect(find.text(_l.delete), findsOneWidget);
      expect(_calls, isEmpty);
    });

    testWidgets('index state next to the title: failed icon, running text', (
      t,
    ) async {
      await _pump(
        t,
        note: _doc(status: 'failed', lastError: 'quota'),
      );
      expect(_warn, findsOneWidget);
      expect(_running, findsNothing);
      // the tooltip carries the mapped reason
      await t.longPress(_warn);
      await t.pumpAndSettle();
      expect(find.text(_l.indexingError('quota')), findsOneWidget);

      await _pump(t, note: _doc(status: 'indexing'));
      expect(_warn, findsNothing);
      expect(find.text('${_l.indexing}…'), findsOneWidget);

      await _pump(t, note: _doc());
      expect(_warn, findsNothing);
      expect(_running, findsNothing);
    });

    testWidgets('a long title still fits next to the status icon', (t) async {
      await _pump(
        t,
        note: _doc(title: 'very long ' * 20, status: 'failed', lastError: 'x'),
      );
      expect(t.takeException(), isNull);
      expect(_warn, findsOneWidget);
    });
  });

  group('re-index', () {
    testWidgets('unchanged note: one reindex call, status updated', (t) async {
      _reindexResult = _doc(title: 'Groceries');
      await _pump(
        t,
        note: _doc(status: 'failed', lastError: 'timeout'),
      );
      expect(_warn, findsOneWidget);
      await _choose(t, _l.reindex);
      expect(_methods, ['reindex']);
      expect(_calls.single.$2, {'documentId': 7});
      expect(find.text(_l.indexed('Groceries')), findsOneWidget);
      expect(_warn, findsNothing); // failed -> ready
    });

    testWidgets('shows the spinner while it runs, then the save check', (
      t,
    ) async {
      _reindexResult = _doc();
      await _pump(t, note: _doc());
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      _gate = Completer<void>();
      await _open(t);
      await t.tap(
        find.ancestor(
          of: find.text(_l.reindex),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      await t.pump(const Duration(milliseconds: 400)); // menu closes
      // request held by the fake server
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(AppIcons.check), findsNothing);
      // nothing else can be started meanwhile
      final more = find.ancestor(
        of: find.byIcon(AppIcons.more),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      );
      expect(more, findsOneWidget);
      expect(t.widget<PopupMenuButton>(more).enabled, isFalse);
      _gate!.complete();
      await t.pump();
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(_methods, ['reindex']);
    });

    testWidgets('server says failed: fixed text, icon appears, no raw reason', (
      t,
    ) async {
      _reindexResult = _doc(status: 'failed', lastError: 'raw provider text');
      await _pump(t, note: _doc());
      await _choose(t, _l.reindex);
      expect(find.text(_l.reindexFailed), findsOneWidget);
      expect(find.textContaining('raw provider text'), findsNothing);
      expect(_warn, findsOneWidget);
    });

    testWidgets('request error: fixed text only, state unchanged', (t) async {
      _failReindex = true;
      await _pump(t, note: _doc());
      await _choose(t, _l.reindex);
      expect(_methods, ['reindex']);
      expect(find.text(_l.reindexFailed), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect(find.textContaining('x.dart'), findsNothing);
      expect(_warn, findsNothing);
      // the menu is usable again
      expect(find.byIcon(AppIcons.more), findsOneWidget);
    });

    testWidgets('unsaved edits: saved first, that save is the only call', (
      t,
    ) async {
      _saveResult = (a) => _doc(body: a['body'] as String);
      await _pump(t, note: _doc());
      await t.enterText(find.byType(TextField).last, 'milk and eggs');
      await t.pump();
      await _choose(t, _l.reindex);
      expect(_methods, ['saveNote']); // no second reindex call
      expect(_calls.single.$2['body'], 'milk and eggs');
      expect(_calls.single.$2['documentId'], 7);
      expect(find.text(_l.indexed('Groceries')), findsOneWidget);
      // saved: a second re-index without edits goes to the endpoint
      _reindexResult = _doc(body: 'milk and eggs');
      await _choose(t, _l.reindex);
      expect(_methods, ['saveNote', 'reindex']);
    });

    testWidgets('unsaved edits and the save fails: fixed text, no raw error', (
      t,
    ) async {
      _saveResult = (_) => throw StateError('boom');
      await _pump(t, note: _doc());
      await t.enterText(find.byType(TextField).last, 'changed');
      await t.pump();
      await _choose(t, _l.reindex);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text(_l.reindexFailed), findsOneWidget);
      expect(_methods, ['saveNote']);
    });
  });

  group('delete', () {
    testWidgets('confirm, delete, close without saving again', (t) async {
      final controller = OpenItemController();
      var closed = 0;
      await _pump(
        t,
        note: _doc(),
        controller: controller,
        onClose: () => closed++,
      );
      await t.enterText(find.byType(TextField).last, 'edited, then deleted');
      await t.pump();
      await _choose(t, _l.delete);
      // the existing confirmation dialog
      expect(find.text(_l.deleteNoteTitle), findsOneWidget);
      expect(find.text(_l.cannotUndo), findsOneWidget);
      expect(_calls, isEmpty);
      await t.tap(find.widgetWithText(FilledButton, _l.delete));
      await t.pumpAndSettle();
      expect(_methods, ['delete']);
      expect(_calls.single.$2, {'documentId': 7});
      expect(closed, 1);
      // closing the (dirty) editor afterwards must not call saveNote
      expect(await controller.flush(), isTrue);
      expect(_methods, ['delete']);
    });

    testWidgets('cancel keeps the note', (t) async {
      var closed = 0;
      await _pump(t, note: _doc(), onClose: () => closed++);
      await _choose(t, _l.delete);
      await t.tap(find.text(_l.cancel));
      await t.pumpAndSettle();
      expect(_calls, isEmpty);
      expect(closed, 0);
    });
  });
}
