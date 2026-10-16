import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';
import '../demo/demo_guard.dart';
import '../services/acl.dart';
import '../services/document_cleanup.dart';

const maxProjectNameLength = 60;

/// Trimmed project name; throws when empty or longer than 60 characters.
String cleanProjectName(String name) {
  final clean = name.trim();
  if (clean.isEmpty || clean.length > maxProjectNameLength) {
    throw ArgumentError('Project name must be 1-$maxProjectNameLength chars');
  }
  return clean;
}

/// Projects share documents between members.
class ProjectEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<Project> create(Session session, String name) async {
    final userId = Acl.requireUser(session);
    DemoGuard.requireNoProject(userId);
    final cleanName = cleanProjectName(name);
    return session.db.transaction((tx) async {
      final project = await Project.db.insertRow(
        session,
        Project(
          name: cleanName,
          ownerId: userId,
          createdAt: DateTime.now().toUtc(),
        ),
        transaction: tx,
      );
      await ProjectMember.db.insertRow(
        session,
        ProjectMember(projectId: project.id!, userId: userId, role: 'owner'),
        transaction: tx,
      );
      return project;
    });
  }

  Future<List<Project>> list(Session session) async {
    final userId = Acl.requireUser(session);
    final ids = await Acl.memberProjectIds(session, userId);
    if (ids.isEmpty) return [];
    return Project.db.find(
      session,
      where: (t) => t.id.inSet(ids),
      orderBy: (t) => t.name,
    );
  }

  /// Adds a registered user by email. Only owners can invite.
  Future<ProjectMember> addMember(
    Session session,
    int projectId,
    String email,
    String role,
  ) async {
    final userId = Acl.requireUser(session);
    await Acl.requireRole(session, userId, projectId, roles: {'owner'});
    if (!{'editor', 'viewer'}.contains(role)) {
      throw ArgumentError('role must be editor or viewer');
    }

    final account = await EmailAccount.db.findFirstRow(
      session,
      where: (t) => t.email.equals(email.trim().toLowerCase()),
    );
    final memberId = account?.authUserId;
    if (memberId == null) throw ArgumentError('No user with email $email');
    DemoGuard.requireNoProject(memberId);

    final existing = await ProjectMember.db.findFirstRow(
      session,
      where: (t) => t.projectId.equals(projectId) & t.userId.equals(memberId),
    );
    if (existing != null) {
      return ProjectMember.db.updateRow(session, existing.copyWith(role: role));
    }
    return ProjectMember.db.insertRow(
      session,
      ProjectMember(projectId: projectId, userId: memberId, role: role),
    );
  }

  Future<List<ProjectMember>> members(Session session, int projectId) async {
    final userId = Acl.requireUser(session);
    await Acl.requireRole(session, userId, projectId);
    return ProjectMember.db.find(
      session,
      where: (t) => t.projectId.equals(projectId),
    );
  }

  /// Renames a project. Only the owner can.
  Future<Project> updateProject(
    Session session,
    int projectId,
    String name,
  ) async {
    final userId = Acl.requireUser(session);
    await Acl.requireRole(session, userId, projectId, roles: {'owner'});
    final cleanName = cleanProjectName(name);
    final project = await Project.db.findById(session, projectId);
    if (project == null) throw ArgumentError('Project not found');
    return Project.db.updateRow(session, project.copyWith(name: cleanName));
  }

  /// What deleting [projectId] would take with it: `notes`, `pdfs`, `members`.
  /// Any member can ask; the app shows it in the delete confirmation.
  Future<Map<String, int>> projectStats(Session session, int projectId) async {
    final userId = Acl.requireUser(session);
    await Acl.requireRole(session, userId, projectId);
    final notes = await Document.db.count(
      session,
      where: (t) => t.projectId.equals(projectId) & t.kind.equals('note'),
    );
    final docs = await Document.db.count(
      session,
      where: (t) => t.projectId.equals(projectId),
    );
    final members = await ProjectMember.db.count(
      session,
      where: (t) => t.projectId.equals(projectId),
    );
    return {'notes': notes, 'pdfs': docs - notes, 'members': members};
  }

  /// Deletes a project. Only the owner can. When it still has documents this
  /// throws (`not_empty:<count>`) unless [deleteDocuments] is true, which also
  /// deletes every document, chunk, page, stored PDF and membership.
  /// Returns how many documents were deleted.
  Future<int> deleteProject(
    Session session,
    int projectId,
    bool deleteDocuments,
  ) async {
    final userId = Acl.requireUser(session);
    await Acl.requireRole(session, userId, projectId, roles: {'owner'});

    final paths = <String?>[];
    final deleted = await session.db.transaction((tx) async {
      final docs = await Document.db.find(
        session,
        where: (t) => t.projectId.equals(projectId),
        transaction: tx,
      );
      if (docs.isNotEmpty && !deleteDocuments) {
        throw ArgumentError('not_empty:${docs.length}');
      }
      paths.addAll(docs.map((d) => d.storagePath));
      await DocumentCleanup.deleteRows(
        session,
        {for (final d in docs) d.id!},
        transaction: tx,
      );
      await ProjectMember.db.deleteWhere(
        session,
        where: (t) => t.projectId.equals(projectId),
        transaction: tx,
      );
      await Project.db.deleteWhere(
        session,
        where: (t) => t.id.equals(projectId),
        transaction: tx,
      );
      return docs.length;
    });
    // After commit, so a failed delete never loses the PDFs.
    await DocumentCleanup.deleteFiles(session, paths);
    return deleted;
  }
}
