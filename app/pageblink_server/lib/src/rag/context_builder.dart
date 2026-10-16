// Two-tier context for Ask (design 029 §4). Pure Dart.
//
// Small unit = a stored chunk: searched, numbered `[n]`, cited. Large unit =
// the note's heading section / a window of 2+2 chunks of a PDF page: computed
// here from the stored text when asking, never stored or embedded, given to
// the model as CONTEXT only.

import 'line_chunker.dart';

/// Total characters (evidence + context) handed to the model.
const contextBudgetChars = 6000;

/// A note's heading section longer than this shrinks to a window of whole
/// chunks around the hit.
const noteContextMax = 1000;

/// A PDF window of +-[pdfWindow] chunks; windows that touch merge while
/// they stay under [pdfContextMax] (+ one chunk of slack).
const pdfWindow = 2;
const pdfContextMax = 700;

/// A retrieved small unit (one stored `DocChunk`).
class HitInput {
  const HitInput({
    required this.documentId,
    required this.page,
    required this.ordinal,
    required this.text,
  });

  final int documentId;
  final int page;
  final int ordinal;
  final String text;
}

/// What the builder needs of a document. [body] is the note's markdown.
class DocInput {
  const DocInput({required this.kind, required this.title, this.body});

  final String kind;
  final String title;
  final String? body;
}

/// One numbered source: `[n]` is its index + 1 in the planned list.
class SourcePlan {
  SourcePlan({
    required this.documentId,
    required this.page,
    required this.title,
    required this.evidence,
    this.quoteStart,
  });

  final int documentId;
  final int page;

  /// Label for the model: `Doc › Heading › Item (note)` or `Doc (p.N)`.
  final String title;

  /// The small unit: what `[n]` cites, and the citation `quote`.
  final String evidence;

  /// Offset of [evidence] in the note body (UTF-16 units); null for PDFs and
  /// when the stored chunk no longer matches the text (expansion skipped).
  final int? quoteStart;

  /// The large unit, on the first (best-ranked) source that falls in it.
  String? context;

  /// Index (0-based) of the earlier source that carries this one's context.
  int? contextRef;

  int get length => evidence.length + (context?.length ?? 0);
}

/// Quote and offset of the citation for [plan] when the model cites
/// [citedText] (empty when it cites the whole source, as `[n]` markers do).
({String quote, int? start}) citationQuote(SourcePlan plan, String citedText) {
  if (citedText.isEmpty || citedText == plan.evidence) {
    return (quote: plan.evidence, start: plan.quoteStart);
  }
  final i = plan.evidence.indexOf(citedText);
  final base = plan.quoteStart;
  return (quote: citedText, start: base == null || i < 0 ? null : base + i);
}

/// Heading sections of a note: `[start, end)` from a heading line to the next
/// heading line (any level); text before the first heading is its own.
/// Fenced code is skipped.
List<(int, int)> noteSections(String body) {
  final heads = <int>[];
  var pos = 0;
  var fence = false;
  final fenceRe = RegExp(r'^[ \t]*(```|~~~)');
  final headRe = RegExp(r'^ {0,3}#{1,6}([ \t]|$)');
  while (pos <= body.length) {
    var nl = body.indexOf('\n', pos);
    if (nl < 0) nl = body.length;
    final line = body.substring(pos, nl);
    if (fenceRe.hasMatch(line)) fence = !fence;
    if (!fence && headRe.hasMatch(line)) heads.add(pos);
    if (nl >= body.length) break;
    pos = nl + 1;
  }
  final out = <(int, int)>[];
  var prev = 0;
  for (final h in [...heads, body.length]) {
    if (h > prev) out.add((prev, h));
    prev = h;
  }
  return out;
}

class _Loc {
  _Loc(this.docId, this.page, this.chunks, this.index, this.text, [this.set]);
  final int docId;
  final int page;

  /// Which chunk list of a PDF page (`doc:page:target`); null for notes.
  final String? set;
  final List<LineChunk> chunks;
  final int index;
  final String text; // note body or page text
}

