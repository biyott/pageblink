# 028 · 언어별 demo 계정과 샘플 노트·질문 예시 스키마(SamplePack)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 10:26 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용: 코드·문서만 읽음, 서버 실행·저장소 쓰기 없음) |
| 질문 | (1) demo 계정을 언어별로 분리하고 샘플·질문 예시도 따라 분리하려면? (2) 일반 계정도 노트 샘플과 질문 예시를 짝지어 지정하려면 — 스키마가 따로 필요한가? |
| 결론 한 줄 | **스키마는 하나(`SamplePack`)면 된다.** 서버 Dart 상수 `SamplePack{id, locale, audience, notes, pdf?, questions}`를 단일 원천으로 두고, 질문 예시를 서버가 `sampleHints()`로 내려 준다(DB 변경 0). demo는 언어별 계정 2개(`demo@`=en 승계, `demo-ko@`)로 나눈다. |
| 반영 | 결정 대기 (ADR 후보: 021). 이어서 쓸 문서: plan 014 §개정 |

> 상태: 조사 완료. PM이 추천안 D1(demo 계정 2개)·S1(단일 SamplePack)·질문은 샘플 내용 언어 기준·Ask 상한 전체 공유로 확정 후 CTO 보고(2026-10-16). 구현 대기.

> 표기: ✅ 코드·문서를 직접 읽어 확인 · ⚠️ 미확인/추정. 줄 번호는 2026-10-16 10:26 기준 `main`(HEAD `c99822f`) 워크트리 값. 영어 노트에 한국어로 질문해 검색되는지는 라이브 검증 중이라 ⚠️로 두고 두 경우를 모두 다룬다.

## 핵심 결론

1. 서버는 가입 시 언어를 모르고(항상 영어 삽입, 첫 로그인에 클라이언트가 `ensureSample(locale)`로 현지화), 샘플↔질문 짝짓기는 **제목 접두사 문자열 일치**이며 질문은 클라이언트 l10n에 하드코딩돼 있다 ✅.
2. demo 계정은 단일 static `demoUserId`·전역 `askCounter`·전역 시드/purge로 계정 1개를 전제하지만, 한도(`countOwn`)·Ask 격리(`ownerId`)·토큰 정리는 이미 계정 인자 기반이라 **D1(계정 2개)이 작은 변경**으로 된다.
3. **스키마는 하나(`SamplePack`)**: 노트·PDF·질문을 서버 Dart 상수 한 곳에 두고 질문은 `sampleHints()`로 클라이언트에 내려 준다. DB 마이그레이션 0.
4. 기존 운영 데이터는 본문 해시를 바꾸지 않아 그대로 승계된다(`demo@`=en). Ask 상한은 공유 1개를 유지하는 것이 PDF 안내문과 모순이 없다.
5. 질문 언어는 샘플 내용 언어를 따르는 것을 기본으로 하고(보증 가능), 교차 언어 검색이 입증되면 UI 언어로 확장한다.

---

## 1. 현재 구조

### 1.1 일반 계정(가입 샘플)

| # | 사실 | 근거 |
|---|---|---|
| 1 | 가입 훅이 **언제나 영어** 샘플 1행을 삽입한다. 서버는 가입 시점에 언어를 모른다(`startRegistration`이 `email`만 받고 `UserProfile`에도 로케일 필드가 없다). 삽입은 임베딩 없이 `status:'indexing'`, `version:1`, `contentHash = sha256(en.body)` | ✅ `sample/sample_seed.dart:21-37`, `server.dart:37`, `sample/sample_note.dart:51-53`; `UserProfile` 필드는 userName·fullName·email·image·createdAt뿐 ✅ (`serverpod_auth_core_server-4.0.4/.../user_profile.spy.yaml`) |
| 2 | **첫 로그인 때 클라이언트가** 해석된 UI 언어로 `document.ensureSample(locale)`을 1회 호출 → `version 1→2`를 원자적으로 선점해 멱등, 한국어면 제목·본문·해시를 한국어로 교체한 뒤 색인 | ✅ `main.dart:115-133`(`context.l.isKorean ? 'ko':'en'`), `rag_endpoints/document_endpoint.dart:190-220` |
| 3 | 서버의 언어 판별은 `ko*`→ko, 그 외 en. 이 한 줄이 지원 언어 개념의 전부 | ✅ `sample_note.dart:48-49` |
| 4 | 샘플 질문(`sampleSuggestions`)은 **클라이언트 l10n에 하드코딩**, UI 언어로 고른다(`_ko ? ko목록 : en목록`) | ✅ `app/l10n.dart:420-434` |
| 5 | 샘플 노트와 질문의 **짝짓기는 제목 접두사**: 개인 노트 제목 중 `Sample · `/`샘플 · `로 시작하는 게 있으면 `sampleSuggestions`를 앞에 붙인다. 접두사 목록은 클라이언트에 별도로 복제돼 있고 "서버와 맞아야 한다"는 주석뿐 | ✅ `features/ask/ask_suggestions.dart:7-9,26-30`, 서버 `sample_note.dart:11,29` |
| 6 | 클라이언트는 UI 언어(수동 선택 `en`/`ko`, 없으면 시스템: 브라우저·기기 언어에 `ko`가 있으면 ko, 아니면 en)를 이미 알고 있고, 서버에는 `ask(..., locale)`·`ensureSample(locale)`로 **인자로** 넘긴다 | ✅ `locale_controller.dart:6-34`, `main.dart:50-59`, `ask_screen.dart:115`, `ask_endpoint.dart:26,31` |

