import 'package:pageblink_server/src/rag/citation_infer.dart';
import 'package:pageblink_server/src/rag/line_chunker.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
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

/// The evidence lines (chunks) of a demo pack's "launch plan" and weekly-sync
/// notes, as the retriever hands them over.
List<String> _packLines(String id) => [
  for (final n in SamplePacks.all.firstWhere((p) => p.id == id).notes.skip(1))
    for (final c in chunkNote(n.body, docTitle: n.title)) c.text,
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

  group('reverse match: a short answer inside a longer evidence line', () {
    final en = _packLines('demo-en');
    final ko = _packLines('demo-ko');
    List<String> lines(List<String> from, List<int> idx) => [
      for (final i in idx) from[i],
    ];

    test('"Nov 18, 2026" links the three lines that say it', () {
      final got = inferCitations('Nov 18, 2026', en);
      expect(lines(en, got), [
        '- **Launch date:** moved to Nov 18, 2026',
        '3. Nov 18, 2026: public launch',
        '1. Launch date confirmed for **Nov 18, 2026**',
      ]);
      expect(inferCitations('Nov 18, 2026.', en), got); // sentence end
      expect(inferCitations('**nov 18, 2026**', en), got); // case, emphasis
    });

    test('"4분기 마케팅 예산: 1,200만 원": the colon splits, the comma does not', () {
      final got = inferCitations('4분기 마케팅 예산: 1,200만 원', ko);
      expect(lines(ko, got), ['- **마케팅 예산:** 4분기 1,200만 원']);
      // the comma inside the number would leave "200만원" (4): never split
      expect(inferCitations('1,200만 원', ko), got);
    });

    test('a phrase of a longer answer links too, one line per phrase', () {
      final got = inferCitations(
        '- Nov 18, 2026\n- Marketing budget: ₩12M for Q4',
        en,
      );
      expect(lines(en, got), [
        '- **Marketing budget:** ₩12M for Q4',
        '- **Launch date:** moved to Nov 18, 2026',
        '3. Nov 18, 2026: public launch',
      ]); // 4 found, ascending, the first 3
    });

    test('a phrase that holds a forward match adds nothing around it', () {
      // "베타 초대 메일 발송" is source 2 and sits inside source 4 too: only 2.
      expect(_infer('베타 초대 메일 발송'), [2]);
      expect(_infer('릴리스 노트 마무리, 베타 초대 메일 발송입니다.'), [1, 2]);
      // The measured 30 answers: the reverse rule changes none of them.
      for (final (name, answer, want) in _noMarker) {
        expect(_infer(answer), want, reason: name);
      }
    });

    test('shorter than 6 after normalizing: ignored', () {
      expect(inferCitations('2026', en), isEmpty);
      expect(inferCitations('Nov 18', en), isEmpty); // nov18 = 5
      expect(inferCitations('20 people', en), isNotEmpty); // 7: ok
    });

    test('longer than 80: a sentence, not a phrase', () {
      final long = 'a' * 81;
      expect(
        inferCitations(long, [
          'x$long'
              'y',
        ]),
        isEmpty,
      );
      expect(inferCitations('a' * 80, ['x${'a' * 80}y']), [0]);
    });

    test('a phrase found in more than 3 sources is ambiguous: ignored', () {
      final ev = [for (var i = 1; i <= 4; i++) '- [ ] the launch step $i'];
      expect(inferCitations('the launch', ev), isEmpty);
      expect(inferCitations('the launch', ev.take(3).toList()), [0, 1, 2]);
      // ...but another phrase of the same answer still counts
      expect(inferCitations('the launch\nlaunch step 4', ev), [3]);
    });

    test('identical evidence in two sources links the first only', () {
      expect(
        inferCitations('launch step', ['- the launch step', 'the launch step']),
        [0],
      );
    });

    test('"not found" answers still link nothing', () {
      for (final a in [
        '문서에서 찾을 수 없습니다.',
        'I could not find the launch date in the documents.',
        'The documents do not say.',
        '출시 계획',
      ]) {
        expect(inferCitations(a, en), isEmpty, reason: a);
        expect(inferCitations(a, ko), isEmpty, reason: a);
      }
    });

    test('markers the model left (out of range) are not part of a phrase', () {
      expect(inferCitations('Nov 18, 2026 [9]', en), hasLength(3));
    });
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
