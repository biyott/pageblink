import 'dart:typed_data';

import 'ocr_text.dart';
import 'recovery_backend.dart';

/// Where the browser engines do not exist (tests, desktop, mobile builds).
RecoveryBackend createRecoveryBackend() => _UnsupportedBackend();

class _UnsupportedBackend implements RecoveryBackend {
  @override
  bool get isSupported => false;

  Never _no() => throw UnsupportedError('PDF recovery needs the web build');

  @override
  Future<void> prepareForms() async => _no();

  @override
  Future<Map<int, List<String>>> readForms(Uint8List pdf, List<int> pages) =>
      _no();

  @override
  Future<void> prepareOcr(void Function(double fraction) onProgress) async =>
      _no();

  @override
  Future<OcrPageData> ocrPage(
    Uint8List bgra,
    int width,
    int height,
    int dpi,
  ) => _no();

  @override
  void abort() {}

  @override
  void dispose() {}
}
