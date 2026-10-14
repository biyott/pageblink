import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../rag/embedding_spec.dart';

/// Turns texts into vectors. Implementations are swappable (ADR 002).
abstract class EmbeddingProvider {
  String get modelId;

  Future<List<List<double>>> embed(List<String> texts);
}

/// EmbeddingGemma-300m hosted on DeepInfra (OpenAI-compatible endpoint).
class DeepInfraEmbeddingProvider implements EmbeddingProvider {
  DeepInfraEmbeddingProvider(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static final _endpoint = Uri.parse(
    'https://api.deepinfra.com/v1/openai/embeddings',
  );

  @override
  String get modelId => EmbeddingSpec.model;

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    final vectors = <List<double>>[];
    // Keep requests small; DeepInfra batch limits are not documented here.
    for (var i = 0; i < texts.length; i += 32) {
      final batch = texts.sublist(
        i,
        i + 32 > texts.length ? texts.length : i + 32,
      );
      final response = await _client.post(
        _endpoint,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': EmbeddingSpec.model,
          'input': batch,
          'encoding_format': 'float',
        }),
      );
      if (response.statusCode != 200) {
        throw EmbeddingException(
          'DeepInfra ${response.statusCode}: ${response.body}',
        );
      }
      final data = (jsonDecode(response.body)['data'] as List)
        ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
      for (final item in data) {
        vectors.add(
          _normalize([
            for (final v in item['embedding'] as List) (v as num).toDouble(),
          ]),
        );
      }
    }
    for (final v in vectors) {
      if (v.length != EmbeddingSpec.dimensions) {
        throw EmbeddingException(
          'Expected ${EmbeddingSpec.dimensions} dims, got ${v.length}',
        );
      }
    }
    return vectors;
  }
}

class EmbeddingException implements Exception {
  EmbeddingException(this.message);
  final String message;
  @override
  String toString() => 'EmbeddingException: $message';
}

List<double> _normalize(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  if (sum == 0) return v;
  final norm = 1 / math.sqrt(sum);
  return [for (final x in v) x * norm];
}
