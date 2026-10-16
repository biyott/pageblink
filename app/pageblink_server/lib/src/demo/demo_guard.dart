import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import '../services/document_cleanup.dart';
import 'demo_config.dart';
import 'demo_user.dart';

/// Counts uses per KST day (resets at 00:00 KST). In memory only: a restart
/// or a second instance starts from zero again, so the real daily total can
/// exceed [limit] (plan 014 L5). Needs a DB counter if that ever matters.
class DailyCounter {
  final int limit;
  final DateTime Function() _now;
  String _day = '';
  int _used = 0;

  DailyCounter(this.limit, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  void _roll() {
    final kst = _now().toUtc().add(const Duration(hours: 9));
    final day = '${kst.year}-${kst.month}-${kst.day}';
    if (day != _day) {
      _day = day;
      _used = 0;
    }
  }

  int get used {
    _roll();
    return _used;
  }

  int get remaining => (limit - used).clamp(0, limit);

  /// Takes one use; false when the day's limit is already reached.
  bool tryConsume() {
    _roll();
    if (_used >= limit) return false;
    _used++;
    return true;
  }
}

/// The rules that only apply to the demo account (plan 014 §6.4). Every check
/// is a no-op for other users and for the internal seeding session.
class DemoGuard {
  /// Replaced by tests to reset it.
  static DailyCounter askCounter = DailyCounter(demoAskDailyLimit);

  /// Documents older than this are expired.
  static DateTime cutoff([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().subtract(demoRetention);

  /// The internal seeding session (authenticated with [demoSeedAuthId]).
  static bool isSeed(Session session) =>
      session.authenticated?.authId == demoSeedAuthId;

  static bool _applies(Session session, UuidValue userId) =>
      DemoUser.isDemo(userId) && !isSeed(session);

  /// Whether [contentHash] marks a sample of the account's own pack.
  static bool _isSample(UuidValue userId, String contentHash) =>
      DemoUser.packOf(userId)?.hashes.contains(contentHash) ?? false;

  /// Rejects a body/PDF hash that would make the document look like a sample
  /// (it would dodge the limit and the purge, or lock itself).
  static void requireNotSampleHash(
    Session session,
    UuidValue userId,
    String contentHash,
  ) {
    if (_applies(session, userId) && _isSample(userId, contentHash)) {
      throw DemoLimitException(reason: DemoLimitReason.sampleLocked);
    }
  }

  /// Samples cannot be edited, re-indexed or deleted.
  static void requireNotSample(
    Session session,
    UuidValue userId,
    Document document,
  ) {
    if (_applies(session, userId) && _isSample(userId, document.contentHash)) {
      throw DemoLimitException(reason: DemoLimitReason.sampleLocked);
    }
  }

  /// A new note or PDF needs a free slot. Expired documents are purged first
  /// so their slots free up. Not atomic with the insert: concurrent creates
  /// can overshoot by a few (demo-grade, research 026 U7).
  static Future<void> requireCreateSlot(
    Session session,
    UuidValue userId,
  ) async {
    if (!_applies(session, userId)) return;
    await purgeExpired(session);
    if (await countOwn(session, userId) >= demoCreateLimit) {
      throw DemoLimitException(
        reason: DemoLimitReason.createLimit,
        limit: demoCreateLimit,
      );
    }
  }

  /// A demo account's own (non-sample, not yet expired) documents. Samples
  /// are those of the account's pack, so each account counts on its own.
  static Future<int> countOwn(Session session, UuidValue demoId) {
    final samples = DemoUser.packOf(demoId)?.hashes ?? <String>{};
    return Document.db.count(
      session,
      where: (t) =>
          t.ownerId.equals(demoId) &
          t.contentHash.notInSet(samples) &
          (t.createdAt >= cutoff()),
    );
  }

  /// Demo cannot create projects, nor be invited to one. Pass the acting
  /// user, or the invited user.
  static void requireNoProject(UuidValue userId) {
    if (DemoUser.isDemo(userId)) {
      throw DemoLimitException(reason: DemoLimitReason.projectLocked);
    }
  }

  /// Takes one of the shared daily questions.
  static void consumeAsk(Session session, UuidValue userId) {
    if (!_applies(session, userId)) return;
    if (!askCounter.tryConsume()) {
      throw DemoLimitException(
        reason: DemoLimitReason.askLimit,
        limit: demoAskDailyLimit,
      );
    }
  }

  /// Deletes expired non-sample documents of every demo account (with their
  /// files) and demo refresh tokens older than [demoRetention] (research 026
  /// §8, §9.2). No-op while no demo account is known or the feature is off.
  static Future<void> purgeExpired(Session session) async {
    if (DemoUser.accounts.isEmpty || !DemoConfig.enabled(session)) return;
    final limit = cutoff();

    for (final MapEntry(key: demoId, value: pack)
        in DemoUser.accounts.entries.toList()) {
      final stale = await Document.db.find(
        session,
        where: (t) =>
            t.ownerId.equals(demoId) &
            t.contentHash.notInSet(pack.hashes) &
            (t.createdAt < limit),
      );
      if (stale.isEmpty) continue;
      await DocumentCleanup.deleteFiles(
        session,
        stale.map((d) => d.storagePath),
      );
      await session.db.transaction(
        (tx) => DocumentCleanup.deleteRows(session, {
          for (final d in stale) d.id!,
        }, transaction: tx),
      );
    }

    await RefreshToken.db.deleteWhere(
      session,
      where: (t) => t.method.equals('demo') & (t.createdAt < limit),
    );
  }
}
