import 'chunker.dart';
import 'embedding_spec.dart';
import 'line_chunker.dart';

/// A chunk ready to embed and store, whichever chunker made it.
class IndexChunk {
  IndexChunk(this.page, this.ordinal, this.text, this.title);

  final int page;
  final int ordinal;

  /// Stored and cited as is.
  final String text;

  /// The `title:` slot of the embedding input (document title, then the
  /// heading path for notes). Never stored.
  final String title;

  String get input => EmbeddingSpec.document(title, text);

  /// Hash of the embedding input under [tag] (`<model>#c<version>`): equal
  /// hashes mean equal vectors, so unchanged lines of an edited note keep
  /// theirs.
  String contentHash(String tag) => sha256Hex('$tag\n$title\n$text');
}

/// Chunks a document with the rules of [version] (`ChunkSpec`). Pure.
List<IndexChunk> buildIndexChunks({
  required String kind,
  required String title,
  required List<({int page, String text})> pages,
  int version = ChunkSpec.latest,
}) {
  if (version == ChunkSpec.legacy) {
    return [
      for (final c in chunkPages(pages))
        IndexChunk(c.page, c.ordinal, c.text, title),
    ];
  }
  final pdfTitle = embeddingTitle(title, '');
  if (kind != 'note') {
    return [
      for (final c in chunkPdfPages(pages))
        IndexChunk(c.page, c.ordinal, c.text, pdfTitle),
    ];
  }
  final out = <IndexChunk>[];
  for (final p in pages) {
    for (final c in chunkNote(p.text, docTitle: title, page: p.page)) {
      out.add(
        IndexChunk(c.page, out.length, c.text, embeddingTitle(title, c.path)),
      );
    }
  }
  return out;
}
