import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../client.dart';
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
    final turn = _Turn(question);
    setState(() => _turns.add(turn));

    final projectIds = widget.projects.isEmpty
        ? <int>[]
        : _selectedProjects.toList();
    _subscription = client.ask
        .ask(question, projectIds, _includePersonal, _modelId)
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

  void _blink(Citation citation) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PageViewerScreen(citation: citation)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_models.isNotEmpty)
          _ModelPicker(
            models: _models,
            selected: _modelId,
            onChanged: (id) => setState(() => _modelId = id),
          ),
        _ScopeBar(
          projects: widget.projects,
          selected: _selectedProjects,
          includePersonal: _includePersonal,
          onPersonal: (v) => setState(() => _includePersonal = v),
          onProject: (id, v) => setState(
            () => v ? _selectedProjects.add(id) : _selectedProjects.remove(id),
          ),
        ),
        Expanded(
          child: _turns.isEmpty
              ? const _EmptyHint()
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: const InputDecoration(
                      hintText: '내 문서에 질문하기…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _streaming ? null : _ask,
                  icon: const Icon(Icons.bolt),
                  tooltip: '질문',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Renders `[n]` markers as ⚡n so they read as tappable citation numbers.
  static String renderMarkers(String text) =>
      text.replaceAllMapped(_marker, (m) => ' `⚡${m[1]}`');
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.models,
    required this.selected,
    required this.onChanged,
  });

  final List<LlmModel> models;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: DropdownButtonFormField<String>(
      initialValue: models.any((m) => m.id == selected) ? selected : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '답변 모델',
        prefixIcon: Icon(Icons.memory),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final m in models)
          DropdownMenuItem(
            value: m.id,
            child: Text(
              '${m.free ? '🆓' : '💳'} ${m.label} · ${m.note ?? ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    ),
  );
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        FilterChip(
          avatar: const Icon(Icons.cloud_outlined, size: 18),
          label: const Text('내 문서'),
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
  final ValueChanged<Citation> onBlink;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final citations = turn.citations.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(turn.question),
          ),
        ),
        if (turn.answer.isEmpty && !turn.done && turn.error == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (turn.modelId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '⚡ ${turn.modelId}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        if (turn.answer.isNotEmpty)
          GptMarkdown(_AskScreenState.renderMarkers(turn.answer.toString())),
        if (turn.error != null)
          Text(turn.error!, style: TextStyle(color: colors.error)),
        if (citations.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in citations)
                ActionChip(
                  avatar: const Icon(Icons.bolt, size: 18),
                  label: Text('${c.index} · ${c.documentTitle} p.${c.page}'),
                  onPressed: () => onBlink(c),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ask your documents.\nBlink to the page.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
