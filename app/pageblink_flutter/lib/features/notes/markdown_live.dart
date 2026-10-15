import 'package:flutter/material.dart';

/// Live Markdown styling on top of a plain text field (research 017 §3).
///
/// The text is never changed: [liveMarkdownSpan] only splits it into styled
/// runs, and markers (`#`, `**`, `` ` ``, `>`, `-`) stay visible but muted. The
/// concatenation of all runs is always exactly the input, so saving stays a
/// 100% Markdown round trip and IME composing / selection offsets stay valid.
///
/// Scope: headings, bold, italic, inline code, quote, list, checklist, links,
/// fenced code. Tables, images, HTML and nested lists are plain text.

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
    this.highlight = const Color(0x55FFCC00),
  });

  /// `h4` is used for `####` and deeper.
  final TextStyle h1, h2, h3, h4;
  final TextStyle marker, bold, italic, code, quote, link, checked;

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

final _fenceRe = RegExp(r'[ \t]{0,3}(```|~~~)');
final _headRe = RegExp(r'[ \t]{0,3}(#{1,6})[ \t]+');
final _quoteRe = RegExp(r'[ \t]{0,3}(?:>[ \t]?)+');
final _listRe = RegExp(r'[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+(\[[ xX]\][ \t]+)?');

/// Splits [text] into contiguous runs covering it completely (in order).
List<LiveRun> parseLiveRuns(String text, LiveStyles st) {
  final out = _Out(text.length);
  var inFence = false;
  var i = 0;
  while (true) {
    final nl = text.indexOf('\n', i);
    final e = nl < 0 ? text.length : nl;
    final fence = _fenceRe.matchAsPrefix(text, i);
    if (fence != null) {
      inFence = !inFence;
      out.emit(e, st.marker.merge(st.code));
    } else if (inFence) {
      out.emit(e, st.code);
    } else {
      _block(text, i, e, st, out);
    }
    if (nl < 0) break;
    out.emit(nl + 1, const TextStyle()); // the newline itself stays plain
    i = nl + 1;
  }
  out.emit(text.length, const TextStyle());
  return out.runs;
}

void _block(String t, int s, int e, LiveStyles st, _Out out) {
  var cur = const TextStyle();
  var pos = s;
  final h = _headRe.matchAsPrefix(t, s);
  if (h != null) {
    final level = h.group(1)!.length;
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
  final l = _listRe.matchAsPrefix(t, pos);
  if (l != null) {
    out.emit(l.end, st.marker);
    pos = l.end;
    final box = l.group(1);
    if (box != null && box[1] != ' ') cur = cur.merge(st.checked);
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
      final j = t.indexOf('`', i + 1);
      if (j > i + 1 && j < to) {
        out.emit(i, cur);
        out.emit(i + 1, st.marker);
        out.emit(j, cur.merge(st.code));
        out.emit(j + 1, st.marker);
        i = j + 1;
        continue;
      }
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
    } else if (c == 0x5b && (i == from || t.codeUnitAt(i - 1) != 0x21)) {
      final j = t.indexOf(']', i + 1);
      if (j > i + 1 && j + 1 < to && t.codeUnitAt(j + 1) == 0x28) {
        final k = t.indexOf(')', j + 2);
        if (k > 0 && k < to) {
          out.emit(i, cur);
          out.emit(i + 1, st.marker);
          _inline(t, i + 1, j, cur.merge(st.link), st, out, depth + 1);
          out.emit(k + 1, st.marker);
          i = k + 1;
          continue;
        }
      }
    }
    i++;
  }
  out.emit(to, cur);
}

/// Emits contiguous runs; [emit] covers `[pos, end)`, so gaps are impossible.
class _Out {
  _Out(this.length);
  final int length;
  final runs = <LiveRun>[];
  int pos = 0;

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

// ── Formatting toggles (pure: value in, value out) ───────────────────────

TextSelection _sel(TextEditingValue v) => v.selection.isValid
    ? v.selection
    : TextSelection.collapsed(offset: v.text.length);

TextEditingValue _value(String text, int base, int extent) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: base, extentOffset: extent),
);

