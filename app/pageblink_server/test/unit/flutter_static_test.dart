import 'dart:io';

import 'package:pageblink_server/src/generated/endpoints.dart';
import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/web/flutter_cache_control.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The Flutter app route exactly as `server.dart` mounts it, over a folder laid
/// out like the build output with the recovery engines in it. Serves on a free
/// loopback port without database (like Serverpod's own web server tests).
void main() {
  late Directory dir;
  late Serverpod pod;
  late HttpClient client;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('pageblink_static_');
    File('${dir.path}/index.html').writeAsStringSync('<html>app</html>');
    final vendor = Directory('${dir.path}/pdf_recovery/vendor')
      ..createSync(recursive: true);
    Directory('${vendor.path}/tesseract-7.0.0').createSync();
    Directory('${vendor.path}/tessdata_fast-4.1.0').createSync();
    Directory('${vendor.path}/pdfjs-6.4.299').createSync();
    for (final f in [
      'tesseract-7.0.0/tesseract.min.js',
      'tesseract-7.0.0/tesseract-core-simd-lstm.wasm.js',
      'tessdata_fast-4.1.0/kor.traineddata.gz',
      'pdfjs-6.4.299/pdf.min.mjs',
      'pdfjs-6.4.299/pdf.worker.min.mjs',
    ]) {
      File('${vendor.path}/$f').writeAsBytesSync(List.filled(64, 7));
    }
    File('${dir.path}/pdf_recovery/recovery.js').writeAsStringSync('//');
    File(
      '${dir.path}/pdf_recovery/THIRD_PARTY_LICENSES',
    ).writeAsStringSync('x');
    File('${dir.path}/main.dart.js').writeAsStringSync('//');
    File('${dir.path}/canvaskit.wasm').writeAsBytesSync([0, 97, 115, 109]);

    final cfg = ServerConfig(
      port: 0,
      publicScheme: 'http',
      publicHost: 'localhost',
      publicPort: 0,
    );
    pod = Serverpod(
      [],
      Protocol(),
      Endpoints(),
      config: ServerpodConfig(apiServer: cfg, webServer: cfg),
    );
    pod.webServer.addRoute(
      FlutterRoute(
        dir,
        enableWasmHeaders: false,
        cacheControlFactory: flutterCacheControl,
      ),
      '/',
    );
    await pod.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await pod.shutdown(exitProcess: false);
    dir.deleteSync(recursive: true);
  });

  Future<({int status, ContentType? type, String? cache, int length})> get(
    String path,
  ) async {
    final rq = await client.getUrl(
      Uri.parse('http://localhost:${pod.webServer.port}$path'),
    );
    final res = await rq.close();
    var n = 0;
    await res.forEach((c) => n += c.length);
    return (
      status: res.statusCode,
      type: res.headers.contentType,
      cache: res.headers.value('cache-control'),
      length: n,
    );
  }

  test('the engine files are served with types the browser accepts', () async {
    const base = '/pdf_recovery/vendor';
    final js = await get('$base/tesseract-7.0.0/tesseract.min.js');
    expect(js.status, 200);
    expect(
      js.type?.mimeType,
      anyOf('text/javascript', 'application/javascript'),
    );
    final core = await get(
      '$base/tesseract-7.0.0/tesseract-core-simd-lstm.wasm.js',
    );
    expect(
      core.type?.mimeType,
      anyOf('text/javascript', 'application/javascript'),
    );
    // dynamic import() and a module worker need a JavaScript type for .mjs
    final mjs = await get('$base/pdfjs-6.4.299/pdf.min.mjs');
    expect(mjs.status, 200);
    expect(
      mjs.type?.mimeType,
      anyOf('text/javascript', 'application/javascript'),
    );
    final worker = await get('$base/pdfjs-6.4.299/pdf.worker.min.mjs');
    expect(
      worker.type?.mimeType,
      anyOf('text/javascript', 'application/javascript'),
    );
    // Tesseract.js gunzips this itself, so any binary type does
    final lang = await get('$base/tessdata_fast-4.1.0/kor.traineddata.gz');
    expect(lang.status, 200);
    expect(lang.length, 64);
    expect((await get('/canvaskit.wasm')).type?.mimeType, 'application/wasm');
  });

  test('versioned engine files cache for a year, the app revalidates', () async {
    final lang = await get(
      '/pdf_recovery/vendor/tessdata_fast-4.1.0/kor.traineddata.gz',
    );
    expect(
      lang.cache,
      allOf(
        contains('public'),
        contains('immutable'),
        contains('max-age=31536000'),
      ),
    );
    final core = await get(
      '/pdf_recovery/vendor/tesseract-7.0.0/tesseract-core-simd-lstm.wasm.js',
    );
    expect(core.cache, contains('immutable'));
    // the page script and the app are not versioned by name: always revalidated
    for (final p in [
      '/pdf_recovery/recovery.js',
      '/main.dart.js',
      '/canvaskit.wasm',
      '/index.html',
    ]) {
      final r = await get(p);
      expect(
        r.cache,
        allOf(contains('private'), contains('no-cache')),
        reason: p,
      );
    }
  });

  test(
    'a missing engine file is not a 404: the app index comes back',
    () async {
      // Why recovery.js checks what it loads: FlutterRoute answers every
      // unknown path with index.html and status 200.
      final r = await get(
        '/pdf_recovery/vendor/tessdata_fast-4.1.0/nope.traineddata.gz',
      );
      expect(r.status, 200);
      expect(r.type?.mimeType, 'text/html');
    },
  );
}
