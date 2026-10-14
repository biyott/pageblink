import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:test/test.dart';

void main() {
  test('chunks stay within one page and carry page numbers', () {
    final pages = [
      (page: 1, text: '첫 문단입니다.\n\n둘째 문단입니다.'),
      (page: 2, text: 'A' * 2000),
    ];
    final chunks = chunkPages(pages, maxChars: 900, overlapChars: 100);

    expect(chunks.first.page, 1);
    expect(chunks.first.text, contains('첫 문단'));
    expect(chunks.where((c) => c.page == 2).length, greaterThan(1));
    expect(chunks.every((c) => c.text.length <= 900 + 101), isTrue);
    expect(
      [for (final c in chunks) c.ordinal],
      [for (var i = 0; i < chunks.length; i++) i],
    );
  });

  test('normalized text hashes identically', () {
    expect(
      sha256Hex(normalizeText('a  b\n\n\n\nc ')),
      sha256Hex(normalizeText('a b\n\nc')),
    );
  });

  test('empty pages produce no chunks', () {
    expect(chunkPages([(page: 1, text: '   ')]), isEmpty);
  });
}
