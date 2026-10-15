import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

/// Live Markdown styling on top of a plain text field (research 017 §3).
///
/// The text is never changed: [liveMarkdownSpan] only splits it into styled
/// runs, and markers (`#`, `**`, `` ` ``, `>`, `-`) stay visible but muted. The
/// concatenation of all runs is always exactly the input, so saving stays a
/// 100% Markdown round trip and IME composing / selection offsets stay valid.
///
/// Scope: headings, bold, italic, strikethrough, inline code, quote, bullet /
/// numbered / checklist items, rules, links (inline and autolinks), fenced
/// code. Tables, images and HTML are plain text.

/// Styles are deltas merged onto the field's base style. All have defaults so
/// tests can use `const LiveStyles()`.
class LiveStyles {
  const LiveStyles({
    this.h1 = const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    this.h2 = const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    this.h3 = const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    this.h4 = const TextStyle(fontWeight: FontWeight.w600),
    this.marker = const TextStyle(color: Color(0x8C808080)),
    this.bold = const TextStyle(fontWeight: FontWeight.w700),
    this.italic = const TextStyle(fontStyle: FontStyle.italic),
    this.code = const TextStyle(fontFamily: 'monospace', fontSize: 14),
    this.quote = const TextStyle(color: Color(0xFF808080)),
    this.link = const TextStyle(
      color: Color(0xFF3366CC),
      decoration: TextDecoration.underline,
    ),
    this.checked = const TextStyle(
      color: Color(0xFF808080),
      decoration: TextDecoration.lineThrough,
    ),
    this.strike = const TextStyle(decoration: TextDecoration.lineThrough),
    this.bullet = const TextStyle(
      color: Color(0xFF3366CC),
      fontWeight: FontWeight.w700,
    ),
    this.number = const TextStyle(color: Color(0xFF3366CC)),
    this.todo = const TextStyle(
      color: Color(0xFF808080),
      fontWeight: FontWeight.w700,
    ),
    this.done = const TextStyle(
      color: Color(0xFF3366CC),
      fontWeight: FontWeight.w700,
    ),
    this.highlight = const Color(0x55FFCC00),
  });

  /// `h4` is used for `####` and deeper.
  final TextStyle h1, h2, h3, h4;
  final TextStyle marker, bold, italic, code, quote, link, checked;

  /// `~~x~~`, and the list prefix pieces: `-`/`*`/`+`, `1.`, `[ ]`, `[x]`.
  final TextStyle strike, bullet, number, todo, done;

  /// Background of the cited passage (opened from an answer).
  final Color highlight;

  List<Object> get _fields => [
    h1,
    h2,
    h3,
    h4,
    marker,
    bold,
    italic,
    code,
    quote,
    link,
    checked,
    strike,
    bullet,
    number,
    todo,
    done,
    highlight,
  ];

  @override
  bool operator ==(Object other) =>
      other is LiveStyles && _listEq(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);
}

bool _listEq(List<Object> a, List<Object> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A [TextEditingController] that paints [liveMarkdownSpan] while [live];
/// when not live it is the stock plain controller (source mode).
class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text, required this.styleOf});

  /// Resolves styles for the current theme / width. Called from
  /// [buildTextSpan], so changes of either rebuild the field.
  final LiveStyles Function(BuildContext context, TextStyle base) styleOf;

  bool _live = true;
  String? _quote;

  bool get live => _live;
  set live(bool v) {
    if (v == _live) return;
    _live = v;
    notifyListeners();
  }

  /// Passage to tint (highlight). Found again by text on every build, so it
  /// follows edits and simply disappears once the user changes it.
  String? get quote => _quote;
  set quote(String? v) {
    if (v == _quote) return;
    _quote = v;
    notifyListeners();
  }

  // ponytail: whole-text re-scan only when text/styles change; selection-only
  // changes reuse the parsed runs. Upgrade path: per-line cache if >50k chars.
  String? _cText;
  LiveStyles? _cStyles;
  List<LiveRun> _cRuns = const [];
  String? _hText, _hQuote;
  TextRange? _hRange;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final comp = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    TextRange? hl;
    if (_quote != null) {
      if (_hText != text || _hQuote != _quote) {
        _hText = text;
        _hQuote = _quote;
        _hRange = findQuote(text, _quote!);
      }
      hl = _hRange;
    }
    if (!_live && hl == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final base = style ?? const TextStyle();
    final styles = styleOf(context, base);
    List<LiveRun> runs;
    if (!_live) {
      runs = [LiveRun(0, text.length, const TextStyle())];
    } else if (_cText == text && _cStyles == styles) {
      runs = _cRuns;
    } else {
      runs = parseLiveRuns(text, styles);
      _cText = text;
      _cStyles = styles;
      _cRuns = runs;
    }
    return runsToSpan(
      text,
      runs,
      base,
      composing: comp,
      highlight: hl,
      highlightColor: styles.highlight,
    );
  }
}

