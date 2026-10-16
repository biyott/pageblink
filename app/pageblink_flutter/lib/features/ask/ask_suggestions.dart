import 'package:pageblink_client/pageblink_client.dart';

import '../../app/l10n.dart';

/// Title prefixes of the sign-up sample note; must match the server's
/// `SampleNote` titles (`app/pageblink_server/lib/src/sample/sample_note.dart`).
const sampleTitlePrefixes = ['Sample · ', '샘플 · '];

bool isSampleTitle(String title) => sampleTitlePrefixes.any(title.startsWith);

/// Titles of the user's own notes, the only place the sample lives.
List<String> personalNoteTitles(Iterable<Document> docs) => [
  for (final d in docs)
    if (d.kind == 'note' && d.projectId == null) d.title,
];

/// Example questions. The demo account gets only its own (the general ones
/// do not match its content); otherwise the sample's first while the sample
/// note exists (else they would only find nothing), then the general ones.
List<String> orderedSuggestions(
  L l,
  Iterable<String> noteTitles, {
  bool isDemo = false,
}) => [
  if (isDemo)
    ...l.demoSuggestions
  else ...[
    if (noteTitles.any(isSampleTitle)) ...l.sampleSuggestions,
    ...l.askSuggestions,
  ],
];
