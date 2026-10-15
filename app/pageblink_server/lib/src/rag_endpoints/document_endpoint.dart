import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag/chunker.dart';
import '../rag/embedding_spec.dart';
import '../sample/sample_note.dart';
import '../services/acl.dart';
import '../services/document_cleanup.dart';
import '../services/rag_services.dart';

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

    final now = DateTime.now().toUtc();
    var document =
        existing ??
        await Document.db.insertRow(
          session,
          Document(
            ownerId: userId,
            projectId: projectId,
            title: title,
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
    if (projectId != null) {
      await Acl.requireRole(
        session,
        userId,
        projectId,
        roles: {'owner', 'editor'},
      );
    }
    final now = DateTime.now().toUtc();
    final cleanTitle = title.trim().isEmpty ? _titleFrom(body) : title.trim();

    Document document;
    if (documentId == null) {
      document = await Document.db.insertRow(
        session,
        Document(
          ownerId: userId,
          projectId: projectId,
          kind: 'note',
          title: cleanTitle,
          body: body,
          contentHash: sha256Hex(body),
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
      if (existing.body == body && existing.title == cleanTitle) {
        return existing;
      }
      document = await Document.db.updateRow(
        session,
        existing.copyWith(
          title: cleanTitle,
          body: body,
          contentHash: sha256Hex(body),
          version: existing.version + 1,
          status: 'indexing',
          updatedAt: now,
        ),
      );
    }
    return _index(session, document, [PageText(page: 1, text: body)]);
  }

  /// Localizes and indexes the sign-up sample note once (research 021 §A).
  /// Returns its id, or null when there is nothing to do (already handled,
  /// edited, deleted). Safe to call on every app start and from two tabs.
  Future<int?> ensureSample(Session session, String locale) async {
    final userId = Acl.requireUser(session);
    final sample = SampleNote.forLocale(locale);
    final localize = sample.body != SampleNote.en.body;
    // Claim atomically: bumping version 1 -> 2 is what makes this idempotent.
    final claimed = await Document.db.updateWhere(
      session,
      columnValues: (t) => [
        t.version(2),
        t.updatedAt(DateTime.now().toUtc()),
        if (localize) ...[
          t.title(sample.title),
          t.body(sample.body),
          t.contentHash(sha256Hex(sample.body)),
        ],
      ],
      where: (t) =>
          t.ownerId.equals(userId) &
          t.projectId.equals(null) &
          t.kind.equals('note') &
          t.version.equals(1) &
          t.status.equals('indexing') &
          t.contentHash.equals(SampleNote.seedHash),
    );
    if (claimed.isEmpty) return null;
    final document = claimed.first;
    await _index(session, document, [
      PageText(page: 1, text: document.body ?? ''),
    ]);
    return document.id;
  }

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
      document.copyWith(status: 'indexing'),
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
      }
    }
    return ready;
  }

  /// Failure code the app localizes: quota | auth | rate | outage | unknown.
  static String _friendlyError(Object e) {
    final m = '$e';
    if (m.contains(' 402')) return 'quota';
    if (m.contains(' 401') || m.contains(' 403')) return 'auth';
    if (m.contains(' 429')) return 'rate';
    if (RegExp(r' 5\d\d').hasMatch(m)) return 'outage';
    return 'unknown';
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
      final chunks = chunkPages([
        for (final p in pages) (page: p.page, text: p.text),
      ]);
      final embedder = RagServices.embedding(session);
      final vectors = chunks.isEmpty
          ? <List<double>>[]
          : await embedder.embed([
              for (final c in chunks)
                EmbeddingSpec.document(document.title, c.text),
            ]);

      await session.db.transaction((tx) async {
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
                contentHash: chunks[i].contentHash,
                embedding: Vector(vectors[i]),
              ),
          ],
          transaction: tx,
        );
      });
      document = document.copyWith(
        status: 'ready',
        embeddingModel: embedder.modelId,
        lastError: null,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      session.log(
        'Indexing failed for document ${document.id}',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      document = document.copyWith(
        status: 'failed',
        lastError: _friendlyError(e),
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return Document.db.updateRow(session, document);
  }

  /// Personal documents plus documents of every project the user belongs to.
  Future<List<Document>> list(Session session) async {
    final userId = Acl.requireUser(session);
    final projectIds = await Acl.memberProjectIds(session, userId);
    return Document.db.find(
      session,
      where: (t) =>
          (t.ownerId.equals(userId) & t.projectId.equals(null)) |
          (projectIds.isEmpty
              ? t.id.equals(-1)
              : t.projectId.inSet(projectIds)),
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
