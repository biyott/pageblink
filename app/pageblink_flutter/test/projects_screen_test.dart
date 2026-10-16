import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/app_icons.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';
import 'package:pageblink_flutter/features/projects/projects_load.dart';
import 'package:pageblink_flutter/features/projects/projects_screen.dart';

final _me = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
final _other = UuidValue.fromString('00000000-0000-4000-8000-000000000002');

Project _project(int id, {UuidValue? owner, String? name}) => Project(
  id: id,
  name: name ?? 'Project $id',
  ownerId: owner ?? _me,
  createdAt: DateTime.utc(2026, 10, 16),
);

Document _doc(int id, int? projectId, {String kind = 'note'}) => Document(
  id: id,
  ownerId: _me,
  projectId: projectId,
  kind: kind,
  title: 'd$id',
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
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    projectsUserIdCall = () => _me;
    // The const instance = "the board has not been read".
    documentsNotifier.value = const [];
  });
  tearDown(() {
    projectsUserIdCall = null;
    documentsNotifier.value = const [];
  });

  Future<void> pump(
    WidgetTester t,
    Size size, {
    List<Project> projects = const [],
    ProjectsLoad status = ProjectsLoad.loaded,
    Future<void> Function()? onChanged,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    String lang = 'en',
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(brightness),
        locale: Locale(lang),
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: PbBackground(child: child!),
        ),
        home: ProjectsScreen(
          projects: projects,
          status: status,
          onChanged: onChanged ?? () async {},
        ),
      ),
    );
    // Not pumpAndSettle: the loading skeleton pulses forever.
    await t.pump(const Duration(milliseconds: 100));
  }

  const phone = Size(360, 780);
  const tablet = Size(600, 800);
  const desktop = Size(1440, 900);

  final cards = find.byType(Card);
  final invite = find.widgetWithText(TextButton, 'Invite');
  final fab = find.byType(FloatingActionButton);
  final newProject = find.widgetWithText(FilledButton, 'New project');

  group('cards', () {
    testWidgets('owner sees the menu and Invite, a member sees neither', (
      t,
    ) async {
      await pump(
        t,
        desktop,
        projects: [
          _project(1),
          _project(2, owner: _other),
        ],
      );
      expect(cards, findsNWidgets(2));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(invite, findsOneWidget);
      expect(find.byIcon(AppIcons.more), findsOneWidget);
      expect(
        find.descendant(of: cards.last, matching: find.byIcon(AppIcons.more)),
        findsNothing,
      );
      expect(
        find.descendant(of: cards.last, matching: invite),
        findsNothing,
      );
    });

    testWidgets('signed out: nobody owns anything', (t) async {
      projectsUserIdCall = () => null;
      await pump(t, desktop, projects: [_project(1)]);
      expect(invite, findsNothing);
      expect(find.byIcon(AppIcons.more), findsNothing);
    });

    testWidgets('the menu offers rename and delete', (t) async {
      await pump(t, desktop, projects: [_project(1)]);
      await t.tap(find.byIcon(AppIcons.more));
      await t.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('a failed invite shows no exception text', (t) async {
      // The test has no server client: the call throws a LateInitializationError.
      await pump(t, desktop, projects: [_project(1)]);
      await t.tap(invite);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'a@b.co');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'OK'));
      await t.pumpAndSettle();
      expect(
        find.text(L.en.inviteFailed(L.en.projectsLoadFailedHint)),
        findsOneWidget,
      );
      expect(find.textContaining('Late'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  group('header and counts', () {
    testWidgets('summary and per-card counts come from the board', (t) async {
      documentsNotifier.value = [
        _doc(1, 1),
        _doc(2, 1),
        _doc(3, 1, kind: 'pdf'),
        _doc(4, 2),
        _doc(5, null), // personal: not in any project
        _doc(6, 99), // a project that is not listed
      ];
      await pump(t, desktop, projects: [_project(1), _project(2)]);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('2 projects · 3 notes, 1 PDFs'), findsOneWidget);
      expect(find.text('2 notes · 1 PDFs'), findsOneWidget);
      expect(find.text('1 notes · 0 PDFs'), findsOneWidget);
    });

    testWidgets('an empty board that was read counts zero', (t) async {
      documentsNotifier.value = <Document>[];
      await pump(t, desktop, projects: [_project(1)]);
      expect(find.text('1 projects · 0 notes, 0 PDFs'), findsOneWidget);
      expect(find.text('0 notes · 0 PDFs'), findsOneWidget);
    });

    testWidgets('nothing is counted before the board is read', (t) async {
      await pump(t, desktop, projects: [_project(1)]);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.textContaining('notes'), findsNothing);
      expect(find.textContaining('PDFs'), findsNothing);
      // The cards are there.
      expect(cards, findsOneWidget);
      expect(find.text('Project 1'), findsOneWidget);
    });

    testWidgets('the counts follow the board', (t) async {
      await pump(t, desktop, projects: [_project(1)]);
      documentsNotifier.value = [_doc(1, 1)];
      await t.pump();
      expect(find.text('1 notes · 0 PDFs'), findsOneWidget);
    });

    testWidgets('Korean', (t) async {
      documentsNotifier.value = [_doc(1, 1)];
      await pump(t, desktop, projects: [_project(1)], lang: 'ko');
      expect(find.text('프로젝트 1개 · 노트 1개, PDF 0개'), findsOneWidget);
      expect(find.text('노트 1개 · PDF 0개'), findsOneWidget);
      expect(find.text('소유자'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading: two skeleton cards, no actions', (t) async {
      await pump(t, phone, status: ProjectsLoad.loading);
      expect(find.byKey(const Key('projects-skeleton')), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(fab, findsNothing);
      expect(find.text(L.en.projectsEmptyTitle), findsNothing);
      expect(find.text(L.en.projectsLoadFailed), findsNothing);
      final skeletons = find.byKey(const Key('projects-skeleton-card'));
      expect(skeletons, findsNWidgets(2));
    });

    testWidgets('empty: icon, title, body and a New project button', (
      t,
    ) async {
      await pump(t, phone);
      expect(find.text(L.en.projectsEmptyTitle), findsOneWidget);
      expect(find.text(L.en.projectsEmpty), findsOneWidget);
      expect(find.byIcon(AppIcons.projects), findsOneWidget);
      expect(newProject, findsOneWidget);
      expect(fab, findsNothing);
    });

    testWidgets('error: message, hint, Retry runs the loader again', (
      t,
    ) async {
      var calls = 0;
      await pump(
        t,
        phone,
        status: ProjectsLoad.error,
        onChanged: () async => calls++,
      );
      expect(find.text(L.en.projectsLoadFailed), findsOneWidget);
      expect(find.text(L.en.projectsLoadFailedHint), findsOneWidget);
      expect(find.text(L.en.projectsEmptyTitle), findsNothing);
      await t.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await t.pump();
      expect(calls, 1);
    });

    testWidgets('error: Retry is disabled while it runs', (t) async {
      final gate = Future<void>.delayed(const Duration(seconds: 1));
      await pump(t, phone, status: ProjectsLoad.error, onChanged: () => gate);
      await t.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await t.pump();
      expect(find.text('Retrying…'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the list it already has', (t) async {
      await pump(
        t,
        desktop,
        projects: [_project(1)],
        status: ProjectsLoad.error,
      );
      expect(find.text('Project 1'), findsOneWidget);
      expect(find.text(L.en.projectsLoadFailed), findsNothing);
    });
  });

  group('new project button', () {
    testWidgets('phone: a FAB, no header button', (t) async {
      await pump(t, phone, projects: [_project(1)]);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.text('New project')),
        findsOneWidget,
      );
      expect(newProject, findsNothing);
    });

    testWidgets('wide: a 44 dp header button, no FAB', (t) async {
      await pump(t, tablet, projects: [_project(1)]);
      expect(fab, findsNothing);
      expect(newProject, findsOneWidget);
      expect(t.getSize(newProject).height, greaterThanOrEqualTo(44));
      // Top-right of the page.
      expect(t.getTopRight(newProject).dx, greaterThan(tablet.width - 40));
    });
  });

  group('grid', () {
    Future<int> columns(WidgetTester t, Size size) async {
      await pump(
        t,
        size,
        projects: [for (var i = 1; i <= 8; i++) _project(i)],
      );
      return {
        for (final c in cards.evaluate())
          t.getTopLeft(find.byWidget(c.widget)).dx,
      }.length;
    }

    testWidgets('360 / 600 / 1024 / 1440 columns', (t) async {
      expect(await columns(t, phone), 2);
      expect(await columns(t, tablet), 2);
      expect(await columns(t, const Size(1024, 800)), 4);
      expect(await columns(t, desktop), 5);
    });

    testWidgets('cards are 176 dp tall with 16 dp gaps', (t) async {
      await pump(t, desktop, projects: [_project(1), _project(2)]);
      expect(t.getSize(cards.first).height, 176);
      expect(
        t.getTopLeft(cards.last).dx - t.getTopRight(cards.first).dx,
        16,
      );
    });
  });

  group('text scale, size and theme', () {
    for (final size in [phone, tablet, const Size(1024, 800), desktop]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          '2x text at ${size.width.toInt()} ${brightness.name}: no overflow',
          (t) async {
            documentsNotifier.value = [_doc(1, 1), _doc(2, 1, kind: 'pdf')];
            await pump(
              t,
              size,
              projects: [
                _project(1, name: 'A project with a rather long name indeed'),
                _project(2, owner: _other),
              ],
              textScale: 2,
              brightness: brightness,
            );
            expect(t.takeException(), isNull);
            expect(cards, findsNWidgets(2));
          },
        );
      }
    }

    for (final status in [
      ProjectsLoad.loading,
      ProjectsLoad.loaded,
      ProjectsLoad.error,
    ]) {
      testWidgets('2x text, ${status.name} state: no overflow', (t) async {
        await pump(t, phone, status: status, textScale: 2);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('dark: the card keeps its paper surface', (t) async {
      await pump(
        t,
        desktop,
        projects: [_project(1)],
        brightness: Brightness.dark,
      );
      final dark = buildPbTheme(Brightness.dark).extension<Pb>()!;
      final card = t.widget<Card>(cards);
      expect(card.color, dark.pdfPaper);
      expect(t.takeException(), isNull);
    });
  });
}
