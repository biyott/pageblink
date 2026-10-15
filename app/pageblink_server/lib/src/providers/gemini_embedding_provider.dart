import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../rag/embedding_spec.dart';
import 'embedding_provider.dart';

/// Gemini API embeddings (free tier) truncated to 768 dims to match the
/// pgvector column. Different vector space from EmbeddingGemma: never mix
/// the two in one index (chunks record `embeddingModel`).
class GeminiEmbeddingProvider implements EmbeddingProvider {
  GeminiEmbeddingProvider(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _model = 'gemini-embedding-001';
  static final _endpoint = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:batchEmbedContents',
  );
  static const _queryPrefix = 'task: search result | query: ';
  static final _documentPattern = RegExp(
    r'^title: (.*?) \| text: ',
    dotAll: true,
  );

  @override
  String get modelId => 'google/$_model@${EmbeddingSpec.dimensions}';

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    final vectors = <List<double>>[];
    for (var i = 0; i < texts.length; i += 100) {
      final batch = texts.sublist(i, math.min(i + 100, texts.length));
      final response = await postEmbeddingRequest(
        _client,
        _endpoint,
        headers: {
          'x-goog-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'requests': [for (final t in batch) _request(t)],
        }),
      );
      if (response.statusCode != 200) {
        throw EmbeddingException(
          'Gemini ${response.statusCode}: ${response.body}',
        );
      }
      for (final e in jsonDecode(response.body)['embeddings'] as List) {
        vectors.add(
          _normalize([
            for (final v in e['values'] as List) (v as num).toDouble(),
          ]),
        );
      }
    }
    return vectors;
  }

  /// Maps the EmbeddingGemma-style prefixes from [EmbeddingSpec] to Gemini
  /// task types.
  Map<String, dynamic> _request(String text) {
    var taskType = 'RETRIEVAL_DOCUMENT';
    String? title;
    var body = text;
    if (text.startsWith(_queryPrefix)) {
      taskType = 'RETRIEVAL_QUERY';
      body = text.substring(_queryPrefix.length);
    } else {
      final m = _documentPattern.firstMatch(text);
      if (m != null) {
        title = m.group(1);
        body = text.substring(m.end);
      }
    }
    return {
      'model': 'models/$_model',
      'content': {
        'parts': [
          {'text': body},
        ],
      },
      'taskType': taskType,
      'title': ?title,
      'outputDimensionality': EmbeddingSpec.dimensions,
    };
  }

  // Truncated (MRL) Gemini vectors must be re-normalized.
  static List<double> _normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    if (sum == 0) return v;
    final inv = 1 / math.sqrt(sum);
    return [for (final x in v) x * inv];
  }
}
