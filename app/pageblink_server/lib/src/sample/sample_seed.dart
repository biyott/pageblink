import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag/embedding_spec.dart';
import 'sample_note.dart';

/// `onAfterAccountCreated` hook: inserts the English sample note for a new
/// account. It runs inside the sign-up transaction, so it only writes one row
/// (no embedding; `document.ensureSample` indexes it later) and a failure is
/// rolled back to a savepoint and logged instead of failing the sign-up.
Future<void> seedSampleNote(
  Session session, {
  required String email,
  required UuidValue authUserId,
  required UuidValue emailAccountId,
  required Transaction? transaction,
}) async {
  Savepoint? savepoint;
  try {
    savepoint = await transaction?.createSavepoint();
    final now = DateTime.now().toUtc();
    await Document.db.insertRow(
      session,
      Document(
        ownerId: authUserId,
        kind: 'note',
        title: SampleNote.en.title,
        body: SampleNote.en.body,
        contentHash: SampleNote.seedHash,
        version: 1,
        pageCount: 1,
        status: 'indexing',
        embeddingModel: EmbeddingSpec.model,
        createdAt: now,
        updatedAt: now,
      ),
      transaction: transaction,
    );
    await savepoint?.release();
  } catch (e, st) {
    session.log(
      'Could not seed the sample note for $authUserId',
      level: LogLevel.warning,
      exception: e,
      stackTrace: st,
    );
    try {
      await savepoint?.rollback();
    } catch (_) {
      // The transaction is unusable; nothing more to do here.
    }
  }
}
