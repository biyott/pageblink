import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../sample/sample_pack.dart';

/// The shared demo accounts (ADR 020): one per demo [SamplePack], so a
/// visitor lands in an account whose notes and questions are in their
/// language (research 028). `demo@` is the English one (the original single
/// account), `demo-<locale>@` the others.
///
/// Rolling back to a single-account build: `demo-ko@` sessions that were
/// already issued would be a regular account without limits or protected
/// samples (the old `isDemo` only knows `demo@`). Delete their refresh tokens
/// first: delete the `RefreshToken` rows of the `demo-ko@` auth user (or
/// delete that account).
class DemoUser {
  /// Auth user id -> pack of every demo account this process knows. Filled by
  /// [ensure] / [load]; the guards only look here.
  static final Map<UuidValue, SamplePack> accounts = {};

  static bool isDemo(UuidValue? userId) =>
      userId != null && accounts.containsKey(userId);

  /// The sample pack of a demo account, null for anyone else.
  static SamplePack? packOf(UuidValue? userId) =>
      userId == null ? null : accounts[userId];

  /// Tests only.
  static void debugReset() {
    accounts.clear();
    debugFailCreate.clear();
  }

  /// Tests only: pack ids whose account cannot be created (simulates a failing
  /// insert); an account that already exists is still found.
  static final Set<String> debugFailCreate = {};

  static void _remember(SamplePack pack, UuidValue? id) {
    accounts.removeWhere((_, p) => p.id == pack.id);
    if (id != null) accounts[id] = pack;
  }

  static Future<UuidValue?> _find(Session session, SamplePack pack) async =>
      (await AuthServices.instance.emailIdp.admin.findAccount(
        session,
        email: pack.accountEmail!,
      ))?.authUserId;

  /// Lookup only (nothing is created): lets the guards keep protecting a
  /// demo session that outlives a switched-off flag.
  static Future<void> load(Session session) async {
    for (final pack in SamplePacks.demo) {
      _remember(pack, await _find(session, pack));
    }
  }

  /// Finds or creates every demo account. One that cannot be created is
  /// logged and skipped (the others stay usable); throws only when none of
  /// them is available.
  static Future<void> ensureAll(Session session) async {
    Object? failure;
    StackTrace? trace;
    for (final pack in SamplePacks.demo) {
      try {
        await ensure(session, pack);
      } catch (e, st) {
        session.log(
          'demo account ${pack.id} unavailable',
          level: LogLevel.warning,
          exception: e,
          stackTrace: st,
        );
        failure ??= e;
        trace ??= st;
      }
    }
    if (failure != null && accounts.isEmpty) {
      Error.throwWithStackTrace(failure, trace!);
    }
  }

  /// Finds or creates the account of [pack]. Idempotent and safe when several
  /// instances boot at once. No `UserProfile` is created (the app has no
  /// profile API; research 026 §2). Always checks the database, so it also
  /// recovers when the database was recreated under a running process.
  static Future<UuidValue> ensure(Session session, SamplePack pack) async {
    final admin = AuthServices.instance.emailIdp.admin;
    final email = pack.accountEmail!;

    UuidValue? id = await _find(session, pack);
    if (id == null) {
      try {
        if (debugFailCreate.contains(pack.id)) {
          throw StateError('demo account ${pack.id}: create failed (test)');
        }
        // One transaction (R-C): if the email insert loses a race on the
        // unique index, the AuthUser is rolled back too — no orphan user.
        id = await session.db.transaction((tx) async {
          final user = await AuthServices.instance.authUsers.create(
            session,
            transaction: tx,
          );
          await admin.createEmailAuthentication(
            session,
            authUserId: user.id,
            email: email,
            password: null, // hash '' never validates (research 026 §1)
            transaction: tx,
          );
          return user.id;
        });
      } catch (_) {
        id = await _find(session, pack); // another instance created it first
        if (id == null) rethrow;
      }
    }
    _remember(pack, id);
    return id!;
  }
}
