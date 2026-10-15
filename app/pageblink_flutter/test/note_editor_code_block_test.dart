import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/live_code_layer.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';

/// Research 024 stage 2: fenced blocks painted as one rounded block behind the
/// field, language label, copy button. Ahem font (tests), macOS desktop.
Future<LiveMarkdownController> _pump(
  WidgetTester t, {
  Size size = const Size(1200, 900),
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light).copyWith(platform: platform),
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
  String text, [
  int caret = 0,
]) async {
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );
  await t.pump();
  await t.pump();
}

RenderEditable _render(WidgetTester t) =>
    t.state<EditableTextState>(find.byType(EditableText).last).renderEditable;

RenderBox _stack(WidgetTester t) => t.renderObject<RenderBox>(
  find
      .ancestor(
        of: find.byType(LiveCodeBackLayer),
        matching: find.byType(Stack),
      )
      .first,
);

RenderObject _back(WidgetTester t) => t.renderObject(
  find.descendant(
    of: find.byType(LiveCodeBackLayer),
    matching: find.byType(CustomPaint),
  ),
);

List<FenceTarget> _targets(WidgetTester t, LiveMarkdownController c) =>
    fenceTargets(_render(t), _stack(t), c.fences);

Color _fill(WidgetTester t) => t
    .widget<LiveCodeBackLayer>(
      find.byType(LiveCodeBackLayer),
    )
    .fill;

CodeBlockUi _ui(WidgetTester t) =>
    t.widget<LiveCodeBackLayer>(find.byType(LiveCodeBackLayer)).ui;

/// Global rectangle of a stack-space [r].
Offset _global(WidgetTester t, Offset p) => _stack(t).localToGlobal(p);

Future<TestGesture> _mouseAt(WidgetTester t, Offset global) async {
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: const Offset(1, 1));
  await g.moveTo(global);
  await t.pump();
  await t.pump();
  return g;
}