### 1.2 demo 계정

| # | 사실 | 근거 |
|---|---|---|
| 1 | 계정 **1개**, 이메일 상수 하나(`demo@pageblink.invalid`). 언어 개념 없음 | ✅ `demo/demo_config.dart:7` |
| 2 | 노트 3개는 **영어만**(`noteTour`·`notePlan`·`noteSync`), PDF 1개는 **한 페이지에 EN→KO가 같이** 들어 있음. 그래서 한국어 UI 방문자는 영어 노트에 한국어 질문을 하게 된다(검색 가능 여부 ⚠️) | ✅ `demo/demo_samples.dart:20-87,107-152`, `l10n.dart:405-418` |
| 3 | demo 판별이 **프로세스 전역 static 1개**: `DemoUser.demoUserId`. `isDemo(userId)`는 이 값과의 동등 비교 | ✅ `demo_user.dart:11-14,60` |
| 4 | Ask 일일 상한 50은 **계정 전체 합산**, 메모리 카운터 1개(`DemoGuard.askCounter`, 재시작·다중 인스턴스 시 0으로 리셋 — 이미 plan 014 L5로 알려진 한계) | ✅ `demo_guard.dart:13-45,51,124-132`, `demo_config.dart:13` |
| 5 | 한도 5개는 `countOwn(session, userId)`로 **userId 인자**를 받아 계정별 계산이 이미 가능. 단, 제외 집합 `DemoSamples.markers`는 전역 | ✅ `demo_guard.dart:106-113` |
| 6 | 정리(`purgeExpired`)는 `DemoUser.demoUserId` **단일 값**으로 `ownerId.equals`. 리프레시 토큰은 `method=='demo'` 전체라 이미 계정 수와 무관 | ✅ `demo_guard.dart:137-165` |
| 7 | 시드는 단일 비행: `_running`·`_lastStart` 전역, `run(session, demoId)`가 **계정 1개 + `DemoSamples` 전역**을 전제. `legacy` 삭제도 `ownerId==demoId & hash in legacy` | ✅ `demo_seed.dart:18-23,56-70,105-147` |
| 8 | `status()`/`signIn()`에 인자가 없다. `askRemaining`은 전역 카운터 값 | ✅ `demo_endpoint.dart:20-46,54-67` |
| 9 | 샘플 잠금·한도 면제 판정은 **본문 해시**(`contentHash ∈ markers`) — 새 컬럼 없이 동작 | ✅ `demo_samples.dart:10-12,159-161`, `demo_guard.dart:66-86` |
| 10 | Ask 검색 범위는 `DocChunk.ownerId == userId`(개인) → **계정이 다르면 문서가 자연히 격리**된다. 언어별 계정 분리가 가능한 근거 | ✅ `ask_endpoint.dart:39-45` |
| 11 | 서버 호출 지점이 적다: `DemoGuard`는 `ask_endpoint.dart:30`, `document_endpoint.dart:71,90,128,144,361`, `project_endpoint.dart:27,78`에서만 쓰이고 모두 `userId`를 이미 넘긴다 | ✅ grep |

### 1.3 서버가 방문자 언어를 아는 경로

| 경로 | 가능? | 평가 |
|---|---|---|
| **클라이언트가 인자로 넘김** | ✅ 이미 `ask`·`ensureSample`이 씀. 선택 위치 인자 `[String? locale]`은 이전 클라이언트와 호환 | **채택 대상.** 수동 언어 전환까지 반영되는 유일한 경로 |
| HTTP `Accept-Language` | 헤더 접근자는 있다 ✅ (`relic_core-2.0.0-rc.2 headers.dart:157`, `MethodCallSession.request` `session.dart:302`). 그러나 **브라우저 언어이지 앱 설정이 아니다**(`localeController` 수동 선택과 달라질 수 있음). 네이티브 Dart HTTP는 헤더를 안 보낼 수 있음 ⚠️ 실측 안 함 | 보조 폴백으로도 권하지 않음 |
| 계정 프로필 | `UserProfile`에 로케일 필드 없음 ✅. 프로필 생성도 앱이 하지 않음(research 026 §2). 스키마 확장은 패키지 테이블이라 부적합 | 불가 |
| demo 계정 자체 | demo는 계정이 곧 언어가 될 수 있음(D1) | D1에서 해결 |

### 1.4 드리프트 입증 (같은 사실이 여러 곳에 손으로 복제돼 있다)

