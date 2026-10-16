/// A positive integer from a password / environment value; [fallback] when
/// it is missing, not a number, or below [min].
int positiveInt(String? raw, int fallback, {int min = 1}) {
  final v = int.tryParse(raw?.trim() ?? '');
  return v == null || v < min ? fallback : v;
}

/// A boolean from a password / environment value: true, 1, yes or on.
bool truthy(String? raw) =>
    const {'true', '1', 'yes', 'on'}.contains(raw?.trim().toLowerCase());
