// Earlier turns of a conversation for the model, and the search query of a
// follow-up question (design 030 §4). Pure Dart.

import '../providers/llm_provider.dart' show ChatTurn;

/// The notice Ask puts in front of an answer that used keyword search. It is
/// stored with the answer but never sent back to the model.
const keywordNoticeKo = '_(의미 검색을 잠시 쓸 수 없어 키워드 검색 결과로 답합니다.)_\n\n';
const keywordNoticeEn =
    '_(Semantic search is unavailable right now, so this answer uses keyword matches.)_\n\n';

/// Role marks and framing the providers add to each earlier turn.
const turnOverheadChars = 40;

/// Room for the system prompt and the numbered titles around the sources.
const promptOverheadChars = 1500;

/// An earlier answer is cut to its start, but never below this when it is the
/// only turn that fits.
const minAnswerChars = 200;

/// The first [max] characters of [s], never splitting a surrogate pair.
String clip(String s, int max) {
  if (s.length <= max) return s;
  var end = max;
  if (end > 0 && _isHigh(s.codeUnitAt(end - 1))) end--;
  return s.substring(0, end);
}

bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;

/// Question text as kept and sent: trimmed and at most [max] characters.
String capQuestion(String question, int max) => clip(question.trim(), max);

/// Conversation title: the first question on one line, at most 80 characters.
String titleOf(String question) =>
    clip(question.replaceAll(RegExp(r'\s+'), ' ').trim(), 80);

final _marker = RegExp(r'\s?(?:\[\d{1,2}\]|【\d{1,2}】|［\d{1,2}］)');

/// An answer as the model should see it: no keyword-search notice, no
/// citation markers (their numbers meant other sources then), cut to
/// [maxChars] with an ellipsis.
String cleanAnswer(String answer, int maxChars) {
  var a = answer;
  for (final notice in const [keywordNoticeKo, keywordNoticeEn]) {
    if (a.startsWith(notice)) a = a.substring(notice.length);
  }
  a = a.replaceAll(_marker, '').trim();
  return a.length <= maxChars ? a : '${clip(a, maxChars)}…';
}

/// Search text of a follow-up: the question, then the previous one cut to
/// [joinChars] (the question itself comes first and is never cut).
String searchQuery(String question, String? previous, int joinChars) {
  if (previous == null || previous.trim().isEmpty) return question;
  return '$question\n${clip(previous.trim(), joinChars)}';
}

/// The earlier turns that fit [budget] characters, oldest first. [past] is
/// oldest first and holds finished turns only.
///
/// Newest turns go in first; the first one that does not fit ends the list,
/// so the history never skips a turn to squeeze an older one in. When not
/// even the newest fits whole, its answer is shortened to the room left (at
/// least [minAnswerChars]), or the history stays empty.
List<ChatTurn> buildHistory(
  List<ChatTurn> past, {
  required int budget,
  required int answerChars,
}) {
  final picked = <ChatTurn>[];
  var left = budget;
  for (final t in past.reversed) {
    final q = t.question;
    final a = cleanAnswer(t.answer, answerChars);
    final cost = q.length + a.length + turnOverheadChars;
    if (cost <= left) {
      picked.add(ChatTurn(q, a));
      left -= cost;
      continue;
    }
    if (picked.isEmpty) {
      final room = left - q.length - turnOverheadChars - 1; // the ellipsis
      if (room >= minAnswerChars && a.length > room) {
        picked.add(ChatTurn(q, '${clip(a, room)}…'));
      }
    }
    break;
  }
  return picked.reversed.toList();
}

/// Characters of earlier turns allowed after the sources and the question
/// are counted against [promptMax]; the sources are never trimmed for them.
int historyBudget({
  required int contextBudget,
  required int promptMax,
  required int sourcesChars,
  required int questionChars,
}) {
  final room = promptMax - promptOverheadChars - sourcesChars - questionChars;
  return room < contextBudget ? (room < 0 ? 0 : room) : contextBudget;
}
