import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_flutter/app/l10n.dart';

void main() {
  test('scopeSummary covers personal / projects / empty', () {
    expect(L.en.scopeSummary(true, 2), 'Sources: My documents + 2 projects');
    expect(L.en.scopeSummary(true, 0), 'Sources: My documents only');
    expect(L.en.scopeSummary(false, 1), 'Sources: 1 project');
    expect(L.en.scopeSummary(false, 0), 'Nothing selected to search');
    expect(L.ko.scopeSummary(true, 2), '출처: 내 문서 + 프로젝트 2개');
    expect(L.ko.scopeSummary(true, 0), '출처: 내 문서만');
    expect(L.ko.scopeSummary(false, 3), '출처: 프로젝트 3개');
    expect(L.ko.scopeSummary(false, 0), '검색할 곳이 없어요');
  });

  test('UX round 2 strings (account, projects, note color)', () {
    expect(L.ko.projectsSummary(2, 5, 3), '프로젝트 2개 · 노트 5개, PDF 3개');
    expect(L.en.projectsSummary(2, 5, 3), '2 projects · 5 notes, 3 PDFs');
    expect(L.ko.projectCounts(5, 3), '노트 5개 · PDF 3개');
    expect(L.en.projectCounts(5, 3), '5 notes · 3 PDFs');
    expect(L.ko.noteColorOf('로즈'), '노트 색: 로즈');
    expect(L.en.noteColorAutoOf('Rose'), 'Auto (Rose)');
    expect(L.ko.accountMenuSemantics('a@b.c'), '계정: a@b.c');
    expect(L.en.appVersionLabel('1.2'), 'PageBlink v1.2');
    expect(L.ko.copyAccountId, '계정 ID 복사');
    expect(L.en.copyAccountId, 'Copy account ID');
    expect(L.en.projectOwner, 'Owner');
    expect(L.ko.projectMember, '멤버');
  });

  test('modelNote drops free/price parts, translates known, keeps unknown', () {
    const free = 'free · recommended · multilingual · fast';
    expect(L.en.modelNote(free), 'recommended · multilingual · fast');
    expect(L.ko.modelNote(free), '추천 · 다국어 · 빠름');
    expect(L.en.modelNote(r'paid $0.25/$1.50 · fast'), 'fast');
    expect(L.ko.modelNote('free · brand new'), 'brand new');
    // The notes of the catalog (server llm_catalog.dart) are all translated.
    const gemma = 'free · multilingual · unstable · upstream limits';
    expect(L.en.modelNote(gemma), 'multilingual · unstable · upstream limits');
    expect(L.ko.modelNote(gemma), '다국어 · 불안정 · 제공처 한도 있음');
    expect(
      L.ko.modelNote(r'paid $0.75/$3.75 · quality · slower first token (~5s)'),
      '고품질 · 첫 글자가 느림(약 5초)',
    );
    expect(
      L.ko.modelNote('free · lightweight · unstable · may not respond'),
      '가벼움 · 불안정 · 응답이 없을 수 있음',
    );
    expect(
      L.ko.modelNote('free · recommended · large model · fast'),
      '추천 · 큰 모델 · 빠름',
    );
    expect(L.en.modelNote('free'), isNull);
    expect(L.en.modelNote(null), isNull);
  });
}