/// Plans the numbered sources for [hits] (ranked best first): resolves each
/// hit's large unit from the stored text, loads it once per unit, and fits
/// the total into [maxChars] (context first, then the lowest-ranked hits).
/// The result is a prefix of [hits], so `[n]` stays `hits[n - 1]`.
///
/// A hit whose stored chunk does not match what the current rules produce
/// from the stored text (edited note not re-indexed yet, older chunk rules)
/// gets no context and no offset: evidence only.
List<SourcePlan> planSources(
  List<HitInput> hits, {
  required DocInput? Function(int documentId) doc,
  required String? Function(int documentId, int page) pageText,
  int maxChars = contextBudgetChars,
}) {
  final noteChunks = <int, List<LineChunk>>{};
  final pdfChunks = <String, List<LineChunk>>{};
  final plans = <SourcePlan>[];
  final locs = <int, _Loc>{};

  for (final (i, h) in hits.indexed) {
    final d = doc(h.documentId);
    _Loc? loc;
    String? path;
    int? start;
    if (d != null && d.kind == 'note' && d.body != null) {
      final cs = noteChunks[h.documentId] ??= chunkNote(
        d.body!,
        docTitle: d.title,
      );
      if (h.ordinal >= 0 &&
          h.ordinal < cs.length &&
          cs[h.ordinal].text == h.text) {
        loc = _Loc(h.documentId, 1, cs, h.ordinal, d.body!);
        path = cs[h.ordinal].path;
        start = cs[h.ordinal].start;
      }
    } else if (d != null) {
      final text = pageText(h.documentId, h.page);
      if (text != null) {
        // The page target (120, or 300 in a large document) is not stored:
        // the chunk text tells which one produced it.
        for (final target in const [120, 300]) {
          final cs = pdfChunks['${h.documentId}:${h.page}:$target'] ??=
              chunkPdfPage(
                h.page,
                text,
                rules: ChunkRules(targetChars: target),
              );
          final idx = cs.indexWhere((c) => c.text == h.text);
          if (idx >= 0) {
            loc = _Loc(
              h.documentId,
              h.page,
              cs,
              idx,
              text,
              '${h.documentId}:${h.page}:$target',
            );
            break;
          }
        }
      }
    }
    if (loc != null) locs[i] = loc;
    final isNote = d?.kind == 'note';
    plans.add(
      SourcePlan(
        documentId: h.documentId,
        page: h.page,
        title: isNote
            ? (path != null && path.isNotEmpty
                  ? '${d!.title} › $path (note)'
                  : '${d!.title} (note)')
            : '${d?.title ?? 'Document'} (p.${h.page})',
        evidence: h.text,
        quoteStart: isNote ? start : null,
      ),
    );
  }

  // Large unit of every located hit: (key, text), PDF windows merged per page.
  final unit = <int, (String, String)>{};
  final byPage = <String, List<int>>{};
  for (final (i, loc) in locs.entries.map((e) => (e.key, e.value))) {
    if (doc(loc.docId)!.kind == 'note') {
      final (a, b) = _noteUnit(loc);
      unit[i] = ('${loc.docId}:$a-$b', loc.text.substring(a, b));
    } else {
      byPage.putIfAbsent(loc.set!, () => []).add(i);
    }
  }
  for (final group in byPage.values) {
    group.sort((x, y) => locs[x]!.index.compareTo(locs[y]!.index));
    for (final w in _pdfWindows([
      for (final i in group) locs[i]!.index,
    ], locs[group.first]!.chunks)) {
      final loc = locs[group.first]!;
      final a = loc.chunks[w.lo].start, b = loc.chunks[w.hi].end;
      final value = (
        '${loc.docId}:${loc.page}:$a-$b',
        loc.text.substring(a, b),
      );
      for (final k in w.hits) {
        unit[group[k]] = value;
      }
    }
  }

  // The best-ranked hit of a unit carries its text, the rest point to it.
  final carrier = <String, int>{};
  for (var i = 0; i < plans.length; i++) {
    final u = unit[i];
    if (u == null) continue;
    final first = carrier.putIfAbsent(u.$1, () => i);
    if (first == i) {
      plans[i].context = u.$2;
    } else {
      plans[i].contextRef = first;
    }
  }
  return _fit(plans, maxChars);
}

