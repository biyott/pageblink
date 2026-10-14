import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../client.dart';

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

  /// Local copy first, then the server original (short-lived signed URL).
  static Future<Uint8List?> fetch(int documentId) async {
    final local = await load(documentId);
    if (local != null) return local;
    try {
      final url = await client.document.pdfUrl(documentId);
      if (url == null) return null;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      await save(documentId, response.bodyBytes);
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> load(int documentId) async {
    final cached = _memory[documentId];
    if (cached != null || kIsWeb) return cached;
    final file = await _file(documentId);
    if (!await file.exists()) return null;
    return _memory[documentId] = await file.readAsBytes();
  }
}
