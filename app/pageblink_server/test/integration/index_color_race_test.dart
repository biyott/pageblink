import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/services/rag_services.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'reindex_test.dart' show FakeEmbedder;
import 'test_tools/serverpod_test_tools.dart';

/// Indexing takes seconds; a color picked meanwhile must survive the
/// final write of the index result. The embedder's `whileBusy` hook is
/// that window.
void main() {
  final embedder = FakeEmbedder();

  withServerpod('Given a note color picked while indexing', (sb, endpoints) {
    late UuidValue ownerId;
    late TestSessionBuilder owner;

    Future<Document> fresh(int id) async =>
        (await Document.db.findById(sb.build(), id))!;

    setUp(() {
      ownerId = const Uuid().v4obj();
      owner = sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          ownerId.toString(),
          {},
        ),
      );
      RagServices.debugEmbedding = embedder;
      embedder
        ..failTimes = 0
        ..whileBusy = null;
    });

    tearDown(() => RagServices.debugEmbedding = null);

    Future<Document> storedNote({String status = 'ready'}) {
      final stamp = DateTime.utc(2026, 10, 1);
      return Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: ownerId,
          kind: 'note',
          title: 'T',
          body: 'first line\nsecond line',
          contentHash: const Uuid().v4(),
          version: 1,
          pageCount: 1,
          status: status,
          embeddingModel: 'fake/embed#c1',
          colorIndex: 3,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }

    test('a new note keeps the color set during the first save', () async {
      // The id is unknown until the insert, so pick it up from the row.
      embedder.whileBusy = () async {
        final row = (await Document.db.find(
          sb.build(),
          where: (t) => t.ownerId.equals(ownerId),
        )).single;
        await endpoints.document.setNoteColor(owner, row.id!, 4);
      };
      final saved = await endpoints.document.saveNote(
        owner,
        null,
        'T',
        'one line\nanother line',
        null,
      );
      expect(saved.status, 'ready');
      expect(saved.colorIndex, 4);
      expect((await fresh(saved.id!)).colorIndex, 4);
    });

    test('editing a note keeps the color set while it re-indexes', () async {
      final d = await storedNote();
      embedder.whileBusy = () async {
        await endpoints.document.setNoteColor(owner, d.id!, 5);
      };
      final saved = await endpoints.document.saveNote(
        owner,
        d.id,
        'T',
        'edited first line\nsecond line',
        null,
      );
      expect(saved.status, 'ready');
      expect(saved.version, 2);
      expect(saved.colorIndex, 5);
      expect((await fresh(d.id!)).colorIndex, 5);
    });

    test('a failed index result keeps the color too', () async {
      final d = await storedNote();
      embedder.whileBusy = () async {
        await endpoints.document.setNoteColor(owner, d.id!, 2);
        throw StateError('provider died');
      };
      final saved = await endpoints.document.saveNote(
        owner,
        d.id,
        'T',
        'edited first line\nsecond line',
        null,
      );
      expect(saved.status, 'failed');
      expect(saved.colorIndex, 2);
      expect((await fresh(d.id!)).colorIndex, 2);
    });

    test('reindex keeps the color set while it runs', () async {
      final d = await storedNote(status: 'failed');
      embedder.whileBusy = () async {
        await endpoints.document.setNoteColor(owner, d.id!, 6);
      };
      final r = await endpoints.document.reindex(owner, d.id!);
      expect(r.status, 'ready');
      expect(r.colorIndex, 6);
      expect((await fresh(d.id!)).colorIndex, 6);
    });
  });
}
