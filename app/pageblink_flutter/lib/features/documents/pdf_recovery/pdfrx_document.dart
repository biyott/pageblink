import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'recovery_backend.dart';
import 'recovery_models.dart';

/// Opens [bytes] with the app's PDF engine (PDFium, the same one that reads the
/// text layer), starting the engine first when nothing has yet.
Future<RecoveryDocument> openWithPdfrx(Uint8List bytes, String name) async {
  await pdfrxFlutterInitialize();
  return _PdfrxDocument(await PdfDocument.openData(bytes, sourceName: name));
}

class _PdfrxDocument implements RecoveryDocument {
  _PdfrxDocument(this._doc);

  final PdfDocument _doc;

  @override
  int get pageCount => _doc.pages.length;

  @override
  Future<String> pageText(int page) async =>
      (await _doc.pages[page - 1].loadStructuredText()).fullText;

  @override
  Future<RenderedPage?> render(int page) async {
    final p = _doc.pages[page - 1];
    final longEdge = p.width > p.height ? p.width : p.height;
    if (longEdge <= 0) return null;
    final scale = kRecoveryRenderLongEdge / longEdge;
    // Form field values are drawn by the default mode, which is what lets
    // recognition read a form whose text is not in the text layer.
    final image = await p.render(
      fullWidth: p.width * scale,
      fullHeight: p.height * scale,
      backgroundColor: 0xffffffff,
      annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
    );
    if (image == null) return null;
    try {
      // Pixels per inch of the paper: the page is `p.width` points wide.
      final dpi = (image.width / (p.width / 72)).round();
      return RenderedPage(
        Uint8List.fromList(image.pixels),
        image.width,
        image.height,
        dpi,
      );
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> dispose() => _doc.dispose();
}
