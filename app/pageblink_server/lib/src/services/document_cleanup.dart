import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Removes documents together with everything that hangs off them. There are
/// no foreign keys, so the server does it (used by `document.delete` and
/// `project.deleteProject`).
class DocumentCleanup {
  static const storageId = 'private';

  /// Deletes chunks, pages and the documents themselves.
  static Future<void> deleteRows(
    Session session,
    Set<int> documentIds, {
    required Transaction transaction,
  }) async {
    if (documentIds.isEmpty) return;
    await DocChunk.db.deleteWhere(
      session,
      where: (t) => t.documentId.inSet(documentIds),
      transaction: transaction,
    );
    await DocPage.db.deleteWhere(
      session,
      where: (t) => t.documentId.inSet(documentIds),
      transaction: transaction,
    );
    await Document.db.deleteWhere(
      session,
      where: (t) => t.id.inSet(documentIds),
      transaction: transaction,
    );
  }

  /// Deletes stored PDF originals; failures are only logged.
  static Future<void> deleteFiles(
    Session session,
    Iterable<String?> paths,
  ) async {
    for (final path in paths.whereType<String>()) {
      try {
        await session.storage.deleteFile(storageId: storageId, path: path);
      } catch (e) {
        session.log('Could not delete $path: $e', level: LogLevel.warning);
      }
    }
  }
}
