import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../providers/embedding_provider.dart';
import '../rag/index_chunks.dart';

/// Embedding and storing chunks: the part `_index` (a user's save or upload)
/// and the boot re-index job share. State changes (`status`, `updatedAt`)
/// stay with the callers.
class ChunkIndexer {
  /// Vectors already stored for [documentId], by chunk `contentHash` (the
  /// hash of the embedding input, tag included).
  static Future<Map<String, List<double>>> knownVectors(
    Session session,
    int documentId,
  ) async {
    final rows = await DocChunk.db.find(
      session,
      where: (t) => t.documentId.equals(documentId),
    );
    return {for (final r in rows) r.contentHash: r.embedding.toList()};
  }

  /// One vector per chunk, in order. Chunks whose input hash is in [known]
  /// keep that vector; only the rest are sent to [embedder].
  static Future<List<List<double>>> vectorsFor(
    EmbeddingProvider embedder,
    List<IndexChunk> chunks,
    String tag, {
    Map<String, List<double>> known = const {},
  }) async {
    final vectors = List<List<double>?>.filled(chunks.length, null);
    final missing = <int>[];
    for (var i = 0; i < chunks.length; i++) {
      final v = known[chunks[i].contentHash(tag)];
      if (v != null) {
        vectors[i] = v;
      } else {
        missing.add(i);
      }
    }
    if (missing.isNotEmpty) {
      final fresh = await embedder.embed([
        for (final i in missing) chunks[i].input,
      ]);
      if (fresh.length != missing.length) {
        throw EmbeddingException(
          'Expected ${missing.length} vectors, got ${fresh.length}',
        );
      }
      for (var k = 0; k < missing.length; k++) {
        vectors[missing[k]] = fresh[k];
      }
    }
    return [for (final v in vectors) v!];
  }

  /// Replaces the chunks of [document] inside [tx] (delete, then insert).
  static Future<void> replace(
    Session session,
    Transaction tx,
    Document document,
    List<IndexChunk> chunks,
    String tag,
    List<List<double>> vectors,
  ) async {
    await DocChunk.db.deleteWhere(
      session,
      where: (t) => t.documentId.equals(document.id!),
      transaction: tx,
    );
    if (chunks.isEmpty) return;
    await DocChunk.db.insert(
      session,
      [
        for (var i = 0; i < chunks.length; i++)
          DocChunk(
            documentId: document.id!,
            projectId: document.projectId,
            ownerId: document.ownerId,
            page: chunks[i].page,
            ordinal: chunks[i].ordinal,
            text: chunks[i].text,
            contentHash: chunks[i].contentHash(tag),
            embedding: Vector(vectors[i]),
          ),
      ],
      transaction: tx,
    );
  }
}