final _headLineRe = RegExp(r'^(#{1,6})[ \t]+');
final _quoteLineRe = RegExp(r'^(?:>[ \t]?)*');
final _listLineRe = RegExp(
  r'^([ \t]*)(?:([-*+])|\d{1,9}[.)])[ \t]+(\[[ xX]\][ \t]+)?',
);

/// Heading level (1-6) of the line at the selection start, 0 if none.
int headingLevel(TextEditingValue v) {
  final s = _sel(v).start;
  final from = s > 0 ? v.text.lastIndexOf('\n', s - 1) + 1 : 0;
  var to = v.text.indexOf('\n', s);
  if (to < 0) to = v.text.length;
  final rest = _splitQuote(v.text.substring(from, to)).$2;
  return _headLineRe.firstMatch(rest)?.group(1)!.length ?? 0;
}

(String, String) _splitQuote(String line) {
  final q = _quoteLineRe.firstMatch(line)!.group(0)!;
  return (q, line.substring(q.length));
}

/// `level` 1-3 sets `#`..`###`; pressing the same level again, or 0, makes
/// the line(s) body text. Other levels are replaced.
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

int _headLevel(String l) => _headLineRe.firstMatch(l)?.group(1)!.length ?? 0;
String _stripHead(String l) => l.replaceFirst(_headLineRe, '');

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
    final m = _listLineRe.firstMatch(l);
    return m != null && m.group(2) != null && m.group(3) == null;
  },
  add: (l) => _relist(l, '- '),
  remove: (l) => _relist(l, ''),
  restOnly: true,
);

/// `- [ ] ` checklist; converts bullet lines.
TextEditingValue toggleCheck(TextEditingValue v) => _lines(
  v,
  has: (l) => _listLineRe.firstMatch(l)?.group(3) != null,
  add: (l) => _relist(l, '- [ ] '),
  remove: (l) => _relist(l, ''),
  restOnly: true,
);

String _relist(String l, String marker) {
  final m = _listLineRe.firstMatch(l);
  if (m != null) return '${m.group(1)}$marker${l.substring(m.end)}';
  final indent = RegExp(r'^[ \t]*').firstMatch(l)!.group(0)!;
  return '$indent$marker${l.substring(indent.length)}';
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
  final s = sel.start;
  var eAnchor = sel.end;
  if (sel.end > sel.start && text.codeUnitAt(sel.end - 1) == 0x0a) eAnchor--;
  final blockStart = s > 0 ? text.lastIndexOf('\n', s - 1) + 1 : 0;
  var blockEnd = eAnchor < blockStart
      ? blockStart
      : text.indexOf('\n', eAnchor);
  if (blockEnd < 0) blockEnd = text.length;
  if (blockEnd < blockStart) blockEnd = blockStart;
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

/// Toggles an inline [marker] (`**`, `_`, `` ` ``) around the selection.
/// Already wrapped (selection includes the markers, or sits inside a pair on
/// the line) removes them; no selection inserts a pair with the caret inside.
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

final _linkRe = RegExp(r'\[([^\]\n]*)\]\(([^)\n]*)\)');

/// `[text](url)`: wraps the selection (caret lands in the parens); on an
/// existing link it removes the link syntax and keeps the text.
TextEditingValue toggleLink(TextEditingValue v) {
  final text = v.text;
  final sel = _sel(v);
  final s = sel.start, e = sel.end;
  final ls = s > 0 ? text.lastIndexOf('\n', s - 1) + 1 : 0;
  var le = text.indexOf('\n', e);
  if (le < 0) le = text.length;
  for (final m in _linkRe.allMatches(text.substring(ls, le))) {
    final a = ls + m.start, b = ls + m.end;
    if (a <= s && e <= b) {
      final label = m.group(1)!;
      return _value(text.replaceRange(a, b, label), a, a + label.length);
    }
  }
  final label = text.substring(s, e);
  final out = text.replaceRange(s, e, '[$label]()');
  final caret = label.isEmpty ? s + 1 : s + label.length + 3;
  return _value(out, caret, caret);
}
