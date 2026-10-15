/// Korean "keep-all" line breaking (docs/design/ui-polish/spec.md UP-01).
///
/// Flutter has no CSS `word-break: keep-all`, so a Hangul word can break between
/// any two syllables ("출/처가"). U+2060 WORD JOINER between the characters of a
/// word forbids that break; spaces stay the only break points.
///
/// Apply to static UI copy only: the joiner is invisible but is copied, searched
/// and read out. Not for user content (notes, titles), text fields, markdown
/// answers or strings sent to the server.
library;

const _wordJoiner = '⁠';

bool _isHangul(int r) =>
    (r >= 0xAC00 && r <= 0xD7A3) || // syllables
    (r >= 0x1100 && r <= 0x11FF) || // jamo
    (r >= 0x3130 && r <= 0x318F) || // compatibility jamo
    (r >= 0xA960 && r <= 0xA97F) || // jamo extended-A
    (r >= 0xD7B0 && r <= 0xD7FF); // jamo extended-B

bool _isWordChar(int r) =>
    _isHangul(r) ||
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A);

/// Inserts U+2060 between two adjacent word characters when at least one is
/// Hangul ("PDF를", "12쪽" stay whole too). Latin/digit-only runs, spaces,
/// punctuation and emoji are untouched. Idempotent.
String keepAllKorean(String s) {
  final out = StringBuffer();
  int? prev;
  for (final r in s.runes) {
    if (prev != null &&
        (_isHangul(prev) || _isHangul(r)) &&
        _isWordChar(prev) &&
        _isWordChar(r)) {
      out.write(_wordJoiner);
    }
    out.writeCharCode(r);
    prev = r;
  }
  return out.toString();
}
