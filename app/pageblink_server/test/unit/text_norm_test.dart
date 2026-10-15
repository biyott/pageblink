import 'package:pageblink_server/src/rag/text_norm.dart';
import 'package:test/test.dart';

void main() {
  test('NFD Korean title composes to NFC; ASCII and NFC are unchanged', () {
    // '부산 여행 계획' as macOS writes it (L V [T] jamo).
    const nfd =
        '\u1107\u116E\u1109\u1161\u11AB \u110B\u1167\u1112\u1162\u11BC '
        '\u1100\u1168\u1112\u116C\u11A8';
    expect(nfd.length, 17); // 21 with '.pdf'
    expect(nfc(nfd), '부산 여행 계획');
    expect(nfc('부산 여행 계획'), '부산 여행 계획');
    expect(nfc('Report 2026'), 'Report 2026');
  });

  test('incomplete jamo pass through', () {
    expect(nfc('ᄀ'), 'ᄀ');
    expect(nfc('ᅡ'), 'ᅡ');
    expect(nfc('ᆨ'), 'ᆨ');
  });
}
