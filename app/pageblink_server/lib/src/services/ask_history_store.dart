import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../demo/demo_user.dart';
import '../generated/protocol.dart';
import '../rag/chat_context.dart';
import 'ask_config.dart';

/// Who is asking, as far as the history is concerned. Demo accounts are
/// shared by many visitors, so they are told apart by a browser-held key
/// (stored only as a hash); one without a valid key gets no history at all.
class AskCtx {
  const AskCtx(this.userId, this.isDemo, this.keyHash);

  final UuidValue userId;
  final bool isDemo;
  final String? keyHash;

  /// History may be read and written for this caller.
  bool get ok => !isDemo || keyHash != null;
}

/// What `ask` found out about the conversation before it starts. [row] is
/// null for a new conversation; [legacy] marks a request from an app that
/// sends no conversation id (recorded hidden, outside every limit).
class AskPlan {
  const AskPlan({this.row, this.legacy = false, this.past = const []});

  final AskSession? row;
  final bool legacy;

  /// The finished turns of the conversation, oldest first.
  final List<AskMessage> past;
}

/// The stored question being answered.
class AskHandle {
  const AskHandle(this.sessionId, this.messageId, this.count, this.legacy);

  final int sessionId;
  final int messageId;
  final int count;
  final bool legacy;
}

/// Everything about Ask conversations that touches the database (design 030).
///
/// Every method takes a session made by [run]: logging is off there, because
/// the ORM writes values into the SQL text, and a slow or failed INSERT would
/// then copy the question into the query log (design 030 F8). Errors are
/// reported by type only, never by message, for the same reason.
class AskStore {
  static final _keyPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  /// Runs [body] with a session that logs nothing and outlives the request
  /// (a cancelled request closes its own session).
  static Future<T> run<T>(Session from, Future<T> Function(Session) body) =>
      from.serverpod.withSession(body, enableLogging: false);

  static void warn(String what, Object e) =>
      stderr.writeln('ask-history: $what failed (${e.runtimeType})');

  static AskCtx ctx(UuidValue userId, String? visitorKey) {
    final demo = DemoUser.isDemo(userId);
    final valid = visitorKey != null && _keyPattern.hasMatch(visitorKey);
    return AskCtx(
      userId,
      demo,
      demo && valid ? sha256.convert(utf8.encode(visitorKey)).toString() : null,
    );
  }

  /// The caller's own, not hidden conversations.
  static Expression<dynamic> _mine(AskSessionTable t, AskCtx c) =>
      t.ownerId.equals(c.userId) &
      (c.isDemo
          ? t.visitorKeyHash.equals(c.keyHash)
          : t.visitorKeyHash.equals(null)) &
      t.hiddenAt.equals(null);

  static DateTime _now() => DateTime.now().toUtc();

  // ── Asking ──────────────────────────────────────────────────────────

  /// Reads the conversation a question goes to and applies the rules (no
  /// writes). Throws [AskLimitException] for `expired`, `busy` and
  /// `questionLimit`.
  static Future<AskPlan> plan(
    Session s,
    AskCtx c,
    int? sessionId,
    AskConfig cfg,
  ) async {
    if (sessionId == null) return const AskPlan(legacy: true);
    if (sessionId <= 0) return const AskPlan();
    final row = await AskSession.db.findFirstRow(
      s,
      where: (t) => t.id.equals(sessionId) & _mine(t, c),
    );
    final now = _now();
    if (row == null ||
        now.difference(row.lastActiveAt) > Duration(minutes: cfg.viewMinutes)) {
      throw AskLimitException(reason: AskLimitReason.expired);
    }
    final since = row.streamingSince;
    if (since != null && now.difference(since) <= AskConfig.streamStale) {
      throw AskLimitException(reason: AskLimitReason.busy);
    }
    if (row.questionCount >= cfg.maxQuestions) {
      throw AskLimitException(
        reason: AskLimitReason.questionLimit,
        limit: cfg.maxQuestions,
      );
    }
    final messages = await AskMessage.db.find(
      s,
      where: (t) => t.sessionId.equals(row.id!) & t.status.equals('done'),
      orderBy: (t) => t.seq,
    );
    return AskPlan(row: row, past: messages);
  }

