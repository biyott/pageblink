import 'package:pageblink_server/src/rag/context_builder.dart';
import 'package:pageblink_server/src/rag/line_chunker.dart';
import 'package:test/test.dart';

const _note =
    '# Q4 launch plan\n\n'
    '> Goal: ship before the holiday freeze.\n\n'
    '## Numbers\n'
    '- **Marketing budget:** 12M for Q4\n'
    '- **Launch date:** moved to Nov 18\n'
    '- **Beta testers:** 20 people\n\n'
    '## Timeline\n'
    '1. Oct 28: feature freeze\n'
    '2. Nov 4: beta invites\n'
    '3. Nov 18: public launch\n';

HitInput _hit(List<LineChunk> cs, String needle, {int doc = 1, int page = 1}) {
  final c = cs.firstWhere((c) => c.text.contains(needle));
  return HitInput(
    documentId: doc,
    page: page,
    ordinal: c.ordinal,
    text: c.text,
  );
}

DocInput? _docs(int id) => id == 1
    ? const DocInput(kind: 'note', title: 'Q4 launch plan', body: _note)
    : null;

void main() {
  final cs = chunkNote(_note, docTitle: 'Q4 launch plan');

  test('a hit gets its heading section as context, offset and path', () {
    final plans = planSources(
      [_hit(cs, 'Launch date')],
      doc: _docs,
      pageText: (_, _) => null,
    );
    final p = plans.single;
    expect(p.evidence, '- **Launch date:** moved to Nov 18');
    expect(p.title, 'Q4 launch plan › Numbers (note)');
    expect(
      p.context,
      '## Numbers\n'
      '- **Marketing budget:** 12M for Q4\n'
      '- **Launch date:** moved to Nov 18\n'
      '- **Beta testers:** 20 people',
    );
    expect(_note.startsWith(p.evidence, p.quoteStart!), isTrue);
    expect(p.contextRef, isNull);
  });

  test('hits in the same section: one context, the rest point to it', () {
    final plans = planSources(
      [
        _hit(cs, 'Launch date'),
        _hit(cs, 'public launch'),
        _hit(cs, 'Marketing budget'),
      ],
      doc: _docs,
      pageText: (_, _) => null,
    );
    expect(plans, hasLength(3));
    expect(plans[0].context, contains('## Numbers'));
    expect(plans[1].context, contains('## Timeline'));
    expect(plans[2].context, isNull);
    expect(plans[2].contextRef, 0);
    // each keeps its own line as evidence: [n] cites the small unit
    expect(plans[2].evidence, '- **Marketing budget:** 12M for Q4');
    expect(_note.startsWith(plans[2].evidence, plans[2].quoteStart!), isTrue);
  });

  test('a duplicate line gets the offset of its own occurrence', () {
    const body = '## Today\n- [ ] Call back\n\n## Tomorrow\n- [ ] Call back\n';
    final dup = chunkNote(body);
    expect(dup, hasLength(2));
    final plans = planSources(
      [
        HitInput(documentId: 1, page: 1, ordinal: 1, text: dup[1].text),
      ],
      doc: (_) => const DocInput(kind: 'note', title: 't', body: body),
      pageText: (_, _) => null,
    );
    expect(plans.single.quoteStart, dup[1].start);
    expect(plans.single.quoteStart, isNot(body.indexOf('- [ ] Call back')));
  });

  test('a stored chunk that no longer matches the text: evidence only', () {
    final stale = HitInput(
      documentId: 1,
      page: 1,
      ordinal: 2,
      text: 'a line that was edited away',
    );
    final plans = planSources([stale], doc: _docs, pageText: (_, _) => null);
    expect(plans.single.context, isNull);
    expect(plans.single.contextRef, isNull);
    expect(plans.single.quoteStart, isNull);
    expect(plans.single.evidence, 'a line that was edited away');
    // unknown document: still a source, labelled like before
    final gone = planSources(
      [HitInput(documentId: 9, page: 2, ordinal: 0, text: 'x')],
      doc: _docs,
      pageText: (_, _) => null,
    );
    expect(gone.single.title, 'Document (p.2)');
  });

  test('a section over 1,000 chars shrinks to a window of whole chunks', () {
    final items = [for (var i = 0; i < 60; i++) '- item number $i of the list'];
    final body = '## Long\n${items.join('\n')}\n';
    final big = chunkNote(body);
    final plans = planSources(
      [HitInput(documentId: 1, page: 1, ordinal: 30, text: big[30].text)],
      doc: (_) => DocInput(kind: 'note', title: 't', body: body),
      pageText: (_, _) => null,
    );
    final ctx = plans.single.context!;
    expect(ctx.length, lessThanOrEqualTo(noteContextMax));
    expect(ctx, contains(big[30].text));
    expect(body, contains(ctx));
    expect(ctx, startsWith('- item'));
  });

  group('pdf', () {
    final page = List.generate(
      12,
      (i) =>
          'Sentence $i of the page says something that is long enough to be '
          'one chunk on its own, more or less, because it keeps going.',
    ).join(' ');
    final pcs = chunkPdfPage(1, page);
    DocInput? pdf(int id) => const DocInput(kind: 'pdf', title: 'Guide');
    HitInput hit(int i) => HitInput(
      documentId: 2,
      page: 1,
      ordinal: i,
      text: pcs[i].text,
    );

    test('context is the hit +-2 chunks of its page; no offset', () {
      expect(pcs.length, greaterThanOrEqualTo(8));
      final p = planSources(
        [hit(4)],
        doc: pdf,
        pageText: (_, _) => page,
      ).single;
      expect(p.title, 'Guide (p.1)');
      expect(p.quoteStart, isNull);
      expect(p.context, contains(pcs[4].text));
      expect(p.context, contains(pcs[2].text));
      expect(p.context, isNot(contains(pcs[0].text)));
      expect(page, contains(p.context));
    });

    test('hits whose windows touch share one context', () {
      final plans = planSources(
        [hit(4), hit(5)],
        doc: pdf,
        pageText: (_, _) => page,
      );
      expect(plans[0].context, isNotNull);
      expect(plans[1].context, isNull);
      expect(plans[1].contextRef, 0);
    });

    test('a large document page is found by its 300-char chunks too', () {
      final c300 = chunkPdfPage(
        1,
        page,
        rules: const ChunkRules(targetChars: 300),
      );
      final plans = planSources(
        [HitInput(documentId: 2, page: 1, ordinal: 0, text: c300[1].text)],
        doc: pdf,
        pageText: (_, _) => page,
      );
      expect(plans.single.context, contains(c300[1].text));
    });
  });

  group('budget', () {
    final body =
        '## A\n${List.generate(30, (i) => '- a line of text number $i padded out').join('\n')}\n';
    final bs = chunkNote(body);

    test('context goes first, lowest-ranked first; evidence is kept', () {
      // 3 distinct windows would exceed the budget
      final docs = {
        for (var d = 1; d <= 3; d++)
          d: DocInput(kind: 'note', title: 'N$d', body: body),
      };
      final hits = [
        for (var d = 1; d <= 3; d++)
          HitInput(documentId: d, page: 1, ordinal: 10, text: bs[10].text),
      ];
      final loose = planSources(
        hits,
        doc: (id) => docs[id],
        pageText: (_, _) => null,
      );
      expect(loose.every((p) => p.context != null), isTrue);
      final one = loose[0].context!.length;
      final tight = planSources(
        hits,
        doc: (id) => docs[id],
        pageText: (_, _) => null,
        maxChars: one + 3 * bs[10].text.length + 5,
      );
      expect(tight, hasLength(3));
      expect(tight[0].context, isNotNull);
      expect(tight[1].context, isNull);
      expect(tight[2].context, isNull);
      expect(
        tight.fold<int>(0, (a, p) => a + p.length),
        lessThanOrEqualTo(one + 3 * bs[10].text.length + 5),
      );
    });

    test('then the lowest-ranked hits go; the result is a prefix', () {
      final hits = [
        for (var i = 0; i < 20; i++)
          HitInput(documentId: 1, page: 1, ordinal: i, text: bs[i].text),
      ];
      final plans = planSources(
        hits,
        doc: (_) => DocInput(kind: 'note', title: 'N', body: body),
        pageText: (_, _) => null,
        maxChars: 200,
      );
      expect(plans.length, lessThan(hits.length));
      expect(plans, isNotEmpty);
      for (final (i, p) in plans.indexed) {
        expect(p.evidence, hits[i].text);
        expect(p.context, isNull);
      }
      expect(
        plans.fold<int>(0, (a, p) => a + p.length),
        lessThanOrEqualTo(200),
      );
    });

    test('the default budget is 6,000 chars', () {
      expect(contextBudgetChars, 6000);
    });

    test('a dropped carrier takes its pointers with it', () {
      final hits = [
        for (final i in [10, 11, 12])
          HitInput(documentId: 1, page: 1, ordinal: i, text: bs[i].text),
      ];
      final loose = planSources(
        hits,
        doc: (_) => DocInput(kind: 'note', title: 'N', body: body),
        pageText: (_, _) => null,
      );
      expect(loose[0].context, isNotNull);
      expect(loose[1].contextRef, 0);
      final tight = planSources(
        hits,
        doc: (_) => DocInput(kind: 'note', title: 'N', body: body),
        pageText: (_, _) => null,
        maxChars: 3 * bs[10].text.length + 60,
      );
      expect(
        tight.every((p) => p.context == null && p.contextRef == null),
        isTrue,
      );
    });
  });

  group('citation quote', () {
    final plan = SourcePlan(
      documentId: 1,
      page: 1,
      title: 't',
      evidence: 'Launch date: Nov 18',
      quoteStart: 40,
    );

    test('[n] markers cite the whole evidence line at its offset', () {
      final q = citationQuote(plan, '');
      expect(q.quote, 'Launch date: Nov 18');
      expect(q.start, 40);
      expect(citationQuote(plan, 'Launch date: Nov 18').start, 40);
    });

    test('a model-cited part moves the offset with it', () {
      final q = citationQuote(plan, 'Nov 18');
      expect(q.quote, 'Nov 18');
      expect(q.start, 40 + 'Launch date: '.length);
      expect(citationQuote(plan, 'something else').start, isNull);
    });

    test('no offset stays null', () {
      final p = SourcePlan(documentId: 1, page: 2, title: 't', evidence: 'abc');
      expect(citationQuote(p, '').start, isNull);
      expect(citationQuote(p, 'b').start, isNull);
    });
  });
}
