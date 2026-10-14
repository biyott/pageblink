import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'app/theme.dart';
import 'client.dart';
import 'features/ask/ask_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/projects/projects_screen.dart';
import 'screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeClient();
  runApp(const PageBlinkApp());
}

class PageBlinkApp extends StatelessWidget {
  const PageBlinkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PageBlink',
    debugShowCheckedModeBanner: false,
    theme: buildPbTheme(Brightness.light),
    darkTheme: buildPbTheme(Brightness.dark),
    builder: (context, child) => PbBackground(child: child!),
    home: const SignInScreen(child: HomeShell()),
  );
}

/// Ask · Documents · Projects.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  List<Project> _projects = const [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await client.project.list();
      if (mounted) setState(() => _projects = projects);
    } catch (_) {
      // Shown as an empty project list; the documents tab surfaces errors.
    }
  }

  static const _destinations = [
    (icon: Icons.bolt_outlined, selected: Icons.bolt, label: '질문'),
    (
      icon: Icons.sticky_note_2_outlined,
      selected: Icons.sticky_note_2,
      label: '노트',
    ),
    (icon: Icons.groups_outlined, selected: Icons.groups, label: '프로젝트'),
  ];

  @override
  Widget build(BuildContext context) {
    final ask = AskScreen(projects: _projects);
    final notes = DocumentsScreen(projects: _projects);
    final projects = ProjectsScreen(
      projects: _projects,
      onChanged: _loadProjects,
    );
    final appBar = AppBar(
      title: const Text('⚡ PageBlink'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: '로그아웃',
          onPressed: () => client.auth.signOutDevice(),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Phone: bottom navigation, one screen at a time.
        if (width < 600) {
          return Scaffold(
            appBar: appBar,
            body: IndexedStack(index: _tab, children: [ask, notes, projects]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        // Desktop: notes/projects in the middle, Ask always open on the right.
        final desktop = width >= 1024;
        final railItems = desktop ? _destinations.sublist(1) : _destinations;
        final railIndex = desktop ? (_tab == 0 ? 0 : _tab - 1) : _tab;
        final center = desktop
            ? (railIndex == 0 ? notes : projects)
            : IndexedStack(index: _tab, children: [ask, notes, projects]);

        return Scaffold(
          appBar: appBar,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                GlassPanel(
                  child: NavigationRail(
                    selectedIndex: railIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) =>
                        setState(() => _tab = desktop ? i + 1 : i),
                    destinations: [
                      for (final d in railItems)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: center),
                if (desktop) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: width >= 1400 ? 420 : 380,
                    child: GlassPanel(child: ask),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
