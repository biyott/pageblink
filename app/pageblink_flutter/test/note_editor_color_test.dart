import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/open_item_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/client.dart' as app;
import 'package:pageblink_flutter/features/documents/note_color_picker.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

/// Note color button in the editor header (docs/design/note-color/spec.md).
/// The server is a fake HTTP client behind the real generated `Client`.
final _l = L.en;
final _pb = Pb.light;

final _calls = <(String, Map<String, dynamic>)>[];
bool _failColor = false;

/// Holds the answers while set (to look at the in-flight state).
Completer<void>? _saveGate;
Completer<void>? _colorGate;

/// When set, every setNoteColor waits for its own release (in call order).
bool _holdEachColor = false;
final _colorHolds = <Completer<void>>[];

Document _doc({int id = 7, int? colorIndex, String body = 'milk'}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Groceries',
  body: body,
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  colorIndex: colorIndex,
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
    case 'saveNote':
      await _saveGate?.future;
      return _json(
        _doc(
          id: (args['documentId'] as int?) ?? 9,
          body: args['body'] as String,
        ).toJson(),
      );
    case 'setNoteColor':
      await _colorGate?.future;
      if (_holdEachColor) {
        final hold = Completer<void>();
        _colorHolds.add(hold);
        await hold.future;
      }
      if (_failColor) return http.Response('secret detail', 500);
      return _json(
        _doc(
          id: args['documentId'] as int,
          colorIndex: args['colorIndex'] as int?,
        ).toJson(),
      );
  }
  return http.Response('', 404);
}

List<String> get _methods => [for (final c in _calls) c.$1];
List<Map<String, dynamic>> _argsOf(String m) => [
  for (final c in _calls)
    if (c.$1 == m) c.$2,
];

