// Links sources to an answer in which the model wrote no `[n]` marker at all
// (measured: about a third of the default model's answers). A source counts
// when its evidence text appears in the answer (forward), when a short
// phrase of the answer appears inside its evidence (reverse: "Nov 18, 2026"
// answering a whole evidence line), or when a sentence of the answer shares
// distinctive tokens with it (a date, a number with its unit, a long word:
// "출시일은 2026년 11월 18일입니다." for "- 출시일: 2026년 11월 18일로 변경").
// An answer that repeats nothing ("not found in the documents") links nothing.

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
/// Token match, last and only for a phrase (a sentence or line of the answer)
/// that neither of the above touched: see [_tokenLinks]. It only adds, and
/// only into the room left under [maxInferred]: it never changes or displaces
/// what the other two found.
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
  final untouched = <String>[]; // phrases left for the token match
  for (final raw in answer.replaceAll(_marker, '').split(_phraseBorder)) {
    final p = normalizeForMatch(raw);
    final n = p.runes.length;
    if (n == 0 || forward.any(p.contains)) continue;
    final hits = n < minInferLength || n > maxPhraseLength
        ? const <int>[]
        : [
            for (var i = 0; i < norm.length; i++)
              if (norm[i].contains(p) && norm.indexOf(norm[i]) == i) i,
          ];
    if (hits.isEmpty) {
      untouched.add(raw);
    } else if (hits.length <= maxInferred) {
      all.addAll(hits);
    }
  }
  final out = (all.toList()..sort()).take(maxInferred).toList();
  for (final i in _tokenLinks(untouched, evidences, norm)) {
    if (out.length < maxInferred && !out.contains(i)) out.add(i);
  }
  return out..sort();
}

// ---- token match ------------------------------------------------------------

/// A phrase that says "not found": its tokens are about what is missing, never
/// a source for it.
final _negation = RegExp(
  '찾을 수 없|찾지 못|확인되지|확인할 수 없|언급되|없습니다|않습니다|않아요|'
  r"not found|could not|couldn't|cannot|can't|do(?:es)? not|don't|doesn't|"
  r'no information|not mention|unable|isn.t (?:stated|mentioned)',
  caseSensitive: false,
);

const _monthNames =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|'
    r'aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
const _ord = r'(?:st|nd|rd|th)?';

