import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../demo/demo_user.dart';
import '../generated/protocol.dart';
import '../services/acl.dart';
import '../services/ask_config.dart';
import '../services/ask_history_store.dart';

/// Stored Ask conversations of the signed-in user (design 030). Every method
/// is a no-op or an empty answer while `ASK_HISTORY_ENABLED` is off. Demo
/// visitors share one account, so they send their browser's [visitorKey] and
/// only see their own conversations.
class AskHistoryEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Whether the app shows the history UI at all, and its rules.
  Future<AskHistoryStatus> historyStatus(Session session) async {
    final userId = Acl.requireUser(session);
    final cfg = AskConfig.of(session);
    if (!cfg.enabled) return AskHistoryStatus(enabled: false);
    return AskHistoryStatus(
      enabled: true,
      questionLimit: cfg.maxQuestions,
      visibleMinutes: cfg.viewMinutes,
      retentionDays: DemoUser.isDemo(userId)
          ? cfg.demoRetentionDays
          : cfg.retentionDays,
      questionMaxChars: cfg.questionMax,
      isAdmin: isAdmin(session),
    );
  }

  /// The recent conversations and, after a reload within the resume window,
  /// the one to continue. The server decides by its own clock.
  Future<AskRestore> restore(Session session, [String? visitorKey]) async {
    final userId = Acl.requireUser(session);
    final cfg = AskConfig.of(session);
    if (!cfg.enabled) return AskRestore(recent: const []);
    final ctx = AskStore.ctx(userId, visitorKey);
    return AskStore.run(session, (s) => AskStore.restore(s, ctx, cfg));
  }

  /// One conversation of the recent list; null when it is gone, hidden, not
  /// the caller's or past its viewing window.
  Future<AskSessionView?> open(
    Session session,
    int sessionId, [
    String? visitorKey,
  ]) async {
    final userId = Acl.requireUser(session);
    final cfg = AskConfig.of(session);
    if (!cfg.enabled) return null;
    final ctx = AskStore.ctx(userId, visitorKey);
    return AskStore.run(
      session,
      (s) => AskStore.open(s, ctx, sessionId, cfg),
    );
  }

  /// "Delete" from the list. Only hides: the server keeps it for the
  /// retention period.
  Future<void> hide(
    Session session,
    int sessionId, [
    String? visitorKey,
  ]) async {
    final userId = Acl.requireUser(session);
    if (!AskConfig.of(session).enabled) return;
    final ctx = AskStore.ctx(userId, visitorKey);
    await AskStore.run(session, (s) => AskStore.hide(s, ctx, sessionId));
  }

  /// The caller is listed in `ADMIN_USER_IDS`, history is on, and the
  /// account is not a shared demo account. Decided on every call.
  static bool isAdmin(Session session) {
    final userId = session.authenticated?.authUserId;
    if (userId == null || !AskConfig.of(session).enabled) return false;
    return !DemoUser.isDemo(userId) &&
        AskConfig.adminIds(session).contains(userId);
  }
}