1. **질문 문구가 3곳**: `demo_samples.dart:29`(투어 노트 본문 속 "Ask: *When is the launch, and what is the budget?*") ↔ `l10n.dart:405-418`(`demoSuggestions[0]`) ↔ PDF 2쪽 예시 문장 "What does the guide say about uploading a PDF?"(`demo_samples.dart:127`)와 `demoSuggestions[3]` "How do I upload a PDF?"(문구가 다름). 노트 본문을 한국어로 바꿔도 한국어 질문은 클라이언트 쪽을 따로 고쳐야 한다.
2. **숫자 하드코딩**: PDF 3쪽 "5 notes…/50 per day"(`demo_samples.dart:145,151`)와 노트 투어 "up to 5"(`:31`)는 `demoCreateLimit=5`·`demoAskDailyLimit=50`(`demo_config.dart:10,13`)과 별개로 적혀 있고, PDF는 **본문 문자열 ↔ `web/samples/pageblink-guide.pdf` 바이너리**까지 맞아야 한다(`demo_samples.dart:105-106` 주석). 상수만 바꾸면 안내가 거짓이 된다.
3. **제목 접두사 복제**: 서버 `sample_note.dart:11,29` ↔ 클라이언트 `ask_suggestions.dart:7`. 검증 테스트는 양쪽이 **따로** 있다(서버 `sample_note_test.dart:15-16`, 클라이언트 `sample_delete_project_test.dart:81-84`) — 서로를 이어 주는 테스트는 없다 ✅.
4. **질문 ↔ 본문을 잇는 테스트가 없다**: 서버 `demo_rules_test.dart`는 개수·해시·legacy만, 클라이언트 테스트는 질문 **문자열 리터럴**만 단정한다(`sample_delete_project_test.dart:51-66,98+`). 본문을 바꿔 답이 안 나오게 돼도 CI가 통과한다.
5. **판별 한계(제목 접두사)**: 사용자가 샘플 제목을 고치면 질문이 사라지고, 반대로 본문을 전부 지워도 제목이 남아 있으면 질문이 남는다. 또 질문이 `indexing`/`failed` 상태에서도 뜬다(`ask_suggestions.dart:28`은 `status`를 보지 않음) — 색인 전엔 "찾지 못했다"만 나온다.
6. **언어 불일치**: 샘플 본문 언어는 **첫 로그인 시점의 UI 언어**로 1회 고정(`version` 선점), 질문은 **현재 UI 언어**를 따른다. 영어로 시작해 한국어로 바꾼 사용자는 영어 노트에 한국어 질문(교차 언어 ⚠️)을 본다.
7. **낡은 주석**: `demo_samples.dart:15-17`("제목이 `Sample · `로 시작하면 질문 화면이 할 일 목록 예시를 띄운다")는 `isDemo`가 우선하는 지금 구조(`ask_suggestions.dart:25-27`)에선 이유가 달라졌다.

---

## 2. 요구 해석

1. demo 계정을 **언어(en/ko)별로 분리**한다. 각 계정은 자기 언어의 노트 샘플과 질문 예시만 가진다. 한국어 방문자가 한국어 노트에 한국어로 묻고, 영어 방문자는 영어로 묻는다.
2. **일반(가입) 계정도 같은 방식**으로 "샘플 노트 ↔ 질문 예시"를 **한 묶음으로 지정**한다. 제목 접두사 추측이나 클라이언트 하드코딩 없이, 어떤 샘플이 있으면 어떤 질문이 뜬다는 관계를 한 곳에 선언한다.
3. 질문: 노트 샘플 스키마와 질문 예시 스키마가 **따로 필요한가?** → 따로 두지 않는다. 한 구조(`SamplePack`)에 노트와 질문을 같이 둔다(§4). 노트가 바뀌면 질문을 같은 파일·같은 PR에서 고치게 하는 것이 목적.

---

## 3. 방안 비교

### 3.1 언어별 demo 계정

| 기준 | **D1 계정 2개** (`demo@`=en, `demo-ko@`) | D2 계정 1개 + 문서 언어 태그 |
|---|---|---|
| 격리 | Ask가 이미 `ownerId`로 격리 ✅(§1.2-10). 코드 변경 최소 | `Document`에 언어 컬럼 없음(마이그레이션) · `DocChunk`에도 없어 **Ask 핫패스** 범위식(`ask_endpoint.dart:39-45`)에 `documentId inSet` 추가 · `list` 필터 필요 |
| 방문자가 만든 노트(5개) | 계정별 분리 | 언어 없는 문서라 두 언어 방문자에게 **섞여 보임** |
| 일일 Ask 한도 | **전체 공유 카운터 1개 유지**(기본). 계정별 50은 선택(PDF 문구 때문에 비용 있음, 아래 세부) | 전 방문자 합산 그대로 |
| 변경 규모(추정) | 서버 5파일 소규모 + 신규 콘텐츠 | 모델 마이그레이션 + 핫패스 + 클라이언트 필터 |
| 롤백 | 코드 되돌리면 계정 하나가 고아로 남을 뿐 | 컬럼 되돌리기 필요 |
| 판정 | **채택** | 기각(핫패스·마이그레이션 대비 얻는 게 없음). 얻는 것은 PDF 중복 저장 방지(25 KB) 정도 |

보류: 방문자별 임시 계정(`AnonymousIdp`)은 ADR 020이 후속 후보로 남긴 별개 주제.

**D1 세부 (계정별로 바뀌는 지점 전부)**

