import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/open_item_controller.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

/// The board recolors a note the moment a swatch is tapped, before the server
/// answers (optimistic update), and stays right when answers arrive late,
/// out of order, or fail.
Document _doc(int id, {int? colorIndex}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'note',
  title: 'Note $id',
  body: 'body $id',
  contentHash: 'h$id',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  colorIndex: colorIndex,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.now().toUtc(),
);

class _Call {
  _Call(this.id, this.color);
  final int id;
  final int? color;
  final done = Completer<Document>();
}

/// A server whose `setNoteColor` answers only when the test says so.
class _Server {
  _Server(this.docs);
  List<Document> docs;
  final calls = <_Call>[];
  int listCalls = 0;

  /// Holds the next `list` call only: it answers after this completes, with
  /// the snapshot taken when it was called.
  Completer<void>? listGate;

  BoardApi get api => BoardApi(
    list: () async {
      listCalls++;
      final snapshot = List.of(docs);
      final gate = listGate;
      listGate = null;
      await gate?.future;
      return snapshot;
    },
    delete: (id) async => docs = [
      for (final d in docs)
        if (d.id != id) d,
    ],
    reindex: (id) async => docs.firstWhere((d) => d.id == id),
    setNoteColor: (id, c) {
      final call = _Call(id, c);
      calls.add(call);
      return call.done.future;
    },
  );

  /// What the real server does when it accepts [call].
  void accept(_Call call) {
    final i = docs.indexWhere((d) => d.id == call.id);
    final saved = docs[i].copyWith(colorIndex: call.color);
    docs[i] = saved;
    call.done.complete(saved);
  }
}

Future<void> _pump(
  WidgetTester t,
  _Server s, {
  bool reduced = true,
  Size size = const Size(1280, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
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

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card));

Color? _cardColor(WidgetTester t, String title) =>
    t.widget<Card>(_card(title)).color;

final _gradientInk = find.byWidgetPredicate(
  (w) =>
      w is Ink &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).gradient != null,
);

