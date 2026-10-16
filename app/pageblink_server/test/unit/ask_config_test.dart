import 'package:pageblink_server/src/services/ask_config.dart';
import 'package:pageblink_server/src/services/env_int.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// Only `passwords` is read.
class _Session implements Session {
  @override
  final Map<String, String> passwords = {};
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  tearDown(AskConfig.debugValues.clear);

  test('defaults: off, and the values the product decided', () {
    final c = AskConfig.of(_Session());
    expect(c.enabled, isFalse);
    expect(
      [
        c.resumeSeconds,
        c.viewMinutes,
        c.maxQuestions,
        c.listed,
        c.retentionDays,
        c.demoRetentionDays,
        c.contextBudget,
        c.contextAnswer,
        c.queryJoin,
        c.promptMax,
        c.questionMax,
      ],
      [30, 30, 10, 5, 30, 7, 8000, 800, 600, 20000, 2000],
    );
  });

  test('passwords and environment values are read, junk falls back', () {
    final s = _Session()
      ..passwords['askHistoryEnabled'] = 'true'
      ..passwords['askSessionMaxQuestions'] = '4'
      ..passwords['askSessionsListed'] = 'many'
      ..passwords['askHistoryRetentionDays'] = '0';
    AskConfig.debugValues['ASK_SESSION_RESUME_SECONDS'] = ' 12 ';
    final c = AskConfig.of(s);
    expect(c.enabled, isTrue);
    expect(c.maxQuestions, 4);
    expect(c.listed, 5, reason: 'not a number: default');
    expect(c.retentionDays, 30, reason: 'below the minimum: default');
    expect(c.resumeSeconds, 12);
  });

  test('truthy accepts the usual spellings only', () {
    for (final v in ['true', '1', 'YES', ' on ']) {
      expect(truthy(v), isTrue, reason: v);
    }
    for (final v in [null, '', 'false', '0', 'no', 'enabled']) {
      expect(truthy(v), isFalse, reason: '$v');
    }
  });

  test(
    'ADMIN_USER_IDS: trimmed, case-insensitive, junk ignored, empty = none',
    () {
      const a = '3f8a1c52-0000-4000-8000-000000000001';
      const b = '3f8a1c52-0000-4000-8000-000000000002';
      final s = _Session();
      expect(AskConfig.adminIds(s), isEmpty);
      AskConfig.debugValues['ADMIN_USER_IDS'] =
          ' ${a.toUpperCase()} , not-a-uuid,, $b ';
      expect(AskConfig.adminIds(s), {
        UuidValue.fromString(a),
        UuidValue.fromString(b),
      });
      AskConfig.debugValues['ADMIN_USER_IDS'] = '   ';
      expect(AskConfig.adminIds(s), isEmpty);
    },
  );
}
