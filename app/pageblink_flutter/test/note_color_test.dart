import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

Document _doc(int id, String kind, {int? colorIndex}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: kind,
  title: kind == 'note' ? 'Note $id' : 'Pdf $id',
  body: kind == 'note' ? 'body $id' : null,
  contentHash: 'h$id',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  colorIndex: colorIndex,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.now().toUtc(),
);

/// In-memory board; `setNoteColor` stores what the server would.
class _Server {
  _Server(this.docs);
  List<Document> docs;
  final colorCalls = <(int, int?)>[];

  BoardApi get api => BoardApi(
    list: () async => List.of(docs),
    delete: (id) async {},
    reindex: (id) async => docs.firstWhere((d) => d.id == id),
    setNoteColor: (id, c) async {
      colorCalls.add((id, c));
      final i = docs.indexWhere((d) => d.id == id);
      return docs[i] = docs[i].copyWith(colorIndex: c);
    },
  );
}

Future<void> _pump(
  WidgetTester t,
  _Server s, {
  Size size = const Size(1280, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light),
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

/// The Card that holds [title].
Color? _cardColor(WidgetTester t, String title) => t
    .widget<Card>(
      find.ancestor(of: find.text(title), matching: find.byType(Card)),
    )
    .color;

Finder _menuOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
  matching: find.byIcon(AppIcons.more),
);

Future<void> _openColorPicker(WidgetTester t, String title) async {
  await t.tap(_menuOf(title));
  await t.pumpAndSettle();
  await t.tap(find.text('Color'));
  await t.pumpAndSettle();
}

void main() {
  const pb = Pb.light;

  testWidgets('the menu offers Color for notes only', (t) async {
    await _pump(t, _Server([_doc(1, 'note'), _doc(2, 'pdf')]));
    await t.tap(_menuOf('Note 1'));
    await t.pumpAndSettle();
    expect(find.text('Color'), findsOneWidget);
    await t.tapAt(const Offset(5, 5)); // dismiss
    await t.pumpAndSettle();
    await t.tap(_menuOf('Pdf 2'));
    await t.pumpAndSettle();
    expect(find.text('Re-index'), findsOneWidget);
    expect(find.text('Color'), findsNothing);
  });

  testWidgets('auto color is unchanged: notes[id % 5]', (t) async {
    await _pump(t, _Server([_doc(1, 'note'), _doc(7, 'note')]));
    expect(_cardColor(t, 'Note 1'), pb.notes[1]);
    expect(_cardColor(t, 'Note 7'), pb.notes[2]);
  });

  testWidgets('picking a swatch calls the API and recolors the card', (
    t,
  ) async {
    final s = _Server([_doc(1, 'note')]);
    await _pump(t, s);
    await _openColorPicker(t, 'Note 1');
    // Every color has a spoken name.
    expect(find.bySemanticsLabel('Rainbow'), findsOneWidget);
    expect(find.bySemanticsLabel('Rose'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('note-color-5')));
    await t.pumpAndSettle();
    expect(s.colorCalls, [(1, 5)]);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
  });

  testWidgets('Auto clears the choice; the picker marks the current one', (
    t,
  ) async {
    final s = _Server([_doc(1, 'note', colorIndex: 6)]);
    await _pump(t, s);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
    await _openColorPicker(t, 'Note 1');
    expect(
      t.getSemantics(find.byKey(const ValueKey('note-color-6'))),
      isSemantics(isSelected: true),
    );
    await t.tap(find.byKey(const ValueKey('note-color-auto')));
    await t.pumpAndSettle();
    expect(s.colorCalls, [(1, null)]);
    expect(_cardColor(t, 'Note 1'), pb.notes[1]);
  });

  testWidgets('rainbow paints a gradient under the ink', (t) async {
    final s = _Server([_doc(1, 'note')]);
    await _pump(t, s);
    final gradientInk = find.byWidgetPredicate(
      (w) =>
          w is Ink &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient != null,
    );
    expect(gradientInk, findsNothing);
    await _openColorPicker(t, 'Note 1');
    await t.tap(find.byKey(const ValueKey('note-color-8')));
    await t.pumpAndSettle();
    expect(s.colorCalls, [(1, Pb.rainbowIndex)]);
    expect(gradientInk, findsOneWidget);
    expect(_cardColor(t, 'Note 1'), Colors.transparent);
  });

  testWidgets('phones get a bottom sheet that stays open and names the pick', (
    t,
  ) async {
    final s = _Server([_doc(1, 'note')]);
    await _pump(t, s, size: const Size(390, 800));
    await _openColorPicker(t, 'Note 1');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget); // caption of the current pick
    await t.tap(find.byKey(const ValueKey('note-color-5')));
    await t.pumpAndSettle();
    expect(s.colorCalls, [(1, 5)]);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Rose'), findsOneWidget); // caption
    await t.tap(find.byKey(const ValueKey('note-color-8')));
    await t.pumpAndSettle();
    expect(s.colorCalls, [(1, 5), (1, 8)]);
    expect(find.text('Rainbow'), findsOneWidget);
  });

  testWidgets('swatch order: Auto, Rose, Peach, Butter, Lime / Mint, ...', (
    t,
  ) async {
    await _pump(t, _Server([_doc(1, 'note')]));
    await _openColorPicker(t, 'Note 1');
    Offset at(String k) => t.getCenter(find.byKey(ValueKey('note-color-$k')));
    final rows = [
      ['auto', '5', '2', '0', '7'],
      ['1', '6', '3', '4', '8'],
    ];
    for (final row in rows) {
      final p = [for (final k in row) at(k)];
      for (var i = 1; i < p.length; i++) {
        expect(p[i].dx, greaterThan(p[i - 1].dx));
        expect(p[i].dy, p[0].dy);
      }
    }
    expect(at('1').dy, greaterThan(at('auto').dy));
    // 48dp touch cells, 4dp apart in the popover.
    expect(
      t.getSize(find.byKey(const ValueKey('note-color-5'))),
      const Size(48, 48),
    );
    expect(at('5').dx - at('auto').dx, 52);
  });

  testWidgets('dismissing the picker changes nothing', (t) async {
    final s = _Server([_doc(1, 'note')]);
    await _pump(t, s);
    await _openColorPicker(t, 'Note 1');
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(s.colorCalls, isEmpty);
  });

  test('noteColor: explicit wins, rainbow has a flat stand-in', () {
    for (final p in [Pb.light, Pb.dark]) {
      expect(p.noteColor(3), p.notes[3]);
      expect(p.noteColor(3, colorIndex: 7), p.notesExtra[2]);
      expect(p.noteColor(null), p.notes[0]);
      expect(p.noteColor(3, colorIndex: 99), p.notes[3]); // bad index: auto
      expect(p.noteColor(3, colorIndex: 8), p.noteRainbowFlat);
      expect(p.noteGradient(8), isA<LinearGradient>());
      expect(p.noteGradient(2), isNull);
      expect(p.noteGradient(null), isNull);
    }
  });
}