Future<void> _openPicker(WidgetTester t, String title) async {
  await t.tap(
    find.descendant(of: _card(title), matching: find.byIcon(AppIcons.more)),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Color'));
  await t.pumpAndSettle();
}

/// One frame after the tap: no waiting for anything.
Future<void> _tapSwatch(WidgetTester t, Object i) async {
  await t.tap(find.byKey(ValueKey('note-color-$i')));
  await t.pump();
}

void main() {
  const pb = Pb.light;
  final l = L.en;

  testWidgets('the card recolors in the tapping frame, call still pending', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    expect(_cardColor(t, 'Note 1'), pb.notes[1]);
    await _tapSwatch(t, 5); // a single frame
    expect(s.calls.single.color, 5);
    expect(s.calls.single.done.isCompleted, isFalse);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The picker marks it and stays open.
    expect(
      t.getSemantics(find.byKey(const ValueKey('note-color-5'))),
      isSemantics(isSelected: true),
    );
    expect(find.byKey(const ValueKey('note-color-5')), findsOneWidget);
  });

  testWidgets('confirmed: the color stays and the list is reloaded quietly', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 6);
    final loads = s.listCalls;
    s.accept(s.calls.single);
    await t.pumpAndSettle();
    expect(s.listCalls, loads + 1);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failure: reverts to the old color and shows the error', (
    t,
  ) async {
    final s = _Server([_doc(1, colorIndex: 3)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
    s.calls.single.done.completeError(Exception('500'));
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notes[3]);
    expect(find.text(l.colorFailed), findsOneWidget);
  });

  testWidgets('demo limit on a pick: reverts and says why', (t) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 2);
    s.calls.single.done.completeError(
      DemoLimitException(reason: DemoLimitReason.sampleLocked),
    );
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notes[1]);
    expect(find.textContaining("Sample items can't be edited"), findsOne);
    expect(find.text(l.colorFailed), findsNothing);
  });

  testWidgets('a list that arrives while the call is pending keeps the pick', (
    t,
  ) async {
    final s = _Server([_doc(1), _doc(2)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 7);
    // The server still has the old color: a refresh now carries it.
    boardRefresh.value++;
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[2]);
    // Other cards come from the server as usual.
    expect(_cardColor(t, 'Note 2'), pb.notes[2]);
    s.accept(s.calls.single);
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[2]);
  });

  testWidgets('a refresh that started before the pick cannot flip it back', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    final gate = s.listGate = Completer<void>();
    boardRefresh.value++; // in flight, will answer with the old color
    await t.pump();
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    s.accept(s.calls.single); // the server now has 5
    await t.pump();
    s.listGate = null;
    gate.complete(); // the stale answer lands after the settle
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
  });

  testWidgets('two quick picks: the last one wins, even if answered first', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    await _tapSwatch(t, 7);
    expect(s.calls.map((c) => c.color), [5, 7]);
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[2]);
    s.accept(s.calls[1]);
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[2]);
    s.accept(s.calls[0]); // the older answer comes late
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[2]);
  });

  testWidgets('an older pick failing late does not undo the newer one', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    await _tapSwatch(t, 6);
    s.calls[0].done.completeError(Exception('500'));
    await t.pump();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
    expect(find.text(l.colorFailed), findsNothing);
    s.accept(s.calls[1]);
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
  });

  testWidgets('the newer pick failing falls back to the last confirmed', (
    t,
  ) async {
    final s = _Server([_doc(1)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    await _tapSwatch(t, 6);
    s.accept(s.calls[0]); // 5 is confirmed, 6 is still out
    await t.pump();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
    s.calls[1].done.completeError(Exception('500'));
    await t.pumpAndSettle();
    expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
    expect(find.text(l.colorFailed), findsOneWidget);
  });

  testWidgets('pick then delete: no ghost card, no error when it fails', (
    t,
  ) async {
    final s = _Server([_doc(1), _doc(2)]);
    await _pump(t, s);
    await _openPicker(t, 'Note 1');
    await _tapSwatch(t, 5);
    await t.tapAt(const Offset(5, 5)); // close the popover
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: _card('Note 1'),
        matching: find.byIcon(AppIcons.more),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(find.text('Note 1'), findsNothing);
    s.calls.single.done.completeError(Exception('not found'));
    await t.pumpAndSettle();
    expect(find.text('Note 1'), findsNothing);
    expect(find.text('Note 2'), findsOneWidget);
    expect(find.text(l.colorFailed), findsNothing);
  });

  group('fade', () {
    testWidgets('reduced motion: no animation at all', (t) async {
      final s = _Server([_doc(1)]);
      await _pump(t, s, reduced: true);
      await _openPicker(t, 'Note 1');
      await _tapSwatch(t, 8);
      expect(_cardColor(t, 'Note 1'), Colors.transparent);
      expect(_gradientInk, findsOneWidget);
      await _tapSwatch(t, 6);
      expect(_cardColor(t, 'Note 1'), pb.notesExtra[1]);
      expect(_gradientInk, findsNothing);
    });

    testWidgets('solid to solid: 200 ms interpolation', (t) async {
      final s = _Server([_doc(1, colorIndex: 0)]);
      await _pump(t, s, reduced: false);
      await _openPicker(t, 'Note 1');
      await _tapSwatch(t, 5);
      expect(_cardColor(t, 'Note 1'), pb.notes[0]); // first frame: start
      await t.pump(const Duration(milliseconds: 100));
      final mid = _cardColor(t, 'Note 1');
      expect(mid, isNot(pb.notes[0]));
      expect(mid, isNot(pb.notesExtra[0]));
      await t.pump(const Duration(milliseconds: 150));
      expect(_cardColor(t, 'Note 1'), pb.notesExtra[0]);
    });

    testWidgets('solid <-> rainbow cross-fades, opaque all the way', (t) async {
      final s = _Server([_doc(1, colorIndex: 3)]);
      await _pump(t, s, reduced: false);
      await _openPicker(t, 'Note 1');
      await _tapSwatch(t, 8);
      await t.pump(const Duration(milliseconds: 100));
      expect(_cardColor(t, 'Note 1'), isNot(Colors.transparent));
      expect(_gradientInk, findsOneWidget);
      await t.pump(const Duration(milliseconds: 150));
      expect(_cardColor(t, 'Note 1'), Colors.transparent);
      expect(_gradientInk, findsOneWidget);

      await _tapSwatch(t, 1);
      await t.pump(const Duration(milliseconds: 100));
      expect(_cardColor(t, 'Note 1'), isNot(Colors.transparent));
      expect(_gradientInk, findsOneWidget); // still fading out
      await t.pump(const Duration(milliseconds: 150));
      expect(_cardColor(t, 'Note 1'), pb.notes[1]);
      expect(_gradientInk, findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
