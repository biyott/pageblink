import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'ocr_text.dart';
import 'recovery_backend.dart';

/// The browser engines, from `web/pdf_recovery/` (self-hosted, loaded on first
/// use). Nothing here runs for a PDF that has text.
RecoveryBackend createRecoveryBackend() => _WebBackend();

@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(String tag);
  external _Element get head;
  external String get baseURI;
}

extension type _Element._(JSObject _) implements JSObject {
  external set src(String value);
  external set onload(JSFunction? value);
  external set onerror(JSFunction? value);
  external void appendChild(JSObject child);
  external void remove();
}

extension type _Api._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> loadForms();
  external JSPromise<JSString> readForms(
    JSUint8Array bytes,
    JSArray<JSNumber> pages,
  );
  external JSPromise<JSString> loadOcr(JSFunction onProgress);
  external JSPromise<JSString> ocrPage(
    JSUint8Array bgra,
    int width,
    int height,
    int dpi,
  );
  external void abort();
  external void dispose();
}

/// Where the page script lives, relative to the app's base href.
const _script = 'pdf_recovery/recovery.js';

class _WebBackend implements RecoveryBackend {
  Future<_Api>? _loading;

  @override
  bool get isSupported => true;

  _Api? get _loaded {
    final o = globalContext['PageBlinkRecovery'];
    return o.isA<JSObject>() ? _Api._(o as JSObject) : null;
  }

  /// Adds the page script once; retries a failed download a few times.
  Future<_Api> _api() => _loading ??= _inject().catchError((Object e) {
    _loading = null;
    throw e;
  });

  Future<_Api> _inject() async {
    final existing = _loaded;
    if (existing != null) return existing;
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      final done = Completer<void>();
      final el = _document.createElement('script');
      el.src = Uri.parse(_document.baseURI).resolve(_script).toString();
      el.onload = (() => done.complete()).toJS;
      el.onerror = (() {
        el.remove();
        done.completeError(StateError('could not load $_script'));
      }).toJS;
      _document.head.appendChild(el);
      try {
        await done.future;
        final api = _loaded;
        if (api != null) return api;
        last = StateError('$_script did not define PageBlinkRecovery');
      } catch (e) {
        last = e;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 400 * (attempt + 1) * (attempt + 1)),
      );
    }
    throw last!;
  }

  @override
  Future<void> prepareForms() async => (await _api()).loadForms().toDart;

  @override
  Future<Map<int, List<String>>> readForms(
    Uint8List pdf,
    List<int> pages,
  ) async {
    final api = await _api();
    final json = await api
        .readForms(pdf.toJS, [for (final p in pages) p.toJS].toJS)
        .toDart;
    final out = <int, List<String>>{};
    for (final e in jsonDecode(json.toDart) as List) {
      final values = [for (final v in (e['values'] as List)) '$v'];
      if (values.isNotEmpty) out[(e['page'] as num).toInt()] = values;
    }
    return out;
  }

  @override
  Future<void> prepareOcr(void Function(double fraction) onProgress) async {
    final api = await _api();
    await api.loadOcr(((JSNumber f) => onProgress(f.toDartDouble)).toJS).toDart;
  }

  @override
  Future<OcrPageData> ocrPage(
    Uint8List bgra,
    int width,
    int height,
    int dpi,
  ) async {
    final api = await _api();
    final json = await api.ocrPage(bgra.toJS, width, height, dpi).toDart;
    return OcrPageData.fromJson(json.toDart);
  }

  @override
  void abort() => _loaded?.abort();

  @override
  void dispose() => _loaded?.dispose();
}
