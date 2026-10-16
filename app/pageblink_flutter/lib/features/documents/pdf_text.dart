import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pdfrx/pdfrx.dart';

/// Loads PDFium (WASM on web) once. pdfrx only does this itself when a
/// viewer opens; without it `PdfDocument.openData` hits the "not
/// initialized" mock on web. Throws when the engine cannot start; a failed
/// attempt is retried by the next call.
Future<void> ensurePdfEngine() => pdfrxFlutterInitialize();

/// Extracts text page by page on the device (ADR 003), so every chunk the
/// server makes knows its page number.
Future<List<PageText>> extractPages(Uint8List bytes, String name) async {
  await ensurePdfEngine();
  final document = await PdfDocument.openData(bytes, sourceName: name);
  try {
    final pages = <PageText>[];
    for (final page in document.pages) {
      final text = await page.loadStructuredText();
      pages.add(PageText(page: page.pageNumber, text: text.fullText));
    }
    return pages;
  } finally {
    await document.dispose();
  }
}

String contentHash(Uint8List bytes) => sha256.convert(bytes).toString();
