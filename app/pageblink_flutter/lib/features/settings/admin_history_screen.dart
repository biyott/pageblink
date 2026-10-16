import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import '../../client.dart';

/// Test hook: replaces `askAdmin.listSessions`.
@visibleForTesting
Future<AskAdminPage> Function(AskAdminFilter filter)? askAdminListCall;

/// The admin list as its own page (pushed from the settings).
class AdminHistoryPage extends StatelessWidget {
  const AdminHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => PbPage(
    child: AdminHistoryScreen(
      embedded: MediaQuery.sizeOf(context).width >= 600,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

enum _Period { all, today, d7, d30 }

/// Read-only list of every user's Ask conversations (admins only; the server
/// checks every call). A row opens to its questions and answers.
class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({
    super.key,
    required this.onClose,
    this.embedded = false,
  });

  final VoidCallback onClose;

  /// In the glass panel (tablet/desktop): "← Settings /" header and close.
  final bool embedded;

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  final _user = TextEditingController();
  var _period = _Period.all;
  final _items = <AskAdminSession>[];
  var _models = <AskModelStat>[];
  DateTime? _nextAt;
  int? _nextId;
  var _loading = false;
  var _failed = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  DateTime? get _from {
    final now = DateTime.now();
    return switch (_period) {
      _Period.all => null,
      _Period.today => DateTime(now.year, now.month, now.day).toUtc(),
      _Period.d7 => now.subtract(const Duration(days: 7)).toUtc(),
      _Period.d30 => now.subtract(const Duration(days: 30)).toUtc(),
    };
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final user = _user.text.trim();
    final filter = AskAdminFilter(
      userId: user.isEmpty ? null : user,
      from: _from,
      beforeActiveAt: reset ? null : _nextAt,
      beforeId: reset ? null : _nextId,
    );
    try {
      final page = await (askAdminListCall ?? client.askAdmin.listSessions)(
        filter,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _models = page.models;
        _nextAt = page.nextBeforeActiveAt;
        _nextId = page.nextBeforeId;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('admin history failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    String periodLabel(_Period p) => switch (p) {
      _Period.all => l.periodAll,
      _Period.today => l.periodToday,
      _Period.d7 => l.period7,
      _Period.d30 => l.period30,
    };
    return Column(
      children: [
        PaneHeader(
          embedded: widget.embedded,
          onBack: widget.onClose,
          onClose: widget.onClose,
          backLabel: l.settings,
          title: Text(l.adminHistory),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Icon(AppIcons.info, size: 16, color: pb.warnText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.adminHistoryNote,
                      style: text.bodySmall?.copyWith(color: pb.warnText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('admin-user'),
                controller: _user,
                decoration: InputDecoration(labelText: l.adminUserFilter),
                onSubmitted: (_) => _load(reset: true),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _Period.values)
                    ChoiceChip(
                      key: ValueKey('period-${p.name}'),
                      label: Text(periodLabel(p)),
                      selected: _period == p,
                      onSelected: (_) {
                        setState(() => _period = p);
                        _load(reset: true);
                      },
                    ),
                ],
              ),
              if (_models.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l.adminModels, style: text.titleSmall),
                for (final m in _models)
                  Text(l.adminModelStat(m.modelId, m.answers, m.fallbacks)),
              ],
              const SizedBox(height: 12),
              for (final s in _items) _SessionTile(s),
              if (_loaded && _items.isEmpty && !_failed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.adminEmpty),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.adminLoadFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_nextAt != null && !_loading)
                Center(
                  child: TextButton(
                    key: const ValueKey('admin-more'),
                    onPressed: () => _load(reset: false),
                    child: Text(l.adminLoadMore),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _when(DateTime t) {
  final d = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(this.s);

  final AskAdminSession s;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final muted = TextStyle(fontSize: 12, color: pb.inkMuted);
    return ExpansionTile(
      key: ValueKey('admin-session-${s.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          _when(s.lastActiveAt),
          s.ownerLabel == s.ownerId ? s.ownerId : s.ownerLabel,
          l.adminSessionMeta(s.questionCount),
          if (s.locale != null) s.locale!,
          if (s.isDemo) l.adminDemo,
          if (s.hidden) l.adminHidden,
        ].join(' · '),
        style: muted,
      ),
      children: [
        Text('${l.adminUserFilter}: ${s.ownerId}', style: muted),
        for (final m in s.messages)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  m.question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(m.answer),
                if (m.citations.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in m.citations)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('[${c.index}] ${c.documentTitle}'),
                        ),
                    ],
                  ),
                Text(
                  [
                    _when(m.createdAt),
                    l.adminStatus(m.status),
                    if (m.modelId != null) m.modelId!,
                    if (m.fallback) l.adminFallback,
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
