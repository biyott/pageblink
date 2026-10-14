import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

/// Access rules. The server derives memberships itself and never trusts
/// project ids sent by the client (ADR 010).
class Acl {
  static UuidValue requireUser(Session session) {
    final userId = session.authenticated?.authUserId;
    if (userId == null) throw AccessDeniedException();
    return userId;
  }

  static Future<Set<int>> memberProjectIds(
    Session session,
    UuidValue userId,
  ) async {
    final rows = await ProjectMember.db.find(
      session,
      where: (t) => t.userId.equals(userId),
    );
    return {for (final r in rows) r.projectId};
  }

  static Future<ProjectMember> requireRole(
    Session session,
    UuidValue userId,
    int projectId, {
    Set<String> roles = const {'owner', 'editor', 'viewer'},
  }) async {
    final member = await ProjectMember.db.findFirstRow(
      session,
      where: (t) => t.projectId.equals(projectId) & t.userId.equals(userId),
    );
    if (member == null || !roles.contains(member.role)) {
      throw AccessDeniedException();
    }
    return member;
  }
}

class AccessDeniedException implements Exception {
  @override
  String toString() => 'Access denied';
}