  /// Stores the question: a new conversation, or the next number of an
  /// existing one. The one UPDATE that takes the number also checks that no
  /// other question is being answered, so two instances cannot both win.
  static Future<AskHandle> begin(
    Session s,
    AskCtx c,
    AskPlan plan,
    AskConfig cfg, {
    required String question,
    required String? locale,
    required List<int> projectIds,
    required bool includePersonal,
  }) async {
    final now = _now();
    final row = plan.row;
    Future<AskMessage> insert(Transaction tx, int sessionId, int seq) =>
        AskMessage.db.insertRow(
          s,
          AskMessage(
            sessionId: sessionId,
            seq: seq,
            question: question,
            status: 'streaming',
            projectIds: projectIds,
            includePersonal: includePersonal,
            createdAt: now,
            updatedAt: now,
          ),
          transaction: tx,
        );

    if (row == null) {
      final handle = await s.db.transaction((tx) async {
        final created = await AskSession.db.insertRow(
          s,
          AskSession(
            ownerId: c.userId,
            visitorKeyHash: c.keyHash,
            isDemo: c.isDemo,
            title: titleOf(question),
            locale: locale == null ? null : (locale == 'ko' ? 'ko' : 'en'),
            questionCount: 1,
            createdAt: now,
            lastActiveAt: now,
            streamingSince: now,
            hiddenAt: plan.legacy ? now : null,
          ),
          transaction: tx,
        );
        final m = await insert(tx, created.id!, 1);
        return AskHandle(created.id!, m.id!, 1, plan.legacy);
      });
      _sweepSometimes(s, cfg);
      return handle;
    }

    final stale = now.subtract(AskConfig.streamStale);
    return s.db.transaction((tx) async {
      final won = await AskSession.db.updateWhere(
        s,
        columnValues: (t) => [
          t.questionCount(row.questionCount + 1),
          t.lastActiveAt(now),
          t.streamingSince(now),
        ],
        where: (t) =>
            t.id.equals(row.id!) &
            t.questionCount.equals(row.questionCount) &
            t.hiddenAt.equals(null) &
            (t.streamingSince.equals(null) | (t.streamingSince < stale)),
        transaction: tx,
      );
      if (won.isEmpty) throw AskLimitException(reason: AskLimitReason.busy);
      if (row.streamingSince != null) {
        // The abandoned answer of an earlier question.
        await AskMessage.db.updateWhere(
          s,
          columnValues: (t) => [t.status('interrupted')],
          where: (t) =>
              t.sessionId.equals(row.id!) & t.status.equals('streaming'),
          transaction: tx,
          noReturn: true,
        );
      }
      final m = await insert(tx, row.id!, row.questionCount + 1);
      return AskHandle(row.id!, m.id!, row.questionCount + 1, false);
    });
  }

  /// A partial answer, so that a reload or a dying server loses at most a
  /// few seconds. Also keeps the conversation "active" and its stream fresh.
  static Future<void> checkpoint(
    Session s,
    AskHandle h, {
    required String answer,
    required List<Citation> citations,
    required String? modelId,
    required bool fallback,
  }) async {
    final now = _now();
    await AskMessage.db.updateWhere(
      s,
      columnValues: (t) => [
        t.answer(answer),
        t.citations(citations),
        t.modelId(modelId),
        t.fallback(fallback),
        t.updatedAt(now),
      ],
      where: (t) => t.id.equals(h.messageId) & t.status.equals('streaming'),
      noReturn: true,
    );
    await AskSession.db.updateWhere(
      s,
      columnValues: (t) => [t.lastActiveAt(now), t.streamingSince(now)],
      where: (t) => t.id.equals(h.sessionId),
      noReturn: true,
    );
  }