/// One styled run `[start, end)`; [style] is a delta over the base style.
class LiveRun {
  const LiveRun(this.start, this.end, this.style);
  final int start, end;
  final TextStyle style;
}

/// Convenience used by tests and by [LiveMarkdownController].
TextSpan liveMarkdownSpan(
  String text,
  TextStyle base,
  LiveStyles styles, {
  TextRange? composing,
  TextRange? highlight,
}) => runsToSpan(
  text,
  parseLiveRuns(text, styles),
  base,
  composing: composing,
  highlight: highlight,
  highlightColor: styles.highlight,
);

/// Builds the span from [runs] and overlays IME underline and highlight.
/// Overlays may cut a run in two; the children's text always concatenates to
/// exactly [text].
TextSpan runsToSpan(
  String text,
  List<LiveRun> runs,
  TextStyle base, {
  TextRange? composing,
  TextRange? highlight,
  Color highlightColor = const Color(0x55FFCC00),
}) {
  var out = runs;
  if (highlight != null && highlight.isValid && !highlight.isCollapsed) {
    out = _overlay(out, highlight, TextStyle(backgroundColor: highlightColor));
  }
  if (composing != null && composing.isValid && !composing.isCollapsed) {
    // Same look as the stock implementation of TextEditingController.
    out = _overlay(
      out,
      composing,
      const TextStyle(decoration: TextDecoration.underline),
    );
  }
  return TextSpan(
    style: base,
    children: [
      for (final r in out)
        TextSpan(text: text.substring(r.start, r.end), style: r.style),
    ],
  );
}

List<LiveRun> _overlay(List<LiveRun> runs, TextRange r, TextStyle over) {
  final out = <LiveRun>[];
  for (final run in runs) {
    if (run.end <= r.start || run.start >= r.end) {
      out.add(run);
      continue;
    }
    final a = run.start > r.start ? run.start : r.start;
    final b = run.end < r.end ? run.end : r.end;
    if (run.start < a) out.add(LiveRun(run.start, a, run.style));
    out.add(LiveRun(a, b, run.style.merge(over)));
    if (b < run.end) out.add(LiveRun(b, run.end, run.style));
  }
  return out;
}

/// Finds a cited [quote] in [text]: exact, then whitespace-tolerant, then by
/// its first 8, then 5 words (the stored body may carry markers the quote lacks).
TextRange? findQuote(String text, String quote) {
  final q = quote.trim();
  if (q.isEmpty || text.isEmpty) return null;
  final i = text.indexOf(q);
  if (i >= 0) return TextRange(start: i, end: i + q.length);
  final words = q.split(RegExp(r'\s+'));
  for (final n in {words.length, 8, 5}.where((n) => n <= words.length)) {
    final re = RegExp(words.take(n).map(RegExp.escape).join(r'\s+'));
    final m = re.firstMatch(text);
    if (m != null) return TextRange(start: m.start, end: m.end);
  }
  return null;
}

// ── Parsing ──────────────────────────────────────────────────────────────

// Block patterns are used with `matchAsPrefix` (never `^`), on the whole text
// at a line start or on a single line, so one definition serves the live
// parser and the toggles. `$` only means end of input, hence the `\r\n`
// lookaheads.

/// ATX heading: 0-3 spaces, 1-6 `#`, then blank or end of line (CommonMark).
/// Group 2 is the hashes. The parser and [setHeading] share this one regex.
final _headRe = RegExp(r'( {0,3})(#{1,6})(?=[ \t\r\n]|$)[ \t]*');
final _quoteRe = RegExp(r'[ \t]{0,3}(?:>[ \t]?)+');

/// List prefix: 1 indent, 2 bullet char, 3 number + delimiter, 4 `[ ]`/`[x]`.
/// A bare marker at the end of the line is an (empty) item.
final _listRe = RegExp(
  r'([ \t]*)(?:([-*+])|(\d{1,9}[.)]))(?:[ \t]+|(?=[\r\n]|$))'
  r'(?:(\[[ xX]\])(?=[ \t\r\n]|$)[ \t]*)?',
);

/// Fenced code state machine (CommonMark): a fence is 3+ backticks or tildes
/// (backtick fences may not carry a backtick in the info string, so a one-line
/// ```` ```x``` ```` is inline code); it closes on a fence of the same
/// character, at least as long, followed by nothing; no closer = code to the
/// end of the document. Indentation is accepted at any depth (nested items).
class _Fence {
  int ch = 0, len = 0;

  /// Advances over line `[s, e)`: 0 normal line, 1 fence line, 2 code body.
  int step(String t, int s, int e) {
    var i = s;
    while (i < e && _ws(t.codeUnitAt(i))) {
      i++;
    }
    final c = i < e ? t.codeUnitAt(i) : 0;
    var j = i;
    if (c == 0x60 || c == 0x7e) {
      while (j < e && t.codeUnitAt(j) == c) {
        j++;
      }
    }
    final n = j - i;
    if (n >= 3) {
      if (ch == 0) {
        var ok = true;
        for (var k = j; c == 0x60 && k < e; k++) {
          if (t.codeUnitAt(k) == 0x60) ok = false;
        }
        if (ok) {
          ch = c;
          len = n;
          return 1;
        }
      } else if (c == ch && n >= len) {
        var k = j;
        while (k < e && (_ws(t.codeUnitAt(k)) || t.codeUnitAt(k) == 0x0d)) {
          k++;
        }
        if (k == e) {
          ch = 0;
          return 1;
        }
      }
    }
    return ch == 0 ? 0 : 2;
  }
}

