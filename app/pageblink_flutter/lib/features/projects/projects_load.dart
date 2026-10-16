import 'package:flutter/foundation.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../client.dart';

/// Where the project list stands: not read yet, read, or the read failed.
enum ProjectsLoad { loading, loaded, error }

/// Test hook: replaces `client.project.list`.
@visibleForTesting
Future<List<Project>> Function()? projectsListCall;

/// The shell's project list plus how reading it went. [list] keeps the plain
/// `ValueNotifier<List<Project>>` API its consumers (tabs, drop zone) use.
class ProjectsModel {
  final list = ValueNotifier<List<Project>>(const []);
  final status = ValueNotifier(ProjectsLoad.loading);
  bool _disposed = false;

  /// Reads the list. Stays [ProjectsLoad.loading] only until the first answer:
  /// a refresh keeps the last status and list until the new answer is in, and a
  /// failed one keeps the last list and sets [ProjectsLoad.error].
  Future<void> load() async {
    try {
      final projects = await (projectsListCall ?? client.project.list)();
      if (_disposed) return;
      list.value = projects;
      status.value = ProjectsLoad.loaded;
    } catch (e) {
      debugPrint('projects unavailable: $e');
      if (!_disposed) status.value = ProjectsLoad.error;
    }
  }

  void dispose() {
    _disposed = true;
    list.dispose();
    status.dispose();
  }
}
