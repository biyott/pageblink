import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';

void main() {
  testWidgets('every picked PDF is uploaded and one summary snackbar shows', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final uploaded = <String>[];
    var nextId = 1;
    final api = UploadApi(
      extractPages: (bytes, name) async => [PageText(page: 1, text: name)],
      upload: (title, pages, hash, projectId) async {
        uploaded.add(title);
        return Document(
          id: nextId++,
          ownerId: UuidValue.fromString(
            '00000000-0000-4000-8000-000000000001',
          ),
          title: title,
          contentHash: hash,
          version: 1,
          pageCount: 1,
          status: 'ready',
          embeddingModel: 'm',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
      },
      storeOriginal: (id, bytes) async => true,
    );
    Future<List<PickedPdf>> pick() async => [
      for (final n in ['a.pdf', 'b.pdf', 'c.pdf'])
        PickedPdf.bytes(n, Uint8List.fromList(utf8.encode('%PDF-1.7 $n'))),
    ];

    await t.pumpWidget(
      MaterialApp(
        theme: buildPbTheme(Brightness.light),
        home: DocumentsScreen(
          projects: const [],
          pickPdfs: pick,
          uploadApi: api,
        ),
      ),
    );
    await t.pump();

    await t.tap(find.byTooltip('Upload PDF'));
    await t.pumpAndSettle();
    await t.tap(find.text('My cloud'));
    await t.pumpAndSettle();

    expect(uploaded, ['a', 'b', 'c']);
    expect(find.text('3 added'), findsOneWidget);
  });
}