/// Date forms, most specific first: the pattern, then the group numbers of
/// year, month and day (0 = the form has none). A month is a number or a name.
final _dateForms = <(RegExp, int, int, int)>[
  (
    RegExp(r'(?<!\d)(\d{4})\s*[-./]\s*(\d{1,2})\s*[-./]\s*(\d{1,2})(?!\d)'),
    1,
    2,
    3,
  ),
  (RegExp(r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일'), 1, 2, 3),
  (
    RegExp(
      r'\b' +
          _monthNames +
          r'\.?\s+(\d{1,2})' +
          _ord +
          r'(?:\s*,\s*|\s+)(\d{4})\b',
    ),
    3,
    1,
    2,
  ),
  (
    RegExp(r'\b(\d{1,2})' + _ord + r'\s+' + _monthNames + r'\.?,?\s+(\d{4})\b'),
    3,
    2,
    1,
  ),
  (RegExp(r'(\d{4})\s*년\s*(\d{1,2})\s*월'), 1, 2, 0),
  (RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일'), 0, 1, 2),
  (RegExp(r'\b' + _monthNames + r'\.?\s+(\d{1,2})' + _ord + r'\b'), 0, 1, 2),
  (RegExp(r'\b(\d{1,2})' + _ord + r'\s+' + _monthNames + r'\b'), 0, 2, 1),
];

const _unitKo =
    r'(?:만\s?원|억\s?원|천\s?원|분기|개월|원|만|억|천|명|개|건|회|%|퍼센트|달러|주|시간|분|초|일|배|대|곳|점|위|차|장|권)';
const _unitEn =
    r'(?:\s?(?:percent|million|billion|thousand|people|persons|users?|'
    r'customers?|days?|weeks?|months?|years?|hours?|minutes?|seconds?|items?|'
    r'points?|ms|gb|mb|kb|tb|kg|km|usd|krw|eur)(?![a-z])|[kmb](?![a-z]))';

/// A number with its unit ("1,200만 원", "300 ms", "12M") or a currency sign.
/// A bare number is not distinctive: it is skipped.
final _quantity = RegExp(
  r'(?<![a-z0-9.,])([₩$€£¥])?\s?(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?'
  '(\\s?$_unitKo|$_unitEn)?',
);
final _magnitude = RegExp(r'^(?:만|억|천|million|billion|thousand|[kmb])$');
final _wordRe = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _hangul = RegExp(r'^[가-힣]+$');
final _wonSuffix = RegExp('(만|억|천)원');

/// Particles and endings stripped from the end of a Hangul word, longest
/// first; at least two syllables must stay.
const _suffixes = [
  '이었습니다', '였습니다', '했습니다', '입니다', '합니다', '됩니다', '습니다', //
  '으로는', '에서는', '에게는', '으로써', '이라고', '이라는', '에서의', //
  '으로', '에서', '에게', '까지', '부터', '처럼', '보다', '이며', '이고', '이다',
  '하는', '되는', '하고', '하며', '에는', '로는', '와의', '과의', //
  '은', '는', '이', '가', '을', '를', '의', '에', '도', '로', '와', '과',
];
const _stop = {
  '입니다', '있습니다', '없습니다', '합니다', '됩니다', '대한', '위한', '관련', //
  '다음', '경우', '통해', '또는', '그리고', '하지만', '현재', '문서', '내용', '정보',
  'that', 'this', 'with', 'from', 'have', 'will', 'were', 'been', 'there',
  'their', 'which', 'about', 'would', 'could', 'should', 'also', 'into',
};
const _months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

/// Distinctive tokens of [raw] (token -> weight) and its plain words.
/// Distinctive: a date (`d:` full date, `ym:`, `md:`), a number with unit or
/// currency sign (`q:`), a long word (`l:`: 6+ Hangul syllables or 12+
/// letters, particle and ending stripped). [expand]: an evidence line also
/// offers the coarser forms of its full dates, so that an answer's "Nov 18"
/// finds "Nov 18, 2026", but "Nov 18, 2026" never finds a line with no year.
({Map<String, int> strong, Set<String> words}) _tokenize(
  String raw, {
  required bool expand,
}) {
  var t = raw.replaceAll(_leading, '').replaceAll(_emphasis, '').toLowerCase();
  final strong = <String, int>{};
  for (final (re, yi, mi, di) in _dateForms) {
    t = t.replaceAllMapped(re, (m) {
      final y = yi == 0 ? null : m[yi]!;
      final mo =
          int.tryParse(m[mi]!) ?? _months.indexOf(m[mi]!.substring(0, 3)) + 1;
      final d = di == 0 ? null : int.parse(m[di]!);
      if (mo < 1 || mo > 12 || d != null && (d < 1 || d > 31)) return m[0]!;
      if (y != null && d != null) {
        strong['d:$y-$mo-$d'] = 2;
        if (expand) {
          strong['ym:$y-$mo'] = 1;
          strong['md:$mo-$d'] = 2;
        }
      } else if (y != null) {
        strong['ym:$y-$mo'] = 1;
      } else {
        strong['md:$mo-$d'] = 2;
      }
      return ' ';
    });
  }
  t = t.replaceAllMapped(_quantity, (m) {
    final cur = m[1], dec = m[3], unit = m[4]?.replaceAll(_space, '');
    if (cur == null && unit == null) return m[0]!;
    final digits = m[2]!.replaceAll(',', '');
    var u = (unit ?? '').replaceAllMapped(_wonSuffix, (x) => x[1]!);
    u = switch (u) {
      '퍼센트' || 'percent' => '%',
      'people' || 'persons' => 'person',
      _ when u.length > 3 && u.endsWith('s') => u.substring(0, u.length - 1),
      _ => u,
    };
    final heavy =
        cur != null ||
        dec != null ||
        _magnitude.hasMatch(u) ||
        digits.length >= 3 && u != '%';
    strong['q:${cur ?? ''}$digits${dec ?? ''}$u'] = heavy ? 2 : 1;
    return ' ';
  });
  final words = <String>{};
  for (final m in _wordRe.allMatches(t)) {
    var w = m[0]!;
    if (int.tryParse(w) != null) continue;
    if (_hangul.hasMatch(w)) {
      for (final suf in _suffixes) {
        if (w.endsWith(suf) && w.length - suf.length >= 2) {
          w = w.substring(0, w.length - suf.length);
          break;
        }
      }
      if (w.length < 2 || _stop.contains(w)) continue;
      if (w.length >= 6) strong['l:$w'] = 2;
    } else {
      if (w.length > 4 && w.endsWith('s') && !w.endsWith('ss')) {
        w = w.substring(0, w.length - 1);
      }
      if (w.length < 4 || _stop.contains(w)) continue;
      if (w.length >= 12) strong['l:$w'] = 2;
    }
    words.add(w);
  }
  return (strong: strong, words: words);
}

int _sharedWords(Set<String> a, Set<String> b) => a
    .where(
      (x) => b.any(
        (y) =>
            x == y ||
            x.length >= 2 && y.contains(x) ||
            y.length >= 2 && x.contains(y),
      ),
    )
    .length;

/// Evidences that a sentence of the answer is built on, by distinctive tokens:
///  - a token counts only if exactly one evidence has it (a token in two
///    lines does not tell them apart: ignored, like an ambiguous phrase);
///  - an evidence is linked when it holds two such tokens, or one heavy token
///    AND plain words of the sentence it shares: a long word (any 6+ Hangul /
///    12+ letter word) needs 1 other shared word, a full date with a year 1,
///    a month-day date or a number of 3+ digits or with a magnitude /
///    currency sign 2.
/// So a lone small number ("8명", "3개") never links, a date or amount links
/// only with its subject words ("출시일"), and another day ("11월 28일" for
/// "11월 18일") is simply another token.
List<int> _tokenLinks(
  List<String> phrases,
  List<String> evidences,
  List<String> norm,
) {
  if (phrases.isEmpty) return const [];
  final lines = [
    for (var i = 0; i < evidences.length; i++)
      norm[i].isEmpty || norm.indexOf(norm[i]) != i
          ? null
          : _tokenize(evidences[i], expand: true),
  ];
  final owners = <String, int>{};
  for (final l in lines.nonNulls) {
    for (final k in l.strong.keys) {
      owners[k] = (owners[k] ?? 0) + 1;
    }
  }
  final out = <int>{};
  for (final raw in phrases) {
    if (_negation.hasMatch(raw)) continue;
    final a = _tokenize(raw, expand: false);
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l == null) continue;
      final hits = [
        for (final k in a.strong.keys)
          if (owners[k] == 1 && l.strong.containsKey(k)) k,
      ];
      if (hits.isEmpty) continue;
      final weight = hits.fold(0, (s, k) => s + a.strong[k]!);
      final long = {
        for (final k in hits)
          if (k.startsWith('l:')) k.substring(2),
      };
      final need = hits.any((k) => k.startsWith('d:'))
          ? 1
          : long.isNotEmpty
          ? 1
          : 2;
      if (hits.length >= 2 ||
          weight >= 2 &&
              _sharedWords(a.words.difference(long), l.words) >= need) {
        out.add(i);
      }
    }
  }
  return out.toList()..sort();
}