/// True if the line containing [offset] is a fence line or inside a fenced
/// block (inline rules, links and list continuation are off there).
bool inCode(String text, int offset) {
  final f = _Fence();
  var i = 0;
  while (true) {
    final nl = text.indexOf('\n', i);
    final e = nl < 0 ? text.length : nl;
    final r = f.step(text, i, e);
    if (offset <= e || nl < 0) return r != 0;
    i = nl + 1;
  }
}

/// A link `[start, end)` in the text and its destination as written.
typedef LiveLink = ({int start, int end, String url});

/// Splits [text] into contiguous runs covering it completely (in order).
List<LiveRun> parseLiveRuns(String text, LiveStyles st) {
  final out = _Out(text.length);
  final fence = _Fence();
  var i = 0;
  while (true) {
    final nl = text.indexOf('\n', i);
    final e = nl < 0 ? text.length : nl;
    switch (fence.step(text, i, e)) {
      case 1:
        out.emit(e, st.marker.merge(st.code));
      case 2:
        out.emit(e, st.code);
      default:
        _block(text, i, e, st, out);
    }
    if (nl < 0) break;
    out.emit(nl + 1, const TextStyle()); // the newline itself stays plain
    i = nl + 1;
  }
  out.emit(text.length, const TextStyle());
  return out.runs;
}

/// The link containing the caret [offset] (strictly inside it), if any. Uses
/// the live parser on that one line, so it agrees with what is painted.
LiveLink? linkAt(String text, int offset) {
  if (offset < 0 || offset > text.length) return null;
  final s = offset > 0 ? text.lastIndexOf('\n', offset - 1) + 1 : 0;
  var e = text.indexOf('\n', offset);
  if (e < 0) e = text.length;
  if (inCode(text, s)) return null;
  final out = _Out(text.length)..links = [];
  _block(text, s, e, const LiveStyles(), out);
  for (final l in out.links!) {
    if (l.start < offset && offset < l.end) return l;
  }
  return null;
}

/// Only http(s) with a host and mailto may be opened; anything else
/// (`javascript:`, `data:`, `file:`, relative paths, whitespace/control chars)
/// is refused. The text is never changed: this only gates the "open" chip.
Uri? safeLinkUri(String raw) {
  final s = raw.trim();
  if (s.isEmpty || RegExp(r'[\x00-\x20\x7f]').hasMatch(s)) return null;
  final u = Uri.tryParse(s);
  if (u == null) return null;
  switch (u.scheme) {
    case 'http' || 'https':
      return u.host.isNotEmpty ? u : null;
    case 'mailto':
      return u.path.isNotEmpty ? u : null;
  }
  return null;
}

/// `---`, `***`, `___` (3+, spaces allowed) alone on the line `[s, e)`.
bool _isRule(String t, int s, int e) {
  var i = s;
  while (i < e && _ws(t.codeUnitAt(i))) {
    i++;
  }
  if (i >= e) return false;
  final c = t.codeUnitAt(i);
  if (c != 0x2d && c != 0x2a && c != 0x5f) return false;
  var n = 0;
  for (; i < e; i++) {
    final u = t.codeUnitAt(i);
    if (u == c) {
      n++;
    } else if (!_ws(u) && u != 0x0d) {
      return false;
    }
  }
  return n >= 3;
}

void _block(String t, int s, int e, LiveStyles st, _Out out) {
  var cur = const TextStyle();
  var pos = s;
  final h = _headRe.matchAsPrefix(t, s);
  if (h != null) {
    final level = h.group(2)!.length;
    cur = switch (level) {
      1 => st.h1,
      2 => st.h2,
      3 => st.h3,
      _ => st.h4,
    };
    out.emit(h.end, st.marker.merge(cur));
    _inline(t, h.end, e, cur, st, out, 0);
    return;
  }
  final q = _quoteRe.matchAsPrefix(t, s);
  if (q != null) {
    out.emit(q.end, st.marker);
    pos = q.end;
    cur = st.quote;
  }
  if (_isRule(t, pos, e)) {
    out.emit(e, st.marker);
    return;
  }
  final l = _listRe.matchAsPrefix(t, pos);
  if (l != null && l.end <= e) {
    // Prefix pieces, text unchanged: indent stays as typed, the marker gets
    // the accent, the box its state colour.
    final all = l.group(0)!, box = l.group(4), at = l.end - all.length;
    out.emit(at + l.group(1)!.length, cur);
    out.emit(
      box == null ? l.end : at + all.indexOf('['),
      l.group(2) != null ? st.bullet : st.number,
    );
    if (box != null) {
      final done = box[1] != ' ';
      out.emit(l.end, done ? st.done : st.todo);
      if (done) cur = cur.merge(st.checked);
    }
    pos = l.end;
  }
  _inline(t, pos, e, cur, st, out, 0);
}