  /// Ends the question: [status] is `done`, `error` or `interrupted`.
  /// [errorCode] is a short code, never an error message.
  static Future<void> finish(
    Session s,
    AskHandle h, {
    required String status,
    required String answer,
    required List<Citation> citations,
    required String? modelId,
    required bool fallback,
    required String? errorCode,
  }) async {
    final now = _now();
    await s.db.transaction((tx) async {
      await AskMessage.db.updateWhere(
        s,
        columnValues: (t) => [
          t.status(status),
          t.answer(answer),
          t.citations(citations),
          t.modelId(modelId),
          t.fallback(fallback),
          t.errorCode(errorCode),
          t.updatedAt(now),
        ],
        where: (t) => t.id.equals(h.messageId),
        transaction: tx,
        noReturn: true,
      );
      await AskSession.db.updateWhere(
        s,
        columnValues: (t) => [t.lastActiveAt(now), t.streamingSince(null)],
        where: (t) => t.id.equals(h.sessionId),
        transaction: tx,
        noReturn: true,
      );
    });
  }

  // ── The user's own conversations ────────────────────────────────────

  static AskMessageView _view(AskMessage m, AskSession row, DateTime now) {
    // A stream that stopped checkpointing is shown as cut off, without a write.
    final abandoned =
        m.status == 'streaming' &&
        (row.streamingSince == null ||
            now.difference(m.updatedAt) > AskConfig.streamStale);
    return AskMessageView(
      seq: m.seq,
      question: m.question,
      answer: m.answer,
      status: abandoned ? 'interrupted' : m.status,
      errorCode: m.errorCode,
      citations: m.citations ?? const [],
      modelId: m.modelId,
      fallback: m.fallback,
      createdAt: m.createdAt,
    );
  }

  static Future<Map<int, List<AskMessage>>> _messagesOf(
    Session s,
    Iterable<int> sessionIds,
  ) async {
    final out = <int, List<AskMessage>>{};
    if (sessionIds.isEmpty) return out;
    final all = await AskMessage.db.find(
      s,
      where: (t) => t.sessionId.inSet(sessionIds.toSet()),
      orderBy: (t) => t.seq,
    );
    for (final m in all) {
      (out[m.sessionId] ??= []).add(m);
    }
    return out;
  }

  static AskSessionView _sessionView(
    AskSession row,
    List<AskMessage> messages,
    AskConfig cfg,
  ) {
    final now = _now();
    return AskSessionView(
      id: row.id!,
      title: row.title,
      questionCount: row.questionCount,
      questionLimit: cfg.maxQuestions,
      lastActiveAt: row.lastActiveAt,
      messages: [for (final m in messages) _view(m, row, now)],
    );
  }

  /// The visible conversations (activity within the viewing window), newest
  /// first, at most the listed count; and the one to resume, if any.
  static Future<AskRestore> restore(Session s, AskCtx c, AskConfig cfg) async {
    if (!c.ok) return AskRestore(recent: const []);
    final now = _now();
    final since = now.subtract(Duration(minutes: cfg.viewMinutes));
    final rows = await AskSession.db.find(
      s,
      where: (t) => _mine(t, c) & (t.lastActiveAt >= since),
      orderByList: (t) => [t.lastActiveAt.desc()],
      limit: cfg.listed,
    );
    AskSessionView? current;
    if (rows.isNotEmpty &&
        now.difference(rows.first.lastActiveAt) <=
            Duration(seconds: cfg.resumeSeconds)) {
      final messages = await _messagesOf(s, [rows.first.id!]);
      current = _sessionView(rows.first, messages[rows.first.id!] ?? [], cfg);
    }
    return AskRestore(
      current: current,
      recent: [
        for (final r in rows)
          AskSessionSummary(
            id: r.id!,
            title: r.title,
            questionCount: r.questionCount,
            lastActiveAt: r.lastActiveAt,
          ),
      ],
    );
  }

