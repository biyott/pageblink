import 'package:flutter/foundation.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';
import '../../client.dart';

/// Example questions of the sample content the account holds, as the server
/// says (`document.sampleHints`). The server owns the pairing of sample
/// content and questions; the app never guesses it from titles. Empty until
/// the first answer and when there is no sample.
final sampleHints = ValueNotifier<List<SampleHint>>(const []);

/// Test hook: replaces the server call.
@visibleForTesting
Future<List<SampleHint>> Function()? sampleHintsCall;

/// Latest-wins: a reset or a newer read makes older answers stale.
var _seq = 0;

/// A new signed-in session starts: forget the previous one's hints.
void resetSampleHints() {
  _seq++;
  sampleHints.value = const [];
}

/// Re-reads the hints (after a sample finished indexing, was edited or
/// deleted: all bump `boardRefresh`). A failed read keeps the last value.
Future<void> refreshSampleHints() async {
  final seq = ++_seq;
  try {
    final hints = await (sampleHintsCall ?? client.document.sampleHints)();
    if (seq == _seq) sampleHints.value = hints;
  } catch (e) {
    debugPrint('sample hints unavailable: $e');
  }
}

/// Example questions: the sample's own first (they are in the language of
/// the sample content, so they are answered), then, for a regular account,
/// the general ones in the UI language. The demo account gets only its own:
/// the general ones do not match its content.
List<String> orderedSuggestions(
  L l,
  Iterable<SampleHint> hints, {
  bool isDemo = false,
}) => [
  for (final h in hints) ...h.questions,
  if (!isDemo) ...l.askSuggestions,
];
