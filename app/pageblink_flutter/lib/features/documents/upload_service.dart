import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../app/local_pdfs.dart';
import '../../client.dart';
import 'pdf_text.dart' as pdf;

/// Every upload limit in one place (research 025 §1, §4).
abstract final class UploadLimits {
  /// Files per batch; the rest are skipped and reported.
  static const maxFiles = 10;

  /// Hard cap on one PDF. The whole file lives in memory (on web twice:
  /// bytes + PDFium WASM copy), and the server has no cap of its own.
  static const maxFileBytes = 50 * 1024 * 1024;

  /// `maxRequestSize` is 524288 bytes in `config/*.yaml` and applies to the
  /// whole `upload` JSON body (extracted text of every page + title, hash).
  /// 480 KiB leaves ~32 KiB for those wrappers and JSON escaping.
  static const maxTextBytes = 480 * 1024;

  /// `{"page":N,"text":""}` per page plus slack.
  static const perPageOverhead = 64;
}

/// What happened to one file.
enum UploadKind {
  added,
  duplicate,
  notPdf,
  tooBig,
  tooMuchText,
  noText,
  unreadable,
  indexFailed,
  permission,

  /// The server answers a denied role check with a bare HTTP 500 (the
  /// server-side `AccessDeniedException` is not serializable), so for a
  /// project upload "server error" and "no permission" look the same.
  serverOrPermission,
  server,
  network,
  timeout,
  unknown,
  cancelled,
}

/// A PDF handed to [uploadPdfs]: platform-neutral name + lazy bytes.
/// `file_picker`'s `PlatformFile` and drop targets' `XFile` both fit:
/// `PickedPdf(name: f.name, size: f.size, read: f.readAsBytes)`.
class PickedPdf {
  const PickedPdf({required this.name, required this.read, this.size});

  PickedPdf.bytes(this.name, Uint8List bytes)
    : read = (() async => bytes),
      size = bytes.length;

  final String name;
  final Future<Uint8List> Function() read;

  /// Known size, if the picker has it; lets oversized files skip the read.
  final int? size;
}

class UploadOutcome {
  const UploadOutcome(
    this.name,
    this.kind, {
    this.document,
    this.pagesFit = 0,
    this.errorCode,
    this.originalStored = true,
  });

  final String name;
  final UploadKind kind;
  final Document? document;

  /// [UploadKind.tooMuchText]: how many leading pages still fit.
  final int pagesFit;

  /// [UploadKind.indexFailed]: the server's `lastError` code.
  final String? errorCode;
  final bool originalStored;

  bool get isFailure => switch (kind) {
    UploadKind.added || UploadKind.duplicate || UploadKind.cancelled => false,
    _ => true,
  };
}

class UploadReport {
  const UploadReport(this.outcomes, {this.skippedOverLimit = 0});

  final List<UploadOutcome> outcomes;
  final int skippedOverLimit;

  int _n(bool Function(UploadOutcome) test) => outcomes.where(test).length;
  int get added => _n((o) => o.kind == UploadKind.added);
  int get duplicates => _n((o) => o.kind == UploadKind.duplicate);
  int get failed => _n((o) => o.isFailure);
  int get cancelled => _n((o) => o.kind == UploadKind.cancelled);
  int get originalsSkipped => _n((o) => !o.originalStored);
}

enum UploadStage { reading, indexing, storing }

/// Sent before each file and stage. [index] is 1-based.
class UploadProgress {
  const UploadProgress(
    this.index,
    this.total,
    this.name,
    this.stage, {
    this.pages = 0,
  });

  final int index;
  final int total;
  final String name;
  final UploadStage stage;
  final int pages;
}

/// Stops the queue before the next file; the running file finishes (it is a
/// server request that cannot be aborted).
class UploadCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// The calls the service makes, injectable because `client` is global.
class UploadApi {
  const UploadApi({
    required this.extractPages,
    required this.upload,
    required this.storeOriginal,
  });

  /// Production wiring: pdfrx extraction, the global `client`, local copy +
  /// server original. Call after `initializeClient`.
  factory UploadApi.live() => UploadApi(
    extractPages: pdf.extractPages,
    upload: client.document.upload,
    storeOriginal: _storeOriginalLive,
  );

  final Future<List<PageText>> Function(Uint8List bytes, String name)
  extractPages;
  final Future<Document> Function(
    String title,
    List<PageText> pages,
    String contentHash,
    int? projectId,
  )
  upload;

  /// Keeps the original so citations open on any device. Returns false when
  /// the cloud copy could not be stored (non-fatal).
  final Future<bool> Function(int documentId, Uint8List bytes) storeOriginal;
}

