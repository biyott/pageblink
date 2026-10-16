import 'dart:async';

/// A page whose text layer holds fewer visible characters than this is a
/// recovery candidate (scan, text drawn as shapes, form-only page, footer-only
/// scan). Design 032 section 5.1.
const kRecoveryMinVisibleChars = 30;

/// Recovered text with fewer visible characters than this counts as nothing.
const kRecoveryMinResultChars = 10;

/// At most this many candidate pages are read per document; the rest are
/// reported as skipped (time, memory, small devices).
const kRecoveryMaxPages = 50;

/// Pages are rendered with their long edge at this many pixels (about 150 dpi
/// for A4). 300 dpi measured clearly worse (design 032 section 3.4).
const kRecoveryRenderLongEdge = 1754;

/// Where recovered page text came from. Null (not listed here) is the
/// original PDF text; the server stores exactly these two values.
abstract final class PageSource {
  /// Values of form fields (AcroForm), exact.
  static const form = 'form';

  /// Text recognized from the rendered page on this device; may contain errors.
  static const ocr = 'ocr';
}

/// What `PdfRecovery.analyze` found.
class RecoveryPlan {
  const RecoveryPlan({
    required this.pageCount,
    required this.visibleChars,
    required this.candidates,
    required this.overLimit,
  });

  /// Pages in the document.
  final int pageCount;

  /// Visible characters of each page's text layer; index 0 is page 1.
  final List<int> visibleChars;

  /// Pages to try (1-based, ascending), at most [kRecoveryMaxPages].
  final List<int> candidates;

  /// Candidate pages beyond the limit. They are not read.
  final List<int> overLimit;

  /// True when there is something to recover.
  bool get needed => candidates.isNotEmpty;

  /// True when every page is a candidate (a scan: nothing is searchable now).
  bool get allPagesEmpty => pageCount > 0 && candidates.length == pageCount;
}

/// Why a page could not be recovered.
enum RecoveryFailure {
  /// The OCR engine could not be downloaded or started.
  engineLoad,

  /// The page could not be drawn.
  render,

  /// Recognition failed.
  ocr,

  /// Recognition took too long and was given up.
  timeout,

  /// Nothing readable came out (a blank or decorative page).
  empty,

  /// The browser feature this needs is missing (not a web build).
  unsupported,
}

/// One page that did not yield text.
class RecoveryPageIssue {
  const RecoveryPageIssue(this.page, this.reason);

  final int page;
  final RecoveryFailure reason;

  @override
  String toString() => 'RecoveryPageIssue($page, ${reason.name})';
}

/// Text recovered for one page.
class RecoveredPage {
  const RecoveredPage({
    required this.page,
    required this.text,
    required this.source,
    this.confidence,
  });

  /// 1-based.
  final int page;

  /// Clean text, at least [kRecoveryMinResultChars] visible characters.
  final String text;

  /// [PageSource.form] or [PageSource.ocr].
  final String source;

  /// Mean word confidence 0..100 for OCR pages, null for form values.
  final int? confidence;

  @override
  String toString() => 'RecoveredPage($page, $source, ${text.length} chars)';
}

/// The end result of one `recover` run.
class RecoveryOutcome {
  const RecoveryOutcome({
    required this.pages,
    required this.failed,
    required this.skippedOverLimit,
    required this.canceled,
  });

  /// Pages that now have text, ascending by page.
  final List<RecoveredPage> pages;

  /// Candidate pages that did not yield text, with the reason.
  final List<RecoveryPageIssue> failed;

  /// Candidate pages left out because of [kRecoveryMaxPages].
  final List<int> skippedOverLimit;

  /// The user stopped the run. [pages] holds what was finished before that.
  final bool canceled;

  bool get hasText => pages.isNotEmpty;
}

enum RecoveryPhase {
  /// Downloading and starting the engine (first use only), [prepare] 0..1.
  preparing,

  /// Reading form field values.
  forms,

  /// Recognizing pages one at a time.
  ocr,

  /// Finished; [RecoveryProgress.outcome] is set. Always the last event.
  done,
}

/// One step of a `recover` run.
class RecoveryProgress {
  const RecoveryProgress({
    required this.phase,
    required this.total,
    required this.handled,
    this.prepare,
    this.page,
    this.recovered,
    this.issue,
    this.outcome,
  });

  final RecoveryPhase phase;

  /// Candidate pages this run works on.
  final int total;

  /// Of those, pages finished so far (recovered or failed).
  final int handled;

  /// Download/start progress 0..1 while [phase] is [RecoveryPhase.preparing].
  final double? prepare;

  /// The page this event is about, if any.
  final int? page;

  /// Set when [page] just got its text.
  final RecoveredPage? recovered;

  /// Set when [page] just failed. The run goes on with the next page.
  final RecoveryPageIssue? issue;

  /// Set only on the [RecoveryPhase.done] event.
  final RecoveryOutcome? outcome;
}

/// Stops a `recover` run. Work in flight is interrupted; pages finished
/// before are kept in the outcome.
class RecoveryCancel {
  final _completer = Completer<void>();
  final _listeners = <void Function()>[];

  bool get isCancelled => _completer.isCompleted;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (isCancelled) return;
    _completer.complete();
    for (final f in _listeners.toList()) {
      f();
    }
  }

  /// Calls [f] now if already cancelled, otherwise when it happens. Returns
  /// a function that removes the listener.
  void Function() onCancel(void Function() f) {
    if (isCancelled) {
      f();
      return () {};
    }
    _listeners.add(f);
    return () => _listeners.remove(f);
  }
}
