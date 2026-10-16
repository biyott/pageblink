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
          return 0;
        }),
        MaintenanceJob('hourly', const Duration(hours: 1), (_) async {
          runs.add('hourly');
          if (failHourly) throw StateError('db down');
          return 0;
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
      MaintenanceJob('slow', const Duration(minutes: 5), (_) async {
        await gate.future;
        return 0;
      }),
    ];
    final first = MaintenanceTimer.runDue(_scope, only: jobs);
    expect(await MaintenanceTimer.runDue(_scope, only: jobs), isEmpty);
    gate.complete();
    expect(await first, ['slow']);
  });

  group('log lines', () {
    late List<String> lines;
    setUp(() {
      lines = [];
      MaintenanceTimer.log = lines.add;
    });

    test('the start line names the jobs and the interval', () {
      expect(
        MaintenanceTimer.startLine(),
        'maintenance: timer started jobs=demo-tokens,auth-tokens,'
        'demo-documents interval=5m',
      );
    });

    test('a quiet job logs once an hour, not once a run', () async {
      final jobs = [
        MaintenanceJob('quiet', const Duration(minutes: 5), (_) async => 0),
      ];
      final t0 = DateTime.utc(2026, 10, 16, 3);
      // 24 hours of 5-minute ticks.
      for (var i = 0; i < 24 * 12; i++) {
        await MaintenanceTimer.runDue(
          _scope,
          now: t0.add(Duration(minutes: 5 * i)),
          only: jobs,
        );
      }
      expect(lines, hasLength(24));
      expect(
        lines.first,
        matches(r'^maintenance: quiet ran deleted=0 ms=\d+$'),
      );
    });

    test('a deletion is logged at once, with its count', () async {
      var n = 0;
      final jobs = [
        MaintenanceJob('busy', const Duration(minutes: 5), (_) async => n),
      ];
      final t0 = DateTime.utc(2026, 10, 16, 3);
      Future<void> pass(int min) => MaintenanceTimer.runDue(
        _scope,
        now: t0.add(Duration(minutes: min)),
        only: jobs,
      );
      await pass(0); // first run: logged (0)
      await pass(5); // quiet again: not logged
      n = 3;
      await pass(10); // deleted: logged at once
      n = 0;
      await pass(15);
      expect(lines, hasLength(2));
      expect(lines.last, startsWith('maintenance: busy ran deleted=3 '));
    });

    test(
      'jobs are throttled separately; a failure is not a ran line',
      () async {
        final jobs = [
          MaintenanceJob('a', const Duration(minutes: 5), (_) async => 0),
          MaintenanceJob('b', const Duration(minutes: 5), (_) async => throw 1),
        ];
        final t0 = DateTime.utc(2026, 10, 16, 3);
        for (var i = 0; i < 3; i++) {
          await MaintenanceTimer.runDue(
            _scope,
            now: t0.add(Duration(minutes: 5 * i)),
            only: jobs,
          );
        }
        expect(lines.where((l) => l.contains(' a ran ')), hasLength(1));
        expect(lines.where((l) => l.contains(' b ran ')), isEmpty);
      },
    );
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
