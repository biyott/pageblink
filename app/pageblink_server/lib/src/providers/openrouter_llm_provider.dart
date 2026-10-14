import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

/// Any chat model through OpenRouter (OpenAI-compatible SSE).
///
/// OpenRouter has no native citations, so passages are numbered `[1]..[n]`
/// and the model is told to cite with those markers. Markers stay in the text
/// (the app renders them as chips) and each first use emits an [LlmCitation].
class OpenRouterLlmProvider implements LlmProvider {
  OpenRouterLlmProvider(
    this._apiKey, {
    this.model = 'anthropic/claude-haiku-5.5',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String _apiKey;
  final String model;
  final http.Client _client;

  static final _endpoint = Uri.parse(
    'https://openrouter.ai/api/v1/chat/completions',
  );
  static final _marker = RegExp(r'\[(\d{1,2})\]');

  static const _system =
      'You answer questions using only the numbered sources provided, '
      'which are excerpts from the user\'s own files. After each sentence that uses a source, '
      'cite it with its number in square brackets, like [1] or [2][3]. '
      'If the sources do not contain the answer, say that it was not found in the documents '
      'instead of guessing. Answer in the language of the question, concisely, using Markdown.';

  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) async* {
    final context = StringBuffer();
    for (var i = 0; i < sources.length; i++) {
      context
        ..writeln('[${i + 1}] ${sources[i].title}')
        ..writeln(sources[i].text)
        ..writeln();
    }

    final request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'X-Title': 'PageBlink',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        // Personal documents: never route to providers that keep or train on data.
        'provider': {'data_collection': 'deny'},
        'messages': [
          {'role': 'system', 'content': _system},
          {
            'role': 'user',
            'content': 'Sources:\n\n$context\nQuestion: $question',
          },
        ],
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw LlmException('OpenRouter ${response.statusCode}: $body');
    }

    final text = StringBuffer();
    final cited = <int>{};
    String? finishReason;

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      // Comment lines (": OPENROUTER PROCESSING") and blanks are keep-alives.
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6).trim();
      if (data == '[DONE]') break;

      final chunk = jsonDecode(data) as Map<String, dynamic>;
      if (chunk['error'] != null) {
        throw LlmException('OpenRouter stream error: ${chunk['error']}');
      }
      final choices = chunk['choices'] as List? ?? const [];
      if (choices.isEmpty) continue;
      final choice = choices.first as Map<String, dynamic>;
      finishReason = choice['finish_reason'] as String? ?? finishReason;

      final delta =
          (choice['delta'] as Map<String, dynamic>?)?['content'] as String?;
      if (delta == null || delta.isEmpty) continue;
      yield LlmText(delta);

      // Markers can be split across chunks, so scan the accumulated text.
      text.write(delta);
      for (final m in _marker.allMatches(text.toString())) {
        final index = int.parse(m.group(1)!) - 1;
        if (index >= 0 && index < sources.length && cited.add(index)) {
          yield LlmCitation(index, '');
        }
      }
    }

    if (finishReason == 'error') {
      throw LlmException('OpenRouter finished with an error');
    }
    yield LlmDone(finishReason);
  }
}
