import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../providers/embedding_provider.dart';
import '../providers/llm_provider.dart';
import '../rag/context_builder.dart';
import '../rag/embedding_spec.dart';
import '../demo/demo_guard.dart';
import '../services/acl.dart';
import '../services/rag_services.dart';

/// Retrieval + generation in one streaming call (Phase 0).
class AskEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Small units (chunks) retrieved. Lines are short, so more of them fit
  /// the same context budget than the old 900-char chunks did.
  static const _topK = 16;

  /// Streams an answer to [question] over the user's personal documents and
  /// the requested projects they are a member of.
  Stream<AnswerEvent> ask(
    Session session,
    String question,
    List<int> projectIds,
    bool includePersonal,
    String? modelId, [
    String? locale,
  ]) async* {
    final userId = Acl.requireUser(session);
    // Throws DemoLimitException(askLimit): arrives as a stream error.
    DemoGuard.consumeAsk(session, userId);
    final ko = locale == 'ko';
    // Intersect with real memberships: client-sent ids are never trusted.
    final allowed = (await Acl.memberProjectIds(
      session,
      userId,
    )).intersection(projectIds.toSet());

    try {
      Expression<dynamic> scope(DocChunkTable t) {
        final personal = t.ownerId.equals(userId) & t.projectId.equals(null);
        final shared = allowed.isEmpty
            ? t.id.equals(-1)
            : t.projectId.inSet(allowed);
        return includePersonal ? (personal | shared) : shared;
      }

      List<DocChunk> hits;
      try {
        final queryVector = Vector(
          (await RagServices.embedding(
            session,
          ).embed([EmbeddingSpec.query(question)])).single,
        );
        hits = await DocChunk.db.find(
          session,
          where: scope,
          orderBy: (t) => t.embedding.distanceCosine(queryVector),
          limit: _topK,
        );
      } on EmbeddingException catch (e) {
        // Embedding service down or out of quota: degrade to keyword search
        // over already-indexed chunks instead of failing the question.
        session.log(
          'Query embedding failed, using keyword fallback: $e',
          level: LogLevel.warning,
        );
        final terms = question
            .split(RegExp(r'[\s,.?!]+'))
            .where((w) => w.length >= 2)
            .take(6)
            .toList();
        hits = terms.isEmpty
            ? []
            : await DocChunk.db.find(
                session,
                where: (t) =>
                    scope(t) &
                    terms
                        .map((w) => t.text.ilike('%$w%'))
                        .reduce((a, b) => a | b),
                limit: _topK,
              );
        yield AnswerEvent(
          type: 'token',
          text: ko
              ? '_(의미 검색을 잠시 쓸 수 없어 키워드 검색 결과로 답합니다.)_\n\n'
              : '_(Semantic search is unavailable right now, so this answer uses keyword matches.)_\n\n',
        );
      }

      if (hits.isEmpty) {
        yield AnswerEvent(
          type: 'token',
          text: ko
              ? '관련 내용을 찾지 못했어요. 노트를 쓰거나 PDF를 올린 뒤, 색인이 끝났는지 확인해 주세요.'
              : 'Nothing relevant found yet. Write a note or upload a PDF, and make sure indexing has finished.',
        );
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

      // Large units are computed from the stored text, not stored (design
      // 029 §4.4). PDF pages are read only for the pages that were hit.
      final pdfHits = [
        for (final h in hits)
          if (documents[h.documentId] != null &&
              documents[h.documentId]!.kind != 'note')
            h,
      ];
      final pageTexts = pdfHits.isEmpty
          ? <String, String>{}
          : {
              for (final p in await DocPage.db.find(
                session,
                where: (t) =>
                    t.documentId.inSet({
                      for (final h in pdfHits) h.documentId,
                    }) &
                    t.page.inSet({for (final h in pdfHits) h.page}),
              ))
                '${p.documentId}:${p.page}': p.text,
            };
      final plans = planSources(
        [
          for (final h in hits)
            HitInput(
              documentId: h.documentId,
              page: h.page,
              ordinal: h.ordinal,
              text: h.text,
            ),
        ],
        doc: (id) {
          final d = documents[id];
          return d == null
              ? null
              : DocInput(kind: d.kind, title: d.title, body: d.body);
        },
        pageText: (id, page) => pageTexts['$id:$page'],
      );
      // `[n]` is plans[n - 1]; plans is a prefix of hits (budget).
      final sources = [
        for (final p in plans)
          SourcePassage(
            title: p.title,
            text: p.evidence,
            context: p.context,
            contextOf: p.contextRef == null ? null : p.contextRef! + 1,
          ),
      ];

      final cited = <int>{};
      await for (final event in RagServices.llm(
        session,
        modelId: modelId,
      ).answer(question, sources)) {
        switch (event) {
          case LlmText(:final text):
            yield AnswerEvent(type: 'token', text: text);
          case LlmCitation(:final sourceIndex, :final citedText):
            if (sourceIndex < 0 ||
                sourceIndex >= plans.length ||
                !cited.add(sourceIndex)) {
              break;
            }
            final hit = hits[sourceIndex];
            final q = citationQuote(plans[sourceIndex], citedText);
            yield AnswerEvent(
              type: 'citation',
              citation: Citation(
                // Matches the [n] marker the model writes (n = sourceIndex + 1).
                index: sourceIndex + 1,
                documentId: hit.documentId,
                documentTitle: titleOf(hit),
                kind: documents[hit.documentId]?.kind ?? 'pdf',
                page: hit.page,
                quote: q.quote,
                quoteStart: q.start,
              ),
            );
          case LlmModelUsed(:final modelId):
            yield AnswerEvent(type: 'model', text: modelId);
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
      yield AnswerEvent(
        type: 'error',
        text: e is LlmBusyException
            ? (ko
                  ? '답변 모델이 일시적으로 바쁩니다. 잠시 후 다시 시도해 주세요.'
                  : 'The answer models are busy right now. Please try again shortly.')
            : (ko
                  ? '답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.'
                  : 'Could not generate an answer. Please try again shortly.'),
      );
    }
  }
}
