import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import '../sample/sample_pack.dart';
import '../services/acl.dart';
import 'demo_config.dart';
import 'demo_guard.dart';
import 'demo_seed.dart';
import 'demo_user.dart';

/// "Try the demo": a shared, fully working account with sample content, one
/// per language (ADR 020, plan 014, research 028). Both methods are public; with `demoEnabled` off the
/// feature does not exist (`status().enabled == false`, `signIn` refuses).
class DemoEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// What the login screen and the demo banner need. Never throws for a
  /// disabled or broken demo: that is just `enabled: false`.
  Future<DemoStatus> status(Session session) async {
    if (!DemoConfig.enabled(session)) return DemoStatus(enabled: false);
    try {
      await DemoUser.ensureAll(session);
    } catch (e, st) {
      session.log(
        'demo user unavailable',
        level: LogLevel.warning,
        exception: e,
        stackTrace: st,
      );
      return DemoStatus(enabled: false);
    }
    final userId = session.authenticated?.authUserId;
    final isDemo = DemoUser.isDemo(userId);
    return DemoStatus(
      enabled: true,
      isDemo: isDemo,
      createLimit: demoCreateLimit,
      createRemaining: isDemo
          ? (demoCreateLimit - await DemoGuard.countOwn(session, userId!))
                .clamp(0, demoCreateLimit)
          : null,
      askLimit: demoAskDailyLimit,
      askRemaining: isDemo ? DemoGuard.askCounter.remaining : null,
    );
  }

  /// Signs in as the demo account of [locale]'s language (`ko*` is Korean,
  /// anything else, or none, is English: what an older app sends). If that
  /// account cannot be found or created, the English one is used instead.
  /// Refused when the flag is off.
  ///
  /// The caller must not be signed in as someone else: the server then throws
  /// `SignInWhileAuthenticatedException`, so the app signs out first
  /// (`client.auth.signOutDevice()`) and then hands the result to
  /// `client.auth.updateSignedInUser`.
  Future<AuthSuccess> signIn(Session session, [String? locale]) async {
    if (!DemoConfig.enabled(session)) throw AccessDeniedException();
    final pack = SamplePacks.forLocale(locale, SampleAudience.demo);
    // Not just a lookup: if boot skipped or failed, create it here (R-A).
    // If that fails for a non-English pack, fall back to the English account
    // (when it fails too, the error stays).
    UuidValue demoId;
    try {
      demoId = await DemoUser.ensure(session, pack);
    } catch (e, st) {
      if (pack.id == SamplePacks.demoEn.id) rethrow;
      session.log(
        'demo account ${pack.id} unavailable, falling back to '
        '${SamplePacks.demoEn.id}',
        level: LogLevel.warning,
        exception: e,
        stackTrace: st,
      );
      demoId = await DemoUser.ensure(session, SamplePacks.demoEn);
    }
    await DemoGuard.purgeExpired(session);
    // Self-heal samples that failed or never got seeded (throttled).
    DemoSeed.startBackground(session.serverpod, force: false);
    return AuthServices.instance.tokenManager.issueToken(
      session,
      authUserId: demoId,
      method: 'demo',
      scopes: const <Scope>{},
    );
  }
}
