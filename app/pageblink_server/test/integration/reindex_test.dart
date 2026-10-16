import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/providers/embedding_provider.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:pageblink_server/src/rag/embedding_spec.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:pageblink_server/src/services/chunk_migration.dart';
import 'package:pageblink_server/src/services/index_config.dart';
import 'package:pageblink_server/src/services/rag_services.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// An embedder that needs no key or network. Vectors are hashed bag-of-words,
/// so cosine search finds lines that share words with the query.
class FakeEmbedder implements EmbeddingProvider {
  FakeEmbedder([this.modelId = 'fake/embed']);

  @override
  final String modelId;

  /// Everything that was sent for embedding, in order.
  final inputs = <String>[];
  int calls = 0;

  /// Throw [failure] on the next [failTimes] calls (-1: always).
  Object? failure;
  int failTimes = 0;

  /// Runs while "the provider is busy": the document can change under it.
  Future<void> Function()? whileBusy;

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    calls++;
    if (failTimes != 0) {
      if (failTimes > 0) failTimes--;
      throw failure!;
    }
    await whileBusy?.call();
    inputs.addAll(texts);
    return [for (final t in texts) vector(t)];
  }

  static List<double> vector(String text) {
    final v = List<double>.filled(EmbeddingSpec.dimensions, 0);
    v[0] = 0.1;
    for (final m in RegExp(r'[a-z0-9가-힣]+').allMatches(text.toLowerCase())) {
      var h = 0x811c9dc5;
      for (final u in m.group(0)!.codeUnits) {
        h = ((h ^ u) * 0x01000193) & 0x7fffffff;
      }
      v[1 + h % (EmbeddingSpec.dimensions - 1)] += 1;
    }
    var n = 0.0;
    for (final x in v) {
      n += x * x;
    }
    n = n == 0 ? 1 : n;
    return [for (final x in v) x / n];
  }
}

class FakeLlm implements LlmProvider {
  List<SourcePassage> seen = const [];

  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) async* {
    seen = sources;
    yield LlmText('answer');
    for (var i = 0; i < sources.length; i++) {
      yield LlmCitation(i, '');
    }
    yield LlmDone('stop');
  }
}

const _note =
    '# Q4 launch plan\n\n'
    '## Numbers\n'
    '- **Marketing budget:** 12M for Q4\n'
    '- **Launch date:** moved to Nov 18\n'
    '- **Beta testers:** 20 people\n\n'
    '## To do\n'
    '- [x] Book the launch-day support rota\n'
    '- [ ] Finalize the release notes\n';

