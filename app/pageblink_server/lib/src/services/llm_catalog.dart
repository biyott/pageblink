import '../generated/protocol.dart';

/// Models offered in the app, in rotation order (ADR 014).
///
/// Free OpenRouter models share one account quota (20 req/min; 50/day, or
/// 1,000/day after buying ≥10 credits), so rotation mainly helps when a single
/// model is congested or rate-limited upstream.
class LlmCatalog {
  static final models = <LlmModel>[
    LlmModel(
      id: 'google/gemma-4-26b-a4b-it:free',
      label: 'Gemma 4 26B',
      provider: 'openrouter',
      free: true,
      note: 'free · recommended · multilingual · fast',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super 120B',
      provider: 'openrouter',
      free: true,
      note: 'free · large model',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3.5-lightning:free',
      label: 'Nemotron 3.5 Lightning',
      provider: 'openrouter',
      free: true,
      note: 'free · lightweight',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      label: 'Nemotron 3 Ultra 550B',
      provider: 'openrouter',
      free: true,
      note: 'free · largest · may be slow',
    ),
    LlmModel(
      id: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
      label: 'Nemotron 3 Nano Omni (reasoning)',
      provider: 'openrouter',
      free: true,
      note: 'free · reasoning · slower first token',
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
      note: r'paid $0.75/$3.75 · quality',
    ),
  ];

  static const defaultModelId = 'google/gemma-4-26b-a4b-it:free';

  static LlmModel? byId(String id) =>
      models.where((m) => m.id == id).firstOrNull;

  /// The chosen model first, then the rest in catalog order.
  /// [mode]: `free` (default) rotates only among free models, `all` also falls
  /// back to paid ones, `off` uses just the chosen model.
  static List<String> rotation(String chosen, {String mode = 'free'}) {
    if (mode == 'off') return [chosen];
    final rest = models
        .where((m) => m.id != chosen && (mode == 'all' || m.free))
        .map((m) => m.id);
    return [chosen, ...rest];
  }
}
