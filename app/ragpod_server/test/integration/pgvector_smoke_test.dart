import 'package:ragpod_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// G1: pgvector works on the local (embedded) database.
void main() {
  withServerpod('Given pgvector-backed DocChunk', (sessionBuilder, _) {
    test(
      'when storing vectors then cosine search returns nearest first',
      () async {
        final session = sessionBuilder.build();
        final owner = UuidValue.fromString(
          '00000000-0000-4000-8000-000000000001',
        );

        List<double> unit(int hot) =>
            List.generate(768, (i) => i == hot ? 1.0 : 0.0);

        for (var i = 0; i < 3; i++) {
          await DocChunk.db.insertRow(
            session,
            DocChunk(
              documentId: 1,
              ownerId: owner,
              page: i + 1,
              ordinal: i,
              text: 'chunk $i',
              contentHash: 'h$i',
              embedding: Vector(unit(i)),
            ),
          );
        }

        final query = Vector(unit(1));
        final hits = await DocChunk.db.find(
          session,
          orderBy: (t) => t.embedding.distanceCosine(query),
          limit: 2,
        );

        expect(hits.first.text, 'chunk 1');
        expect(hits, hasLength(2));
      },
    );
  });
}
