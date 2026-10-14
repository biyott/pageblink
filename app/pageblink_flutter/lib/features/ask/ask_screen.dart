import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/theme.dart';
import '../../app/l10n.dart';
import '../../client.dart';
import '../viewer/citation_sheet.dart';
import '../viewer/page_viewer_screen.dart';

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
  String? _modelId;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await client.model.list();
      final fallback = await client.model.defaultModel();
      if (mounted) setState(() => _models = models);
      if (mounted) setState(() => _modelId ??= fallback);
    } catch (_) {
      // Picker stays hidden; the server default model is used.
    }
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

  void _ask() {
    final question = _input.text.trim();
    if (question.isEmpty || _streaming) return;
    _input.clear();
    final turn = _Turn(question)
      ..modelLabel = _models.where((m) => m.id == _modelId).firstOrNull?.label;
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
              case 'error':
                turn.error = event.text;
              case 'done':
                turn.done = true;
            }
            _scrollToEnd();
          }),
          onError: (Object e) => setState(() {
            turn.error = '$e';
            turn.done = true;
          }),
          onDone: () => setState(() => turn.done = true),
        );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Phones get the citation bottom sheet; wider layouts open the viewer.
  void _blink(List<Citation> all, Citation citation) {
    if (MediaQuery.sizeOf(context).width < 600) {
      showCitationSheet(context, all, all.indexOf(citation));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PageViewerScreen(citation: citation)),
      );
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
                Icon(Icons.bolt, size: 26, color: pb.accent),
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
                      : () => setState(() => _turns.clear()),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        Expanded(
          child: _turns.isEmpty
              ? _EmptyHint(
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
                    _ScopeBar(
                      projects: widget.projects,
                      selected: _selectedProjects,
                      includePersonal: _includePersonal,
                      onPersonal: (v) => setState(() => _includePersonal = v),
                      onProject: (id, v) => setState(
                        () => v
                            ? _selectedProjects.add(id)
                            : _selectedProjects.remove(id),
                      ),
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
                                _input.text.trim().isNotEmpty && !_streaming;
                            return IconButton.filled(
                              onPressed: canSend ? _ask : null,
                              tooltip: context.l.askTooltip,
                              icon: const Icon(Icons.arrow_upward),
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
  static String renderMarkers(String text) =>
      text.replaceAllMapped(_marker, (m) => ' `⚡${m[1]}`');
}

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
    return PopupMenuButton<String>(
      tooltip: l.answerModel,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final m in models)
          PopupMenuItem(
            value: m.id,
            child: Text(
              '${m.label} · ${m.free ? l.free : l.paid}'
              '${m.note == null ? '' : ' · ${m.note}'}',
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
                current?.label ?? l.answerModel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (current != null) ...[
              const SizedBox(width: 6),
              Text(
                current.free ? l.free : l.paid,
                style: TextStyle(fontSize: 11, color: pb.success),
              ),
            ],
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.projects,
    required this.selected,
    required this.includePersonal,
    required this.onPersonal,
    required this.onProject,
  });

  final List<Project> projects;
  final Set<int> selected;
  final bool includePersonal;
  final ValueChanged<bool> onPersonal;
  final void Function(int id, bool value) onProject;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        FilterChip(
          avatar: const Icon(Icons.cloud_outlined, size: 18),
          label: Text(context.l.myDocs),
          selected: includePersonal,
          onSelected: onPersonal,
        ),
        for (final p in projects) ...[
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.groups_outlined, size: 18),
            label: Text(p.name),
            selected: selected.contains(p.id),
            onSelected: (v) => onProject(p.id!, v),
          ),
        ],
      ],
    ),
  );
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
                                Icons.bolt,
                                size: 16,
                                color: pb.accent,
                              ),
                              side: BorderSide(color: pb.accent),
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
                          icon: const Icon(Icons.copy_outlined),
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
  const _EmptyHint({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 44, color: theme.colorScheme.primary),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in context.l.askSuggestions)
                  ActionChip(label: Text(s), onPressed: () => onPick(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
