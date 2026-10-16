// Models sometimes write the full-width 【3】 or ［3］ for [3].
final _marker = RegExp(r'\[(\d{1,2})\]|【(\d{1,2})】|［(\d{1,2})］');
final _noGapAfter = RegExp(r'[\s.,;:!?)\]]');

/// Spaces out the `[n]` citation markers the model writes so the markdown
/// renderer's source tag (drawn as a tappable ⚡n chip, see `ask_screen.dart`)
/// does not touch the words around it: a space goes before the marker and,
/// unless whitespace or punctuation follows, after it. The marker itself stays
/// `[n]` (the full-width forms become it), which gpt_markdown parses as a
/// source tag.
String renderMarkers(String text) => text.replaceAllMapped(_marker, (m) {
  final next = m.end < text.length ? text[m.end] : '';
  final gap = next.isEmpty || _noGapAfter.hasMatch(next) ? '' : ' ';
  return ' [${m[1] ?? m[2] ?? m[3]}]$gap';
});