| 현재(단일 가정) | D1 이후 | 비고 |
|---|---|---|
| `DemoUser.demoUserId` (`UuidValue?`) | `Map<UuidValue, SamplePack> accounts` (id → 팩). `isDemo(id)=accounts.containsKey(id)` | `ensure`·`load`는 팩 목록을 순회. 멱등·동시 부팅 처리 로직은 그대로(이메일만 팩별) |
| `demoEmail` 상수 | `SamplePack.accountEmail`. en은 **기존 `demo@pageblink.invalid` 유지**, ko는 `demo-ko@pageblink.invalid` | `.invalid` TLD 규칙 동일 |
| `askCounter` 1개 | **그대로 둔다.** `consumeAsk`는 이미 `isDemo(userId)`로 걸러 모든 demo 계정에 같은 카운터를 적용 | 공유 PDF 3쪽의 "데모 방문자 전체가 하루 50회"(`demo_samples.dart:145,151`)가 계속 참. 계정별 50으로 나누면 이 문장이 거짓이 되어 PDF 본문 수정 → `pdfHash` 변경 → `web/samples/pageblink-guide.pdf` 재생성 + 옛 해시를 `legacy`에 추가(en 승계 콘텐츠 변경)가 필요 |
| `purgeExpired` `ownerId.equals(demoId)` | `ownerId.inSet(accounts.keys)` | 토큰 정리는 이미 전역 |
| `DemoSeed._running/_lastStart` + `run(session, demoId)` | 단일 비행 유지, `run`이 계정×팩을 **순차** 처리 | 새 계정이 늘어도 임베딩 호출이 병렬로 폭주하지 않음 |
| `legacy` 삭제 | 모든 demo 계정 소유자에게 적용(해시 일치만 지움) | 해시가 전역 고유라 안전 |
| `markers` 전역 | demo 팩 전체의 해시 합집합 그대로 | 한 팩의 해시가 다른 계정에서 마커 취급돼도 무해 |
| `status()` | 변경 없음(인자 불필요, `askRemaining`은 공유 카운터 값) | 새 필드 없음 |
| `signIn()` | `signIn([String? locale])` → `forLocale(locale, demo)`의 계정으로 토큰 발급. 인자 없으면 en(**이전 클라이언트와 동일 동작**) | 선택 위치 인자는 `ask`가 이미 쓰는 패턴 ✅ |

**기존 단일 demo 계정 이전**: 코드만 바꾼다. 기존 `demo@pageblink.invalid`를 그대로 en으로 승계 — 그 계정의 문서·14일 리프레시 토큰이 모두 유효하다. 영어 노트 본문은 **한 글자도 바꾸지 않는다**(바뀌면 해시가 달라 새 행이 생기고, 옛 해시는 `legacy`에 넣어야 한다 — 이 장치는 이미 있음 ✅ `demo_seed.dart:108-120`). ko 계정은 부팅/첫 `signIn`에서 `ensure`가 만든다.

**계정이 3개 이상이 될 때**: 팩 하나 추가 = 상수 + 이메일 규칙(`demo-<locale>@…`). 공유 카운터라 총 비용 상한은 계정 수와 무관하지만, 한 언어 방문자가 상한을 다 써 다른 언어를 막을 수 있다(트레이드오프, 필요하면 계정별 카운터 + PDF 문구 수정). 5개를 넘기면 부팅 시 전부 시드하지 말고 첫 `signIn`에서 지연 생성을 검토. ⚠️ 시드 소요 시간·LLM 비용은 측정하지 않음.

**로그인 시 언어 선택**

| 방식 | 평가 |
|---|---|
| **UI 언어 자동**(`Localizations.localeOf(context)`를 `signIn`에 전달) | **권장.** 로그인 화면에 언어 스위처가 이미 있다(`sign_in_screen.dart:357-378`) → 사용자는 언어를 바꾼 뒤 버튼을 누르면 그 언어의 데모로 들어간다. 추가 UI 0 |
| 버튼 2개(English demo / 한국어 데모) | 선택은 명시적이나 첫 화면이 복잡해지고, 언어를 이미 정한 사용자에게 중복. 언어가 3개 이상이면 더 나빠짐 |
| 로그인 후 전환 | 로그아웃→재로그인 필요(계정 단위 상태). 필요해지면 배너에 "한국어 데모로" 링크를 얹는 후속 기능으로 |

데모에 들어간 뒤 UI 언어를 바꿔도 계정(내용)은 그대로이고, 질문 예시는 계정의 팩 언어를 따른다(§4.4).

### 3.2 샘플 + 질문 예시 스키마

