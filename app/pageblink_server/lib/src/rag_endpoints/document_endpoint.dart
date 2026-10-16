import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag/chunker.dart';
import '../rag/embedding_spec.dart';
import '../rag/index_chunks.dart';
import '../rag/text_norm.dart';
import '../sample/sample_pack.dart';
import '../providers/embedding_provider.dart';
import '../demo/demo_guard.dart';
import '../demo/demo_user.dart';
import '../services/acl.dart';
import '../services/chunk_indexer.dart';
import '../services/index_config.dart';
import '../services/document_cleanup.dart';
import '../services/rag_services.dart';

/// Valid `colorIndex` is 0..noteColorCount-1: the 8 solid colors of `Pb.notes`
/// plus 8 = rainbow gradient (app side). Keep in sync with the app.
const noteColorCount = 9;

/// A document stuck in `indexing` longer than this lost its request (restart,
/// rollout, gateway kill). Normal indexing takes seconds: <= ~19 batches of
/// 32 chunks for a 512 KiB upload, each capped at [embeddingRequestTimeout].
const _staleIndexing = Duration(minutes: 10);

/// True when an `indexing` document has not been touched for [_staleIndexing].
/// `updatedAt` is set when indexing starts and not changed until it ends.
/// `list` applies the same predicate atomically in SQL (updateWhere).
bool isStaleIndexing(String status, DateTime updatedAt, DateTime now) =>
    status == 'indexing' && updatedAt.isBefore(now.subtract(_staleIndexing));

/// The save-note shortcut: same content AND already `ready`. A `failed` or
/// stuck `indexing` note with identical content must be re-indexed.
bool isUnchangedReadyNote(Document existing, String body, String title) =>
    existing.status == 'ready' &&
    existing.body == body &&
    existing.title == title;

/// A PDF whose extracted text yielded no chunks (a scan, or text-less pages)
/// can never be cited. Notes are exempt: an empty note is simply empty.
bool isNoTextFailure(String kind, int chunkCount) =>
    kind != 'note' && chunkCount == 0;

/// Thrown by `_index` when [isNoTextFailure]; becomes `lastError: 'no_text'`.
class NoTextException implements Exception {
  @override
  String toString() => 'NoTextException: no text to index';
}

/// Failure code the app localizes (`indexingError` in l10n.dart):
/// quota | auth | rate | outage | timeout | no_text | unknown
/// (+ interrupted, no_source).
String friendlyIndexingError(Object e) {
  if (e is NoTextException) return 'no_text';
  final m = '$e';
  if (m.contains(' 402')) return 'quota';
  if (m.contains(' 401') || m.contains(' 403')) return 'auth';
  if (m.contains(' 429')) return 'rate';
  if (RegExp(r' 5\d\d').hasMatch(m)) return 'outage';
  if (m.contains('timeout') || m.contains('TimeoutException')) return 'timeout';
  return 'unknown';
}