Future<void> _pump(
  WidgetTester t, {
  Document? note,
  double width = 1200,
  TargetPlatform platform = TargetPlatform.macOS,
  String? highlight,
  OpenItemController? controller,
  Locale? locale,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox()); // fresh editor state
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildPbTheme(Brightness.light).copyWith(platform: platform),
      home: Scaffold(
        body: NoteEditorView(
          note: note,
          embedded: true,
          highlight: highlight,
          controller: controller,
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pump();
  // The header row (not part of this change) overflows under Ahem at 360.
  if (width < 400) t.takeException();
}

final _button = find.byKey(const ValueKey('note-color-button'));
final _dot = find.descendant(
  of: _button,
  matching: find.byType(NoteColorDot),
);
Finder _swatch(Object i) => find.byKey(ValueKey('note-color-$i'));

NoteColorDot _dotWidget(WidgetTester t) => t.widget<NoteColorDot>(_dot);

/// The dot's painted fill.
BoxDecoration _dotDeco(WidgetTester t) =>
    t
            .widget<AnimatedContainer>(
              find.descendant(
                of: _dot,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

Future<void> _openPicker(WidgetTester t) async {
  await t.tap(_button);
  // not pumpAndSettle: a held save would time out in fake time
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _pick(WidgetTester t, Object i) async {
  await t.tap(_swatch(i));
  await t.pump();
  await t.pump();
}

Future<void> _enterBody(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField).last, text);
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
    _failColor = false;
    _saveGate = null;
    _colorGate = null;
    _holdEachColor = false;
    _colorHolds.clear();
  });

  group('button', () {
    testWidgets('present for a stored and for a new note', (t) async {
      await _pump(t, note: _doc());
      expect(_button, findsOneWidget);
      await _pump(t);
      expect(_button, findsOneWidget);
      expect(_calls, isEmpty);
    });

    testWidgets('auto, stored: the color the card gets (notes[id % 5])', (
      t,
    ) async {
      await _pump(t, note: _doc(id: 7));
      expect(_dotWidget(t).index, isNull);
      expect(_dotWidget(t).noteId, 7);
      expect(_dotDeco(t).color, _pb.notes[7 % 5]);
      expect(find.descendant(of: _dot, matching: find.text('A')), findsNothing);
    });

    testWidgets('auto, unsaved: paper with a serif A', (t) async {
      await _pump(t);
      expect(_dotDeco(t).color, _pb.pdfPaper);
      expect(find.descendant(of: _dot, matching: find.text('A')), findsOne);
    });

    testWidgets('solid and rainbow notes show their color', (t) async {
      await _pump(t, note: _doc(colorIndex: 6));
      expect(_dotDeco(t).color, _pb.notesExtra[1]);
      await _pump(t, note: _doc(colorIndex: Pb.rainbowIndex));
      expect(_dotDeco(t).gradient, isA<SweepGradient>());
      expect(_dotDeco(t).color, isNull);
    });

    testWidgets('chevron next to the dot, 44x44 hit area, 24dp dot', (
      t,
    ) async {
      await _pump(t, note: _doc());
      expect(t.getSize(_button), const Size(44, 44));
      expect(t.getSize(_dot), const Size(24, 24));
      expect(
        find.descendant(of: _button, matching: find.byIcon(AppIcons.expand)),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(find.byIcon(AppIcons.expand)).dx - t.getRect(_dot).right,
        closeTo(2, 0.01),
      );
    });

    for (final (locale, l) in [
      (const Locale('en'), L.en),
      (const Locale('ko'), L.ko),
    ]) {
      testWidgets('semantics label (${locale.languageCode})', (t) async {
        final h = t.ensureSemantics();
        await _pump(t, note: _doc(id: 7), locale: locale);
        // auto, stored: notes[7 % 5] = index 2 (Peach)
        expect(
          t.getSemantics(_button).label,
          l.noteColorAutoOf(l.noteColorName(2)),
        );
        await _pump(t, note: _doc(colorIndex: 3), locale: locale);
        expect(
          t.getSemantics(_button).label,
          l.noteColorOf(l.noteColorName(3)),
        );
        await _pump(t, locale: locale);
        expect(t.getSemantics(_button).label, l.noteColorOf(l.noteColorAuto));
        expect(
          find.byTooltip(l.noteColor),
          findsOneWidget,
        ); // Tooltip(l.noteColor)
        h.dispose();
      });
    }
  });

  group('layout', () {
    for (final width in [360.0, 640.0, 800.0, 1200.0]) {
      testWidgets('width $width: title never runs under the button', (t) async {
        await _pump(
          t,
          note: _doc(),
          width: width,
          platform: width < 600 ? TargetPlatform.android : TargetPlatform.macOS,
        );
        final field = t.widget<TextField>(find.byType(TextField).first);
        final pad = field.decoration!.contentPadding! as EdgeInsets;
        expect(pad.right, NoteSpacing.of(width, short: false).gutter + 48);
        expect(pad.left, NoteSpacing.of(width, short: false).gutter);
        // the title's text area ends left of the button
        final titleRight = t.getRect(find.byType(TextField).first).right;
        expect(
          t.getRect(_button).left,
          greaterThanOrEqualTo(titleRight - pad.right),
        );
        // the chevron ends on the gutter line
        expect(
          titleRight - t.getTopRight(find.byIcon(AppIcons.expand)).dx,
          closeTo(NoteSpacing.of(width, short: false).gutter, 0.6),
        );
      });
    }

    testWidgets('long title at 360: no overflow', (t) async {
      await _pump(
        t,
        note: _doc().copyWith(title: 'very long ' * 20),
        width: 360,
        platform: TargetPlatform.android,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('quote bar on/off: button stays on the first title line', (
      t,
    ) async {
      await _pump(t, width: 724, highlight: 'cited passage');
      expect(find.byKey(const ValueKey('cite-bar')), findsOneWidget);
      double offset() =>
          t.getCenter(_button).dy -
          t.getTopLeft(find.byType(TextField).first).dy;
      final sp = NoteSpacing.of(724, short: false);
      const title = 26.0; // noteSizes(724).title
      expect(offset(), closeTo(sp.bannerToTitle + title * 1.25 / 2, 0.01));
      // closing the highlight; the bar folds away
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('cite-bar')),
          matching: find.byIcon(AppIcons.close),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cite-bar')), findsNothing);
      expect(offset(), closeTo(sp.titleTop + title * 1.25 / 2, 0.01));
    });
  });

  group('picking', () {
    testWidgets('a swatch: setNoteColor once, note stays unchanged', (t) async {
      final controller = OpenItemController();
      await _pump(t, note: _doc(), controller: controller);
      await _openPicker(t);
      expect(find.byType(NoteColorGrid), findsOneWidget); // popover (>= 600)
      await _pick(t, 3);
      expect(_methods, ['setNoteColor']);
      expect(_calls.single.$2, {'documentId': 7, 'colorIndex': 3});
      expect(_dotWidget(t).index, 3);
      expect(_dotDeco(t).color, _pb.notes[3]);
      // not dirty: closing saves nothing
      expect(await controller.flush(), isTrue);
      expect(_methods, ['setNoteColor']);
    });

    testWidgets('Auto sends null', (t) async {
      await _pump(t, note: _doc(colorIndex: 3));
      await _openPicker(t);
      await _pick(t, 'auto');
      expect(_argsOf('setNoteColor').single, {
        'documentId': 7,
        'colorIndex': null,
      });
      expect(_dotWidget(t).index, isNull);
    });

    testWidgets('phone (360): the picker is a sheet', (t) async {
      await _pump(
        t,
        note: _doc(),
        width: 360,
        platform: TargetPlatform.android,
      );
      await _openPicker(t);
      expect(find.byType(BottomSheet), findsOneWidget);
      await _pick(t, 6);
      expect(_argsOf('setNoteColor').single['colorIndex'], 6);
    });

    testWidgets('a pick during a save is sent after the save', (t) async {
      await _pump(t, note: _doc());
      await _enterBody(t, 'milk and eggs');
      _saveGate = Completer<void>();
      await t.tap(find.byIcon(AppIcons.more));
      await t.pumpAndSettle();
      await t.tap(find.text(_l.reindex));
      await t.pump(const Duration(milliseconds: 400));
      expect(_methods, ['saveNote']);
      await _openPicker(t);
      await _pick(t, 2);
      expect(_methods, ['saveNote']); // waits
      expect(_dotWidget(t).index, 2); // but the dot already shows it
      _saveGate!.complete();
      await t.pump();
      await t.pump();
      await t.pump();
      expect(_methods, ['saveNote', 'setNoteColor']);
      expect(_argsOf('setNoteColor').single, {
        'documentId': 7,
        'colorIndex': 2,
      });
    });

    testWidgets('new note: the pick waits for the first save', (t) async {
      await _pump(t);
      await _enterBody(t, 'first words');
      await _openPicker(t);
      await _pick(t, 5);
      expect(_calls, isEmpty);
      expect(_dotWidget(t).index, isNull); // still paper + A
      expect(find.descendant(of: _dot, matching: find.text('A')), findsOne);
      // reopening marks the waiting pick
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(_l.save)); // save and close
      await t.pump();
      await t.pump();
      await t.pump();
      expect(_methods, ['saveNote', 'setNoteColor']);
      expect(_argsOf('setNoteColor').single, {
        'documentId': 9,
        'colorIndex': 5,
      });
      expect(_dotWidget(t).index, 5);
      expect(_dotDeco(t).color, _pb.notesExtra[0]);
    });

    testWidgets('failure: dot reverts, picker closes, fixed text', (t) async {
      _failColor = true;
      await _pump(t, note: _doc(colorIndex: 1));
      await _openPicker(t);
      await _pick(t, 4);
      await t.pumpAndSettle();
      expect(_methods, ['setNoteColor']);
      expect(_dotWidget(t).index, 1);
      expect(find.byType(NoteColorGrid), findsNothing);
      expect(find.text(_l.colorFailed), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    });

    testWidgets('the dot recolors at once, before the server answers', (
      t,
    ) async {
      _colorGate = Completer<void>();
      await _pump(t, note: _doc(colorIndex: 1));
      await _openPicker(t);
      await _pick(t, 6);
      expect(_methods, ['setNoteColor']);
      expect(_dotWidget(t).index, 6);
      expect(_dotDeco(t).color, _pb.notesExtra[1]);
      _colorGate!.complete();
      await t.pumpAndSettle();
      expect(_dotWidget(t).index, 6);
    });

    testWidgets('two quick picks: an older answer arriving last is ignored', (
      t,
    ) async {
      _holdEachColor = true;
      await _pump(t, note: _doc(colorIndex: 1));
      await _openPicker(t);
      await _pick(t, 2);
      await _pick(t, 4);
      expect(_colorHolds, hasLength(2));
      expect(_dotWidget(t).index, 4);
      _colorHolds[1].complete(); // the newer answers first
      await t.pump(const Duration(milliseconds: 50));
      expect(_dotWidget(t).index, 4);
      _colorHolds[0].complete(); // the older one comes late
      await t.pump(const Duration(milliseconds: 50));
      expect(_dotWidget(t).index, 4);
    });

    testWidgets('an older pick failing late does not revert the newer', (
      t,
    ) async {
      _holdEachColor = true;
      await _pump(t, note: _doc(colorIndex: 1));
      await _openPicker(t);
      await _pick(t, 2);
      await _pick(t, 4);
      _colorHolds[1].complete();
      await t.pump(const Duration(milliseconds: 50));
      _failColor = true;
      _colorHolds[0].complete();
      await t.pumpAndSettle();
      expect(_dotWidget(t).index, 4);
      expect(find.text(_l.colorFailed), findsNothing);
      expect(find.byType(NoteColorGrid), findsOneWidget); // still open
    });

    testWidgets('failure on a phone closes the sheet', (t) async {
      _failColor = true;
      await _pump(
        t,
        note: _doc(),
        width: 360,
        platform: TargetPlatform.android,
      );
      await _openPicker(t);
      await _pick(t, 4);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(_l.colorFailed), findsOneWidget);
      expect(_dotWidget(t).index, isNull);
    });
  });

  group('menu', () {
    testWidgets('order: Re-index, Color, Delete', (t) async {
      await _pump(t, note: _doc());
      await t.tap(find.byIcon(AppIcons.more));
      await t.pumpAndSettle();
      final ys = [
        for (final s in [_l.reindex, _l.noteColor, _l.delete])
          t
              .getTopLeft(
                find.descendant(
                  of: find.byWidgetPredicate((w) => w is PopupMenuItem),
                  matching: find.text(s),
                ),
              )
              .dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    });

    testWidgets('Color opens the popover under the color button', (t) async {
      await _pump(t, note: _doc());
      await t.tap(find.byIcon(AppIcons.more));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is PopupMenuItem),
          matching: find.text(_l.noteColor),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(NoteColorGrid), findsOneWidget);
      // anchored to the color button, not the "...": under it, 4 gap + 16 pad
      final grid = t.getRect(find.byType(NoteColorGrid));
      final b = t.getRect(_button);
      expect(grid.top, closeTo(b.bottom + 4 + 16, 0.6));
      expect(grid.left, closeTo(b.left + 16, 0.6));
      await _pick(t, 7);
      expect(_argsOf('setNoteColor').single['colorIndex'], 7);
    });

    testWidgets('Color on a phone opens the sheet', (t) async {
      await _pump(
        t,
        note: _doc(),
        width: 360,
        platform: TargetPlatform.android,
      );
      await t.tap(find.byIcon(AppIcons.more));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is PopupMenuItem),
          matching: find.text(_l.noteColor),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
