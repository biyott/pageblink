# 011 · 청크 v2 · 2단 컨텍스트 · U2 인용 하이라이트 · 언어별 demo (9차 배포)

| 항목 | 값 |
|---|---|
| 상태 | ✅ 배포 완료 (9차 `2801184`) · ⚠️ 실기 수동 확인 대기 |
| 단계 | 기능 추가 · 서버 + 앱 |
| 시작 | 2026-10-16 10:26 KST ([research 028](../research/028-locale-samples.md) 조사 시각. 이 작업의 출발점이 된 조사) |
| 완료 | 확인 필요 (배포 완료 시각은 전달받지 못함. 커밋 시각 11:27 KST 이후) |
| 소요 | 확인 필요 |
| 최종 수정 | 2026-10-16 11:53 KST |

## 목표
- 출처(⚡)를 눌렀을 때 노트 **전체**가 칠해지는 문제를 고쳐, 근거가 된 **한 줄**(PDF는 한 문장 묶음)만 하이라이트한다 ([research 027](../research/027-citation-span-highlight.md)).
- 이를 위해 청크를 줄/블록 단위로 바꾸고(청크 v2), LLM에는 큰 단위 맥락을 따로 준다 ([research 029](../research/029-line-level-chunking.md)).
- demo 계정을 UI 언어별로 나누고(en·ko) 샘플·질문 예시를 한 곳(`SamplePack`)에서 관리한다 ([research 028](../research/028-locale-samples.md)).
- 이전 기록 [devlog 010](010-demo-account-implementation.md)의 "다음 할 일" 중 영어 노트 연도 명시, 언어별 demo 계정·`SamplePack`을 이 작업에서 처리했다.

## 작업 로그
시각은 문서·git에서 확인한 값이다 (KST, 2026-10-16). 배포 시각은 전달받지 못했다.
- `10:26`~`10:28` research 028(언어별 demo·SamplePack), research 027(출처 구간 하이라이트) 작성 (devlog 010에 기록된 시각)
- `10:33` 커밋 `92d9835` (research 027·028 문서 등록, 8차 기록) ✅ (git 작성 시각)
- `11:01` research 029(줄 단위 청킹·재색인 설계) 작성 (문서에 적힌 시각)
- `11:27` 커밋 `2801184` (`feat(app,server): per-locale demo accounts, line-level chunks with two-tier context, U2 citation highlight`), push `92d9835..2801184`, 66개 파일(+7,064/-734) ✅ (git 작성 시각)
- 배포 (9차): 빌드 133초 · 롤아웃 66초, DB 마이그레이션 없음 — 시작·종료 시각은 확인 필요
- 재색인 플래그 `REINDEX_ON_BOOT`를 켜서 재배포 → 운영 재색인 5개 문서 13초 — 시각은 확인 필요
- `11:40` research 030(Ask 대화 기록 설계) 작성 (문서에 적힌 시각. 이번 배포 범위 밖, 설계만)
- `11:53` research 029·030 정식 편입, ADR 021·022, plan 012·014 갱신, 이 기록 작성

## 결과

### 만든 것