Future<void> _click(WidgetTester t, Offset global) async {
  final g = await t.startGesture(
    global,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  await t.pump(const Duration(milliseconds: 40));
  await g.up();
  await t.pump();
  await t.pump();
}

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

/// Records what the app puts on the clipboard.
List<String> _clipboard(WidgetTester t) {
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

const _doc =
    'intro line\n\n```dart\nfinal a = 1;\n\nprint(a);\n```\n\nafter the code';

void main() {
  group('geometry', () {
    testWidgets('one block: union of the fence lines, widened by the bleed', (
      t,
    ) async {
      final c = await _pump(t);
      await _set(t, c, _doc);
      final got = _targets(t, c);
      expect(got, hasLength(1));
      final b = got.single.block;
      final r = _render(t), stack = _stack(t);
      final xf = r.getTransformTo(stack);
      final lines = [
        for (final tb in r.getBoxesForSelection(
          TextSelection(baseOffset: b.start, extentOffset: b.end),
        ))
          MatrixUtils.transformRect(xf, tb.toRect()),
      ];
      expect(lines.length, greaterThan(4));
      final top = lines.map((e) => e.top).reduce((a, b) => a < b ? a : b);
      final bottom = lines.map((e) => e.bottom).reduce((a, b) => a > b ? a : b);
      final rect = got.single.rect;
      expect(rect.top, closeTo(top - 4, 0.01));
      expect(rect.bottom, closeTo(bottom + 4, 0.01));
      // text area width plus the bleed on both sides; the text did not move
      final area = MatrixUtils.transformRect(xf, Offset.zero & r.size);
      expect(rect.left, closeTo(area.left - kFenceBleed, 0.01));
      expect(rect.right, closeTo(area.right + kFenceBleed, 0.01));
      expect(lines.first.left, closeTo(area.left, 0.01));
      // the line above and below are outside the block
      final intro = r
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 5),
          )
          .first;
      expect(
        MatrixUtils.transformRect(xf, intro.toRect()).bottom,
        lessThanOrEqualTo(rect.top + 0.01),
      );
      final after = _doc.indexOf('after');
      final tail = r
          .getBoxesForSelection(
            TextSelection(baseOffset: after, extentOffset: after + 5),
          )
          .first;
      expect(
        MatrixUtils.transformRect(xf, tail.toRect()).top,
        greaterThanOrEqualTo(rect.bottom - 0.01),
      );
    });

    testWidgets('painted as a 10 px rounded rect in the token tint', (t) async {
      final c = await _pump(t);
      await _set(t, c, _doc);
      final rect = _targets(t, c).single.rect;
      final ink = buildPbTheme(Brightness.light).extension<Pb>()!.ink;
      expect(_fill(t).a, closeTo(0.055, 0.001));
      expect(_fill(t).toARGB32() & 0x00FFFFFF, ink.toARGB32() & 0x00FFFFFF);
      expect(
        _back(t),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          color: _fill(t),
        ),
      );
    });

    testWidgets('an unclosed fence runs to the end, an empty last line too', (
      t,
    ) async {
      final c = await _pump(t);
      await _set(t, c, 'text\n```\ncode\n');
      final got = _targets(t, c).single;
      expect(got.block.closeStart, -1);
      final r = _render(t);
      final caret = MatrixUtils.transformRect(
        r.getTransformTo(_stack(t)),
        r.getLocalRectForCaret(TextPosition(offset: c.text.length)),
      );
      expect(got.rect.bottom, greaterThanOrEqualTo(caret.bottom - 0.01));
      expect(got.head, isNotNull);
    });

    testWidgets('the lines of a block carry no per-glyph background', (
      t,
    ) async {
      final c = await _pump(t);
      await _set(t, c, 'x `inline` y\n```\nin block\n```');
      final span = c.buildTextSpan(
        context: t.element(find.byType(EditableText).last),
        withComposing: false,
      );
      bool bg(String needle) =>
          span.children!
              .whereType<TextSpan>()
              .firstWhere((s) => s.text!.contains(needle))
              .style!
              .backgroundColor !=
          null;
      expect(bg('inline'), isTrue); // inline code keeps its tint
      expect(bg('in block'), isFalse); // the block layer paints it
      expect(bg('```'), isFalse);
    });

    testWidgets('follows scroll, text changes and resize in the same frame', (
      t,
    ) async {
      final c = await _pump(t, size: const Size(700, 500));
      final text = [
        for (var i = 0; i < 12; i++)
          '```dart\ncode $i\nmore $i\n```\n\nparagraph $i',
      ].join('\n\n');
      await _set(t, c, text);
      final scroll = t
          .widget<EditableText>(find.byType(EditableText).last)
          .scrollController!;

      void verify() {
        final got = _targets(t, c);
        expect(got, isNotEmpty);
        final rects = [for (final g in got) g.rect];
        // exactly what was just laid out is painted, one rrect per block
        final m = paints;
        for (final r in rects) {
          m.rrect(rrect: RRect.fromRectAndRadius(r, const Radius.circular(10)));
        }
        expect(_back(t), m);
      }

      verify();
      scroll.jumpTo(180);
      await t.pump(); // one frame, no extra settle
      verify();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      verify();
      c.value = c.value.copyWith(
        text:
            'new first\n\n```\nx\n```\n\nwrapped ${'long ' * 90}\n\n${c.text}',
      );
      await t.pump();
      verify();
      t.view.physicalSize = const Size(500, 500);
      await t.pump();
      verify();
      // a block that continues above the view is not closed at the view's top
      scroll.jumpTo(60);
      await t.pump();
      final first = _targets(t, c).first;
      final view = MatrixUtils.transformRect(
        _render(t).getTransformTo(_stack(t)),
        Offset.zero & _render(t).size,
      );
      expect(first.rect.top <= view.top || first.head != null, isTrue);
    });

    testWidgets('only blocks near the viewport are read', (t) async {
      final c = await _pump(t, size: const Size(700, 400));
      final text = [
        for (var i = 0; i < 200; i++) '```\nline $i\n```',
      ].join('\n\n');
      await _set(t, c, text);
      expect(c.fences.length, 200);
      final got = _targets(t, c);
      expect(got.length, lessThan(25));
      expect(got.first.block.start, 0);
    });
  });

  group('source mode and touch', () {
    _desktopTest('source mode: no block, no copy layer', (t, c) async {
      await _set(t, c, _doc);
      expect(_back(t), paints..rrect());
      await t.tap(find.text('Source'));
      await t.pump();
      expect(
        find.descendant(
          of: find.byType(LiveCodeBackLayer),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.byType(LiveCodeCopyLayer), findsNothing);
      await t.tap(find.text('Live'));
      await t.pump();
      expect(_back(t), paints..rrect());
    });

    testWidgets('touch platform: the block shows, the copy button does not', (
      t,
    ) async {
      final c = await _pump(t, platform: TargetPlatform.android);
      await _set(t, c, _doc);
      expect(_back(t), paints..rrect());
      expect(find.byType(LiveCodeCopyLayer), findsNothing);
      // tapping the block only places the caret
      final r = _targets(t, c).single.rect;
      await t.tapAt(_global(t, r.center));
      await t.pump();
      expect(c.text, _doc);
      expect(_ui(t).hovered, isNull);
    });
  });

  group('language label', () {
    testWidgets('painted for ```dart, not for a bare fence', (t) async {
      final c = await _pump(t);
      await _set(t, c, '```dart\nx\n```');
      expect(
        _back(t),
        paints
          ..rrect()
          ..paragraph(),
      );
      await _set(t, c, '```\nx\n```');
      expect(_back(t), isNot(paints..paragraph()));
      expect(c.text, '```\nx\n```'); // saved text never changes
    });
  });

  group('copy button', () {
    _desktopTest('hover shows it; click copies the body without the fences', (
      t,
      c,
    ) async {
      final copied = _clipboard(t);
      await _set(t, c, _doc);
      final tg = _targets(t, c).single;
      expect(_ui(t).shows(tg.block.start), isFalse);
      final btn = copyButtonRect(tg)!;
      // the button sits inside the text area, on the opening fence line
      expect(btn.right, lessThanOrEqualTo(tg.rect.right - kFenceBleed));
      expect(btn.center.dy, closeTo(tg.head!.center.dy, 0.01));
      final g = await _mouseAt(t, _global(t, tg.rect.center));
      expect(_ui(t).shows(tg.block.start), isTrue);
      expect(_ui(t).overButton, isFalse);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
      );
      await g.moveTo(_global(t, btn.center));
      await t.pump();
      await t.pump();
      expect(_ui(t).overButton, isTrue);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      final caret = c.selection;
      await _click(t, _global(t, btn.center));
      expect(copied, ['final a = 1;\n\nprint(a);']);
      expect(c.text, _doc);
      expect(c.selection, caret); // the click did not move the caret
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue,
      );
      // short "Copied" feedback, then back to the button
      expect(_ui(t).copied, tg.block.start);
      await t.pump(const Duration(seconds: 2));
      expect(_ui(t).copied, isNull);
      await g.removePointer();
    });

    _desktopTest('moving away hides the button; a click there is just text', (
      t,
      c,
    ) async {
      final copied = _clipboard(t);
      await _set(t, c, _doc);
      final tg = _targets(t, c).single;
      final g = await _mouseAt(t, _global(t, tg.rect.center));
      expect(_ui(t).shows(tg.block.start), isTrue);
      await g.moveTo(const Offset(5, 5)); // header area, outside the stack
      await t.pump();
      expect(_ui(t).hovered, isNull);
      await _click(t, _global(t, copyButtonRect(tg)!.center));
      expect(copied, isEmpty); // not hovered: the button was not there
      await g.removePointer();
    });

    _desktopTest('unclosed block copies to the end; empty copies nothing', (
      t,
      c,
    ) async {
      final copied = _clipboard(t);
      await _set(t, c, 'x\n```py\na\nb');
      var tg = _targets(t, c).single;
      var g = await _mouseAt(t, _global(t, tg.rect.center));
      await g.moveTo(_global(t, copyButtonRect(tg)!.center));
      await t.pump();
      await _click(t, _global(t, copyButtonRect(tg)!.center));
      expect(copied.last, 'a\nb');
      await g.removePointer();
      await t.pump(const Duration(seconds: 2));
      await _set(t, c, '```\n```');
      tg = _targets(t, c).single;
      g = await _mouseAt(t, _global(t, tg.rect.center));
      await g.moveTo(_global(t, copyButtonRect(tg)!.center));
      await t.pump();
      await _click(t, _global(t, copyButtonRect(tg)!.center));
      expect(copied.last, '');
      await g.removePointer();
      await t.pump(const Duration(seconds: 2));
    });

    _desktopTest('screen readers get a Copy code button node', (t, c) async {
      final handle = t.ensureSemantics();
      final copied = _clipboard(t);
      await _set(t, c, _doc);
      await t.pump();
      expect(find.semantics.byLabel('Copy code'), findsOneWidget);
      t.semantics.tap(find.semantics.byLabel('Copy code'));
      await t.pump();
      expect(copied, ['final a = 1;\n\nprint(a);']);
      await t.pump(const Duration(seconds: 2));
      handle.dispose();
    });
  });

  group('editing around the block', () {
    _desktopTest('inline formats and checkboxes are not applied inside', (
      t,
      c,
    ) async {
      await _set(t, c, '```\n**not bold** [a](https://x.co) - [ ] no\n```');
      expect(c.checks, isEmpty);
      final span = c.buildTextSpan(
        context: t.element(find.byType(EditableText).last),
        withComposing: false,
      );
      for (final s in span.children!.whereType<TextSpan>()) {
        expect(s.style?.fontWeight, isNull, reason: s.text);
        expect(s.style?.decoration, isNull, reason: s.text);
      }
      // no link popover for a caret in the code
      await _set(t, c, '```\n[a](https://x.co)\n```', 8);
      expect(find.byKey(const ValueKey('link-popover')), findsNothing);
    });

    _desktopTest('toolbar Code wraps lines in a fence and unwraps it', (
      t,
      c,
    ) async {
      c.value = const TextEditingValue(
        text: 'a\nb',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await t.pump();
      await t.pump();
      await t.tap(find.byIcon(AppIcons.code).first); // toolbar
      await t.pump();
      await t.pump();
      expect(c.text, '```\na\nb\n```');
      expect(c.fences, hasLength(1));
      expect(_back(t), paints..rrect());
      // caret inside the block: Code takes the fence off again
      c.value = const TextEditingValue(
        text: '```\na\nb\n```',
        selection: TextSelection.collapsed(offset: 5),
      );
      await t.pump();
      await t.pump();
      await t.tap(find.byIcon(AppIcons.code).first);
      await t.pump();
      await t.pump();
      expect(c.text, 'a\nb');
      expect(c.fences, isEmpty);
      expect(_back(t), isNot(paints..rrect()));
    });

    _desktopTest('Code button: empty line gives a fenced block, one undo', (
      t,
      c,
    ) async {
      await _set(t, c, '');
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.byIcon(AppIcons.code).first); // toolbar
      await t.pump();
      await t.pump();
      expect(c.text, '```\n\n```');
      expect(c.selection, const TextSelection.collapsed(offset: 4));
      expect(c.fences, hasLength(1));
      // the block shows at once, no further input needed
      expect(_back(t), paints..rrect());
      expect(_targets(t, c), hasLength(1));
      await t.pump(const Duration(seconds: 1));
      await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await t.pump();
      await t.pump();
      expect(c.text, '');
      expect(c.fences, isEmpty);
    });

    _desktopTest('Code button: non-empty line gets an inline pair', (
      t,
      c,
    ) async {
      await _set(t, c, 'hello', 5);
      await t.tap(find.byIcon(AppIcons.code).first);
      await t.pump();
      await t.pump();
      expect(c.text, 'hello``');
      expect(c.selection, const TextSelection.collapsed(offset: 6));
      expect(c.fences, isEmpty);
    });

    _desktopTest('Code button with the caret inside a block unwraps it', (
      t,
      c,
    ) async {
      await _set(t, c, '```\n\n```', 4);
      await t.tap(find.byIcon(AppIcons.code).first);
      await t.pump();
      await t.pump();
      expect(c.text, '');
      expect(c.fences, isEmpty);
    });

    _desktopTest('typing a fence by hand makes a block as you type', (
      t,
      c,
    ) async {
      await _set(t, c, '```');
      expect(c.fences, hasLength(1));
      await _set(t, c, '```\nco');
      await _set(t, c, '```\nco\n```');
      expect(c.fences.single.closeStart, greaterThan(0));
      expect(_back(t), paints..rrect());
    });
  });

  group('performance', () {
    testWidgets('10,000 chars, 100 fences: cheap to read and paint', (
      t,
    ) async {
      final c = await _pump(t, size: const Size(700, 600));
      final text = [
        for (var i = 0; i < 100; i++)
          '```dart\nvoid f$i() { print($i); }\nreturn $i;\n```\nnote number $i here',
      ].join('\n');
      expect(text.length, greaterThan(6000));
      await _set(t, c, '$text\n${'tail ' * 800}');
      expect(c.text.length, greaterThan(10000));
      expect(c.fences.length, 100);
      final r = _render(t), s = _stack(t);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        fenceTargets(r, s, c.fences);
      }
      final perRead = sw.elapsedMicroseconds / 20 / 1000;
      sw
        ..reset()
        ..start();
      final scroll = t
          .widget<EditableText>(find.byType(EditableText).last)
          .scrollController!;
      for (var y = 0; y < 10; y++) {
        scroll.jumpTo(y * 150.0);
        await t.pump();
      }
      final perFrame = sw.elapsedMicroseconds / 10 / 1000;
      // debug JIT in a test VM: generous bounds, the point is "not O(100)"
      expect(perRead, lessThan(25));
      expect(perFrame, lessThan(150));
    });
  });
}
