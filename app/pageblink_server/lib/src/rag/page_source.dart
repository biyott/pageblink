import '../generated/protocol.dart';

/// Where a PDF page's text came from when it is not the PDF text layer.
const pageSourceForm = 'form';
const pageSourceOcr = 'ocr';

/// The client's `source`, or null for anything else (null = original text).
/// Trust boundary: only known values reach the database.
String? normalizePageSource(String? source) =>
    source == pageSourceForm || source == pageSourceOcr ? source : null;

/// Pages as the client sent them, with an unknown `source` dropped.
List<PageText> normalizePages(List<PageText> pages) => [
  for (final p in pages)
    p.source == normalizePageSource(p.source)
        ? p
        : p.copyWith(source: normalizePageSource(p.source)),
];

/// Pages with fewer visible characters than this have no real text layer
/// (the client's recovery candidates: scans, footer-only scans, form pages).
const recoveryCandidateChars = 30;

int _visibleChars(String text) =>
    text.runes.where((r) => r > 0x20 && !(r >= 0x7f && r <= 0xa0)).length;

/// A retried upload of the same file (the document `failed` or got stuck)
/// must not erase text that was recovered earlier. The bytes are the same, so
/// a page that was recovered had almost no text layer, and a client that does
/// not recover again sends that near-nothing (blank, or only a footer such as
/// a page number) without a `source`. Where [incoming] has no `source` and
/// fewer than [recoveryCandidateChars] visible characters, keep the stored page
/// of the same number if it was recovered (has a `source` and text). Text the
/// client sends with a `source`, or with a real text layer, wins.
List<PageText> keepRecoveredPages(
  List<PageText> incoming,
  Iterable<DocPage> stored,
) {
  final recovered = {
    for (final d in stored)
      if (normalizePageSource(d.source) != null && d.text.trim().isNotEmpty)
        d.page: d,
  };
  if (recovered.isEmpty) return incoming;
  return [
    for (final p in incoming)
      if (p.source == null &&
          _visibleChars(p.text) < recoveryCandidateChars &&
          recovered.containsKey(p.page))
        PageText(
          page: p.page,
          text: recovered[p.page]!.text,
          source: recovered[p.page]!.source,
        )
      else
        p,
  ];
}