| 영역 | 내용 |
|---|---|
| 노트 청크 | 줄/블록 단위. 6자 미만 병합, 300자 초과 줄만 분할, 겹침 없음, 마크다운 기호 보존. `chunk.text == body.substring(start, end)` |
| 임베딩 입력 | 제목 경로는 임베딩 입력에만 붙임(저장·인용 텍스트에는 없음) |
| PDF 청크 | 문장 묶음(목표 120자·최대 300자, 큰 문서는 300) |
| 2단 컨텍스트 | 큰 단위는 저장하지 않고 읽을 때 계산(노트=제목 구간, PDF=±2 창). 상위 k 8→16, 컨텍스트 6,000자 |
| 인용 | `Citation.quoteStart` 추가(비테이블 모델) |
| 재색인 | 구버전 표식 `Document.embeddingModel='<모델>#c2'`, 부팅 후 백그라운드 잡(`REINDEX_ON_BOOT`), 문서 사이 1.5초, 429 백오프 30→60→120초, 연속 5회 실패 시 중단, 임베딩 먼저 후 조건부 교체 트랜잭션. 플래그 `CHUNKER_VERSION` |
| demo 계정 | 언어별 2개(en `demo@pageblink.invalid` 승계, ko `demo-ko@pageblink.invalid`). 로그인 시 UI 언어로 자동 선택(`signIn([locale])`, 인자 없으면 en, ko 계정 생성 실패 시 en 폴백) |
| `SamplePack` | 샘플·질문 예시 단일 원천(`id`, `locale`, `audience`, `notes`, `pdf`, `questions[{text, evidence}]`). 질문은 `sampleHints()`로 전달. `evidence`가 본문에 없으면 단위 테스트 실패. DB 테이블 없음 |
| 샘플 본문 | 한국어 샘플은 영어와 같은 사실. 영어 노트 날짜에 연도 명시(8차 환각 대응) |
| 클라이언트 U2 | `CiteBackLayer`(블록 + 3px 레일 + 600ms 펄스, 모션 축소 시 펄스 생략), 인용 바(`⚡n · 답변의 근거`, `‹ n/m ›`, `✕`), PDF 줄별 둥근 채움 + 아래 막대(`pagePaintCallbacks`, 공백 제거 + 인덱스 맵 매칭), 선택 색 중립 회청색(전역), 인용 시트 색 토큰화(다크 모드 수정) |
| DB | 마이그레이션 없음 ✅ |

한국어 샘플 이름: `PageBlink 둘러보기: 5분이면 충분해요`, `4분기 출시 계획`, `주간 회의: 10월 셋째 주` + PDF 공유 ([plan 014 §8.2](../plan/014-demo-account.md)).

색 값 (클라이언트 보고. [research 027 §3](../research/027-citation-span-highlight.md)의 제안 값과 비교):

| 항목 | research 027 제안 | 실제 구현 |
|---|---|---|
| 노트 채움, 라이트 | accent 10~14%, 펄스 28%→12% | `citeFill` accent 12% / 펄스 28% |
| 노트 채움, 다크 | 알파 28%, 레일 `#B7A6FF` | `#B7A6FF` 14% / 펄스 30% |
| PDF 채움 | accent 22% | `#6C4CF5` 22% (다크에서도 동일 — PDF 페이지가 흰색이라) |

한계: 인용 이동은 같은 문서 안에서만, PDF는 펄스 없음, `←→`는 버튼(키보드 단축키 아님).

### 검증

| 항목 | 결과 |
|---|---|
| 클라이언트 `flutter test` | ✅ 1,194개 통과 (기준선 1,156 + 인용 하이라이트 38) |
| 클라이언트 `flutter analyze` | ✅ 이슈 0 |
| 서버 `dart test` | ✅ 146개 통과 |
| 서버 `dart analyze` | ✅ 이슈 0 |
| `flutter build web --release` | ✅ 성공 |
| 배포 | ✅ 빌드 133초 · 롤아웃 66초 · 마이그레이션 없음 |
| 재색인 | ✅ 5개 문서 13초, `ok=5 skipped=0 failed=0`. 로그 `chunk-migration: start tag=google/embeddinggemma-300m#c2 pending=5` → `done`. 이후 부팅은 `pending=0` |
| 문서 상태 | ✅ 영·한 데모 계정 문서 4개씩 `ready`, id 대역 분리(영 8~13, 한 14~17) |
| 샘플 본문 | ✅ 연도(`2026`) 반영, 옛 노트 정리 |
| `sampleHints` | ✅ 언어별 4개 |
| 새 노트 인용 | ✅ 노트(`chunk check`) 저장 시 인용이 `- Beta launch is Dec 5, 2026` 한 줄(28자), `quoteStart`가 `startsWith`와 일치 |
| 샘플 질문 | ✅ 영어 2개·한국어 2개 인용 정상 (quote 16~47자 줄 단위, `quoteStart` 있음) |
| PDF 인용 | ✅ 문장 묶음(128자), `quoteStart`는 null이 정상 |
| 일반 회귀 | ✅ 정상 |
| Ask 사용 | 질문 7회 사용 |

