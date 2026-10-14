import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

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

ThemeData _buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C4CF5),
    brightness: brightness,
  ),
);

class PageBlinkApp extends StatelessWidget {
  const PageBlinkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PageBlink',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      AskScreen(projects: _projects),
      DocumentsScreen(projects: _projects),
      ProjectsScreen(projects: _projects, onChanged: _loadProjects),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ PageBlink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => client.auth.signOutDevice(),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: '질문',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            label: '문서',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: '프로젝트',
          ),
        ],
      ),
    );
  }
}
