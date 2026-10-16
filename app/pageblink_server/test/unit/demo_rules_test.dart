import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/demo/demo_guard.dart';
import 'package:pageblink_server/src/demo/demo_samples.dart';
import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:test/test.dart';

void main() {
  group('sample content', () {
    test('every note fits one chunk and avoids the to-do sample prefix', () {
      for (final n in DemoSamples.notes) {
        expect(n.body.length, lessThan(900));
        expect(chunkPages([(page: 1, text: n.body)]), hasLength(1));
        expect(n.title, isNot(startsWith('Sample · ')));
        expect(n.title, isNot(startsWith('샘플 · ')));
      }
    });

    test('markers: two notes plus the PDF, all different', () {
      expect(DemoSamples.markers, hasLength(3));
      expect(DemoSamples.isSampleHash(DemoSamples.noteEn.hash), isTrue);
      expect(
        DemoSamples.isSampleHash(sha256Hex(DemoSamples.noteKo.body)),
        isTrue,
      );
      expect(DemoSamples.isSampleHash(DemoSamples.pdfHash), isTrue);
      expect(DemoSamples.isSampleHash(sha256Hex('my own note')), isFalse);
    });

    test('the PDF has several pages with different text', () {
      expect(DemoSamples.pdfPages.length, greaterThanOrEqualTo(2));
      expect(
        DemoSamples.pdfPages.toSet(),
        hasLength(DemoSamples.pdfPages.length),
      );
      for (final p in DemoSamples.pdfPages) {
        expect(chunkPages([(page: 1, text: p)]), isNotEmpty);
      }
    });
  });

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