| 기준 | **S1 서버 상수 + API로 질문 전달** | S2 노트=서버 상수, 질문=클라이언트 l10n(pack id 키) | S3 DB 테이블 | S4 JSON 자산(서버·클라이언트 공용) |
|---|---|---|---|---|
| 드리프트 방지 | **노트와 질문이 같은 상수 안.** 한 PR에서 같이 보임 | 두 저장소로 다시 갈라짐(지금과 같은 문제, pack id만 생김) | 한 테이블이면 좋지만 시드 마커·PDF 해시와 별개 관리 | 같은 파일이면 좋음 |
| 배포·마이그레이션 | **DB 변경 0.** 모델 1개(`SampleHint`, 테이블 없음)·엔드포인트 메서드 1개 → `serverpod generate` | pack id를 클라이언트가 알려면 어차피 서버 API 필요 → S1과 같은 호출이 필요하고 이득이 없음 | 마이그레이션 + 관리 UI 없음 + 시드·PDF 해시 연동 | 서버가 런타임 파일 읽기: `web/`만 번들에 있다고 알려져 있음(research 026 §10) ⚠️ 경로 의존, PDF 선례만 있음 |
| 다국어 추가 | 팩 상수 1개 + 이메일 규칙 | l10n + 서버 상수 두 군데 | 행 추가(배포 없이 가능, 장점) | 파일 추가 |
| 테스트 | **순수 Dart 단위 테스트**로 팩 무결성·질문 증거 문자열 검증 가능 | 서버·클라이언트 테스트가 분리 | DB 필요(통합 테스트) | 파일 로드 테스트 필요 |
| "답이 나오는지" 보증 | 질문마다 `evidence`(본문에 반드시 있어야 하는 문자열)를 두고 단위 테스트로 검사 ✅ 가능 | 서버가 질문을 모르므로 불가 | 제약식으로 불가, 별도 스크립트 | 가능(파일 기반) |
| 구현 규모(추정) | 신규 1파일 + 기존 4파일 수정 | S1보다 크지 않으나 효과 없음 | 최대 | 중간 |
| 판정 | **채택** | 기각 | 기각(2~4개 팩 규모에 과함, 비개발자 편집 요구가 생기면 재검토) | 기각(S1 대비 얻는 게 없음) |

**답: 스키마는 따로 나오지 않는다.** 노트 샘플과 질문 예시는 `SamplePack` 한 구조의 필드다. 단, **전송용** 작은 모델 `SampleHint`(질문 목록 응답)는 하나 생긴다 — 이것은 저장 스키마가 아니라 API 응답 형이다.

---

## 4. 추천안

### 4.1 구조 (서버 단일 원천)

새 파일 `app/pageblink_server/lib/src/sample/sample_pack.dart` — 기존 `SampleNote`(`sample_note.dart`)와 `DemoSampleNote`(`demo_samples.dart`)는 필드·해시 동작이 같으므로 **하나로 합친다**.

```dart
enum SampleAudience { signup, demo }

class SampleNote {            // = 기존 SampleNote/DemoSampleNote 통합
  final String title, body;
  const SampleNote(this.title, this.body);
  String get hash => sha256Hex(body);   // 본문 해시 = 마커(컬럼 불필요)
}

class SampleQuestion {
  final String text;               // 화면에 띄우는 질문
  final List<String> evidence;     // 이 문자열들이 팩의 노트/PDF 본문에 있어야 한다(단위 테스트)
  const SampleQuestion(this.text, this.evidence);
}

class SamplePdf {                  // demo 전용, ko·en 팩이 같은 PDF 공유 가능
  final String title, assetPath;
  final List<String> pages;
  String get hash => sha256Hex(pages.join('\u0000'));
}

class SamplePack {
  final String id;                 // 'signup-en' 'signup-ko' 'demo-en' 'demo-ko'
  final String locale;             // 내용 언어
  final SampleAudience audience;
  final List<SampleNote> notes;
  final SamplePdf? pdf;            // demo 전용
  final List<SampleQuestion> questions;
  final String? accountEmail;      // demo 전용 (en은 기존 demo@pageblink.invalid)
  Set<String> get hashes => {...notes.map((n) => n.hash), ?pdf?.hash};
}

abstract final class SamplePacks {
  static const all = [signupEn, signupKo, demoEn, demoKo];
  static SamplePack forLocale(String? l, SampleAudience a) =>   // ko* → ko, 그 외 en
      all.firstWhere((p) => p.audience == a && p.locale == _norm(l));
  static SamplePack? byHash(String h) => ...;                   // 사용자 소유 문서 해시 → 팩
  static Set<String> demoMarkers => ...;                        // 기존 DemoSamples.markers
}
```

핵심 성질: **가입 팩은 노트 1개**(지금 훅·`ensureSample`이 1행을 다룸). `notes`가 리스트인 것은 형식 통일일 뿐이며 여러 노트 가입 샘플은 YAGNI.

### 4.2 질문 예시 전달

모델(`lib/src/models/sample_hint.spy.yaml`, 테이블 없음):

```yaml
class: SampleHint
fields:
  packId: String          # 'signup-ko' ...
  locale: String          # 질문(=내용) 언어
  questions: List<String>
```

엔드포인트(기존 `DocumentEndpoint`에 메서드 추가 — 파일 증가 없음):

```dart
/// Hints for the sample packs whose note the caller holds and that is ready.
Future<List<SampleHint>> sampleHints(Session session)
// where ownerId==userId & projectId==null & kind=='note' & status=='ready'
//   & contentHash inSet(allPackHashes) → byHash → pack.questions.map(text)
```

**두 갈래**: (가) *가입 계정*은 위 해시 조회(본문 해시 + ready 상태)로 판별 — §1.4-5의 두 결함이 사라진다. (나) *demo 계정*은 서버가 이미 계정→팩을 알므로(`DemoUser.accounts[userId]`) **해시 조회·ready 검사 없이** 그 팩의 질문을 바로 돌려준다. 시드가 늦어도 질문이 뜨는 현행 동작과 같고(§6 리스크), demo 팩 질문이 계정 언어와 항상 일치한다. 반환 형은 같은 `SampleHint`라 클라이언트는 갈래를 모른다. 클라이언트 `isSampleTitle`·`sampleTitlePrefixes`·`l10n.sampleSuggestions`·`l10n.demoSuggestions`를 삭제한다.

