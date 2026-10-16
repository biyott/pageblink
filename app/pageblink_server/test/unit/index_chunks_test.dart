import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:pageblink_server/src/rag/embedding_spec.dart';
import 'package:pageblink_server/src/rag/index_chunks.dart';
import 'package:test/test.dart';

const _body =
    '# Q4 launch plan\n\n## Numbers\n- **Budget:** 12M for Q4\n'
    '- **Date:** moved to Nov 18\n\n## To do\n- [ ] Finalize the notes\n';

void main() {
  test('v2 note: the context is in the title slot, never in the text', () {
    final cs = buildIndexChunks(
      kind: 'note',
      title: 'Q4 launch plan',
      pages: [(page: 1, text: _body)],
    );
    expect(
      [for (final c in cs) c.text],
      [
        '- **Budget:** 12M for Q4',
        '- **Date:** moved to Nov 18',
        '- [ ] Finalize the notes',
      ],
    );
    for (final c in cs) {
      expect(_body, contains(c.text));
      expect(c.text, isNot(contains('Numbers')));
    }
    expect(
      cs[0].input,
      'title: Q4 launch plan > Numbers | text: ${cs[0].text}',
    );
    expect(cs[2].input, startsWith('title: Q4 launch plan > To do | text: '));
    expect([for (final c in cs) c.ordinal], [0, 1, 2]);
  });

  test('v2 title slot is capped at 120 chars', () {
    final cs = buildIndexChunks(
      kind: 'note',
      title: 'A' * 80,
      pages: [
        (page: 1, text: '## ${'B' * 90}\n- an item that is long enough\n'),
      ],
    );
    expect(cs.single.title.length, lessThanOrEqualTo(120));
    expect(cs.single.text, '- an item that is long enough');
  });

  test('v2 pdf: document title only, page and ordinal kept', () {
    final cs = buildIndexChunks(
      kind: 'pdf',
      title: 'Guide',
      pages: [
        (page: 1, text: 'Intro text goes here. It has two sentences.'),
        (page: 2, text: 'Second page text. Also two sentences here.'),
      ],
    );
    expect([for (final c in cs) c.page], [1, 2]);
    expect([for (final c in cs) c.ordinal], [0, 1]);
    expect(cs[1].input, startsWith('title: Guide | text: Second page'));
  });

  test('v1 (CHUNKER_VERSION=1) is the old paragraph chunker', () {
    final pages = [(page: 1, text: _body)];
    final cs = buildIndexChunks(
      kind: 'note',
      title: 'Q4 launch plan',
      pages: pages,
      version: ChunkSpec.legacy,
    );
    final old = chunkPages(pages);
    expect([for (final c in cs) c.text], [for (final c in old) c.text]);
    expect(
      cs.single.input,
      EmbeddingSpec.document('Q4 launch plan', old.single.text),
    );
  });

  test('the hash covers tag, title slot and text', () {
    final a = IndexChunk(1, 0, 'text', 'Doc > A');
    expect(
      a.contentHash('m#c2'),
      IndexChunk(1, 5, 'text', 'Doc > A').contentHash('m#c2'),
    );
    expect(a.contentHash('m#c2'), isNot(a.contentHash('m#c1')));
    expect(a.contentHash('m#c2'), isNot(a.contentHash('other#c2')));
    expect(
      a.contentHash('m#c2'),
      isNot(IndexChunk(1, 0, 'text', 'Doc > B').contentHash('m#c2')),
    );
  });

  test('the tag is model + chunk version', () {
    expect(
      ChunkSpec.tag('google/embeddinggemma-300m', 2),
      'google/embeddinggemma-300m#c2',
    );
    expect(ChunkSpec.latest, 2);
    expect(ChunkSpec.legacy, 1);
  });
}
