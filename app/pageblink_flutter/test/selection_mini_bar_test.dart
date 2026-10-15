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
