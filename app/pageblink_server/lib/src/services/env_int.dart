/// A positive integer from a password / environment value; [fallback] when
/// it is missing, not a number, or below [min].
int positiveInt(String? raw, int fallback, {int min = 1}) {
  final v = int.tryParse(raw?.trim() ?? '');
  return v == null || v < min ? fallback : v;
}
