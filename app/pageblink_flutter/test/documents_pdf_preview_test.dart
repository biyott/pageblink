import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';

const _ko = '대한민국 헌법은 국가의 최고 규범으로서 국민의 기본권을 보장한다. ';
const _en = 'The quick brown fox jumps over the lazy dog while reading. ';

Document _pdf({
  String? preview,
  String status = 'ready',
  String? lastError,
  int id = 1,
  String title = 'Report',
}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: 'pdf',
  title: title,
  preview: preview,
  contentHash: 'h$id',
  version: 1,
  pageCount: 3,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pumpCard(
  WidgetTester t,
  Document d, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool reindexing = false,
}) => t.pumpWidget(
  MaterialApp(
    theme: buildPbTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          height: 250,
          child: DocumentCard(d, const [], reindexing: reindexing),
        ),
      ),
    ),
  ),
);

// The three skeleton bars are the only FractionallySizedBox on a card.
final _bars = find.byType(FractionallySizedBox);

void main() {
  testWidgets('ready PDF shows its preview like a note body', (t) async {
    await _pumpCard(t, _pdf(preview: 'Quarterly results overview…'));
    final text = t.widget<Text>(find.text('Quarterly results overview…'));
    expect(text.style?.fontSize, 13);
    expect(text.style?.height, 1.5);
    expect(_bars, findsNothing);
  });

  testWidgets('null preview (backfill pending) shows no text', (t) async {
    await _pumpCard(t, _pdf());
    expect(_bars, findsNothing);
  });

  testWidgets("'' preview (unreadable) leaves the body empty", (t) async {
    await _pumpCard(t, _pdf(preview: ''));
    expect(_bars, findsNothing);
  });

  for (final status in ['uploaded', 'indexing']) {
    testWidgets('$status: skeleton wins over the preview', (t) async {
      await _pumpCard(t, _pdf(preview: 'Old preview', status: status));
      expect(find.text('Old preview'), findsNothing);
      expect(_bars, findsNWidgets(3));
    });
  }

  testWidgets('reindexing ready PDF shows the skeleton, not the preview', (
    t,
  ) async {
    await _pumpCard(t, _pdf(preview: 'Old preview'), reindexing: true);
    expect(find.text('Old preview'), findsNothing);
    expect(_bars, findsNWidgets(3));
  });

  testWidgets('failed: the reason wins over the preview', (t) async {
    await _pumpCard(
      t,
      _pdf(preview: 'Old preview', status: 'failed', lastError: 'boom'),
    );
    expect(find.text('Old preview'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final (name, sample) in [('ko', _ko), ('en', _en)]) {
      testWidgets('long $name preview fits 280x250 at 2x text '
          '(${brightness.name})', (t) async {
        final long = '${sample * 8}…';
        await _pumpCard(
          t,
          _pdf(preview: long),
          brightness: brightness,
          textScale: 2,
        );
        expect(t.takeException(), isNull);
        // Same style as a note body: theme bodySmall ink.
        expect(
          t.widget<Text>(find.text(long)).style?.color,
          buildPbTheme(brightness).textTheme.bodySmall?.color,
        );
      });
    }
  }

  testWidgets('search finds a PDF by preview (NFC, any case)', (t) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // '부산 여행' stored decomposed (NFD jamo) in the preview.
    const nfd = '부산 여행';
    final docs = [
      _pdf(id: 1, title: 'Alpha', preview: '$nfd Quarterly Results'),
      _pdf(id: 2, title: 'Beta', preview: 'nothing here'),
      _pdf(id: 3, title: 'Gamma'),
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

    await search('부산 여행');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Gamma'), findsNothing);

    await search('QUARTERLY');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });
}