bool _ws(int c) => c == 0x20 || c == 0x09;
bool _alnum(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a) ||
    c > 0x7f;

/// Closing marker for `*`/`_` (single or double) in `(from, to)`, or -1.
int _closer(String t, int c, bool dbl, int from, int to) {
  var k = from;
  while (k < to) {
    final u = t.codeUnitAt(k);
    if (u == 0x5c) {
      k += 2;
    } else if (u == 0x60) {
      final j = t.indexOf('`', k + 1);
      k = (j < 0 || j >= to) ? k + 1 : j + 1;
    } else if (u == c) {
      final next = k + 1 < to && t.codeUnitAt(k + 1) == c;
      if (dbl) {
        if (next) {
          var j = k;
          while (j + 2 < to && t.codeUnitAt(j + 2) == c) {
            j++;
          }
          if (j > from && !_ws(t.codeUnitAt(j - 1))) return j;
          k = j + 2;
        } else {
          k++;
        }
      } else if (next) {
        k += 2;
      } else if (!_ws(t.codeUnitAt(k - 1)) &&
          (c != 0x5f || k + 1 >= to || !_alnum(t.codeUnitAt(k + 1)))) {
        return k;
      } else {
        k++;
      }
    } else {
      k++;
    }
  }
  return -1;
}

/// Closing `~~` in `(from, to)`, or -1.
int _strikeCloser(String t, int from, int to) {
  var k = from;
  while (k + 1 < to) {
    final u = t.codeUnitAt(k);
    if (u == 0x5c) {
      k += 2;
    } else if (u == 0x60) {
      final j = t.indexOf('`', k + 1);
      k = (j < 0 || j >= to) ? k + 1 : j + 1;
    } else if (u == 0x7e &&
        t.codeUnitAt(k + 1) == 0x7e &&
        k > from &&
        !_ws(t.codeUnitAt(k - 1))) {
      return k;
    } else {
      k++;
    }
  }
  return -1;
}

/// The `)` closing a link destination that starts at [from]; parentheses may
/// nest (`https://a.com/x_(y)`), `\)` is escaped. -1 if not closed before [to].
int _parenEnd(String t, int from, int to) {
  var depth = 1, k = from;
  while (k < to) {
    final u = t.codeUnitAt(k);
    if (u == 0x5c) {
      k += 2;
      continue;
    }
    if (u == 0x28) depth++;
    if (u == 0x29 && --depth == 0) return k;
    k++;
  }
  return -1;
}

/// Destination part of `(dest "title")`.
String _dest(String raw) {
  final s = raw.trimLeft();
  if (s.startsWith('<')) {
    final g = s.indexOf('>');
    if (g > 0) return s.substring(1, g);
  }
  final w = s.indexOf(RegExp(r'\s'));
  return w < 0 ? s : s.substring(0, w);
}

final _angleRe = RegExp(r'<(https?://[^\s<>]+)>', caseSensitive: false);
final _bareRe = RegExp(r'https?://[^\s<>]+', caseSensitive: false);

/// Drops trailing sentence punctuation (and an unbalanced `)`) from a bare URL
/// spanning `[s, e)`.
int _trimUrl(String t, int s, int e) {
  while (e > s) {
    final u = t.codeUnitAt(e - 1);
    if (u == 0x29) {
      var open = 0, close = 0;
      for (var k = s; k < e; k++) {
        final x = t.codeUnitAt(k);
        if (x == 0x28) open++;
        if (x == 0x29) close++;
      }
      if (close <= open) break;
    } else if (!'.,;:!?\'"*_~]}'.codeUnits.contains(u)) {
      break;
    }
    e--;
  }
  return e;
}

