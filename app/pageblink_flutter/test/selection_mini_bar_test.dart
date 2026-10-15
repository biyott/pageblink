import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/notes/selection_mini_bar.dart';

Future<TextEditingController> _pump(WidgetTester t) async {
  t.view.physicalSize = const Size(1200, 900);
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

/// Two pumps: the bar is measured in a post-frame callback.
Future<void> _select(
  WidgetTester t,
  TextEditingController c,
  String text,
  int a,
  int b, {
  TextRange composing = TextRange.empty,
}) async {
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: a, extentOffset: b),
    composing: composing,
  );
  await t.pump();
  await t.pump();
}

final _bar = find.byType(SelectionMiniBar);

void main() {
  mouseTests();
  testWidgets('selection shows the bar, collapsing hides it', (t) async {
    final c = await _pump(t);
    expect(_bar, findsNothing);
    await _select(t, c, 'hello world', 0, 5);
    expect(_bar, findsOneWidget);
    expect(
      find.descendant(of: _bar, matching: find.byType(IconButton)),
      findsNWidgets(4),
    );
    // Floats inside the text area, at its left edge for this first line.
    final body = t.getRect(find.byType(TextField).last);
    final bar = t.getRect(
      find.descendant(of: _bar, matching: find.byType(Material)).first,
    );
    expect(body.contains(bar.center), isTrue);
    await _select(t, c, 'hello world', 5, 5);
    expect(_bar, findsNothing);
  });

  testWidgets('bold button wraps the selection, keeps it, toggles back', (
    t,
  ) async {
    final c = await _pump(t);
    await _select(t, c, 'hello world', 0, 5);
    final bold = find.descendant(
      of: _bar,
      matching: find.byIcon(AppIcons.bold),
    );
    await t.tap(bold);
    await t.pump();
    await t.pump();
    expect(c.text, '**hello** world');
    expect(c.selection, const TextSelection(baseOffset: 2, extentOffset: 7));
    expect(_bar, findsOneWidget); // still selected, bar follows
    await t.tap(bold);
    await t.pump();
    expect(c.text, 'hello world');
    expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    // focus stayed in the body
    expect(
      t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('hidden while composing; text untouched', (t) async {
    final c = await _pump(t);
    await _select(
      t,
      c,
      '한글 입력',
      0,
      2,
      composing: const TextRange(start: 0, end: 2),
    );
    expect(_bar, findsNothing);
    expect(c.text, '한글 입력');
    // composition committed -> bar appears
    await _select(t, c, '한글 입력', 0, 2);
    expect(_bar, findsOneWidget);
  });

  testWidgets('Esc closes the bar', (t) async {
    final c = await _pump(t);
    await _select(t, c, 'hello world', 0, 5);
    expect(_bar, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    await t.pump();
    expect(_bar, findsNothing);
    expect(c.text, 'hello world');
  });

  testWidgets('touch platform: no overlay bar (system menu is extended)', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(
          Brightness.light,
        ).copyWith(platform: TargetPlatform.android),
        home: Scaffold(body: NoteEditorView(embedded: true, onClose: () {})),
      ),
    );
    await t.tap(find.byType(TextField).last);
    await t.pump();
    final c = t.widget<EditableText>(find.byType(EditableText).last).controller;
    await _select(t, c, 'hello world', 0, 5);
    expect(_bar, findsNothing);
  });
}

/// A real mouse click: pointer down, a frame, pointer up. Desktop and web
/// treat a down outside the text field as "tap outside" and drop its focus.
Future<void> _mouseClick(WidgetTester t, Finder f) async {
  final g = await t.startGesture(
    t.getCenter(f),
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  // A real click lasts several frames; the bar re-measures in a post-frame
  // callback and rebuilds on the frame after, so give it two.
  await t.pump(const Duration(milliseconds: 40));
  await t.pump(const Duration(milliseconds: 40));
  await g.up();
  await t.pump();
  await t.pump();
}

/// A macOS desktop test: `defaultTargetPlatform` decides the tap-outside
/// default (the theme platform alone does not), and it must be reset inside
/// the test body.
void _desktopTest(
  String name,
  Future<void> Function(WidgetTester t, TextEditingController c) body,
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

void mouseTests() {
  group('mouse click on the bar (tap-outside focus rules)', () {
    _desktopTest('bold button works with a real pointer down/up', (t, c) async {
      await _select(t, c, 'hello world', 0, 5);
      await _mouseClick(
        t,
        find.descendant(of: _bar, matching: find.byIcon(AppIcons.bold)),
      );
      expect(c.text, '**hello** world');
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(_bar, findsOneWidget);
    });

    _desktopTest('code, link and heading buttons too', (t, c) async {
      await _select(t, c, 'hello world', 0, 5);
      await _mouseClick(
        t,
        find.descendant(of: _bar, matching: find.byIcon(AppIcons.code)),
      );
      expect(c.text, '`hello` world');
      await _select(t, c, 'hello world', 6, 11);
      await _mouseClick(
        t,
        find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
      );
      expect(c.text, 'hello [world]()');
      await _select(t, c, 'hello world', 0, 5);
      await _mouseClick(t, find.byKey(const ValueKey('mini-h2')));
      expect(c.text, '## hello world');
    });

    _desktopTest('multi-line block selection through the bar', (t, c) async {
      await _select(t, c, '- one\n- two', 0, 11);
      await _mouseClick(
        t,
        find.descendant(of: _bar, matching: find.byIcon(AppIcons.bold)),
      );
      expect(c.text, '- **one**\n- **two**');
    });

    _desktopTest('top toolbar keeps the body focused on a mouse click', (
      t,
      c,
    ) async {
      await _select(t, c, 'hello world', 0, 5);
      await _mouseClick(t, find.byIcon(AppIcons.italic).first);
      expect(c.text, '_hello_ world');
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    _desktopTest('active state shows, a second click takes it off', (
      t,
      c,
    ) async {
      final active = find.descendant(
        of: _bar,
        matching: find.byWidgetPredicate(
          (w) => w is IconButton && w.isSelected == true,
        ),
      );
      await _select(t, c, 'one\ntwo', 0, 7);
      expect(active, findsNothing);
      final bold = find.descendant(
        of: _bar,
        matching: find.byIcon(AppIcons.bold),
      );
      await _mouseClick(t, bold);
      expect(c.text, '**one**\n**two**');
      expect(active, findsOneWidget);
      // the bar's own bold button is the active one
      expect(
        find.ancestor(
          of: bold,
          matching: find.byWidgetPredicate(
            (w) => w is IconButton && w.isSelected == true,
          ),
        ),
        findsOneWidget,
      );
      await _mouseClick(t, bold);
      expect(c.text, 'one\ntwo');
      expect(active, findsNothing);
    });

    _desktopTest('code on a block fences it and a second click unfences', (
      t,
      c,
    ) async {
      final code = find.descendant(
        of: _bar,
        matching: find.byIcon(AppIcons.code),
      );
      await _select(t, c, '- a\n- b', 0, 7);
      await _mouseClick(t, code);
      expect(c.text, '```\n- a\n- b\n```');
      await _mouseClick(t, code);
      expect(c.text, '- a\n- b');
    });

    _desktopTest('link on list items puts the caret in the first parens', (
      t,
      c,
    ) async {
      final link = find.descendant(
        of: _bar,
        matching: find.byIcon(AppIcons.link),
      );
      await _select(t, c, '- a\n- b', 0, 7);
      await _mouseClick(t, link);
      expect(c.text, '- [a]()\n- [b]()');
      expect(c.selection, const TextSelection.collapsed(offset: 6));
    });

    _desktopTest('nothing is applied while composing', (t, c) async {
      await _select(t, c, 'hello world', 0, 5);
      c.value = c.value.copyWith(composing: const TextRange(start: 0, end: 5));
      await t.pump();
      await _mouseClick(t, find.byIcon(AppIcons.bold).first); // toolbar
      expect(c.text, 'hello world');
    });
  });
}