클라이언트 `orderedSuggestions`는 단순해진다:

```dart
List<String> orderedSuggestions(L l, List<SampleHint> hints, {required bool isDemo}) => [
  for (final h in hints) ...h.questions,
  if (!isDemo) ...l.askSuggestions,   // 범용 문구는 UI 언어, 샘플과 무관
];
```

갱신 시점: HomeShell이 이미 `boardRefresh` 리스너로 `refreshDemoStatus`를 호출하는 패턴(`main.dart:100-110`)에 `sampleHints`를 같이 건다(색인이 끝나거나 샘플이 지워지면 `boardRefresh`가 올라감 ✅). 비용: 개인 노트 ≤ 수십 행 조회(`ownerId` 인덱스 있음 ✅ `document.spy.yaml`).

### 4.3 일반 계정: 샘플 언어

- **현행 유지**: 훅은 영어 삽입(서버가 언어를 모름) → 첫 로그인에 클라이언트가 `ensureSample(uiLocale)`로 현지화·색인. 이는 research 021이 검토한 방식 ③이며 가입 트랜잭션에 임베딩을 넣지 않는다 ✅. 인자 기반이 Accept-Language보다 정확하다(§1.3).
- 코드 변경: `SampleNote.forLocale`·`seedHash`를 `SamplePacks.forLocale(locale, signup)`·`signupEn.notes.first.hash`로 치환(동작 동일). **해시는 그대로**라 기존 운영 계정의 샘플 행은 새 코드에서도 그대로 인식된다 → 데이터 이전 0.
- 샘플 제목 접두사(`Sample · `/`샘플 · `)는 **사용자에게 보이는 라벨로만** 남기고, 로직(질문 노출)에서는 쓰지 않는다.

### 4.4 UI 언어를 바꿨을 때 질문 언어 (두 경우 모두)

| | (A) 샘플 **내용 언어**를 따름 (권장) | (B) **UI 언어**를 따름 |
|---|---|---|
| 동작 | 샘플이 영어면 UI가 한국어여도 영어 질문을 띄움 | UI가 한국어면 한국어 질문(영어 노트 대상) |
| 답이 나오나 | **언제나 보장** — 질문 본문 증거가 같은 팩에 있음(단위 테스트 가능) | 교차 언어 검색 성능에 의존 ⚠️(라이브 검증 중). 같은 노트에 한국어 질문이 닿는지는 임베딩 모델 성능이지 코드 보증이 아님 |
| UX | 질문 언어가 UI와 다를 수 있음(어색할 수 있음) | UI와 일관 |
| 구현 | 지금 §4.2 그대로 | `SamplePack.questions`를 `Map<queryLocale, List<SampleQuestion>>`로 확장하고 `sampleHints(uiLocale)`로 선택, 없으면 내용 언어로 폴백 |

권장은 (A): 단위 테스트로 보증되는 쪽을 기본으로 한다. 교차 언어 검색이 라이브에서 충분하다고 입증되면 (B)로 **스키마 확장만**(맵) 하면 되고, A→B 전환이 어렵지 않게 `SampleHint.locale`을 이미 내려 준다. demo는 계정=언어라 이 문제가 없다(질문은 항상 계정 팩 언어).

### 4.5 변경 파일 목록

서버 (`app/pageblink_server/`)
- 신규 `lib/src/sample/sample_pack.dart` (위 구조 + en/ko × signup/demo 4개 팩. ko demo 노트 3개는 신규 번역·작성)
- 수정 `lib/src/sample/sample_note.dart`(삭제 또는 팩으로 이관), `sample_seed.dart`(`signupEn` 사용), `lib/src/demo/demo_samples.dart`(내용을 팩으로 이관·삭제), `demo_config.dart`(이메일 상수 제거), `demo_user.dart`(Map), `demo_guard.dart`(purge `ownerId.inSet`; 카운터는 그대로), `demo_seed.dart`(계정×팩 순회), `demo_endpoint.dart`(`signIn([String? locale])`; `status`는 그대로)
- 수정 `lib/src/rag_endpoints/document_endpoint.dart`(`ensureSample`이 팩 사용, `sampleHints` 추가)
- 신규 `lib/src/models/sample_hint.spy.yaml` → `serverpod generate`(서버 생성물 + `pageblink_client` 갱신, 둘 다 커밋 대상 ✅ research 021 §F)
- `web/samples/pageblink-guide.pdf`: **변경 없음**(양쪽 언어 팩이 같은 이중언어 PDF 공유, 소유자별 `existing(hash)` 조회라 두 계정이 같은 해시를 가져도 충돌 없음 ✅). 이 "변경 없음"은 Ask 상한을 **전체 공유 1개로 유지**할 때만 성립 — 계정별 상한을 고르면 PDF·`pdfHash`·`legacy`가 변경 목록에 들어온다(§3.1)

