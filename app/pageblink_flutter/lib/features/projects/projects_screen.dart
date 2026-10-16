import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/app_icons.dart';
import '../../app/confirm_dialog.dart';
import '../../app/l10n.dart';
import '../../app/pb_interactive.dart';
import '../../app/open_item_controller.dart';
import '../../client.dart';
import '../demo/demo.dart';
import 'projects_load.dart';

/// Same limit the server enforces (`cleanProjectName`).
const maxProjectNameLength = 60;

/// The trimmed name when it is 1..60 characters, else null.
String? validProjectName(String raw) {
  final name = raw.trim();
  return name.isEmpty || name.length > maxProjectNameLength ? null : name;
}

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

  /// Whether [projects] is still being read or could not be (the screen does
  /// not tell the two from an empty list yet).
  final ProjectsLoad status;
  final Future<void> Function() onChanged;

  /// Only the owner can rename or delete (the server enforces it too).
  bool _isOwner(Project p) => p.ownerId == client.auth.authInfo?.authUserId;

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
          messenger.showSnackBar(SnackBar(content: Text(l.inviteFailed(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      floatingActionButton: PbFocusRing(
        radius: 28,
        child: FloatingActionButton.extended(
          onPressed: () => _create(context),
          icon: const Icon(AppIcons.newProject),
          label: Text(l.newProject),
        ),
      ),
      body: projects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.projectsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                for (final p in projects)
                  ListTile(
                    leading: const Icon(AppIcons.projects),
                    title: Text(p.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(AppIcons.invite),
                          tooltip: l.invite,
                          onPressed: () => _invite(context, p),
                        ),
                        if (_isOwner(p))
                          PopupMenuButton<_Action>(
                            tooltip: l.moreActions,
                            icon: const Icon(AppIcons.more),
                            onSelected: (a) => switch (a) {
                              _Action.rename => _rename(context, p),
                              _Action.delete => _delete(context, p),
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
                  ),
              ],
            ),
    );
  }
}
