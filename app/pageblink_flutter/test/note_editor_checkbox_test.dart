import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/live_check_layer.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/notes/selection_mini_bar.dart';

/// Research 024 stage 1: checkboxes drawn behind the field, tap / keyboard
/// toggles, mini bar. Ahem font (tests), macOS desktop behaviour.
final _bar = find.byType(SelectionMiniBar);

Future<LiveMarkdownController> _pump(
  WidgetTester t, {
  Size size = const Size(1200, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(body: NoteEditorView(embedded: true, onClose: () {})),
    ),
  );
  await t.tap(find.byType(TextField).last); // focus the body
  await t.pump();
  return t.widget<EditableText>(find.byType(EditableText).last).controller
      as LiveMarkdownController;
}

Future<void> _set(
  WidgetTester t,
  TextEditingController c,
  String text,
  int a, [
  int? b,
  TextRange composing = TextRange.empty,
]) async {
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: a, extentOffset: b ?? a),
    composing: composing,
  );
  await t.pump();
  await t.pump();
}

RenderEditable _render(WidgetTester t) =>
    t.state<EditableTextState>(find.byType(EditableText).last).renderEditable;

RenderBox _stack(WidgetTester t) => t.renderObject<RenderBox>(
  find
      .ancestor(of: find.byType(LiveCheckLayer), matching: find.byType(Stack))
      .first,
);

/// Global centre of the marker `[start, end)` (a point a user would click).
Offset _globalCenter(WidgetTester t, int start, int end) {
  final r = _render(t);
  final box = r
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .first
      .toRect();
  return r.localToGlobal(box.center);
}

Future<void> _mouseClick(WidgetTester t, Offset at) async {
  final g = await t.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  await t.pump(const Duration(milliseconds: 40));
  await g.up();
  await t.pump();
  await t.pump();
}

