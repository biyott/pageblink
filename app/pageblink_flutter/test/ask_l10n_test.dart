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

  test('modelNote drops free/price parts, translates known, keeps unknown', () {
    const free = 'free · recommended · multilingual · fast';
    expect(L.en.modelNote(free), 'recommended · multilingual · fast');
    expect(L.ko.modelNote(free), '추천 · 다국어 · 빠름');
    expect(L.en.modelNote(r'paid $0.25/$1.50 · fast'), 'fast');
    expect(L.ko.modelNote('free · brand new'), 'brand new');
    expect(L.en.modelNote('free'), isNull);
    expect(L.en.modelNote(null), isNull);
  });
}
