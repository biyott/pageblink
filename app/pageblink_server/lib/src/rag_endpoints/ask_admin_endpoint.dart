import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/acl.dart';
import '../services/ask_config.dart';
import '../services/ask_history_store.dart';
import 'ask_history_endpoint.dart';

/// Read-only conversation list for administrators (`ADMIN_USER_IDS`). The
/// server decides who is one on every call; there is no write method.
class AskAdminEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Where the console lines go (tests replace it), like
  /// `MaintenanceTimer.log`: Cloud shows stdout, not the session log table.
  static void Function(String line) out = stdout.writeln;

  /// One page of conversations with their messages, newest first, and the
  /// answers per model over the whole filtered range.
  Future<AskAdminPage> listSessions(
    Session session,
    AskAdminFilter filter,
  ) async {
    final adminId = Acl.requireUser(session);
    if (!AskHistoryEndpoint.isAdmin(session)) {
      out(deniedLine(adminId));
      throw AccessDeniedException();
    }
    final page = await AskStore.run(
      session,
      (s) => AskStore.adminPage(s, filter),
    );
    // Who looked, at what scope: never what was in the conversations.
    session.log(adminAccessLine(adminId, filter, page.items.length));
    out(adminConsoleLine(adminId, filter, page.items.length));
    return page;
  }

  /// The audit line of one list call (ids and counts only).
  static String adminAccessLine(
    UuidValue adminId,
    AskAdminFilter filter,
    int returned,
  ) {
    final wanted = filter.userId?.trim() ?? '';
    final user = wanted.isEmpty
        ? '-'
        : (AskConfig.parseUuid(wanted)?.toString() ?? 'invalid');
    String t(DateTime? d) => d == null ? '-' : d.toUtc().toIso8601String();
    return 'ask-admin: list by=$adminId user=$user '
        'from=${t(filter.from)} to=${t(filter.to)} '
        'page=${filter.pageSize ?? AskStore.adminDefaultPage} returned=$returned';
  }

  /// The console line of one list call: who, whether a user / period filter
  /// was set, page size and count. No user text, no target ids.
  static String adminConsoleLine(
    UuidValue adminId,
    AskAdminFilter filter,
    int returned,
  ) {
    String has(Object? v) => v == null ? 'no' : 'yes';
    final user = (filter.userId?.trim() ?? '').isEmpty ? 'no' : 'yes';
    return 'ask-admin: list by=$adminId user=$user '
        'from=${has(filter.from)} to=${has(filter.to)} '
        'page=${filter.pageSize ?? AskStore.adminDefaultPage} returned=$returned';
  }

  /// A refused attempt (not an administrator).
  static String deniedLine(UuidValue userId) => 'ask-admin: denied by=$userId';
}
