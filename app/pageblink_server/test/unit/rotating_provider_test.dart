import 'dart:async';

import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/rotating_llm_provider.dart';
import 'package:pageblink_server/src/services/daily_counter.dart';
import 'package:pageblink_server/src/services/llm_catalog.dart';
import 'package:test/test.dart';

class _Fake implements LlmProvider {
  _Fake(this.events);
  final Stream<LlmEvent> Function() events;
  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) =>
      events();
}

Stream<LlmEvent> _ok(String text) =>
    Stream.fromIterable([LlmText(text), LlmDone('stop')]);

void main() {
  test(
    'rotates to the next model on a retryable error before output',
    () async {
      final rotated = <String>[];
      final provider = RotatingLlmProvider(
        ['a', 'b'],
        (id) => _Fake(
          () => id == 'a'
              ? Stream.error(LlmException('429', retryable: true))
              : _ok('hi'),
        ),
        onRotate: (failed, _) => rotated.add(failed),
      );
      final events = await provider.answer('q', []).toList();
      expect((events.first as LlmModelUsed).modelId, 'b');
      expect(events.whereType<LlmText>().single.text, 'hi');
      expect(rotated, ['a']);
    },
  );

  test('does not rotate after text has streamed', () async {
    final provider = RotatingLlmProvider(
      ['a', 'b'],
      (id) => _Fake(() async* {
        yield LlmText('partial');
        throw LlmException('boom', retryable: true);
      }),
    );
    expect(provider.answer('q', []).toList(), throwsA(isA<LlmException>()));
  });

  test('non-retryable errors are not rotated', () async {
    final provider = RotatingLlmProvider(
      ['a', 'b'],
      (id) => _Fake(() => Stream.error(LlmException('bad request'))),
    );
    expect(provider.answer('q', []).toList(), throwsA(isA<LlmException>()));
  });

  group('catalog', () {
    const superId = 'nvidia/nemotron-3-super-120b-a12b:free';
    const ultra = 'nvidia/nemotron-3-ultra-550b-a55b:free';
    const lite = 'google/gemini-3.1-flash-lite';
    const flash = 'google/gemini-3.8-flash';
    const gemma = 'google/gemma-4-26b-a4b-it:free';

    test('the default is nemotron super', () {
      expect(LlmCatalog.defaultModelId, superId);
      expect(LlmCatalog.byId(superId)!.free, isTrue);
    });

    test('automatic order: super, ultra, then paid (all mode only)', () {
      expect(LlmCatalog.rotation(superId), [superId, ultra]);
      expect(LlmCatalog.rotation(superId, mode: 'all'), [
        superId,
        ultra,
        lite,
        flash,
      ]);
      expect(LlmCatalog.rotation(superId, mode: 'off'), [superId]);
    });

    test('unstable models stay selectable but are never rotated to', () {
      for (final id in LlmCatalog.manualOnly) {
        expect(LlmCatalog.byId(id), isNotNull, reason: id);
        for (final mode in ['free', 'all']) {
          expect(
            LlmCatalog.rotation(superId, mode: mode),
            isNot(contains(id)),
            reason: '$id $mode',
          );
        }
      }
      expect(LlmCatalog.manualOnly, hasLength(3));
      expect(LlmCatalog.manualOnly, contains(gemma));
    });

    test('a chosen unstable model is tried first, the order follows', () {
      expect(LlmCatalog.rotation(gemma), [gemma, superId, ultra]);
      expect(LlmCatalog.rotation(gemma, mode: 'all'), [
        gemma,
        superId,
        ultra,
        lite,
        flash,
      ]);
      expect(LlmCatalog.rotation(flash, mode: 'all'), [
        flash,
        superId,
        ultra,
        lite,
      ]);
    });

    test('notes mark the slow and unstable models', () {
      expect(LlmCatalog.byId(flash)!.note, contains('slower first token'));
      for (final id in LlmCatalog.manualOnly) {
        expect(LlmCatalog.byId(id)!.note, contains('unstable'), reason: id);
      }
    });

    test('reasoning is switched off only where it was measured to work', () {
      expect(LlmCatalog.reasoningFor(superId), {'effort': 'none'});
      expect(LlmCatalog.reasoningFor(ultra), {'effort': 'none'});
      expect(
        LlmCatalog.reasoningFor(
          'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
        ),
        {'enabled': false},
      );
      for (final id in [
        lite,
        flash,
        gemma,
        'nvidia/nemotron-3.5-lightning:free',
      ]) {
        expect(LlmCatalog.reasoningFor(id), isNull, reason: id);
      }
    });

    test(
      'a chosen unstable model, then the fixed order, with the free limit',
      () async {
        final tried = <String>[];
        final provider = RotatingLlmProvider(
          LlmCatalog.rotation(gemma, mode: 'all'),
          (id) => _Fake(() {
            tried.add(id);
            return id.endsWith(':free')
                ? Stream.error(LlmException('x', retryable: true))
                : _ok('paid');
          }),
          isFree: (id) => LlmCatalog.byId(id)?.free ?? false,
          freeAttempts: 2,
          paidCounter: DailyCounter(5),
        );
        final events = await provider.answer('q', []).toList();
        // gemma counts as the first free attempt; ultra is skipped.
        expect(tried, [gemma, superId, lite]);
        expect((events.first as LlmModelUsed).modelId, lite);
      },
    );
  });

  test('every model failing gives the same busy error as the cap', () async {
    final provider = RotatingLlmProvider(
      ['a', 'b'],
      (id) => _Fake(() => Stream.error(LlmException('x', retryable: true))),
    );
    await expectLater(
      provider.answer('q', []).toList(),
      throwsA(isA<LlmBusyException>()),
    );
  });

  group('paid fallback', () {
    // f1..f3 free, p1..p2 paid. `tried` records the models actually called.
    bool isFree(String id) => id.startsWith('f');
    final ids = ['f1', 'f2', 'f3', 'p1', 'p2'];

    ({RotatingLlmProvider provider, List<String> tried, List<String> log})
    build(
      Stream<LlmEvent> Function(String id) behave, {
      DailyCounter? counter,
      int? freeAttempts = 2,
      Duration? timeout,
      List<String>? order,
    }) {
      final tried = <String>[];
      final log = <String>[];
      final provider = RotatingLlmProvider(
        order ?? ids,
        (id) => _Fake(() {
          tried.add(id);
          return behave(id);
        }),
        isFree: isFree,
        freeAttempts: freeAttempts,
        firstTokenTimeout: timeout,
        paidCounter: counter,
        onRotate: (m, reason) => log.add('$m:$reason'),
        onPaidFallback: (m, {required allowed}) => log.add('paid:$m:$allowed'),
      );
      return (provider: provider, tried: tried, log: log);
    }

    Stream<LlmEvent> failFree(String id) => isFree(id)
        ? Stream.error(LlmException('x', retryable: true, statusCode: 429))
        : _ok('paid answer');

    test(
      'two free failures, then paid; the third free one is skipped',
      () async {
        final t = build(failFree, counter: DailyCounter(5));
        final events = await t.provider.answer('q', []).toList();
        expect((events.first as LlmModelUsed).modelId, 'p1');
        expect(t.tried, ['f1', 'f2', 'p1']);
        expect(t.log, ['f1:status 429', 'f2:status 429', 'paid:p1:true']);
      },
    );

    test('first-token timeout moves on; text after it is not timed', () async {
      final t = build(
        (id) => id == 'f1'
            ? Stream.fromFuture(Completer<LlmEvent>().future) // never answers
            : id == 'f2'
            ? (() async* {
                yield LlmText('a');
                await Future<void>.delayed(const Duration(milliseconds: 150));
                yield LlmText('b');
                yield LlmDone('stop');
              })()
            : _ok('no'),
        timeout: const Duration(milliseconds: 60),
      );
      final events = await t.provider.answer('q', []).toList();
      expect(events.whereType<LlmText>().map((e) => e.text).join(), 'ab');
      expect(t.tried, ['f1', 'f2']);
      expect(t.log, ['f1:first-token-timeout']);
    });

    test('daily cap: one use per answer, then paid is skipped', () async {
      final counter = DailyCounter(1, now: () => DateTime.utc(2026, 10, 16, 3));
      var t = build(failFree, counter: counter);
      await t.provider.answer('q', []).toList(); // takes the only use
      expect(counter.remaining, 0);

      t = build(failFree, counter: counter);
      await expectLater(
        t.provider.answer('q', []).toList(),
        throwsA(isA<LlmBusyException>()),
      );
      // Paid is out of reach, so the free limit (2) is lifted: all 3 tried.
      expect(t.tried, ['f1', 'f2', 'f3']);
      expect(t.log.last, 'paid:null:false');
    });

    test('the cap resets at midnight KST', () async {
      var now = DateTime.utc(2026, 10, 16, 14, 59);
      final counter = DailyCounter(1, now: () => now);
      await build(failFree, counter: counter).provider.answer('q', []).toList();
      expect(counter.remaining, 0);
      now = DateTime.utc(2026, 10, 16, 15, 1);
      final t = build(failFree, counter: counter);
      final events = await t.provider.answer('q', []).toList();
      expect((events.first as LlmModelUsed).modelId, 'p1');
    });

    test('a paid model the user picked is not capped', () async {
      final counter = DailyCounter(0);
      final t = build(
        (id) => _ok('ok'),
        counter: counter,
        order: ['p2', 'f1', 'f2', 'p1'],
      );
      final events = await t.provider.answer('q', []).toList();
      expect((events.first as LlmModelUsed).modelId, 'p2');
      expect(t.log, isEmpty);
    });

    test(
      'a chosen paid model that fails still falls back within the cap',
      () async {
        final t = build(
          (id) => id == 'p2'
              ? Stream.error(LlmException('x', retryable: true))
              : _ok('ok'),
          counter: DailyCounter(5),
          order: ['p2', 'f1', 'f2', 'f3', 'p1'],
        );
        final events = await t.provider.answer('q', []).toList();
        expect((events.first as LlmModelUsed).modelId, 'f1');
        expect(t.tried, ['p2', 'f1']);
      },
    );

    test('an error after text is surfaced, not rotated, not counted', () async {
      final counter = DailyCounter(5);
      final t = build(
        (id) => (() async* {
          yield LlmText('partial');
          throw LlmException('boom', retryable: true);
        })(),
        counter: counter,
      );
      await expectLater(
        t.provider.answer('q', []).toList(),
        throwsA(isA<LlmException>()),
      );
      expect(t.tried, ['f1']);
      expect(counter.used, 0);
    });

    test('without a counter or limit (free / off) nothing changes', () async {
      // free: every free model is tried, paid ones are not even listed.
      final t = build(
        (id) => Stream.error(LlmException('x', retryable: true)),
        freeAttempts: null,
        order: ['f1', 'f2', 'f3'],
      );
      await expectLater(
        t.provider.answer('q', []).toList(),
        throwsA(isA<LlmBusyException>()),
      );
      expect(t.tried, ['f1', 'f2', 'f3']);
      // off: just the chosen model.
      final off = build(
        (id) => Stream.error(LlmException('x', retryable: true)),
        freeAttempts: null,
        order: ['f1'],
      );
      await expectLater(
        off.provider.answer('q', []).toList(),
        throwsA(isA<LlmBusyException>()),
      );
      expect(off.tried, ['f1']);
    });
  });
}
