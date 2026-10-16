import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_recovery/recovery_merge.dart';

export 'pdf_recovery/recovery_merge.dart' show RecoveryHook;

/// Loads PDFium (WASM on web) once. pdfrx only does this itself when a
/// viewer opens; without it `PdfDocument.openData` hits the "not
/// initialized" mock on web. Throws when the engine cannot start; a failed
/// attempt is retried by the next call.
Future<void> ensurePdfEngine() => pdfrxFlutterInitialize();

/// Extracts text page by page on the device (ADR 003), so every chunk the
/// server makes knows its page number.
///
/// With a [recovery] hook, pages that have no readable text (scans, form-only
/// pages) are then read on the device too (form values, then OCR) and come back
/// with `PageText.source` set. Without it nothing changes: no recovery code or
/// engine is loaded.
Future<List<PageText>> extractPages(
  Uint8List bytes,
  String name, {
  RecoveryHook? recovery,
}) async {
  await ensurePdfEngine();
  final document = await PdfDocument.openData(bytes, sourceName: name);
  final List<PageText> pages;
  try {
    pages = <PageText>[];
    for (final page in document.pages) {
      final text = await page.loadStructuredText();
      pages.add(PageText(page: page.pageNumber, text: text.fullText));
    }
  } finally {
    await document.dispose();
  }
  return recovery == null ? pages : recoverPages(pages, bytes, name, recovery);
}

String contentHash(Uint8List bytes) => sha256.convert(bytes).toString();
