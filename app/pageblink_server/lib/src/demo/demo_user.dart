import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import 'demo_config.dart';

/// The shared demo account (ADR 020).
class DemoUser {
  /// Auth user id of the demo account; null until [ensure] ran in this
  /// process (or when the feature is off). Guards only compare against this.
  static UuidValue? demoUserId;

  static bool isDemo(UuidValue? userId) =>
      userId != null && userId == demoUserId;

  /// Lookup only (nothing is created): lets the guards keep protecting a
  /// demo session that outlives a switched-off flag. Returns null if absent.
  static Future<UuidValue?> load(Session session) async {
    final id = (await AuthServices.instance.emailIdp.admin.findAccount(
      session,
      email: demoEmail,
    ))?.authUserId;
    return demoUserId = id;
  }

  /// Finds or creates the demo user. Idempotent and safe when several
  /// instances boot at once. No `UserProfile` is created (the app has no
  /// profile API; research 026 §2). Always checks the database, so it also
  /// recovers when the database was recreated under a running process.
  static Future<UuidValue> ensure(Session session) async {
    final admin = AuthServices.instance.emailIdp.admin;
    Future<UuidValue?> find() async =>
        (await admin.findAccount(session, email: demoEmail))?.authUserId;

    UuidValue? id = await find();
    if (id == null) {
      try {
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
            email: demoEmail,
            password: null, // hash '' never validates (research 026 §1)
            transaction: tx,
          );
          return user.id;
        });
      } catch (_) {
        id = await find(); // another instance created it first
        if (id == null) rethrow;
      }
    }
    final resolved = id!;
    demoUserId = resolved;
    return resolved;
  }
}
