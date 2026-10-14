import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'app/l10n.dart';
import 'app/locale_controller.dart';
import 'app/theme.dart';
import 'client.dart';
import 'features/ask/ask_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/projects/projects_screen.dart';
import 'features/settings/settings_screen.dart';
import 'screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeClient();
  await localeController.load();
  runApp(const PageBlinkApp());
}

class PageBlinkApp extends StatelessWidget {
  const PageBlinkApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale?>(
    valueListenable: localeController,
    builder: (context, chosen, _) => MaterialApp(
      locale: chosen,
      title: 'PageBlink',
      debugShowCheckedModeBanner: false,
      theme: buildPbTheme(Brightness.light),
      darkTheme: buildPbTheme(Brightness.dark),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // English by default; Korean if any of the device/browser locales is ko.
      localeResolutionCallback: (locale, supported) {
        final preferred = [
          ?locale,
          ...WidgetsBinding.instance.platformDispatcher.locales,
        ];
        return preferred.any((l) => l.languageCode == 'ko')
            ? const Locale('ko')
            : const Locale('en');
      },
      builder: (context, child) => PbBackground(child: child!),
      home: const SignInScreen(child: HomeShell()),
    ),
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

  List<({IconData icon, IconData selected, String label})> _destinations(
    L l,
  ) => [
    (icon: Icons.bolt_outlined, selected: Icons.bolt, label: l.tabAsk),
    (
      icon: Icons.sticky_note_2_outlined,
      selected: Icons.sticky_note_2,
      label: l.tabNotes,
    ),
    (
      icon: Icons.groups_outlined,
      selected: Icons.groups,
      label: l.tabProjects,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final destinations = _destinations(l);
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
          icon: const Icon(Icons.settings_outlined),
          tooltip: l.settings,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: l.signOut,
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
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        // Desktop: custom sidebar | board | Ask (fixed 380), 24 gaps.
        final desktop = width >= 1024;
        if (desktop) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 240,
                      child: _Sidebar(
                        selected: _tab == 2 ? 2 : 1,
                        projects: _projects,
                        onSelect: (i) => setState(() => _tab = i),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: _tab == 2 ? projects : notes,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(width: 380, child: GlassPanel(child: ask)),
                  ],
                ),
              ),
            ),
          );
        }

        // Tablet: rail + one screen at a time.
        return Scaffold(
          appBar: appBar,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                GlassPanel(
                  child: NavigationRail(
                    selectedIndex: _tab,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [ask, notes, projects],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Desktop sidebar: brand, nav, tiers (AB v2).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.projects,
    required this.onSelect,
  });

  final int selected;
  final List<Project> projects;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<Document>>(
          valueListenable: documentsNotifier,
          builder: (context, docs, _) {
            final mine = docs.where((d) => d.projectId == null).length;
            final shared = docs.length - mine;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 24, color: pb.accent),
                      const SizedBox(width: 6),
                      Text('PageBlink', style: text.titleLarge),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
                  child: Text(
                    l.tagline,
                    style: text.bodySmall?.copyWith(color: pb.inkMuted),
                  ),
                ),
                _NavItem(
                  icon: Icons.sticky_note_2_outlined,
                  label: l.tabNotes,
                  count: docs.length,
                  active: selected == 1,
                  onTap: () => onSelect(1),
                ),
                _NavItem(
                  icon: Icons.groups_outlined,
                  label: l.tabProjects,
                  count: projects.isEmpty ? null : projects.length,
                  active: selected == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: l.settings,
                  active: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    l.tiers.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: pb.inkMuted,
                    ),
                  ),
                ),
                _TierRow(
                  icon: Icons.shield_outlined,
                  title: 'Cloak',
                  subtitle: l.deviceOnly,
                  badge: l.soon.toUpperCase(),
                  dim: true,
                ),
                _TierRow(
                  icon: Icons.cloud_outlined,
                  title: l.myCloud,
                  subtitle: l.privateToYou,
                  count: mine,
                ),
                _TierRow(
                  icon: Icons.groups_outlined,
                  title: l.sharedVisionName,
                  subtitle: projects.isEmpty
                      ? l.projectsNone
                      : projects.map((p) => p.name).join(', '),
                  count: shared,
                ),
                const Spacer(),
                const Divider(),
                _NavItem(
                  icon: Icons.logout,
                  label: l.signOut,
                  active: false,
                  onTap: () => client.auth.signOutDevice(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? scheme.onPrimary : context.pb.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (count != null)
                    Text(
                      '$count',
                      style: TextStyle(color: fg.withValues(alpha: 0.85)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.count,
    this.badge,
    this.dim = false,
  });

  final IconData icon;
  final String title, subtitle;
  final int? count;
  final String? badge;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: pb.tile,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: pb.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontSize: 12,
                      color: pb.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pb.tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: pb.inkMuted,
                  ),
                ),
              )
            else if (count != null)
              Text(
                '$count',
                style: text.bodySmall?.copyWith(color: pb.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}
