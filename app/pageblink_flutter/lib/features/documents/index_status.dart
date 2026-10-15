import 'package:flutter/widgets.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';

/// How a card's status line looks. `warn` = failure the user can't blame on
/// themselves, `neutral` = interrupted/unreadable, `calm` = in progress.
enum IndexTone { calm, neutral, warn }

/// One status line under a card (docs/design/upload-dnd-reindex §2.2).
@immutable
class IndexLine {
  const IndexLine({
    required this.label,
    required this.tone,
    this.icon,
    this.pulse = false,
    this.canRetry = false,
    this.reason,
  });

  final String label;
  final IndexTone tone;

  /// Null while indexing (a pulsing dot is drawn instead).
  final IconData? icon;
  final bool pulse;

  /// Shows the "Retry" link. Hidden when retrying cannot help.
  final bool canRetry;

  /// Full sentence for the PDF body / the note's tooltip. Never a raw code.
  final String? reason;
}

/// Reasons a retry cannot fix: the source has no text, or the server's key is
/// rejected. The link is hidden and bulk retry skips them.
const _futileCodes = {'no_source', 'no_text', 'auth'};

/// A failed document where another attempt can plausibly work.
bool isRetryableFailure(Document d) =>
    d.status == 'failed' && !_futileCodes.contains(d.lastError);

/// Phase thresholds of the "indexing" wording (§2.2 rows 2-4).
const indexingLongAfter = Duration(seconds: 20);
const indexingVeryLongAfter = Duration(minutes: 3);

/// `null` = nothing to show (a `ready` card). [elapsed] is how long the
/// document has been indexing (`updatedAt` is set when indexing starts and
/// not touched until it ends: document_endpoint.dart). [reindexing] is a
/// local re-index of this very card.
IndexLine? indexLine(
  L l,
  Document d, {
  Duration elapsed = Duration.zero,
  bool reindexing = false,
}) {
  if (reindexing) {
    return IndexLine(
      label: l.reindexingShort,
      tone: IndexTone.calm,
      pulse: true,
    );
  }
  switch (d.status) {
    case 'ready':
      return null;
    case 'failed':
      final code = d.lastError;
      final reason = l.indexingError(code ?? 'unknown');
      return switch (code) {
        'interrupted' => IndexLine(
          label: l.indexingInterrupted,
          tone: IndexTone.neutral,
          icon: AppIcons.error,
          canRetry: true,
          reason: reason,
        ),
        'no_source' || 'no_text' => IndexLine(
          label: l.indexingNoText,
          tone: IndexTone.neutral,
          icon: AppIcons.info,
          reason: reason,
        ),
        'auth' => IndexLine(
          label: l.indexingServerSetup,
          tone: IndexTone.warn,
          icon: AppIcons.error,
          reason: reason,
        ),
        _ => IndexLine(
          label: l.indexingFailed,
          tone: IndexTone.warn,
          icon: AppIcons.error,
          canRetry: true,
          reason: reason,
        ),
      };
    default:
      return IndexLine(
        label: elapsed >= indexingVeryLongAfter
            ? l.indexingVeryLong
            : elapsed >= indexingLongAfter
            ? l.indexingLong
            : l.indexing,
        tone: IndexTone.calm,
        pulse: true,
      );
  }
}
