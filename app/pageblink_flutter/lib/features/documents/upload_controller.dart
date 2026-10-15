import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/open_item_controller.dart' show boardRefresh;
import '../../client.dart';
import 'upload_service.dart';

// ── Drop state machine ──────────────────────────────────────────────────

enum DropPhase { idle, armed, over }

/// Idle → Armed (a drag is over the window) → Over (over the pane).
///
/// Chrome sends a bogus `dragleave` when the pointer crosses the `<input>`
/// under a focused TextField (research 025), so leaving only counts after
/// [exitDelay] without a new `dragover`. And a drag that ends silently
/// (Esc, left the window) never sends `exited`, so [staleAfter] without any
/// signal also ends it. A real drag fires `dragover` every ~50 ms.
class DropMachine {
  DropMachine({
    this.exitDelay = const Duration(milliseconds: 150),
    this.staleAfter = const Duration(milliseconds: 400),
  });

  final Duration exitDelay;
  final Duration staleAfter;
  final phase = ValueNotifier<DropPhase>(DropPhase.idle);

  Timer? _exit;
  Timer? _stale;

  /// Drag entered or moved. [inZone]: the pointer is over the drop pane.
  void hover({required bool inZone}) {
    _exit?.cancel();
    _exit = null;
    phase.value = inZone ? DropPhase.over : DropPhase.armed;
    _stale?.cancel();
    _stale = Timer(staleAfter, reset);
  }

  /// The drag left (possibly bogus): ends after [exitDelay] unless it moves.
  void leave() {
    if (phase.value == DropPhase.idle) return;
    _exit ??= Timer(exitDelay, reset);
  }

  void reset() {
    _exit?.cancel();
    _stale?.cancel();
    _exit = _stale = null;
    phase.value = DropPhase.idle;
  }

  void dispose() {
    _exit?.cancel();
    _stale?.cancel();
    phase.dispose();
  }
}

// ── Upload queue ────────────────────────────────────────────────────────

enum RowState { waiting, reading, indexing, storing, done, failed, cancelled }

/// A dropped item that is not a PDF (shown as a row, never read).
class RejectedFile {
  const RejectedFile(this.name, {this.isFolder = false});
  final String name;
  final bool isFolder;

  /// `.docx`; empty for folders and names without an extension.
  String get ext {
    if (isFolder) return '';
    final dot = name.lastIndexOf('.');
    return dot <= 0 || dot == name.length - 1
        ? ''
        : name.substring(dot).toLowerCase();
  }
}

class _Batch {
  _Batch(this.skippedOverLimit);
  final int skippedOverLimit;
  final rows = <TrayRow>[];
  bool reported = false;
}

/// One file in the tray.
class TrayRow {
  TrayRow._(this.name, this.file, this.projectId, this._batch);

  final String name;
  final PickedPdf? file;
  final int? projectId;
  _Batch _batch;

  RowState state = RowState.waiting;
  int pages = 0;
  UploadOutcome? outcome;
  Document? document;
  UploadCancel cancel = UploadCancel();

  /// Set for non-PDF drops.
  RejectedFile? rejected;

  bool get active =>
      state == RowState.waiting ||
      state == RowState.reading ||
      state == RowState.indexing ||
      state == RowState.storing;

  /// The service can only stop a file before it starts.
  bool get canCancel => state == RowState.waiting;

  /// A failure another attempt can fix: the same file again, or a re-index
  /// of the card that was created but failed to index.
  bool get canRetry {
    if (state != RowState.failed) return false;
    final kind = outcome?.kind;
    if (kind == UploadKind.indexFailed) {
      // Same reasons the card hides its link for (no_source, no_text, auth).
      return document?.id != null &&
          !const {'no_source', 'no_text', 'auth'}.contains(outcome?.errorCode);
    }
    return file != null &&
        const {
          UploadKind.unreadable,
          UploadKind.readFailed,
          UploadKind.engineUnavailable,
          UploadKind.network,
          UploadKind.timeout,
          UploadKind.server,
          UploadKind.unknown,
        }.contains(kind);
  }
}