  /// One of the caller's conversations still in its viewing window.
  static Future<AskSessionView?> open(
    Session s,
    AskCtx c,
    int sessionId,
    AskConfig cfg,
  ) async {
    if (!c.ok) return null;
    final since = _now().subtract(Duration(minutes: cfg.viewMinutes));
    final row = await AskSession.db.findFirstRow(
      s,
      where: (t) =>
          t.id.equals(sessionId) & _mine(t, c) & (t.lastActiveAt >= since),
    );
    if (row == null) return null;
    final messages = await _messagesOf(s, [row.id!]);
    return _sessionView(row, messages[row.id!] ?? [], cfg);
  }

  /// "Delete" from the user's list: hidden, kept on the server for the
  /// retention period.
  static Future<void> hide(Session s, AskCtx c, int sessionId) async {
    if (!c.ok) return;
    await AskSession.db.updateWhere(
      s,
      columnValues: (t) => [t.hiddenAt(_now())],
      where: (t) => t.id.equals(sessionId) & _mine(t, c),
      noReturn: true,
    );
  }

  // ── Administrators ──────────────────────────────────────────────────

  static const adminDefaultPage = 20;
  static const adminMaxPage = 50;

  static Future<AskAdminPage> adminPage(Session s, AskAdminFilter f) async {
    final owner = AskConfig.parseUuid(f.userId);
    if ((f.userId?.trim() ?? '').isNotEmpty && owner == null) {
      return AskAdminPage(items: const [], models: const []);
    }
    final size = (f.pageSize ?? adminDefaultPage).clamp(1, adminMaxPage);
    final rows = await AskSession.db.find(
      s,
      where: (t) {
        final conds = <Expression<dynamic>>[
          if (owner != null) t.ownerId.equals(owner),
          if (f.from != null) t.lastActiveAt >= f.from!.toUtc(),
          if (f.to != null) t.lastActiveAt <= f.to!.toUtc(),
          if (f.beforeActiveAt != null)
            (t.lastActiveAt < f.beforeActiveAt!.toUtc()) |
                (t.lastActiveAt.equals(f.beforeActiveAt!.toUtc()) &
                    (t.id < (f.beforeId ?? 0))),
        ];
        return conds.isEmpty ? t.id > 0 : conds.reduce((a, b) => a & b);
      },
      orderByList: (t) => [t.lastActiveAt.desc(), t.id.desc()],
      limit: size + 1,
    );
    final page = rows.take(size).toList();
    final messages = await _messagesOf(s, [for (final r in page) r.id!]);
    final now = _now();
    return AskAdminPage(
      items: [
        for (final r in page)
          AskAdminSession(
            id: r.id!,
            ownerId: r.ownerId.toString(),
            ownerLabel: r.isDemo
                ? (DemoUser.packOf(r.ownerId)?.id ?? 'demo')
                : r.ownerId.toString(),
            isDemo: r.isDemo,
            hidden: r.hiddenAt != null,
            title: r.title,
            locale: r.locale,
            questionCount: r.questionCount,
            createdAt: r.createdAt,
            lastActiveAt: r.lastActiveAt,
            messages: [for (final m in messages[r.id!] ?? []) _view(m, r, now)],
          ),
      ],
      nextBeforeActiveAt: rows.length > size ? page.last.lastActiveAt : null,
      nextBeforeId: rows.length > size ? page.last.id : null,
      models: await _modelStats(s, owner, f.from, f.to),
    );
  }

