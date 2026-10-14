import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/openrouter_llm_provider.dart';
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
}
