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

/// The demo limit as the real client sees it: a typed 400 body from the
/// server, parsed by the generated protocol into [DemoLimitException].
final _l = L.en;
final _calls = <String>[];
DemoLimitException? _refuse;

Future<http.Response> _server(http.Request r) async {
  _calls.add(r.url.pathSegments.last);
  final e = _refuse;
  if (e == null) return http.Response('', 404);
  return http.Response(
    Protocol().encodeWithType(e),
    400,
    headers: {'content-type': 'text/json'},
  );
}

Document _doc() => Document(
  id: 7,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Sample',
  body: 'milk',
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester t, {
  Document? note,
  required OpenItemController controller,
}) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: NoteEditorView(
          note: note,
          embedded: true,
          onClose: () {},
          controller: controller,
        ),
      ),
    ),
  );
  await t.pump();
}

void main() {
  setUpAll(() {
    app.client = Client(
      'http://localhost:8080/',
      httpClientOverride: MockClient(_server),
    );
  });

  setUp(() {
    _calls.clear();
    _refuse = null;
  });

  testWidgets('save refused by the demo limit: message once, then the editor '
      'can be left', (t) async {
    _refuse = DemoLimitException(
      reason: DemoLimitReason.createLimit,
      limit: 5,
    );
    final controller = OpenItemController();
    await _pump(t, controller: controller);
    await t.enterText(find.byType(TextField).last, 'my new note');
    await t.pump();

    expect(await controller.flush(), isFalse);
    await t.pump();
    expect(_calls, ['saveNote']);
    expect(find.textContaining('up to 5 notes or PDFs'), findsOneWidget);
    expect(find.text(_l.demoSignUp), findsOneWidget);
    expect(find.textContaining('Save failed'), findsNothing);

    // Same text again: the save cannot succeed, so closing is allowed.
    expect(await controller.flush(), isTrue);
    expect(_calls, ['saveNote']);
  });

  testWidgets('delete of a sample: the lock message, not "could not delete"', (
    t,
  ) async {
    _refuse = DemoLimitException(reason: DemoLimitReason.sampleLocked);
    await _pump(t, note: _doc(), controller: OpenItemController());
    await t.tap(find.byIcon(AppIcons.more));
    await t.pumpAndSettle();
    await t.tap(
      find.ancestor(
        of: find.text(_l.delete),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, _l.delete));
    await t.pumpAndSettle();
    expect(_calls, ['delete']);
    expect(find.textContaining("Sample items can't be edited"), findsOneWidget);
    expect(find.text(_l.noteDeleteFailed), findsNothing);
    // A lock is not fixed by signing up.
    expect(find.text(_l.demoSignUp), findsNothing);
  });
}