void _inline(
  String t,
  int from,
  int to,
  TextStyle cur,
  LiveStyles st,
  _Out out,
  int depth,
) {
  // ponytail: very long lines / deep nesting stay plain (O(n) guard).
  if (to - from > 3000 || depth > 3) {
    out.emit(to, cur);
    return;
  }
  var i = from;
  while (i < to) {
    final c = t.codeUnitAt(i);
    if (c == 0x5c) {
      i += 2; // backslash escape: next char stays plain
      continue;
    }
    if (c == 0x60) {
      // A run of n backticks closes at the next run of exactly n; without
      // one the run is literal text.
      var n = 1;
      while (i + n < to && t.codeUnitAt(i + n) == 0x60) {
        n++;
      }
      var close = -1;
      var k = i + n;
      while (k < to && close < 0) {
        if (t.codeUnitAt(k) != 0x60) {
          k++;
          continue;
        }
        var m = 1;
        while (k + m < to && t.codeUnitAt(k + m) == 0x60) {
          m++;
        }
        if (m == n) close = k;
        k += m;
      }
      if (close > 0) {
        out.emit(i, cur);
        out.emit(i + n, st.marker);
        out.emit(close, cur.merge(st.code));
        out.emit(close + n, st.marker);
      }
      i = close > 0 ? close + n : i + n;
      continue;
    } else if ((c == 0x2a || c == 0x5f) &&
        !(c == 0x5f && i > from && _alnum(t.codeUnitAt(i - 1)))) {
      final dbl = i + 1 < to && t.codeUnitAt(i + 1) == c;
      final n = dbl ? 2 : 1;
      if (i + n < to && !_ws(t.codeUnitAt(i + n))) {
        final j = _closer(t, c, dbl, i + n, to);
        if (j > i + n) {
          out.emit(i, cur);
          out.emit(i + n, st.marker);
          _inline(
            t,
            i + n,
            j,
            cur.merge(dbl ? st.bold : st.italic),
            st,
            out,
            depth + 1,
          );
          out.emit(j + n, st.marker);
          i = j + n;
          continue;
        }
      }
      if (dbl) {
        i += 2; // unclosed `**`: do not retry on its second char
        continue;
      }
    } else if (c == 0x7e &&
        i + 2 < to &&
        t.codeUnitAt(i + 1) == 0x7e &&
        !_ws(t.codeUnitAt(i + 2))) {
      final j = _strikeCloser(t, i + 2, to);
      if (j > i + 2) {
        out.emit(i, cur);
        out.emit(i + 2, st.marker);
        final d = cur.decoration;
        var inner = cur.merge(st.strike);
        if (d != null && d != TextDecoration.none) {
          // keep a link's underline next to the strike
          inner = inner.copyWith(
            decoration: TextDecoration.combine([d, TextDecoration.lineThrough]),
          );
        }
        _inline(t, i + 2, j, inner, st, out, depth + 1);
        out.emit(j + 2, st.marker);
        i = j + 2;
        continue;
      }
      i += 2;
      continue;
    } else if (c == 0x5b && (i == from || t.codeUnitAt(i - 1) != 0x21)) {
      final j = t.indexOf(']', i + 1);
      if (j > i + 1 && j + 1 < to && t.codeUnitAt(j + 1) == 0x28) {
        final k = _parenEnd(t, j + 2, to);
        if (k > 0) {
          out.links?.add((
            start: i,
            end: k + 1,
            url: _dest(t.substring(j + 2, k)),
          ));
          out.emit(i, cur);
          out.emit(i + 1, st.marker);
          _inline(t, i + 1, j, cur.merge(st.link), st, out, depth + 1);
          out.emit(k + 1, st.marker);
          i = k + 1;
          continue;
        }
      }
    } else if (c == 0x3c) {
      final m = _angleRe.matchAsPrefix(t, i);
      if (m != null && m.end <= to) {
        out.links?.add((start: i, end: m.end, url: m.group(1)!));
        out.emit(i, cur);
        out.emit(i + 1, st.marker);
        out.emit(m.end - 1, cur.merge(st.link));
        out.emit(m.end, st.marker);
        i = m.end;
        continue;
      }
    } else if ((c | 0x20) == 0x68 &&
        i + 7 < to &&
        (t.codeUnitAt(i + 1) | 0x20) == 0x74 &&
        (i == from || !_asciiAlnum(t.codeUnitAt(i - 1)))) {
      final m = _bareRe.matchAsPrefix(t, i);
      if (m != null) {
        final scheme = t.codeUnitAt(i + 4) == 0x3a
            ? 7
            : 8; // http:// | https://
        final end = _trimUrl(t, i, m.end > to ? to : m.end);
        if (end > i + scheme) {
          out.links?.add((start: i, end: end, url: t.substring(i, end)));
          out.emit(i, cur);
          out.emit(end, cur.merge(st.link));
          i = end;
          continue;
        }
      }
    }
    i++;
  }
  out.emit(to, cur);
}

bool _asciiAlnum(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a);

/// Emits contiguous runs; [emit] covers `[pos, end)`, so gaps are impossible.
class _Out {
  _Out(this.length);
  final int length;
  final runs = <LiveRun>[];
  int pos = 0;

  /// Collects links when set (see [linkAt]); null while painting.
  List<LiveLink>? links;

  void emit(int end, TextStyle style) {
    if (end > length) end = length;
    if (end <= pos) return;
    if (runs.isNotEmpty && runs.last.style == style) {
      runs[runs.length - 1] = LiveRun(runs.last.start, end, style);
    } else {
      runs.add(LiveRun(pos, end, style));
    }
    pos = end;
  }
}

// ── List continuation (Enter) ────────────────────────────────────────────

bool _composing(TextEditingValue v) =>
    v.composing.isValid && !v.composing.isCollapsed;

final _contRe = RegExp(
  r'([ \t]*)(?:([-*+])|(\d{1,9})([.)]))[ \t]+(?:(\[[ xX]\])(?:[ \t]+|$))?',
);

