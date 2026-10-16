import 'dart:typed_data';

import 'recovery_models.dart';

/// Characters a reader can see: not whitespace, not control or format
/// characters, not the replacement character, not private-use code points
/// (what a broken text layer tends to hold).
int visibleCharCount(String text) {
  var n = 0;
  for (final r in text.runes) {
    if (_isVisible(r)) n++;
  }
  return n;
}

bool _isVisible(int r) {
  if (r <= 0x20 || (r >= 0x7f && r <= 0xa0)) return false; // controls, space
  if (r == 0xad) return false; // soft hyphen
  if (r >= 0x2000 && r <= 0x200f) return false; // spaces, zero-width, marks
  if (r >= 0x2028 && r <= 0x202f) return false;
  if (r == 0x205f || r == 0x2060 || r == 0x3000 || r == 0xfeff) return false;
  if (r == 0xfffc || r == 0xfffd) return false; // object / replacement
  if (r >= 0xe000 && r <= 0xf8ff) return false; // private use
  return true;
}

/// Which pages of a document need recovery, from the visible characters of
/// each page's text layer (index 0 is page 1). Pure.
///
/// A page is a candidate below [minChars] (design 032 section 5.1). Past
/// [maxPages] candidates the rest are listed as [RecoveryPlan.overLimit].
RecoveryPlan planRecovery(
  List<int> visibleChars, {
  int minChars = kRecoveryMinVisibleChars,
  int maxPages = kRecoveryMaxPages,
}) {
  final all = [
    for (var i = 0; i < visibleChars.length; i++)
      if (visibleChars[i] < minChars) i + 1,
  ];
  return RecoveryPlan(
    pageCount: visibleChars.length,
    visibleChars: List.unmodifiable(visibleChars),
    candidates: List.unmodifiable(all.take(maxPages)),
    overLimit: List.unmodifiable(all.skip(maxPages)),
  );
}

/// False only when [pdf] cannot contain form fields, so the form reader (about
/// 1.7 MB of script) need not be downloaded for a plain scan. Form fields hang
/// off the catalog's `/AcroForm`; that name is in the file text, unless the
/// catalog sits inside a compressed object stream (`/ObjStm`), which makes the
/// answer "maybe". Never a false negative for an unencrypted name.
bool mayHaveForms(Uint8List pdf) =>
    _contains(pdf, 'AcroForm'.codeUnits) || _contains(pdf, 'ObjStm'.codeUnits);

bool _contains(Uint8List data, List<int> needle) {
  final first = needle[0], last = data.length - needle.length;
  for (var i = 0; i <= last; i++) {
    if (data[i] != first) continue;
    var j = 1;
    while (j < needle.length && data[i + j] == needle[j]) {
      j++;
    }
    if (j == needle.length) return true;
  }
  return false;
}
