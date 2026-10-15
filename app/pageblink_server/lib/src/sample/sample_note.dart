import '../rag/chunker.dart';

/// The to-do list note every new account gets (research 021 §G). Keep each
/// body under one chunk (900 chars) so a question finds it in one hit.
class SampleNote {
  final String title;
  final String body;

  const SampleNote(this.title, this.body);

  static const en = SampleNote('Sample · My to-do list', '''
# My to-do list

## Today
- [x] Reply to Sam about the venue
- [x] Buy coffee beans
- [ ] Send the invoice to Acme (due 5 pm)

## This week
- [ ] Book the dentist (call before Wednesday)
- [ ] Finish the slides for Friday's team meeting
- [ ] Renew passport (needs 2 photos)

## Later
- [ ] Plan a weekend trip to Busan
- [ ] Clean out the garage
''');

  static const ko = SampleNote('샘플 · 할 일 목록', '''
# 내 할 일 목록

## 오늘
- [x] 민수에게 장소 관련 답장 보내기
- [x] 커피 원두 사기
- [ ] 한빛상사에 청구서 보내기 (오후 5시까지)

## 이번 주
- [ ] 치과 예약하기 (수요일 전에 전화)
- [ ] 금요일 팀 회의 발표 자료 마무리
- [ ] 여권 갱신하기 (사진 2장 필요)

## 나중에
- [ ] 주말 부산 여행 계획 세우기
- [ ] 창고 정리하기
''');

  /// `ko*` gets the Korean sample, everything else English.
  static SampleNote forLocale(String? locale) =>
      (locale ?? '').toLowerCase().startsWith('ko') ? ko : en;

  /// Body hash of the untouched English seed; identifies an unprocessed
  /// sample (the signup hook always inserts English).
  static final seedHash = sha256Hex(en.body);
}
