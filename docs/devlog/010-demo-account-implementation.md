# 010 · 데모 체험 로그인(demo 계정) 구현·배포

| 항목 | 값 |
|---|---|
| 상태 | ✅ 배포 완료 (7차 `8445f02`, 후속 8차 `c99822f`) · ⚠️ 브라우저 수동 확인 대기 |
| 단계 | 기능 추가 · 서버 + 앱 |
| 시작 | 2026-10-16 09:06 KST ([plan 014](../plan/014-demo-account.md) 최초 작성 시각) |
| 완료 | 확인 필요 (배포 완료 시각은 전달받지 못함. 커밋 시각 09:56 KST 이후) |
| 소요 | 확인 필요 |
| 최종 수정 | 2026-10-16 10:32 KST |

## 목표
- 로그인 카드의 `데모 체험하기`(EN `Try the demo`) 버튼 하나로, 가입·인증 코드 없이 미리 만든 **공유 demo 계정**으로 들어가 노트·PDF·Ask를 체험하게 한다.
- 운영에서 환경 설정 플래그로 켜고 끌 수 있고, 꺼 두면 기능이 통째로 사라진다.

## 작업 로그
시각은 문서·git에서 확인한 값이다 (KST, 2026-10-16). 배포 시각은 전달받지 못했다.
- `09:06` [plan 014](../plan/014-demo-account.md) 최초 작성 (구현 전 검토용 명세)
- `09:22` [research 026](../research/026-demo-account-api-verification.md) Serverpod 4.0.4 소스 검증 (서버는 실행하지 않음)
- `09:30` research 026 반영: 설계 변경 D1~D6, §10 값 PM 확정, [ADR 020](../adr/020-demo-account-shared-user.md) 구체화
- `09:56` 커밋 `8445f02` (`feat(app,server): try-the-demo sign-in with sample content (plan 014, ADR 020)`), push `74e1e44..8445f02`, 파일 49개 ✅ (git 작성 시각)
- 배포 (7차): 빌드 151초 · 롤아웃 70초 — 시작·종료 시각은 확인 필요
- `10:07` plan 014 · ADR 020 · 012 · 이 기록에 결과 반영
- `10:17` 커밋 `c99822f` (`feat(app,server): richer demo sample notes and demo-specific Ask examples`), push `925d363..c99822f`, 파일 9개 ✅ (git 작성 시각)
- 배포 (8차): 빌드 139초 · 롤아웃 82초 — 시작·종료 시각은 확인 필요
- `10:26`~`10:28` [research 028](../research/028-locale-samples.md)(언어별 demo 계정·SamplePack)·[research 027](../research/027-citation-span-highlight.md)(출처 구간 하이라이트) 작성 (조사일 기준, 구현 없음)
- `10:32` plan 014 · 012 · 이 기록에 8차 결과 반영

## 결과

### 만든 것

| 영역 | 내용 |
|---|---|
| 서버 | 공유 demo 사용자(`demo@pageblink.invalid`) 멱등 프로비저닝(`await pod.start()` 뒤), 공개 `DemoEndpoint.status()`·`signIn()`, 쓰기 한도·샘플 보호·프로젝트 금지·Ask 상한 가드, 24시간 정리(비샘플 문서 + demo 리프레시 토큰) |
| 시드 | 자체 제작 사용 가이드: 노트 2개(EN 1·KO 1) + PDF 1개(`web/samples/pageblink-guide.pdf`) |
| 클라이언트 | 로그인 카드 데모 버튼, 홈 배너(`데모 모드 · 새 항목 5/5개 남음`), 개인정보 안내, 한도·샘플 잠금·질문 한도 안내, 배너 `가입하기` |
| 플래그 | `demoEnabled`(기본 꺼짐). 운영은 `scloud variable set DEMO_ENABLED true` |
| 확정 값 | 문서 5개(샘플 제외, PDF 포함) · 24시간 정리 · Ask 일일 50회 · 샘플 수정·삭제·재색인 불가 · 프로젝트 생성·초대 불가 ([plan 014 §10](../plan/014-demo-account.md)) |
| DB | 마이그레이션 없음 ✅ (`contentHash` 표식 사용, 새 컬럼·테이블 없음) |

### 검증

