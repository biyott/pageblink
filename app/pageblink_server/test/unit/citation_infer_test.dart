import 'package:pageblink_server/src/rag/citation_infer.dart';
import 'package:pageblink_server/src/rag/line_chunker.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/providers/openrouter_llm_provider.dart';
import 'package:test/test.dart';

import 'citation_infer_cases.dart';

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

  group(
    'token match: a narrative sentence that repeats a date or an amount',
    () {
      List<int> on(String pack, String answer) =>
          inferCitations(answer, packs[pack]!);

      test('"출시일은 2026년 11월 18일입니다." finds the line with the date', () {
        expect(on('koA', '출시일은 2026년 11월 18일입니다.'), [0]);
        expect(on('enA', 'The launch date is November 18, 2026.'), [0]);
        // other spellings of the same day
        expect(on('koA', '출시일이 2026-11-18로 확정됐습니다.'), [0]);
        expect(on('enA', 'The launch was moved to 18th November 2026.'), [0]);
      });

      test('Korean particles and endings do not matter', () {
        expect(on('koA', '4분기 마케팅 예산은 1,200만원이에요.'), [1]);
        expect(on('koA', '예산은 4분기에 1,200만 원이 책정됐습니다.'), [1]);
        expect(on('koA', '이해관계자와의 커뮤니케이션은 법무팀이 검토합니다.'), [6]);
        expect(on('koA', '구독료는 월 9,900원, 연간 결제 시 99,000원입니다.'), [8]);
      });

      test('two sentences, two sources', () {
        expect(
          on('koA', '출시일은 2026년 11월 18일입니다. 마케팅 예산은 4분기 1,200만 원입니다.'),
          [0, 1],
        );
      });

      test('a date on two lines tells them apart no better: ignored', () {
        expect(on('koB', '출시일은 2026년 11월 18일입니다.'), isEmpty);
        expect(on('enB', 'The launch date is November 18, 2026.'), isEmpty);
        expect(on('koB', '프레스 킷은 11월 18일에 배포됩니다.'), isEmpty);
        expect(on('koC', '커뮤니케이션 계획을 세웠습니다.'), isEmpty);
      });

      test('a number or unit that only looks the same is rejected', () {
        expect(on('koA', '이번 설문에는 8명이 응답했습니다.'), isEmpty); // 8명 alone
        expect(on('koA', '회의 안건은 3개 항목입니다.'), isEmpty);
        expect(on('koA', '지난달 로딩 시간은 300ms였습니다.'), isEmpty); // 1 shared word
        expect(on('enA', 'Page load takes 300 ms on mobile.'), isEmpty);
        expect(on('enA', 'Only 250 days passed since then.'), isEmpty); // unit
        expect(
          on('enA', 'The Q4 budget is \$12 million.'),
          isEmpty,
        ); // currency
      });

      test('a near-miss day or amount is another token', () {
        expect(on('koA', '출시일은 2026년 11월 19일입니다.'), isEmpty);
        expect(on('koA', '출시일은 2025년 11월 18일입니다.'), isEmpty);
        expect(on('koA', '마케팅 예산은 1,500만 원입니다.'), isEmpty);
        // right date, but of another subject: no word in common
        expect(on('koA', '앱스토어 심사는 2026년 11월 18일에 제출합니다.'), isEmpty);
        expect(
          on('enA', 'App Store review submission is on Nov 18, 2026.'),
          isEmpty,
        );
      });

      test(
        'a month-day answer finds a dated line; a dated answer needs the year',
        () {
          expect(on('koA', '11월 28일에 앱스토어 심사를 제출합니다.'), [4]);
          final ev = ['- 출시일: 11월 18일 예정', '- 심사 제출: 2026년 11월 28일'];
          expect(inferCitations('출시일은 2026년 11월 18일입니다.', ev), isEmpty);
          expect(inferCitations('심사 제출일은 11월 28일입니다.', ev), [1]);
        },
      );

      test('"not found" sentences link nothing even with a date in them', () {
        expect(
          on('koA', '2026년 11월 18일 출시일 정보는 문서에서 찾을 수 없습니다.'),
          isEmpty,
        );
        expect(
          on(
            'enA',
            'I could not find a launch on Nov 18, 2026 in the documents.',
          ),
          isEmpty,
        );
      });

      test('a long word is enough, with one more word of the sentence', () {
        expect(on('enA', 'Stakeholder communications are reviewed by legal.'), [
          6,
        ]);
        expect(on('enA', 'The communications team is large.'), isEmpty);
      });

      test('it never takes the place of a forward or reverse match', () {
        final ev = [
          '- 날짜 2026년 11월 18일',
          '- 항목 하나 정말 길게',
          '- 항목 둘 정말 길게',
          '- 항목 셋 정말 길게',
        ];
        const base = '항목 하나 정말 길게, 항목 둘 정말 길게, 항목 셋 정말 길게';
        expect(inferCitations(base, ev), [1, 2, 3]);
        // full of old links already: the date's source is not added
        expect(inferCitations('$base\n날짜는 2026년 11월 18일입니다.', ev), [1, 2, 3]);
        // room left: it is added
        expect(
          inferCitations('항목 하나 정말 길게\n날짜는 2026년 11월 18일입니다.', ev),
          [0, 1],
        );
      });
    },
  );

  group('labeled synthetic cases (citation_infer_cases.dart)', () {
    test('no mis-link, and nothing the old behavior linked is lost', () {
      var gained = 0;
      for (final (id, _, pack, answer, truth) in cases) {
        final got = inferCitations(answer, packs[pack]!);
        expect(got.where((i) => !truth.contains(i)), isEmpty, reason: id);
        expect(got, containsAll(oldLinks[id]!), reason: id);
        gained += got.length - oldLinks[id]!.length;
      }
      expect(cases.length, greaterThanOrEqualTo(40));
      expect(gained, 34); // new correct links on the set
    });

    test('the cases that must stay silent do', () {
      for (final (id, _, pack, answer, truth) in cases) {
        if (truth.isEmpty) {
          expect(inferCitations(answer, packs[pack]!), isEmpty, reason: id);
        }
      }
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
