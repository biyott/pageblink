import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/drop_zone.dart';
import 'package:pageblink_flutter/features/documents/upload_controller.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';
import 'package:pageblink_flutter/features/documents/upload_tray.dart';

Document _doc(int id) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  title: 't$id',
  contentHash: 'h$id',
  version: 1,
  pageCount: 3,
  status: 'ready',
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Sends what the `desktop_drop` web plugin / native side would.
Future<void> _native(String method, [Object? args]) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, args),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage('desktop_drop', data, (_) {});
}

Future<void> _enter(WidgetTester t, double x, double y) async {
  await _native('entered', [x, y]);
  await t.pump();
}

Future<void> _move(WidgetTester t, double x, double y) async {
  await _native('updated', [x, y]);
  await t.pump();
}

Future<void> _exit(WidgetTester t) async {
  await _native('exited', [0.0, 0.0]);
  await t.pump();
}

Map<String, Object?> _item(String name, {String? type, bool dir = false}) => {
  // dart:io XFile derives `name` from the path.
  'uri': name,
  'children': <Object>[],
  'data': dir ? null : utf8.encode('%PDF-1.7 $name'),
  'name': name,
  'type': dir ? 'directory' : (type ?? 'application/pdf'),
  'size': 12,
  'relativePath': name,
  'lastModified': 0,
};

Future<void> _drop(WidgetTester t, List<Map<String, Object?>> items) async {
  // The package only reports a drop that followed an enter.
  await _native('updated', [450.0, 350.0]);
  await _native('performOperation_web', items);
  await t.pump();
  await t.pump();
}

class _Harness {
  _Harness({this.projects = const [], this.touch = false});
  final List<Project> projects;
  final bool touch;
  final uploaded = <String>[];
  final projectIds = <int?>[];
  int _n = 0;
  late final UploadController controller;
  final paneKey = GlobalKey();
  final editorText = TextEditingController(text: 'my draft note');

  UploadApi get api => UploadApi(
    extractPages: (b, n) async => [PageText(page: 1, text: n)],
    upload: (title, pages, hash, projectId) async {
      uploaded.add(title);
      projectIds.add(projectId);
      return _doc(++_n);
    },
    storeOriginal: (id, bytes) async => true,
  );

