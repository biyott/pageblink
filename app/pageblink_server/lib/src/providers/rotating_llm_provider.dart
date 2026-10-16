import 'dart:async';

import '../services/daily_counter.dart';
import 'llm_provider.dart';

/// Tries models in order and moves to the next one when a model fails before
/// producing any text for a retryable reason (rate limit, free quota, outage)
/// or stays silent past [firstTokenTimeout]. Once text has streamed, errors
/// are surfaced instead of silently switching.
///
/// `modelIds.first` is the model the user (or the default) chose. Paid
/// fallback (ADR 014, task 10), only when [isFree] is given:
/// - [freeAttempts] limits how many free models are tried, the chosen one
///   included, before the paid ones. When the paid budget is used up the limit
///   does not apply: free models are all that is left to try.
/// - [paidCounter] caps how many answers per KST day may fall back to a paid
///   model (one use per answer). The chosen model is exempt: a user who picks
///   a paid model is not limited. In memory per instance (see
///   [DailyCounter]).
class _FirstTokenTimeout extends LlmException {
  _FirstTokenTimeout(Duration d)
    : super('No text within ${d.inSeconds}s', retryable: true);
}

class RotatingLlmProvider implements LlmProvider {
  RotatingLlmProvider(
    this.modelIds,
    this.providerFor, {
    this.onRotate,
    this.onPaidFallback,
    this.isFree,
    this.freeAttempts,
    this.firstTokenTimeout,
    this.paidCounter,
  });

  final List<String> modelIds;
  final LlmProvider Function(String modelId) providerFor;

  /// A model failed before any text. [reason] is `first-token-timeout`,
  /// `status 429`, or `error`: never the provider's message.
  final void Function(String failedModel, String reason)? onRotate;

  /// A free-to-paid fallback happened ([allowed]) or the daily cap blocked it
  /// ([modelId] is null then).
  final void Function(String? modelId, {required bool allowed})? onPaidFallback;

  final bool Function(String modelId)? isFree;
  final int? freeAttempts;

  /// Counted until the first answer text (`LlmText`, the model's `content`).
  /// Reasoning deltas never reach this class (the provider drops them), so a
  /// model that thinks out loud for a minute still times out.
  final Duration? firstTokenTimeout;
  final DailyCounter? paidCounter;

  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) async* {
    final free = isFree;
    final chosen = modelIds.isEmpty ? null : modelIds.first;
    // Peeking only: the use is taken when the first paid model is reached.
    final paidLeft = paidCounter == null || paidCounter!.remaining > 0;
    final limit = freeAttempts;

    // The plan: which of modelIds to try, in order.
    var freeCount = 0;
    var paidBlocked = false;
    final plan = <String>[];
    for (final id in modelIds) {
      final exempt = id == chosen;
      if (free == null || free(id)) {
        if (!exempt && limit != null && paidLeft && freeCount >= limit) {
          continue;
        }
        if (free != null) freeCount++;
        plan.add(id);
      } else if (exempt || paidLeft) {
        plan.add(id);
      } else {
        paidBlocked = true;
      }
    }

    Object? lastError;
    var paidCharged = false;
    for (final modelId in plan) {
      if (free != null && !free(modelId) && modelId != chosen) {
        if (!paidCharged) {
          if (paidCounter != null && !paidCounter!.tryConsume()) {
            paidBlocked = true;
            continue;
          }
          paidCharged = true;
          onPaidFallback?.call(modelId, allowed: true);
        }
      }
      var started = false;
      final it = StreamIterator(providerFor(modelId).answer(question, sources));
      final clock = Stopwatch()..start();
      try {
        while (true) {
          var next = it.moveNext();
          final timeout = firstTokenTimeout;
          if (!started && timeout != null) {
            final left = timeout - clock.elapsed;
            next = next.timeout(
              left > Duration.zero ? left : Duration.zero,
              onTimeout: () => throw _FirstTokenTimeout(timeout),
            );
          }
          if (!await next) break;
          final event = it.current;
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
        onRotate?.call(
          modelId,
          e is _FirstTokenTimeout
              ? 'first-token-timeout'
              : e.statusCode != null
              ? 'status ${e.statusCode}'
              : 'error',
        );
      } finally {
        // Not awaited: a generator stuck on the network only ends when it
        // wakes up, and the next model must not wait for it.
        unawaited(it.cancel().catchError((_) {}));
      }
    }
    // Every model failed or was out of budget: one message for both cases.
    if (paidBlocked) onPaidFallback?.call(null, allowed: false);
    throw LlmBusyException('All models are unavailable right now: $lastError');
  }
}
