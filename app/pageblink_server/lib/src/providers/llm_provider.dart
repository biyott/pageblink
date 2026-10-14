import 'dart:convert';

import 'package:http/http.dart' as http;

/// A retrieved passage handed to the model as a citable document.
class SourcePassage {
  SourcePassage({required this.title, required this.text});
  final String title;
  final String text;
}

/// Events produced while an answer streams.
sealed class LlmEvent {}

class LlmText extends LlmEvent {
  LlmText(this.text);
  final String text;
}

/// The model cited [citedText] from the passage at [sourceIndex].
class LlmCitation extends LlmEvent {
  LlmCitation(this.sourceIndex, this.citedText);
  final int sourceIndex;
  final String citedText;
}

class LlmDone extends LlmEvent {
  LlmDone(this.stopReason);
  final String? stopReason;
}

/// The model that is actually answering (may differ after rotation).
class LlmModelUsed extends LlmEvent {
  LlmModelUsed(this.modelId);
  final String modelId;
}

class LlmException implements Exception {
  /// [retryable]: failed before any output for a reason another model may not
  /// have (rate limit, quota, provider unavailable) — safe to rotate.
  LlmException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
  @override
  String toString() => 'LlmException: $message';
}

/// Streams grounded answers. Implementations are swappable (ADR 004).
abstract class LlmProvider {
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources);
}

/// Claude Messages API over raw HTTP + SSE (no official Dart SDK).
///
/// Each passage is sent as a text `document` block with citations enabled, so
/// the model returns `citations_delta` events pointing back at the passage.
class ClaudeLlmProvider implements LlmProvider {
  ClaudeLlmProvider(
    this._apiKey, {
    this.model = 'claude-opus-5-5',
    this.effort = 'low',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String _apiKey;
  final String model;
  final String effort;
  final http.Client _client;

  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  static const _system =
      'You answer questions using only the provided documents, '
      'which are excerpts from the user\'s own files. Cite the passages you rely on. '
      'If the documents do not contain the answer, say that it was not found in the documents '
      'instead of guessing. Answer in the language of the question, concisely, using Markdown.';

  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) async* {
    final request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'server-side-fallback-2026-07-01',
        'content-type': 'application/json',
      })
      ..body = jsonEncode({
        'model': model,
        'max_tokens': 16000,
        'stream': true,
        'thinking': {'type': 'adaptive'},
        'output_config': {'effort': effort},
        'fallbacks': 'default',
        'system': [
          {
            'type': 'text',
            'text': _system,
            'cache_control': {'type': 'ephemeral'},
          },
        ],
        'messages': [
          {
            'role': 'user',
            'content': [
              for (final s in sources)
                {
                  'type': 'document',
                  'source': {
                    'type': 'text',
                    'media_type': 'text/plain',
                    'data': s.text,
                  },
                  'title': s.title,
                  'citations': {'enabled': true},
                },
              {'type': 'text', 'text': question},
            ],
          },
        ],
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw LlmException('Claude ${response.statusCode}: $body');
    }

    String? stopReason;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final event = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      switch (event['type']) {
        case 'content_block_delta':
          final delta = event['delta'] as Map<String, dynamic>;
          switch (delta['type']) {
            case 'text_delta':
              yield LlmText(delta['text'] as String);
            case 'citations_delta':
              final citation = delta['citation'] as Map<String, dynamic>;
              yield LlmCitation(
                citation['document_index'] as int,
                citation['cited_text'] as String? ?? '',
              );
          }
        case 'message_delta':
          stopReason =
              (event['delta'] as Map<String, dynamic>)['stop_reason']
                  as String? ??
              stopReason;
        case 'error':
          throw LlmException('Claude stream error: ${event['error']}');
      }
    }
    if (stopReason == 'refusal') {
      throw LlmException('The model declined to answer this question.');
    }
    yield LlmDone(stopReason);
  }
}
