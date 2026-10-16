import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:pageblink_server/src/services/index_config.dart';
import 'package:pageblink_server/src/services/preview_backfill.dart';
import 'package:pageblink_server/src/services/rag_services.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'reindex_test.dart' show FakeEmbedder;
import 'test_tools/serverpod_test_tools.dart';

const _cover = 'Trip guide';
const _p1 = 'The orientation starts at nine and ends at noon on Monday.';
const _p2 = 'Check in at the Busan harbor hotel. Dinner is at seven sharp.';

void main() {
  final embedder = FakeEmbedder();

  withServerpod('Given the PDF card preview', (sb, endpoints) {
    late UuidValue owner;
    late TestSessionBuilder user;

    Future<R> scope<R>(Future<R> Function(Session) body) => body(sb.build());
    Future<PreviewReport> backfill() =>
        PreviewBackfill.run(scope, batch: 2, log: (_) {});
    Future<Document> fresh(int id) async =>
        (await Document.db.findById(sb.build(), id))!;

    Future<Document> pdf({
      String status = 'ready',
      String kind = 'pdf',
      String? preview,
      String? hash,
      List<String> pages = const [_cover, '$_p1 $_p2'],
    }) async {
      final now = DateTime.utc(2026, 10, 1);
      final d = await Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: owner,
          kind: kind,
          title: 'Trip',
          contentHash:
              hash ?? 'h-${DateTime.now().microsecondsSinceEpoch}$pages',
          version: 3,
          pageCount: pages.length,
          preview: preview,
          status: status,
          embeddingModel: 'old',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await DocPage.db.insert(sb.build(), [
        for (var i = 0; i < pages.length; i++)
          DocPage(documentId: d.id!, page: i + 1, text: pages[i]),
      ]);
      return d;
    }

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

    tearDown(() => RagServices.debugEmbedding = null);

    test('upload stores the preview of the first real page', () async {
      final d = await endpoints.document.upload(
        user,
        'Trip',
        [PageText(page: 1, text: _cover), PageText(page: 2, text: '$_p1 $_p2')],
        'hash-up',
        null,
      );
      expect(d.status, 'ready');
      expect(d.preview, '$_p1 $_p2');
      expect((await fresh(d.id!)).preview, '$_p1 $_p2');
      final listed = await endpoints.document.list(user);
      expect(listed.single.preview, '$_p1 $_p2');
    });

    test('a PDF without readable text gets an empty string', () async {
      final d = await endpoints.document.upload(
        user,
        'Scan',
        [PageText(page: 1, text: ''), PageText(page: 2, text: '   ')],
        'hash-scan',
        null,
      );
      expect(d.status, 'failed');
      expect(d.lastError, 'no_text');
      expect(d.preview, '');
      expect((await fresh(d.id!)).preview, '');
    });

    test('form and OCR pages count', () async {
      final d = await endpoints.document.upload(
        user,
        'Form',
        [
          PageText(page: 1, text: ''),
          PageText(page: 2, text: _p1, source: 'ocr'),
        ],
        'hash-ocr',
        null,
      );
      expect(d.preview, _p1);
    });

    test('a note keeps a null preview', () async {
      final n = await endpoints.document.saveNote(
        user,
        null,
        'Note',
        'A note body that is long enough to be a real preview of text.',
        null,
      );
      expect(n.kind, 'note');
      expect(n.preview, isNull);
      final again = await endpoints.document.reindex(user, n.id!);
      expect(again.preview, isNull);
    });

    test('reindex recomputes the preview from the stored pages', () async {
      final d = await pdf(status: 'failed', preview: 'stale');
      final r = await endpoints.document.reindex(user, d.id!);
      expect(r.status, 'ready');
      expect(r.preview, '$_p1 $_p2');
      expect((await fresh(d.id!)).preview, '$_p1 $_p2');
    });

    test('reindexFailed and a retried upload fill it too', () async {
      final d = await pdf(status: 'failed');
      expect(await endpoints.document.reindexFailed(user), 1);
      expect((await fresh(d.id!)).preview, '$_p1 $_p2');

      final f = await pdf(status: 'failed', pages: [''], hash: 'h-retry');
      final r = await endpoints.document.upload(
        user,
        'Trip',
        [PageText(page: 1, text: _p1)],
        'h-retry',
        null,
      );
      expect(r.id, f.id);
      expect(r.preview, _p1);
    });

    test('the backfill fills only ready PDFs whose preview is null', () async {
      final todo = await pdf();
      final scan = await pdf(pages: ['', '3']);
      final noPages = await pdf(pages: []);
      final kept = await pdf(preview: 'KEEP');
      final failed = await pdf(status: 'failed');
      final indexing = await pdf(status: 'indexing');
      final note = await pdf(kind: 'note');

      final r = await backfill();
      expect((r.pending, r.filled, r.empty, r.skipped), (3, 1, 2, 0));
      expect((await fresh(todo.id!)).preview, '$_p1 $_p2');
      expect((await fresh(scan.id!)).preview, '');
      expect((await fresh(noPages.id!)).preview, '');
      expect((await fresh(kept.id!)).preview, 'KEEP');
      for (final d in [failed, indexing, note]) {
        expect((await fresh(d.id!)).preview, isNull);
      }
      expect(embedder.calls, 0, reason: 'no embedding');
    });

    test('it is idempotent: the second run has nothing to do', () async {
      await pdf();
      expect((await backfill()).filled, 1);
      final again = await backfill();
      expect((again.pending, again.filled, again.empty), (0, 0, 0));
    });

    test('a row filled meanwhile is not overwritten', () async {
      final d = await pdf(preview: 'ANOTHER INSTANCE');
      final gone = await scope((s) => PreviewBackfill.fill(s, d.id!));
      expect(gone, isNull);
      expect((await fresh(d.id!)).preview, 'ANOTHER INSTANCE');
      final todo = await pdf();
      expect(await scope((s) => PreviewBackfill.fill(s, todo.id!)), isNotNull);
      expect(await scope((s) => PreviewBackfill.fill(s, todo.id!)), isNull);
    });

    test('it writes the preview and nothing else, samples included', () async {
      final hash = SamplePacks.demoPdf.hash;
      final sample = await pdf(hash: hash);
      final before = await fresh(sample.id!);
      await backfill();
      final after = await fresh(sample.id!);
      expect(after.preview, '$_p1 $_p2');
      expect(
        after.copyWith(preview: null).toJson(),
        before.copyWith(preview: null).toJson(),
      );
      expect(after.contentHash, hash);
      expect(after.updatedAt, before.updatedAt);
      expect(after.version, 3);
    });

    test('a document row from an older server reads as null', () {
      final json = Document(
        ownerId: owner,
        title: 't',
        contentHash: 'h',
        version: 1,
        pageCount: 1,
        status: 'ready',
        embeddingModel: 'm',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ).toJson()..remove('preview');
      expect(Document.fromJson(json).preview, isNull);
    });
  });
}