  Future<void> pump(WidgetTester t, {bool editorOpen = false}) async {
    t.view.physicalSize = const Size(900, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    controller = UploadController(api: api);
    addTearDown(controller.dispose);
    final projectsNotifier = ValueNotifier<List<Project>>(projects);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: Scaffold(
          body: UploadDropHost(
            controller: controller,
            projects: projectsNotifier,
            paneKey: paneKey,
            touch: touch,
            child: Padding(
              padding: const EdgeInsets.all(100),
              child: Stack(
                key: paneKey,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: TextField(controller: editorText, maxLines: null),
                  ),
                  DropZone(projects: projectsNotifier, editorOpen: editorOpen),
                  const Positioned(right: 16, bottom: 16, child: UploadTray()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  const title = 'Drop PDFs here to add';

  testWidgets('idle: nothing is drawn and the pane keeps its size', (t) async {
    final h = _Harness();
    await h.pump(t);
    // The zone must not shrink the Stack it sits in (all siblings are
    // Positioned): 900x700 minus the 100 px padding.
    expect(t.getSize(find.byKey(h.paneKey)), const Size(700, 500));
    expect(find.text(title), findsNothing);
    expect(h.controller.drop.phase.value, DropPhase.idle);
  });

  testWidgets('armed outside the pane, over inside it; copy and target', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final h = _Harness();
    await h.pump(t);
    await _enter(t, 20, 20); // window, outside pane + 12
    expect(h.controller.drop.phase.value, DropPhase.armed);
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text(title), findsOneWidget);
    expect(
      find.text('Drop several at once · Goes to My documents'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Drop area.*added to My documents')),
      findsOneWidget,
    );
    await _move(t, 450, 350);
    expect(h.controller.drop.phase.value, DropPhase.over);
    await _move(t, 20, 20);
    expect(h.controller.drop.phase.value, DropPhase.armed);
    await _exit(t);
    await t.pump(const Duration(milliseconds: 200));
    semantics.dispose();
  });

  testWidgets('exit: 150 ms grace; a dragover in between keeps the zone', (
    t,
  ) async {
    final h = _Harness();
    await h.pump(t);
    await _enter(t, 450, 350);
    await _exit(t); // Chrome's fake exit over the TextField
    await t.pump(const Duration(milliseconds: 100));
    expect(h.controller.drop.phase.value, DropPhase.over);
    await _move(t, 452, 350);
    await t.pump(const Duration(milliseconds: 100));
    expect(h.controller.drop.phase.value, DropPhase.over);

    await _exit(t);
    await t.pump(const Duration(milliseconds: 140));
    expect(h.controller.drop.phase.value, DropPhase.over);
    await t.pump(const Duration(milliseconds: 20));
    expect(h.controller.drop.phase.value, DropPhase.idle);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text(title), findsNothing);
  });

  testWidgets('400 ms without any signal ends a silent drag', (t) async {
    final h = _Harness();
    await h.pump(t);
    await _enter(t, 450, 350);
    await t.pump(const Duration(milliseconds: 390));
    expect(h.controller.drop.phase.value, DropPhase.over);
    await t.pump(const Duration(milliseconds: 20));
    expect(h.controller.drop.phase.value, DropPhase.idle);
  });

  testWidgets('drop of PDFs with no projects uploads straight to personal', (
    t,
  ) async {
    final h = _Harness();
    await h.pump(t);
    await _enter(t, 450, 350);
    await _drop(t, [_item('a.pdf'), _item('B.PDF')]);
    await t.pumpAndSettle();
    expect(find.text('Where should it go?'), findsNothing);
    expect(h.uploaded, ['a', 'B']);
    expect(h.projectIds, [null, null]);
    expect(h.controller.drop.phase.value, DropPhase.idle);
    // One summary snackbar.
    expect(find.text('2 added'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('with projects: the target sheet shows once per drop', (t) async {
    final h = _Harness(
      projects: [
        Project(
          id: 7,
          name: 'Vision',
          ownerId: UuidValue.fromString(
            '00000000-0000-4000-8000-000000000001',
          ),
          createdAt: DateTime.utc(2026),
        ),
      ],
    );
    await h.pump(t);
    await _enter(t, 450, 350);
    await t.pump(const Duration(milliseconds: 250));
    expect(
      find.text('Drop several at once · You choose where after dropping'),
      findsOneWidget,
    );
    await _drop(t, [_item('a.pdf'), _item('b.pdf'), _item('c.pdf')]);
    await t.pumpAndSettle();
    expect(find.text('Where should it go?'), findsOneWidget);
    expect(h.uploaded, isEmpty);
    await t.tap(find.text('Shared Vision · Vision'));
    await t.pumpAndSettle();
    expect(h.uploaded, ['a', 'b', 'c']);
    expect(h.projectIds, [7, 7, 7]);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('cancelling the sheet cancels the whole drop', (t) async {
    final h = _Harness(
      projects: [
        Project(
          id: 7,
          name: 'Vision',
          ownerId: UuidValue.fromString(
            '00000000-0000-4000-8000-000000000001',
          ),
          createdAt: DateTime.utc(2026),
        ),
      ],
    );
    await h.pump(t);
    await _drop(t, [_item('a.pdf')]);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10)); // barrier
    await t.pumpAndSettle();
    expect(h.uploaded, isEmpty);
    expect(h.controller.rows, isEmpty);
  });

  testWidgets('non-PDF and folders: tray rows say so, PDFs still go', (
    t,
  ) async {
    final h = _Harness();
    await h.pump(t);
    await _drop(t, [
      _item('notes.docx', type: 'application/msword'),
      _item('photos', dir: true),
      _item('real.pdf'),
    ]);
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Only PDFs are supported (.docx)'), findsOneWidget);
    expect(find.text('Only PDFs are supported'), findsOneWidget);
    expect(h.uploaded, ['real']);
    await t.pumpAndSettle();
    // Header counts what needs attention.
    expect(find.text('1 added · 2 need attention'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('only non-PDFs: no sheet, no upload', (t) async {
    final h = _Harness(
      projects: [
        Project(
          id: 7,
          name: 'Vision',
          ownerId: UuidValue.fromString(
            '00000000-0000-4000-8000-000000000001',
          ),
          createdAt: DateTime.utc(2026),
        ),
      ],
    );
    await h.pump(t);
    await _drop(t, [_item('a.txt', type: 'text/plain')]);
    await t.pumpAndSettle();
    expect(find.text('Where should it go?'), findsNothing);
    expect(find.text('Only PDFs are supported (.txt)'), findsOneWidget);
  });

  testWidgets('12 PDFs: ten are uploaded, the rest is said to be skipped', (
    t,
  ) async {
    final h = _Harness();
    await h.pump(t);
    await _drop(t, [for (var i = 0; i < 12; i++) _item('f$i.pdf')]);
    await t.pumpAndSettle();
    expect(h.uploaded, hasLength(UploadLimits.maxFiles));
    expect(
      find.textContaining('Up to 10 files at a time; 2 skipped.'),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('open editor: zone says "new documents"; the note is untouched', (
    t,
  ) async {
    final h = _Harness();
    await h.pump(t, editorOpen: true);
    await t.tap(find.byType(TextField));
    await t.pump();
    await _enter(t, 450, 350);
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text('Drop PDFs to add as new documents'), findsOneWidget);
    expect(
      find.text('Your open note stays as it is · Goes to My documents'),
      findsOneWidget,
    );
    await _drop(t, [_item('a.pdf')]);
    await t.pumpAndSettle();
    expect(h.uploaded, ['a']);
    expect(h.editorText.text, 'my draft note');
    expect(find.byType(TextField), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('touch device: no drop target, no overlay', (t) async {
    final h = _Harness(touch: true);
    await h.pump(t);
    expect(find.byType(DropZone), findsOneWidget); // present but inert
    await _enter(t, 450, 350);
    await t.pump(const Duration(milliseconds: 300));
    expect(h.controller.drop.phase.value, DropPhase.idle);
    expect(find.text(title), findsNothing);
    expect(h.controller.dropEnabled, isFalse);
    await _drop(t, [_item('a.pdf')]);
    await t.pumpAndSettle();
    expect(h.uploaded, isEmpty);
  });

  testWidgets('side panels get a scrim only while dragging', (t) async {
    final controller = UploadController(api: _Harness().api);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: UploadDropHost(
          controller: controller,
          projects: ValueNotifier(const []),
          touch: false,
          child: const Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: DropScrim(child: ColoredBox(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
    double opacity() => t
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(DropScrim),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 0);
    await _enter(t, 100, 100);
    expect(opacity(), 1);
    await _exit(t);
    await t.pump(const Duration(milliseconds: 200));
    expect(opacity(), 0);
  });

  group('motion', () {
    Widget wrapMotion(bool reduce, Widget child) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: child,
    );

    for (final reduce in [false, true]) {
      testWidgets(
        'icon bounce runs over the pane only without reduced motion '
        '(reduced=$reduce)',
        (t) async {
          final controller = UploadController(api: _Harness().api);
          addTearDown(controller.dispose);
          final projects = ValueNotifier<List<Project>>(const []);
          final key = GlobalKey();
          await t.pumpWidget(
            wrapMotion(
              reduce,
              MaterialApp(
                theme: buildPbTheme(Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduce,
                  ),
                  child: child!,
                ),
                home: UploadDropHost(
                  controller: controller,
                  projects: projects,
                  paneKey: key,
                  touch: false,
                  child: Stack(
                    key: key,
                    clipBehavior: Clip.none,
                    children: [DropZone(projects: projects, grow: 0)],
                  ),
                ),
              ),
            ),
          );
          await _enter(t, 400, 300);
          await t.pump(const Duration(milliseconds: 300));
          // Keep the drag alive past the 400 ms safety timer.
          await _move(t, 401, 300);
          await t.pump(const Duration(milliseconds: 300));
          if (reduce) {
            expect(t.binding.transientCallbackCount, 0);
          } else {
            expect(t.binding.transientCallbackCount, greaterThan(0));
          }
          await _exit(t);
          await t.pump(const Duration(milliseconds: 400));
        },
      );
    }
  });
}