/// A note hit's large unit as `[a, b)` of the body: its heading section, or
/// a window of whole chunks inside it when the section is too long.
(int, int) _noteUnit(_Loc loc) {
  final c = loc.chunks[loc.index];
  var a = 0, b = loc.text.length;
  for (final (s, e) in noteSections(loc.text)) {
    if (c.start >= s && c.start < e) {
      a = s;
      b = e;
      break;
    }
  }
  while (b > a && loc.text.codeUnitAt(b - 1) <= 32) {
    b--;
  }
  if (b - a <= noteContextMax) return (a, b);
  final cs = loc.chunks;
  bool inside(int k) => cs[k].start >= a && cs[k].end <= b;
  var lo = loc.index, hi = loc.index;
  while (true) {
    var grew = false;
    if (lo > 0 &&
        inside(lo - 1) &&
        cs[hi].end - cs[lo - 1].start <= noteContextMax) {
      lo--;
      grew = true;
    }
    if (hi + 1 < cs.length &&
        inside(hi + 1) &&
        cs[hi + 1].end - cs[lo].start <= noteContextMax) {
      hi++;
      grew = true;
    }
    if (!grew) break;
  }
  return (cs[lo].start, cs[hi].end);
}

/// Windows of +-[pdfWindow] chunks around [indices] (sorted chunk indices of
/// one page); touching windows merge while short. `hits` are positions in
/// [indices].
List<({int lo, int hi, List<int> hits})> _pdfWindows(
  List<int> indices,
  List<LineChunk> cs,
) {
  final cap = pdfContextMax + 200;
  final wins = <({int lo, int hi, List<int> hits})>[];
  for (final (k, i) in indices.indexed) {
    final lo = (i - pdfWindow).clamp(0, cs.length - 1);
    final hi = (i + pdfWindow).clamp(0, cs.length - 1);
    if (wins.isNotEmpty && lo <= wins.last.hi + 1) {
      final w = wins.last;
      final nh = hi > w.hi ? hi : w.hi;
      if (cs[nh].end - cs[w.lo].start <= cap) {
        wins[wins.length - 1] = (lo: w.lo, hi: nh, hits: [...w.hits, k]);
        continue;
      }
    }
    wins.add((lo: lo, hi: hi, hits: [k]));
  }
  // A lone hit's window may be too long (5 chunks of 300): shrink the side
  // farther from the hit.
  return [
    for (final w in wins)
      () {
        var lo = w.lo, hi = w.hi;
        final i = indices[w.hits.first];
        while (hi > lo && cs[hi].end - cs[lo].start > cap) {
          if (i - lo > hi - i) {
            lo++;
          } else {
            hi--;
          }
        }
        return (lo: lo, hi: hi, hits: w.hits);
      }(),
  ];
}

/// Drops context from the lowest-ranked source up, then the lowest-ranked
/// sources themselves, until the total is within [maxChars]. Evidence of the
/// best source is never dropped.
List<SourcePlan> _fit(List<SourcePlan> plans, int maxChars) {
  var total = plans.fold<int>(0, (a, p) => a + p.length);
  for (var i = plans.length - 1; i >= 0 && total > maxChars; i--) {
    final c = plans[i].context;
    if (c == null) continue;
    total -= c.length;
    plans[i].context = null;
    for (final p in plans) {
      if (p.contextRef == i) p.contextRef = null;
    }
  }
  var n = plans.length;
  while (n > 1 && total > maxChars) {
    total -= plans[--n].length;
  }
  return plans.sublist(0, n);
}
