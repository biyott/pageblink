import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../demo/demo_config.dart';
import '../demo/demo_guard.dart';
import '../demo/demo_user.dart';
import 'ask_config.dart';
import 'ask_history_store.dart';
import 'chunk_migration.dart' show SessionScope;

/// One periodic cleanup. [every] is a lower bound: the timer ticks every
/// [MaintenanceTimer.tick], so a job runs at most one tick late. [run]
/// returns how many rows (or documents) it deleted.
class MaintenanceJob {
  const MaintenanceJob(this.name, this.every, this.run);
  final String name;
  final Duration every;
  final Future<int> Function(Session session) run;
}

/// Periodic cleanup inside the server process (Serverpod's scheduled future
/// calls are not available on the current plan). Every job is idempotent
/// (deletes only), so several instances may run it at the same time.
///
/// Add future cleanups to [jobs]. A failing job is logged
/// without any user content and retried on the next tick; it never stops the
/// others or the timer.
class MaintenanceTimer {
  static const tick = Duration(minutes: 5);

  /// Demo sign-ins past idle / absolute limit (every tick).
  static final demoTokens = MaintenanceJob('demo-tokens', tick, (s) async {
    if (!DemoConfig.enabled(s)) return 0;
    // Accounts not ready at boot (or created by another instance): look up.
    if (DemoUser.accounts.isEmpty) await DemoUser.load(s);
    return DemoGuard.purgeExpiredTokens(s);
  });

  /// Expired refresh tokens of every user (JWT lifetime). Nothing else calls
  /// `deleteExpiredRefreshTokens`, so without this the table only grows.
  static final authTokens = MaintenanceJob(
    'auth-tokens',
    const Duration(hours: 1),
    (s) async {
      final jwt = AuthServices.getTokenManager<JwtTokenManager>().jwt;
      // The library call returns nothing: count what it will delete first.
      final oldest = DateTime.now().subtract(jwt.config.refreshTokenLifetime);
      final expired = await RefreshToken.db.count(
        s,
        where: (t) => t.lastUpdatedAt < oldest,
      );
      await jwt.admin.deleteExpiredRefreshTokens(s);
      return expired;
    },
  );

  /// Demo documents past [demoRetention] (the create gate also does this).
  static final demoDocuments = MaintenanceJob(
    'demo-documents',
    const Duration(hours: 1),
    (s) async {
      if (!DemoConfig.enabled(s)) return 0;
      if (DemoUser.accounts.isEmpty) await DemoUser.load(s);
      return DemoGuard.purgeExpiredDocuments(s);
    },
  );

  /// Ask conversations past their keeping time (30 days, demo 7). Runs while
  /// history is off too: what was stored before still has to age out. The
  /// session logs nothing (the SQL would carry user text).
  static final askHistory = MaintenanceJob(
    'ask-history',
    const Duration(hours: 1),
    (s) => AskStore.run(s, (q) => AskStore.purge(q, AskConfig.of(q))),
  );

  static final jobs = <MaintenanceJob>[
    demoTokens,
    authTokens,
    demoDocuments,
    askHistory,
  ];

  static Timer? _first;
  static Timer? _periodic;
  static bool _busy = false;
  static final _lastOk = <String, DateTime>{};
  static final _lastLogged = <String, DateTime>{};

  /// A `ran` line per job at most once an hour, unless something was deleted.
  static const logEvery = Duration(hours: 1);

  /// Where log lines go (tests replace it).
  static void Function(String line) log = stdout.writeln;

  /// The line written once when the timer starts.
  static String startLine({List<MaintenanceJob>? only}) =>
      'maintenance: timer started jobs=${(only ?? jobs).map((j) => j.name).join(',')} '
      'interval=${tick.inMinutes}m';

  /// Starts the timer: a first pass after 5 to 35 seconds (random, so that
  /// instances booting together do not run at once), then every [tick]. Does
  /// nothing for the `maintenance` role or when already started. Call after
  /// `pod.start()`. Returns whether it started.
  static bool start(Serverpod pod, {Duration? firstDelay}) {
    if (pod.config.role.name == 'maintenance') return false;
    if (_first != null || _periodic != null) return false;
    void pass() => unawaited(runDue(pod.withSession));
    _first = Timer(
      firstDelay ?? Duration(seconds: 5 + Random().nextInt(30)),
      () {
        pass();
        _periodic = Timer.periodic(tick, (_) => pass());
      },
    );
    pod.experimental.shutdownTasks.addTask('maintenance-timer', () async {
      stop();
    });
    log(startLine());
    return true;
  }

  static void stop() {
    _first?.cancel();
    _periodic?.cancel();
    _first = _periodic = null;
  }

  /// Runs the jobs that are due, one after the other. Never throws; a pass
  /// that is still running makes the next one skip. Returns the names tried.
  static Future<List<String>> runDue(
    SessionScope scope, {
    DateTime? now,
    List<MaintenanceJob>? only,
  }) async {
    if (_busy) return const [];
    _busy = true;
    final tried = <String>[];
    try {
      for (final job in only ?? jobs) {
        final t = now ?? DateTime.now();
        final last = _lastOk[job.name];
        if (last != null && t.difference(last) < job.every) continue;
        tried.add(job.name);
        try {
          final clock = Stopwatch()..start();
          final deleted = await scope(job.run);
          _lastOk[job.name] = t;
          final shown = _lastLogged[job.name];
          if (deleted > 0 || shown == null || t.difference(shown) >= logEvery) {
            _lastLogged[job.name] = t;
            // Job name, count and time only: no user data.
            log(
              'maintenance: ${job.name} ran deleted=$deleted '
              'ms=${clock.elapsedMilliseconds}',
            );
          }
        } catch (e) {
          // No stack trace, no request data: only what the job itself threw.
          stderr.writeln('maintenance: ${job.name} failed: $e');
        }
      }
    } finally {
      _busy = false;
    }
    return tried;
  }

  /// Tests only.
  static void debugReset() {
    stop();
    _busy = false;
    _lastOk.clear();
    _lastLogged.clear();
    log = stdout.writeln;
  }
}
