import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/app_icons.dart';
import '../../app/confirm_dialog.dart';
import '../../app/empty_state.dart';
import '../../app/l10n.dart';
import '../../app/open_item_controller.dart';
import '../../app/pb_interactive.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../demo/demo.dart';
import '../documents/documents_screen.dart';
import 'projects_load.dart';

/// Same limit the server enforces (`cleanProjectName`).
const maxProjectNameLength = 60;

/// The trimmed name when it is 1..60 characters, else null.
String? validProjectName(String raw) {
  final name = raw.trim();
  return name.isEmpty || name.length > maxProjectNameLength ? null : name;
}

/// Test hook: replaces the signed-in user id.
@visibleForTesting
UuidValue? Function()? projectsUserIdCall;

/// The board's list before the first read is this exact (const) instance; a
/// list that came from the server is never identical to it, even when empty.
// ponytail: identity check instead of a loaded flag in documents_screen.
const _documentsNotRead = <Document>[];

enum _Action { rename, delete }

/// Shared Vision: projects whose documents members can all ask about.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    required this.projects,
    required this.onChanged,
    this.status = ProjectsLoad.loaded,
  });

  final List<Project> projects;

  /// Whether [projects] is still being read or could not be: tells an empty
  /// list from one that has not arrived. Retry and refresh call [onChanged].
  final ProjectsLoad status;
  final Future<void> Function() onChanged;

  /// Only the owner can invite, rename or delete (the server enforces it too).
  bool _isOwner(Project p) =>
      p.ownerId ==
      (projectsUserIdCall ?? () => client.auth.authInfo?.authUserId)();

  /// Text dialog. [projectName] applies the 1..60 rule; otherwise any text.
  Future<String?> _prompt(
    BuildContext context,
    String title,
    String hint, {
    String initial = '',
    bool projectName = false,
  }) {
    final controller = TextEditingController(text: initial);
    String? submitted(String text) =>
        projectName ? validProjectName(text) : text.trim();
    return showDialog<String>(
      context: context,
      builder: (dialog) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          final text = submitted(value.text);
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                errorText:
                    projectName &&
                        value.text.trim().length > maxProjectNameLength
                    ? dialog.l.projectNameTooLong
                    : null,
              ),
              onSubmitted: (_) {
                if (text != null && text.isNotEmpty) {
                  Navigator.pop(dialog, text);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(dialog.l.cancel),
              ),
              FilledButton(
                onPressed: text == null || text.isEmpty
                    ? null
                    : () => Navigator.pop(dialog, text),
                child: Text(dialog.l.ok),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    // The demo account cannot make projects: say so before asking for a name.
    if (demoStatus.value?.isDemo ?? false) {
      showDemoLimit(
        messenger,
        l,
        DemoLimitException(reason: DemoLimitReason.projectLocked),
      );
      return;
    }
    final name = await _prompt(
      context,
      context.l.newProject,
      context.l.newProjectHint,
      projectName: true,
    );
    if (name == null || name.isEmpty) return;
    try {
      await client.project.create(name);
    } on DemoLimitException catch (e) {
      showDemoLimit(messenger, l, e);
      return;
    }
    await onChanged();
  }

  Future<void> _rename(BuildContext context, Project project) async {
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final name = await _prompt(
      context,
      l.renameProjectTitle,
      l.newProjectHint,
      initial: project.name,
      projectName: true,
    );
    if (name == null || name.isEmpty || name == project.name) return;
    try {
      await client.project.updateProject(project.id!, name);
      await onChanged();
    } catch (e) {
      debugPrint('rename project failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.projectRenameFailed)));
    }
  }

  /// Counts first: the server refuses (without a reason) to delete a project
  /// that still has documents unless told to take them along.
  Future<void> _delete(BuildContext context, Project project) async {
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stats = await client.project.projectStats(project.id!);
      final notes = stats['notes'] ?? 0;
      final pdfs = stats['pdfs'] ?? 0;
      final hasDocuments = notes + pdfs > 0;
      if (!context.mounted) return;
      final ok = await confirmDestructive(
        context,
        title: l.deleteProjectTitle(project.name),
        message: hasDocuments
            ? l.projectDeleteWarning(notes, pdfs)
            : l.cannotUndo,
      );
      if (!ok) return;
      await client.project.deleteProject(project.id!, hasDocuments);
      boardRefresh.value++;
      await onChanged();
    } catch (e) {
      debugPrint('delete project failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.projectDeleteFailed)));
    }
  }

  Future<void> _invite(BuildContext context, Project project) async {
    final l = context.l;
    final email = await _prompt(
      context,
      l.inviteTo(project.name),
      l.teammateEmail,
    );
    if (email == null || email.isEmpty || !context.mounted) return;
    try {
      await client.project.addMember(project.id!, email, 'editor');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.invited(email))));
      }
    } catch (e) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        if (e is DemoLimitException) {
          showDemoLimit(messenger, l, e);
        } else {
          debugPrint('invite failed: $e');
          // Never the exception object: the server's short message, if any.
          final reason = e is ServerpodClientException && e.message.isNotEmpty
              ? e.message
              : l.projectsLoadFailedHint;
          messenger.showSnackBar(
            SnackBar(content: Text(l.inviteFailed(reason))),
          );
        }
      }
    }
  }

  Widget _header(
    BuildContext context, {
    required bool wide,
    required String? summary,
    required bool showNew,
  }) {
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l.tabProjects,
          style: theme.headlineMedium?.copyWith(
            fontSize: wide ? 32 : 28,
            letterSpacing: -0.3,
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: 4),
          Text(summary, style: theme.bodyMedium?.copyWith(color: pb.inkMuted)),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 0 : 12,
        wide ? 0 : 8,
        wide ? 0 : 12,
        0,
      ),
      child: wide && showNew
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(AppIcons.add),
                  label: Text(context.l.newProject),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            )
          : title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final showList = projects.isNotEmpty;
    return Scaffold(
      floatingActionButton: wide || !showList
          ? null
          : PbFocusRing(
              radius: 28,
              child: FloatingActionButton.extended(
                onPressed: () => _create(context),
                icon: const Icon(AppIcons.newProject),
                label: Text(l.newProject),
              ),
            ),
      body: ValueListenableBuilder<List<Document>>(
        valueListenable: documentsNotifier,
        builder: (context, docs, _) {
          final read = !identical(docs, _documentsNotRead);
          // Documents per project: (notes, pdfs).
          final counts = <int?, (int, int)>{};
          for (final d in docs) {
            final (n, f) = counts[d.projectId] ?? (0, 0);
            counts[d.projectId] = d.kind == 'note' ? (n + 1, f) : (n, f + 1);
          }
          var notes = 0, pdfs = 0;
          for (final p in projects) {
            final (n, f) = counts[p.id] ?? (0, 0);
            notes += n;
            pdfs += f;
          }
          return Column(
            children: [
              _header(
                context,
                wide: wide,
                summary: showList && read
                    ? l.projectsSummary(projects.length, notes, pdfs)
                    : null,
                showNew: showList,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onChanged,
                  child: showList
                      ? _grid(context, wide, read ? counts : null)
                      : switch (status) {
                          ProjectsLoad.loading => const _Skeletons(),
                          ProjectsLoad.error => ListView(
                            children: [_RetryState(onRetry: onChanged)],
                          ),
                          ProjectsLoad.loaded => ListView(
                            children: [
                              PbEmptyState(
                                icon: AppIcons.projects,
                                title: l.projectsEmptyTitle,
                                body: l.projectsEmpty,
                                action: FilledButton.icon(
                                  onPressed: () => _create(context),
                                  icon: const Icon(AppIcons.add),
                                  label: Text(l.newProject),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, bool wide, Map<int?, (int, int)>? counts) {
    return GridView.builder(
      // 4 at the sides on a wide page: room for the focus ring of the first
      // and last column (same as the Notes board).
      padding: EdgeInsets.fromLTRB(
        wide ? 4 : 12,
        12,
        wide ? 4 : 12,
        wide ? 24 : 140,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: _cardExtent(context),
      ),
      itemCount: projects.length,
      itemBuilder: (context, i) {
        final p = projects[i];
        final owner = _isOwner(p);
        return _ProjectCard(
          project: p,
          owner: owner,
          counts: counts == null ? null : counts[p.id] ?? (0, 0),
          onInvite: owner ? () => _invite(context, p) : null,
          onRename: owner ? () => _rename(context, p) : null,
          onDelete: owner ? () => _delete(context, p) : null,
        );
      },
    );
  }
}

/// 176 dp, taller as the text scale grows (the card holds text, not just
/// icons, and a narrow column wraps it onto more lines).
double _cardExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return 176 * (1 + 1.25 * (scale.clamp(1.0, 4.0) - 1));
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.owner,
    required this.counts,
    required this.onInvite,
    required this.onRename,
    required this.onDelete,
  });

  final Project project;
  final bool owner;

  /// (notes, pdfs); null until the board has been read.
  final (int, int)? counts;
  final VoidCallback? onInvite;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context).textTheme;
    final touch = switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: pb.pdfPaper,
      shadowColor: pb.ink.withValues(alpha: 0.06),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pb.ink.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: pb.tile,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(AppIcons.projects, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    owner ? l.projectOwner : l.projectMember,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: pb.inkMuted,
                    ),
                  ),
                ),
                if (owner)
                  PopupMenuButton<_Action>(
                    tooltip: l.moreActions,
                    icon: Icon(AppIcons.more, size: 18, color: pb.inkMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onSelected: (a) => switch (a) {
                      _Action.rename => onRename?.call(),
                      _Action.delete => onDelete?.call(),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _Action.rename,
                        child: Text(l.renameProject),
                      ),
                      PopupMenuItem(
                        value: _Action.delete,
                        child: Text(l.delete),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              project.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (counts != null) ...[
              const SizedBox(height: 6),
              Text(
                l.projectCounts(counts!.$1, counts!.$2),
                style: theme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: pb.inkMuted,
                ),
              ),
            ],
            const Spacer(),
            if (onInvite != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onInvite,
                  icon: const Icon(AppIcons.invite, size: 18),
                  label: Text(l.invite),
                  style: TextButton.styleFrom(
                    foregroundColor: pb.linkInk,
                    minimumSize: Size(0, touch ? 44 : 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The error state: message, hint and a Retry that waits for the answer.
class _RetryState extends StatefulWidget {
  const _RetryState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_RetryState> createState() => _RetryStateState();
}

class _RetryStateState extends State<_RetryState> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return PbEmptyState(
      title: l.projectsLoadFailed,
      body: l.projectsLoadFailedHint,
      action: OutlinedButton(
        onPressed: _busy ? null : _retry,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        child: Text(_busy ? l.retrying : l.retry),
      ),
    );
  }
}

/// Two card-shaped placeholders while the first read is on its way.
class _Skeletons extends StatefulWidget {
  const _Skeletons();

  @override
  State<_Skeletons> createState() => _SkeletonsState();
}

class _SkeletonsState extends State<_Skeletons>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Static with reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: pb.ink.withValues(alpha: 0.10 * (0.4 + 0.6 * _c.value)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SizedBox(height: height, width: double.infinity),
        ),
      ),
    );
    return ExcludeSemantics(
      key: const Key('projects-skeleton'),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(wide ? 4 : 12, 12, wide ? 4 : 12, 24),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: _cardExtent(context),
        ),
        itemCount: 2,
        itemBuilder: (_, _) => DecoratedBox(
          key: const Key('projects-skeleton-card'),
          decoration: BoxDecoration(
            color: pb.pdfPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pb.ink.withValues(alpha: 0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 32, child: bar(1, 32)),
                const SizedBox(height: 16),
                bar(0.8, 10),
                const SizedBox(height: 10),
                bar(0.5, 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
