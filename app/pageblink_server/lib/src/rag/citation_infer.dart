// Links sources to an answer in which the model wrote no `[n]` marker at all
// (measured: about a third of the default model's answers). A source counts
// when its evidence text appears in the answer, so an answer that does not
// repeat any evidence ("not found in the documents") links nothing.

final _leading = RegExp(
  r'^[ \t]*(?:>[ \t]*)*(?:#{1,6}[ \t]+)?(?:(?:[-*+]|\d+[.)])[ \t]+)?'
  r'(?:\[[ xX]\][ \t]*)?',
  multiLine: true,
);
final _emphasis = RegExp(r'[*_`~]');
final _space = RegExp(r'\s');

/// [s] without quote / heading / list / checkbox prefixes and `* _ ` ~`,
/// with all whitespace removed.
String normalizeForMatch(String s) =>
    s.replaceAll(_leading, '').replaceAll(_emphasis, '').replaceAll(_space, '');

/// Evidence shorter than this (after normalizing) is too generic to match.
const minInferLength = 6;

/// At most this many sources are linked.
const maxInferred = 3;

/// 0-based indexes into [evidences] to link to [answer], ascending. Only for
/// an answer with no model citation: the caller decides that.
///
/// A candidate that is a substring of a longer candidate is dropped (the
/// longer one is the better match); of equal candidates the first stays.
/// Nothing matching means nothing is linked: never a top-k guess.
List<int> inferCitations(String answer, List<String> evidences) {
  final text = normalizeForMatch(answer);
  if (text.isEmpty) return const [];
  final cand = <int, String>{};
  for (var i = 0; i < evidences.length; i++) {
    final e = normalizeForMatch(evidences[i]);
    if (e.runes.length >= minInferLength && text.contains(e)) cand[i] = e;
  }
  final kept = <int>[];
  for (final MapEntry(key: i, value: e) in cand.entries) {
    final dominated = cand.entries.any(
      (o) =>
          o.key != i &&
          (o.value.length > e.length && o.value.contains(e) ||
              o.value == e && o.key < i),
    );
    if (!dominated) kept.add(i);
  }
  return kept.take(maxInferred).toList();
}