/// Shell-level queue of PDF uploads (button and drop share it), so progress
/// survives tab changes. Files go one at a time (memory, embedding limits).
class UploadController extends ChangeNotifier {
  UploadController({
    this._api,
    this._existing,
    this._reindex,
    this.autoClearAfter = const Duration(seconds: 5),
    this.flashFor = const Duration(milliseconds: 1600),
    DropMachine? drop,
  }) : drop = drop ?? DropMachine();

  final UploadApi? _api;
  final Iterable<Document> Function()? _existing;
  final Future<Document> Function(int documentId)? _reindex;
  final Duration autoClearAfter;
  final Duration flashFor;

  final DropMachine drop;

  /// Whether drag-and-drop exists on this device (not on touch devices).
  bool dropEnabled = false;

  /// Called once per batch when its last file ends (summary snackbar).
  void Function(UploadReport report)? onBatchDone;

  /// Document ids of cards that just arrived (they flash on the board).
  final flash = ValueNotifier<Set<int>>(const {});

  final _rows = <TrayRow>[];
  final _added = <Document>[];
  final _flashTimers = <Timer>[];
  Timer? _clearTimer;
  bool _running = false;
  bool _disposed = false;

  List<TrayRow> get rows => List.unmodifiable(_rows);
  bool hidden = false;
  bool collapsed = false;

  bool get hasActive => _rows.any((r) => r.active);

  // ── Commands ──

  /// Queues [files] (at most [UploadLimits.maxFiles]; the rest are reported
  /// as skipped) and shows [rejected] as rows that need no work.
  void enqueue(
    List<PickedPdf> files, {
    int? projectId,
    List<RejectedFile> rejected = const [],
  }) {
    if (files.isEmpty && rejected.isEmpty) return;
    final take = files.take(UploadLimits.maxFiles).toList();
    final batch = _Batch(files.length - take.length);
    for (final f in rejected) {
      final row = TrayRow._(f.name, null, null, batch)
        ..rejected = f
        ..state = RowState.failed
        ..outcome = UploadOutcome(f.name, UploadKind.notPdf);
      batch.rows.add(row);
      _rows.add(row);
    }
    for (final f in take) {
      final row = TrayRow._(f.name, f, projectId, batch);
      batch.rows.add(row);
      _rows.add(row);
    }
    hidden = false;
    _changed();
    _checkBatch(batch);
    unawaited(_pump());
  }

  void cancel(TrayRow row) {
    if (!row.canCancel) return;
    row.cancel.cancel();
    row.state = RowState.cancelled;
    row.outcome = UploadOutcome(row.name, UploadKind.cancelled);
    _rows.remove(row);
    _changed();
    _checkBatch(row._batch);
  }

  void retry(TrayRow row) {
    if (!row.canRetry || !_rows.contains(row)) return;
    row._batch = _Batch(0)..rows.add(row);
    final reindexDoc = row.outcome?.kind == UploadKind.indexFailed;
    row
      ..outcome = null
      ..cancel = UploadCancel()
      ..state = reindexDoc ? RowState.indexing : RowState.waiting;
    hidden = false;
    _changed();
    if (reindexDoc) {
      unawaited(_reindexRow(row));
    } else {
      unawaited(_pump());
    }
  }

  /// Removes one finished row.
  void dismiss(TrayRow row) {
    if (row.active) return;
    _rows.remove(row);
    _changed();
  }

  /// Closes the tray; work in progress continues and reopens it on news.
  void close() {
    if (hasActive) {
      hidden = true;
    } else {
      _rows.clear();
    }
    _changed();
  }

  void toggleCollapsed() {
    collapsed = !collapsed;
    notifyListeners();
  }