클라이언트 (`app/pageblink_flutter/`)
- `lib/features/ask/ask_suggestions.dart`(제목 판별 제거), `lib/app/l10n.dart`(`sampleSuggestions`·`demoSuggestions` 삭제), `lib/features/ask/ask_screen.dart`(힌트 구독), `lib/main.dart`(HomeShell에서 힌트 갱신), `lib/features/demo/demo.dart`+`lib/screens/sign_in_screen.dart`(`signInAsDemo(locale)`·테스트 훅 시그니처)
- 테스트: `test/sample_delete_project_test.dart` 수정

### 4.6 마이그레이션 · 기존 운영 데이터

| 항목 | 처리 |
|---|---|
| DB 스키마 | **변경 없음**(새 테이블·컬럼 없음, `SampleHint`는 `table:` 없는 직렬화 모델) ✅ |
| 운영 demo 계정 | `demo@pageblink.invalid`를 en으로 승계. en 노트·PDF 본문을 건드리지 않으면 문서 행 그대로 인식 |
| ko demo 계정 | 첫 부팅/`signIn`에서 `ensure`가 자동 생성·백그라운드 시드 |
| 운영 일반 계정 샘플 | 본문 해시 동일 → 그대로 인식, 질문은 힌트 API로 대체 |
| 이전 클라이언트(캐시된 웹 등) | `signIn()` 인자 없음 → en(현행 동작). 새 서버 메서드는 선택 인자라 호환 ✅. 단 이전 클라이언트가 제목 접두사로 판별하는 `l10n` 질문은 그대로 동작 |
| 플래그 | `demoEnabled` 그대로. 꺼지면 모든 demo 계정 `load`만(가드 유지: 꺼진 상태의 `DemoSeed.boot` 분기가 모든 demo 계정을 조회해야 한다) |

### 4.7 테스트 방법

단위(`test/unit/sample_pack_test.dart`, DB 불필요):
1. 팩 `id` 고유, `(audience, locale)` 조합 고유, 모든 해시(노트·PDF) 팩 간 충돌 없음(의도적 PDF 공유 제외), `legacy ∩ demoMarkers = ∅`
2. 각 노트 본문 ≤ 900자(한 청크 — `chunker.dart:29` maxChars 900 ✅)
3. **각 질문의 `evidence` 모든 문자열이 같은 팩의 노트(+PDF 해당 언어 페이지)에 포함** — 본문 수정으로 근거가 사라지면 실패. 예: `What is due today?` ← `due 5 pm`, 출시 질문 ← `Nov 18`·`₩12M`
4. 가입 팩 제목 접두사 규칙, 투어 노트 본문 속 질문 문구가 팩 질문에 있는지, PDF 문구의 한도 숫자가 `demoCreateLimit`·`demoAskDailyLimit`와 일치(§1.4-2)
5. `forLocale('ko-KR'|'ja'|null)` 매핑

통합(`test/integration/demo_test.dart` 확장, 기존 `DemoUser.demoUserId`·`DemoGuard.askCounter` 참조 약 15곳 갱신 ✅):
6. 두 계정의 한도(`countOwn`)·정리·시드 독립, 공유 카운터가 두 계정 합산으로 동작, `signIn('ko')`가 ko 계정 토큰, `sampleHints`가 계정 팩만 반환, `status().isDemo`가 두 계정 모두 true, 꺼진 플래그에서 두 계정 모두 `load`되어 가드 적용

수동/라이브: (B)안 판단용으로 영어 노트에 한국어 질문 결과 기록(진행 중인 검증 재사용). 임베딩 호출을 쓰는 "질문→인용 노트 일치" 자동 테스트는 비용·불안정성 때문에 CI 제외, 환경 변수 게이트 선택 사항 ⚠️.

---

## 5. 구현 순서 · 규모 · 되돌리기

규모는 모두 **추정**(코드 줄 기준, 콘텐츠 제외): 서버 약 +250/-120, 클라이언트 약 +40/-70, 테스트 약 +200. 신규 콘텐츠: ko demo 노트 3개(영어 본문 번역·한 청크 이내) + 질문 4개×4팩.

| 단계 | 내용 | 배포 | 되돌리기 |
|---|---|---|---|
| 1 | `SamplePack` 도입(내용 이전만, 동작 동일) + `sampleHints` + 클라이언트가 힌트 사용 + 단위 테스트(증거 문자열) | 서버+웹 1회 | 커밋 revert, 데이터 영향 0 |
| 2 | D1: demo 계정 맵화, `signIn(locale)`, ko 팩·콘텐츠, 통합 테스트 | 서버+웹 1회 | **단순 revert는 위험**: 되돌린 코드의 `isDemo`는 `demo@`만 알아, 이미 발급된 `demo-ko@` 세션(JWT/리프레시 14일)이 **한도·보호 없는 일반 계정**이 된다(ADR 020·`DemoSeed.boot` 주석이 막으려던 상황). 되돌리기 절차에 `demo-ko@`의 `RefreshToken` 삭제(또는 계정 삭제)를 포함한다. `purgeExpired`가 `method=='demo'` 토큰을 24시간 지나면 지우므로 창은 한정적이나, 리프레시 시 `createdAt`이 갱신되는지는 ⚠️ 확인 안 함 |
| 3 | `l10n` 구 질문·제목 접두사 코드 제거, plan 014·ADR 갱신 | 문서+코드 | — |

