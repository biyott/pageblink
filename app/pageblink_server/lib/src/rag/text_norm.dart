// Twin of pageblink_flutter/lib/app/text_norm.dart: keep both in sync.

/// Composes decomposed Hangul jamo (NFD, what macOS gives for file names)
/// into precomposed syllables, so IME input (NFC) and stored NFD titles
/// compare equal.
///
/// Scope: only conjoining jamo L (U+1100..1112) + V (U+1161..1175) [+ T
/// (U+11A8..11C2)] -> U+AC00 syllables. Compatibility jamo (U+3130..) and
/// Latin combining marks are left as is. Lone/incomplete jamo pass through.
String nfc(String s) {
  const sBase = 0xAC00, lBase = 0x1100, vBase = 0x1161, tBase = 0x11A7;
  const lCount = 19, vCount = 21, tCount = 28;
  final out = <int>[];
  for (final c in s.runes) {
    if (out.isNotEmpty) {
      final p = out.last;
      if (p >= lBase &&
          p < lBase + lCount &&
          c >= vBase &&
          c < vBase + vCount) {
        out.last = sBase + ((p - lBase) * vCount + (c - vBase)) * tCount;
        continue;
      }
      if (p >= sBase &&
          p < sBase + lCount * vCount * tCount &&
          (p - sBase) % tCount == 0 &&
          c > tBase &&
          c < tBase + tCount) {
        out.last = p + (c - tBase);
        continue;
      }
    }
    out.add(c);
  }
  return String.fromCharCodes(out);
}
