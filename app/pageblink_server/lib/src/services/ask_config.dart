import 'dart:io';

import 'package:serverpod/serverpod.dart';

import 'env_int.dart';

/// The Ask history rules (design 030). Read per request, like `DemoConfig`:
/// the password (camelCase) first, then the environment variable; a missing
/// or invalid number falls back to its default, so a typo never breaks Ask.
/// Everything is off until `ASK_HISTORY_ENABLED` is set.
class AskConfig {
  const AskConfig._({
    required this.enabled,
    required this.resumeSeconds,
    required this.viewMinutes,
    required this.maxQuestions,
    required this.listed,
    required this.retentionDays,
    required this.demoRetentionDays,
    required this.contextBudget,
    required this.contextAnswer,
    required this.queryJoin,
    required this.promptMax,
    required this.questionMax,
  });

  /// Master switch for recording, restoring, the lists and the admin view.
  final bool enabled;

  /// A reload within this time of the last activity continues the latest
  /// conversation.
  final int resumeSeconds;

  /// A conversation stays visible this long after its last activity.
  final int viewMinutes;

  /// Questions per conversation (failed and interrupted ones count).
  final int maxQuestions;

  /// Conversations in the user's list.
  final int listed;

  /// Server-side keeping time, normal and demo accounts.
  final int retentionDays;
  final int demoRetentionDays;

  /// Characters of earlier turns handed to the model (newest first), the
  /// length kept of each earlier answer, and the length of the previous
  /// question appended to the search query.
  final int contextBudget;
  final int contextAnswer;
  final int queryJoin;

  /// Whole prompt (system + sources + earlier turns + question).
  final int promptMax;

  /// Longer questions are cut to this.
  final int questionMax;

  /// An answer that has not checkpointed for this long counts as abandoned
  /// (its server died or the stream hung): the next question may go on.
  static const streamStale = Duration(seconds: 30);

  /// Tests only: values by environment variable name, checked first.
  static final Map<String, String> debugValues = {};

  static String? _raw(Session s, String password, String env) =>
      debugValues[env] ?? s.passwords[password] ?? Platform.environment[env];

  static int _int(Session s, String password, String env, int fallback) =>
      positiveInt(_raw(s, password, env), fallback);

  static AskConfig of(Session s) => AskConfig._(
    enabled: truthy(_raw(s, 'askHistoryEnabled', 'ASK_HISTORY_ENABLED')),
    resumeSeconds: _int(
      s,
      'askSessionResumeSeconds',
      'ASK_SESSION_RESUME_SECONDS',
      30,
    ),
    viewMinutes: _int(
      s,
      'askSessionViewMinutes',
      'ASK_SESSION_VIEW_MINUTES',
      30,
    ),
    maxQuestions: _int(
      s,
      'askSessionMaxQuestions',
      'ASK_SESSION_MAX_QUESTIONS',
      10,
    ),
    listed: _int(s, 'askSessionsListed', 'ASK_SESSIONS_LISTED', 5),
    retentionDays: _int(
      s,
      'askHistoryRetentionDays',
      'ASK_HISTORY_RETENTION_DAYS',
      30,
    ),
    demoRetentionDays: _int(
      s,
      'askHistoryDemoRetentionDays',
      'ASK_HISTORY_DEMO_RETENTION_DAYS',
      7,
    ),
    contextBudget: _int(
      s,
      'askContextBudgetChars',
      'ASK_CONTEXT_BUDGET_CHARS',
      8000,
    ),
    contextAnswer: _int(
      s,
      'askContextAnswerChars',
      'ASK_CONTEXT_ANSWER_CHARS',
      800,
    ),
    queryJoin: _int(s, 'askQueryJoinChars', 'ASK_QUERY_JOIN_CHARS', 600),
    promptMax: _int(s, 'askPromptMaxChars', 'ASK_PROMPT_MAX_CHARS', 20000),
    questionMax: _int(
      s,
      'askQuestionMaxChars',
      'ASK_QUESTION_MAX_CHARS',
      2000,
    ),
  );

  /// [text] as a UUID (any case, trimmed), or null when it is not one.
  static UuidValue? parseUuid(String? text) {
    final t = text?.trim().toLowerCase() ?? '';
    if (t.isEmpty) return null;
    try {
      return UuidValue.withValidation(t);
    } catch (_) {
      return null;
    }
  }

  /// `ADMIN_USER_IDS` / `adminUserIds`: comma separated auth user UUIDs.
  /// Parsed on every call, so a changed value applies at once; an entry that
  /// is not a UUID is ignored. Empty means no administrator.
  static Set<UuidValue> adminIds(Session s) {
    final raw = _raw(s, 'adminUserIds', 'ADMIN_USER_IDS');
    final ids = <UuidValue>{};
    for (final part in (raw ?? '').split(',')) {
      // Not a UUID: ignored, and never logged (it may be a typo of a secret).
      final id = parseUuid(part);
      if (id != null) ids.add(id);
    }
    return ids;
  }
}