1→2 순서: 1단계가 기존 영어 동작을 그대로 두고 구조만 바꾸므로 회귀를 분리해서 볼 수 있다. 2단계는 en 승계라 기존 방문자에게 영향 없음.

---

## 6. CTO 결정 사항

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| 1 | demo 분리 방식 | D1 계정 2개 / D2 태그 | **D1** (§3.1) |
| 2 | 언어 선택 UI | 자동(UI 언어) / 버튼 2개 / 로그인 후 전환 | **자동**, 후속으로 배너 전환 링크 |
| 3 | 스키마 | 단일 `SamplePack`(S1) / l10n 분리(S2) / DB(S3) / JSON(S4) | **S1** (DB 변경 0) |
| 4 | UI 언어 변경 시 질문 언어 | (A) 샘플 언어 / (B) UI 언어 | **(A)**, 교차 언어 검색이 라이브에서 입증되면 (B)로 확장(스키마 맵화만) |
| 5 | demo Ask 상한 | 전체 50 공유(현행) / 계정별 50(합 100) | **전체 50 공유**: 코드 변경 0, 공유 PDF 문구가 계속 참, en 콘텐츠 무변경. 계정별로 나누려면 PDF 본문+바이너리 재생성+`legacy` 추가가 따라옴 |
| 6 | 영어 demo 본문 | 그대로 유지 / 개선하면서 `legacy`에 옛 해시 추가 | **그대로** (개선은 별건) |
| 7 | 샘플 편집 시 질문 | 본문 수정하면 질문 사라짐(해시 기반) / 제목 기준 유지 | **해시 기반** (질문이 답을 못 낼 수 있어서) |

## 미확인 · 리스크

- ⚠️ 영어 노트에 한국어 질문이 검색되는 정도: 라이브 검증 대기. (A)안은 이에 의존하지 않는다. demo ko 신규 콘텐츠는 본문이 한국어라 무관.
- ⚠️ ko demo 시드 시간과 임베딩 비용(ko 노트 3개+PDF 추가): 측정 안 함. 공유 카운터 기본안에서 질문 총량 상한은 그대로(메모리 카운터라 재시작·다중 인스턴스 시 더 늘 수 있음, plan 014 L5, 이미 감수).
- ⚠️ **배포 직후 첫 ko 방문자**: ko 계정은 백그라운드 시드라 색인이 끝나기 전엔 질문이 "찾지 못했다"만 낼 수 있다. 사용자가 보는 순서는 ① `signIn`이 계정 생성+시드 시작 ② 노트가 `indexing`. 완화: 배포 후 운영자가 `demo-ko`로 한 번 들어가 시드가 끝났는지 확인(plan 014 §12.2 수동 확인 절차에 항목 추가), 클라이언트는 `boardRefresh`로만 갱신하므로 질문이 늦게 나타날 수 있음.
- ⚠️ `Accept-Language`가 네이티브 클라이언트에서 오는지: 실측 안 함(채택하지 않으므로 영향 없음).
- ⚠️ `serverpod generate` 결과 diff와 `sampleHints` 쿼리의 실제 성능: 구현 전이라 미확인(`ownerId` 인덱스가 있어 작은 규모에서는 문제없을 것으로 추정).
- ⚠️ 이전 웹 클라이언트 캐시의 `demo.signIn()` 호환: 선택 위치 인자 호환성은 `ask`의 선례(`ask_endpoint.dart:26`)로 추정, 실제 호출 테스트는 안 함.
- 한국어 UI에서 한국어 demo 노트가 "기존 영어 demo를 대체"하는 방문자 경험 변화: 영어 투어 노트에 한국어 UI 질문이 뜨던 현행과 달라짐(개선이지만 라이브 스크린샷은 안 봄).

## 출처 (코드·문서, 저장소 내)

- 서버: `app/pageblink_server/lib/src/demo/{demo_user,demo_endpoint,demo_config,demo_guard,demo_seed,demo_samples}.dart`, `lib/src/sample/{sample_note,sample_seed}.dart`, `lib/src/rag_endpoints/{document,ask,project}_endpoint.dart`, `lib/server.dart`, `lib/src/models/{demo_status,document}.spy.yaml`, `test/unit/{demo_rules,sample_note}_test.dart`, `test/integration/demo_test.dart`
- 클라이언트: `app/pageblink_flutter/lib/{main.dart,app/l10n.dart,app/locale_controller.dart,features/ask/ask_suggestions.dart,features/ask/ask_screen.dart,features/demo/demo.dart,screens/sign_in_screen.dart}`, `test/sample_delete_project_test.dart`
- 문서: `docs/plan/014-demo-account.md`, `docs/adr/020-demo-account-shared-user.md`, `docs/research/021-sample-note-delete-and-project-edit.md`, `docs/research/026-demo-account-api-verification.md`
- 패키지 소스(pub cache): `serverpod-4.0.4/lib/src/server/session.dart:298-302`, `relic_core-2.0.0-rc.2/lib/src/headers/headers.dart:157`, `serverpod_auth_core_server-4.0.4/.../user_profile.spy.yaml`