/// Enter after `- `, `* `, `+ `, `1. `, `- [ ] ` or `> ` starts the next item
/// with the same prefix (number + 1, a fresh unchecked box, same indent and
/// quote); Enter on an empty item removes the prefix and ends the list.
///
/// Called with the value before and after an edit. Anything but "a single
/// `\n` typed at a collapsed caret" is returned untouched, so this never
/// interferes with IME composing (old or new value composing), replacing a
/// selection, paste, deletion, or code fences.
TextEditingValue continueList(TextEditingValue old, TextEditingValue neu) {
  final os = old.selection, ns = neu.selection;
  if (!os.isValid || !os.isCollapsed || !ns.isValid || !ns.isCollapsed) {
    return neu;
  }
  if (_composing(old) || _composing(neu)) return neu;
  final ot = old.text, p = os.baseOffset;
  if (p < 0 ||
      p > ot.length ||
      ns.baseOffset != p + 1 ||
      neu.text.length != ot.length + 1 ||
      neu.text.codeUnitAt(p) != 0x0a ||
      neu.text != ot.replaceRange(p, p, '\n')) {
    return neu;
  }
  final ls = p > 0 ? ot.lastIndexOf('\n', p - 1) + 1 : 0;
  var le = ot.indexOf('\n', p);
  if (le < 0) le = ot.length;
  if (inCode(ot, ls) || _isRule(ot, ls, le)) return neu;
  final line = ot.substring(ls, le);
  final q = _quoteRe.matchAsPrefix(line)?.group(0) ?? '';
  final m = _contRe.matchAsPrefix(line, q.length);
  final pre = m?.end ?? q.length;
  if (pre == 0 || p - ls < pre) return neu; // plain line / caret in the prefix
  if (p == le && line.substring(pre).trim().isEmpty) {
    // empty item: drop the prefix, no new line
    return TextEditingValue(
      text: ot.replaceRange(ls, le, ''),
      selection: TextSelection.collapsed(offset: ls),
    );
  }
  var next = q;
  if (m != null) {
    final marker = m.group(2) ?? '${int.parse(m.group(3)!) + 1}${m.group(4)}';
    next = '$q${m.group(1)}$marker ${m.group(5) != null ? '[ ] ' : ''}';
  }
  return TextEditingValue(
    text: neu.text.replaceRange(p + 1, p + 1, next),
    selection: TextSelection.collapsed(offset: p + 1 + next.length),
  );
}

/// [continueList] as an input formatter for the note body field.
class ListContinuationFormatter extends TextInputFormatter {
  const ListContinuationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => continueList(oldValue, newValue);
}

// ── Formatting toggles (pure: value in, value out) ───────────────────────

TextSelection _sel(TextEditingValue v) => v.selection.isValid
    ? v.selection
    : TextSelection.collapsed(offset: v.text.length);

TextEditingValue _value(String text, int base, int extent) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: base, extentOffset: extent),
);

final _quoteLineRe = RegExp(r'(?:>[ \t]?)*');
final _listLineRe = RegExp(
  r'([ \t]*)(?:([-*+])|\d{1,9}[.)])[ \t]+(\[[ xX]\][ \t]+)?',
);

/// Heading level of the line(s) the selection touches, using the same lines
/// and the same rule as [setHeading]: 1-6 when every non-blank line has that
/// level, 0 when all are body text, -1 when they differ (mixed).
int headingLevel(TextEditingValue v) {
  final (a, b) = _lineBlock(v.text, _sel(v));
  final lines = v.text.substring(a, b).split('\n');
  int? level;
  for (final l in lines) {
    if (lines.length > 1 && l.trim().isEmpty) continue;
    final lv = _headLevel(_splitQuote(l).$2);
    if (level != null && level != lv) return -1;
    level = lv;
  }
  return level ?? 0;
}

(String, String) _splitQuote(String line) {
  final q = _quoteLineRe.matchAsPrefix(line)!.group(0)!;
  return (q, line.substring(q.length));
}

/// `level` 1-6 sets `#`..`######`; 0 makes the line(s) body text. Apply rule
/// (the only place it is defined): if every non-blank selected line already
/// has exactly `level`, it is removed from all of them (pressing the same
/// level again clears it); otherwise `level` is set on all of them
/// (replacing other levels, including a mixed selection). A leading `> `
/// quote prefix is kept; list items are not converted.
TextEditingValue setHeading(TextEditingValue v, int level) => _lines(
  v,
  has: (l) => level > 0 && _headLevel(l) == level,
  add: (l) {
    final rest = _stripHead(l);
    return level == 0 ? rest : '${'#' * level} $rest';
  },
  remove: _stripHead,
  restOnly: true,
);

int _headLevel(String l) => _headRe.matchAsPrefix(l)?.group(2)!.length ?? 0;
String _stripHead(String l) {
  final m = _headRe.matchAsPrefix(l);
  return m == null ? l : l.substring(m.end);
}