| 항목 | 결과 |
|---|---|
| 클라이언트 `flutter test` | ✅ 1,150개 통과 (기존 1,106 + 신규 44) |
| 클라이언트 `flutter analyze` | ✅ 이슈 0 |
| 서버 `dart test` | ✅ 48개 통과 (외부 API 키 4종을 해제한 환경에서 실행) |
| 서버 `dart analyze` | ✅ 이슈 0 |
| 배포 | ✅ 빌드 151초 · 롤아웃 70초 · 마이그레이션 없음 |
| 정적 파일 | ✅ 200 + 새 문자열 존재 |
| `status()` (비로그인) | ✅ `enabled:true, createLimit:5, askLimit:50` |
| `signIn()` | ✅ 토큰 수령 |
| 로그인 후 `status()` | ✅ `isDemo:true, createRemaining:5, askRemaining:50` |
| 문서 목록 | ✅ 샘플 3개(노트 2 + PDF 1) 모두 `ready`, PDF 3쪽 |
| 서버 2회 부팅 | ✅ 중복 없음 |
| Ask 1회 | ✅ 성공, `askRemaining` 50→49, 인용이 PDF 3쪽을 가리킴 |
| 로그인 화면 · `greeting/hello` | ✅ 200 |
| 인증 없는 `document/list` | ✅ 401 |
| 브라우저 수동 시나리오 11개 | ⚠️ 미확인 — [plan 014 §12.2](../plan/014-demo-account.md) |

### 운영 메모

| 항목 | 내용 |
|---|---|
| API 호스트 | `https://pageblink.api.serverpod.space` (웹 호스트 `pageblink.serverpod.space`와 다름) |
| 호출 형식 | `POST /<endpoint>/<method>`. `POST /demo {"method":...}` 형식은 405 |
| 켜기 | `scloud variable set DEMO_ENABLED true` → 재배포 |
| 끄기 | `scloud variable set DEMO_ENABLED false` → `scloud deploy --redeploy` (변수만 바꿔서는 반영 안 됨) |
| 끈 뒤 | 만든 demo 데이터는 남음. 열려 있던 demo 세션에는 한도·보호가 계속 적용됨 (PM 판단) |

## 후속 변경(8차, `c99822f`)

7차 배포 직후 데모 샘플의 내용과 Ask 예시를 보강한 후속 변경입니다. 새 기능이 아니라 같은 기능의 콘텐츠·표시 조정이라 새 devlog를 만들지 않고 이 기록에 붙입니다.

### 변경 내용

| 영역 | 내용 |
|---|---|
| 샘플 노트 | 영어 3개로 교체: `PageBlink tour: try it in 5 minutes`, `Q4 launch plan`, `Weekly sync: week 3 of October`. 각각 1청크 · 900자 미만. PDF `PageBlink guide`는 그대로 |
| 옛 샘플 | `Getting started with PageBlink`, `답변의 출처 따라가기` 2개는 `legacy` 해시 목록으로 **시드 시 1회 정리** |
| Ask 예시 | 데모 계정이면 데모 전용 4개만 표시(`demoSuggestions`, EN/KO) |
| 파일 | 9개: 클라이언트 `l10n.dart`·`ask_screen.dart`·`ask_suggestions.dart`·테스트 2개, 서버 `demo_samples.dart`·`demo_seed.dart`·테스트 2개 ✅ |
| DB | 마이그레이션 없음 ✅ |

### 검증

| 항목 | 결과 |
|---|---|
| 클라이언트 `flutter test` | ✅ 1,152개 통과, `flutter analyze` 이슈 0 |
| 서버 `dart test` | ✅ 50개 통과 (API 키 4종을 해제한 환경에서 실행), `dart analyze` 이슈 0 |
| 배포 | ✅ 빌드 139초 · 롤아웃 82초 · 마이그레이션 없음 |
| 샘플 문서 | ✅ 정확히 4개(노트 3 + PDF 1), 모두 `ready`. 옛 샘플 삭제됨 |
| 예시 질문 6개(EN 4 + KO 2) 실제 질문 | ✅ 모두 올바른 문서를 인용. EN 질문 1·2는 `Q4 launch plan` + `Weekly sync` 2개 문서 인용 |
| 영어 노트에 한국어 질문 | ✅ 올바른 문서를 찾음(교차 언어 검색). [research 028](../research/028-locale-samples.md)에서 ⚠️(검증 중)였던 항목이 해소됨 |
| Ask 일일 상한 | 질문 6회 후 50 중 44 남음 |

