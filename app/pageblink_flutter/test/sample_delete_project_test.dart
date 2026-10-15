import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/confirm_dialog.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/text_wrap.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/ask/ask_suggestions.dart';
import 'package:pageblink_flutter/features/notes/note_editor_screen.dart';
import 'package:pageblink_flutter/features/projects/projects_screen.dart';

Document _doc(
  String title, {
  String kind = 'note',
  int? projectId,
  int id = 1,
}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  projectId: projectId,
  kind: kind,
  title: title,
  body: 'body',
  contentHash: 'h',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('ask suggestions', () {
    test('sample questions come first only while the sample exists', () {
      for (final l in [L.en, L.ko]) {
        expect(orderedSuggestions(l, ['Groceries']), l.askSuggestions);
        expect(orderedSuggestions(l, const []), l.askSuggestions);
        final sampleTitle = l.isKorean
            ? '샘플 · 할 일 목록'
            : 'Sample · My to-do list';
        expect(orderedSuggestions(l, ['Groceries', sampleTitle]), [
          ...l.sampleSuggestions,
          ...l.askSuggestions,
        ]);
      }
    });

    test('either language title counts; lookalikes do not', () {
      expect(isSampleTitle('Sample · My to-do list'), isTrue);
      expect(isSampleTitle('샘플 · 할 일 목록'), isTrue);
      expect(isSampleTitle('Sample notes'), isFalse);
      expect(isSampleTitle('My Sample · x'), isFalse);
    });

    test('only personal notes can be the sample', () {
      final titles = personalNoteTitles([
        _doc('Sample · mine'),
        _doc('Sample · in project', projectId: 3),
        _doc('Sample · pdf', kind: 'pdf'),
      ]);
      expect(titles, ['Sample · mine']);
    });

    test('sample question texts', () {
      expect(L.en.sampleSuggestions.first, 'What is left to do this week?');
      expect(L.ko.sampleSuggestions.last, '여권 갱신에 뭐가 필요해?');
      expect(L.en.sampleSuggestions, hasLength(4));
      expect(L.ko.sampleSuggestions, hasLength(4));
    });
  });

  group('projects', () {
    test('delete warning shows both counts', () {
      expect(
        L.ko.projectDeleteWarning(3, 2),
        keepAllKorean('노트 3개, PDF 2개가 함께 삭제됩니다. 되돌릴 수 없어요.'),
      );
      expect(
        L.en.projectDeleteWarning(1, 2),
        "1 note and 2 PDFs will be deleted with it. This can't be undone.",
      );
    });

    test('name rule: trimmed, 1..60 characters', () {
      expect(validProjectName('  Launch  '), 'Launch');
      expect(validProjectName('   '), isNull);
      expect(validProjectName(''), isNull);
      expect(validProjectName('a' * 60), 'a' * 60);
      expect(validProjectName('a' * 61), isNull);
    });
  });

  Widget app(Widget home) => MaterialApp(
    theme: buildPbTheme(Brightness.light),
    home: Scaffold(body: home),
  );

  group('confirmDestructive', () {
    Future<void> open(WidgetTester t, void Function(bool) onResult) async {
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await confirmDestructive(context, title: 'T?', message: 'M'),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
    }

    testWidgets('cancel returns false', (t) async {
      bool? result;
      await open(t, (v) => result = v);
      expect(find.text('T?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('delete returns true', (t) async {
      bool? result;
      await open(t, (v) => result = v);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('note editor delete', () {
    testWidgets('new note has no delete button', (t) async {
      await t.pumpWidget(
        app(NoteEditorView(embedded: true, onClose: () {})),
      );
      await t.pump();
      expect(find.byIcon(AppIcons.delete), findsNothing);
      expect(find.byIcon(AppIcons.more), findsNothing);
    });

    testWidgets(
      'cancel keeps the note open, confirm failure shows a snackbar',
      (
        t,
      ) async {
        var closed = 0;
        await t.pumpWidget(
          app(
            NoteEditorView(
              note: _doc('Hello'),
              embedded: true,
              onClose: () => closed++,
            ),
          ),
        );
        await t.pump();
        await t.tap(find.byIcon(AppIcons.more)); // header menu
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(PopupMenuItem<bool>, 'Delete'));
        await t.pumpAndSettle();
        expect(find.text('Delete this note?'), findsOneWidget);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        expect(closed, 0);
        expect(find.byType(SnackBar), findsNothing);

        // The test has no server client: the call fails, the note stays open.
        await t.tap(find.byIcon(AppIcons.more)); // header menu
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(PopupMenuItem<bool>, 'Delete'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Delete'));
        await t.pumpAndSettle();
        expect(closed, 0);
        expect(find.text(L.en.noteDeleteFailed), findsOneWidget);
      },
    );
  });
}