  // ── Worker ──

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (!_disposed) {
        final row = _rows
            .where((r) => r.state == RowState.waiting && r.file != null)
            .firstOrNull;
        if (row == null) break;
        final outcome = await _process(row);
        if (outcome.kind == UploadKind.engineUnavailable) {
          // Same cause for every queued file: report it, don't try again.
          for (final r
              in _rows
                  .where((r) => r.state == RowState.waiting && r.file != null)
                  .toList()) {
            _finish(
              r,
              UploadOutcome(
                r.name,
                UploadKind.engineUnavailable,
                detail: outcome.detail,
              ),
            );
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<UploadOutcome> _process(TrayRow row) async {
    row.state = RowState.reading;
    _changed();
    UploadOutcome outcome;
    try {
      final report = await uploadPdfs(
        [row.file!],
        api: _api ?? UploadApi.live(),
        projectId: row.projectId,
        existing: [...?_existing?.call(), ..._added],
        cancel: row.cancel,
        onProgress: (p) {
          row.state = switch (p.stage) {
            UploadStage.reading => RowState.reading,
            UploadStage.indexing => RowState.indexing,
            UploadStage.storing => RowState.storing,
          };
          row.pages = p.pages;
          _changed();
        },
      );
      outcome = report.outcomes.single;
    } catch (e) {
      debugPrint('upload ${row.name} crashed: $e');
      outcome = UploadOutcome(row.name, UploadKind.unknown);
    }
    _finish(row, outcome);
    return outcome;
  }

  Future<void> _reindexRow(TrayRow row) async {
    final id = row.document!.id!;
    UploadOutcome outcome;
    Document? doc;
    try {
      doc = await (_reindex ?? client.document.reindex)(id);
      outcome = doc.status == 'ready'
          ? UploadOutcome(row.name, UploadKind.added, document: doc)
          : UploadOutcome(
              row.name,
              UploadKind.indexFailed,
              document: doc,
              errorCode: doc.lastError,
            );
    } catch (e) {
      debugPrint('re-index ${row.name} failed: $e');
      outcome = UploadOutcome(
        row.name,
        UploadKind.indexFailed,
        document: row.document,
        errorCode: 'unknown',
      );
    }
    _finish(row, outcome);
  }

  void _finish(TrayRow row, UploadOutcome o) {
    if (_disposed) return;
    row.outcome = o;
    row.document = o.document ?? row.document;
    switch (o.kind) {
      case UploadKind.added || UploadKind.duplicate:
        row.state = RowState.done;
      case UploadKind.cancelled:
        row.state = RowState.cancelled;
        _rows.remove(row);
      default:
        row.state = RowState.failed;
    }
    final doc = o.document;
    if (doc != null) {
      _added.add(doc);
      boardRefresh.value++;
      if (o.kind == UploadKind.added && doc.id != null) _flash(doc.id!);
    }
    _changed();
    _checkBatch(row._batch);
  }

  void _flash(int id) {
    flash.value = {...flash.value, id};
    _flashTimers.add(
      Timer(flashFor, () {
        if (_disposed) return;
        flash.value = {...flash.value}..remove(id);
      }),
    );
  }

  void _checkBatch(_Batch b) {
    if (b.reported || b.rows.any((r) => r.active)) return;
    b.reported = true;
    onBatchDone?.call(
      UploadReport([
        for (final r in b.rows)
          if (r.outcome != null) r.outcome!,
      ], skippedOverLimit: b.skippedOverLimit),
    );
  }

  /// Finished rows leave on their own; failures stay until dismissed.
  void _changed() {
    if (_disposed) return;
    if (hasActive) {
      _clearTimer?.cancel();
      _clearTimer = null;
    } else if (_clearTimer == null &&
        _rows.any((r) => r.state == RowState.done)) {
      _clearTimer = Timer(autoClearAfter, () {
        _clearTimer = null;
        _rows.removeWhere((r) => r.state == RowState.done);
        _changed();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearTimer?.cancel();
    for (final t in _flashTimers) {
      t.cancel();
    }
    drop.dispose();
    flash.dispose();
    super.dispose();
  }
}

/// Gives the shell's [UploadController] to the board, zone and tray. Plain
/// [InheritedWidget]: dependents listen to what they need themselves.
class UploadScope extends InheritedWidget {
  const UploadScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final UploadController controller;

  static UploadController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UploadScope>()?.controller;

  @override
  bool updateShouldNotify(UploadScope old) => controller != old.controller;
}