TextEditingValue toggleQuote(TextEditingValue v) => _lines(
  v,
  has: (l) => l.startsWith('>'),
  add: (l) => '> $l',
  remove: (l) => l.replaceFirst(RegExp(r'^>[ \t]?'), ''),
);

/// `- ` list; converts numbered / checklist lines instead of stacking.
TextEditingValue toggleBullet(TextEditingValue v) => _lines(
  v,
  has: (l) {
    final m = _listLineRe.matchAsPrefix(l);
    return m != null && m.group(2) != null && m.group(3) == null;
  },
  add: (l) => _relist(l, '- '),
  remove: (l) => _relist(l, ''),
  restOnly: true,
);

/// `1. ` numbered list (1., 2., ... per selected line); converts bullets.
TextEditingValue toggleOrdered(TextEditingValue v) {
  var n = 0;
  return _lines(
    v,
    has: (l) {
      final m = _listLineRe.matchAsPrefix(l);
      return m != null && m.group(2) == null && m.group(3) == null;
    },
    add: (l) => _relist(l, '${++n}. '),
    remove: (l) => _relist(l, ''),
    restOnly: true,
  );
}

/// `- [ ] ` checklist; converts bullet lines.
TextEditingValue toggleCheck(TextEditingValue v) => _lines(
  v,
  has: (l) => _listLineRe.matchAsPrefix(l)?.group(3) != null,
  add: (l) => _relist(l, '- [ ] '),
  remove: (l) => _relist(l, ''),
  restOnly: true,
);

String _relist(String l, String marker) {
  final m = _listLineRe.matchAsPrefix(l);
  if (m != null) return '${m.group(1)}$marker${l.substring(m.end)}';
  final indent = RegExp(r'^[ \t]*').firstMatch(l)!.group(0)!;
  return '$indent$marker${l.substring(indent.length)}';
}

/// `[start, end)` of the whole lines touched by [sel] (a selection that ends
/// right after a `\n` does not touch the next line).
(int, int) _lineBlock(String text, TextSelection sel) {
  final s = sel.start;
  var eAnchor = sel.end;
  if (sel.end > sel.start && text.codeUnitAt(sel.end - 1) == 0x0a) eAnchor--;
  final blockStart = s > 0 ? text.lastIndexOf('\n', s - 1) + 1 : 0;
  var blockEnd = eAnchor < blockStart
      ? blockStart
      : text.indexOf('\n', eAnchor);
  if (blockEnd < 0) blockEnd = text.length;
  if (blockEnd < blockStart) blockEnd = blockStart;
  return (blockStart, blockEnd);
}

/// Applies a line-prefix toggle to every line touched by the selection:
/// if all (non-blank) lines [has] it, [remove] from all, else [add] to all.
/// [restOnly] runs the ops after a leading `> ` quote prefix.
TextEditingValue _lines(
  TextEditingValue v, {
  required bool Function(String line) has,
  required String Function(String line) add,
  required String Function(String line) remove,
  bool restOnly = false,
}) {
  final text = v.text;
  final sel = _sel(v);
  final (blockStart, blockEnd) = _lineBlock(text, sel);
  final old = text.substring(blockStart, blockEnd).split('\n');
  final multi = old.length > 1;
  bool target(String l) => !multi || l.trim().isNotEmpty;
  String rest(String l) => restOnly ? _splitQuote(l).$2 : l;
  final targets = old.where(target).toList();
  final all = targets.isNotEmpty && targets.every((l) => has(rest(l)));
  String apply(String l) {
    if (!target(l)) return l;
    final (q, r) = restOnly ? _splitQuote(l) : ('', l);
    return q + (all ? remove(r) : add(r));
  }

  final fresh = old.map(apply).toList();
  // Only prefixes change, so the common suffix is the untouched content.
  final pOld = <int>[], pNew = <int>[];
  for (var i = 0; i < old.length; i++) {
    final a = old[i], b = fresh[i];
    var k = 0;
    final max = a.length < b.length ? a.length : b.length;
    while (k < max &&
        a.codeUnitAt(a.length - 1 - k) == b.codeUnitAt(b.length - 1 - k)) {
      k++;
    }
    pOld.add(a.length - k);
    pNew.add(b.length - k);
  }
  int map(int o) {
    if (o <= blockStart) return o;
    var oldStart = blockStart, newStart = blockStart;
    for (var i = 0; i < old.length; i++) {
      if (o <= oldStart + old[i].length) {
        final p = o - oldStart;
        final np = p >= pOld[i]
            ? p - pOld[i] + pNew[i]
            : (p < pNew[i] ? p : pNew[i]);
        return newStart + np;
      }
      oldStart += old[i].length + 1;
      newStart += fresh[i].length + 1;
    }
    return o + (newStart - oldStart);
  }

  return _value(
    text.replaceRange(blockStart, blockEnd, fresh.join('\n')),
    map(sel.baseOffset < 0 ? sel.start : sel.baseOffset),
    map(sel.extentOffset < 0 ? sel.end : sel.extentOffset),
  );
}

