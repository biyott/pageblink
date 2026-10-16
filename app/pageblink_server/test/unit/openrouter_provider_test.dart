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
}