void main() {
  final embedder = FakeEmbedder();
  final tagV2 = ChunkSpec.tag('fake/embed', 2);
  final tagV1 = ChunkSpec.tag('fake/embed', 1);
  final noWait = <Duration>[];

  withServerpod('Given the chunk re-index job', (sb, endpoints) {
    late UuidValue owner;

    Future<R> scope<R>(Future<R> Function(Session) body) => body(sb.build());

    Future<MigrationReport> run({int maxFails = 5}) => ChunkMigration.run(
      scope,
      pause: Duration.zero,
      maxConsecutiveFailures: maxFails,
      sleep: (d) async => noWait.add(d),
      log: (_) {},
    );

    Future<Document> doc({
      String title = 'Q4 launch plan',
      String? body = _note,
      String kind = 'note',
      String status = 'ready',
      String model = 'fake/embed#c1',
      String? hash,
      int pages = 1,
    }) async {
      final now = DateTime.utc(2026, 10, 1);
      final d = await Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: owner,
          kind: kind,
          title: title,
          body: body,
          contentHash: hash ?? sha256Hex('$title $body $model $status'),
          version: 3,
          pageCount: pages,
          status: status,
          embeddingModel: model,
          createdAt: now,
          updatedAt: now,
        ),
      );
      // what the old rules left behind: one blob chunk
      await DocChunk.db.insertRow(
        sb.build(),
        DocChunk(
          documentId: d.id!,
          ownerId: owner,
          page: 1,
          ordinal: 0,
          text: 'OLD ${body ?? 'pdf'}',
          contentHash: 'old-${d.id}',
          embedding: Vector(FakeEmbedder.vector('old')),
        ),
      );
      return d;
    }

    Future<List<DocChunk>> chunksOf(Document d) => DocChunk.db.find(
      sb.build(),
      where: (t) => t.documentId.equals(d.id!),
      orderBy: (t) => t.ordinal,
    );

    Future<Document> fresh(Document d) async =>
        (await Document.db.findById(sb.build(), d.id!))!;

    setUp(() {
      owner = const Uuid().v4obj();
      RagServices.debugEmbedding = embedder;
      embedder
        ..inputs.clear()
        ..calls = 0
        ..failTimes = 0
        ..whileBusy = null;
      noWait.clear();
      IndexConfig.debugChunkerVersion = null;
      IndexConfig.debugReindexOnBoot = null;
    });

    tearDown(() {
      RagServices.debugEmbedding = null;
      IndexConfig.debugChunkerVersion = null;
      IndexConfig.debugReindexOnBoot = null;
    });

    test('only ready documents with an older tag are touched', () async {
      final stale = await doc();
      final untagged = await doc(model: EmbeddingSpec.model);
      final current = await doc(model: tagV2);
      final failed = await doc(status: 'failed');
      final indexing = await doc(status: 'indexing');

      final r = await run();
      expect(r.pending, 2);
      expect(r.ok, 2);
      expect(r.aborted, isFalse);

      expect((await fresh(stale)).embeddingModel, tagV2);
      expect((await fresh(untagged)).embeddingModel, tagV2);
      for (final d in [current, failed, indexing]) {
        expect((await chunksOf(d)).single.text, startsWith('OLD'));
      }
      expect((await fresh(failed)).embeddingModel, 'fake/embed#c1');
      expect((await fresh(indexing)).status, 'indexing');
    });

    test('chunks become lines; status, updatedAt, version stay', () async {
      final d = await doc();
      await run();

      final after = await fresh(d);
      expect(after.status, 'ready');
      expect(after.updatedAt, d.updatedAt);
      expect(after.version, d.version);
      expect(after.contentHash, d.contentHash);
      expect(after.embeddingModel, tagV2);

      final cs = await chunksOf(d);
      expect(
        [for (final c in cs) c.text],
        [
          '- **Marketing budget:** 12M for Q4',
          '- **Launch date:** moved to Nov 18',
          '- **Beta testers:** 20 people',
          '- [x] Book the launch-day support rota',
          '- [ ] Finalize the release notes',
        ],
      );
      for (final c in cs) {
        expect(_note, contains(c.text));
        expect(c.ownerId, owner);
      }
      // the heading path went to the embedder, not into the stored text
      expect(
        embedder.inputs.first,
        'title: Q4 launch plan > Numbers | text: ${cs.first.text}',
      );
      expect(embedder.inputs.last, startsWith('title: Q4 launch plan > To do'));
    });

    test('a second run has nothing to do', () async {
      await doc();
      await run();
      embedder.calls = 0;
      final r = await run();
      expect(r.pending, 0);
      expect(embedder.calls, 0);
    });

    test('an edit during embedding discards the result', () async {
      final d = await doc();
      embedder.whileBusy = () async {
        await Document.db.updateRow(
          sb.build(),
          (await fresh(d)).copyWith(
            body: 'edited',
            contentHash: 'edited-hash',
            version: d.version + 1,
          ),
        );
      };
      final r = await run();
      expect(r.skipped, 1);
      expect(r.ok, 0);
      expect((await chunksOf(d)).single.text, startsWith('OLD'));
      expect((await fresh(d)).embeddingModel, 'fake/embed#c1');
    });

    test('a failure or a rename during embedding discards it too', () async {
      final d = await doc();
      embedder.whileBusy = () async {
        await Document.db.updateRow(
          sb.build(),
          (await fresh(d)).copyWith(status: 'failed', lastError: 'rate'),
        );
      };
      expect((await run()).skipped, 1);
      expect((await chunksOf(d)).single.text, startsWith('OLD'));

      final e = await doc(title: 'Before');
      embedder.whileBusy = () async {
        await Document.db.updateRow(
          sb.build(),
          (await fresh(e)).copyWith(title: 'After'),
        );
      };
      expect((await run()).skipped, 1);
      expect((await chunksOf(e)).single.text, startsWith('OLD'));
    });

    test('a delete during embedding leaves no chunks behind', () async {
      final d = await doc();
      embedder.whileBusy = () async {
        await DocChunk.db.deleteWhere(
          sb.build(),
          where: (t) => t.documentId.equals(d.id!),
        );
        await Document.db.deleteRow(sb.build(), await fresh(d));
      };
      final r = await run();
      expect(r.skipped, 1);
      expect(await chunksOf(d), isEmpty);
      expect(await Document.db.findById(sb.build(), d.id!), isNull);
    });

    test(
      'a rate limit keeps the old chunks, backs off 30s, then goes on',
      () async {
        final d = await doc();
        embedder
          ..failure = EmbeddingException('Gemini 429: slow down')
          ..failTimes = 1;
        final r = await run();
        expect(noWait.first, const Duration(seconds: 30));
        expect(r.ok, 1);
        expect(r.failed, 0);
        expect((await fresh(d)).embeddingModel, tagV2);
        expect((await fresh(d)).status, 'ready');
      },
    );

    test('five failures in a row stop the run, nothing is lost', () async {
      final a = await doc(title: 'A', body: '## A\n- one line of text\n');
      final b = await doc(title: 'B', body: '## B\n- two lines of text\n');
      embedder
        ..failure = EmbeddingException('DeepInfra 503: down')
        ..failTimes = -1;
      final r = await run();
      expect(r.aborted, isTrue);
      expect(embedder.calls, 5);
      expect(
        noWait.where((d) => d.inSeconds >= 30),
        [30, 60, 120, 120].map((s) => Duration(seconds: s)),
      );
      for (final d in [a, b]) {
        expect((await chunksOf(d)).single.text, startsWith('OLD'));
        expect((await fresh(d)).status, 'ready');
        expect((await fresh(d)).embeddingModel, 'fake/embed#c1');
      }
    });

    test('an authentication error stops at once', () async {
      await doc();
      await doc(title: 'B', body: '## B\n- two lines of text\n');
      embedder
        ..failure = EmbeddingException('Gemini 403: key')
        ..failTimes = -1;
      final r = await run();
      expect(r.aborted, isTrue);
      expect(embedder.calls, 1);
      expect(noWait, isEmpty);
    });

    test('REINDEX_ON_BOOT off: start does nothing', () async {
      final d = await doc();
      final pod = sb.build().server.serverpod;
      IndexConfig.debugReindexOnBoot = false;
      expect(ChunkMigration.start(pod, scope: scope), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(embedder.calls, 0);
      expect((await fresh(d)).embeddingModel, 'fake/embed#c1');
    });

    test('REINDEX_ON_BOOT on: start runs the job', () async {
      final d = await doc();
      final pod = sb.build().server.serverpod;
      IndexConfig.debugReindexOnBoot = true;
      final run = ChunkMigration.start(pod, scope: scope);
      expect(run, isNotNull);
      expect(
        ChunkMigration.start(pod, scope: scope),
        isNull,
        reason: 'one run',
      );
      final r = await run!;
      expect(r.ok, 1);
      expect((await fresh(d)).embeddingModel, tagV2);
    });

    test('CHUNKER_VERSION=1 rolls documents back to the old chunks', () async {
      final d = await doc(model: tagV2);
      IndexConfig.debugChunkerVersion = 1;
      final r = await run();
      expect(r.ok, 1);
      final after = await fresh(d);
      expect(after.embeddingModel, tagV1);
      final cs = await chunksOf(d);
      expect(cs, hasLength(1)); // the whole short note, as v1 made it
      expect(cs.single.text, contains('Marketing budget'));
      expect(cs.single.text, contains('Finalize the release notes'));
    });

    test('demo samples are re-indexed like any document', () async {
      final sample = SamplePacks.demoEn.notes.first;
      final d = await doc(
        title: sample.title,
        body: sample.body,
        hash: sample.hash,
      );
      final r = await run();
      expect(r.ok, 1);
      final after = await fresh(d);
      expect(after.contentHash, sample.hash, reason: 'seed marker kept');
      expect(after.embeddingModel, tagV2);
      expect((await chunksOf(d)).length, 10);
    });

    test(
      'a PDF uses its stored pages; without them it is left alone',
      () async {
        final withPages = await doc(kind: 'pdf', body: null, pages: 2);
        await DocPage.db.insert(sb.build(), [
          DocPage(
            documentId: withPages.id!,
            page: 1,
            text: 'First page has one sentence. And a second one follows.',
          ),
          DocPage(
            documentId: withPages.id!,
            page: 2,
            text: 'Second page sentence here. Another one on page two.',
          ),
        ]);
        final noPages = await doc(
          kind: 'pdf',
          body: null,
          title: 'Old PDF',
          hash: 'old-pdf',
        );

        final r = await run();
        expect(r.ok, 1);
        expect(r.skipped, 1);
        final cs = await chunksOf(withPages);
        expect([for (final c in cs) c.page], [1, 2]);
        expect(cs.first.text, startsWith('First page'));
        expect(
          embedder.inputs.first,
          startsWith('title: Q4 launch plan | text:'),
        );
        expect((await chunksOf(noPages)).single.text, startsWith('OLD'));
        expect((await fresh(noPages)).embeddingModel, 'fake/embed#c1');
      },
    );

    test('new notes are indexed with the v2 rules and tagged #c2', () async {
      final user = sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          owner.toString(),
          {},
        ),
      );
      final saved = await endpoints.document.saveNote(
        user,
        null,
        'Q4 launch plan',
        _note,
        null,
      );
      expect(saved.status, 'ready');
      expect(saved.embeddingModel, tagV2);
      final cs = await chunksOf(saved);
      expect(cs, hasLength(5));
      for (final c in cs) {
        expect(_note, contains(c.text));
      }
      expect(embedder.inputs, hasLength(5));

      // editing one line embeds one line: the other vectors are reused
      embedder.inputs.clear();
      final edited = await endpoints.document.saveNote(
        user,
        saved.id,
        'Q4 launch plan',
        _note.replaceFirst('Nov 18', 'Nov 25'),
        null,
      );
      expect(edited.status, 'ready');
      expect(embedder.inputs, hasLength(1));
      expect(embedder.inputs.single, contains('Nov 25'));
      expect(await chunksOf(edited), hasLength(5));
    });

    test('ask: evidence lines are the sources, sections are context', () async {
      final user = sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          owner.toString(),
          {},
        ),
      );
      final saved = await endpoints.document.saveNote(
        user,
        null,
        'Q4 launch plan',
        _note,
        null,
      );
      final llm = FakeLlm();
      RagServices.debugLlm = llm;
      addTearDown(() => RagServices.debugLlm = null);

      final events = await endpoints.ask
          .ask(user, 'When is the launch date?', [], true, null)
          .toList();
      final citations = [
        for (final e in events)
          if (e.citation != null) e.citation!,
      ];
      expect(llm.seen, hasLength(5));
      expect(citations, hasLength(5));
      for (final c in citations) {
        final src = llm.seen[c.index - 1];
        expect(c.quote, src.text, reason: 'the cited text is the small unit');
        expect(c.documentId, saved.id);
        expect(c.kind, 'note');
        expect(_note.startsWith(c.quote, c.quoteStart!), isTrue);
        expect(src.title, startsWith('Q4 launch plan › '));
      }
      // two sections: each context is carried once, the rest point to it
      final carriers = llm.seen.where((s) => s.context != null).toList();
      expect(carriers, hasLength(2));
      expect(carriers.map((s) => s.context).toSet(), hasLength(2));
      expect(llm.seen.where((s) => s.contextOf != null), hasLength(3));
      for (final s in llm.seen) {
        expect(s.context == null, s.contextOf != null);
      }
    });

    test('ask: a busy-models failure gets its own message', () async {
      final user = sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          owner.toString(),
          {},
        ),
      );
      await endpoints.document.saveNote(user, null, 'Plan', _note, null);
      RagServices.debugLlm = _BusyLlm();
      addTearDown(() => RagServices.debugLlm = null);

      final ko = await endpoints.ask
          .ask(user, 'When is the launch date?', [], true, null, 'ko')
          .toList();
      expect(ko.last.type, 'error');
      expect(ko.last.text, contains('답변 모델이 일시적으로 바쁩니다'));
      final en = await endpoints.ask
          .ask(user, 'When is the launch date?', [], true, null)
          .toList();
      expect(en.last.text, contains('busy'));
    });
  });
}

class _BusyLlm implements LlmProvider {
  @override
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources) =>
      Stream.error(LlmBusyException('cap'));
}
