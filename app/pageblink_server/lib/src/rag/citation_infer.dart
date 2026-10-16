// Links sources to an answer in which the model wrote no `[n]` marker at all
// (measured: about a third of the default model's answers). A source counts
// when its evidence text appears in the answer (forward), or when a short
// phrase of the answer appears inside its evidence (reverse: "Nov 18, 2026"
// answering a whole evidence line). An answer that repeats nothing ("not
// found in the documents") links nothing.

final _leading = RegExp(
  r'^[ \t]*(?:>[ \t]*)*(?:#{1,6}[ \t]+)?(?:(?:[-*+]|\d+[.)])[ \t]+)?'
  r'(?:\[[ xX]\][ \t]*)?',
  multiLine: true,
);
final _emphasis = RegExp(r'[*_`~]');
final _space = RegExp(r'\s');

/// [s] without quote / heading / list / checkbox prefixes and `* _ ` ~`,
/// with all whitespace removed, lower case.
String normalizeForMatch(String s) => s
    .replaceAll(_leading, '')
    .replaceAll(_emphasis, '')
    .replaceAll(_space, '')
    .toLowerCase();

// Phrase borders of an answer: line breaks, sentence ends (a `.` inside
// "1.5" or "a.com" is not one), and a colon before a space. A comma never
// splits: "Nov 18, 2026" and "1,200만 원" must stay whole.
final _phraseBorder = RegExp(r'[\r\n]+|[.!?](?=\s|$)|。|:(?=\s)|：');
final _marker = RegExp(r'\[\d{1,3}\]');

/// Evidence shorter than this (after normalizing) is too generic to match.
const minInferLength = 6;

/// At most this many sources are linked.
const maxInferred = 3;

/// A reverse phrase is at most this long (a longer one is a sentence).
const maxPhraseLength = 80;

/// 0-based indexes into [evidences] to link to [answer], ascending. Only for
/// an answer with no model citation: the caller decides that.
///
/// A candidate that is a substring of a longer candidate is dropped (the
/// longer one is the better match); of equal candidates the first stays.
///
/// Reverse match, added to those: each phrase of the answer (6..80 characters
/// normalized) that sits inside an evidence links that evidence. Skipped: a
/// phrase that already contains a forward match (the forward match explains
/// it, and a longer evidence around it would only be a wrong extra), and an
/// ambiguous phrase found in more than [maxInferred] evidences. Reverse
/// candidates do not yield to each other: of two evidences around the same
/// phrase neither is a better guess.
///
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
  final forward = cand.values.toList();
  final all = {...kept};
  final norm = [for (final e in evidences) normalizeForMatch(e)];
  for (final raw in answer.replaceAll(_marker, '').split(_phraseBorder)) {
    final p = normalizeForMatch(raw);
    final n = p.runes.length;
    if (n < minInferLength || n > maxPhraseLength) continue;
    if (forward.any(p.contains)) continue;
    final hits = [
      for (var i = 0; i < norm.length; i++)
        if (norm[i].contains(p) && norm.indexOf(norm[i]) == i) i,
    ];
    if (hits.length <= maxInferred) all.addAll(hits);
  }
  return (all.toList()..sort()).take(maxInferred).toList();
}
