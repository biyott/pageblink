import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/text_wrap.dart';
import '../../app/theme.dart';
import '../../app/l10n.dart';
import '../../client.dart';
import '../demo/demo.dart' show demoStatus;
import '../viewer/citation_sheet.dart';
import '../../app/open_item_controller.dart';
import '../open_item/open_item_view.dart';
import 'ask_chat.dart';
import 'ask_markers.dart';
import 'ask_sources.dart';
import 'ask_suggestions.dart';
import '../../app/app_icons.dart';

export 'ask_chat.dart' show AskTurn;

/// Ask a question; the answer streams in with ⚡ citations you can blink to.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, required this.projects});

  final List<Project> projects;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _chat = AskChat();
  final _selectedProjects = <int>{};
  bool _includePersonal = true;
  bool _noticeShown = false;
  List<LlmModel> _models = const [];

  /// null = Auto: the server picks its default model and rotates (ADR 014).
  String? _modelId;

  @override
  void initState() {
    super.initState();
    _chat.labelOf = (id) => _models.where((m) => m.id == id).firstOrNull?.label;
    _chat.onGiveBack = (q) => _input.text = q;
    _chat.addListener(_chatChanged);
    _loadModels();
    _chat.start();
    noticeDismissed().then((gone) {
      if (mounted) setState(() => _noticeShown = !gone);
    });
  }

  /// Scroll to the newest text and announce a counter that got close to the
  /// limit (once, not on every question).
  void _chatChanged() {
    _scrollToEnd();
    final level = _chat.announce;
    if (level == null || !mounted) return;
    _chat.announce = null;
    final l = context.l;
    final text = level >= 2
        ? l.askLimitReached(_chat.count ?? 0)
        : l.askCountLeft((_chat.limit ?? 0) - (_chat.count ?? 0));
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    );
  }

  Future<void> _loadModels() async {
    try {
      final models = await client.model.list();
      if (mounted) setState(() => _models = models);
    } catch (_) {
      // Picker stays hidden; the server default model is used.
    }
  }

  /// A deleted project must not stay in the scope.
  @override
  void didUpdateWidget(AskScreen old) {
    super.didUpdateWidget(old);
    final ids = {for (final p in widget.projects) p.id};
    _selectedProjects.retainWhere(ids.contains);
  }

  @override
  void dispose() {
    _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _streaming => _chat.streaming;

  /// Checked projects that still exist; the server drops anything else too.
  int get _projectCount =>
      widget.projects.where((p) => _selectedProjects.contains(p.id)).length;

  /// Nothing checked: the server would only answer "nothing found".
  bool get _scopeEmpty => !_includePersonal && _projectCount == 0;

  bool get _blocked => _streaming || _scopeEmpty || _chat.limitReached;

  void _ask() {
    final question = _input.text.trim();
    if (question.isEmpty || _blocked) return;
    _input.clear();
    _chat.ask(
      question,
      projectIds: widget.projects.isEmpty
          ? <int>[]
          : _selectedProjects.toList(),
      includePersonal: _includePersonal,
      modelId: _modelId,
      locale: Localizations.localeOf(context).languageCode,
    );
  }

  /// Recent conversations: bottom sheet on phones, dialog otherwise.
  Future<void> _pickChat() {
    _chat.refreshRecent();
    Widget content(BuildContext context) => _RecentChats(
      chat: _chat,
      onPick: (id) {
        Navigator.of(context).pop();
        _chat.openSession(id);
      },
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(child: content(context)),
      );
    }
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content(context),
        ),
      ),
    );
  }

  /// Phones get a bottom sheet, wider layouts a dialog. Changes apply live.
  Future<void> _pickScope() {
    Widget content(BuildContext context) => _ScopeChecklist(
      projects: widget.projects,
      includePersonal: _includePersonal,
      selected: {..._selectedProjects},
      onChanged: (personal, selected) => setState(() {
        _includePersonal = personal;
        _selectedProjects
          ..clear()
          ..addAll(selected);
      }),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(child: content(context)),
      );
    }
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content(context),
        ),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Phones get the citation bottom sheet; wider layouts open the center pane.
  void _blink(List<Citation> all, Citation citation) {
    if (MediaQuery.sizeOf(context).width < 600) {
      showCitationSheet(
        context,
        all,
        all.indexOf(citation),
        onOpen: (c) {
          if (mounted) {
            openItem(
              context,
              OpenItem.citation(c, related: all),
              inNotesTab: true,
            );
          }
        },
      );
    } else {
      openItem(context, OpenItem.citation(citation, related: all));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    _chat.l = context.l;
    return ListenableBuilder(
      listenable: Listenable.merge([_chat, historyStatus]),
      builder: (context, _) => _body(context, pb),
    );
  }

  Widget _body(BuildContext context, Pb pb) {
    final l = context.l;
    final wideHeader = MediaQuery.sizeOf(context).width >= 1024;
    final turns = _chat.turns;
    final status = historyStatus.value;
    final historyOn = _chat.on;
    final limitReached = _chat.limitReached;
    return Column(
      children: [
        if (wideHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
            child: Row(
              children: [
                Icon(AppIcons.ask, size: 26, color: pb.accent),
                const SizedBox(width: 6),
                Text(
                  context.l.tabAsk,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l.newChat,
                  onPressed: turns.isEmpty ? null : _chat.newChat,
                  icon: const Icon(AppIcons.newQuestion),
                ),
              ],
            ),
          ),
        if (historyOn && _noticeShown)
          _HistoryNotice(
            text: l.historyNotice(status!.retentionDays),
            onClose: () {
              setState(() => _noticeShown = false);
              dismissNotice();
            },
          ),
        Expanded(
          child: turns.isEmpty
              ? AskEmptyHint(
                  includePersonal: _includePersonal,
                  onPick: (q) {
                    _input.text = q;
                    _ask();
                  },
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: turns.length,
                  itemBuilder: (context, i) => AskTurnView(
                    turns[i],
                    onBlink: _blink,
                    onAskAgain: (q) => _input.text = q,
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: GlassPanel(
              radius: 20,
              strong: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (historyOn)
                      _ChatBar(
                        chat: _chat,
                        onRecent: _pickChat,
                      ),
                    if (_chat.hint != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          switch (_chat.hint!) {
                            AskHint.busy => l.askBusy,
                            AskHint.expired => l.askExpired,
                            AskHint.notFound => l.askChatGone,
                            AskHint.loadFailed => l.historyLoadFailed,
                          },
                          style: TextStyle(fontSize: 12, color: pb.warnText),
                        ),
                      ),
                    if (limitReached)
                      _LimitBanner(
                        text: l.askLimitReached(
                          _chat.limit ?? _chat.count ?? 0,
                        ),
                        onNew: _chat.newChat,
                      ),
                    _ScopeButton(
                      summary: context.l.scopeSummary(
                        _includePersonal,
                        _projectCount,
                      ),
                      empty: _scopeEmpty,
                      onTap: _pickScope,
                    ),
                    // Input and send button share a row (chat style); the
                    // button stays at the bottom edge when the text wraps.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: !limitReached,
                            inputFormatters:
                                historyOn && (status?.questionMaxChars ?? 0) > 0
                                ? [
                                    LengthLimitingTextInputFormatter(
                                      status!.questionMaxChars,
                                    ),
                                  ]
                                : null,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _ask(),
                            decoration: InputDecoration(
                              hintText: limitReached
                                  ? l.askLimitHint
                                  : l.askPlaceholder,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ListenableBuilder(
                            listenable: _input,
                            builder: (context, _) {
                              final canSend =
                                  _input.text.trim().isNotEmpty && !_blocked;
                              return IconButton.filled(
                                onPressed: canSend ? _ask : null,
                                tooltip: context.l.askTooltip,
                                icon: const Icon(AppIcons.send),
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(40, 40),
                                  backgroundColor: pb.accent,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  disabledBackgroundColor: pb.hairline,
                                  disabledForegroundColor: pb.inkMuted,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_models.isNotEmpty)
                      _ModelPill(
                        models: _models,
                        selected: _modelId,
                        onChanged: (id) => setState(() => _modelId = id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            context.l.aiDisclaimer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11, color: pb.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// Menu sentinel for Auto; never sent to the server (Auto sends null).
const _autoValue = '';

class _ModelPill extends StatelessWidget {
  const _ModelPill({
    required this.models,
    required this.selected,
    required this.onChanged,
  });

  final List<LlmModel> models;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final l = context.l;
    final current = models.where((m) => m.id == selected).firstOrNull;
    final muted = TextStyle(fontSize: 11, color: pb.inkMuted);
    Widget check(bool on) => SizedBox(
      width: 20,
      child: on ? Icon(AppIcons.check, size: 18, color: pb.accent) : null,
    );
    return PopupMenuButton<String>(
      tooltip: l.answerModel,
      onSelected: (v) => onChanged(v == _autoValue ? null : v),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _autoValue,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.modelAutoRotates,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              check(current == null),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final m in models)
          PopupMenuItem(
            value: m.id,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _FreeBadge(free: m.free),
                        ],
                      ),
                      if (l.modelNote(m.note) case final note?)
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                    ],
                  ),
                ),
                check(m.id == selected),
              ],
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pb.chipBg,
          border: Border.all(color: pb.hairline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current?.label ?? l.modelAuto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (current != null) ...[
              const SizedBox(width: 6),
              _FreeBadge(free: current.free),
            ],
            const Icon(AppIcons.expand, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Small "Free" / "Paid" tag next to a model name.
class _FreeBadge extends StatelessWidget {
  const _FreeBadge({required this.free});

  final bool free;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final color = free ? pb.success : pb.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        free ? context.l.free : context.l.paid,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// One-line summary of where answers come from; tap to change.
class _ScopeButton extends StatelessWidget {
  const _ScopeButton({
    required this.summary,
    required this.empty,
    required this.onTap,
  });

  final String summary;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final color = empty ? pb.warn : pb.inkMuted;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: context.l.scope,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: empty ? pb.warnContainer : Colors.transparent,
              border: Border.all(color: empty ? pb.warnBorder : pb.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  empty ? AppIcons.warning : AppIcons.scope,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: empty ? pb.warn : pb.ink,
                    ),
                  ),
                ),
                Icon(AppIcons.expand, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checklist of "My documents" + each project. Keeps a local copy so the
/// sheet redraws; every change is reported to the screen immediately.
class _ScopeChecklist extends StatefulWidget {
  const _ScopeChecklist({
    required this.projects,
    required this.includePersonal,
    required this.selected,
    required this.onChanged,
  });

  final List<Project> projects;
  final bool includePersonal;
  final Set<int> selected;
  final void Function(bool personal, Set<int> selected) onChanged;

  @override
  State<_ScopeChecklist> createState() => _ScopeChecklistState();
}

class _ScopeChecklistState extends State<_ScopeChecklist> {
  late bool _personal = widget.includePersonal;
  late final Set<int> _selected = {...widget.selected};

  void _set({bool? personal, Set<int>? selected}) {
    setState(() {
      _personal = personal ?? _personal;
      if (selected != null) {
        _selected
          ..clear()
          ..addAll(selected);
      }
    });
    widget.onChanged(_personal, {..._selected});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    final ids = {for (final p in widget.projects) p.id!};
    final all = _personal && _selected.containsAll(ids);
    final none = !_personal && _selected.intersection(ids).isEmpty;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.scope, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  l.scopeSubtitle,
                  style: text.bodySmall?.copyWith(color: pb.inkMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: all
                      ? null
                      : () => _set(personal: true, selected: ids),
                  child: Text(l.selectAll),
                ),
                TextButton(
                  onPressed: none
                      ? null
                      : () => _set(personal: false, selected: {}),
                  child: Text(l.clearAll),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            value: _personal,
            onChanged: (v) => _set(personal: v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l.myDocs),
            subtitle: Text(l.onlyYou),
            secondary: const Icon(AppIcons.tierCloud),
          ),
          for (final p in widget.projects)
            CheckboxListTile(
              value: _selected.contains(p.id),
              onChanged: (v) => _set(
                selected: v == true
                    ? {..._selected, p.id!}
                    : ({..._selected}..remove(p.id)),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              secondary: const Icon(AppIcons.tierShared),
            ),
          if (!_personal && _selected.intersection(ids).isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                l.scopeEmpty,
                style: text.bodySmall?.copyWith(color: pb.warn),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.done),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One turn: the question bubble, the streaming answer and its source chips.
/// Tapping a ⚡n marker in the answer scrolls to and flashes source chip n.
@visibleForTesting
class AskTurnView extends StatefulWidget {
  const AskTurnView(
    this.turn, {
    super.key,
    required this.onBlink,
    this.onAskAgain,
  });

  final AskTurn turn;
  final void Function(List<Citation> all, Citation c) onBlink;

  /// "Ask again" on a cut-off answer: puts the question back in the input.
  final ValueChanged<String>? onAskAgain;

  @override
  State<AskTurnView> createState() => _AskTurnViewState();
}

class _AskTurnViewState extends State<AskTurnView>
    with TickerProviderStateMixin {
  /// Selected row: 120ms delay + 1320ms (ask_sources.dart `sourceFx`), then the
  /// resting ring, which has no end.
  late final _flash = AnimationController(
    vsync: this,
    duration: sourceFlashDuration,
  );

  /// Marker acknowledgement, 600ms (`citeAckCurve`).
  late final _ack = AnimationController(
    vsync: this,
    duration: citeAckDuration,
  );

  /// The previous pick's ring fading out, 200ms, when another source is picked.
  late final _release = AnimationController(
    vsync: this,
    duration: sourceReleaseDuration,
  );
  final _chipKeys = <int, GlobalKey>{};
  int? _acking;

  /// The source whose ring is fading out, and what it showed when it began.
  int? _releasing;
  SourceFx _releaseFrom = SourceFx.none;

  /// The source picked last (marker or row). Its ring stays after the
  /// animation, until another source is picked or the turn is rebuilt.
  late final _pick = ValueNotifier<int?>(null);
  late final _markerTick = Listenable.merge([_ack, _pick, _release]);
  int? get _selected => _pick.value;
  set _selected(int? v) => _pick.value = v;

  /// The animation for [_selected] has begun (it waits for a scroll first).
  bool _started = false;

  /// [_selected] was picked again after resting: the ring stays through the
  /// start delay instead of going out.
  bool _replay = false;

  /// The folded sources are shown (per turn).
  bool _expanded = false;

  /// Expand without animating: a marker tap expands, then scrolls.
  bool _snap = false;

  /// Bumped per marker tap so an older, still-awaiting tap gives up.
  int _citeToken = 0;

  /// The list reuses this state by position; a different turn starts clean.
  @override
  void didUpdateWidget(AskTurnView old) {
    super.didUpdateWidget(old);
    if (!identical(old.turn, widget.turn)) {
      _citeToken++;
      _selected = null;
      _acking = null;
      _started = false;
      _replay = false;
      _expanded = false;
      _snap = false;
      _chipKeys.clear();
      _releasing = null;
      _flash.value = 0;
      _ack.value = 0;
      _release.value = 0;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _ack.dispose();
    _release.dispose();
    _pick.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  /// Five or more sources fold to three once the answer is complete (while it
  /// streams, a new source would turn the last visible row into the toggle).
  bool _collapsible(int n) => widget.turn.done && n >= sourcesCollapseFrom;

  /// Whether source [index] is currently folded away.
  bool _folded(int index, List<Citation> sorted) =>
      _collapsible(sorted.length) &&
      !_expanded &&
      sorted.indexWhere((c) => c.index == index) >= sourcesCollapsedShow;

  /// The number is looked up at tap time: an unknown or not yet arrived
  /// source does nothing, and works once its citation event has come in.
  /// A folded source is unfolded first, then scrolled to and flashed.
  Future<void> _cite(int index, {bool scroll = true}) async {
    final turn = widget.turn;
    if (!turn.citations.containsKey(index)) return;
    final token = ++_citeToken;
    final reduced = _reduced;
    var chip = _chipKeys[index]?.currentContext;
    if (chip == null) {
      final sorted = turn.citations.values.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      if (!_folded(index, sorted)) return;
      setState(() {
        _expanded = true;
        _snap = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || token != _citeToken) return;
      chip = _chipKeys[index]?.currentContext;
      if (chip == null || !chip.mounted) return;
    }
    final replay = _selected == index && _started && _flash.isCompleted;
    // Another source: the old ring fades out (at once when motion is reduced).
    final prev = _selected;
    if (prev != null && prev != index && !reduced) {
      _releaseFrom = _fx(prev);
      _releasing = prev;
      _release.forward(from: 0);
    } else if (prev != index) {
      _releasing = null;
    }
    setState(() {
      _acking = index;
      _selected = index;
      _started = false;
      _replay = replay;
    });
    _ack.forward(from: 0);
    var scrolled = false;
    if (scroll && !_visible(chip)) {
      scrolled = true;
      await Scrollable.ensureVisible(
        chip,
        alignment: 0.4,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted || token != _citeToken) return;
    setState(() => _started = true);
    // Reduced motion: no animation, the resting halo at once. Otherwise the
    // start delay is already spent when we had to scroll.
    if (reduced) {
      _flash.value = 1;
    } else {
      _flash.forward(from: scrolled ? sourceFlashSkipLead : 0);
    }
  }

  /// Fully inside the enclosing scrollable (true when there is none).
  static bool _visible(BuildContext chip) {
    final box = chip.findRenderObject();
    final viewport = Scrollable.maybeOf(chip)?.context.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox || !box.hasSize) {
      return true;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top >= 0 && top + box.size.height <= viewport.size.height;
  }

  /// Share of the fading ring still shown for [index] (0 when it is not the
  /// one being released).
  double _keep(int index) => _releasing == index && _release.isAnimating
      ? sourceReleaseKeep(_release.value)
      : 0;

  SourceFx _fx(int index) {
    if (_selected != index) {
      final k = _keep(index);
      return k > 0 ? _releaseFrom.faded(k) : SourceFx.none;
    }
    if (!_started) return _replay ? SourceFx.settled : SourceFx.none;
    return _reduced
        ? SourceFx.settled
        : sourceFx(_flash.value, replay: _replay);
  }

  double _ackValue(int index) {
    if (_acking != index || !_ack.isAnimating) return 0;
    return citeAckCurve.transform(_ack.value);
  }

  InlineSpan _marker(SourceTagBuildDetails tag) {
    final n = int.tryParse(tag.id) ?? 0;
    // Pill height: 18, but never taller than the line box minus 2.
    final base = DefaultTextStyle.of(tag.context).style.merge(tag.style);
    final line = (base.fontSize ?? 14) * (base.height ?? 1.4);
    return tag.asWidgetSpan(
      CiteMarker(
        key: ValueKey('cite-marker-$n'),
        index: n,
        height: (line - 2).clamp(14.0, 18.0),
        ack: _markerTick,
        ackValue: () => _ackValue(n),
        reduced: _reduced,
        selected: () => _selected == n,
        pick: () => _selected == n ? 1 : _keep(n),
        onTap: tag.onTap,
      ),
    );
  }

  Widget _sourceRow(List<Citation> all, Citation c) {
    return AnimatedBuilder(
      key: _chipKeys.putIfAbsent(c.index, GlobalKey.new),
      animation: Listenable.merge([_flash, _release]),
      builder: (context, _) => SourceRow(
        citation: c,
        fx: _fx(c.index),
        selected: _selected == c.index,
        onTap: () {
          _cite(c.index, scroll: false);
          widget.onBlink(all, c);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final colors = Theme.of(context).colorScheme;
    final pb = context.pb;
    final l = context.l;
    final citations = turn.citations.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pb.accentGradient),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              turn.question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (turn.answer.isEmpty && !turn.done && turn.error == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (turn.answer.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.92,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pb.glassStrong,
                  border: Border.all(color: pb.glassBorder),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GptMarkdown(
                      renderMarkers(turn.answer.toString()),
                      // The pill carries its own 2px hit padding.
                      styleSheet: const GptMarkdownStyleSheet(
                        sourceTag: SourceTagStyle(padding: EdgeInsets.zero),
                      ),
                      inlineSourceTagBuilder: _marker,
                      onSourceTagTap: (id) {
                        final n = int.tryParse(id);
                        if (n != null) _cite(n);
                      },
                    ),
                    if (citations.isNotEmpty)
                      SourcesList(
                        citations: citations,
                        collapsible: _collapsible(citations.length),
                        expanded: _expanded,
                        snap: _snap,
                        onToggle: () => setState(() {
                          _snap = false;
                          _expanded = !_expanded;
                        }),
                        rowBuilder: (c) => _sourceRow(citations, c),
                      ),
                    SizedBox(height: citations.isEmpty ? 8 : 12),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          color: pb.inkMuted,
                          tooltip: l.copy,
                          icon: const Icon(AppIcons.copy),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: turn.answer.toString()),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.copied)),
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        if (turn.modelLabel != null)
                          Text(
                            turn.modelLabel!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 12, color: pb.inkMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (turn.pending)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (turn.cutOff)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Icon(AppIcons.warning, size: 16, color: pb.warnText),
              Text(
                l.askInterrupted,
                style: TextStyle(fontSize: 13, color: pb.warnText),
              ),
              if (widget.onAskAgain != null)
                TextButton(
                  onPressed: () => widget.onAskAgain!(turn.question),
                  child: Text(l.askAskAgain),
                ),
            ],
          ),
        if (turn.error != null)
          Text(turn.error!, style: TextStyle(color: colors.error)),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The empty state: the example questions. A card shows its question with
/// Korean word-keeping line breaks, but [onPick] gets the plain string: the
/// joiner is for display only and must never reach the server.
@visibleForTesting
class AskEmptyHint extends StatelessWidget {
  const AskEmptyHint({
    super.key,
    required this.onPick,
    required this.includePersonal,
  });

  final ValueChanged<String> onPick;

  /// The sample is a personal note: unchecked, its questions find nothing.
  final bool includePersonal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.ask, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              context.l.askEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l.askEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.pb.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            // demoStatus and the hints can arrive after this screen is built.
            ListenableBuilder(
              listenable: Listenable.merge([sampleHints, demoStatus]),
              builder: (context, _) => Column(
                children: [
                  for (final s in orderedSuggestions(
                    context.l,
                    includePersonal ? sampleHints.value : const [],
                    isDemo: demoStatus.value?.isDemo ?? false,
                  ))
                    _SuggestionCard(text: s, onTap: () => onPick(s)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One example question: wraps freely, never shorter than a 44px tap target.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: pb.hairline),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 44),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: pb.chipBg,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  keepAllKorean(text),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "kept on the server" notice, shown once until closed.
class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: pb.chipBg,
        border: Border.all(color: pb.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, size: 16, color: pb.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: pb.inkMuted),
            ),
          ),
          IconButton(
            tooltip: context.l.dismiss,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onClose,
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    );
  }
}

/// `[Question 3/10]  [Recent conversations v]  [New conversation +]`
class _ChatBar extends StatelessWidget {
  const _ChatBar({required this.chat, required this.onRecent});

  final AskChat chat;
  final VoidCallback onRecent;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final n = chat.count, m = chat.limit ?? chat.status?.questionLimit;
    final close = chat.level >= 1;
    final reached = chat.level >= 2;
    final color = close ? pb.warnText : pb.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (n != null && m != null && n >= 1)
            Semantics(
              label: l.askCountLabel(n, m),
              excludeSemantics: true,
              child: Container(
                key: const ValueKey('ask-count'),
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: close ? pb.warnContainer : Colors.transparent,
                  border: Border.all(
                    color: close ? pb.warnBorder : pb.hairline,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (close) ...[
                      Icon(AppIcons.warning, size: 16, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        l.askCount(n, m) +
                            (close && !reached
                                ? ' · ${l.askCountLeft(m - n)}'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: close ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ActionChip(
            key: const ValueKey('ask-recent'),
            avatar: const Icon(AppIcons.expand, size: 18),
            label: Text(l.recentChats),
            onPressed: onRecent,
          ),
          ActionChip(
            key: const ValueKey('ask-new-chat'),
            avatar: const Icon(AppIcons.add, size: 18),
            label: Text(l.newConversation),
            tooltip: l.newConversation,
            onPressed: chat.turns.isEmpty && chat.sessionId == 0
                ? null
                : chat.newChat,
          ),
        ],
      ),
    );
  }
}

/// Shown when the conversation holds its last question.
class _LimitBanner extends StatelessWidget {
  const _LimitBanner({required this.text, required this.onNew});

  final String text;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Container(
      key: const ValueKey('ask-limit-banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pb.warnContainer,
        border: Border.all(color: pb.warnBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: 18, color: pb.warnText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: pb.warnText),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onNew,
            child: Text(context.l.newConversation),
          ),
        ],
      ),
    );
  }
}

/// The recent conversations sheet / dialog. Repaints when the list changes.
class _RecentChats extends StatelessWidget {
  const _RecentChats({required this.chat, required this.onPick});

  final AskChat chat;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final minutes = chat.status?.visibleMinutes ?? 0;
        final now = DateTime.now().toUtc();
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(l.recentChats, style: text.titleMedium),
              ),
              if (chat.recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    l.recentChatsEmpty(minutes),
                    style: text.bodyMedium?.copyWith(color: pb.inkMuted),
                  ),
                ),
              for (final s in chat.recent)
                ListTile(
                  key: ValueKey('recent-${s.id}'),
                  selected: s.id == chat.sessionId,
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (s.id == chat.sessionId) l.currentChat,
                      l.chatMeta(
                        s.questionCount,
                        now.difference(s.lastActiveAt.toUtc()).inMinutes,
                      ),
                    ].join(' · '),
                  ),
                  onTap: () => onPick(s.id),
                  trailing: IconButton(
                    tooltip: l.removeFromList,
                    icon: const Icon(AppIcons.delete),
                    onPressed: () => chat.hideSession(s.id),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  l.recentChatsNote(minutes),
                  style: text.bodySmall?.copyWith(color: pb.inkMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
