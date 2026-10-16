import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// Folder of the self-hosted recovery engines (`web/pdf_recovery/vendor/` in
/// the Flutter app). Every folder under it carries its version in its name
/// (`tesseract-7.0.0`, `pdfjs-6.4.299`, `tessdata_fast-4.1.0`), so a file never
/// changes under the same URL.
const vendorPath = '/pdf_recovery/vendor/';

const _vendorMaxAge = 31536000; // one year
const _envVariable = 'SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL';

/// Cache headers of the Flutter app route.
///
/// Versioned vendor files may be cached for a year: the OCR engine is about
/// 7 MB and must not be downloaded again at every visit. Everything else
/// keeps Serverpod's default for the app (`private, no-cache`, revalidated with
/// the ETag) or the `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` override, since
/// the build output uses fixed file names.
CacheControlHeader? flutterCacheControl(Request request, FileInfo fileInfo) {
  if (request.url.path.contains(vendorPath)) {
    return CacheControlHeader(
      publicCache: true,
      immutable: true,
      maxAge: _vendorMaxAge,
    );
  }
  final override = Platform.environment[_envVariable];
  return override == null
      ? CacheControlHeader(privateCache: true, noCache: true)
      : CacheControlHeader.parseStrict([override]);
}
