import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/services/acl.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Metadata only: no embedding or LLM is involved, so no keys are needed.
void main() {
  withServerpod('Given a note color', (sb, endpoints) {
    late UuidValue ownerId;
    late TestSessionBuilder owner;

    TestSessionBuilder as(UuidValue id) => sb.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        id.toString(),
        {},
      ),
    );

    final stamp = DateTime.utc(2026, 10, 1);

    Future<Document> doc({
      String kind = 'note',
      int? projectId,
      int? colorIndex,
    }) => Document.db.insertRow(
      sb.build(),
      Document(
        ownerId: ownerId,
        projectId: projectId,
        kind: kind,
        title: 'T',
        body: kind == 'note' ? 'body' : null,
        contentHash: const Uuid().v4(),
        version: 3,
        pageCount: 1,
        status: 'ready',
        embeddingModel: 'fake/embed#c2',
        colorIndex: colorIndex,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );

    Future<Document> fresh(Document d) async =>
        (await Document.db.findById(sb.build(), d.id!))!;

    setUp(() {
      ownerId = const Uuid().v4obj();
      owner = as(ownerId);
    });

    test('set, change and clear; the metadata stays untouched', () async {
      final d = await doc();
      for (final c in [0, 5, 7, 8]) {
        final r = await endpoints.document.setNoteColor(owner, d.id!, c);
        expect(r.colorIndex, c);
        final row = await fresh(d);
        expect(row.colorIndex, c);
        expect(row.updatedAt, stamp);
        expect(row.version, 3);
        expect(row.status, 'ready');
        expect(row.embeddingModel, 'fake/embed#c2');
        expect(row.body, 'body');
      }
      final cleared = await endpoints.document.setNoteColor(owner, d.id!, null);
      expect(cleared.colorIndex, isNull);
      expect((await fresh(d)).colorIndex, isNull);
    });

    test('out-of-range values are rejected and nothing changes', () async {
      final d = await doc(colorIndex: 2);
      for (final bad in [-1, 9, 100]) {
        await expectLater(
          endpoints.document.setNoteColor(owner, d.id!, bad),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect((await fresh(d)).colorIndex, 2);
    });

    test('someone else cannot color a personal note', () async {
      final d = await doc(colorIndex: 1);
      final other = as(const Uuid().v4obj());
      await expectLater(
        endpoints.document.setNoteColor(other, d.id!, 4),
        throwsA(isA<AccessDeniedException>()),
      );
      expect((await fresh(d)).colorIndex, 1);
    });

    test('PDFs and missing documents are rejected', () async {
      final pdf = await doc(kind: 'pdf');
      await expectLater(
        endpoints.document.setNoteColor(owner, pdf.id!, 3),
        throwsA(isA<ArgumentError>()),
      );
      expect((await fresh(pdf)).colorIndex, isNull);
      await expectLater(
        endpoints.document.setNoteColor(owner, -1, 3),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('project notes: editors may color, viewers may not', () async {
      const projectId = 987001;
      final editorId = const Uuid().v4obj();
      final viewerId = const Uuid().v4obj();
      for (final (id, role) in [
        (ownerId, 'owner'),
        (editorId, 'editor'),
        (viewerId, 'viewer'),
      ]) {
        await ProjectMember.db.insertRow(
          sb.build(),
          ProjectMember(projectId: projectId, userId: id, role: role),
        );
      }
      final d = await doc(projectId: projectId);

      final r = await endpoints.document.setNoteColor(as(editorId), d.id!, 6);
      expect(r.colorIndex, 6);
      await expectLater(
        endpoints.document.setNoteColor(as(viewerId), d.id!, 2),
        throwsA(isA<AccessDeniedException>()),
      );
      expect((await fresh(d)).colorIndex, 6);
    });
  });
}
