import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pageblink_client/pageblink_client.dart';

import 'app/app_icons.dart';
import 'app/l10n.dart';
import 'app/locale_controller.dart';
import 'app/open_item_controller.dart';
import 'app/pb_interactive.dart';
import 'app/theme.dart';
import 'client.dart';
import 'features/account/account.dart';
import 'features/account/account_menu.dart';
import 'features/ask/ask_chat.dart'
    show ensureHistoryStatus, resetHistoryStatus;
import 'features/ask/ask_screen.dart';
import 'features/ask/ask_suggestions.dart';
import 'features/documents/documents_screen.dart';
import 'features/documents/drop_zone.dart';
import 'features/documents/upload_controller.dart';
import 'features/demo/demo.dart';
import 'features/demo/demo_widgets.dart';
import 'features/documents/upload_tray.dart';
import 'features/open_item/open_item_view.dart';
import 'features/projects/projects_load.dart';
import 'features/projects/projects_screen.dart';
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
      // A chosen language always wins. System: English, or Korean if any device/
      // browser locale is ko.
      localeResolutionCallback: (locale, supported) {
        if (chosen != null) return chosen;
        final preferred = [
          ?locale,
          ...WidgetsBinding.instance.platformDispatcher.locales,
        ];
        return preferred.any((l) => l.languageCode == 'ko')
            ? const Locale('ko')
            : const Locale('en');
      },
      builder: (context, child) =>
          pbAdaptiveTargets(context, PbBackground(child: child!)),
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
  final _projectsModel = ProjectsModel();
  ValueNotifier<List<Project>> get _projects => _projectsModel.list;

  /// Notes and PDFs open in the center pane on tablet/desktop...
  final _open = OpenItemController();

  /// PDF uploads (button and drag-and-drop) live here, above every tab, so
  /// progress survives tab changes and an open editor (ADR 019).
  final _uploads = UploadController(
    existing: () => documentsNotifier.value,
  );

  /// The pane the drop zone covers (the board / open item area).
  final _paneKey = GlobalKey();

  /// ...and, on phones, inside the active tab's own navigator.
  final _navKeys = [for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>()];
  late final _observers = [
    for (var i = 0; i < 3; i++) _TabObserver(_tabStackChanged),
  ];

  /// Keeps the layout (navigators, open editor) mounted when the demo banner
  /// appears above it.
  final _bodyKey = GlobalKey();

  bool _sampleEnsured = false;

  @override
  void initState() {
    super.initState();
    _open.openInNotesTab = _openInNotesTab;
    _projectsModel.load();
    // Demo account: banner + create counter. Re-read after anything that
    // changes the count (note save/delete, PDF added all bump boardRefresh).
    resetDemoStatus();
    refreshDemoStatus();
    // Who is signed in (email on the account block).
    resetAccountInfo();
    loadAccountInfo();
    // Ask history: off (and all its UI hidden) unless the server says so.
    resetHistoryStatus();
    ensureHistoryStatus();
    boardRefresh.addListener(refreshDemoStatus);
    // Example questions follow the sample note's state (ready, edited,
    // deleted: all bump boardRefresh).
    resetSampleHints();
    refreshSampleHints();
    boardRefresh.addListener(refreshSampleHints);
  }

  /// Once per signed-in session (this shell only exists while signed in).
  /// Needs the locale, so it runs here and not in [initState].
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sampleEnsured) return;
    _sampleEnsured = true;
    _ensureSample(context.l.isKorean ? 'ko' : 'en');
  }

  /// Localizes + indexes the sign-up sample note (idempotent on the server).
  Future<void> _ensureSample(String locale) async {
    try {
      if (await client.document.ensureSample(locale) != null) {
        boardRefresh.value++;
      }
    } catch (e) {
      debugPrint('ensureSample failed: $e'); // silent for the user
    }
  }

  @override
  void dispose() {
    boardRefresh.removeListener(refreshDemoStatus);
    boardRefresh.removeListener(refreshSampleHints);
    _open.dispose();
    _uploads.dispose();
    _projectsModel.dispose();
    super.dispose();
  }

  /// The tab navigators push/pop outside of this widget's build.
  void _tabStackChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  bool _tabIsDeep(int i) => _navKeys[i].currentState?.canPop() ?? false;

  /// Phone: a cited note opens in the Notes tab, whichever tab asked.
  Future<void> _openInNotesTab(OpenItem item) async {
    if (!await _open.flush() || !mounted) return;
    setState(() => _tab = 1);
    final nav = _navKeys[1].currentState;
    nav?.popUntil((route) => route.isFirst);
    nav?.push(
      MaterialPageRoute<void>(builder: (_) => OpenItemPage(item: item)),
    );
  }

  /// Settings open like a note: center pane (tablet/desktop), or pushed on the
  /// current tab's navigator on phones so the bottom bar stays.
  void _openSettings() {
    final item = OpenItem.settings();
    if (_open.wide) {
      _open.open(item);
      return;
    }
    _navKeys[_tab].currentState?.push(
      MaterialPageRoute<void>(builder: (_) => OpenItemPage(item: item)),
    );
  }

  /// Sidebar / rail: save and close an open pane, then switch.
  Future<void> _select(int i) async {
    await _open.close();
    if (mounted && _open.item == null) setState(() => _tab = i);
  }

  List<({IconData icon, IconData selected, String label})> _destinations(
    L l,
  ) => [
    (icon: AppIcons.ask, selected: AppIcons.askSelected, label: l.tabAsk),
    (
      icon: AppIcons.note,
      selected: AppIcons.noteSelected,
      label: l.tabNotes,
    ),
    (
      icon: AppIcons.projects,
      selected: AppIcons.projectsSelected,
      label: l.tabProjects,
    ),
  ];

  Widget _ask() => ValueListenableBuilder<List<Project>>(
    valueListenable: _projects,
    builder: (context, projects, _) => AskScreen(projects: projects),
  );

  Widget _notes() => ValueListenableBuilder<List<Project>>(
    valueListenable: _projects,
    builder: (context, projects, _) => DocumentsScreen(projects: projects),
  );

  Widget _projectsTab() => ListenableBuilder(
    listenable: Listenable.merge([_projects, _projectsModel.status]),
    builder: (context, _) => ProjectsScreen(
      projects: _projects.value,
      status: _projectsModel.status.value,
      onChanged: _projectsModel.load,
    ),
  );

  /// One navigator per tab (phones), so pushes stay inside the tab.
  Widget _tabNavigator(int i, Widget root) => HeroControllerScope.none(
    child: Navigator(
      key: _navKeys[i],
      observers: [_observers[i]],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
    ),
  );

  /// The tab content, with the open item layered over it (wide layouts),
  /// then the drop zone and the upload tray on top of both.
  Widget _withPane(Widget base) {
    final item = _open.item;
    return Stack(
      key: _paneKey,
      // The zone reaches 12 px past the pane.
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          // Offstage is still in the focus tree: Tab must not go into the
          // board hidden behind an open note.
          child: ExcludeFocus(
            excluding: item != null,
            child: Offstage(
              offstage: item != null,
              child: TickerMode(enabled: item == null, child: base),
            ),
          ),
        ),
        if (item != null)
          Positioned.fill(
            child: OpenItemPane(
              key: ObjectKey(item),
              item: item,
              controller: _open,
            ),
          ),
        DropZone(projects: _projects, editorOpen: item?.isNote ?? false),
        const Positioned(right: 16, bottom: 16, child: UploadTray()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final destinations = _destinations(l);
    final appBar = AppBar(
      // Same brand mark as the desktop sidebar (UP-06): star + wordmark.
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.brand, size: 24, color: context.pb.accent),
          const SizedBox(width: 6),
          Text(
            'PageBlink',
            // Global titleLarge is 20 (UP-02); the brand stays >= 22.
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 22, letterSpacing: -0.2),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(AppIcons.settings),
          tooltip: l.settings,
          onPressed: _openSettings,
        ),
        // Sign out lives in the account menu / sheet.
        const AccountAvatarButton(),
      ],
    );

    return UploadDropHost(
      controller: _uploads,
      projects: _projects,
      paneKey: _paneKey,
      child: OpenItemScope(
        controller: _open,
        child: ListenableBuilder(
          listenable: _open,
          builder: (context, _) => ValueListenableBuilder<DemoStatus?>(
            valueListenable: demoStatus,
            builder: (context, demo, _) {
              final banner = demo != null && demo.isDemo;
              return Column(
                children: [
                  if (banner) DemoBanner(status: demo),
                  Expanded(
                    key: _bodyKey,
                    // The banner's SafeArea took the status bar inset.
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: banner,
                      child: LayoutBuilder(
                        builder: (context, constraints) => _layout(
                          context,
                          constraints.maxWidth,
                          destinations,
                          appBar,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    double width,
    List<({IconData icon, IconData selected, String label})> destinations,
    AppBar appBar,
  ) {
    _open.wide = width >= 600;

    // Phone: bottom navigation; every tab has its own navigator, so notes and
    // PDFs open inside the tab and the bar stays.
    if (width < 600) {
      final deep = _tabIsDeep(_tab);
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return PopScope(
        // Back pops inside the active tab first; only a tab at its root exits.
        canPop: !deep,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navKeys[_tab].currentState?.maybePop();
        },
        child: Scaffold(
          appBar: deep ? null : appBar,
          body: Stack(
            key: _paneKey,
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    _tabNavigator(0, _ask()),
                    _tabNavigator(1, _notes()),
                    _tabNavigator(2, _projectsTab()),
                  ],
                ),
              ),
              // Only a desktop browser squeezed below 600 px ever shows it.
              DropZone(projects: _projects, grow: -12),
              Positioned(
                left: 12,
                right: 12,
                // ponytail: clears the Notes tab's two FABs (~124 px).
                bottom: _tab == 1 && !deep ? 136 : 12,
                child: const UploadTray(width: null),
              ),
            ],
          ),
          // Hidden while typing, so the editor toolbar sits on the keyboard.
          bottomNavigationBar: keyboardOpen
              ? null
              : NavigationBar(
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
        ),
      );
    }

    // Back / Esc-equivalent: close the open item before anything else.
    Widget guard(Widget child) => PopScope(
      canPop: _open.item == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open.close();
      },
      child: child,
    );

    // Desktop: custom sidebar | board or open item | Ask (fixed 380), 24 gaps.
    if (width >= 1024) {
      return guard(
        Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: FocusTraversalGroup(
                      child: DropScrim(
                        child: ValueListenableBuilder<List<Project>>(
                          valueListenable: _projects,
                          builder: (context, projects, _) => _Sidebar(
                            selected: _tab == 2 ? 2 : 1,
                            projects: projects,
                            onSelect: _select,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: FocusTraversalGroup(
                          child: _withPane(
                            _tab == 2 ? _projectsTab() : _notes(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 380,
                    child: FocusTraversalGroup(
                      child: DropScrim(child: GlassPanel(child: _ask())),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Tablet: rail + one screen at a time (or the open item).
    return guard(
      Scaffold(
        appBar: appBar,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              DropScrim(
                child: GlassPanel(
                  child: NavigationRail(
                    selectedIndex: _tab,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: _select,
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
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _withPane(
                  IndexedStack(
                    index: _tab,
                    children: [_ask(), _notes(), _projectsTab()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the shell when a tab's navigator pushes or pops a page.
class _TabObserver extends NavigatorObserver {
  _TabObserver(this.onChanged);
  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
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
                      Icon(AppIcons.brand, size: 26, color: pb.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'PageBlink',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Matches the Ask header weight (headlineMedium
                          // 28 + icon 26); global titleLarge stays 20.
                          style: text.titleLarge?.copyWith(
                            fontSize: 24,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
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
                  icon: AppIcons.note,
                  label: l.tabNotes,
                  count: docs.length,
                  active: selected == 1,
                  onTap: () => onSelect(1),
                ),
                _NavItem(
                  icon: AppIcons.projects,
                  label: l.tabProjects,
                  count: projects.isEmpty ? null : projects.length,
                  active: selected == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  icon: AppIcons.settings,
                  label: l.settings,
                  active: false,
                  onTap: () => openItem(context, OpenItem.settings()),
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
                // Device-only tier: not built yet, so not shown. Flip
                // [_showCloakTier] when the feature ships.
                if (_showCloakTier)
                  _TierRow(
                    icon: AppIcons.privacy,
                    title: 'Cloak',
                    subtitle: l.deviceOnly,
                    badge: l.soon.toUpperCase(),
                    dim: true,
                  ),
                _TierRow(
                  icon: AppIcons.tierCloud,
                  title: l.myCloud,
                  subtitle: l.privateToYou,
                  count: mine,
                ),
                _TierRow(
                  icon: AppIcons.tierShared,
                  title: l.sharedVisionName,
                  subtitle: projects.isEmpty
                      ? l.projectsNone
                      : projects.map((p) => p.name).join(', '),
                  count: shared,
                ),
                const Spacer(),
                // 12 above and below: the theme's divider has no spacing.
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                const AccountRow(),
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
    final pb = context.pb;
    final fg = active ? scheme.onPrimary : pb.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: PbInteractive(
        onTap: onTap,
        radius: 14,
        pressScale: 0.985,
        expand: true,
        minHit: const Size(0, 40),
        selected: active,
        builder: (context, states) => AnimatedContainer(
          duration: pbFast(context),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            // The open item is a violet fill: it darkens (black 8% / 14%);
            // the rest tint with ink / white 6% / 12%.
            color: active
                ? Color.alphaBlend(
                    pbTint(pb, states, filled: true),
                    scheme.primary,
                  )
                : pbTint(pb, states),
            borderRadius: BorderRadius.circular(14),
          ),
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
    );
  }
}

const _showCloakTier = false;

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
