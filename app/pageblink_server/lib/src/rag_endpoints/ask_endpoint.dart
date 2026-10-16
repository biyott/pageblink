import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../providers/embedding_provider.dart';
import '../providers/llm_provider.dart';
import '../rag/chat_context.dart';
import '../rag/citation_infer.dart';
import '../rag/context_builder.dart';
import '../rag/embedding_spec.dart';
import '../demo/demo_guard.dart';
import '../services/acl.dart';
import '../services/ask_config.dart';
import '../services/ask_history_store.dart';
import '../services/llm_catalog.dart';
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
  ///
  /// With Ask history on (`ASK_HISTORY_ENABLED`, design 030) the question and
  /// answer are stored, [sessionId] picks the conversation (0 = new, null =
  /// an app that does not know conversations: recorded hidden, outside the
  /// limits) and the first event is `session`. Off, nothing changes.
  /// [visitorKey] tells demo visitors apart; other users' is ignored.
  Stream<AnswerEvent> ask(
    Session session,
    String question,
    List<int> projectIds,
    bool includePersonal,
    String? modelId, [
    String? locale,
    int? sessionId,
    String? visitorKey,
  ]) async* {
    final userId = Acl.requireUser(session);
    final cfg = AskConfig.of(session);
    final ko = locale == 'ko';
    if (!cfg.enabled) {
      // Throws DemoLimitException(askLimit): arrives as a stream error.
      DemoGuard.consumeAsk(session, userId);
      yield* _answer(
        session,
        userId,
        question,
        question,
        projectIds,
        includePersonal,
        modelId,
        ko,
        _Run(),
      );
      return;
    }

    final text = capQuestion(question, cfg.questionMax);
    final ctx = AskStore.ctx(userId, visitorKey);
    // The rules first: a refused question must not use up a demo question.
    // Anything else that goes wrong with the history only costs the history.
    AskPlan? plan;
    if (ctx.ok) {
      try {
        plan = await AskStore.run(
          session,
          (s) => AskStore.plan(s, ctx, sessionId, cfg),
        );
      } on AskLimitException {
        rethrow;
      } catch (e) {
        AskStore.warn('read', e);
      }
    }
    DemoGuard.consumeAsk(session, userId);
    AskHandle? handle;
    if (plan != null) {
      try {
        handle = await AskStore.run(
          session,
          (s) => AskStore.begin(
            s,
            ctx,
            plan!,
            cfg,
            question: text,
            locale: locale,
            projectIds: projectIds,
            includePersonal: includePersonal,
          ),
        );
      } on AskLimitException {
        rethrow;
      } catch (e) {
        AskStore.warn('write', e);
      }
    }
    if (handle != null && !handle.legacy) {
      yield AnswerEvent(
        type: 'session',
        sessionId: handle.sessionId,
        questionCount: handle.count,
        questionLimit: cfg.maxQuestions,
      );
    }

    // Earlier finished turns of this conversation (never for a legacy app).
    final past = handle == null || handle.legacy
        ? const <AskMessage>[]
        : plan!.past;
    final run = _Run(
      past: [for (final m in past) ChatTurn(m.question, m.answer)],
      cfg: cfg,
    );
    final chosen =
        modelId ?? session.passwords['llmModel'] ?? LlmCatalog.defaultModelId;
    var status = 'interrupted';
    String? errorCode;
    var lastSaved = DateTime.now();
    try {
      await for (final e in _answer(
        session,
        userId,
        text,
        searchQuery(
          text,
          past.isEmpty ? null : past.last.question,
          cfg.queryJoin,
        ),
        projectIds,
        includePersonal,
        modelId,
        ko,
        run,
      )) {
        switch (e.type) {
          case 'token':
            run.answer.write(e.text ?? '');
          case 'citation':
            if (e.citation != null) run.citations.add(e.citation!);
          case 'model':
            run.modelId = e.text;
          case 'done':
            status = 'done';
          case 'error':
            status = 'error';
            errorCode = run.errorCode ?? 'internal';
        }
        yield e;
        if (handle != null &&
            status == 'interrupted' &&
            DateTime.now().difference(lastSaved) >= _checkpointEvery) {
          lastSaved = DateTime.now();
          try {
            await AskStore.run(
              session,
              (s) => AskStore.checkpoint(
                s,
                handle!,
                answer: run.answer.toString(),
                citations: run.citations,
                modelId: run.modelId,
                fallback: run.modelId != null && run.modelId != chosen,
              ),
            );
          } catch (err) {
            AskStore.warn('checkpoint', err);
          }
        }
      }
    } catch (_) {
      status = 'error';
      errorCode = 'internal';
      rethrow;
    } finally {
      // Also runs when the app disconnects mid-answer (status stays
      // `interrupted`). Awaited, on a session of its own: the request's may
      // already be closed.
      if (handle != null) {
        try {
          await AskStore.run(
            session,
            (s) => AskStore.finish(
              s,
              handle!,
              status: status,
              answer: run.answer.toString(),
              citations: run.citations,
              modelId: run.modelId,
              fallback: run.modelId != null && run.modelId != chosen,
              errorCode: errorCode,
            ),
          );
        } catch (err) {
          AskStore.warn('finish', err);
        }
      }
    }
  }

  /// How often a partial answer is saved while it streams.
  static const _checkpointEvery = Duration(seconds: 3);

  /// Retrieval + generation. [query] is what is searched (the question, plus
  /// the previous one in a conversation); [question] is what the model is
  /// asked.
  Stream<AnswerEvent> _answer(
    Session session,
    UuidValue userId,
    String question,
    String query,
    List<int> projectIds,
    bool includePersonal,
    String? modelId,
    bool ko,
    _Run run,
  ) async* {
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
          ).embed([EmbeddingSpec.query(query)])).single,
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
        final terms = query
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
          text: ko ? keywordNoticeKo : keywordNoticeEn,
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
      final answerText = StringBuffer();
      Citation citationFor(int sourceIndex, String citedText) {
        final hit = hits[sourceIndex];
        final q = citationQuote(plans[sourceIndex], citedText);
        return Citation(
          // Matches the [n] marker the model writes (n = sourceIndex + 1).
          index: sourceIndex + 1,
          documentId: hit.documentId,
          documentTitle: titleOf(hit),
          kind: documents[hit.documentId]?.kind ?? 'pdf',
          page: hit.page,
          quote: q.quote,
          quoteStart: q.start,
        );
      }

      // Earlier turns come after the sources: the sources are never trimmed
      // for them, the history is (design 030 §4.6).
      final cfg = run.cfg;
      final history = cfg == null
          ? const <ChatTurn>[]
          : buildHistory(
              run.past,
              budget: historyBudget(
                contextBudget: cfg.contextBudget,
                promptMax: cfg.promptMax,
                sourcesChars: sources.fold(
                  0,
                  (a, p) =>
                      a +
                      p.title.length +
                      p.text.length +
                      (p.context?.length ?? 0),
                ),
                questionChars: question.length,
              ),
              answerChars: cfg.contextAnswer,
            );
      if (history.isNotEmpty) {
        session.log('ask: history turns=${history.length}');
      }

      await for (final event in RagServices.llm(
        session,
        modelId: modelId,
      ).answer(question, sources, history: history)) {
        switch (event) {
          case LlmText(:final text):
            answerText.write(text);
            yield AnswerEvent(type: 'token', text: text);
          case LlmCitation(:final sourceIndex, :final citedText):
            if (sourceIndex < 0 ||
                sourceIndex >= plans.length ||
                !cited.add(sourceIndex)) {
              break;
            }
            yield AnswerEvent(
              type: 'citation',
              citation: citationFor(sourceIndex, citedText),
            );
          case LlmModelUsed(:final modelId):
            yield AnswerEvent(type: 'model', text: modelId);
          case LlmDone():
            // The model wrote no marker at all: link the sources whose
            // evidence the answer repeats. Only on a finished answer (an
            // error skips this), before the done event.
            if (cited.isEmpty) {
              final inferred = inferCitations(answerText.toString(), [
                for (final p in plans) p.evidence,
              ]);
              if (inferred.isNotEmpty) {
                session.log('ask: inferred citations n=${inferred.length}');
                for (final i in inferred) {
                  yield AnswerEvent(
                    type: 'citation',
                    citation: citationFor(i, '').copyWith(inferred: true),
                  );
                }
              }
            }
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
      run.errorCode = e is LlmBusyException
          ? 'busy'
          : e is LlmException
          ? 'llm'
          : 'internal';
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

/// What one question accumulates and is given: the earlier turns and rules
/// going in, the answer coming out.
class _Run {
  _Run({this.past = const [], this.cfg});

  /// Finished earlier turns, oldest first (raw, as stored).
  final List<ChatTurn> past;

  /// Null when history is off: no earlier turns are built.
  final AskConfig? cfg;

  final answer = StringBuffer();
  final citations = <Citation>[];
  String? modelId;

  /// Short code of the failure, set by the answer when it ends in an error.
  String? errorCode;
}
