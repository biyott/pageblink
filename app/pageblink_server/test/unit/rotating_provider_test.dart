import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/rotating_llm_provider.dart';
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

  test('catalog rotation modes', () {
    final free = LlmCatalog.rotation(LlmCatalog.defaultModelId);
    expect(free.first, LlmCatalog.defaultModelId);
    expect(free.every((id) => id.endsWith(':free')), isTrue);
    expect(
      LlmCatalog.rotation('google/gemini-3.8-flash', mode: 'all').length,
      LlmCatalog.models.length,
    );
    expect(LlmCatalog.rotation('x', mode: 'off'), ['x']);
  });
}
