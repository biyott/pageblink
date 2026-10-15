import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/notes/link_popover.dart';
import 'package:pageblink_flutter/features/notes/markdown_live.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/notes/selection_mini_bar.dart';

/// Editor UI for research 023: heading state, mini-bar headings, link popover,
/// Enter continuation through the real text field.
final _chip = find.byType(LinkPopover);
final _bar = find.byType(SelectionMiniBar);
final _headingButton = find.byKey(const ValueKey('heading-button'));
final _chipButton = find.byKey(const ValueKey('link-open'));

Future<(LiveMarkdownController, List<Uri>)> _pump(WidgetTester t) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final opened = <Uri>[];
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: NoteEditorView(
          embedded: true,
          onClose: () {},
          openLink: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ),
    ),
  );
  await t.tap(find.byType(TextField).last); // focus the body
  await t.pump();
  final c =
      t.widget<EditableText>(find.byType(EditableText).last).controller
          as LiveMarkdownController;
  return (c, opened);
}

/// Two pumps: bar and chip are measured in a post-frame callback.
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

void main() {
  group('heading button', () {
    testWidgets('shows the current level, none for body or mixed', (t) async {
      final (c, _) = await _pump(t);
      Finder label(String s) =>
          find.descendant(of: _headingButton, matching: find.text(s));
      await _set(t, c, 'body', 2);
      expect(label('H1'), findsNothing);
      expect(label('H2'), findsNothing);
      await _set(t, c, '## two', 4);
      expect(label('H2'), findsOneWidget);
      await _set(t, c, '#### four', 4);
      expect(label('H4'), findsOneWidget);
      await _set(t, c, '# a\nplain', 0, 9);
      expect(label('H1'), findsNothing); // mixed
      await _set(t, c, '# a\n# b', 0, 7);
      expect(label('H1'), findsOneWidget);
    });

    testWidgets('menu checks the matching level; H4 is not "body"', (t) async {
      final (c, _) = await _pump(t);
      Future<Map<String, bool>> menu(String text, int a, [int? b]) async {
        await _set(t, c, text, a, b);
        await t.tap(_headingButton);
        await t.pumpAndSettle();
        final items = t.widgetList<CheckedPopupMenuItem<int>>(
          find.byType(CheckedPopupMenuItem<int>),
        );
        final out = {
          for (final i in items) (i.child! as Text).data!: i.checked,
        };
        await t.tapAt(const Offset(5, 5)); // dismiss
        await t.pumpAndSettle();
        return out;
      }

      final h4 = await menu('#### x', 5);
      expect(h4['H4'], isTrue);
      expect(h4['Body text'] ?? h4['본문'], isFalse);
      expect(h4.keys.where((k) => k.startsWith('H')).length, 6);
      expect(h4.values.where((v) => v).length, 1);

      final body = await menu('x', 1);
      expect(body.values.where((v) => v).length, 1);
      expect(body['Body text'] ?? body['본문'], isTrue);

      final mixed = await menu('# a\nb', 0, 5);
      expect(mixed.values.where((v) => v), isEmpty);
    });

    testWidgets('picking the same level again clears the heading', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, 'hello', 5);
      Future<void> pick(String label) async {
        await t.tap(_headingButton);
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(CheckedPopupMenuItem<int>, label));
        await t.pumpAndSettle();
      }

      await pick('H2');
      expect(c.text, '## hello');
      await pick('H2');
      expect(c.text, 'hello');
    });
  });

  group('toolbar buttons', () {
    testWidgets('strikethrough and numbered list buttons', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, 'a\nb', 0, 3);
      await t.tap(find.byIcon(AppIcons.orderedList));
      await t.pump();
      expect(c.text, '1. a\n2. b');
      await _set(t, c, 'word', 0, 4);
      await t.tap(find.byIcon(AppIcons.strikethrough));
      await t.pump();
      expect(c.text, '~~word~~');
    });

    testWidgets('code button fences a multi-line selection', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, 'a\nb', 0, 3);
      await t.tap(find.byIcon(AppIcons.code).first); // toolbar, not the bar
      await t.pump();
      expect(c.text, '```\na\nb\n```');
    });
  });

  group('mini bar headings', () {
    testWidgets('H1-H3 appear, current one is marked, again clears', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, 'hello', 0, 5);
      expect(_bar, findsOneWidget);
      // the four icon buttons are unchanged
      expect(
        find.descendant(of: _bar, matching: find.byType(IconButton)),
        findsNWidgets(4),
      );
      for (final n in [1, 2, 3]) {
        expect(find.byKey(ValueKey('mini-h$n')), findsOneWidget);
      }
      BoxDecoration deco(int n) =>
          t.widget<Container>(find.byKey(ValueKey('mini-h$n'))).decoration!
              as BoxDecoration;
      expect(deco(2).color, isNull);
      await t.tap(find.byKey(const ValueKey('mini-h2')));
      await t.pump();
      await t.pump();
      expect(c.text, '## hello');
      expect(deco(2).color, isNotNull);
      expect(deco(1).color, isNull);
      await t.tap(find.byKey(const ValueKey('mini-h2')));
      await t.pump();
      await t.pump();
      expect(c.text, 'hello');
      expect(deco(2).color, isNull);
    });
  });

  group('link popover (view): open', () {
    const link = 'see [docs](https://example.com/a_(b)) now';
    final inside = link.indexOf('docs') + 1;

    testWidgets('caret in a link shows the popover; tap opens the URL', (
      t,
    ) async {
      final (c, opened) = await _pump(t);
      await _set(t, c, link, inside);
      expect(_chip, findsOneWidget);
      // sits over the link line, inside the text area
      final body = t.getRect(find.byType(TextField).last);
      expect(body.contains(t.getCenter(_chipButton)), isTrue);
      await t.tap(_chipButton);
      await t.pump();
      expect(opened, [Uri.parse('https://example.com/a_(b)')]);
      // focus stays in the body
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('a real mouse click on the chip opens it (tap region)', (
      t,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final (c, opened) = await _pump(t);
        await _set(t, c, link, inside);
        final g = await t.startGesture(
          t.getCenter(_chipButton),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        );
        await t.pump(const Duration(milliseconds: 40));
        await t.pump(const Duration(milliseconds: 40));
        await g.up();
        await t.pump();
        expect(opened, [Uri.parse('https://example.com/a_(b)')]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('caret outside the link: no chip', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, link, 1);
      expect(_chip, findsNothing);
      await _set(t, c, link, link.length);
      expect(_chip, findsNothing);
    });

    testWidgets('bare URL and mailto get the chip', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, 'go https://example.com now', 8);
      expect(_chip, findsOneWidget);
      await _set(t, c, '<mailto:a@b.co> x', 3);
      expect(_chip, findsNothing); // only <http(s)> autolinks are recognised
      await _set(t, c, '[mail](mailto:a@b.co)', 3);
      expect(_chip, findsOneWidget);
    });

    testWidgets('unsafe and relative targets: shown, open disabled + warning', (
      t,
    ) async {
      final (c, opened) = await _pump(t);
      for (final src in [
        '[x](javascript:alert(1))',
        '[x](JAVASCRIPT:alert(1))',
        '[x](data:text/html;base64,AAAA)',
        '[x](file:///etc/passwd)',
        '[x](/relative)',
        '[x](page.html)',
        '[x](www.example.com)',
        '[x]()',
      ]) {
        await _set(t, c, src, 2);
        expect(_chip, findsOneWidget, reason: src);
        expect(find.byKey(const ValueKey('link-unsafe')), findsOneWidget);
        expect(
          t.widget<IconButton>(_chipButton).onPressed,
          isNull,
          reason: src,
        );
        // the other three buttons stay usable
        expect(
          t
              .widget<IconButton>(find.byKey(const ValueKey('link-edit')))
              .onPressed,
          isNotNull,
        );
        await t.tap(_chipButton, warnIfMissed: false);
        await t.pump();
      }
      expect(opened, isEmpty);
    });

    testWidgets('hidden while composing', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, link, inside);
      expect(_chip, findsOneWidget);
      await _set(
        t,
        c,
        link,
        inside,
        inside,
        TextRange(start: inside - 1, end: inside + 1),
      );
      expect(_chip, findsNothing);
      expect(c.text, link); // untouched
      await _set(t, c, link, inside);
      expect(_chip, findsOneWidget);
    });

    testWidgets('a selection inside the link: mini bar wins, no chip', (
      t,
    ) async {
      final (c, _) = await _pump(t);
      await _set(t, c, link, inside, inside + 3);
      expect(_bar, findsOneWidget);
      expect(_chip, findsNothing);
      await _set(t, c, link, inside + 3);
      expect(_bar, findsNothing);
      expect(_chip, findsOneWidget);
    });

    testWidgets('not inside a code fence; Esc closes the chip', (t) async {
      final (c, _) = await _pump(t);
      await _set(t, c, '```\n[x](https://example.com)\n```', 8);
      expect(_chip, findsNothing);
      await _set(t, c, link, inside);
      expect(_chip, findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump();
      expect(_chip, findsNothing);
      expect(c.text, link);
    });

    testWidgets('failed open shows a snackbar', (t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildPbTheme(
            Brightness.light,
          ).copyWith(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: NoteEditorView(
              embedded: true,
              onClose: () {},
              openLink: (_) async => false,
            ),
          ),
        ),
      );
      await t.tap(find.byType(TextField).last);
      await t.pump();
      final c = t
          .widget<EditableText>(find.byType(EditableText).last)
          .controller;
      await _set(t, c, link, inside);
      await t.tap(_chipButton);
      await t.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Enter through the text field', () {
    testWidgets('continues a bullet, then ends the list on an empty item', (
      t,
    ) async {
      final (c, _) = await _pump(t);
      await t.enterText(find.byType(TextField).last, '- one');
      await t.pump();
      // the engine delivers the newline as an edit
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- one\n',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await t.pump();
      expect(c.text, '- one\n- ');
      expect(c.selection, const TextSelection.collapsed(offset: 8));
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- one\n- \n',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      await t.pump();
      expect(c.text, '- one\n');
      expect(c.selection, const TextSelection.collapsed(offset: 6));
    });

    testWidgets('does not touch a composing Hangul edit', (t) async {
      final (c, _) = await _pump(t);
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- 안녕',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 3, end: 4),
        ),
      );
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- 안녕\n',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 3, end: 4),
        ),
      );
      await t.pump();
      expect(c.text, '- 안녕\n');
    });

    testWidgets('typing normal characters is untouched', (t) async {
      final (c, _) = await _pump(t);
      await t.enterText(find.byType(TextField).last, '- ');
      await t.pump();
      await t.enterText(find.byType(TextField).last, '- a');
      await t.pump();
      expect(c.text, '- a');
    });
  });
}
