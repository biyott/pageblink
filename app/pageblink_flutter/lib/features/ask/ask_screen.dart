import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/theme.dart';
import '../../app/l10n.dart';
import '../../client.dart';
import '../viewer/citation_sheet.dart';
import '../../app/open_item_controller.dart';
import '../documents/documents_screen.dart' show documentsNotifier;
import '../open_item/open_item_view.dart';
import 'ask_suggestions.dart';
import '../../app/app_icons.dart';

/// Ask a question; the answer streams in with ⚡ citations you can blink to.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key, required this.projects});

  final List<Project> projects;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _Turn {
  _Turn(this.question);
  final String question;
  final answer = StringBuffer();
  final citations = <int, Citation>{};
  String? modelId;
  String? modelLabel;
  String? error;
  bool done = false;
}

class _AskScreenState extends State<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  final _selectedProjects = <int>{};
  bool _includePersonal = true;
  StreamSubscription<AnswerEvent>? _subscription;
  List<LlmModel> _models = const [];

  /// null = Auto: the server picks its default model and rotates (ADR 014).
  String? _modelId;

  @override
  void initState() {
    super.initState();
    _loadModels();
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

  static final _marker = RegExp(r'\[(\d{1,2})\]');

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _streaming => _turns.isNotEmpty && !_turns.last.done;

  /// Checked projects that still exist; the server drops anything else too.
  int get _projectCount =>
      widget.projects.where((p) => _selectedProjects.contains(p.id)).length;

  /// Nothing checked: the server would only answer "nothing found".
  bool get _scopeEmpty => !_includePersonal && _projectCount == 0;

  void _ask() {
    final question = _input.text.trim();
    if (question.isEmpty || _streaming || _scopeEmpty) return;
    final failed = context.l.askFailed;
    _input.clear();
    final turn = _Turn(question);
    setState(() => _turns.add(turn));

    final projectIds = widget.projects.isEmpty
        ? <int>[]
        : _selectedProjects.toList();
    _subscription = client.ask
        .ask(
          question,
          projectIds,
          _includePersonal,
          _modelId,
          Localizations.localeOf(context).languageCode,
        )
        .listen(
          (event) => setState(() {
            switch (event.type) {
              case 'token':
                turn.answer.write(event.text ?? '');
              case 'citation':
                final c = event.citation;
                if (c != null) turn.citations[c.index] = c;
              case 'model':
                // The model that actually answered (may differ after rotation).
                final id = event.text;
                turn.modelId = id;
                turn.modelLabel =
                    _models.where((m) => m.id == id).firstOrNull?.label ?? id;
              case 'error':
                turn.error = event.text;
              case 'done':
                turn.done = true;
            }
            _scrollToEnd();
          }),
          onError: (Object e) {
            debugPrint('ask failed: $e');
            setState(() {
              turn.error = failed;
              turn.done = true;
            });
          },
          onDone: () => setState(() => turn.done = true),
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
            openItem(context, OpenItem.citation(c), inNotesTab: true);
          }
        },
      );
    } else {
      openItem(context, OpenItem.citation(citation));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final wideHeader = MediaQuery.sizeOf(context).width >= 1024;
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
                  onPressed: _turns.isEmpty
                      ? null
                      : () {
                          _subscription?.cancel();
                          _subscription = null;
                          setState(_turns.clear);
                        },
                  icon: const Icon(AppIcons.newQuestion),
                ),
              ],
            ),
          ),
        Expanded(
          child: _turns.isEmpty
              ? _EmptyHint(
                  includePersonal: _includePersonal,
                  onPick: (q) {
                    _input.text = q;
                    _ask();
                  },
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _turns.length,
                  itemBuilder: (context, i) =>
                      _TurnView(_turns[i], onBlink: _blink),
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
                    _ScopeButton(
                      summary: context.l.scopeSummary(
                        _includePersonal,
                        _projectCount,
                      ),
                      empty: _scopeEmpty,
                      onTap: _pickScope,
                    ),
                    TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: context.l.askPlaceholder,
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
                    Row(
                      children: [
                        if (_models.isNotEmpty)
                          Flexible(
                            child: _ModelPill(
                              models: _models,
                              selected: _modelId,
                              onChanged: (id) => setState(() => _modelId = id),
                            ),
                          ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: _input,
                          builder: (context, _) {
                            final canSend =
                                _input.text.trim().isNotEmpty &&
                                !_streaming &&
                                !_scopeEmpty;
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
                      ],
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

  /// Renders `[n]` markers as ⚡n so they read as tappable citation numbers.
  /// A space goes before the chip and, unless punctuation follows, after it;
  /// thin spaces inside the code span pad the chip itself.
  static String renderMarkers(String text) =>
      text.replaceAllMapped(_marker, (m) {
        final next = m.end < text.length ? text[m.end] : '';
        final gap = next.isEmpty || _noGapAfter.hasMatch(next) ? '' : ' ';
        return ' `\u2009⚡${m[1]}\u2009`$gap';
      });
  static final _noGapAfter = RegExp(r'[\s.,;:!?)\]]');
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

class _TurnView extends StatelessWidget {
  const _TurnView(this.turn, {required this.onBlink});

  final _Turn turn;
  final void Function(List<Citation> all, Citation c) onBlink;

  @override
  Widget build(BuildContext context) {
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
                      _AskScreenState.renderMarkers(turn.answer.toString()),
                    ),
                    if (citations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(color: pb.hairline),
                      const SizedBox(height: 10),
                      Text(
                        l.sourcesLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: pb.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in citations)
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                AppIcons.citation,
                                size: 16,
                                color: pb.accent,
                              ),
                              side: BorderSide(color: pb.accent),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              backgroundColor: Colors.transparent,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                color: pb.onAccentContainer,
                                fontWeight: FontWeight.w500,
                              ),
                              label: Text(
                                '${c.index} · ${c.documentTitle}'
                                '${c.kind == 'note' ? '' : ' p.${c.page}'}',
                              ),
                              onPressed: () => onBlink(citations, c),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
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
        if (turn.error != null)
          Text(turn.error!, style: TextStyle(color: colors.error)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onPick, required this.includePersonal});

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
            ValueListenableBuilder<List<Document>>(
              valueListenable: documentsNotifier,
              builder: (context, docs, _) => Column(
                children: [
                  for (final s in orderedSuggestions(
                    context.l,
                    includePersonal ? personalNoteTitles(docs) : const [],
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
                  text,
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
