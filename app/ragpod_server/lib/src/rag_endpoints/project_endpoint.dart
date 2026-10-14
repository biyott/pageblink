import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';
import '../services/acl.dart';

/// Projects share documents between members.
class ProjectEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<Project> create(Session session, String name) async {
    final userId = Acl.requireUser(session);
    return session.db.transaction((tx) async {
      final project = await Project.db.insertRow(
        session,
        Project(name: name, ownerId: userId, createdAt: DateTime.now().toUtc()),
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
    if (!{'editor', 'viewer'}.contains(role))
      throw ArgumentError('role must be editor or viewer');

    final account = await EmailAccount.db.findFirstRow(
      session,
      where: (t) => t.email.equals(email.trim().toLowerCase()),
    );
    final memberId = account?.authUserId;
    if (memberId == null) throw ArgumentError('No user with email $email');

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
}
