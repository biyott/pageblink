import 'dart:typed_data';

import 'package:pageblink_client/pageblink_client.dart';

import 'pdf_recovery.dart';

/// Lets `extractPages` recover empty pages in the same call. Without it the
/// extraction is exactly what it was.
class RecoveryHook {
  const RecoveryHook(
    this.engine, {
    this.approve,
    this.onProgress,
    this.cancel,
  });

  final PdfRecovery engine;

  /// Asked once, with what was found, before anything is downloaded or read.
  /// Null means yes. Returning false leaves the pages as extracted.
  final Future<bool> Function(RecoveryPlan plan)? approve;

  final void Function(RecoveryProgress progress)? onProgress;

  final RecoveryCancel? cancel;
}

/// [pages] with the recovered texts in place and their `source` set. Pages not
/// in [recovered] are untouched. A form page keeps the few characters its own
/// text layer had (already part of the recovered text).
List<PageText> mergeRecovered(
  List<PageText> pages,
  Iterable<RecoveredPage> recovered,
) {
  final byPage = {for (final r in recovered) r.page: r};
  return [
    for (final p in pages)
      if (byPage[p.page] case final r?)
        PageText(page: p.page, text: r.text, source: r.source)
      else
        p,
  ];
}

/// Runs recovery for [pages] (already extracted from [bytes]) when some have no
/// text, and returns them merged. Returns [pages] itself when nothing needs
/// recovering, the hook declines, or nothing could be read.
Future<List<PageText>> recoverPages(
  List<PageText> pages,
  Uint8List bytes,
  String name,
  RecoveryHook hook,
) async {
  final plan = hook.engine.planFromTexts([for (final p in pages) p.text]);
  if (!plan.needed) return pages;
  if (hook.approve != null && !await hook.approve!(plan)) return pages;
  RecoveryOutcome? outcome;
  await for (final e in hook.engine.recover(
    bytes,
    plan,
    name: name,
    cancel: hook.cancel,
  )) {
    hook.onProgress?.call(e);
    outcome = e.outcome ?? outcome;
  }
  final got = outcome?.pages ?? const <RecoveredPage>[];
  return got.isEmpty ? pages : mergeRecovered(pages, got);
}
