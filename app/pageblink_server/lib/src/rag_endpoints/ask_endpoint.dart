import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../providers/llm_provider.dart';
import '../rag/embedding_spec.dart';
import '../services/acl.dart';
import '../services/rag_services.dart';

/// Retrieval + generation in one streaming call (Phase 0).
class AskEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  static const _topK = 8;

  /// Streams an answer to [question] over the user's personal documents and
  /// the requested projects they are a member of.
  Stream<AnswerEvent> ask(
    Session session,
    String question,
    List<int> projectIds,
    bool includePersonal,
  ) async* {
    final userId = Acl.requireUser(session);
    // Intersect with real memberships: client-sent ids are never trusted.
    final allowed = (await Acl.memberProjectIds(
      session,
      userId,
    )).intersection(projectIds.toSet());

    try {
      final queryVector = Vector(
        (await RagServices.embedding(
          session,
        ).embed([EmbeddingSpec.query(question)])).single,
      );

      final hits = await DocChunk.db.find(
        session,
        where: (t) {
          final personal = t.ownerId.equals(userId) & t.projectId.equals(null);
          final shared = allowed.isEmpty
              ? t.id.equals(-1)
              : t.projectId.inSet(allowed);
          return includePersonal ? (personal | shared) : shared;
        },
        orderBy: (t) => t.embedding.distanceCosine(queryVector),
        limit: _topK,
      );

      if (hits.isEmpty) {
        yield AnswerEvent(type: 'token', text: '검색할 문서가 없습니다. 먼저 PDF를 올려 주세요.');
        yield AnswerEvent(type: 'done');
        return;
      }

      final documentIds = {for (final h in hits) h.documentId};
      final documents = {
        for (final d in await Document.db.find(
          session,
          where: (t) => t.id.inSet(documentIds),
        ))
          d.id!: d,
      };
      String titleOf(DocChunk h) =>
          documents[h.documentId]?.title ?? 'Document';

      final sources = [
        for (final h in hits)
          SourcePassage(title: '${titleOf(h)} (p.${h.page})', text: h.text),
      ];

      final cited = <int>{};
      await for (final event in RagServices.llm(
        session,
      ).answer(question, sources)) {
        switch (event) {
          case LlmText(:final text):
            yield AnswerEvent(type: 'token', text: text);
          case LlmCitation(:final sourceIndex, :final citedText):
            if (sourceIndex < 0 ||
                sourceIndex >= hits.length ||
                !cited.add(sourceIndex)) {
              break;
            }
            final hit = hits[sourceIndex];
            yield AnswerEvent(
              type: 'citation',
              citation: Citation(
                // Matches the [n] marker the model writes (n = sourceIndex + 1).
                index: sourceIndex + 1,
                documentId: hit.documentId,
                documentTitle: titleOf(hit),
                page: hit.page,
                quote: citedText.isEmpty ? hit.text : citedText,
              ),
            );
          case LlmDone():
            yield AnswerEvent(type: 'done');
        }
      }
    } catch (e, st) {
      session.log(
        'ask failed',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      yield AnswerEvent(type: 'error', text: '답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }
}
