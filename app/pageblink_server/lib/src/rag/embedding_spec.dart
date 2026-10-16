/// Embedding rules shared by server and (later) device.
///
/// Pure Dart: no Serverpod imports, so it can move to packages/pageblink_core.
/// Device and server must use identical model, dimension and prefixes,
/// otherwise vectors live in different spaces (ADR 002).
class EmbeddingSpec {
  static const model = 'google/embeddinggemma-300m';
  static const dimensions = 768;

  static String query(String question) =>
      'task: search result | query: $question';

  static String document(String title, String text) =>
      'title: $title | text: $text';
}

/// Chunk rules version (design 029). `Document.embeddingModel` of a ready
/// document is `<embedding model id>#c<version>`: a document is stale when
/// that tag differs from the current one (new rules or a new embedder).
class ChunkSpec {
  /// Line/block notes, sentence-pack PDFs (`line_chunker.dart`).
  static const latest = 2;

  /// Paragraph chunks with overlap (`chunker.dart`), kept for rollback.
  static const legacy = 1;

  static String tag(String modelId, int version) => '$modelId#c$version';
}
