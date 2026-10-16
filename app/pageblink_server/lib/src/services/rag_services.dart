import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../providers/embedding_provider.dart';
import '../providers/gemini_embedding_provider.dart';
import '../providers/llm_provider.dart';
import '../providers/openrouter_llm_provider.dart';
import '../providers/rotating_llm_provider.dart';
import 'llm_catalog.dart';

/// Builds providers from server passwords (config/passwords.yaml or Cloud).
class RagServices {
  /// Tests only: replace the providers (no keys, no network).
  static EmbeddingProvider? debugEmbedding;
  static LlmProvider? debugLlm;

  /// Serverpod password (passwords.yaml, Cloud, or `SERVERPOD_PASSWORD_name`),
  /// falling back to a conventional environment variable.
  static String? _secret(Session session, String password, String envVar) {
    final value = session.passwords[password];
    if (value != null && value.isNotEmpty) return value;
    final env = Platform.environment[envVar];
    return env == null || env.isEmpty ? null : env;
  }

  /// Gemini (free tier) when `geminiApiKey` / GEMINI_API_KEY is set,
  /// otherwise DeepInfra EmbeddingGemma. Pick one per deployment: vectors
  /// from different models are not comparable.
  static EmbeddingProvider embedding(Session session) {
    final fake = debugEmbedding;
    if (fake != null) return fake;
    final gemini = _secret(session, 'geminiApiKey', 'GEMINI_API_KEY');
    if (gemini != null) return GeminiEmbeddingProvider(gemini);
    final key = _secret(session, 'deepinfraApiKey', 'DEEPINFRA_API_KEY');
    if (key == null) {
      throw StateError('Set password "geminiApiKey" or "deepinfraApiKey"');
    }
    return DeepInfraEmbeddingProvider(key);
  }

  /// OpenRouter (with model rotation) when `openrouterApiKey` is set,
  /// otherwise Claude direct. [modelId] comes from the app's model picker.
  static LlmProvider llm(Session session, {String? modelId}) {
    final fake = debugLlm;
    if (fake != null) return fake;
    final openRouterKey = _secret(
      session,
      'openrouterApiKey',
      'OPENROUTER_API_KEY',
    );
    if (openRouterKey != null && openRouterKey.isNotEmpty) {
      final chosen =
          modelId ?? session.passwords['llmModel'] ?? LlmCatalog.defaultModelId;
      final mode = session.passwords['llmRotation'] ?? 'free';
      return RotatingLlmProvider(
        LlmCatalog.rotation(chosen, mode: mode),
        (id) => OpenRouterLlmProvider(
          openRouterKey,
          model: id,
          denyDataCollection: !(LlmCatalog.byId(id)?.free ?? false),
        ),
        onRotate: (failed, error) => session.log(
          'LLM $failed unavailable, rotating: $error',
          level: LogLevel.warning,
        ),
      );
    }
    final anthropicKey = _secret(
      session,
      'anthropicApiKey',
      'ANTHROPIC_API_KEY',
    );
    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      return ClaudeLlmProvider(
        anthropicKey,
        model: session.passwords['claudeModel'] ?? 'claude-opus-5-5',
      );
    }
    throw StateError('Set password "openrouterApiKey" (or "anthropicApiKey")');
  }
}