/// Upload and list documents. Text is extracted on the client (ADR 003).
class DocumentEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Indexes a document from per-page text. [projectId] null = personal.
  Future<Document> upload(
    Session session,
    String title,
    List<PageText> pages,
    String contentHash,
    int? projectId,
  ) async {
    final userId = Acl.requireUser(session);
    DemoGuard.requireNotSampleHash(session, userId, contentHash);
    if (projectId != null) {
      await Acl.requireRole(
        session,
        userId,
        projectId,
        roles: {'owner', 'editor'},
      );
    }

    final existing = await Document.db.findFirstRow(
      session,
      where: (t) =>
          t.contentHash.equals(contentHash) &
          t.ownerId.equals(userId) &
          t.projectId.equals(projectId),
    );
    if (existing != null && existing.status == 'ready') return existing;
    // A retry of the user's own failed document needs no new slot.
    if (existing == null) await DemoGuard.requireCreateSlot(session, userId);

    final now = DateTime.now().toUtc();
    // A retried failed/stuck document restarts the stale-indexing clock.
    var document = existing != null
        ? await Document.db.updateRow(
            session,
            existing.copyWith(status: 'indexing', updatedAt: now),
          )
        : await Document.db.insertRow(
            session,
            Document(
              ownerId: userId,
              projectId: projectId,
              title: nfc(title),
              contentHash: contentHash,
              version: 1,
              pageCount: pages.length,
              status: 'indexing',
              embeddingModel: EmbeddingSpec.model,
              createdAt: now,
              updatedAt: now,
            ),
          );

    return _index(session, document, pages);
  }

  /// Creates or updates a markdown note and (re)indexes it as one page.
  Future<Document> saveNote(
    Session session,
    int? documentId,
    String title,
    String body,
    int? projectId,
  ) async {
    final userId = Acl.requireUser(session);
    final bodyHash = sha256Hex(body);
    DemoGuard.requireNotSampleHash(session, userId, bodyHash);
    if (projectId != null) {
      await Acl.requireRole(
        session,
        userId,
        projectId,
        roles: {'owner', 'editor'},
      );
    }
    final now = DateTime.now().toUtc();
    final cleanTitle = nfc(
      title.trim().isEmpty ? _titleFrom(body) : title.trim(),
    );

    Document document;
    if (documentId == null) {
      await DemoGuard.requireCreateSlot(session, userId);
      document = await Document.db.insertRow(
        session,
        Document(
          ownerId: userId,
          projectId: projectId,
          kind: 'note',
          title: cleanTitle,
          body: body,
          contentHash: bodyHash,
          version: 1,
          pageCount: 1,
          status: 'indexing',
          embeddingModel: EmbeddingSpec.model,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final existing = await Document.db.findById(session, documentId);
      if (existing == null || existing.kind != 'note') {
        throw ArgumentError('Note not found');
      }
      await _requireWrite(session, userId, existing);
      if (isUnchangedReadyNote(existing, body, cleanTitle)) return existing;
      // Same content but not ready: re-index without bumping the version.
      final changed = existing.body != body || existing.title != cleanTitle;
      document = await Document.db.updateRow(
        session,
        existing.copyWith(
          title: cleanTitle,
          body: body,
          contentHash: bodyHash,
          version: changed ? existing.version + 1 : existing.version,
          lastError: null,
          status: 'indexing',
          updatedAt: now,
        ),
      );
    }
    return _index(session, document, [PageText(page: 1, text: body)]);
  }

  /// Sets (or clears with null) a note's card color. Metadata only: no
  /// re-index, and `updatedAt`/`version`/`status` stay as they are.
  Future<Document> setNoteColor(
    Session session,
    int documentId,
    int? colorIndex,
  ) async {
    final userId = Acl.requireUser(session);
    if (colorIndex != null &&
        (colorIndex < 0 || colorIndex >= noteColorCount)) {
      throw ArgumentError('Invalid color');
    }
    final document = await Document.db.findById(session, documentId);
    if (document == null || document.kind != 'note') {
      throw ArgumentError('Note not found');
    }
    await _requireWrite(session, userId, document);
    return Document.db.updateRow(
      session,
      document.copyWith(colorIndex: colorIndex),
      columns: (t) => [t.colorIndex],
    );
  }

  /// Localizes and indexes the sign-up sample note once (research 021 §A).
  /// Returns its id, or null when there is nothing to do (already handled,
  /// edited, deleted). Safe to call on every app start and from two tabs.
  Future<int?> ensureSample(Session session, String locale) async {
    final userId = Acl.requireUser(session);
    // The hook always inserts the English note: that hash marks "unprocessed".
    final seed = SamplePacks.signupEn.notes.first;
    final sample = SamplePacks.forLocale(
      locale,
      SampleAudience.signup,
    ).notes.first;
    final localize = sample.hash != seed.hash;
    // Claim atomically: bumping version 1 -> 2 is what makes this idempotent.
    final claimed = await Document.db.updateWhere(
      session,
      columnValues: (t) => [
        t.version(2),
        t.updatedAt(DateTime.now().toUtc()),
        if (localize) ...[
          t.title(sample.title),
          t.body(sample.body),
          t.contentHash(sample.hash),
        ],
      ],
      where: (t) =>
          t.ownerId.equals(userId) &
          t.projectId.equals(null) &
          t.kind.equals('note') &
          t.version.equals(1) &
          t.status.equals('indexing') &
          t.contentHash.equals(seed.hash),
    );
    if (claimed.isEmpty) return null;
    final document = claimed.first;
    await _index(session, document, [
      PageText(page: 1, text: document.body ?? ''),
    ]);
    return document.id;
  }

  /// Example questions for the sample content the caller holds, in the
  /// language of that content (research 028 §4.2). A sign-up sample counts
  /// only while its note is untouched (body hash) and `ready`: before that,
  /// or after an edit or delete, its questions would find nothing. A demo
  /// account gets its pack's questions directly.
  Future<List<SampleHint>> sampleHints(Session session) async {
    final userId = Acl.requireUser(session);
    final demo = DemoUser.packOf(userId);
    if (demo != null) return [_hint(demo)];
    final rows = await Document.db.find(
      session,
      where: (t) =>
          t.ownerId.equals(userId) &
          t.projectId.equals(null) &
          t.kind.equals('note') &
          t.status.equals('ready') &
          t.contentHash.inSet(SamplePacks.signupMarkers),
    );
    final held = {
      for (final d in rows)
        ?SamplePacks.byHash(d.contentHash, audience: SampleAudience.signup),
    };
    return [
      for (final p in SamplePacks.all)
        if (held.contains(p)) _hint(p),
    ];
  }

  static SampleHint _hint(SamplePack p) => SampleHint(
    packId: p.id,
    locale: p.locale,
    questions: [for (final q in p.questions) q.text],
  );

  /// One document the user can read (notes are opened in the editor).
  Future<Document?> get(Session session, int documentId) async {
    final userId = Acl.requireUser(session);
    final document = await Document.db.findById(session, documentId);
    if (document == null) return null;
    if (document.projectId == null) {
      return document.ownerId == userId ? document : null;
    }
    final projects = await Acl.memberProjectIds(session, userId);
    return projects.contains(document.projectId) ? document : null;
  }

  static const _storageId = DocumentCleanup.storageId;
  static String _pdfPath(int documentId) => 'pdfs/$documentId.pdf';

  /// Upload description for the original PDF of [documentId] (direct upload
  /// to cloud storage; API requests are capped at 512 KiB).
  Future<String> pdfUploadDescription(Session session, int documentId) async {
    final userId = Acl.requireUser(session);
    final document = await Document.db.findById(session, documentId);
    if (document == null || document.kind != 'pdf') {
      throw ArgumentError('PDF not found');
    }
    await _requireWrite(session, userId, document);
    return session.storage.createUploadDescription(
      storageId: _storageId,
      path: _pdfPath(documentId),
    );
  }

  /// Confirms the upload and records where the original is stored.
  Future<bool> confirmPdfUpload(Session session, int documentId) async {
    final userId = Acl.requireUser(session);
    final document = await Document.db.findById(session, documentId);
    if (document == null) return false;
    await _requireWrite(session, userId, document);
    final path = _pdfPath(documentId);
    final ok = await session.storage.verifyUpload(
      storageId: _storageId,
      path: path,
    );
    if (ok) {
      await Document.db.updateRow(
        session,
        document.copyWith(storagePath: path),
      );
    }
    return ok;
  }

  /// Short-lived download URL for the original PDF, after an access check.
  Future<String?> pdfUrl(Session session, int documentId) async {
    final document = await get(session, documentId);
    final path = document?.storagePath;
    if (path == null) return null;
    final url = await session.storage.temporaryDownloadUrl(
      storageId: _storageId,
      path: path,
    );
    return url.toString();
  }

  /// Retries indexing from the stored text (failed or stale documents).
  Future<Document> reindex(Session session, int documentId) async {
    final userId = Acl.requireUser(session);
    final document = await Document.db.findById(session, documentId);
    if (document == null) throw ArgumentError('Document not found');
    await _requireWrite(session, userId, document);
    final pages = await DocPage.db.find(
      session,
      where: (t) => t.documentId.equals(documentId),
      orderBy: (t) => t.page,
    );
    final texts = pages.isNotEmpty
        ? [for (final p in pages) PageText(page: p.page, text: p.text)]
        : document.kind == 'note'
        ? [PageText(page: 1, text: document.body ?? '')]
        : null;
    if (texts == null) {
      return Document.db.updateRow(
        session,
        document.copyWith(
          status: 'failed',
          lastError: 'no_source',
        ),
      );
    }
    final indexing = await Document.db.updateRow(
      session,
      document.copyWith(
        status: 'indexing',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return _index(session, indexing, texts);
  }

  /// Retries every failed document the user can edit. Returns how many are ready now.
  Future<int> reindexFailed(Session session) async {
    final failed = (await list(session)).where((d) => d.status == 'failed');
    var ready = 0;
    for (final d in failed) {
      try {
        if ((await reindex(session, d.id!)).status == 'ready') ready++;
      } on AccessDeniedException {
        // Viewers can't re-index project documents; skip.
      } on DemoLimitException {
        // Demo samples are locked; skip.
      }
    }
    return ready;
  }

  static String _titleFrom(String body) {
    final firstLine = body
        .trim()
        .split('\n')
        .first
        .replaceAll(RegExp(r'^[#>\-\*\s\[\]x]+'), '')
        .trim();
    if (firstLine.isEmpty) return 'Untitled note';
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
  }

  Future<void> _requireWrite(
    Session session,
    UuidValue userId,
    Document document,
  ) async {
    if (document.projectId == null) {
      if (document.ownerId != userId) throw AccessDeniedException();
    } else {
      await Acl.requireRole(
        session,
        userId,
        document.projectId!,
        roles: {'owner', 'editor'},
      );
    }
    DemoGuard.requireNotSample(session, userId, document);
  }

  /// Chunks, embeds and stores [pages], replacing previous chunks.
  Future<Document> _index(
    Session session,
    Document document,
    List<PageText> pages,
  ) async {
    // Keep the raw text so a failed document can be retried later.
    await session.db.transaction((tx) async {
      await DocPage.db.deleteWhere(
        session,
        where: (t) => t.documentId.equals(document.id!),
        transaction: tx,
      );
      await DocPage.db.insert(
        session,
        [
          for (final p in pages)
            DocPage(documentId: document.id!, page: p.page, text: p.text),
        ],
        transaction: tx,
      );
    });
    try {
      final version = IndexConfig.chunkerVersion(session);
      final embedder = RagServices.embedding(session);
      final tag = ChunkSpec.tag(embedder.modelId, version);
      final chunks = buildIndexChunks(
        kind: document.kind,
        title: document.title,
        pages: [for (final p in pages) (page: p.page, text: p.text)],
        version: version,
      );
      // Unchanged lines of an edited note keep their vectors.
      final vectors = await ChunkIndexer.vectorsFor(
        embedder,
        chunks,
        tag,
        known: chunks.isEmpty
            ? const {}
            : await ChunkIndexer.knownVectors(session, document.id!),
      );

      await session.db.transaction(
        (tx) =>
            ChunkIndexer.replace(session, tx, document, chunks, tag, vectors),
      );
      if (isNoTextFailure(document.kind, chunks.length)) {
        throw NoTextException();
      }
      document = document.copyWith(
        status: 'ready',
        embeddingModel: tag,
        lastError: null,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      session.log(
        'Indexing failed for document ${document.id}',
        level: e is NoTextException ? LogLevel.warning : LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      document = document.copyWith(
        status: 'failed',
        lastError: friendlyIndexingError(e),
        updatedAt: DateTime.now().toUtc(),
      );
    }
    try {
      return await Document.db.updateRow(session, document);
    } catch (e, st) {
      // Last resort: the row may stay `indexing`; `list` recovers it as
      // `failed`/`interrupted` after [_staleIndexing].
      session.log(
        'Could not save indexing result for document ${document.id}',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Personal documents plus documents of every project the user belongs to.
  Future<List<Document>> list(Session session) async {
    final userId = Acl.requireUser(session);
    final projectIds = await Acl.memberProjectIds(session, userId);
    Expression<dynamic> visible(DocumentTable t) =>
        (t.ownerId.equals(userId) & t.projectId.equals(null)) |
        (projectIds.isEmpty ? t.id.equals(-1) : t.projectId.inSet(projectIds));

    // Recover documents whose indexing request died (restart, rollout).
    await Document.db.updateWhere(
      session,
      columnValues: (t) => [t.status('failed'), t.lastError('interrupted')],
      where: (t) =>
          visible(t) &
          t.status.equals('indexing') &
          (t.updatedAt < DateTime.now().toUtc().subtract(_staleIndexing)),
    );
    return Document.db.find(
      session,
      where: visible,
      orderByList: (t) => [t.updatedAt.desc()],
    );
  }

  Future<void> delete(Session session, int documentId) async {
    final userId = Acl.requireUser(session);
    final document = await Document.db.findById(session, documentId);
    if (document == null) return;
    await _requireWrite(session, userId, document);
    await DocumentCleanup.deleteFiles(session, [document.storagePath]);
    await session.db.transaction(
      (tx) => DocumentCleanup.deleteRows(
        session,
        {documentId},
        transaction: tx,
      ),
    );
  }
}