Future<bool> _storeOriginalLive(int documentId, Uint8List bytes) async {
  try {
    await LocalPdfs.save(documentId, bytes);
    final description = await client.document.pdfUploadDescription(documentId);
    final ok = await FileUploader(
      description,
    ).uploadByteData(ByteData.sublistView(bytes));
    if (ok) await client.document.confirmPdfUpload(documentId);
    return ok;
  } catch (e) {
    debugPrint('store original failed: $e');
    return false;
  }
}

// ── Pure helpers ──────────────────────────────────────────────────────────

/// Extension, `%PDF-` header (anywhere in the first KiB, as PDF readers
/// accept) and size. Null means fine.
UploadKind? validatePdf(Uint8List bytes, String name) {
  if (!name.toLowerCase().endsWith('.pdf')) return UploadKind.notPdf;
  if (bytes.length > UploadLimits.maxFileBytes) return UploadKind.tooBig;
  final head = latin1.decode(
    bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
    allowInvalid: true,
  );
  return head.contains('%PDF-') ? null : UploadKind.notPdf;
}

/// Request-body cost of [pages] and how many leading pages fit the limit.
({int bytes, int fittingPages}) textBudget(List<PageText> pages) {
  var total = 0;
  var fit = 0;
  for (final p in pages) {
    // jsonEncode counts quotes and escapes (\n, \", \uXXXX) like the wire.
    total +=
        utf8.encode(jsonEncode(p.text)).length + UploadLimits.perPageOverhead;
    if (total <= UploadLimits.maxTextBytes) fit++;
  }
  return (bytes: total, fittingPages: fit);
}

/// Maps a thrown error to a kind. Unary-call timeouts arrive as
/// `ServerpodClientNetworkException('Request timed out…')` (serverpod_client
/// 4.0.4 `serverpod_client_io.dart`/`_browser.dart`), not `TimeoutException`.
UploadKind classifyUploadError(Object e, {int? projectId}) => switch (e) {
  TimeoutException() => UploadKind.timeout,
  ServerpodClientUnauthorized() ||
  ServerpodClientForbidden() => UploadKind.permission,
  ServerpodClientInternalServerError() =>
    projectId != null ? UploadKind.serverOrPermission : UploadKind.server,
  ServerpodClientNetworkException(:final message) =>
    message.contains('timed out') ? UploadKind.timeout : UploadKind.network,
  ServerpodClientHttpException(:final statusCode) => switch (statusCode) {
    413 => UploadKind.tooMuchText,
    408 || 504 => UploadKind.timeout,
    _ => UploadKind.server,
  },
  _ => UploadKind.unknown,
};

// ── Service ───────────────────────────────────────────────────────────────

/// Uploads [files] one after another (memory, embedding rate limits, simple
/// progress) and never throws: every file gets an [UploadOutcome].
///
/// [existing] is the board as it was before the call; a returned document
/// that is already `ready` in it is reported as [UploadKind.duplicate] (the
/// server hands back the existing row for the same content hash, owner and
/// project without re-indexing) and its original is not uploaded again.
Future<UploadReport> uploadPdfs(
  List<PickedPdf> files, {
  required UploadApi api,
  int? projectId,
  Iterable<Document> existing = const [],
  void Function(UploadProgress progress)? onProgress,
  UploadCancel? cancel,
}) async {
  final batch = files.take(UploadLimits.maxFiles).toList();
  final knownReady = {
    for (final d in existing)
      if (d.status == 'ready' && d.id != null) d.id!,
  };
  final outcomes = <UploadOutcome>[];
  for (var i = 0; i < batch.length; i++) {
    final file = batch[i];
    if (cancel?.isCancelled ?? false) {
      outcomes.add(UploadOutcome(file.name, UploadKind.cancelled));
      continue;
    }
    outcomes.add(
      await _uploadOne(
        file,
        api,
        projectId,
        knownReady,
        (stage, [pages = 0]) => onProgress?.call(
          UploadProgress(i + 1, batch.length, file.name, stage, pages: pages),
        ),
      ),
    );
  }
  return UploadReport(
    outcomes,
    skippedOverLimit: files.length - batch.length,
  );
}

