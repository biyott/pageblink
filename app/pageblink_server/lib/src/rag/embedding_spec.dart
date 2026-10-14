/// Embedding rules shared by server and (later) device.
///
/// Pure Dart: no Serverpod imports, so it can move to packages/pageblink_core.
/// Device and server must use identical model, dimension and prefixes,
/// otherwise vectors live in different spaces (ADR 002).
class EmbeddingSpec {
  static const model = 'google/embeddinggemma-300m';
  static const dimensions = 768;

  static String query(String question) =>
      'task: search result | query: $question';

  static String document(String title, String text) =>
      'title: $title | text: $text';
}