  static Future<List<AskModelStat>> _modelStats(
    Session s,
    UuidValue? owner,
    DateTime? from,
    DateTime? to,
  ) async {
    final where = <String>['m."modelId" IS NOT NULL'];
    final params = <String, Object?>{};
    if (owner != null) {
      where.add('s."ownerId" = @owner::uuid');
      params['owner'] = owner.toString();
    }
    if (from != null) {
      where.add('s."lastActiveAt" >= @from::timestamp');
      params['from'] = from.toUtc();
    }
    if (to != null) {
      where.add('s."lastActiveAt" <= @to::timestamp');
      params['to'] = to.toUtc();
    }
    final result = await s.db.unsafeQuery(
      'SELECT m."modelId", count(*), count(*) FILTER (WHERE m."fallback") '
      'FROM ask_message m JOIN ask_session s ON s.id = m."sessionId" '
      'WHERE ${where.join(' AND ')} '
      'GROUP BY m."modelId" ORDER BY count(*) DESC, m."modelId"',
      parameters: QueryParameters.named(params),
    );
    return [
      for (final row in result)
        AskModelStat(
          modelId: row[0] as String,
          answers: row[1] as int,
          fallbacks: row[2] as int,
        ),
    ];
  }

  // ── Keeping time ────────────────────────────────────────────────────

  /// Deletes the conversations (and, by cascade, their messages) past the
  /// retention time, demo accounts' first (shorter), at most [batch] per
  /// round; [rounds] caps the rounds. Also settles answers that were
  /// abandoned while streaming. Idempotent: instances may overlap. Returns
  /// the number of conversations deleted.
  static Future<int> purge(
    Session s,
    AskConfig cfg, {
    DateTime? now,
    int batch = 200,
    int rounds = 1000,
  }) async {
    final t = now ?? _now();
    var total = 0;
    for (final (demoOnly, days) in [
      (true, cfg.demoRetentionDays),
      (false, cfg.retentionDays),
    ]) {
      final cutoff = t.subtract(Duration(days: days));
      for (var i = 0; i < rounds; i++) {
        final rows = await AskSession.db.find(
          s,
          where: (x) =>
              (demoOnly ? x.isDemo.equals(true) : x.id > 0) &
              (x.lastActiveAt < cutoff),
          orderBy: (x) => x.lastActiveAt,
          limit: batch,
        );
        if (rows.isEmpty) break;
        final ids = {for (final r in rows) r.id!};
        final gone = await AskSession.db.deleteWhere(
          s,
          where: (x) => x.id.inSet(ids) & (x.lastActiveAt < cutoff),
        );
        total += gone.length;
        if (rows.length < batch || gone.isEmpty) break;
      }
    }
    // An answer abandoned while streaming (server died): settle it so the
    // data matches what the lists already show.
    final stuck = await AskSession.db.find(
      s,
      where: (x) => x.streamingSince < t.subtract(const Duration(minutes: 5)),
      limit: batch,
    );
    if (stuck.isNotEmpty) {
      final ids = {for (final r in stuck) r.id!};
      await AskMessage.db.updateWhere(
        s,
        columnValues: (m) => [m.status('interrupted')],
        where: (m) => m.sessionId.inSet(ids) & m.status.equals('streaming'),
        noReturn: true,
      );
      await AskSession.db.updateWhere(
        s,
        columnValues: (x) => [x.streamingSince(null)],
        where: (x) => x.id.inSet(ids),
        noReturn: true,
      );
    }
    return total;
  }

  static DateTime? _lastSweep;

  /// The sweep started by the latest new conversation (tests await it).
  static Future<void>? sweeping;

  static void debugResetSweep() {
    _lastSweep = null;
    sweeping = null;
  }

  /// A new conversation also deletes a few expired ones, at most once per
  /// five minutes per process: the hourly job does the bulk, this keeps the
  /// retention honest if that job is not running.
  static void _sweepSometimes(Session s, AskConfig cfg) {
    final now = DateTime.now();
    final last = _lastSweep;
    if (last != null && now.difference(last) < const Duration(minutes: 5)) {
      return;
    }
    _lastSweep = now;
    sweeping = run(
      s,
      (x) => purge(x, cfg, batch: 20, rounds: 1),
    ).then<void>((_) {}).catchError((Object e) => warn('sweep', e));
  }
}
