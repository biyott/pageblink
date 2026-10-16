import '../generated/protocol.dart';

/// Models offered in the app (ADR 014). The list is the picker order; the
/// automatic rotation uses the same order minus [manualOnly] (from the
/// 2026-10-16 OpenRouter measurement).
///
/// Free OpenRouter models share one account quota (20 req/min; 50/day, or
/// 1,000/day after buying ≥10 credits), so rotation mainly helps when a single
/// model is congested or rate-limited upstream.
class LlmCatalog {
  static final models = <LlmModel>[
    LlmModel(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super 120B',
      provider: 'openrouter',
      free: true,
      note: 'free · recommended · large model · fast',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      label: 'Nemotron 3 Ultra 550B',
      provider: 'openrouter',
      free: true,
      note: 'free · largest · may be slow',
    ),
    LlmModel(
      id: 'google/gemini-3.1-flash-lite',
      label: 'Gemini 3.1 Flash Lite',
      provider: 'openrouter',
      free: false,
      note: r'paid $0.25/$1.50 · fast',
    ),
    LlmModel(
      id: 'google/gemini-3.8-flash',
      label: 'Gemini 3.8 Flash',
      provider: 'openrouter',
      free: false,
      note: r'paid $0.75/$3.75 · quality · slower first token (~5s)',
    ),
    LlmModel(
      id: 'google/gemma-4-26b-a4b-it:free',
      label: 'Gemma 4 26B',
      provider: 'openrouter',
      free: true,
      note: 'free · multilingual · unstable · upstream limits',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3.5-lightning:free',
      label: 'Nemotron 3.5 Lightning',
      provider: 'openrouter',
      free: true,
      note: 'free · lightweight · unstable · may not respond',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
      label: 'Nemotron 3 Nano Omni',
      provider: 'openrouter',
      free: true,
      note: 'free · fast · unstable · upstream limits',
    ),
  ];

  static const defaultModelId = 'nvidia/nemotron-3-super-120b-a12b:free';

  /// Selectable, but never picked by the automatic rotation: measured
  /// unreliable (429 / no response / 502). A user who picks one still gets it
  /// as the first try, and the rotation continues after it when it fails.
  static const manualOnly = {
    'google/gemma-4-26b-a4b-it:free',
    'nvidia/nemotron-3.5-lightning:free',
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
  };

  /// The OpenRouter `reasoning` request field that turns thinking off, for the
  /// models that accept it (measured: first text 10-40 s on, under 1 s off).
  /// Not for the others: gemini-3.8-flash cannot switch it off (mandatory),
  /// and a value a model does not support may be answered with a 400.
  static const _reasoningOff = <String, Map<String, Object>>{
    'nvidia/nemotron-3-super-120b-a12b:free': {'effort': 'none'},
    'nvidia/nemotron-3-ultra-550b-a55b:free': {'effort': 'none'},
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free': {'enabled': false},
  };

  static Map<String, Object>? reasoningFor(String id) => _reasoningOff[id];

  static LlmModel? byId(String id) =>
      models.where((m) => m.id == id).firstOrNull;

  /// The chosen model first, then the rest of the automatic rotation in
  /// catalog order. [mode]: `free` (default) rotates only among free models,
  /// `all` also falls back to paid ones, `off` uses just the chosen model.
  static List<String> rotation(String chosen, {String mode = 'free'}) {
    if (mode == 'off') return [chosen];
    final rest = models
        .where(
          (m) =>
              m.id != chosen &&
              !manualOnly.contains(m.id) &&
              (mode == 'all' || m.free),
        )
        .map((m) => m.id);
    return [chosen, ...rest];
  }
}
