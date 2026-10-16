// Line/block-level chunking (design 029, "chunker v2"). Pure Dart: no
// Serverpod imports, same as `chunker.dart` (v1, kept for rollback).
//
// Notes: one chunk per markdown line/block, `text == body.substring(start,
// end)` (markers kept), headings are a path and not chunks. PDFs: sentences
// packed to ~120 chars (max 300). The heading path is used for the embedding
// input only (`embeddingTitle`), never stored or cited.

import '../rag/text_norm.dart';

/// One citable chunk. For notes `text == source.substring(start, end)`; for
/// PDFs `text` is the source slice with whitespace runs collapsed.
class LineChunk {
  LineChunk(
    this.page,
    this.ordinal,
    this.start,
    this.end,
    this.text,
    this.path,
    this.kind,
  );

  final int page;
  int ordinal;

  /// Offsets into the page text (notes: the body). UTF-16 code units.
  final int start;
  final int end;
  final String text;

  /// Heading path (+ parent list items), embedding-only. `' > '` joined.
  final String path;

  /// para | list | quote | table | code | heading | merged | packed | pdf
  final String kind;
}

class ChunkRules {
  const ChunkRules({
    this.packSmall = false,
    this.maxChars = 300,
    this.codeMaxChars = 600,
    this.targetChars = 120,
    this.minVisible = 6,
    this.minPdfChars = 40,
  });

  /// Paragraph / sentence-pack cap.
  final int maxChars;

  /// Fenced code cap.
  final int codeMaxChars;

  /// Close a pack once it reaches this (at a sentence end).
  final int targetChars;

  /// Notes: merge units with fewer visible chars than this.
  final int minVisible;

  /// PDF: merge tails shorter than this.
  final int minPdfChars;

  /// Large notes: also pack adjacent same-path lines up to [maxChars].
  final bool packSmall;
}

/// A note longer than this packs adjacent lines (3,000 lines -> ~480 chunks).
const largeNoteChars = 20000;

/// A PDF with more text than this (all pages) uses a 300-char target, to cap
/// the number of embedding calls.
const largePdfChars = 60000;

/// Heading path of the embedding `title:` slot is cut to this many chars.
const embeddingTitleMax = 120;

// ── shared helpers ──────────────────────────────────────────────────────

bool _isWs(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d || c == 0xa0;

bool _isHigh(int c) => c >= 0xD800 && c <= 0xDBFF;
bool _isLow(int c) => c >= 0xDC00 && c <= 0xDFFF;

const _abbrev = <String>{
  'e.g', 'i.e', 'etc', 'vs', 'mr', 'mrs', 'ms', 'dr', 'prof', 'fig', 'no', //
  'p', 'pp', 'inc', 'ltd', 'co', 'approx', 'u.s', 'jan', 'feb', 'mar', 'apr',
  'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec',
};
const _closers = '"\'”’)]」』>';
const _enders = '.!?。！？…';
const _fullwidth = '。！？';
final _digits = RegExp(r'^\d+$');
final _lowerAscii = RegExp(r'[a-z]');

/// End offsets (exclusive) of sentences in [s]. Breaks after `. ! ? 。 …`
/// when followed by whitespace (always for fullwidth marks), except decimals
/// and versions (no whitespace after the dot), abbreviations, 1-3 digit
/// numbers (list numbers), single letters and a dot followed by a lowercase
/// ASCII letter.
List<int> sentenceEnds(String s) {
  final ends = <int>[];
  final n = s.length;
  var i = 0;
  while (i < n) {
    final ch = s[i];
    if (!_enders.contains(ch)) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < n && _enders.contains(s[j])) {
      j++;
    }
    while (j < n && _closers.contains(s[j])) {
      j++;
    }
    final atBoundary =
        j >= n || _isWs(s.codeUnitAt(j)) || _fullwidth.contains(s[j - 1]);
    var split = atBoundary;
    if (split && ch == '.' && j - i == 1) {
      var a = i;
      while (a > 0 && !_isWs(s.codeUnitAt(a - 1))) {
        a--;
      }
      final token = s.substring(a, i).toLowerCase();
      if (_abbrev.contains(token)) split = false;
      if (token.isNotEmpty && token.length <= 3 && _digits.hasMatch(token)) {
        split = false;
      }
      if (token.length == 1 && _lowerAscii.hasMatch(token)) split = false;
      var k = j;
      while (k < n && _isWs(s.codeUnitAt(k))) {
        k++;
      }
      if (k < n && _lowerAscii.hasMatch(s[k])) split = false;
    }
    if (split) ends.add(j);
    i = j;
  }
  if (ends.isEmpty || ends.last != n) ends.add(n);
  return ends;
}

