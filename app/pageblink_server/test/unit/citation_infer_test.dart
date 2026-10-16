import 'package:pageblink_server/src/rag/citation_infer.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/openrouter_llm_provider.dart';
import 'package:test/test.dart';

/// The six sources of the measured question "4분기 출시 계획에서 남은 일이
/// 뭐야?" (demo-ko pack): evidence lines, in source order [1]..[6].
const _evidence = [
  '- [ ] 릴리스 노트 마무리',
  '- [ ] 베타 초대 메일 발송',
  '- [ ] 릴리스 노트 초안 작성 (미나, 금요일까지)',
  '- [ ] 베타 초대 메일 발송 (준)',
  '- [x] 출시 당일 지원 근무표 짜기',
  '- [x] 스테이징 확인',
];

/// The 9 real answers of nemotron-3-super (reasoning off) that had no `[n]`
/// marker among the 30 measured calls (citefix: A#1 B#6 B#8 B#16 A#17 A#19
/// B#20, C#1 C#9), with the sources a reader would link (1-based).
const _noMarker = <(String, String, List<int>)>[
  ('A1', '- 릴리스 노트 마무리  \n- 베타 초대 메일 발송', [1, 2]),
  ('B6', '- 릴리스 노트 마무리  \n- 베타 초대 메일 발송', [1, 2]),
  ('B8', '- 릴리스 노트 마무리  \n- 베타 초대 메일 발송', [1, 2]),
  ('B16', '- [ ] 릴리스 노트 마무리  \n- [ ] 베타 초대 메일 발송', [1, 2]),
  ('A17', '- [ ] 릴리스 노트 마무리  \n- [ ] 베타 초대 메일 발송', [1, 2]),
  ('A19', '- [ ] 릴리스 노트 마무리  \n- [ ] 베타 초대 메일 발송', [1, 2]),
  ('B20', '4분기 출시 계획에서 남은 일은 릴리스 노트 마무리 및 베타 초대 메일 발송입니다.', [1, 2]),
  ('C1', '- [ ] 릴리스 노트 마무리  \n- [ ] 베타 초대 메일 발송', [1, 2]),
  (
    'C9',
    '- [ ] 릴리스 노트 마무리  \n- [ ] 베타 초대 메일 발송  \n'
        '- [ ] 릴리스 노트 초안 작성 (미나, 금요일까지)',
    [1, 2, 3],
  ),
];

List<int> _infer(String answer) => [
  for (final i in inferCitations(answer, _evidence)) i + 1,
];

void main() {
  test('all 9 measured marker-less answers get their sources back', () {
    expect(_noMarker, hasLength(9));
    for (final (name, answer, want) in _noMarker) {
      expect(_infer(answer), want, reason: name);
    }
  });

  test('a marked answer with the markers taken out gives the same sources', () {
    // B#14, which cited [5][1][1][2][5] itself.
    expect(
      _infer(
        '4분기 출시 계획에서 남은 일은:  \n- 릴리스 노트 마무리  \n- 베타 초대 메일 발송  \n'
        '- 출시 당일 지원 근무표 짜기 (완료 표시: [x])',
      ),
      [1, 2, 5],
    );
  });

  test('a shorter evidence inside a longer candidate yields to the longer', () {
    // Measured A13 / B18 with the markers taken out: "베타 초대 메일 발송" is
    // part of "베타 초대 메일 발송 (준)", so source 2 is dropped.
    expect(
      _infer(
        '4분기 출시 계획에서 남은 일은 릴리스 노트 마무리, 베타 초대 메일 발송, '
        '그리고 릴리스 노트 초안 작성(미나, 금요일까지)과 베타 초대 메일 발송(준)입니다.',
      ),
      [1, 3, 4],
    );
  });

  test('markdown, list prefixes and spacing do not matter', () {
    expect(_infer('**릴리스   노트\n마무리**와 `베타 초대 메일 발송`'), [1, 2]);
    expect(_infer('1. 출시 당일 지원 근무표 짜기\n2. ~~스테이징 확인~~'), [5, 6]);
    expect(_infer('> ## - [x] 스테이징 확인'), [6]);
  });

  test('"not found" and unrelated answers link nothing', () {
    expect(_infer('문서에서 찾을 수 없습니다.'), isEmpty);
    expect(_infer('The documents do not say.'), isEmpty);
    expect(_infer(''), isEmpty);
    expect(_infer('릴리스 노트'), isEmpty); // only part of an evidence
  });

  test('evidence shorter than 6 characters is ignored', () {
    expect(
      inferCitations('확인 완료 그리고 끝', ['- [x] 확인 완료', '- 끝']),
      isEmpty,
    );
    expect(inferCitations('스테이징 확인', ['- [x] 스테이징 확인']), [0]); // 6
  });

  test('at most 3, in source order', () {
    final ev = [for (var i = 1; i <= 5; i++) '- 항목 번호 $i 입니다 정말'];
    final answer = ev.reversed.join(' ');
    expect(inferCitations(answer, ev), [0, 1, 2]);
  });

  test('identical evidence in two sources links the first only', () {
    expect(
      inferCitations('릴리스 노트 마무리', ['릴리스 노트 마무리', '- 릴리스 노트 마무리']),
      [0],
    );
  });

  test(
    'both prompts ask for a marker on every sentence with a source',
    () async {
      // OpenRouter: the exact sentence; the text is the same one the measured
      // diagnosis used.
      expect(
        OpenRouterLlmProvider.systemPrompt,
        contains(
          'Every sentence that uses information from a source must end with '
          'its [n] marker; never answer without markers when sources are '
          'provided.',
        ),
      );
      expect(
        ClaudeLlmProvider.systemPrompt,
        contains('must be cited; never answer without citations'),
      );
    },
  );
}
