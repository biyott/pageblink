import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the original PDFs this device uploaded, so citations can open the
/// exact page offline. (Server-side originals come later via file storage.)
class LocalPdfs {
  static final _memory = <int, Uint8List>{};

  static Future<File> _file(int documentId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pageblink/pdfs/$documentId.pdf');
  }

  static Future<void> save(int documentId, Uint8List bytes) async {
    _memory[documentId] = bytes;
    if (kIsWeb) return;
    final file = await _file(documentId);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  static Future<Uint8List?> load(int documentId) async {
    final cached = _memory[documentId];
    if (cached != null || kIsWeb) return cached;
    final file = await _file(documentId);
    if (!await file.exists()) return null;
    return _memory[documentId] = await file.readAsBytes();
  }
}
