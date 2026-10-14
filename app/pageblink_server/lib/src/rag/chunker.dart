import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A chunk of one page, ready to embed.
class TextChunk {
  final int page;
  final int ordinal;
  final String text;

  TextChunk(this.page, this.ordinal, this.text);

  String get contentHash => sha256Hex(text);
}

String sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

/// Collapses whitespace so the same text always hashes and embeds the same.
String normalizeText(String text) => text
    .replaceAll(RegExp(r'[ \t ]+'), ' ')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Splits each page into paragraph-based chunks of about [maxChars] characters
/// (~400 tokens of Korean), carrying [overlapChars] from the previous chunk.
/// Chunks never cross pages, so every chunk has exactly one page to cite.
List<TextChunk> chunkPages(
  List<({int page, String text})> pages, {
  int maxChars = 900,
  int overlapChars = 120,
}) {
  final chunks = <TextChunk>[];
  var ordinal = 0;

  for (final p in pages) {
    final text = normalizeText(p.text);
    if (text.isEmpty) continue;

    var overlap = '';
    final fresh = StringBuffer();
    void flush() {
      if (fresh.isEmpty) return;
      final chunk = '$overlap${fresh.toString()}'.trim();
      chunks.add(TextChunk(p.page, ordinal++, chunk));
      overlap = chunk.length > overlapChars
          ? '${chunk.substring(chunk.length - overlapChars)} '
          : '';
      fresh.clear();
    }

    for (final paragraph in text.split(RegExp(r'\n\s*\n'))) {
      for (final piece in _splitLong(paragraph.trim(), maxChars)) {
        if (overlap.length + fresh.length + piece.length > maxChars) flush();
        fresh.write('$piece\n');
      }
    }
    flush();
  }
  return chunks;
}

/// Splits a paragraph longer than [maxChars] at sentence ends, then hard-wraps.
Iterable<String> _splitLong(String paragraph, int maxChars) sync* {
  if (paragraph.length <= maxChars) {
    if (paragraph.isNotEmpty) yield paragraph;
    return;
  }
  final sentences = paragraph.split(RegExp(r'(?<=[.!?。])\s+'));
  final current = StringBuffer();
  for (final s in sentences) {
    if (current.length + s.length > maxChars && current.isNotEmpty) {
      yield current.toString().trim();
      current.clear();
    }
    if (s.length > maxChars) {
      for (var i = 0; i < s.length; i += maxChars) {
        yield s.substring(i, i + maxChars > s.length ? s.length : i + maxChars);
      }
    } else {
      current.write('$s ');
    }
  }
  if (current.isNotEmpty) yield current.toString().trim();
}
