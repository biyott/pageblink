import 'dart:async';

import 'package:pageblink_server/src/services/env_int.dart';
import 'package:pageblink_server/src/services/maintenance_timer.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The jobs below never touch the session.
class _NoSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<R> _scope<R>(Future<R> Function(Session) body) => body(_NoSession());

void main() {
  setUp(MaintenanceTimer.debugReset);
  tearDown(MaintenanceTimer.debugReset);

  test(
    'jobs run when due: every tick, hourly, and again after a failure',
    () async {
      final runs = <String>[];
      var failHourly = true;
      final jobs = [
        MaintenanceJob('fast', const Duration(minutes: 5), (_) async {
          runs.add('fast');
        }),
        MaintenanceJob('hourly', const Duration(hours: 1), (_) async {
          runs.add('hourly');
          if (failHourly) throw StateError('db down');
        }),
      ];
      final t0 = DateTime.utc(2026, 10, 16, 3);
      Future<List<String>> pass(Duration after) =>
          MaintenanceTimer.runDue(_scope, now: t0.add(after), only: jobs);

      // First pass: both run; the failure is swallowed and does not stop 'fast'.
      expect(await pass(Duration.zero), ['fast', 'hourly']);
      // 5 minutes later: 'fast' is due, 'hourly' is retried (it never succeeded).
      failHourly = false;
      expect(await pass(const Duration(minutes: 5)), ['fast', 'hourly']);
      // Both succeeded; the hourly one now waits.
      expect(await pass(const Duration(minutes: 10)), ['fast']);
      expect(await pass(const Duration(minutes: 66)), ['fast', 'hourly']);
      expect(runs.where((r) => r == 'hourly'), hasLength(3));
    },
  );

  test('a pass that is still running makes the next one skip', () async {
    final gate = Completer<void>();
    final jobs = [
      MaintenanceJob('slow', const Duration(minutes: 5), (_) => gate.future),
    ];
    final first = MaintenanceTimer.runDue(_scope, only: jobs);
    expect(await MaintenanceTimer.runDue(_scope, only: jobs), isEmpty);
    gate.complete();
    expect(await first, ['slow']);
  });

  test('default jobs: demo tokens every tick, the rest hourly', () {
    expect(
      {for (final j in MaintenanceTimer.jobs) j.name: j.every},
      {
        'demo-tokens': const Duration(minutes: 5),
        'auth-tokens': const Duration(hours: 1),
        'demo-documents': const Duration(hours: 1),
      },
    );
  });

  test('positiveInt falls back on missing, junk or too small values', () {
    expect(positiveInt(null, 60), 60);
    expect(positiveInt(' 15 ', 60), 15);
    expect(positiveInt('abc', 60), 60);
    expect(positiveInt('0', 60), 60);
    expect(positiveInt('0', 300, min: 0), 0);
    expect(positiveInt('-3', 60), 60);
  });
}
