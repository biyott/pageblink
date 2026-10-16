import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../providers/embedding_provider.dart';
import '../providers/gemini_embedding_provider.dart';
import '../providers/llm_provider.dart';
import '../providers/openrouter_llm_provider.dart';
import '../providers/rotating_llm_provider.dart';
import 'daily_counter.dart';
import 'env_int.dart';
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

  /// Free models tried (the chosen one included) before falling back to paid
  /// ones, `llmRotation=all` only (`LLM_FREE_ATTEMPTS`, 2).
  static int freeAttempts(Session session) => positiveInt(
    _secret(session, 'llmFreeAttempts', 'LLM_FREE_ATTEMPTS'),
    2,
  );

  /// Seconds to wait for the first text of a model before trying the next
  /// (`LLM_FIRST_TOKEN_TIMEOUT_SECONDS`, 10).
  static Duration firstTokenTimeout(Session session) => Duration(
    seconds: positiveInt(
      _secret(
        session,
        'llmFirstTokenTimeoutSeconds',
        'LLM_FIRST_TOKEN_TIMEOUT_SECONDS',
      ),
      10,
    ),
  );

  static DailyCounter? _paidCounter;

  /// Answers per KST day that may fall back to a paid model
  /// (`LLM_PAID_DAILY_CAP`, 300; 0 turns the paid fallback off). One counter
  /// per process, so with several instances the real total can be higher.
  static DailyCounter paidCounter(Session session) {
    final cap = positiveInt(
      _secret(session, 'llmPaidDailyCap', 'LLM_PAID_DAILY_CAP'),
      300,
      min: 0,
    );
    final c = _paidCounter;
    return c != null && c.limit == cap ? c : _paidCounter = DailyCounter(cap);
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
      final mode = _secret(session, 'llmRotation', 'LLM_ROTATION') ?? 'free';
      return RotatingLlmProvider(
        LlmCatalog.rotation(chosen, mode: mode),
        (id) => OpenRouterLlmProvider(
          openRouterKey,
          model: id,
          denyDataCollection: !(LlmCatalog.byId(id)?.free ?? false),
          reasoning: LlmCatalog.reasoningFor(id),
        ),
        isFree: (id) => LlmCatalog.byId(id)?.free ?? false,
        freeAttempts: mode == 'all' ? freeAttempts(session) : null,
        firstTokenTimeout: mode == 'off' ? null : firstTokenTimeout(session),
        paidCounter: mode == 'all' ? paidCounter(session) : null,
        // Model and reason only: never the question, answer or error body.
        onRotate: (failed, reason) => session.log(
          'LLM $failed unavailable ($reason), rotating',
          level: LogLevel.warning,
        ),
        onPaidFallback: (id, {required allowed}) => session.log(
          allowed
              ? 'LLM fallback free to paid: $id'
              : 'LLM paid fallback skipped: daily cap reached',
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
