import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/text_norm.dart';

// Decompose precomposed syllables into L V [T] jamo (what macOS file names use).
String _nfd(String s) {
  final out = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0xAC00 && c <= 0xD7A3) {
      final i = c - 0xAC00;
      out.writeCharCode(0x1100 + i ~/ 588);
      out.writeCharCode(0x1161 + (i % 588) ~/ 28);
      if (i % 28 != 0) out.writeCharCode(0x11A7 + i % 28);
    } else {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

void main() {
  test('NFD Korean composes to NFC', () {
    final nfd = _nfd('부산 여행 계획');
    expect(nfd.length, 17); // 21 with '.pdf'
    expect(nfc(nfd), '부산 여행 계획');
    expect(nfc(nfd).length, 8);
  });

  test('NFC, ASCII, digits, spaces and mixed text are unchanged', () {
    for (final s in ['부산 여행', 'Report 2026 v2', '  a b ', '', '계획 Plan 3']) {
      expect(nfc(s), s);
    }
    expect(nfc(_nfd('보고서 Q3 최종')), '보고서 Q3 최종');
  });

  test('incomplete jamo pass through without crashing', () {
    const l = 'ᄀ', v = 'ᅡ', t = 'ᆨ';
    expect(nfc(l), l); // initial only
    expect(nfc(v), v); // vowel only
    expect(nfc(t), t); // final only
    expect(nfc('$l$l'), '$l$l');
    expect(nfc('$v$t'), '$v$t');
    expect(nfc('$l$v$t'), '각');
    expect(nfc('$l$v$t$t'), '각$t'); // LVT + T: no second final
  });
}
