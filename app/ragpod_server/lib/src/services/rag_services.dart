import 'package:serverpod/serverpod.dart';

import '../providers/embedding_provider.dart';
import '../providers/llm_provider.dart';

/// Builds providers from server passwords (config/passwords.yaml or Cloud).
class RagServices {
  static EmbeddingProvider embedding(Session session) {
    final key = session.passwords['deepinfraApiKey'];
    if (key == null || key.isEmpty) {
      throw StateError('Missing password "deepinfraApiKey"');
    }
    return DeepInfraEmbeddingProvider(key);
  }

  static LlmProvider llm(Session session) {
    final key = session.passwords['anthropicApiKey'];
    if (key == null || key.isEmpty) {
      throw StateError('Missing password "anthropicApiKey"');
    }
    return ClaudeLlmProvider(
      key,
      model: session.passwords['claudeModel'] ?? 'claude-opus-5-5',
    );
  }
}