### 수동 확인 체크리스트 (실기 · ⚠️ 사용자가 눈으로)

| # | 확인 | 결과 |
|---|---|---|
| 1 | 노트에서 ⚡를 누르면 해당 줄이 블록 + 레일로 칠해지고 중앙으로 스크롤 | ⚠️ |
| 2 | 마우스 드래그 선택 색(청회색)과 인용 블록이 구분됨 | ⚠️ |
| 3 | PDF에서 ⚡를 누르면 문장이 하이라이트됨 | ⚠️ |
| 4 | 모바일에서 인용 바 줄바꿈, `✕` 터치 크기(36px) | ⚠️ |
| 5 | 다크 모드 | ⚠️ |
| 6 | 펄스 600ms 체감, 모션 축소 설정 | ⚠️ |
| 7 | 긴 PDF를 처음 열 때 중앙 스크롤 | ⚠️ |
| 8 | 한국어 PDF 공백·줄바꿈 차이에도 매칭됨 | ⚠️ |

## 문제와 해결

| # | 관찰 | 처리 |
|---|---|---|
| 1 | 샘플이 부팅 시드 때 이미 v2로 색인돼 있었다(재색인 전부터 줄 단위). 재색인 대상 5개는 데모 영어 PDF·tour 노트 + 다른 사용자 노트 3개 | 예상과 달랐던 점으로 기록. 조치 없음 |
| 2 | 한국어 질문 1건에서 모델이 `【3】`(전각 괄호)로 표기해 인용 0개가 됨 (1회 관찰) | 10차에서 인용 파서 보강 예정 ⚠️ |

## 결정 (→ ADR 링크)
- [ADR 021 · 줄 단위 청크 + 2단 구조 + 부팅 후 재색인](../adr/021-line-level-chunks-two-tier-context.md) — [ADR 002](../adr/002-embedding-embeddinggemma-768.md)에는 상태 칸에 링크만 부기
- [ADR 022 · 언어별 demo 계정 2개 + 단일 SamplePack](../adr/022-per-locale-demo-accounts-sample-pack.md) — [ADR 020](../adr/020-demo-account-shared-user.md)에는 상태 칸에 링크만 부기

## 다음 할 일
- ⚠️ 위 수동 확인 8개 (사용자, 실기)
- ⚠️ 남은 미확인: 운영의 대량 문서 재색인 속도·임베딩 한도, `【n】` 반복 여부(10차에서 보강), 모바일 실기
- 10차: Ask 대화 기록 설계 [research 030](../research/030-ask-sessions.md)의 P0(타이머·로그아웃 훅), demo 세션 만료(유휴 60분/절대 240분), 유료 폴백, `【n】` 파서 보강. [plan 012 §0](../plan/012-session-handoff.md) 참조
- 그다음: Ask 대화 기록 — D1(사용자 대화 삭제 정책), D9(무료 모델 이력 전송 고지) CTO 결정 대기. PDF 대체 경로는 설계 중, 접근성은 그 뒤
- devlog 010의 "다음 할 일" 중 영어 노트 연도 명시와 언어별 demo 계정·`SamplePack`(010은 "ADR 후보 021"로 적었음)은 이 작업에서 닫혔고, 최종 번호는 ADR 022다. 010 본문은 고치지 않았다
- 인용 하이라이트 한계: 인용 이동은 같은 문서 안에서만, PDF는 펄스 없음, `←→` 키보드 단축키 없음

## 변경 이력
- `2026-10-16 11:53` 최초 작성 (사실은 릴리스·클라이언트 엔지니어 보고와 git 로그 기준. 배포 시각·소요는 확인 필요)
