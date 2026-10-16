import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/rag/chat_context.dart';
import 'package:test/test.dart';

ChatTurn _t(String q, String a) => ChatTurn(q, a);

void main() {
  group('cleanAnswer', () {
    test('drops half- and full-width markers and the keyword notice', () {
      expect(
        cleanAnswer('Budget is 12M [1][2]. Date 【3】 is set ［4］.', 800),
        'Budget is 12M. Date is set.',
      );
      expect(
        cleanAnswer(
          '$keywordNoticeEn'
          'The answer [1].',
          800,
        ),
        'The answer.',
      );
      expect(
        cleanAnswer(
          '$keywordNoticeKo'
          '답 [2]',
          800,
        ),
        '답',
      );
    });

    test('keeps the start, with an ellipsis, and never splits a pair', () {
      expect(cleanAnswer('a' * 900, 800), '${'a' * 800}…');
      // 799 letters + a 2-unit emoji: the cut falls inside the pair
      final s = '${'a' * 799}😀tail';
      final out = cleanAnswer(s, 800);
      expect(out, '${'a' * 799}…');
      expect(cleanAnswer('short', 800), 'short');
    });
  });

  group('buildHistory', () {
    test('newest first, oldest dropped, no holes', () {
      // cost of each: 10 + 40 + 40 = 90
      final past = [
        for (var i = 1; i <= 5; i++) _t('q$i${'x' * 8}', 'a' * 40),
      ];
      final h = buildHistory(past, budget: 300, answerChars: 800);
      expect(h.map((t) => t.question.substring(0, 2)), ['q3', 'q4', 'q5']);
      // a short old turn is not squeezed in after a long one did not fit
      final mixed = [_t('q', 'a'), _t('q' * 100, 'a' * 100), _t('q', 'a')];
      expect(
        buildHistory(mixed, budget: 100, answerChars: 800).length,
        1,
        reason: 'stops at the first turn that does not fit',
      );
    });

    test('all nine turns of a short conversation fit the default budget', () {
      final past = [for (var i = 0; i < 9; i++) _t('q' * 80, 'a' * 500)];
      expect(buildHistory(past, budget: 8000, answerChars: 800), hasLength(9));
    });

    test('long answers are cut to the answer length', () {
      final h = buildHistory(
        [_t('q', 'a' * 2000)],
        budget: 8000,
        answerChars: 800,
      );
      expect(h.single.answer, '${'a' * 800}…');
    });

    test(
      'only the newest fits: its answer is shortened (min 200), else none',
      () {
        final long = _t('q', 'a' * 800);
        final h = buildHistory([long], budget: 500, answerChars: 800);
        expect(h.single.answer.length, lessThanOrEqualTo(500));
        expect(h.single.answer.endsWith('…'), isTrue);
        expect(buildHistory([long], budget: 200, answerChars: 800), isEmpty);
        expect(buildHistory(const [], budget: 8000, answerChars: 800), isEmpty);
      },
    );

    test('markers are removed from what goes to the model', () {
      final h = buildHistory(
        [_t('q', 'x [1] y 【2】')],
        budget: 8000,
        answerChars: 800,
      );
      expect(h.single.answer, 'x y');
    });
  });

  test('searchQuery appends the previous question, cut to the join length', () {
    expect(searchQuery('now', null, 600), 'now');
    expect(searchQuery('now', '  ', 600), 'now');
    expect(searchQuery('now', 'before', 600), 'now\nbefore');
    final q = searchQuery('now', 'p' * 1000, 600);
    expect(q, 'now\n${'p' * 600}');
  });

  test('capQuestion trims and cuts at the limit', () {
    expect(capQuestion('  hi  ', 2000), 'hi');
    expect(capQuestion('x' * 2500, 2000).length, 2000);
    expect(titleOf('a\n\n  b ${'c' * 100}').length, 80);
    expect(titleOf('a\n\n b'), 'a b');
  });

  test('historyBudget: the sources and question come first', () {
    expect(
      historyBudget(
        contextBudget: 8000,
        promptMax: 20000,
        sourcesChars: 6000,
        questionChars: 100,
      ),
      8000,
    );
    expect(
      historyBudget(
        contextBudget: 8000,
        promptMax: 10000,
        sourcesChars: 6000,
        questionChars: 500,
      ),
      2000,
    );
    expect(
      historyBudget(
        contextBudget: 8000,
        promptMax: 5000,
        sourcesChars: 6000,
        questionChars: 0,
      ),
      0,
    );
  });
}
