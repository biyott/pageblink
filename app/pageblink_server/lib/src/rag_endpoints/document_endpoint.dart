import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../rag/chunker.dart';
import '../rag/embedding_spec.dart';
import '../services/acl.dart';
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
    try {
      final chunks = chunkPages([
        for (final p in pages) (page: p.page, text: p.text),
      ]);
      final vectors = chunks.isEmpty
          ? <List<double>>[]
          : await RagServices.embedding(session).embed([
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
    await session.db.transaction((tx) async {
      await DocChunk.db.deleteWhere(
        session,
        where: (t) => t.documentId.equals(documentId),
        transaction: tx,
      );
      await Document.db.deleteRow(session, document, transaction: tx);
    });
  }
}
