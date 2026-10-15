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

/// Research 024 stage 3: the link popover (view, edit, remove), unsafe
/// targets, the mini bar's link button, focus and tap-region rules.
final _view = find.byType(LinkPopover);
final _edit = find.byType(LinkEditPopover);
final _bar = find.byType(SelectionMiniBar);
final _textField = find.byKey(const ValueKey('link-text-field'));
final _urlField = find.byKey(const ValueKey('link-url-field'));

const _link = 'see [docs](https://example.com/a) now';
final _inside = _link.indexOf('docs') + 1;
final _linkEnd = _link.indexOf(' now');

class _Env {
  _Env(this.c, this.opened, this.clip, this.setClip);
  final LiveMarkdownController c;
  final List<Uri> opened;

  /// What the app wrote to the clipboard.
  final List<String> clip;

  /// What `Clipboard.getData` returns next (null: refuse with an error).
  final void Function(String? text) setClip;
}

Future<_Env> _pump(
  WidgetTester t, {
  Size size = const Size(1200, 900),
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final opened = <Uri>[];
  final written = <String>[];
  String? readable = '';
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          written.add((call.arguments as Map)['text'] as String);
        case 'Clipboard.getData':
          if (readable == null) {
            throw PlatformException(code: 'denied', message: 'no permission');
          }
          return <String, dynamic>{'text': readable};
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
  await t.pumpWidget(
    MaterialApp(
      theme: buildPbTheme(Brightness.light).copyWith(platform: platform),
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
  return _Env(c, opened, written, (s) => readable = s);
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
  // the undo history merges edits that come within 500 ms
  await t.pump(const Duration(seconds: 1));
}

// the body is the second EditableText (title first); popover fields follow
Finder get _body => find.byType(EditableText).at(1);

bool _bodyFocused(WidgetTester t) =>
    t.widget<EditableText>(_body).focusNode.hasFocus;

bool _fieldFocused(WidgetTester t, Finder f) => t
    .widget<EditableText>(
      find.descendant(of: f, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

String _fieldText(WidgetTester t, Finder f) => t
    .widget<EditableText>(
      find.descendant(of: f, matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<void> _tapKey(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await t.pump();
  await t.pump();
}

Future<void> _mouseClick(WidgetTester t, Offset at) async {
  final g = await t.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  await t.pump(const Duration(milliseconds: 40));
  await t.pump(const Duration(milliseconds: 40));
  await g.up();
  await t.pump();
  await t.pump();
}

/// Applies the edit popover with Enter in the address field.
Future<void> _enter(WidgetTester t) async {
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
  await t.pump();
}

Future<void> _undo(WidgetTester t) async {
  await t.pump(const Duration(seconds: 1));
  await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await t.pump();
  await t.pump();
}

void _desktopTest(
  String name,
  Future<void> Function(WidgetTester t, _Env e) body,
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

Rect _popoverRect(WidgetTester t, Finder popover) => t.getRect(
  find.descendant(of: popover, matching: find.byType(Material)).first,
);

/// Global rectangle of the link's line in the body.
Rect _linkRect(WidgetTester t, int a, int b) {
  final r = t.state<EditableTextState>(_body).renderEditable;
  var rect = r
      .getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: b))
      .first
      .toRect();
  rect = rect.shift(r.localToGlobal(Offset.zero));
  return rect;
}

void main() {
  group('view popover', () {
    testWidgets('sits just below the link, inside the text area', (t) async {
      final e = await _pump(t);
      await _set(t, e.c, _link, _inside);
      expect(_view, findsOneWidget);
      final link = _linkRect(t, 4, _linkEnd);
      final pop = _popoverRect(t, _view);
      expect(pop.top, greaterThanOrEqualTo(link.bottom));
      expect(pop.top - link.bottom, lessThan(16));
      final body = t.getRect(find.byType(TextField).last);
      expect(body.contains(pop.center), isTrue);
      expect(pop.left, greaterThanOrEqualTo(body.left));
      expect(pop.right, lessThanOrEqualTo(body.right));
      expect(find.byKey(const ValueKey('link-url')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('link-url'))).data,
        'https://example.com/a',
      );
    });

    testWidgets('no room below: above; and clamped to the right edge', (
      t,
    ) async {
      final e = await _pump(t, size: const Size(700, 330));
      final text = '${'x\n' * 6}${' ' * 60}[docs](https://example.com/a)';
      await _set(t, e.c, text, text.length - 12);
      expect(_view, findsOneWidget);
      final link = _linkRect(t, text.indexOf('[docs'), text.length);
      final pop = _popoverRect(t, _view);
      expect(pop.bottom, lessThanOrEqualTo(link.top + 0.5));
      final body = t.getRect(find.byType(TextField).last);
      expect(pop.right, lessThanOrEqualTo(body.right + 0.5));
      expect(pop.left, greaterThanOrEqualTo(body.left - 0.5));
    });

    testWidgets('shows when the caret moves in with the arrow keys', (
      t,
    ) async {
      final e = await _pump(t);
      await _set(t, e.c, _link, 4); // just before "[docs]"
      expect(_view, findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      await t.pump();
      expect(e.c.selection.baseOffset, 5);
      expect(_view, findsOneWidget);
      // and leaves again at the end of the link
      await _set(t, e.c, _link, _linkEnd);
      expect(_view, findsNothing);
    });

    _desktopTest('a mouse click on the link opens it; focus stays', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, 0);
      expect(_view, findsNothing);
      await _mouseClick(t, _linkRect(t, 5, 9).center);
      expect(e.c.selection.isCollapsed, isTrue);
      expect(_view, findsOneWidget);
      expect(_bodyFocused(t), isTrue);
    });

    _desktopTest('not with a selection, composing, in code, or after Esc', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside, _inside + 2);
      expect(_view, findsNothing);
      expect(_bar, findsOneWidget);
      await _set(t, e.c, _link, _inside);
      expect(_view, findsOneWidget);
      await _set(
        t,
        e.c,
        _link,
        _inside,
        _inside,
        TextRange(start: _inside - 1, end: _inside + 1),
      );
      expect(_view, findsNothing);
      await _set(t, e.c, '```\n[x](https://example.com)\n```', 8);
      expect(_view, findsNothing);
      await _set(t, e.c, _link, _inside);
      expect(_view, findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump();
      expect(_view, findsNothing);
      expect(e.c.text, _link);
    });

    _desktopTest('open and copy buttons: a real mouse click works', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _mouseClick(
        t,
        t.getCenter(find.byKey(const ValueKey('link-open'))),
      );
      expect(e.opened, [Uri.parse('https://example.com/a')]);
      expect(_bodyFocused(t), isTrue);
      expect(_view, findsOneWidget); // a press inside is not "outside"
      await _mouseClick(
        t,
        t.getCenter(find.byKey(const ValueKey('link-copy'))),
      );
      expect(e.clip, ['https://example.com/a']);
      final checked = find.descendant(
        of: _view,
        matching: find.byIcon(AppIcons.check),
      );
      expect(checked, findsOneWidget); // short feedback
      await t.pump(const Duration(seconds: 2));
      expect(checked, findsNothing);
      expect(_bodyFocused(t), isTrue);
    });

    testWidgets('unsafe link: shown, warning, open disabled, others work', (
      t,
    ) async {
      final e = await _pump(t);
      await _set(t, e.c, '[x](javascript:alert(1))', 2);
      expect(_view, findsOneWidget);
      expect(find.byKey(const ValueKey('link-unsafe')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('link-unsafe'))).data,
        "This link isn't safe, so it won't open.",
      );
      expect(
        t.widget<IconButton>(find.byKey(const ValueKey('link-open'))).onPressed,
        isNull,
      );
      await _tapKey(t, 'link-copy');
      expect(e.clip, ['javascript:alert(1)']);
      expect(e.opened, isEmpty);
      // a safe one has no warning
      await _set(t, e.c, _link, _inside);
      expect(find.byKey(const ValueKey('link-unsafe')), findsNothing);
    });

    testWidgets('a bare URL cannot be removed (no markers), it can be edited', (
      t,
    ) async {
      final e = await _pump(t);
      await _set(t, e.c, 'go https://example.com now', 8);
      expect(
        t
            .widget<IconButton>(find.byKey(const ValueKey('link-remove')))
            .onPressed,
        isNull,
      );
      expect(
        t.widget<IconButton>(find.byKey(const ValueKey('link-edit'))).onPressed,
        isNotNull,
      );
    });
  });

  group('edit mode', () {
    _desktopTest('edit shows both inputs; body selection is kept', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      final sel = e.c.selection;
      await _tapKey(t, 'link-edit');
      expect(_edit, findsOneWidget);
      expect(_view, findsNothing);
      expect(_fieldText(t, _textField), 'docs');
      expect(_fieldText(t, _urlField), 'https://example.com/a');
      expect(_fieldFocused(t, _urlField), isTrue);
      expect(_bodyFocused(t), isFalse);
      expect(e.c.selection, sel); // caret did not move
      expect(e.c.text, _link);
      // stays open across frames (nothing closes it by itself)
      await t.pump(const Duration(milliseconds: 300));
      expect(_edit, findsOneWidget);
    });

    _desktopTest('Enter applies: [text](url) replaces the link, one undo', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await t.enterText(_textField, 'Docs page');
      await t.enterText(_urlField, 'https://new.example/b');
      await _enter(t);
      expect(e.c.text, 'see [Docs page](https://new.example/b) now');
      expect(_edit, findsNothing);
      expect(_bodyFocused(t), isTrue);
      // caret behind the link: no popover comes straight back
      expect(e.c.selection.isCollapsed, isTrue);
      expect(_view, findsNothing);
      await _undo(t);
      expect(e.c.text, _link);
    });

    _desktopTest('Esc cancels: nothing changes, body focused, no popover', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await t.enterText(_urlField, 'https://changed.example');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump();
      expect(e.c.text, _link);
      expect(_edit, findsNothing);
      expect(_view, findsNothing);
      expect(_bodyFocused(t), isTrue);
      // moving the caret brings the popover back
      await _set(t, e.c, _link, _inside + 1);
      expect(_view, findsOneWidget);
    });

    _desktopTest('Cancel and Apply buttons', (t, e) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await _tapKey(t, 'link-cancel');
      expect(e.c.text, _link);
      expect(_edit, findsNothing);
      await _set(t, e.c, _link, _inside + 1);
      await _tapKey(t, 'link-edit');
      await t.enterText(_urlField, 'https://b.example');
      await t.pump();
      await _tapKey(t, 'link-apply');
      expect(e.c.text, 'see [docs](https://b.example) now');
    });

    _desktopTest('an empty address is not applied', (t, e) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await t.enterText(_urlField, '  ');
      await t.pump();
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('link-apply')))
            .onPressed,
        isNull,
      );
      await _enter(t);
      expect(_edit, findsOneWidget);
      expect(e.c.text, _link);
    });

    _desktopTest('autolink: editing promotes it to [text](url)', (t, e) async {
      const t0 = 'go https://example.com now';
      await _set(t, e.c, t0, 8);
      await _tapKey(t, 'link-edit');
      expect(_fieldText(t, _textField), 'https://example.com');
      await t.enterText(_textField, 'Example');
      await _enter(t);
      expect(e.c.text, 'go [Example](https://example.com) now');
    });

    _desktopTest('a title is kept when the address is not changed', (
      t,
      e,
    ) async {
      const t0 = 'a [t](https://a.co "Title") b';
      await _set(t, e.c, t0, 5);
      await _tapKey(t, 'link-edit');
      await t.enterText(_textField, 'new');
      await _enter(t);
      expect(e.c.text, 'a [new](https://a.co "Title") b');
    });

    _desktopTest('remove: markers go, text and caret stay; one undo', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside + 1); // after "do"
      await _tapKey(t, 'link-remove');
      expect(e.c.text, 'see docs now');
      expect(e.c.selection, TextSelection.collapsed(offset: _inside));
      expect(_view, findsNothing);
      expect(_bodyFocused(t), isTrue);
      await _undo(t);
      expect(e.c.text, _link);
    });

    _desktopTest('Hangul input in both fields (composition stays open)', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await t.tap(_textField);
      await t.pump();
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '문서',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      await t.pump();
      expect(_edit, findsOneWidget);
      expect(_fieldText(t, _textField), '문서');
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '문서',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await t.pump();
      await t.enterText(_urlField, 'https://example.com/한글');
      await _enter(t);
      expect(e.c.text, 'see [문서](https://example.com/한글) now');
    });

    _desktopTest('a real mouse press in the inputs does not close it', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await _mouseClick(t, t.getCenter(_textField));
      expect(_edit, findsOneWidget);
      expect(_fieldFocused(t, _textField), isTrue);
      await _mouseClick(t, t.getCenter(_urlField));
      expect(_edit, findsOneWidget);
      expect(_fieldFocused(t, _urlField), isTrue);
      expect(e.c.selection, TextSelection.collapsed(offset: _inside));
    });

    _desktopTest('the text moving on drops the edit, nothing is applied', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      expect(_edit, findsOneWidget);
      e.c.value = TextEditingValue(
        text: 'other $_link',
        selection: const TextSelection.collapsed(offset: 0),
      );
      await t.pump();
      await t.pump();
      await t.pump();
      expect(_edit, findsNothing);
      expect(e.c.text, 'other $_link');
    });

    _desktopTest('focus going elsewhere (the title) closes it unchanged', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      await _mouseClick(t, t.getCenter(find.byType(TextField).first));
      expect(_edit, findsNothing);
      expect(e.c.text, _link);
      expect(_bodyFocused(t), isFalse); // it went where the user clicked
    });
  });

  group('link button (mini bar and toolbar)', () {
    _desktopTest('selected text: edit popover, text filled, URL waits', (
      t,
      e,
    ) async {
      e.setClip(null); // not readable: ignored, nothing filled
      await _set(t, e.c, 'hello world', 6, 11);
      expect(_bar, findsOneWidget);
      await _mouseClick(
        t,
        t.getCenter(
          find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
        ),
      );
      expect(e.c.text, 'hello world'); // no instant toggle
      expect(_edit, findsOneWidget);
      expect(_fieldText(t, _textField), 'world');
      expect(_fieldText(t, _urlField), '');
      expect(_fieldFocused(t, _urlField), isTrue);
      expect(
        e.c.selection,
        const TextSelection(baseOffset: 6, extentOffset: 11),
      );
      await t.enterText(_urlField, 'https://a.co');
      await _enter(t);
      expect(e.c.text, 'hello [world](https://a.co)');
      expect(_bodyFocused(t), isTrue);
    });

    _desktopTest('an http(s) URL on the clipboard fills the address', (
      t,
      e,
    ) async {
      e.setClip('  https://example.com/x?y=1 ');
      await _set(t, e.c, 'hello world', 6, 11);
      await _mouseClick(
        t,
        t.getCenter(
          find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
        ),
      );
      await t.pump();
      await t.pump();
      expect(_fieldText(t, _urlField), 'https://example.com/x?y=1');
      // selected, so typing replaces it; Enter confirms as is
      final ctl = t
          .widget<EditableText>(
            find.descendant(of: _urlField, matching: find.byType(EditableText)),
          )
          .controller;
      expect(ctl.selection.start, 0);
      expect(ctl.selection.end, ctl.text.length);
      await _enter(t);
      expect(e.c.text, 'hello [world](https://example.com/x?y=1)');
    });

    _desktopTest('other clipboard text is not used', (t, e) async {
      e.setClip('just some words');
      await _set(t, e.c, 'hello world', 6, 11);
      await _mouseClick(
        t,
        t.getCenter(
          find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
        ),
      );
      await t.pump();
      expect(_fieldText(t, _urlField), '');
      await _enter(t); // empty address: nothing is applied
      expect(e.c.text, 'hello world');
      expect(_edit, findsOneWidget);
    });

    _desktopTest('Esc on a new link leaves text and selection alone', (
      t,
      e,
    ) async {
      await _set(t, e.c, 'hello world', 6, 11);
      await _mouseClick(
        t,
        t.getCenter(
          find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump();
      await t.pump();
      expect(_edit, findsNothing);
      expect(e.c.text, 'hello world');
      expect(
        e.c.selection,
        const TextSelection(baseOffset: 6, extentOffset: 11),
      );
      expect(_bodyFocused(t), isTrue);
      expect(_bar, findsOneWidget); // the bar comes back
    });

    _desktopTest('on a link: the view popover opens next to the bar', (
      t,
      e,
    ) async {
      await _set(t, e.c, _link, _inside, _inside + 2);
      expect(_bar, findsOneWidget);
      expect(_view, findsNothing);
      final linkBtn = find.descendant(
        of: _bar,
        matching: find.byIcon(AppIcons.link),
      );
      // the button shows the link state
      expect(
        t
            .widget<IconButton>(
              find.ancestor(of: linkBtn, matching: find.byType(IconButton)),
            )
            .isSelected,
        isTrue,
      );
      await _mouseClick(t, t.getCenter(linkBtn));
      expect(e.c.text, _link); // not removed
      expect(_view, findsOneWidget);
      expect(_edit, findsNothing);
      expect(_bar, findsOneWidget);
      // moving the selection drops it
      await _set(t, e.c, _link, 0, 3);
      expect(_view, findsNothing);
    });

    _desktopTest('toolbar with a caret: edit with empty text inserts a link', (
      t,
      e,
    ) async {
      e.setClip('');
      await _set(t, e.c, 'a b', 2);
      await t.tap(find.byIcon(AppIcons.link).first);
      await t.pump();
      await t.pump();
      expect(_edit, findsOneWidget);
      expect(_fieldText(t, _textField), '');
      await t.enterText(_textField, 'site');
      await t.enterText(_urlField, 'https://s.example');
      await _enter(t);
      expect(e.c.text, 'a [site](https://s.example)b');
      await _undo(t);
      expect(e.c.text, 'a b');
    });

    _desktopTest('several lines keep the old per-line wrapping', (t, e) async {
      await _set(t, e.c, '- a\n- b', 0, 7);
      await _mouseClick(
        t,
        t.getCenter(
          find.descendant(of: _bar, matching: find.byIcon(AppIcons.link)),
        ),
      );
      expect(e.c.text, '- [a]()\n- [b]()');
      expect(_edit, findsNothing);
    });

    _desktopTest('not while composing', (t, e) async {
      await _set(t, e.c, 'hello world', 6, 11);
      e.c.value = e.c.value.copyWith(
        composing: const TextRange(start: 6, end: 11),
      );
      await t.pump();
      await t.tap(find.byIcon(AppIcons.link).first); // toolbar
      await t.pump();
      expect(_edit, findsNothing);
      expect(e.c.text, 'hello world');
    });
  });

  group('accessibility', () {
    testWidgets('popover has a label; buttons have tooltips', (t) async {
      final handle = t.ensureSemantics();
      final e = await _pump(t);
      await _set(t, e.c, _link, _inside);
      expect(find.semantics.byLabel(RegExp('Link')), findsWidgets);
      for (final tip in ['Open', 'Copy link', 'Edit link', 'Remove link']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
      handle.dispose();
    });

    testWidgets('Tab moves through the edit fields and buttons', (t) async {
      final e = await _pump(t);
      await _set(t, e.c, _link, _inside);
      await _tapKey(t, 'link-edit');
      expect(_fieldFocused(t, _urlField), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      // from the address field on to the buttons, still inside the popover
      expect(_edit, findsOneWidget);
      expect(_fieldFocused(t, _urlField), isFalse);
    });
  });
}
