import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:pageblink_server/src/rag_endpoints/project_endpoint.dart';
import 'package:pageblink_server/src/sample/sample_note.dart';
import 'package:test/test.dart';

void main() {
  test('sample bodies fit one chunk so a question finds them in one hit', () {
    for (final s in [SampleNote.en, SampleNote.ko]) {
      expect(s.body.length, lessThan(900));
      expect(chunkPages([(page: 1, text: s.body)]), hasLength(1));
    }
  });

  test('titles carry the prefix the app uses to spot the sample', () {
    expect(SampleNote.en.title, startsWith('Sample · '));
    expect(SampleNote.ko.title, startsWith('샘플 · '));
  });

  test('only ko* locales get the Korean sample', () {
    expect(SampleNote.forLocale('ko'), same(SampleNote.ko));
    expect(SampleNote.forLocale('ko-KR'), same(SampleNote.ko));
    expect(SampleNote.forLocale('en'), same(SampleNote.en));
    expect(SampleNote.forLocale('ja'), same(SampleNote.en));
    expect(SampleNote.forLocale(''), same(SampleNote.en));
  });

  test('seed hash matches the English body, not the Korean one', () {
    expect(SampleNote.seedHash, sha256Hex(SampleNote.en.body));
    expect(SampleNote.seedHash, isNot(sha256Hex(SampleNote.ko.body)));
  });

  test('project names are trimmed and bounded', () {
    expect(cleanProjectName('  Team  '), 'Team');
    expect(() => cleanProjectName('   '), throwsArgumentError);
    expect(() => cleanProjectName('a' * 61), throwsArgumentError);
    expect(cleanProjectName('a' * 60), hasLength(60));
  });
}
