import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/note_color_picker.dart';

/// Regression: a fixed popover width (272) smaller than its content (16 + 256)
/// made MenuAnchor's UnconstrainedBox(hardEdge) cut the right swatch column.
Future<void> _open(WidgetTester t, Brightness b, double w, Alignment at) async {
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = MenuController();
  final pb = b == Brightness.light ? Pb.light : Pb.dark;
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(b),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: at,
          child: MenuAnchor(
            controller: c,
            style: noteColorMenuStyle(pb),
            alignmentOffset: noteColorAnchorOffset,
            menuChildren: [NoteColorPopover(current: null, onPick: (_) {})],
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    ),
  );
  c.open();
  await t.pumpAndSettle();
}

void main() {
  for (final b in Brightness.values) {
    for (final w in [600.0, 1024.0, 1440.0]) {
      for (final at in [Alignment.centerLeft, Alignment.centerRight]) {
        testWidgets('popover is not clipped: ${b.name} $w $at', (t) async {
          await _open(t, b, w, at);
          final popover = find.byType(NoteColorPopover);
          final box = find.ancestor(
            of: popover,
            matching: find.byType(UnconstrainedBox),
          );
          final material = find.ancestor(
            of: popover,
            matching: find.byType(Material),
          );
          final panel = t.getRect(material.first);
          expect(panel.width, 288);
          // No clipped pixel: the box that clips is no smaller than the panel.
          expect(
            t.getRect(box.first).inflate(0.001).contains(panel.topLeft),
            isTrue,
          );
          expect(
            t.getRect(box.first).inflate(0.001).contains(panel.bottomRight),
            isTrue,
          );
          final first = t.getRect(
            find.byKey(const ValueKey('note-color-auto')),
          );
          final last = t.getRect(find.byKey(const ValueKey('note-color-8')));
          expect(
            panel.right - last.right,
            closeTo(first.left - panel.left, 0.001),
          );
          expect(first.left - panel.left, 16);
          // Stays on screen, also when anchored at the right edge.
          expect(panel.left, greaterThanOrEqualTo(0));
          expect(panel.right, lessThanOrEqualTo(w));
        });
      }
    }
  }
}
