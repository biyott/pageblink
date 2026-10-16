import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/providers/embedding_provider.dart';
import 'package:pageblink_server/src/rag/embedding_spec.dart';
import 'package:pageblink_server/src/services/chunk_migration.dart';
import 'package:pageblink_server/src/services/index_config.dart';
import 'package:pageblink_server/src/services/rag_services.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'reindex_test.dart' show FakeEmbedder, FakeLlm;
import 'test_tools/serverpod_test_tools.dart';

const _p1 = 'The orientation starts at nine and ends at noon on Monday.';
const _p2 = 'Check in at the Busan harbor hotel. Dinner is at seven sharp.';
const _p3 = 'The ferry to Jeju leaves from pier four at dawn.';

void main() {
  final embedder = FakeEmbedder();

  withServerpod('Given PDF pages recovered on the client', (sb, endpoints) {
    late UuidValue owner;
    late TestSessionBuilder user;

    Future<List<DocPage>> pagesOf(Document d) => DocPage.db.find(
      sb.build(),
      where: (t) => t.documentId.equals(d.id!),
      orderBy: (t) => t.page,
    );

    List<PageText> upload({String ocr = _p2, String form = _p3}) => [
      PageText(page: 1, text: _p1),
      PageText(page: 2, text: ocr, source: 'ocr'),
      PageText(page: 3, text: form, source: 'form'),
    ];

    setUp(() {
      owner = const Uuid().v4obj();
      user = sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          owner.toString(),
          {},
        ),
      );
      RagServices.debugEmbedding = embedder;
      embedder
        ..inputs.clear()
        ..calls = 0
        ..failTimes = 0
        ..whileBusy = null;
      IndexConfig.debugChunkerVersion = null;
    });

    tearDown(() {
      RagServices.debugEmbedding = null;
      RagServices.debugLlm = null;
    });

    test(
      'upload stores each page source; unknown values become null',
      () async {
        final d = await endpoints.document.upload(
          user,
          'Trip',
          [
            PageText(page: 1, text: _p1),
            PageText(page: 2, text: _p2, source: 'ocr'),
            PageText(page: 3, text: _p3, source: 'ai'),
          ],
          'hash-1',
          null,
        );
        expect(d.status, 'ready');
        expect(
          [for (final p in await pagesOf(d)) p.source],
          [null, 'ocr', null],
        );
      },
    );

    test('an older client that sends no source stores null', () async {
      final d = await endpoints.document.upload(
        user,
        'Trip',
        [PageText(page: 1, text: _p1), PageText(page: 2, text: _p2)],
        'hash-2',
        null,
      );
      expect(d.status, 'ready');
      expect([for (final p in await pagesOf(d)) p.source], [null, null]);
    });

    test('reindex keeps source and text', () async {
      final d = await endpoints.document.upload(
        user,
        'Trip',
        upload(),
        'hash-3',
        null,
      );
      final again = await endpoints.document.reindex(user, d.id!);
      expect(again.status, 'ready');
      final pages = await pagesOf(d);
      expect([for (final p in pages) p.source], [null, 'ocr', 'form']);
      expect([for (final p in pages) p.text], [_p1, _p2, _p3]);
    });

    test('reindexFailed keeps source and text', () async {
      embedder
        ..failure = EmbeddingException('DeepInfra 503: down')
        ..failTimes = -1;
      final d = await endpoints.document.upload(
        user,
        'Trip',
        upload(),
        'hash-4',
        null,
      );
      expect(d.status, 'failed');
      embedder.failTimes = 0;
      expect(await endpoints.document.reindexFailed(user), 1);
      final pages = await pagesOf(d);
      expect([for (final p in pages) p.source], [null, 'ocr', 'form']);
      expect([for (final p in pages) p.text], [_p1, _p2, _p3]);
    });

    test(
      're-uploading a failed document with blank pages keeps the recovered text',
      () async {
        embedder
          ..failure = EmbeddingException('DeepInfra 503: down')
          ..failTimes = -1;
        final failed = await endpoints.document.upload(
          user,
          'Trip',
          upload(),
          'hash-5',
          null,
        );
        expect(failed.status, 'failed');
        embedder.failTimes = 0;

        // The same file again, from a client that did not recover: the two
        // image pages arrive blank and without a source.
        final d = await endpoints.document.upload(
          user,
          'Trip',
          [
            PageText(page: 1, text: _p1),
            PageText(page: 2, text: ''),
            PageText(page: 3, text: ' '),
          ],
          'hash-5',
          null,
        );
        expect(d.id, failed.id);
        expect(d.status, 'ready');
        final pages = await pagesOf(d);
        expect([for (final p in pages) p.text], [_p1, _p2, _p3]);
        expect([for (final p in pages) p.source], [null, 'ocr', 'form']);
        final chunks = await DocChunk.db.find(
          sb.build(),
          where: (t) => t.documentId.equals(d.id!),
        );
        expect({for (final c in chunks) c.page}, {1, 2, 3});
      },
    );

    test('a footer-only page is kept as recovered when re-uploaded', () async {
      embedder
        ..failure = EmbeddingException('DeepInfra 503: down')
        ..failTimes = -1;
      await endpoints.document.upload(user, 'Trip', upload(), 'hash-9', null);
      embedder.failTimes = 0;
      // The same file from a client that does not recover: page 2 is a scan
      // with only a page number in its text layer.
      final d = await endpoints.document.upload(
        user,
        'Trip',
        [
          PageText(page: 1, text: _p1),
          PageText(page: 2, text: 'Page 2'),
          PageText(page: 3, text: _p3 * 2),
        ],
        'hash-9',
        null,
      );
      expect(d.status, 'ready');
      final pages = await pagesOf(d);
      expect(pages[1].text, _p2);
      expect(pages[1].source, 'ocr');
      expect(pages[2].text, _p3 * 2, reason: 'a real text layer wins');
      expect(pages[2].source, isNull);
    });

    test('a retry that sends text replaces it, and its source', () async {
      embedder
        ..failure = EmbeddingException('DeepInfra 503: down')
        ..failTimes = -1;
      await endpoints.document.upload(user, 'Trip', upload(), 'hash-6', null);
      embedder.failTimes = 0;
      final d = await endpoints.document.upload(
        user,
        'Trip',
        [
          PageText(page: 1, text: _p1),
          PageText(page: 2, text: 'A real text layer now. Second sentence.'),
          PageText(page: 3, text: _p3, source: 'form'),
        ],
        'hash-6',
        null,
      );
      expect(d.status, 'ready');
      final pages = await pagesOf(d);
      expect(pages[1].text, startsWith('A real text layer'));
      expect([for (final p in pages) p.source], [null, null, 'form']);
    });

    test('the chunk migration leaves DocPage rows alone', () async {
      final d = await endpoints.document.upload(
        user,
        'Trip',
        upload(),
        'hash-7',
        null,
      );
      // make the document look stale: older tag
      await Document.db.updateRow(
        sb.build(),
        d.copyWith(embeddingModel: ChunkSpec.tag('fake/embed', 1)),
      );
      final r = await ChunkMigration.run(
        <R>(body) => body(sb.build()),
        pause: Duration.zero,
        log: (_) {},
      );
      expect(r.ok, 1);
      final pages = await pagesOf(d);
      expect([for (final p in pages) p.source], [null, 'ocr', 'form']);
      expect([for (final p in pages) p.text], [_p1, _p2, _p3]);
    });

    test('ask: a citation to a recovered page carries its source', () async {
      await endpoints.document.upload(user, 'Trip', upload(), 'hash-8', null);
      RagServices.debugLlm = FakeLlm();
      final events = await endpoints.ask
          .ask(user, 'orientation harbor hotel ferry pier', [], true, null)
          .toList();
      final bySource = {
        for (final e in events)
          if (e.citation != null) e.citation!.page: e.citation!.source,
      };
      expect(bySource.keys, containsAll([1, 2, 3]));
      expect(bySource[1], isNull);
      expect(bySource[2], 'ocr');
      expect(bySource[3], 'form');
    });
  });
}
