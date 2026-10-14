import 'package:serverpod/serverpod.dart';

import '../providers/embedding_provider.dart';
import '../providers/llm_provider.dart';
import '../providers/openrouter_llm_provider.dart';

/// Builds providers from server passwords (config/passwords.yaml or Cloud).
class RagServices {
  static EmbeddingProvider embedding(Session session) {
    final key = session.passwords['deepinfraApiKey'];
    if (key == null || key.isEmpty) {
      throw StateError('Missing password "deepinfraApiKey"');
    }
    return DeepInfraEmbeddingProvider(key);
  }

  /// OpenRouter when `openrouterApiKey` is set (default), otherwise Claude direct.
  static LlmProvider llm(Session session) {
    final openRouterKey = session.passwords['openrouterApiKey'];
    if (openRouterKey != null && openRouterKey.isNotEmpty) {
      return OpenRouterLlmProvider(
        openRouterKey,
        model: session.passwords['llmModel'] ?? 'anthropic/claude-haiku-5.5',
      );
    }
    final anthropicKey = session.passwords['anthropicApiKey'];
    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      return ClaudeLlmProvider(
        anthropicKey,
        model: session.passwords['claudeModel'] ?? 'claude-opus-5-5',
      );
    }
    throw StateError('Set password "openrouterApiKey" (or "anthropicApiKey")');
  }
}