/// Cuts [a,b) of [s] into pieces of at most [max] chars: at the last
/// whitespace in the window, else a hard cut that never splits a surrogate
/// pair.
List<(int, int)> _cutLong(String s, int a, int b, int max) {
  final out = <(int, int)>[];
  var p = a;
  while (b - p > max) {
    var cut = -1;
    for (var k = p + max; k > p + max ~/ 2; k--) {
      if (_isWs(s.codeUnitAt(k))) {
        cut = k;
        break;
      }
    }
    if (cut < 0) {
      cut = p + max;
      if (_isHigh(s.codeUnitAt(cut - 1))) cut--;
    }
    out.add((p, cut));
    p = cut;
    while (p < b && _isWs(s.codeUnitAt(p))) {
      p++;
    }
  }
  if (p < b) out.add((p, b));
  return out;
}

/// Greedy packing of the sentences of `s[from, to)` into spans of at most
/// [max] chars, closing a span once it reaches [target]. Returns `[start,
/// end)` spans into [s].
List<(int, int)> _pack(
  String s,
  int from,
  int to,
  int max, [
  int target = 1 << 30,
]) {
  final sub = s.substring(from, to);
  final spans = <(int, int)>[];
  var st = 0;
  for (final e in sentenceEnds(sub)) {
    var a = st;
    while (a < e && _isWs(sub.codeUnitAt(a))) {
      a++;
    }
    var b = e;
    while (b > a && _isWs(sub.codeUnitAt(b - 1))) {
      b--;
    }
    if (b > a) {
      if (b - a > max) {
        spans.addAll(_cutLong(sub, a, b, max));
      } else {
        spans.add((a, b));
      }
    }
    st = e;
  }
  final out = <(int, int)>[];
  int? cs, ce;
  for (final (a, b) in spans) {
    if (cs == null) {
      cs = a;
      ce = b;
    } else if (b - cs <= max && ce! - cs < target) {
      ce = b;
    } else {
      out.add((from + cs, from + ce!));
      cs = a;
      ce = b;
    }
  }
  if (cs != null) out.add((from + cs, from + ce!));
  return out;
}

// ── notes ───────────────────────────────────────────────────────────────

