import 'llm_provider.dart';

/// Tries models in order and moves to the next one when a model fails before
/// producing any text for a retryable reason (rate limit, free quota, outage).
/// Once text has streamed, errors are surfaced instead of silently switching.
class RotatingLlmProvider implements LlmProvider {
  RotatingLlmProvider(this.modelIds, this.providerFor, {this.onRotate});

  final List<String> modelIds;
  final LlmProvider Function(String modelId) providerFor;
  final void Function(String failedModel, Object error)? onRotate;

  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) async* {
    Object? lastError;
    for (final modelId in modelIds) {
      var started = false;
      try {
        await for (final event in providerFor(
          modelId,
        ).answer(question, sources)) {
          if (!started && event is LlmText) {
            started = true;
            yield LlmModelUsed(modelId);
          }
          yield event;
        }
        return;
      } on LlmException catch (e) {
        if (started || !e.retryable) rethrow;
        lastError = e;
        onRotate?.call(modelId, e);
      }
    }
    throw LlmException('All models are unavailable right now: $lastError');
  }
}