Future<UploadOutcome> _uploadOne(
  PickedPdf file,
  UploadApi api,
  int? projectId,
  Set<int> knownReady,
  void Function(UploadStage stage, [int pages]) progress,
) async {
  UploadOutcome fail(UploadKind kind, {int pagesFit = 0}) =>
      UploadOutcome(file.name, kind, pagesFit: pagesFit);

  progress(UploadStage.reading);
  if ((file.size ?? 0) > UploadLimits.maxFileBytes) {
    return fail(UploadKind.tooBig);
  }
  final Uint8List bytes;
  try {
    bytes = await file.read();
  } catch (e) {
    debugPrint('read ${file.name} failed: $e');
    return fail(UploadKind.unreadable);
  }
  final problem = validatePdf(bytes, file.name);
  if (problem != null) return fail(problem);

  final List<PageText> pages;
  try {
    pages = await api.extractPages(bytes, file.name);
  } catch (e) {
    // Password-protected or damaged.
    debugPrint('extract ${file.name} failed: $e');
    return fail(UploadKind.unreadable);
  }
  // Scans: nothing to index, so don't leave a failed card behind.
  if (pages.every((p) => p.text.trim().isEmpty)) return fail(UploadKind.noText);
  final budget = textBudget(pages);
  if (budget.bytes > UploadLimits.maxTextBytes) {
    return fail(UploadKind.tooMuchText, pagesFit: budget.fittingPages);
  }

  progress(UploadStage.indexing, pages.length);
  final Document document;
  try {
    document = await api.upload(
      file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
      pages,
      pdf.contentHash(bytes),
      projectId,
    );
  } catch (e) {
    debugPrint('upload ${file.name} failed: $e');
    return fail(classifyUploadError(e, projectId: projectId));
  }
  final id = document.id;
  if (id == null) return fail(UploadKind.unknown);
  if (knownReady.contains(id)) {
    return UploadOutcome(file.name, UploadKind.duplicate, document: document);
  }

  progress(UploadStage.storing);
  var stored = false;
  try {
    stored = await api.storeOriginal(id, bytes);
  } catch (e) {
    debugPrint('store original ${file.name} failed: $e');
  }
  if (document.status == 'failed') {
    final code = document.lastError;
    return UploadOutcome(
      file.name,
      code == 'no_text' ? UploadKind.noText : UploadKind.indexFailed,
      document: document,
      errorCode: code,
      originalStored: stored,
    );
  }
  if (document.status == 'ready') knownReady.add(id);
  return UploadOutcome(
    file.name,
    UploadKind.added,
    document: document,
    originalStored: stored,
  );
}

// ── Text ──────────────────────────────────────────────────────────────────

/// Busy-line text for the progress indicator.
String uploadProgressText(L l, UploadProgress p) {
  if (p.total > 1) return l.uploadingOf(p.index, p.total, p.name);
  return switch (p.stage) {
    UploadStage.reading => l.reading(p.name),
    UploadStage.indexing => l.indexingFile(p.name, p.pages),
    UploadStage.storing => l.storingOriginal(p.name),
  };
}

/// Fixed, localized reason for a failed file (raw errors only go to the log).
String uploadReasonText(L l, UploadOutcome o) => switch (o.kind) {
  UploadKind.notPdf => l.uploadNotPdf,
  UploadKind.tooBig => l.uploadTooBig(UploadLimits.maxFileBytes ~/ 1048576),
  UploadKind.tooMuchText => l.uploadTooMuchText(o.pagesFit),
  UploadKind.noText => l.indexingError('no_text'),
  UploadKind.unreadable => l.uploadUnreadable,
  UploadKind.indexFailed =>
    o.errorCode == null ? l.indexingFailed : l.indexingError(o.errorCode),
  UploadKind.permission => l.uploadPermission,
  UploadKind.serverOrPermission => l.uploadServerOrPermission,
  UploadKind.server => l.uploadServer,
  UploadKind.network => l.uploadNetwork,
  UploadKind.timeout => l.uploadTimeout,
  UploadKind.unknown => l.uploadUnknown,
  UploadKind.added || UploadKind.duplicate || UploadKind.cancelled => '',
};

/// One snackbar for the whole batch: "3 added, 1 failed: a.pdf — reason".
String uploadSummary(L l, UploadReport r) {
  final counts = [
    if (r.added > 0) l.uploadAddedCount(r.added),
    if (r.duplicates > 0) l.uploadDuplicateCount(r.duplicates),
    if (r.failed > 0) l.uploadFailedCount(r.failed),
    if (r.cancelled > 0) l.uploadCancelledCount(r.cancelled),
  ];
  final failures = [
    for (final o in r.outcomes)
      if (o.isFailure) '${o.name} — ${uploadReasonText(l, o)}',
  ];
  final lines = [
    if (counts.isNotEmpty)
      counts.join(', ') +
          (failures.isEmpty
              ? ''
              : ': ${failures.take(2).join('; ')}${failures.length > 2 ? '…' : ''}'),
    if (r.originalsSkipped > 0) l.uploadOriginalSkipped(r.originalsSkipped),
    if (r.skippedOverLimit > 0)
      l.uploadOverLimit(r.skippedOverLimit, UploadLimits.maxFiles),
  ];
  return lines.join('\n');
}
