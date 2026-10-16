import 'package:flutter/painting.dart' show TextRange;
import 'package:pdfrx/pdfrx.dart';

import '../notes/markdown_live.dart' show findQuote;

/// Where a cited passage is on a PDF page, as one rectangle per text line in
/// PDF page coordinates (research 027, PDF part).
///
/// [pageText] is the page's extracted text (`fullText`, same engine as the
/// text the server indexed, so a chunk is a substring up to whitespace).
/// Matching: the whole quote with whitespace ignored ([findQuoteLoose]), then
/// the note editor's [findQuote] (which also tries its first 8 / 5 words). Null: not found (the caller falls back to the
/// banner).
List<PdfRect>? pdfCiteLines(
  String fullText,
  List<PdfRect> charRects,
  String quote,
) {
  final r = findQuoteLoose(fullText, quote) ?? findQuote(fullText, quote);
  if (r == null || r.isCollapsed) return null;
  final end = r.end < charRects.length ? r.end : charRects.length;
  final lines = pdfLineRects(charRects, r.start, end);
  return lines.isEmpty ? null : lines;
}

/// [quote] in [text] ignoring all whitespace on both sides: the server joins
/// the lines of a page with spaces, while PDF text breaks a word at the end of
/// a line (or has no space where the chunk has one). Matches on the text with
/// whitespace removed and maps the hit back to indices of [text]. Null: not
/// found.
TextRange? findQuoteLoose(String text, String quote) {
  final ws = RegExp(r'\s');
  final q = quote.replaceAll(ws, '');
  if (q.isEmpty) return null;
  final kept = StringBuffer();
  final at = <int>[]; // index in [text] of each kept character
  for (var i = 0; i < text.length; i++) {
    if (ws.hasMatch(text[i])) continue;
    kept.write(text[i]);
    at.add(i);
  }
  final i = kept.toString().indexOf(q);
  if (i < 0) return null;
  return TextRange(start: at[i], end: at[i + q.length - 1] + 1);
}

/// The character boxes `[start, end)` grouped into text lines: a box joins the
/// current line when it overlaps it vertically by more than half of the
/// smaller height and starts within about two line heights of its end (so the
/// gutter between two columns is not filled). Empty boxes (spaces, line
/// breaks) are skipped. Pure, in reading order.
List<PdfRect> pdfLineRects(List<PdfRect> chars, int start, int end) {
  final lines = <PdfRect>[];
  PdfRect? cur;
  for (var i = start < 0 ? 0 : start; i < end && i < chars.length; i++) {
    final c = chars[i];
    if (c.isEmpty) continue;
    if (cur != null) {
      final top = c.top < cur.top ? c.top : cur.top;
      final bottom = c.bottom > cur.bottom ? c.bottom : cur.bottom;
      final h = c.height < cur.height ? c.height : cur.height;
      final sameLine = top - bottom > h * 0.5;
      final near = c.left - cur.right < 2 * cur.height && c.right > cur.left;
      if (sameLine && near) {
        cur = cur.merge(c);
        continue;
      }
      lines.add(cur);
    }
    cur = c;
  }
  if (cur != null) lines.add(cur);
  return lines;
}

/// Union of the line rectangles in PDF page coordinates.
PdfRect? pdfLinesBounds(List<PdfRect> lines) {
  PdfRect? u;
  for (final l in lines) {
    u = u == null ? l : u.merge(l);
  }
  return u;
}
