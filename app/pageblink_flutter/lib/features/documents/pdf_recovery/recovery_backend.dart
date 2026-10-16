import 'dart:typed_data';

import 'ocr_text.dart';

/// The browser side of recovery: form values (pdf.js) and OCR (Tesseract.js),
/// loaded on first use. A fake stands in for it in tests.
abstract class RecoveryBackend {
  /// False where the engines cannot run (not a web build).
  bool get isSupported;

  /// Loads the form reader. Throws when it cannot be loaded.
  Future<void> prepareForms();

  /// Non-empty text and choice field values per page (1-based). Pages without
  /// values or that could not be read are absent.
  Future<Map<int, List<String>>> readForms(Uint8List pdf, List<int> pages);

  /// Downloads and starts the OCR engine; [onProgress] gets 0..1. Does nothing
  /// when it is already running. Throws when it cannot start.
  Future<void> prepareOcr(void Function(double fraction) onProgress);

  /// Recognizes one rendered page (BGRA8888, [width] x [height], drawn at
  /// [dpi] dots per inch of the paper). Throws on failure; a message containing
  /// `timeout` means the page was given up on.
  Future<OcrPageData> ocrPage(Uint8List bgra, int width, int height, int dpi);

  /// Interrupts the work in flight; the engine restarts on the next prepare.
  void abort();

  /// Frees the engine's workers and memory.
  void dispose();
}

/// One page drawn for recognition.
class RenderedPage {
  const RenderedPage(this.bgra, this.width, this.height, this.dpi);

  final Uint8List bgra;
  final int width;
  final int height;

  /// Pixels per inch of the paper page: the recognizer scales its expectations
  /// by it (measured: stating it right matters for poor scans).
  final int dpi;
}

/// The PDF as recovery needs it: the text layer to judge pages by, and
/// rendered pages to read.
abstract class RecoveryDocument {
  int get pageCount;

  /// The page's own text (empty for a scan).
  Future<String> pageText(int page);

  /// The page drawn at about 150 dpi on white, form fields included; null when
  /// it cannot be drawn.
  Future<RenderedPage?> render(int page);

  Future<void> dispose();
}

typedef RecoveryDocumentOpener =
    Future<RecoveryDocument> Function(Uint8List bytes, String name);
