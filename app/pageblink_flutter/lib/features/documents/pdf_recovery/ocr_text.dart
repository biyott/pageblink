import 'dart:convert';

import 'page_detect.dart';
import 'recovery_models.dart';

/// One word as Tesseract reports it, with its box in the rendered page.
class OcrWord {
  const OcrWord(this.text, this.x0, this.y0, this.x1, this.y1, this.conf);

  final String text;
  final int x0, y0, x1, y1;
  final int conf;

  int get height => y1 - y0;
}

/// One text line: words left to right, and the column region it came from.
class OcrLine {
  const OcrLine(this.region, this.words, this.conf);

  final int region;
  final List<OcrWord> words;
  final int conf;
}

/// What the page script returns for one page (`ocrPage`).
class OcrPageData {
  const OcrPageData(this.lines, {this.skew = 0, this.regions = 1});

  final List<OcrLine> lines;
  final double skew;
  final int regions;

  factory OcrPageData.fromJson(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final lines = <OcrLine>[];
    for (final l in (m['lines'] as List? ?? const [])) {
      final words = <OcrWord>[];
      for (final w in (l['w'] as List? ?? const [])) {
        final b = (w['b'] as List).cast<num>();
        words.add(
          OcrWord(
            '${w['t']}',
            b[0].round(),
            b[1].round(),
            b[2].round(),
            b[3].round(),
            ((w['c'] as num?) ?? 0).round(),
          ),
        );
      }
      lines.add(
        OcrLine(
          ((l['r'] as num?) ?? 0).toInt(),
          words,
          ((l['c'] as num?) ?? 0).round(),
        ),
      );
    }
    return OcrPageData(
      lines,
      skew: ((m['skew'] as num?) ?? 0).toDouble(),
      regions: ((m['regions'] as num?) ?? 1).toInt(),
    );
  }
}

/// Words closer than this many median word heights are glued. Tesseract puts
/// spaces inside Korean words (`워 크 숍`); measured on synthetic scans the
/// letter gap inside a word is mostly under 0.4 and a real word gap above
/// (design 032 section 3.6, rule tuned in this implementation).
const _glueGap = 0.38;

bool _isHangul(int r) =>
    (r >= 0xac00 && r <= 0xd7a3) ||
    (r >= 0x1100 && r <= 0x11ff) ||
    (r >= 0x3130 && r <= 0x318f);

/// Punctuation that never starts a word after a space: `, . ; : ! ? ) ] } %`.
bool _isClosing(int r) => ',.;:!?)]}%'.runes.contains(r);

bool _isWordChar(int r) =>
    _isHangul(r) ||
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x41 && r <= 0x5a) ||
    (r >= 0x61 && r <= 0x7a);

/// The text of one line, with the spaces Tesseract wrongly put inside Korean
/// words taken out. A space is dropped only before a Hangul syllable (or a
/// closing mark such as `,` or `)`) that follows a Hangul, Latin letter or
/// digit, when the gap between the boxes is small compared with the median word
/// height of the line. Everything else keeps its space.
String restoreLineSpaces(OcrLine line) {
  final words = [
    for (final w in line.words)
      if (w.text.trim().isNotEmpty) w,
  ];
  if (words.isEmpty) return '';
  final heights = [for (final w in words) w.height]..sort();
  final medianH = heights[heights.length ~/ 2].clamp(1, 1 << 20);
  final out = StringBuffer(words.first.text.trim());
  for (var i = 1; i < words.length; i++) {
    final prev = words[i - 1], next = words[i];
    final a = prev.text.trim(), b = next.text.trim();
    final first = b.runes.first;
    final glue =
        (_isHangul(first) || _isClosing(first)) &&
        _isWordChar(a.runes.last) &&
        (next.x0 - prev.x1) < _glueGap * medianH;
    if (!glue) out.write(' ');
    out.write(b);
  }
  return out.toString();
}

final _boxChars = RegExp('[|│┃¦║╎╏┆┇┊┋]');
final _ruleRuns = RegExp(r'[-_=~—–―·.]{3,}');
final _spaces = RegExp(r'[ \t ]+');

/// Drops what recognition makes of table borders, rules and specks, and the
/// lines that are mostly not letters. Returns the surviving lines.
List<String> cleanOcrLines(Iterable<String> lines, {List<int>? confidences}) {
  final out = <String>[];
  var i = 0;
  for (final raw in lines) {
    final conf = confidences != null && i < confidences.length
        ? confidences[i]
        : 100;
    i++;
    final line = raw
        .replaceAll(_boxChars, ' ')
        .replaceAll(_ruleRuns, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    final visible = visibleCharCount(line);
    if (visible == 0) continue;
    var wordChars = 0;
    for (final r in line.runes) {
      if (_isWordChar(r)) wordChars++;
    }
    if (wordChars < 2 || wordChars < visible * 0.5) continue; // specks
    if (conf < 30 && visible < 8) continue; // short and doubtful
    out.add(line);
  }
  return out;
}

/// Recognized page to text: lines in reading order (regions top to bottom,
/// left column before right), spaces restored, junk removed. May be empty.
String ocrPageText(OcrPageData data) {
  final lines = <String>[];
  final confs = <int>[];
  for (final l in data.lines) {
    lines.add(restoreLineSpaces(l));
    confs.add(l.conf);
  }
  return cleanOcrLines(lines, confidences: confs).join('\n');
}

/// Mean word confidence 0..100 weighted by word length; null without words.
int? ocrConfidence(OcrPageData data) {
  var sum = 0, weight = 0;
  for (final l in data.lines) {
    for (final w in l.words) {
      final n = visibleCharCount(w.text);
      sum += w.conf * n;
      weight += n;
    }
  }
  return weight == 0 ? null : (sum / weight).round();
}

/// Form field values of one page as text: one value per line, the page's own
/// short text first when it has any. Field names are not used (they are
/// identifiers, not words).
String formPageText(String original, List<String> values) {
  final parts = [
    if (visibleCharCount(original) > 0) original.trim(),
    ...values.map((v) => v.trim()).where((v) => v.isNotEmpty),
  ];
  return parts.join('\n');
}

/// The result for a page, or null when too little came out.
RecoveredPage? recoveredOrNull({
  required int page,
  required String text,
  required String source,
  int? confidence,
}) => visibleCharCount(text) < kRecoveryMinResultChars
    ? null
    : RecoveredPage(
        page: page,
        text: text,
        source: source,
        confidence: confidence,
      );