/// Toggles an inline [marker] (`**`, `_`, `~~`, `` ` ``) around the selection.
/// Already wrapped (selection includes the markers, or sits inside a pair on
/// the line) removes them; no selection inserts a pair with the caret inside.
/// Inline spans are single-line: for code over several lines use [toggleCode].
TextEditingValue toggleInline(TextEditingValue v, String marker) {
  final text = v.text;
  final sel = _sel(v);
  final s = sel.start, e = sel.end, n = marker.length;
  // 1) selection itself includes the markers
  if (e - s >= 2 * n &&
      text.startsWith(marker, s) &&
      text.startsWith(marker, e - n)) {
    final inner = text.substring(s + n, e - n);
    return _value(text.replaceRange(s, e, inner), s, s + inner.length);
  }
  // 2) inside a marker pair on the same line
  if (!text.substring(s, e).contains('\n')) {
    final ls = s > 0 ? text.lastIndexOf('\n', s - 1) + 1 : 0;
    var le = text.indexOf('\n', e);
    if (le < 0) le = text.length;
    final at = <int>[];
    for (
      var k = text.indexOf(marker, ls);
      k >= 0 && k + n <= le;
      k = text.indexOf(marker, k + n)
    ) {
      at.add(k);
    }
    for (var p = 0; p + 1 < at.length; p += 2) {
      final a = at[p], b = at[p + 1];
      if (a + n <= s && e <= b) {
        final out = text.replaceRange(b, b + n, '').replaceRange(a, a + n, '');
        return _value(out, s - n, e - n);
      }
    }
  }
  // 3) wrap / insert pair
  final sel0 = text.substring(s, e);
  final out = text.replaceRange(s, e, '$marker$sel0$marker');
  return _value(out, s + n, e + n);
}

/// Code button. One line: inline `` `x` `` ([toggleInline]). Several lines:
/// the whole lines go into a fenced block (the live parser reads inline code
/// per line, so a backtick pair around a line break would never be styled);
/// a selection that already is a fenced block gets unwrapped.
TextEditingValue toggleCode(TextEditingValue v) {
  final text = v.text;
  final sel = _sel(v);
  var e = sel.end;
  if (e > sel.start && text.codeUnitAt(e - 1) == 0x0a) e--;
  if (!text.substring(sel.start, e).contains('\n')) {
    return toggleInline(_value(text, sel.start, e), '`');
  }
  final chunk = text.substring(sel.start, e);
  if (chunk.length >= 2 &&
      chunk.startsWith('`') &&
      chunk.endsWith('`') &&
      !chunk.startsWith('```')) {
    // an old `a⏎b` pair: just take the backticks off
    return toggleInline(_value(text, sel.start, e), '`');
  }
  final (a, b) = _lineBlock(text, sel);
  final lines = text.substring(a, b).split('\n');
  final f = _Fence();
  if (lines.length >= 2 &&
      f.step(lines.first, 0, lines.first.length) == 1 &&
      f.step(lines.last, 0, lines.last.length) == 1 &&
      f.ch == 0) {
    final inner = lines.sublist(1, lines.length - 1).join('\n');
    return _value(text.replaceRange(a, b, inner), a, a + inner.length);
  }
  final body = lines.join('\n');
  var fence = '```';
  while (body.contains(fence)) {
    fence += '`';
  }
  final start = a + fence.length + 1;
  return _value(
    text.replaceRange(a, b, '$fence\n$body\n$fence'),
    start,
    start + body.length,
  );
}

/// `[text](url)`: wraps the selection (caret lands in the parens); on an
/// existing link it removes the link syntax and keeps the text; inside a bare
/// or `<url>` autolink it turns that URL into `[url](url)`. Links are found by
/// the live parser itself (same line, same rules), so URL parentheses agree.
TextEditingValue toggleLink(TextEditingValue v) {
  final text = v.text;
  final sel = _sel(v);
  final s = sel.start, e = sel.end;
  final ls = s > 0 ? text.lastIndexOf('\n', s - 1) + 1 : 0;
  var le = text.indexOf('\n', e);
  if (le < 0) le = text.length;
  if (!text.substring(s, e).contains('\n') && !inCode(text, ls)) {
    final out = _Out(text.length)..links = [];
    _block(text, ls, le, const LiveStyles(), out);
    for (final l in out.links!) {
      if (l.start > s || e > l.end) continue;
      if (text.codeUnitAt(l.start) == 0x5b) {
        final label = text.substring(
          l.start + 1,
          text.indexOf(']', l.start + 1),
        );
        return _value(
          text.replaceRange(l.start, l.end, label),
          l.start,
          l.start + label.length,
        );
      }
      final md = '[${l.url}](${l.url})';
      return _value(
        text.replaceRange(l.start, l.end, md),
        l.start + 1,
        l.start + 1 + l.url.length,
      );
    }
  }
  final label = text.substring(s, e);
  final out = text.replaceRange(s, e, '[$label]()');
  final caret = label.isEmpty ? s + 1 : s + label.length + 3;
  return _value(out, caret, caret);
}