### 관찰: 생성 단계 환각 ⚠️

- 한국어 질문 1건(출시일·예산)에서 모델이 **노트에 없는 연도 "2024"** 를 지어냈습니다.
- 검색·인용은 정상이었습니다. 즉 검색 단계가 아니라 **생성 단계** 문제입니다.
- 6개 질문 중 1건만 관찰한 값이라 빈도는 알 수 없습니다 ⚠️.
- 노트에 연도를 명시하면 줄일 수 있어, **다음 샘플 변경 때 반영**할 예정입니다(아직 적용 전).

## 문제와 해결
| # | 문제 | 해결 |
|---|---|---|
| 1 | 라이브 확인 시 API 호스트·호출 형식이 예상과 달랐음 (웹 호스트로 `POST /demo {"method":...}` → 405) | API 호스트 `pageblink.api.serverpod.space`, `POST /<endpoint>/<method>`로 호출해 확인 |
| 2 | 변수만 바꿔서는 플래그가 반영되지 않음 | `scloud deploy --redeploy`로 반영 (plan 014 U1 해소) |
| 3 | 로그에 무료 모델 OpenRouter 429 | 모델 로테이션으로 처리됨 ([ADR 014](../adr/014-model-catalog-and-rotation.md)). 조치 없음 |

## 결정 (→ ADR 링크)
- [ADR 020 · 공유 demo 사용자 + 환경 설정 플래그](../adr/020-demo-account-shared-user.md) — 배포 후 기록을 ADR 끝에 덧붙임. 결정은 그대로(채택).
- 설계 변경 D1~D6(시작 시점 `pod.start()` 뒤, 일반 변수 주입, 샘플 보호 4곳, 시드 방식 A, `DemoLimitException`, 샘플 제목 접두 금지)은 [plan 014 §6~§8](../plan/014-demo-account.md)·ADR 020 결정 절에 있음.
- 구현 중 단순화 선택(클라이언트): 한도 도달 시 편집기를 닫으면 입력 텍스트를 버림, 샘플 편집·삭제 버튼은 비활성화하지 않고 서버 안내만 사용, `demoStatus`는 `boardRefresh` 시점에 갱신.

## 다음 할 일
- 다음 샘플 변경 때 노트 본문에 연도를 명시(8차 관찰 환각 완화). 본문이 바뀌면 해시가 달라져 옛 해시를 `legacy`에 넣어야 하고, PDF 본문과 맞는 숫자도 함께 점검
- 언어별 demo 계정(D1)·`SamplePack`(S1) 구현 — [research 028](../research/028-locale-samples.md), 구현 대기(ADR 후보 021)
- ⚠️ 브라우저 수동 확인 11개 (사용자) — [plan 014 §12.2](../plan/014-demo-account.md)
- ⚠️ U3: `.invalid` 수신자에 대한 Cloud 이메일 API 처리 확인 (방문자가 비밀번호 재설정을 호출할 때만 발생)
- 알려진 한계(허용): `askRemaining` 카운터는 메모리라 재시작 시 초기화 · 공개 `signOutAllDevices`로 한 방문자가 모든 demo 세션을 끊을 수 있음(R16) · 한도 검사·삽입이 원자적이지 않음 · 다중 인스턴스 동시 부팅 시 샘플 중복 가능성
- 유지 주의: 샘플 PDF 본문에 `5개`·`24시간`·`50회`가 하드코딩되어 있어 상수를 바꾸면 PDF를 다시 만들어야 함
- 후속 후보: 슬롯 고갈·개인정보 노출이 문제가 되면 `AnonymousIdp`(방문자별 임시 계정)로 전환 (새 ADR)

## 변경 이력
- `2026-10-16 10:07` 최초 작성 (사실은 릴리스·클라이언트 엔지니어 보고와 plan 014·git 로그 기준. 배포 시각·소요는 확인 필요)
- `2026-10-16 10:32` 후속 변경(8차 `c99822f`) 절·작업 로그·다음 할 일 추가, 상태 갱신. 7차까지의 내용은 수정하지 않음