final _fenceRe = RegExp(r'^[ \t]*(`{3,}|~{3,})');
final _headRe = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*#*[ \t]*$');
final _hrRe = RegExp(r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
final _listRe = RegExp(r'^([ \t]*)(?:[-*+]|\d{1,9}[.)])[ \t]+');
final _quoteRe = RegExp(r'^[ \t]{0,3}>');
final _tableRe = RegExp(r'^[ \t]*\|');
final _continuationRe = RegExp(r'^(?: {2,}|\t)');
final _markers = RegExp(
  r'^(?:[ \t]*>)*[ \t]*(?:#{1,6}[ \t]+)?(?:(?:[-*+]|\d{1,9}[.)])[ \t]+)?(?:\[[ xX]\][ \t]*)?',
);
final _linkRe = RegExp(r'!?\[([^\]]*)\]\([^)]*\)');
final _emphasisRe = RegExp(r'[*_`~]');

String _plain(String s) =>
    s.replaceAll(_linkRe, r'$1').replaceAll(_emphasisRe, '').trim();

/// Visible length of the first line, markers and emphasis stripped.
int _visible(String t) {
  final first = t.split('\n').first;
  return _plain(first.replaceFirst(_markers, '')).runes.length;
}

/// [t] cut to [n] code units plus `…`, never inside a surrogate pair.
String _clip(String t, int n) {
  if (t.length <= n) return t;
  var e = n;
  if (_isHigh(t.codeUnitAt(e - 1))) e--;
  return '${t.substring(0, e)}…';
}

class _U {
  _U(this.start, this.end, this.kind, this.path, [this.level = 0]);
  int start, end;
  String kind;
  List<String> path;
  int level;
}

/// Splits a markdown note into line/block level chunks. Chunk text is always
/// a substring of [body]; markdown markers are kept. Offsets are into [body].
///
/// Without [rules], notes longer than [largeNoteChars] pack adjacent lines.
List<LineChunk> chunkNote(
  String body, {
  String docTitle = '',
  int page = 1,
  ChunkRules? rules,
}) {
  rules ??= ChunkRules(packSmall: body.length > largeNoteChars);
  final units = <_U>[];
  final stack = <(int, String)>[]; // heading level, plain text
  final listStack = <(int, String)>[]; // indent, plain item text
  var titleSkipped = docTitle.isEmpty;

  List<String> currentPath([bool withList = true]) => [
    for (final (_, t) in stack) t,
    if (withList)
      for (final (_, t) in listStack) _clip(t, 40),
  ];

  _U? pending; // heading without content yet
  _U? acc; // multi-line unit being built (quote/table/list item)
  String? fenceCh;
  var fenceLen = 0;
  _U? code;

  void flushAcc() {
    if (acc != null) {
      units.add(acc!);
      acc = null;
    }
  }

  void content(_U u) {
    pending = null;
    units.add(u);
  }

  var pos = 0;
  while (pos <= body.length) {
    var nl = body.indexOf('\n', pos);
    if (nl < 0) nl = body.length;
    var e = nl;
    if (e > pos && body.codeUnitAt(e - 1) == 0x0d) e--;
    final line = body.substring(pos, e);
    final start = pos;
    pos = nl + 1;
    if (start >= body.length && line.isEmpty) break;

    // inside fenced code
    if (code != null) {
      final m = _fenceRe.firstMatch(line);
      code.end = e;
      if (m != null &&
          m.group(1)![0] == fenceCh &&
          m.group(1)!.length >= fenceLen &&
          line.trim() == m.group(1)) {
        content(code);
        code = null;
        fenceCh = null;
      }
      continue;
    }
    final fm = _fenceRe.firstMatch(line);
    if (fm != null) {
      flushAcc();
      fenceCh = fm.group(1)![0];
      fenceLen = fm.group(1)!.length;
      code = _U(
        start + (line.length - line.trimLeft().length),
        e,
        'code',
        currentPath(),
      );
      continue;
    }
    if (line.trim().isEmpty) {
      flushAcc();
      continue;
    }
    final hm = _headRe.firstMatch(line);
    if (hm != null) {
      flushAcc();
      final level = hm.group(1)!.length;
      final text = _plain(hm.group(2) ?? '');
      if (pending != null && level <= pending!.level) {
        // previous heading had no content and no child: keep it searchable
        units.add(pending!);
      }
      pending = null;
      while (stack.isNotEmpty && stack.last.$1 >= level) {
        stack.removeLast();
      }
      listStack.clear();
      final parents = currentPath(false);
      // a heading equal to the document title adds nothing to the path
      final tl = docTitle.toLowerCase(), hl = text.toLowerCase();
      final isTitle =
          !titleSkipped &&
          stack.isEmpty &&
          hl.isNotEmpty &&
          (tl.contains(hl) || hl.contains(tl));
      if (isTitle) titleSkipped = true;
      if (!isTitle && text.isNotEmpty) stack.add((level, text));
      final hs = start + (line.length - line.trimLeft().length);
      // an orphan heading is cited under its parents, not under itself
      pending = _U(hs, e, 'heading', parents, level);
      continue;
    }
    if (_hrRe.hasMatch(line)) {
      flushAcc();
      continue;
    }
    final ls = start + (line.length - line.trimLeft().length);
    if (_quoteRe.hasMatch(line)) {
      if (acc != null && acc!.kind == 'quote') {
        acc!.end = e;
      } else {
        flushAcc();
        acc = _U(ls, e, 'quote', currentPath());
        pending = null;
      }
      continue;
    }
    if (_tableRe.hasMatch(line)) {
      if (acc != null && acc!.kind == 'table') {
        acc!.end = e;
      } else {
        flushAcc();
        acc = _U(ls, e, 'table', currentPath());
        pending = null;
      }
      continue;
    }
    final lm = _listRe.firstMatch(line);
    if (lm != null) {
      flushAcc();
      final indent = lm.group(1)!.replaceAll('\t', '    ').length;
      while (listStack.isNotEmpty && listStack.last.$1 >= indent) {
        listStack.removeLast();
      }
      acc = _U(ls, e, 'list', currentPath());
      pending = null;
      listStack.add((indent, _plain(line.replaceFirst(_markers, ''))));
      continue;
    }
    // indented continuation of a list item
    if (acc != null && acc!.kind == 'list' && _continuationRe.hasMatch(line)) {
      acc!.end = e;
      continue;
    }
    flushAcc();
    listStack.clear();
    content(_U(ls, e, 'para', currentPath()));
  }
  if (code != null) content(code);
  flushAcc();
  if (pending != null) units.add(pending!);
  units.sort((a, b) => a.start.compareTo(b.start));

  // 0. trim outer whitespace; drop units with nothing visible (`- [ ]`, `>`)
  final trimmed = <_U>[];
  for (final u in units) {
    var a = u.start, b = u.end;
    while (a < b && _isWs(body.codeUnitAt(a))) {
      a++;
    }
    while (b > a && _isWs(body.codeUnitAt(b - 1))) {
      b--;
    }
    if (b == a) continue;
    u.start = a;
    u.end = b;
    if (u.kind != 'code' && _visible(body.substring(a, b)) == 0) continue;
    trimmed.add(u);
  }

  // Whole lines of [u] packed up to [max] chars (code fences, tables).
  void splitLines(_U u, int max, List<_U> into) {
    var a = u.start;
    var cur = u.start;
    var p = u.start;
    while (p < u.end) {
      var nl = body.indexOf('\n', p);
      if (nl < 0 || nl > u.end) nl = u.end;
      if (nl - a > max && p > a) {
        into.add(_U(a, cur, u.kind, u.path));
        a = p;
      }
      cur = nl;
      p = nl + 1;
    }
    into.add(_U(a, u.end, u.kind, u.path));
  }

  // 1. split oversize units
  final split = <_U>[];
  for (final u in trimmed) {
    final len = u.end - u.start;
    if (u.kind == 'code') {
      if (len <= rules.codeMaxChars) {
        split.add(u);
      } else {
        splitLines(u, rules.codeMaxChars, split);
      }
    } else if (len <= rules.maxChars) {
      split.add(u);
    } else if (u.kind == 'table') {
      splitLines(u, rules.maxChars, split);
    } else {
      for (final (a, b) in _pack(
        body,
        u.start,
        u.end,
        rules.maxChars,
        rules.targetChars,
      )) {
        split.add(_U(a, b, u.kind, u.path));
      }
    }
  }

  bool samePath(_U a, _U b) => a.path.join('\u0001') == b.path.join('\u0001');
  bool mergeable(_U u) => u.kind != 'code' && u.kind != 'table';

  // 2. merge fragments (fewer than minVisible visible chars)
  final merged = <_U>[];
  for (var i = 0; i < split.length; i++) {
    final u = split[i];
    final tiny =
        u.kind != 'code' &&
        _visible(body.substring(u.start, u.end)) < rules.minVisible;
    if (tiny) {
      final next = i + 1 < split.length ? split[i + 1] : null;
      if (next != null &&
          mergeable(next) &&
          samePath(next, u) &&
          next.end - u.start <= rules.maxChars) {
        split[i + 1] = _U(u.start, next.end, 'merged', u.path);
        continue;
      }
      if (merged.isNotEmpty) {
        final prev = merged.last;
        if (mergeable(prev) &&
            samePath(prev, u) &&
            u.end - prev.start <= rules.maxChars) {
          merged[merged.length - 1] = _U(
            prev.start,
            u.end,
            'merged',
            prev.path,
          );
          continue;
        }
      }
    }
    merged.add(u);
  }

  var finalUnits = merged;
  if (rules.packSmall) {
    final packed = <_U>[];
    for (final u in merged) {
      if (packed.isNotEmpty) {
        final p = packed.last;
        if (mergeable(p) &&
            mergeable(u) &&
            samePath(p, u) &&
            u.end - p.start <= rules.maxChars) {
          packed[packed.length - 1] = _U(p.start, u.end, 'packed', p.path);
          continue;
        }
      }
      packed.add(u);
    }
    finalUnits = packed;
  }

  final res = <LineChunk>[];
  for (final u in finalUnits) {
    var a = u.start, b = u.end;
    while (a < b && _isWs(body.codeUnitAt(a))) {
      a++;
    }
    while (b > a && _isWs(body.codeUnitAt(b - 1))) {
      b--;
    }
    if (b == a) continue;
    res.add(
      LineChunk(
        page,
        res.length,
        a,
        b,
        body.substring(a, b),
        u.path.join(' > '),
        u.kind,
      ),
    );
  }
  return res;
}

// ── PDF pages ───────────────────────────────────────────────────────────

final _bulletRe = RegExp(
  r'^\s*(?:[•·‣◦▪■□○●※▶▷◆◇★☆]|[-–—]\s|\d{1,2}[.)]\s|\(\d{1,2}\)\s)',
);

/// Splits one page of extracted text into sentence/paragraph chunks of at
/// most [ChunkRules.maxChars]. Hard line wraps are reflowed (newline ->
/// space) and whitespace runs collapse, so `text` equals the source slice up
/// to whitespace; `start`/`end` index the page text. Chunks never cross a
/// blank-line paragraph, except that a short heading-like paragraph
/// (< [ChunkRules.minPdfChars]) is carried into the next one.
List<LineChunk> chunkPdfPage(
  int page,
  String text, {
  ChunkRules rules = const ChunkRules(),
}) {
  // paragraphs of (start,end) line spans
  final paras = <List<(int, int)>>[];
  var cur = <(int, int)>[];
  var pos = 0;
  while (pos <= text.length) {
    var nl = text.indexOf('\n', pos);
    if (nl < 0) nl = text.length;
    var a = pos, b = nl;
    while (a < b && _isWs(text.codeUnitAt(a))) {
      a++;
    }
    while (b > a && _isWs(text.codeUnitAt(b - 1))) {
      b--;
    }
    pos = nl + 1;
    if (a == b) {
      if (cur.isNotEmpty) paras.add(cur);
      cur = [];
    } else {
      if (cur.isNotEmpty && _bulletRe.hasMatch(text.substring(a, b))) {
        paras.add(cur);
        cur = [];
      }
      cur.add((a, b));
    }
    if (nl >= text.length) break;
  }
  if (cur.isNotEmpty) paras.add(cur);

  final out = <(int, int, String)>[]; // srcStart, srcEnd, text
  (int, int, String)? carry;
  for (final lines in paras) {
    final buf = StringBuffer();
    final map = <int>[];
    for (final (a, b) in lines) {
      if (buf.isNotEmpty) {
        buf.write(' ');
        map.add(map.last + 1);
      }
      for (var k = a; k < b; k++) {
        buf.write(text[k]);
        map.add(k);
      }
    }
    final s = buf.toString();
    final spans = _pack(s, 0, s.length, rules.maxChars, rules.targetChars);
    for (var si = 0; si < spans.length; si++) {
      final (a, b) = spans[si];
      var c = (map[a], map[b - 1] + 1, s.substring(a, b));
      if (carry != null) {
        c = (carry.$1, c.$2, '${carry.$3} ${c.$3}');
        carry = null;
      }
      final last = si == spans.length - 1;
      if (last && c.$3.length < rules.minPdfChars && lines != paras.last) {
        carry = c; // heading-like tail: glue to the next paragraph
        continue;
      }
      out.add(c);
    }
  }
  if (carry != null) out.add(carry);

  // merge tiny tails into the previous chunk
  final fin = <(int, int, String)>[];
  for (final c in out) {
    if (fin.isNotEmpty &&
        c.$3.length < rules.minPdfChars &&
        fin.last.$3.length + 1 + c.$3.length <=
            rules.maxChars + rules.minPdfChars) {
      final p = fin.removeLast();
      fin.add((p.$1, c.$2, '${p.$3} ${c.$3}'));
    } else {
      fin.add(c);
    }
  }
  return [
    for (final (i, c) in fin.indexed)
      LineChunk(page, i, c.$1, c.$2, c.$3, '', 'pdf'),
  ];
}

/// The PDF sentence-pack target for a document whose pages hold [totalChars]
/// characters in all.
int pdfTargetFor(int totalChars) => totalChars > largePdfChars ? 300 : 120;

/// All pages of a PDF, chunk ordinals running across pages. The target grows
/// to 300 for documents over [largePdfChars] (fewer embedding calls).
List<LineChunk> chunkPdfPages(List<({int page, String text})> pages) {
  final total = pages.fold<int>(0, (a, p) => a + p.text.length);
  final rules = ChunkRules(targetChars: pdfTargetFor(total));
  final out = <LineChunk>[];
  for (final p in pages) {
    for (final c in chunkPdfPage(p.page, p.text, rules: rules)) {
      c.ordinal = out.length;
      out.add(c);
    }
  }
  return out;
}

// ── embedding input (the title slot carries the context path) ───────────

/// The `title:` slot of the embedding input: document title, then the heading
/// path. ` | ` becomes ` / ` (the Gemini provider splits the input on it).
/// Over [maxLen] the front is cut and the nearest headings are kept.
String embeddingTitle(
  String docTitle,
  String path, {
  int maxLen = embeddingTitleMax,
}) {
  String clean(String s) =>
      nfc(s).replaceAll(' | ', ' / ').replaceAll('\n', ' ');
  var t = path.isEmpty
      ? clean(docTitle)
      : '${clean(docTitle)} > ${clean(path)}';
  if (t.length > maxLen) {
    var from = t.length - (maxLen - 1);
    if (_isLow(t.codeUnitAt(from))) from++;
    t = '…${t.substring(from)}';
  }
  return t;
}
