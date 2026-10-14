import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

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
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await _prompt(context, '새 프로젝트', '예: 2026 해커톤');
    if (name == null || name.isEmpty) return;
    await client.project.create(name);
    await onChanged();
  }

  Future<void> _invite(BuildContext context, Project project) async {
    final email = await _prompt(context, '${project.name}에 초대', '팀원 이메일');
    if (email == null || email.isEmpty || !context.mounted) return;
    try {
      await client.project.addMember(project.id!, email, 'editor');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$email 님을 초대했어요.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('초대 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('새 프로젝트'),
      ),
      body: projects.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '프로젝트를 만들면 팀원과 문서를 공유하고\n함께 질문할 수 있어요. (Shared Vision)',
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
                      tooltip: '초대',
                      onPressed: () => _invite(context, p),
                    ),
                  ),
              ],
            ),
    );
  }
}
