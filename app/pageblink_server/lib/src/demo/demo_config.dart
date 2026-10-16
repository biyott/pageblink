import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// The demo account's email. `.invalid` is a reserved TLD (RFC 2606): mail
/// never arrives, so nobody can reset its password (research 026 §1, §4).
const demoEmail = 'demo@pageblink.invalid';

/// Own documents (notes + PDFs, samples excluded) the demo account may hold.
const demoCreateLimit = 5;

/// Questions per day for the whole demo account (all visitors together).
const demoAskDailyLimit = 50;

/// Own demo documents and demo refresh tokens older than this are deleted.
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
