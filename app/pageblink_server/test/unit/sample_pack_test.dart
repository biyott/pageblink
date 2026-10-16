import 'dart:io';

import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:pageblink_server/src/rag/line_chunker.dart';
import 'package:pageblink_server/src/rag/preview_text.dart';
import 'package:pageblink_server/src/rag_endpoints/project_endpoint.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:test/test.dart';

void main() {
  final packs = SamplePacks.all;

  test('ids and (audience, locale) are unique', () {
    expect(packs.map((p) => p.id).toSet(), hasLength(packs.length));
    expect(
      packs.map((p) => '${p.audience.name}/${p.locale}').toSet(),
      hasLength(packs.length),
    );
  });

  test('note hashes never collide; each demo language has its own PDF', () {
    final noteHashes = [
      for (final p in packs)
        for (final n in p.notes) n.hash,
    ];
    expect(noteHashes.toSet(), hasLength(noteHashes.length));
    final pdfs = {for (final p in packs) ?p.pdf?.hash};
    expect(pdfs, hasLength(2));
    expect(SamplePacks.demoEn.pdf, isNot(same(SamplePacks.demoKo.pdf)));
    expect(SamplePacks.demoPdfHashes, pdfs);
    expect(noteHashes.toSet().intersection(pdfs), isEmpty);
  });

  test('every note is indexed line by line, each chunk a slice of it', () {
    for (final p in packs) {
      for (final n in p.notes) {
        final chunks = chunkNote(n.body, docTitle: n.title);
        // several short chunks, none a whole-note blob
        expect(chunks.length, greaterThanOrEqualTo(4), reason: n.title);
        for (final c in chunks) {
          expect(n.body.substring(c.start, c.end), c.text, reason: n.title);
          expect(c.text.length, lessThanOrEqualTo(300), reason: n.title);
        }
      }
    }
  });

  test('every question\'s evidence is in chunks, or in their heading path', () {
    for (final p in packs) {
      final texts = <String>[];
      final paths = <String>[];
      for (final n in p.notes) {
        for (final c in chunkNote(n.body, docTitle: n.title)) {
          texts.add(c.text);
          paths.add('${n.title} > ${c.path}');
        }
      }
      for (final (i, page) in (p.pdf?.pages ?? const <String>[]).indexed) {
        texts.addAll([for (final c in chunkPdfPage(i + 1, page)) c.text]);
      }
      for (final q in p.questions) {
        for (final e in q.evidence) {
          final heading = RegExp(r'^#+\s+(.*)$').firstMatch(e)?.group(1);
          final found = heading != null
              ? paths.any((x) => x.contains(heading))
              : texts.any((t) => t.replaceAll(RegExp(r'\s+'), ' ').contains(e));
          expect(found, isTrue, reason: '${p.id}: "${q.text}" -> "$e"');
        }
      }
    }
  });

  test('every question has evidence that is in the pack text', () {
    for (final p in packs) {
      expect(p.questions, hasLength(4), reason: p.id);
      for (final q in p.questions) {
        expect(q.evidence, isNotEmpty, reason: q.text);
        for (final e in q.evidence) {
          expect(p.text, contains(e), reason: '${p.id}: "${q.text}" -> "$e"');
        }
      }
    }
  });

  test('demo questions are in the content language of their pack', () {
    final hangul = RegExp('[가-힣]');
    for (final p in packs) {
      for (final q in p.questions) {
        expect(hangul.hasMatch(q.text), p.locale == 'ko', reason: q.text);
      }
    }
  });

  test('sign-up packs: one note, a label prefix, no PDF', () {
    final en = SamplePacks.signupEn;
    final ko = SamplePacks.signupKo;
    expect(en.notes, hasLength(1));
    expect(ko.notes, hasLength(1));
    expect(en.notes.first.title, startsWith('Sample · '));
    expect(ko.notes.first.title, startsWith('샘플 · '));
    expect(en.pdf, isNull);
    expect(en.accountEmail, isNull);
  });

  test('sign-up hashes are the ones already stored in production', () {
    // Changing a sign-up body orphans every account's existing sample row.
    expect(
      SamplePacks.signupEn.notes.first.hash,
      '23c4284ae8754bbddca9063c22ec2948c973f8fead0b363d31955d401714cbea',
    );
    expect(
      SamplePacks.signupKo.notes.first.hash,
      'f11fe5c7690d1c47857e82503f4eec75d296a61cce95b11d1bb4502b23067415',
    );
  });

  test('forLocale: ko* is Korean, everything else English', () {
    for (final a in SampleAudience.values) {
      for (final l in ['ko', 'ko-KR', 'KO']) {
        expect(SamplePacks.forLocale(l, a).locale, 'ko');
      }
      for (final l in ['en', 'ja', '', null]) {
        expect(SamplePacks.forLocale(l, a).locale, 'en');
      }
      expect(SamplePacks.forLocale('ko', a).audience, a);
    }
  });

  test('byHash finds the pack of a note or the PDF', () {
    for (final p in packs) {
      for (final n in p.notes) {
        expect(SamplePacks.byHash(n.hash), same(p));
      }
    }
    expect(SamplePacks.byHash(sha256Hex('my own note')), isNull);
    final signupHash = SamplePacks.signupEn.notes.first.hash;
    expect(
      SamplePacks.byHash(signupHash, audience: SampleAudience.demo),
      isNull,
    );
  });

  test('demo markers: every demo note and the PDF, not sign-up notes', () {
    final demo = SamplePacks.demo.toList();
    expect(demo, isNotEmpty);
    for (final p in demo) {
      expect(SamplePacks.demoMarkers, containsAll(p.hashes));
      expect(p.accountEmail, endsWith('@pageblink.invalid'));
      expect(p.notes, hasLength(3));
      for (final n in p.notes) {
        expect(n.title, isNot(startsWith('Sample · ')));
        expect(n.title, isNot(startsWith('샘플 · ')));
      }
    }
    expect(
      SamplePacks.demoMarkers.intersection(SamplePacks.signupMarkers),
      isEmpty,
    );
    expect(
      {for (final p in demo) p.accountEmail},
      hasLength(demo.length),
      reason: 'one account per pack',
    );
  });

  test('legacy hashes are not demo markers', () {
    expect(
      SamplePacks.demoLegacy.intersection(SamplePacks.demoMarkers),
      isEmpty,
    );
    expect(
      SamplePacks.demoLegacy.intersection(SamplePacks.signupMarkers),
      isEmpty,
    );
  });

  test('the PDFs have several pages with different text', () {
    for (final p in SamplePacks.demo) {
      final pages = p.pdf!.pages;
      expect(pages.length, greaterThanOrEqualTo(2), reason: p.id);
      expect(pages.toSet(), hasLength(pages.length), reason: p.id);
      for (final page in pages) {
        expect(chunkPdfPage(1, page), isNotEmpty, reason: p.id);
      }
    }
  });

  test('the demo guides state the limits the code enforces', () {
    final en = SamplePacks.demoEn.pdf!.pages.join('\n');
    expect(en, contains('up to $demoCreateLimit notes or PDFs'));
    expect(en, contains('${demoRetention.inHours} hours'));
    expect(en, contains('$demoAskDailyLimit per day'));
    // The English PDF is bilingual; the Korean one is Korean only.
    final ko = SamplePacks.demoKo.pdf!.pages.join('\n');
    for (final text in [en, ko]) {
      expect(text, contains('최대 $demoCreateLimit개'));
      expect(text, contains('${demoRetention.inHours}시간 뒤'));
      expect(text, contains('하루 $demoAskDailyLimit회'));
    }
  });

  /// What `upload` stores as the PDF card preview.
  String previewOf(SamplePack p) => pdfPreview([
    for (final (i, t) in p.pdf!.pages.indexed) (page: i + 1, text: t),
  ]);

  test('the PDF card preview starts in the language of the pack', () {
    final en = previewOf(SamplePacks.demoEn);
    final ko = previewOf(SamplePacks.demoKo);
    expect(en, startsWith('Adding your documents'));
    expect(ko, startsWith('문서 추가하기'));
    // No English paragraph in the Korean PDF.
    final latinRun = RegExp('[A-Za-z]{4,} [A-Za-z]{4,} [A-Za-z]{4,}');
    expect(latinRun.hasMatch(SamplePacks.demoKo.pdf!.pages.join('\n')), false);
  });

  test('the English sample PDF stays as deployed (its hash is a marker)', () {
    expect(
      SamplePacks.demoEn.pdf!.hash,
      '4a5d084247372275ba1e7e59da1356b539eb2ef1b0aa8481d1b220ec00528cb0',
    );
  });

  test('every sample PDF original ships under web/ and is small', () {
    final paths = {for (final p in SamplePacks.demo) p.pdf!.assetPath};
    expect(paths, hasLength(SamplePacks.demo.length));
    for (final path in paths) {
      expect(path, startsWith('web/samples/'));
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: path);
      final bytes = f.readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: path);
      expect(bytes.length, lessThan(100 * 1024), reason: path);
    }
  });

  test('the tour note quotes the pack\'s first question', () {
    for (final p in SamplePacks.demo) {
      expect(p.notes.first.body, contains('*${p.questions.first.text}*'));
      expect(p.notes.first.body, contains('$demoCreateLimit'));
    }
  });

  test('project names are trimmed and bounded', () {
    expect(cleanProjectName('  Team  '), 'Team');
    expect(() => cleanProjectName('   '), throwsArgumentError);
    expect(() => cleanProjectName('a' * 61), throwsArgumentError);
    expect(cleanProjectName('a' * 60), hasLength(60));
  });
}
