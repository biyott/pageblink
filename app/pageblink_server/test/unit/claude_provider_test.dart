import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:test/test.dart';

String _sse(List<Map<String, dynamic>> events) =>
    events.map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n').join();

void main() {
  test('parses text and citation deltas from the SSE stream', () async {
    late Map<String, dynamic> sentBody;
    final client = MockClient.streaming((request, bodyStream) async {
      sentBody =
          jsonDecode(await utf8.decodeStream(bodyStream))
              as Map<String, dynamic>;
      final body = _sse([
        {'type': 'message_start', 'message': {}},
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': '예산은 '},
        },
        {
          'type': 'content_block_delta',
          'index': 1,
          'delta': {
            'type': 'citations_delta',
            'citation': {
              'type': 'char_location',
              'document_index': 1,
              'cited_text': '3억 원',
            },
          },
        },
        {
          'type': 'content_block_delta',
          'index': 1,
          'delta': {'type': 'text_delta', 'text': '3억 원입니다.'},
        },
        {
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
        },
        {'type': 'message_stop'},
      ]);
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    });

    final provider = ClaudeLlmProvider('test-key', client: client);
    final events = await provider.answer('예산은?', [
      SourcePassage(title: 'a (p.1)', text: 'x'),
      SourcePassage(title: 'b (p.2)', text: '예산은 3억 원'),
    ]).toList();

    expect(
      events.whereType<LlmText>().map((e) => e.text).join(),
      '예산은 3억 원입니다.',
    );
    final citation = events.whereType<LlmCitation>().single;
    expect(citation.sourceIndex, 1);
    expect(citation.citedText, '3억 원');
    expect(events.last, isA<LlmDone>());

    final content = (sentBody['messages'] as List).single['content'] as List;
    expect(content.where((b) => b['type'] == 'document'), hasLength(2));
    expect(sentBody['thinking'], {'type': 'adaptive'});
    expect(sentBody['fallbacks'], 'default');
  });

  test('throws on refusal stop reason', () async {
    final client = MockClient.streaming(
      (request, _) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            _sse([
              {
                'type': 'message_delta',
                'delta': {'stop_reason': 'refusal'},
              },
            ]),
          ),
        ),
        200,
      ),
    );
    final provider = ClaudeLlmProvider('k', client: client);
    expect(provider.answer('q', []).toList(), throwsA(isA<LlmException>()));
  });
}
