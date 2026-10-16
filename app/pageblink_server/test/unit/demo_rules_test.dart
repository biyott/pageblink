import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/demo/demo_guard.dart';
import 'package:test/test.dart';

void main() {
  group('DailyCounter', () {
    test('stops at the limit and tells how many are left', () {
      final c = DailyCounter(2, now: () => DateTime.utc(2026, 10, 16, 3));
      expect(c.remaining, 2);
      expect(c.tryConsume(), isTrue);
      expect(c.tryConsume(), isTrue);
      expect(c.tryConsume(), isFalse);
      expect(c.remaining, 0);
      expect(c.used, 2);
    });

    test('resets at midnight KST, not midnight UTC', () {
      var now = DateTime.utc(2026, 10, 16, 14, 59); // 23:59 KST
      final c = DailyCounter(1, now: () => now);
      expect(c.tryConsume(), isTrue);
      now = DateTime.utc(2026, 10, 16, 15, 1); // 00:01 KST next day
      expect(c.remaining, 1);
      expect(c.tryConsume(), isTrue);
    });
  });

  test('retention is 24 hours', () {
    final now = DateTime.utc(2026, 10, 16, 12);
    expect(DemoGuard.cutoff(now), DateTime.utc(2026, 10, 15, 12));
    expect(demoRetention, const Duration(hours: 24));
  });
}
