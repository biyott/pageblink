import 'llm_provider.dart';

/// Google Gemini API direct (AI Studio key). Not implemented yet: Gemini
/// models are reachable through OpenRouter today (ADR 013). Implement this
/// when a direct free-tier quota is needed in addition to OpenRouter's.
class GeminiLlmProvider implements LlmProvider {
  GeminiLlmProvider(this.apiKey, {required this.model});

  final String apiKey;
  final String model;

  @override
  Stream<LlmEvent> answer(
    String question,
    List<SourcePassage> sources, {
    List<ChatTurn> history = const [],
  }) => Stream.error(
    LlmException(
      'Gemini direct provider is not implemented yet',
      retryable: true,
    ),
  );
}
