// The PDF card text (`Document.preview`): the start of the first page that
// has real text. Pure; the app shows it as is.

/// A page needs this many visible (non-space) characters, after cleaning, to
/// count as real text: a cover title or a stray number does not.
const previewMinChars = 40;

/// Upper bound of the stored preview, ellipsis included. The note card shows
/// about 5 lines of 38 Latin (19 Korean) characters, 6 with a one-line title.
const previewMaxChars = 240;

final _space = RegExp(r'\s+');
final _digits = RegExp(r'\d+');

// "3", "- 3 -", "3 / 9", "Page 3", "p. 3 of 9", "3쪽", "제 3 페이지"
final _pageNumber = RegExp(
  r'^[-–—\s]*(?:(?:page|p\.?|제)\s*)?\d{1,4}\s*(?:(?:/|of)\s*\d{1,4}\s*)?(?:쪽|페이지)?[-–—\s]*$',
  caseSensitive: false,
);

// Table-of-contents leaders: "Intro ..... 3", ". . . . .", "·····", "……"
final _leader = RegExp(r'(?:\.\s?){4,}|[·•⋯]{3,}|…{2,}');

bool _isContentsPage(int lines, int leaderLines) =>
    leaderLines >= 3 && leaderLines * 5 >= lines * 2;

int _visible(String s) => s.runes.where((r) => r > 0x20 && !_isSpace(r)).length;

bool _isSpace(int r) =>
    r == 0xa0 || r == 0x3000 || (r >= 0x2000 && r <= 0x200a) || r == 0xfeff;

List<String> _lines(String text) => [
  for (final l in text.split(RegExp(r'[\r\n  ]+')))
    if (l.replaceAll(_space, ' ').trim().isNotEmpty)
      l.replaceAll(_space, ' ').trim(),
];

/// Lines that open or close at least two pages (and a quarter of all pages),
/// ignoring digits: running heads and footers such as "Report 2026 - 3".
Set<String> _runningLines(List<List<String>> pages) {
  final seen = <String, int>{};
  for (final lines in pages) {
    final body = [
      for (final l in lines)
        if (!_pageNumber.hasMatch(l)) l,
    ];
    final edge = <String>{
      ...body.take(2).map(_key),
      ...body.skip(body.length < 2 ? 0 : body.length - 2).map(_key),
    };
    for (final k in edge) {
      seen[k] = (seen[k] ?? 0) + 1;
    }
  }
  return {
    for (final e in seen.entries)
      if (e.value >= 2 && e.value * 4 >= pages.length) e.key,
  };
}

String _key(String line) => line.replaceAll(_digits, '#').toLowerCase();

/// The preview of a PDF from its per-page text, or `''` when no page has
/// [previewMinChars] visible characters left after dropping page numbers,
/// running heads and footers, and contents pages.
String pdfPreview(List<({int page, String text})> pages) {
  final sorted = [...pages]..sort((a, b) => a.page.compareTo(b.page));
  final all = [for (final p in sorted) _lines(p.text)];
  final running = _runningLines(all);
  for (final lines in all) {
    final keep = <String>[];
    var leaders = 0;
    for (final l in lines) {
      if (_pageNumber.hasMatch(l) || running.contains(_key(l))) continue;
      if (_leader.hasMatch(l)) {
        leaders++;
        continue;
      }
      keep.add(l);
    }
    if (_isContentsPage(keep.length + leaders, leaders)) continue;
    final text = keep.join(' ');
    if (_visible(text) >= previewMinChars) return _cut(text);
  }
  return '';
}

// Spaced scripts end a word at a space; CJK punctuation ends one without it.
final _cjkPunct = RegExp(r'[。！？、，；：]');

/// [text] up to [previewMaxChars] characters, cut after a space or a
/// punctuation mark (never in the middle of a word), with `…` when cut.
String _cut(String text) {
  if (text.length <= previewMaxChars) return text;
  const room = previewMaxChars - 1; // the ellipsis
  var end = room;
  for (var i = room; i >= room ~/ 2; i--) {
    if (text[i] == ' ' || _cjkPunct.hasMatch(text[i - 1])) {
      end = i;
      break;
    }
  }
  // Not between the halves of a surrogate pair (emoji).
  if (end < text.length && (text.codeUnitAt(end) & 0xFC00) == 0xDC00) end--;
  final head = text
      .substring(0, end)
      .replaceFirst(RegExp(r'[\s.,;:、，。]+$'), '');
  return '$head…';
}
