import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

// '부산 여행 계획' / '서울 맛집' as macOS file names store them (NFD jamo).
const _busanNfd =
    '\u1107\u116E\u1109\u1161\u11AB \u110B\u1167\u1112\u1162\u11BC '
    '\u1100\u1168\u1112\u116C\u11A8';
const _seoulNfd =
    '\u1109\u1165\u110B\u116E\u11AF \u1106\u1161\u11BA\u110C\u1175\u11B8';

Document _doc(int id, String title, {String? body}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: body == null ? 'pdf' : 'note',
  title: title,
  body: body,
  contentHash: 'h$id',
  version: 1,
  pageCount: 1,
  status: 'ready',
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('NFC query finds NFD titles, bodies and ignores case', (t) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final docs = [
      _doc(1, _busanNfd),
      _doc(2, _seoulNfd),
      _doc(3, 'Memo', body: '$_busanNfd 메모 Hello'),
    ];
    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: DocumentsScreen(
          projects: const [],
          boardApi: BoardApi(
            list: () async => docs,
            delete: (id) async {},
            setNoteColor: (id, c) async => throw UnimplementedError(),
            reindex: (id) async => docs.first,
          ),
          pickPdfs: () async => const [],
        ),
      ),
    );
    await t.pumpAndSettle();

    Future<void> search(String q) async {
      await t.enterText(find.byType(TextField).first, q);
      await t.pumpAndSettle();
    }

    expect(find.text(_busanNfd), findsOneWidget);
    expect(find.text(_seoulNfd), findsOneWidget);

    await search('부산 여행'); // NFC, title match (and note body match)
    expect(find.text(_busanNfd), findsOneWidget);
    expect(find.text(_seoulNfd), findsNothing);
    expect(find.text('Memo'), findsOneWidget);

    await search('맛집');
    expect(find.text(_seoulNfd), findsOneWidget);
    expect(find.text(_busanNfd), findsNothing);

    await search('HELLO'); // body, case-insensitive
    expect(find.text('Memo'), findsOneWidget);
    expect(find.text(_busanNfd), findsNothing);
  });
}
