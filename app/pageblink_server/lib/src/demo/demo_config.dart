import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../services/env_int.dart';

/// Own documents (notes + PDFs, samples excluded) the demo account may hold.
const demoCreateLimit = 5;

/// Questions per day for all demo accounts and visitors together.
const demoAskDailyLimit = 50;

/// Own demo documents older than this are deleted. (Demo sign-ins end by
/// [DemoSessionConfig.idle] / [DemoSessionConfig.max] instead.)
const demoRetention = Duration(hours: 24);

/// `AuthenticationInfo.authId` of the internal seeding session. Real tokens
/// carry a refresh-token UUID there, so a client can never produce this value.
const demoSeedAuthId = 'demo-seed';

bool _truthy(String? v) =>
    const {'true', '1', 'yes', 'on'}.contains(v?.trim().toLowerCase());

/// The `demoEnabled` flag (off by default). Read like `RagServices._secret`:
/// password `demoEnabled` first, then env `DEMO_ENABLED` (research 026 §5).
/// passwords.yaml values must be strings: `demoEnabled: 'true'`.
class DemoConfig {
  static const _password = 'demoEnabled';
  static const _env = 'DEMO_ENABLED';

  /// Tests only: forces the flag without touching passwords or environment.
  static bool? debugOverride;

  /// At boot (no session yet).
  static bool enabledForPod(Serverpod pod) =>
      debugOverride ??
      _truthy(pod.getPassword(_password) ?? Platform.environment[_env]);

  /// While serving a request.
  static bool enabled(Session session) =>
      debugOverride ??
      _truthy(session.passwords[_password] ?? Platform.environment[_env]);
}

/// How long a demo sign-in lasts (plan 014, task 10). A `method == 'demo'`
/// refresh token is deleted when it was not used (rotated) for the idle time,
/// or when it was issued longer ago than the absolute limit. Read like
/// [DemoConfig]: password (`demoSessionIdleMinutes`, `demoSessionMaxMinutes`),
/// then env `DEMO_SESSION_IDLE_MINUTES` (60) / `DEMO_SESSION_MAX_MINUTES` (240).
class DemoSessionConfig {
  static const idleDefault = 60;
  static const maxDefault = 240;

  static Duration idle(Session session) => Duration(
    minutes: positiveInt(
      session.passwords['demoSessionIdleMinutes'] ??
          Platform.environment['DEMO_SESSION_IDLE_MINUTES'],
      idleDefault,
    ),
  );

  static Duration max(Session session) => Duration(
    minutes: positiveInt(
      session.passwords['demoSessionMaxMinutes'] ??
          Platform.environment['DEMO_SESSION_MAX_MINUTES'],
      maxDefault,
    ),
  );
}
