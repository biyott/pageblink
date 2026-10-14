import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../client.dart';

/// Shared Vision: projects whose documents members can all ask about.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    required this.projects,
    required this.onChanged,
  });

  final List<Project> projects;
  final Future<void> Function() onChanged;

  Future<String?> _prompt(BuildContext context, String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await _prompt(
      context,
      context.l.newProject,
      context.l.newProjectHint,
    );
    if (name == null || name.isEmpty) return;
    await client.project.create(name);
    await onChanged();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.inviteFailed(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.group_add_outlined),
        label: Text(context.l.newProject),
      ),
      body: projects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l.projectsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final p in projects)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(p.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add_alt),
                      tooltip: context.l.invite,
                      onPressed: () => _invite(context, p),
                    ),
                  ),
              ],
            ),
    );
  }
}
