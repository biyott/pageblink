import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/openrouter_llm_provider.dart';
import 'package:pageblink_server/src/providers/rotating_llm_provider.dart';
import 'package:pageblink_server/src/services/llm_catalog.dart';
import 'package:test/test.dart';

String _chunk(String content, {String? finish}) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
          'finish_reason': finish,
        },
      ],
    })}\n\n';

void main() {
  test('streams text, skips comments, emits each cited source once', () async {
    late Map<String, dynamic> sent;
    final client = MockClient.streaming((request, body) async {
      sent = jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
      final sse =
          ': OPENROUTER PROCESSING\n\n'
          '${_chunk('예산은 3억 원입니다 [')}'
          '${_chunk('2]. 일정은 미정 [2][1].')}'
          '${_chunk('', finish: 'stop')}'
          'data: [DONE]\n\n';
      return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
    });

    final events = await OpenRouterLlmProvider('k', client: client).answer(
      '예산?',
      [
        SourcePassage(title: 'a (p.1)', text: 'x'),
        SourcePassage(title: 'b (p.2)', text: '예산 3억'),
      ],
    ).toList();

    expect(
      events.whereType<LlmText>().map((e) => e.text).join(),
      '예산은 3억 원입니다 [2]. 일정은 미정 [2][1].',
    );
    expect(events.whereType<LlmCitation>().map((c) => c.sourceIndex), [1, 0]);
    expect(events.last, isA<LlmDone>());
    expect(sent['provider'], {'data_collection': 'deny'});
    expect(sent['model'], 'anthropic/claude-haiku-5.5');
  });

  test('renders EVIDENCE per numbered source, CONTEXT once', () async {
    late Map<String, dynamic> sent;
    final client = MockClient.streaming((request, body) async {
      sent = jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
      return http.StreamedResponse(
        Stream.value(utf8.encode('${_chunk('ok [2]')}data: [DONE]\n\n')),
        200,
      );
    });
    final events = await OpenRouterLlmProvider('k', client: client).answer(
      'q',
      [
        SourcePassage(
          title: 'Plan › Numbers (note)',
          text: '- **Date:** Nov 18',
          context: '## Numbers\n- **Budget:** 12M\n- **Date:** Nov 18',
        ),
        SourcePassage(
          title: 'Plan › Numbers (note)',
          text: '- **Budget:** 12M',
          contextOf: 1,
        ),
        SourcePassage(title: 'Other (p.3)', text: 'plain'),
      ],
    ).toList();

    final messages = sent['messages'] as List;
    final system = messages[0]['content'] as String;
    final user = messages[1]['content'] as String;
    expect(system, contains('EVIDENCE'));
    expect(system, contains('CONTEXT'));
    expect(
      user,
      contains(
        '[1] Plan › Numbers (note)\n'
        'EVIDENCE: - **Date:** Nov 18\n'
        'CONTEXT:\n'
        '## Numbers\n'
        '- **Budget:** 12M\n'
        '- **Date:** Nov 18\n\n'
        '[2] Plan › Numbers (note)\n'
        'EVIDENCE: - **Budget:** 12M\n'
        '(same context as [1])\n\n'
        '[3] Other (p.3)\nEVIDENCE: plain\n',
      ),
    );
    // the marker maps to the small unit, not to the context
    expect(events.whereType<LlmCitation>().single.sourceIndex, 1);
  });

  test('throws on in-stream error', () async {
    final client = MockClient.streaming(
      (request, _) async => http.StreamedResponse(
        Stream.value(
          utf8.encode('data: {"error":{"code":502,"message":"upstream"}}\n\n'),
        ),
        200,
      ),
    );
    expect(
      OpenRouterLlmProvider('k', client: client).answer('q', []).toList(),
      throwsA(isA<LlmException>()),
    );
  });

  test('full-width markers cite too, also when split across chunks', () async {
    final client = MockClient.streaming((request, body) async {
      final sse =
          '${_chunk('예산은 3억 원입니다【')}'
          '${_chunk('2')}'
          '${_chunk('】. 일정은 미정 ［1］ [2].')}'
          '${_chunk('', finish: 'stop')}'
          'data: [DONE]\n\n';
      return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
    });
    final events = await OpenRouterLlmProvider('k', client: client).answer(
      '예산?',
      [
        SourcePassage(title: 'a', text: 'x'),
        SourcePassage(title: 'b', text: 'y'),
      ],
    ).toList();
    expect(events.whereType<LlmCitation>().map((c) => c.sourceIndex), [1, 0]);
    // the text is passed through untouched; the app turns the markers into chips
    expect(
      events.whereType<LlmText>().map((e) => e.text).join(),
      contains('【2】'),
    );
  });

  test('the system prompt asks for half-width brackets', () async {
    late Map<String, dynamic> sent;
    final client = MockClient.streaming((request, body) async {
      sent = jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
      return http.StreamedResponse(
        Stream.value(utf8.encode('data: [DONE]\n\n')),
        200,
      );
    });
    await OpenRouterLlmProvider('k', client: client).answer('q', []).toList();
    expect(
      (sent['messages'] as List)[0]['content'],
      contains('half-width brackets [n]'),
    );
  });

  test('HTTP failures carry the status code and retryability', () async {
    final client = MockClient.streaming(
      (request, _) async =>
          http.StreamedResponse(Stream.value(utf8.encode('busy')), 429),
    );
    await expectLater(
      OpenRouterLlmProvider('k', client: client).answer('q', []).toList(),
      throwsA(
        isA<LlmException>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  group('reasoning request field', () {
    Future<Map<String, dynamic>> bodyFor(String model) async {
      late Map<String, dynamic> sent;
      final client = MockClient.streaming((request, body) async {
        sent =
            jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: [DONE]\n\n')),
          200,
        );
      });
      await OpenRouterLlmProvider(
        'k',
        model: model,
        reasoning: LlmCatalog.reasoningFor(model),
        client: client,
      ).answer('q', []).toList();
      return sent;
    }

    test('sent exactly as the catalog says, for every catalog model', () async {
      const expected = <String, Map<String, Object>?>{
        'nvidia/nemotron-3-super-120b-a12b:free': {'effort': 'none'},
        'nvidia/nemotron-3-ultra-550b-a55b:free': {'effort': 'none'},
        'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free': {
          'enabled': false,
        },
        'google/gemini-3.1-flash-lite': null,
        'google/gemini-3.8-flash': null, // mandatory: cannot be switched off
        'google/gemma-4-26b-a4b-it:free': null,
        'nvidia/nemotron-3.5-lightning:free': null,
      };
      expect(expected.keys.toSet(), {for (final m in LlmCatalog.models) m.id});
      for (final MapEntry(key: model, value: want) in expected.entries) {
        final sent = await bodyFor(model);
        if (want == null) {
          expect(sent.containsKey('reasoning'), isFalse, reason: model);
        } else {
          expect(sent['reasoning'], want, reason: model);
        }
        expect(sent['model'], model);
      }
    });

    test('without a setting nothing is sent', () async {
      late Map<String, dynamic> sent;
      final client = MockClient.streaming((request, body) async {
        sent =
            jsonDecode(await utf8.decodeStream(body)) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: [DONE]\n\n')),
          200,
        );
      });
      await OpenRouterLlmProvider('k', client: client).answer('q', []).toList();
      expect(sent.containsKey('reasoning'), isFalse);
    });
  });

  group('first-token timeout counts content, not reasoning', () {
    String reasoningChunk() =>
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'reasoning': 'thinking...', 'content': null},
            },
          ],
        })}\n\n';

    test('reasoning deltas do not stop the clock', () async {
      // Model "slow" streams reasoning at once and never any content.
      final slow = StreamController<List<int>>();
      addTearDown(slow.close);
      final tried = <String>[];
      final provider = RotatingLlmProvider(
        ['slow', 'fast'],
        (id) {
          tried.add(id);
          return OpenRouterLlmProvider(
            'k',
            model: id,
            client: MockClient.streaming((request, body) async {
              if (id == 'slow') {
                slow.add(utf8.encode(reasoningChunk()));
                return http.StreamedResponse(slow.stream, 200);
              }
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode('${_chunk('hello')}data: [DONE]\n\n'),
                ),
                200,
              );
            }),
          );
        },
        firstTokenTimeout: const Duration(milliseconds: 150),
      );
      final events = await provider.answer('q', []).toList();
      expect(tried, ['slow', 'fast']);
      expect(events.whereType<LlmText>().single.text, 'hello');
      expect((events.first as LlmModelUsed).modelId, 'fast');
    });

    test('content after reasoning ends the wait: no switch', () async {
      final tried = <String>[];
      final provider = RotatingLlmProvider(
        ['a', 'b'],
        (id) {
          tried.add(id);
          return OpenRouterLlmProvider(
            'k',
            model: id,
            client: MockClient.streaming((request, body) async {
              Stream<List<int>> sse() async* {
                yield utf8.encode(reasoningChunk());
                await Future<void>.delayed(const Duration(milliseconds: 60));
                yield utf8.encode('${_chunk('answer')}data: [DONE]\n\n');
              }

              return http.StreamedResponse(sse(), 200);
            }),
          );
        },
        firstTokenTimeout: const Duration(milliseconds: 400),
      );
      final events = await provider.answer('q', []).toList();
      expect(tried, ['a']);
      expect(events.whereType<LlmText>().single.text, 'answer');
    });
  });
}