bool _focused(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus;

void _desktopTest(
  String name,
  Future<void> Function(WidgetTester t, LiveMarkdownController c) body,
) {
  testWidgets(name, (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body(t, await _pump(t));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

const _todo = '- [ ] first\n- [x] second\nplain line\n  - [ ] nested';

void main() {
  group('tap toggle', () {
    _desktopTest('a click on the prefix flips the box, caret and focus stay', (
      t,
      c,
    ) async {
      await _set(t, c, _todo, 14); // caret inside "second"
      expect(find.byType(LiveCheckLayer), findsOneWidget);
      await _mouseClick(t, _globalCenter(t, 0, 6));
      expect(c.text, _todo.replaceFirst('- [ ] first', '- [x] first'));
      expect(c.selection, const TextSelection.collapsed(offset: 14));
      expect(_focused(t), isTrue);
      // and back; a done item is cleared
      await _mouseClick(t, _globalCenter(t, 12, 18));
      expect(c.text, '- [x] first\n- [ ] second\nplain line\n  - [ ] nested');
      expect(c.selection, const TextSelection.collapsed(offset: 14));
    });

    _desktopTest('a range selection survives a toggle', (t, c) async {
      await _set(t, c, _todo, 3, 22);
      await _mouseClick(t, _globalCenter(t, 12, 18));
      expect(c.text.startsWith('- [ ] first\n- [ ] second'), isTrue);
      expect(c.selection, const TextSelection(baseOffset: 3, extentOffset: 22));
    });

    _desktopTest('indented item, and text next to the prefix is not a hit', (
      t,
      c,
    ) async {
      await _set(t, c, _todo, 0);
      final nestedStart = _todo.indexOf('- [ ] nested');
      await _mouseClick(t, _globalCenter(t, nestedStart, nestedStart + 6));
      expect(c.text.endsWith('  - [x] nested'), isTrue);
      // a click on the item's words only moves the caret
      final w = _todo.indexOf('first') + 2;
      final before = c.text;
      await _mouseClick(t, _globalCenter(t, w, w + 1));
      expect(c.text, before);
      expect(c.selection.isCollapsed, isTrue);
      expect(c.selection.baseOffset, anyOf(w, w + 1));
    });

    _desktopTest('undo (Cmd+Z) restores the box', (t, c) async {
      await _set(t, c, _todo, 14);
      await t.pump(const Duration(seconds: 1));
      await _mouseClick(t, _globalCenter(t, 0, 6));
      expect(c.text.startsWith('- [x] first'), isTrue);
      await t.pump(const Duration(seconds: 1));
      await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await t.pump();
      expect(c.text, _todo);
    });

    _desktopTest('ignored while an IME composition is open', (t, c) async {
      await _set(
        t,
        c,
        _todo,
        14,
        14,
        const TextRange(start: 12, end: 14),
      );
      await _mouseClick(t, _globalCenter(t, 0, 6));
      expect(c.text, _todo);
      expect(c.value.composing, const TextRange(start: 12, end: 14));
    });

    _desktopTest('source mode: no boxes, no toggle', (t, c) async {
      await _set(t, c, _todo, 14);
      await t.tap(find.text('Source'));
      await t.pump();
      expect(find.byType(LiveCheckLayer), findsNothing);
      final span = c.buildTextSpan(
        context: t.element(find.byType(EditableText).last),
        withComposing: false,
      );
      expect(span.toPlainText(), _todo);
      expect(span.children, isNull); // stock plain controller
      await _mouseClick(t, _globalCenter(t, 0, 6));
      expect(c.text, _todo);
      await t.tap(find.text('Live'));
      await t.pump();
      expect(find.byType(LiveCheckLayer), findsOneWidget);
    });
  });

  group('painter geometry', () {
    testWidgets('boxes sit on the transparent prefix, scroll and resize', (
      t,
    ) async {
      final c = await _pump(t, size: const Size(700, 500));
      final text = [
        for (var i = 0; i < 60; i++)
          if (i % 7 == 3)
            'plain $i'
          else
            '- [${i % 3 == 0 ? 'x' : ' '}] item $i',
      ].join('\n');
      await _set(t, c, text, 0);
      final scroll = t
          .widget<EditableText>(find.byType(EditableText).last)
          .scrollController!;

      void verify() {
        final r = _render(t), stack = _stack(t);
        // as the layer reads: items in the air band above the editable too
        final air = t
            .widget<LiveCheckLayer>(find.byType(LiveCheckLayer))
            .topAir;
        final got = checkBoxTargets(r, stack, c.checks, topAir: air);
        expect(got, isNotEmpty);
        for (final (:item, :rect) in got) {
          final local = r
              .getBoxesForSelection(
                TextSelection(baseOffset: item.start, extentOffset: item.end),
              )
              .first
              .toRect();
          final want = local.shift(
            r.localToGlobal(Offset.zero) - stack.localToGlobal(Offset.zero),
          );
          expect(rect, want);
          // 6 characters of the Ahem 16 px font (+ default letter spacing)
          expect(rect.width, greaterThan(40));
        }
        // the drawing is the same frame as the layout (T10): one rrect each
        final painted = t.renderObject(
          find.descendant(
            of: find.byType(LiveCheckLayer),
            matching: find.byType(CustomPaint),
          ),
        );
        final accent = buildPbTheme(Brightness.light).colorScheme.primary;
        final hairline = t.element(find.byType(LiveCheckLayer)).pb.hairline;
        final matcher = paints;
        for (final (:item, :rect) in got) {
          final side = math.max(10.0, math.min(18.0, rect.width - 4));
          final box = Rect.fromLTWH(
            rect.left,
            rect.center.dy - side / 2,
            side,
            side,
          );
          final rr = RRect.fromRectAndRadius(box, const Radius.circular(5));
          if (item.done) {
            matcher.rrect(rrect: rr, color: accent);
          } else {
            matcher.rrect(
              rrect: rr.deflate(0.75),
              color: hairline,
              style: PaintingStyle.stroke,
              strokeWidth: 1.5,
            );
          }
        }
        expect(painted, matcher);
      }

      verify();
      scroll.jumpTo(120);
      await t.pump(); // one frame, no extra settle
      verify();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      verify();
      // content change moves everything below
      c.value = c.value.copyWith(
        text: '# New heading\n\nwrapped ${'long ' * 80}\n${c.text}',
      );
      await t.pump();
      verify();
      // narrower window: lines wrap, boxes follow
      t.view.physicalSize = const Size(500, 500);
      await t.pump();
      verify();
    });

    testWidgets('only the items around the viewport are read', (t) async {
      final c = await _pump(t, size: const Size(700, 400));
      final text = [for (var i = 0; i < 400; i++) '- [ ] item $i'].join('\n');
      await _set(t, c, text, 0);
      final got = checkBoxTargets(_render(t), _stack(t), c.checks);
      expect(got.length, lessThan(40));
      expect(got.first.item.start, 0);
    });

    testWidgets('10,000 chars, 300 checkboxes: cheap to read and paint', (
      t,
    ) async {
      final c = await _pump(t, size: const Size(700, 600));
      final lines = <String>[
        for (var i = 0; i < 300; i++)
          '- [${i.isEven ? ' ' : 'x'}] task number $i with a few more words',
      ];
      final text = lines.join('\n');
      expect(text.length, greaterThan(10000));
      await _set(t, c, text, 0);
      expect(c.checks.length, 300);
      final r = _render(t), s = _stack(t);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        checkBoxTargets(r, s, c.checks);
      }
      final perRead = sw.elapsedMicroseconds / 20 / 1000;
      sw
        ..reset()
        ..start();
      final scroll = t
          .widget<EditableText>(find.byType(EditableText).last)
          .scrollController!;
      for (var y = 0; y < 10; y++) {
        scroll.jumpTo(y * 200.0);
        await t.pump();
      }
      final perFrame = sw.elapsedMicroseconds / 10 / 1000;
      // debug JIT in a test VM: generous bounds, the point is "not O(300)"
      expect(perRead, lessThan(25));
      expect(perFrame, lessThan(150));
    });

    testWidgets('screen readers get done / not done nodes with a tap', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      final c = await _pump(t);
      await _set(t, c, '- [ ] a\n- [x] b', 0);
      await t.pump();
      final todo = find.semantics.byLabel('Not done').evaluate().single;
      final done = find.semantics.byLabel('Done').evaluate().single;
      // ignore: deprecated_member_use
      expect(todo.hasFlag(SemanticsFlag.hasCheckedState), isTrue);
      // ignore: deprecated_member_use
      expect(todo.hasFlag(SemanticsFlag.isChecked), isFalse);
      // ignore: deprecated_member_use
      expect(done.hasFlag(SemanticsFlag.isChecked), isTrue);
      // the field itself is still one text field (not a container of spans)
      // ignore: deprecated_member_use
      expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsWidgets);
      t.semantics.tap(find.semantics.byLabel('Not done'));
      await t.pump();
      expect(c.text, '- [x] a\n- [x] b');
      handle.dispose();
    });

    testWidgets('a touch tap on the box toggles it, nothing else moves', (
      t,
    ) async {
      final c = await _pump(t);
      await _set(t, c, _todo, 14);
      await t.tapAt(_globalCenter(t, 0, 6));
      await t.pump();
      expect(c.text, _todo.replaceFirst('- [ ] first', '- [x] first'));
      expect(c.selection, const TextSelection.collapsed(offset: 14));
      expect(_focused(t), isTrue);
      // below the line pitch: a tap in the gap above a box still finds it
      final r = _globalCenter(t, 12, 18);
      await t.tapAt(r + const Offset(0, 11));
      await t.pump();
      expect(c.text.contains('- [ ] second'), isTrue);
    });

    testWidgets('pointer over a marker shows the click cursor', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final c = await _pump(t);
        await _set(t, c, _todo, 0);
        final g = await t.createGesture(kind: PointerDeviceKind.mouse);
        await g.addPointer(location: const Offset(1, 1));
        await g.moveTo(_globalCenter(t, 0, 6));
        await t.pump();
        await t.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );
        final w = _todo.indexOf('first');
        await g.moveTo(_globalCenter(t, w, w + 1));
        await t.pump();
        await t.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.text,
        );
        await g.removePointer();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('keyboard and mini bar', () {
    Future<void> cmdEnter(WidgetTester t) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await t.pump();
    }

    _desktopTest('Cmd+Enter toggles the caret line, caret stays', (t, c) async {
      await _set(t, c, _todo, 14);
      await cmdEnter(t);
      expect(c.text, _todo.replaceFirst('- [x] second', '- [ ] second'));
      expect(c.selection, const TextSelection.collapsed(offset: 14));
      await _set(t, c, 'plain', 2);
      await cmdEnter(t);
      expect(c.text, 'plain'); // not a checklist line: nothing happens
    });

    _desktopTest('Cmd+Enter on a selection checks all, then clears all', (
      t,
      c,
    ) async {
      await _set(t, c, _todo, 0, _todo.length);
      await cmdEnter(t);
      expect(c.text, '- [x] first\n- [x] second\nplain line\n  - [x] nested');
      await cmdEnter(t);
      expect(c.text, '- [ ] first\n- [ ] second\nplain line\n  - [ ] nested');
    });

    _desktopTest('mini bar: complete all / uncheck all appears with items', (
      t,
      c,
    ) async {
      await _set(t, c, 'plain text', 0, 5);
      expect(_bar, findsOneWidget);
      expect(find.byTooltip('Complete all'), findsNothing);
      expect(find.byTooltip('Uncheck all'), findsNothing);
      expect(
        find.descendant(of: _bar, matching: find.byType(IconButton)),
        findsNWidgets(4),
      );

      await _set(t, c, _todo, 0, _todo.length);
      expect(
        find.descendant(of: _bar, matching: find.byType(IconButton)),
        findsNWidgets(5),
      );
      await t.tap(find.byTooltip('Complete all'));
      await t.pump();
      await t.pump();
      expect(c.text, '- [x] first\n- [x] second\nplain line\n  - [x] nested');
      expect(
        c.selection,
        TextSelection(baseOffset: 0, extentOffset: _todo.length),
      );
      expect(find.byTooltip('Uncheck all'), findsOneWidget);
      await t.tap(find.byTooltip('Uncheck all'));
      await t.pump();
      await t.pump();
      expect(c.text, '- [ ] first\n- [ ] second\nplain line\n  - [ ] nested');
      expect(_focused(t), isTrue);
    });

    _desktopTest('mini bar over plain lines gains nothing', (t, c) async {
      await _set(t, c, '- a\n- b\nc', 0, 9);
      expect(
        find.descendant(of: _bar, matching: find.byType(IconButton)),
        findsNWidgets(4),
      );
    });
  });
}
