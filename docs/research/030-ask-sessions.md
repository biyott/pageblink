# 030 · Ask 대화 기록·멀티턴·관리자 조회 설계

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 11:40 (KST) |
| 담당 | 서브에이전트 (설계 담당 엔지니어, 읽기 전용) |
| 질문 | Ask 대화 기록을 서버에 저장·복원하고, 멀티턴 문맥·보관 삭제·관리자 조회를 붙이려면 어떻게 하나, 그리고 마이그레이션은 안전하게 배포되나 |
| 결론 한 줄 | 테이블 2개(`ask_session`·`ask_message`) + `ask()` 래퍼로 대화를 저장·복원하고, 문맥은 턴 수가 아니라 문자 예산으로 구성한다. 마이그레이션은 추가형이라 배포해도 안전(조건부, §8). |
| 반영 | 13차 구현·배포 ([devlog 012](../devlog/012-releases-10-to-15.md)). 설계 당시에는 D1 사용자 대화 삭제 정책 · D9 무료 모델 이력 전송 고지가 결정 대기였음 (확정 기록은 확인 필요) |
| 범위 | 서버 저장·복원·멀티턴 문맥·보관 삭제·관리자 조회·클라이언트 UI·마이그레이션 배포 안전성 |
| 작성 시점 상태 | 설계안. 저장소 파일은 만들거나 고치지 않았고, 서버를 실행하지 않았고, 커밋하지 않았습니다 |
| 표기 | ✅ 소스·로그로 확인 / ⚠️ 미확인 또는 추정 |
| 검증에 쓴 것 | 저장소 소스, pub 캐시의 Serverpod 4.0.4 소스, `scloud` 읽기 전용 명령(배포 목록·로그), **HEAD를 `git archive`로 scratchpad에 풀어 만든 복사본**에서 돌린 `serverpod generate`/`create-migration` |

> 상태: 구현·배포 완료(13차, 2026-10-16, `de349e9`, 스위치 `ASK_HISTORY_ENABLED`) · UI 변경 15차(대화 헤더·최근 대화 메뉴, [`design/ask-history-ui/spec.md`](../design/ask-history-ui/spec.md)). P0(타이머·로그아웃 훅)은 10차에 배포. 아래 본문은 설계 시점의 스냅샷이며, D1(사용자 대화 삭제 정책)·D9(무료 모델 이력 전송 고지)의 최종 결정 기록은 확인 필요. 경위는 [devlog 012](../devlog/012-releases-10-to-15.md).

> 이 문서의 SQL·spy.yaml 스케치는 scratchpad 복사본에서 실제로 생성해 본 결과입니다. 그 마이그레이션(`20261016023356379`)은 **증거용**이며 저장소에 없습니다. 구현자는 저장소에서 다시 생성하고, 타임스탬프는 달라집니다.

---

## 0. 한눈에 보기

### 핵심 설계 결정 (10줄)

1. **테이블 2개**: `ask_session`(대화) · `ask_message`(질문+답변 한 쌍). 둘 다 `serverOnly: true`라 클라이언트에는 별도 DTO(`AskSessionView` 등)만 나갑니다. 메시지는 `sessionId`에 FK + `onDelete=Cascade`, `(sessionId, seq)` 유니크.
2. **`ask()`는 래퍼**: 기존 본문을 `_answer()`로 옮기고, 새 `ask()`가 대화 확보 → `_answer()` 순회·누적 → `finally`에서 저장. 무결과 안내문·키워드 폴백 안내·오류 이벤트까지 한 곳에서 잡힙니다.
3. **구버전 호환**: `ask(..., [locale, sessionId, visitorKey])`. `sessionId == null`(구버전)은 **숨김 1질문 대화로 기록만** 하고 한도·문맥에서 제외합니다. 새 클라이언트는 `0`(새 대화) 또는 대화 id를 보냅니다.
4. **한도·동시 질문 방지·고아 스트림 복구를 UPDATE 한 번으로**: `questionCount = 관측값 AND (streamingSince IS NULL OR 오래됨)` 조건의 compare-and-set. 다중 인스턴스에서도 안전합니다.
5. **스트리밍 저장**: 질문 수신 시 `streaming` 행을 먼저 쓰고, 3초마다 부분 답변을 체크포인트, `finally`에서 `done/error/interrupted`로 확정. 확정 쓰기는 **요청 세션이 아니라 `pod.withSession(enableLogging: false)`** 로 합니다(요청 세션은 취소 중에 닫힐 수 있고, 질문 원문이 쿼리 로그에 남는 것도 막음).
6. **이어보기(30초)·조회 창(30분)은 서버가 판정**(시계 기준 하나). 서버가 `questionLimit`·`questionCount`를 응답에 실어 UI의 "질문 3/10"이 환경값을 따라갑니다.
7. **문맥은 "턴 수"가 아니라 "문자 예산"**: 최신 턴부터 담되 기본 8,000자, 답변당 앞 800자, `[n]` 제거, 검색 질의는 현재 질문 + 직전 질문(기본 600자 상한), 합계 프롬프트 상한 20,000자.
8. **삭제**: 서버 안 `Timer.periodic(1시간)`(+부팅 직후 1회, 지터) + 새 대화 생성 시 소량 기회적 정리. 쿼리는 `lastActiveAt` 인덱스 + 배치 200 + 트랜잭션 수준 advisory lock. **demo 정리(`DemoGuard.purgeExpired`)도 같은 타이머에서 호출**합니다.
9. **관리자**: `ADMIN_USER_IDS`를 매 호출 파싱, 서버가 `session.authenticated.authUserId`로 판정, demo 계정은 관리자 불가, 읽기 전용, 접근 로그 한 줄. "내 계정 ID 복사"는 `client.auth.authInfo?.authUserId`로 로컬 처리(엔드포인트 불필요).
10. **마이그레이션은 추가형이고 운영 파이프라인이 이미 3번 검증됨**. 첫 배포는 `ASK_HISTORY_ENABLED` 미설정(꺼짐)으로 나가고, 다음 재배포에서 켭니다.

### 마이그레이션 배포 안전성 결론 (자세한 근거는 §8)

**배포해도 안전합니다(추가형, 조건부).** 새 마이그레이션은 `CREATE TABLE` 2 + `CREATE INDEX` 3 + `FOREIGN KEY` 1 + 버전 행 갱신뿐입니다(✅ 복사본에서 생성). 운영은 부팅 때마다 `applyMigrations: true`로 마이그레이션을 적용하고, 지난 36시간 로그에서 불일치 경고가 0건입니다(✅). 아래 두 가지는 **사실과 다릅니다**.

- ✅ **"이번이 첫 마이그레이션 배포"가 아닙니다.** 운영 로그에 `Applied database migration`이 **3번**(2026-10-15 00:04 `…327746`, 00:28 `…152214229`, 00:47 `…154208706`) 찍혔습니다. 이번이 4번째입니다. 이번이 처음인 것은 "실사용자 데이터가 쌓인 뒤의 첫 마이그레이션"입니다.
- ⚠️ **Starter에는 DB 백업이 없습니다**(`scloud db backup list` → "Database backups are available on the Growth plan"). 롤백 안전망은 "추가형만"이라는 사실 자체입니다.

---

## 1. 확인한 사실

| # | 사실 | 근거 |
|---|---|---|
| F1 | 현재 Ask는 서버에 아무것도 저장하지 않고, 질문마다 독립적이다 | `ask_endpoint.dart:23-216`, `ask_screen.dart:47` `_turns` |
| F2 | `ask()`는 `[String? locale]`을 선택 인자로 이미 받는다(구버전이 생략해도 동작). 같은 방식으로 인자를 더 붙일 수 있다 | `ask_endpoint.dart:23-30`, `demo_endpoint.dart:67-69` 주석 |
| F3 | demo 일일 상한은 **프로세스 메모리** 카운터(`DailyCounter`). 인스턴스가 둘이면 합계가 50을 넘을 수 있다 | `demo_guard.dart:9-48`, 운영 로그에 `serverId`가 다른 부팅이 배포당 2번 |
| F4 | `LlmProvider.answer(question, sources)`에 이력 인자가 없다. 구현체: OpenRouter(`openrouter_llm_provider.dart:45`), Claude(`llm_provider.dart:99`), Rotating(`rotating_llm_provider.dart:14`), Gemini 스텁, 테스트용 `RagServices.debugLlm` | 각 파일 |
| F5 | RAG 근거 예산은 `contextBudgetChars = 6000`(evidence+context 합) | `context_builder.dart:11` |
| F6 | Serverpod는 스트림 구독이 취소되면(웹소켓 종료 포함) 서버 쪽 `async*` 제너레이터의 구독을 취소한다. `closeAllStreams`는 6초 타임아웃 후 `onCancel`을 직접 부른다. 출력 컨트롤러의 `onCancel`이 `session.close()`를 부르며, **제너레이터의 `finally`와 순서가 보장되지 않는다** | `method_stream_manager.dart:171-198, 354-366, 643-649` (serverpod 4.0.4) |
| F7 | 세션 로그는 기본으로 DB에 저장되고 보관 90일. 느린(≥1초)·실패한 쿼리는 로그에 남는다 | `config.dart:1349-1355`, `serverpod.dart:233-243` (`logSlowQueries: true`, `logFailedQueries: true`, `slowQueryDuration: 1.0`) |
| F8 | **ORM이 값을 SQL 문자열에 직접 박아 넣는다**(`VALUES (<encoded>)`). 그래서 느리거나 실패한 INSERT/UPDATE의 쿼리 로그에 질문·답변 원문이 들어갈 수 있다 | `sql_query_builder.dart:521-552` |
| F9 | `pod.withSession(cb, enableLogging: false)`로 로깅이 꺼진 내부 세션을 쓸 수 있다 | `serverpod.dart:1188-1217` |
| F10 | 리프레시 토큰 회전은 `rotatingSecretHash`와 `lastUpdatedAt`만 바꾼다. **`createdAt`은 발급 때 한 번만** 쓰인다 | `jwt_admin.dart` `_rotateLockedRefreshToken`, `jwt.dart:175` |
| F11 | 액세스 토큰(JWT) 검증은 서명·발급자·만료만 본다(DB 조회 없음). 그래서 리프레시 행을 지워도 이미 발급된 액세스 토큰은 최대 10분 유효 | `jwt_util.dart:112-201`, `jwt_admin.dart` 주석 |
| F12 | `client.auth.initialize()`는 시작 때 `validateAuthentication()`을 부르고, 리프레시가 `failedUnauthorized`면 `signOutDevice()`로 로그아웃시킨다. 그러나 **실행 중에는** 호출이 401 → 리프레시 실패 → `ServerpodClientUnauthorized`를 던질 뿐 **로그아웃하지 않는다** | `session_manager.dart:137-149, 227-236`, `serverpod_client_shared.dart:221-237` |
| F13 | 앱은 `validateAuthentication`을 직접 부르지 않는다(`SignInScreen`은 `authInfoListenable`만 듣는다) | `lib/` grep, `sign_in_screen.dart:64` |
| F14 | 클라이언트에 `shared_preferences`가 이미 있다(`locale_controller.dart`). `client.auth.authInfo`(`AuthSuccess?`)에 `authUserId`가 있다 | `pubspec.yaml:47`, `session_manager.dart:65` |
| F15 | 운영은 `scloud.yaml`의 `pre_deploy`로 `serverpod generate` + Flutter 웹 빌드를 한 뒤 서버와 웹을 **한 번에** 배포한다. 새 클라이언트와 새 서버가 함께 나간다(다만 브라우저 캐시의 구버전 JS는 남을 수 있다) | `scloud.yaml`, `plan/012 §2-3` |

---

## 2. 데이터 모델

### 2.1 결론

- **테이블 2개**, 둘 다 `serverOnly: true`. 이유: `ownerId`·`visitorKeyHash`가 클라이언트로 직렬화되는 사고를 모델 수준에서 막습니다(✅ 복사본에서 확인: `pageblink_client`에 `Ask*` 클래스가 생기지 않음).
- 클라이언트에 나가는 것은 **테이블이 아닌 DTO** 4개: `AskSessionView`(대화+메시지), `AskSessionSummary`(목록 한 줄), `AskRestore`(복원 응답), `AskAdminPage`/`AskAdminSession`(관리자).
- `citations`·`projectIds`는 **json 컬럼**(`List<Citation>?`, `List<int>?`). 기존 `Citation` 모델을 그대로 재사용해서 복원된 답변이 `quote`/`quoteStart`/`page`/`kind`로 칩과 U2 하이라이트를 그대로 구동합니다(✅ 생성 확인: `"citations" json`).
- FK는 **이번에 처음 도입**합니다. 기존 모델은 "FK 없음, 서버가 지운다"(research 021)였지만, 새 두 테이블은 1:N이 확실하고 삭제 배치가 `DELETE FROM ask_session`(+cascade)으로 한 문장이 되며 고아 행이 생길 수 없습니다. 추가형 FK는 새 테이블끼리만 걸어 기존 테이블에 영향이 없습니다.

### 2.2 spy.yaml 스케치 (scratchpad에서 `serverpod generate` + `create-migration` 통과)

```yaml
# lib/src/models/ask_session.spy.yaml
### One Ask conversation. Server only: the app gets AskSessionView instead.
class: AskSession
table: ask_session
serverOnly: true
fields:
  ### Authenticated user. Demo accounts are shared by many visitors.
  ownerId: UuidValue
  ### SHA-256 hex of the browser's visitor key. Demo accounts only.
  visitorKeyHash: String?
  isDemo: bool, default=false
  ### First question, shortened to 80 characters.
  title: String
  ### Questions asked so far (display; the message rows are the truth).
  questionCount: int, default=0
  createdAt: DateTime
  ### Last question received or answer finished. Drives the 30-minute list,
  ### the 30-second resume rule and the 30-day purge.
  lastActiveAt: DateTime
  ### Set while an answer streams; the gate for "one question at a time".
  streamingSince: DateTime?
  ### Hidden from the user's lists (legacy-client rows, user "delete").
  ### Still kept for the retention period (CTO decision D1).
  hiddenAt: DateTime?
indexes:
  ask_session_owner_active_idx:
    fields: ownerId, visitorKeyHash, lastActiveAt
  ask_session_active_idx:
    fields: lastActiveAt
```

```yaml
# lib/src/models/ask_message.spy.yaml
### One question and its answer inside an AskSession. Server only.
class: AskMessage
table: ask_message
serverOnly: true
fields:
  sessionId: int, relation(parent=ask_session, onDelete=Cascade)
  ### 1-based position in the conversation.
  seq: int
  question: String
  ### The answer exactly as streamed, [n] markers included.
  answer: String, default=''
  ### streaming | done | error | interrupted
  status: String
  ### Short code only (llm, embedding, internal). Never an exception message.
  errorCode: String?
  citations: List<Citation>?
  modelId: String?
  ### Scope the question was asked with (after the membership intersection).
  projectIds: List<int>?
  includePersonal: bool, default=true
  createdAt: DateTime
  ### Last checkpoint while streaming, then the finish time.
  updatedAt: DateTime
indexes:
  ask_message_session_seq_idx:
    fields: sessionId, seq
    unique: true
```

생성된 SQL (✅ scratchpad 복사본, 요약):

```sql
CREATE TABLE "ask_message" ("id" bigserial PRIMARY KEY, "sessionId" bigint NOT NULL, "seq" bigint NOT NULL,
  "question" text NOT NULL, "answer" text NOT NULL DEFAULT ''::text, "status" text NOT NULL, "errorCode" text,
  "citations" json, "modelId" text, "projectIds" json, "includePersonal" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp without time zone NOT NULL, "updatedAt" timestamp without time zone NOT NULL);
CREATE UNIQUE INDEX "ask_message_session_seq_idx" ON "ask_message" USING btree ("sessionId", "seq");
CREATE TABLE "ask_session" (... "ownerId" uuid NOT NULL, "visitorKeyHash" text, "isDemo" boolean NOT NULL DEFAULT false, ...);
CREATE INDEX "ask_session_owner_active_idx" ON "ask_session" USING btree ("ownerId", "visitorKeyHash", "lastActiveAt");
CREATE INDEX "ask_session_active_idx" ON "ask_session" USING btree ("lastActiveAt");
ALTER TABLE ONLY "ask_message" ADD CONSTRAINT "ask_message_fk_0" FOREIGN KEY("sessionId")
  REFERENCES "ask_session"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
```

(위 스케치에는 `streamingSince`·`hiddenAt`이 아직 없던 초안으로 생성했습니다. 컬럼 둘은 둘 다 nullable `timestamp`라 같은 방식으로 생성됩니다. **구현자는 최종 필드로 다시 생성해 SQL을 눈으로 확인**하세요.)

### 2.3 인덱스가 하는 일

| 질의 | 인덱스 | 비고 |
|---|---|---|
| 사용자의 최근 30분 대화 5개 | `ask_session_owner_active_idx (ownerId, visitorKeyHash, lastActiveAt)` | 일반 사용자는 `visitorKeyHash IS NULL`, demo는 `= 해시`. 둘 다 btree로 처리됨 |
| 30일 보관 삭제 · 관리자 기간 조회 | `ask_session_active_idx (lastActiveAt)` | 범위 스캔 + `LIMIT` |
| 대화의 메시지 순서 · FK cascade 탐색 | `ask_message_session_seq_idx (sessionId, seq)` unique | 동시 질문의 최후 방어선이기도 함 |
| 오래된 `streaming` 정리 | (인덱스 없음) | 최근 24시간 세션만 찾아 그 id로 메시지 갱신. 행 수가 작아 순차 스캔도 문제 없음. 커지면 부분 인덱스 추가 |

용량: 질문 수는 LLM 한도가 지배합니다(무료 모델 계정당 일 50회, ADR 014). 질문 1건 약 수 KB × 30일이면 MB 단위입니다. ⚠️ Starter DB 저장 한도는 확인하지 못했습니다.

### 2.4 검토 후 버린 대안

| 대안 | 버린 이유 |
|---|---|
| 한 테이블(질문마다 한 행, `conversationId` 문자열) | 대화 단위 만료·한도·목록·동시성 게이트를 모두 집계 쿼리로 해야 함. `streamingSince`·`hiddenAt` 같은 대화 속성의 자리가 없음 |
| FK 없이 서버가 두 번 지우기(기존 관례) | 삭제 배치가 두 문장 + 트랜잭션이어야 하고 실패 시 고아 발생. FK는 새 테이블끼리라 위험 없음 |
| 인용을 별도 테이블 | 인용은 항상 메시지와 함께 읽히고 질의 대상이 아님. json 컬럼이 단순 |
| `questionCount`를 DB에서 집계만 | 목록 5건마다 `count`를 따로 쳐야 함. 비정규화하되 **진실은 메시지 행**(스큐가 나도 `seq`는 행 기준) |
| 대화를 클라이언트가 UUID로 직접 만든다 | 권한 확인과 한도를 서버가 소유해야 함. 서버 발급 `bigint`가 맞음 |

---

## 3. 서버 흐름

### 3.1 `ask()` 시그니처 (구버전 호환)

```dart
Stream<AnswerEvent> ask(
  Session session,
  String question,
  List<int> projectIds,
  bool includePersonal,
  String? modelId, [
  String? locale,
  int? sessionId,    // null = 구버전(기록만, 한도·문맥 제외), 0 = 새 대화, >0 = 이어서
  String? visitorKey, // demo 방문자 키. 일반 사용자는 무시
]) async* { ... }
```

`AnswerEvent`에 선택 필드 `sessionId`, `questionCount`, `questionLimit`(`int?`)과 새 `type: 'session'`을 추가합니다. 구버전 클라이언트는 모르는 필드·모르는 `type`을 무시합니다(생성된 `fromJson`은 아는 키만 읽고, 클라이언트의 `switch`에 `default`가 없어도 예외가 나지 않음 ✅ `ask_screen.dart:119-134`).

**구버전(캐시된 JS) 처리 (중요).** `sessionId == null`을 "새 대화"로 취급하면 구버전이 다섯 번째 질문부터 막힐 수 있습니다. 그래서:

- `sessionId == null` → **1질문짜리 대화를 `hiddenAt = now`로 만들어 기록만** 합니다. 사용자 목록에는 안 나오고(관리자만 봄), 한도(질문 10개)·문맥 대상에서 제외됩니다. 구버전은 지금처럼 질문마다 독립 동작합니다.
- 이 규칙 덕분에 1단계(서버 저장만, 클라이언트 변경 없음)에서도 모든 질문이 관리자에게 기록되어, 운영에서 저장 경로를 검증할 수 있습니다.

### 3.2 정책 오류와 인프라 오류를 분리

- **정책 오류**(사용자에게 보여야 함): 새 예외 모델 `AskLimitException(reason, limit)`.
  `reason`: `questionLimit`(10개 도달) · `busy`(같은 대화에서 답변 중) · `expired`(대화가 30분 창을 벗어남 → 클라이언트가 새 대화로 다시 보냄).
  첫 `yield` 전에 던지므로 스트림 오류로 도착합니다(기존 `DemoLimitException` 방식).
- **인프라 오류**(DB 쓰기 실패 등): **답변을 막지 않습니다.** 저장은 best-effort이고, 실패하면 기록 없이 지금처럼 답합니다(경고 로그에는 내용 없이 "history unavailable"만). 마이그레이션이 실패해 테이블이 없어도 서비스가 계속되도록 하는 장치입니다(§8).
- 킬 스위치: `ASK_HISTORY_ENABLED`(기본 꺼짐). 꺼져 있으면 `sessionId`·`visitorKey`를 무시하고 지금과 동일하게 동작합니다.

### 3.3 한 질문의 처리 순서

```
ask(question, ...)
 1. userId = Acl.requireUser; 질문 trim, 길이 상한(ASK_QUESTION_MAX_CHARS) 자르기
 2. [기록 켜짐] 대화 준비 (읽기만, 부작용 없음)
      · sessionId > 0: 대화 행 읽기 → 소유자·방문자 키 일치, hiddenAt 아님,
        30분 창 안(아니면 expired), questionCount < 한도(아니면 questionLimit),
        답변 중이 아님(streamingSince가 신선하면 busy)
      · demo 계정인데 방문자 키가 없거나 형식 불량 → 기록·복원 모두 건너뜀(공유 버킷으로 떨어지지 않음)
 3. DemoGuard.consumeAsk(session, userId)   // 대화 한도 검사 뒤에 둔다: 거절된 질문이 일일 50을 깎지 않게
 4. [기록 켜짐] begin(): 게이트 UPDATE + 메시지 INSERT (3.4)
 5. 첫 이벤트: AnswerEvent(type:'session', sessionId, questionCount, questionLimit)
 6. _answer(...) 순회 → 이벤트를 그대로 yield 하면서 누적(토큰·인용·모델·상태)
    · 3초마다 체크포인트(부분 답변·인용·updatedAt)
 7. finally: 상태 확정(done/error/interrupted) + 대화 streamingSince=null, lastActiveAt=now
```

3번과 4번 사이에서 동시 경합으로 4번이 실패하는 경우(더블 클릭 등)는 demo 일일 카운트 1을 낭비합니다. 드물고 demo 등급이므로 허용합니다(`DailyCounter`에 환불을 넣지 않음).

### 3.4 게이트: UPDATE 한 번으로 한도·동시성·고아 복구

ORM의 `updateWhere`는 증가식(`count + 1`)을 못 쓰므로 **compare-and-set**으로 씁니다. 대화 행을 읽어 `observed = questionCount`를 얻은 뒤:

```dart
final stale = now.subtract(Duration(seconds: staleSeconds)); // 기본 30초
final won = await AskSession.db.updateWhere(
  s,
  columnValues: (t) => [
    t.questionCount(observed + 1),
    t.lastActiveAt(now),
    t.streamingSince(now),
  ],
  where: (t) =>
      t.id.equals(id) &
      t.questionCount.equals(observed) &       // 동시 질문이면 한쪽만 이김
      (t.streamingSince.equals(null) | (t.streamingSince < stale)), // 고아 스트림은 풀림
);
if (won.isEmpty) → 다시 읽어 busy 또는 questionLimit 판정 후 던짐
```

- 이긴 쪽이 `seq = observed + 1`로 메시지를 INSERT합니다. `(sessionId, seq)` 유니크가 뒷받침합니다.
- 풀린 고아(`streamingSince`가 오래된 경우)가 있었다면 이전 `streaming` 메시지를 `interrupted`로 바꿉니다.
- 새 대화(`sessionId == 0`): 한 트랜잭션에서 대화(`questionCount = 1`, `streamingSince = now`)와 메시지 `seq = 1`을 INSERT합니다.
- **롤링 배포가 인스턴스를 SIGTERM으로 끊어도** 3초 체크포인트로 부분 답변이 남고, `streamingSince`가 오래되면 다음 질문이 막히지 않습니다. 조회 쪽은 오래된 `streaming`을 `interrupted`로 계산해 보여 줍니다(쓰기 없이).

### 3.5 스트리밍 중 새로고침·연결 끊김

- 새로고침이면 웹소켓이 닫히고 F6 경로로 제너레이터가 취소됩니다. `async*`는 취소를 다음 `yield` 지점에서 받아 `finally`를 실행합니다. 단, 제너레이터가 LLM 청크를 기다리는 중이면 **다음 청크가 올 때까지 취소가 미뤄질 수** 있습니다(그 사이 6초 타임아웃은 `onCancel`만 부르고 제너레이터를 강제 종료하지 않음). 그래서 확정 쓰기는 **늦게 실행돼도 안전해야** 하고, 그 때문에 `pod.withSession` 신선 세션을 씁니다(F6·F9).
- `finally`는 `completed` 플래그가 없으면 `interrupted`로 확정합니다. 이때까지 받은 부분 답변·인용·모델이 보존됩니다.
- 재접속 후 UI: 마지막 메시지가 `interrupted`면 부분 답변을 보여 주고 "답변이 중간에 끊겼어요" + "다시 질문" 버튼(입력창에 질문을 채워 줄 뿐 자동 전송 안 함). **끊긴 스트림에 다시 붙지 않습니다**(Serverpod 스트림은 연결에 묶여 있어 재접속이 불가능).
- 취소 경합으로 복원 시점에 아직 `streaming`이면(서버가 아직 끊김을 처리 중) 클라이언트는 `open(sessionId)`를 2초 간격으로 최대 5번 다시 읽습니다.
- 한 가지 한계: 취소가 LLM 청크 대기 때문에 늦어지는 동안 사용자가 같은 대화에서 질문하면 `busy`가 나올 수 있습니다(최대 `ASK_STREAM_STALE_SECONDS`=30초). 안내 문구로 충분합니다.

### 3.6 검색 질의와 문맥 구성 → §4

---

## 4. 멀티턴 문맥 정책 (문자 예산)

### 4.1 정책 (3턴 고정 폐기)

모델 컨텍스트 길이는 제약이 아닙니다(코디네이터가 OpenRouter 공개 목록으로 확인한 값: gemma-4-26b 262,144 · nemotron-3-super 262,144 · nano-omni 256,000 · lightning/ultra 1,000,000 토큰 — ⚠️ 이 값은 제가 다시 조회하지 않았습니다). 실제 제약은 **응답 지연, 요청 횟수 한도(무료 분당 20·일 50, ADR 014), 긴 이력의 품질 저하**입니다. 그래서 상한을 턴 수가 아니라 문자 예산으로 둡니다.

| 환경값 | 기본 | 뜻 |
|---|---|---|
| `ASK_CONTEXT_ENABLED` | `true` | 끄면 후속 질문도 독립(이전 문맥 없음). 문맥 기능만 되돌릴 때 |
| `ASK_CONTEXT_CHARS` | `8000` | 이전 턴 전체에 쓰는 문자 예산 |
| `ASK_CONTEXT_ANSWER_CHARS` | `800` | 이전 답변 하나당 앞부분 길이 |
| `ASK_CONTEXT_QUESTION_CHARS` | `500` | 이전 질문 하나당 길이 |
| `ASK_QUESTION_MAX_CHARS` | `2000` | 현재 질문 길이 상한(지금은 상한이 없고, 이제 질문이 저장·재전송됨) |
| `ASK_QUERY_MAX_CHARS` | `600` | 검색 질의(현재+직전 질문) 길이 상한 |
| `ASK_PROMPT_MAX_CHARS` | `20000` | 시스템+RAG 근거+이전 문맥+질문 합계 상한 |

### 4.2 이전 문맥을 고르는 규칙 (예산 소진 시 버리는 순서)

1. 후보는 같은 대화의 `status == 'done'` 턴만(오류·중단 턴은 제외: 답변이 없거나 불완전하면 오히려 오도).
2. **최신 턴부터** 거꾸로 하나씩 담습니다. 한 턴의 비용 = `min(질문, 500) + min(정리한 답변, 800) + 40(역할 표기)`.
3. 남은 예산이 비용보다 작으면 **거기서 멈춥니다(더 오래된 턴은 모두 버림).** 짧은 턴을 건너뛰고 더 오래된 턴을 끼워 넣어 이력에 "구멍"이 생기지 않게 하기 위함입니다. **가장 오래된 턴부터 버려집니다.**
4. 단, 가장 최근 턴조차 안 들어가면 그 답변을 남은 예산까지 줄여(최소 200자) 넣습니다. 그것도 안 되면 이전 문맥 없음.
5. 대화당 질문은 최대 10개이므로 이전 턴은 최대 9개. 기본값으로 한 턴 최대 약 1,340자이므로 큰 턴은 약 5개, 짧은 턴(질문 80자·답변 500자 ≈ 620자)은 9개 모두 들어갑니다.

### 4.3 이전 답변 정리 (모델에 가는 사본에서만)

- `[n]` 마커 제거: `RegExp(r'\s?\[\d{1,2}\]')`. **저장본에는 마커를 남깁니다**(복원된 칩·U2 하이라이트가 `[n]`과 `citations`로 동작해야 하므로).
- 키워드 폴백 안내문(`_(의미 검색을 잠시 쓸 수 없어…)_`)이 답변 앞에 붙어 저장되므로 모델 사본에서는 맨 앞의 해당 안내문을 제거합니다(안내문 상수를 한 곳에 두고 양쪽이 같이 씀).
- 800자 초과면 앞 800자 + `…`. 서로게이트 쌍 중간을 자르지 않습니다.
- 이전 질문·답변은 **Sources 블록 안이 아니라 별도 user/assistant 메시지**로 보냅니다. 시스템 프롬프트에 한 문장 추가: *"Earlier turns are only for resolving references such as 'it' or 'the previous one'. Answer from the numbered sources of the current question; the [n] numbers refer only to the current sources."*

### 4.4 인터페이스 변경 (영향 범위)

```dart
class ChatTurn { ChatTurn(this.question, this.answer); final String question, answer; }
abstract class LlmProvider {
  Stream<LlmEvent> answer(String question, List<SourcePassage> sources,
      {List<ChatTurn> history = const []});
}
```

이름 있는 선택 인자라 기존 호출·테스트는 컴파일됩니다. 바꿔야 할 곳: `OpenRouterLlmProvider`(messages 배열에 이력 삽입), `ClaudeLlmProvider`(이전 턴을 텍스트 전용 user/assistant 메시지로, **document 블록은 현재 user 메시지에만**), `RotatingLlmProvider`(그대로 전달), `GeminiLlmProvider` 스텁, 테스트 가짜 `debugLlm` 구현.

### 4.5 검색 질의 (추가 모델 호출 없음)

`query = 현재 질문 + "\n" + 직전 질문(done 턴 중 가장 최근)`. 길이 상한 `ASK_QUERY_MAX_CHARS`(600):

- 현재 질문이 우선입니다. 직전 질문에 줄 수 있는 길이 = `min(300, 600 − 현재 질문 길이)`. 40자 미만이면 직전 질문을 붙이지 않습니다.
- 임베딩에는 `EmbeddingSpec.query(query)`를 넣고, 키워드 폴백의 단어(`take(6)`)도 이 질의에서 뽑되 **현재 질문 단어가 먼저**입니다.
- 영향: 후속 질문("그건 언제야?")의 검색이 직전 주제를 따라가는 대신, 주제가 바뀐 질문은 직전 질문이 섞여 검색이 약간 흐려질 수 있습니다(현재 질문을 앞에 두고 직전을 뒤에 짧게 붙여 완화). 이는 요구된 방식이며 품질은 §10 평가 질문으로 확인합니다. ⚠️ 정량 효과는 측정하지 않았습니다.

### 4.6 합계 입력 상한 (RAG 근거 + 이전 대화)

`ASK_PROMPT_MAX_CHARS`(기본 20,000자)는 **시스템 프롬프트 + RAG 근거(제목·EVIDENCE·CONTEXT) + 이전 문맥 + 현재 질문**의 합입니다. 우선순위는 **현재 질문 > RAG 근거 > 이전 문맥**입니다.

| 구성 | 기본 상한(자) |
|---|---|
| 시스템 프롬프트 | 약 800 |
| RAG 근거 (`contextBudgetChars`) + 제목/번호 표기 | 6,000 + 약 1,000 |
| 현재 질문 | ≤ 2,000 |
| 이전 문맥 | ≤ 8,000 |
| **합계** | 약 17,800 → 상한 20,000 안 |

이전 문맥 예산 = `min(ASK_CONTEXT_CHARS, ASK_PROMPT_MAX_CHARS − (시스템+RAG 실제 길이) − 현재 질문)`을 **RAG를 만든 뒤에** 계산합니다. RAG가 평소보다 커지면 이전 문맥이 먼저 줄고, RAG 예산(6,000)은 건드리지 않습니다.

### 4.7 지연·비용 영향 추정 (⚠️ 추정, 미측정)

| 항목 | 추정 | 근거/가정 |
|---|---|---|
| 이전 문맥 8,000자의 토큰 | 한글 약 4,000–8,000, 영어 약 2,000 | 한글 1–2자/토큰, 영어 약 4자/토큰 가정 |
| 첫 글자까지 지연(TTFT) 증가 | 일반 0.2–1.5초, 최악(한글 8,000토큰·느린 모델) 수 초 | 입력 처리 속도를 초당 수천 토큰으로 가정 |
| 무료 모델 횟수 한도 | **영향 없음**(요청 수 기준) | ADR 014 |
| 유료 모델 비용 | 턴마다 입력 토큰 + 위 수치 × 단가 | 단가는 모델별 |
| 품질 | 이력이 길면 이전 답변을 되풀이하거나 이전 출처 번호를 인용할 위험 | §4.3 정리·프롬프트 한 줄로 완화 |

보정 방법: 요청마다 **내용 없이** `promptChars`·`historyChars`·`historyTurns`·`ttftMs`·`modelId`만 구조화 로그로 남겨 1주일 뒤 `ASK_CONTEXT_CHARS`를 조정합니다(질문·답변 원문은 로그 금지, §9).

### 4.8 3턴 고정을 버린 데 대한 기각 사유

- "최근 3턴 고정": 컨텍스트 한도가 이유가 아니고, 짧은 턴이 많은 대화에서 쓸 수 있는 문맥을 버립니다. 반대로 긴 답변 3개가 8,000자를 넘어 지연을 키울 수도 있어 **상한이 길이 기준이어야** 둘 다 해결됩니다.
- "전체 이력 무제한": 대화당 10질문으로 상한이 이미 있으나 답변이 길면 수만 자가 되어 지연·품질 문제.
- "이력을 모델로 요약": 추가 모델 호출(요구 위반, 지연·한도 소모).

---

## 5. 조회 API

### 5.1 사용자용 `AskHistoryEndpoint` (클라이언트 이름 `client.askHistory`)

```dart
class AskHistoryEndpoint extends Endpoint {
  @override bool get requireLogin => true;

  /// 새로고침/재접속 때 한 번. 서버가 30초(이어보기)·30분(조회) 판정.
  Future<AskRestore> restore(Session s, [String? visitorKey]);

  /// 목록에서 대화 하나를 열 때(30분 창 안이면). 아니면 null.
  Future<AskSessionView?> open(Session s, int sessionId, [String? visitorKey]);

  /// 사용자 "삭제". D1 결정에 따라 hiddenAt만 설정. (D1=A면 만들지 않음)
  Future<void> hide(Session s, int sessionId, [String? visitorKey]);
}
```

```yaml
# 비테이블 모델 (spy.yaml 스케치)
class: AskRestore
fields:
  enabled: bool                 # 서버 플래그. false면 클라이언트는 메모리 방식으로 동작
  questionLimit: int
  visibleMinutes: int
  current: AskSessionView?      # 마지막 활동이 resumeSeconds 이내인 대화(없으면 빈 새 대화로 시작)
  recent: List<AskSessionSummary>  # 최근 30분, 최대 ASK_MAX_VISIBLE_SESSIONS
  serverNow: DateTime
---
class: AskSessionView
fields: { id: int, title: String, questionCount: int, questionLimit: int,
          lastActiveAt: DateTime, messages: List<AskMessageView> }
---
class: AskMessageView
fields: { seq: int, question: String, answer: String, status: String, errorCode: String?,
          citations: List<Citation>, modelId: String?, createdAt: DateTime }
---
class: AskSessionSummary
fields: { id: int, title: String, questionCount: int, lastActiveAt: DateTime }
```

- **이어보기 판정은 서버**가 합니다(클라이언트 시계 어긋남 방지): "활동" = `streamingSince`가 신선하면 지금, 아니면 `lastActiveAt`. 체크포인트와 종료가 모두 활동으로 잡혀, 40초짜리 답변 도중 새로고침해도 빈 대화가 되지 않습니다. `now − 활동 ≤ ASK_HISTORY_RESUME_SECONDS(30)` 이면 `current`.
- 목록은 30분이 지나면 사라집니다(저장은 30일). `hiddenAt != null`은 제외.
- **demo 방문자 키 전달**: 모든 호출에 선택 인자 `visitorKey`로 보냅니다(일반 사용자는 서버가 무시). 서버는 형식 `^[A-Za-z0-9_-]{16,64}$`을 검사하고 SHA-256 해시로만 저장·비교합니다. **demo 계정인데 키가 없거나 불량이면 `restore`는 빈 응답**, `ask`는 기록 없이 응답합니다. 모든 읽기 질의는 `(ownerId, visitorKeyHash)`로 거릅니다.
- `open`/`hide`는 소유자·키 일치 확인 후에만 동작합니다(남의 `sessionId`를 넣어도 null/무시).

### 5.2 새 대화·삭제

- "새 대화"는 **서버 호출이 없습니다.** 클라이언트가 `sessionId = 0`으로 상태를 비우고, 첫 질문에서 서버가 대화를 만듭니다(빈 대화 행이 생기지 않음).
- 사용자 삭제는 §6.3(결정 D1).

### 5.3 관리자용 `AskAdminEndpoint` (`client.askAdmin`)

```dart
class AskAdminEndpoint extends Endpoint {
  @override bool get requireLogin => true;

  /// 메뉴 표시용. 관리자가 아니면 false (예외를 던지지 않음).
  Future<bool> isAdmin(Session s);

  Future<AskAdminPage> listSessions(Session s, AskAdminFilter filter);
  Future<AskAdminSession?> getSession(Session s, int sessionId);
}
```

```yaml
class: AskAdminFilter
fields: { userId: String?, email: String?, from: DateTime?, to: DateTime?,
          demoOnly: bool?, beforeActiveAt: DateTime?, beforeId: int?, pageSize: int? }  # pageSize 서버가 1..50로 보정
class: AskAdminPage
fields: { items: List<AskAdminSession>, nextBeforeActiveAt: DateTime?, nextBeforeId: int? }
class: AskAdminSession   # 대화 + 메시지(질문·답변·인용 문서 제목·모델·시각·상태)
fields: { id: int, ownerId: String, ownerLabel: String, isDemo: bool, hidden: bool, title: String,
          questionCount: int, createdAt: DateTime, lastActiveAt: DateTime, messages: List<AskMessageView> }
```

- **`ADMIN_USER_IDS` 파싱**: 비밀값 `adminUserIds` → 환경변수 `ADMIN_USER_IDS` 순서(기존 `DemoConfig`/`IndexConfig` 패턴). 쉼표로 나눠 trim·소문자화, `UuidValue.fromString` 실패 항목은 무시하고(내용 없이) "N개 무시" 경고만. 호출마다 읽으므로 환경값 변경(재배포)이 즉시 반영됩니다. **비어 있으면 관리자 없음.**
- **판정**: 서버가 `session.authenticated?.authUserId`로만 판정합니다(클라이언트가 보낸 id는 신뢰하지 않음). **demo 계정(`DemoUser.isDemo`)은 목록에 있어도 관리자로 인정하지 않습니다.** 관리자가 아니면 `listSessions`/`getSession`은 `AccessDeniedException`.
- `email` 필터: 기존 `AuthServices.instance.emailIdp.admin.findAccount(session, email:)`로 `authUserId`를 얻어 `userId`로 변환합니다(`demo_user.dart`에서 쓰는 API).
- **페이지네이션**: `(lastActiveAt desc, id desc)` 키셋. `from/to`는 `lastActiveAt` 범위. 한 페이지 최대 50대화(각 최대 10메시지).
- **읽기 전용**: 쓰기 메서드를 만들지 않습니다. 관리자도 질문할 수 없고 삭제할 수 없습니다.
- **접근 로그**: 조회마다 `session.log('ask-admin list admin=<uuid> user=<uuid|-> from=<..> to=<..> returned=<n>')`, 상세는 `ask-admin get admin=<uuid> session=<id> owner=<uuid>`. **질문·답변 텍스트는 로그에 넣지 않습니다.** 이 로그는 `serverpod_log`에 90일 저장됩니다(F7). 더 강한 감사가 필요하면 세 번째 테이블(결정 D5).
- `ownerLabel`: demo 계정이면 `demo-ko`/`demo-en`(`DemoUser.packOf`), 아니면 UUID 앞 8자. 이메일 표시는 필터로 찾았을 때만(요구된 5개 열에 이메일은 없음).

### 5.4 관리자 목록 단위에 대한 해석

요구는 "질문·답변·인용 문서·사용 모델·시각 목록"입니다. 대화 단위 목록(제목·사용자·질문 수·시각) 한 줄을 펼치면 메시지별 질문·답변·인용 문서·모델·시각이 나오는 구성으로 설계했습니다(대화를 맥락째 읽는 용도에 맞고 테이블 2개 모델과 일치). 메시지 단위 평면 목록이 더 낫다면 `ask_message`에 `ownerId`·인덱스를 추가해야 하므로 **마이그레이션 생성 전에** 알려 주세요(D4).

---

## 6. 삭제(보관 만료)와 정리 타이머

### 6.1 서버 안 주기 타이머 (부팅 직후 1회 + 매시간)

`lib/src/services/ask_history_purge.dart`(신규)에 `AskHistoryPurge.start(pod)`를 두고 `server.dart`의 `await DemoSeed.boot(pod)` 다음, `ChunkMigration.start`와 나란히 `unawaited(AskHistoryPurge.start(pod))`로 시작합니다. `ChunkMigration.start`처럼 `role == maintenance`면 아무것도 안 합니다(✅ `chunk_migration.dart:61`).

```dart
static void start(Serverpod pod) {
  if (pod.config.role.name == 'maintenance') return;
  // 인스턴스들이 같은 순간에 몰리지 않게 0~120초 지터 뒤 첫 실행
  final first = Duration(seconds: 5 + Random().nextInt(115));
  _timer = Timer(first, () { tick(pod); _timer = Timer.periodic(Duration(minutes: interval), (_) => tick(pod)); });
}

static Future<void> tick(Serverpod pod) async {
  if (_running) return;               // 같은 프로세스에서 겹치지 않게
  _running = true;
  try {
    await _guarded('ask-history', () => pod.withSession(enableLogging: false, (s) => purgeAskHistory(s)));
    await _guarded('demo',        () => pod.withSession((s) async {
      if (!DemoConfig.enabled(s)) return;                 // 꺼져 있으면 무동작
      if (DemoUser.accounts.isEmpty) await DemoUser.load(s); // 계정 미준비면 조회만으로 복구
      await DemoGuard.purgeExpired(s);                    // 이미 DemoConfig/accounts 가드가 있음
    }));
  } finally { _running = false; }
}
```

- `_guarded`는 예외를 삼키고 stderr에 한 줄(내용 없음)만 씁니다. 한 작업의 실패가 다른 작업을 막지 않습니다.
- 서버 종료 시 타이머를 취소하는 훅은 만들지 않습니다(프로세스가 종료됨). ⚠️ 주기 `Timer`가 Serverpod의 정상 종료를 지연시키는지는 확인하지 못했습니다. 지연이 보이면 `pod.shutdown` 전에 `cancel()`을 호출합니다.
- 환경값: `ASK_PURGE_INTERVAL_MINUTES`(기본 60), `ASK_HISTORY_PURGE_ENABLED`(기본 true).

### 6.2 대화 삭제 쿼리

```dart
Future<int> purgeAskHistory(Session s) async {
  final now = DateTime.now().toUtc();
  var total = 0;
  for (final (cutoff, demoOnly) in [
    (now.subtract(demoRetention), true),    // demo: 짧은 보관 (D3, 기본 7일)
    (now.subtract(retention), false),       // 전체: 30일
  ]) {
    while (true) {
      final ids = (await AskSession.db.find(s,
        where: (t) => demoOnly ? t.isDemo.equals(true) & (t.lastActiveAt < cutoff)
                               : (t.lastActiveAt < cutoff),
        orderBy: (t) => t.lastActiveAt, limit: 200,
      )).map((r) => r.id!).toSet();
      if (ids.isEmpty) break;
      final gone = await s.db.transaction((tx) async {
        // 트랜잭션 수준 advisory lock: 다른 인스턴스가 이미 지우는 중이면 이번엔 건너뜀
        final got = (await s.db.unsafeQuery(
          "SELECT pg_try_advisory_xact_lock(hashtext('ask_history_purge')) AS ok", transaction: tx)).first.first as bool;
        if (!got) return -1;
        return (await AskSession.db.deleteWhere(s, where: (t) => t.id.inSet(ids), transaction: tx)).length; // FK cascade가 메시지도 삭제
      });
      if (gone < 0) return total;        // 다른 인스턴스가 처리 중
      total += gone;
      if (ids.length < 200) break;
    }
  }
  return total;
}
```

- **멱등**: 이미 지워진 id를 다시 지워도 0행. 조회 후 삭제 사이 활동이 생긴 대화는 거의 없지만(30일 지난 행) 안전하려면 `deleteWhere`에 `lastActiveAt < cutoff`를 한 번 더 겁니다.
- **다중 인스턴스**: 같은 행을 두 인스턴스가 지워도 정합성 문제가 없고, advisory lock은 낭비를 줄이는 장치입니다(마이그레이션이 쓰는 `pg_advisory_lock`과 같은 계열 ✅ `postgres_migration_runner.dart:29`). ⚠️ `pg_try_advisory_xact_lock`을 `unsafeQuery`로 부르는 부분은 임베디드 Postgres 통합 테스트로 확인 필요.
- **오래된 `streaming` 정리**: 같은 틱에서 `lastActiveAt`이 최근 24시간 이내이고 `streamingSince < now − 5분`인 대화를 찾아, 그 대화의 `streaming` 메시지를 `interrupted`로, `streamingSince`를 null로 되돌립니다.
- **기회적 정리**: 새 대화를 만드는 `begin()`에서 프로세스당 5분에 한 번, **최대 20개** 대화를 위 쿼리로 지웁니다(`unawaited`, 자체 try/catch, `enableLogging: false` 세션). 배치가 작고 `lastActiveAt` 인덱스를 타므로 요청 지연에 영향이 없습니다.

### 6.3 사용자 삭제를 허용할 것인가 (개인정보 관점 결정 D1)

충돌 지점: 사용자가 "삭제"를 눌러도 서버는 관리용으로 30일 보관합니다. 질문·답변에는 **개인 노트 내용**이 들어갑니다.

| 안 | 내용 | 평가 |
|---|---|---|
| A | 삭제 UI 없음. 30분 뒤 목록에서 사라짐 | 요구 그대로, 가장 단순. 사용자가 "지웠다"고 오해할 일이 없음 |
| **B (추천)** | **스키마에 `hiddenAt`을 포함**하고 UI 삭제는 "내 화면에서 숨김"으로 구현 가능하게 함. 서버 보관 30일은 유지하며 **그 사실을 개인정보 고지에 명시** | 마이그레이션이 한 번뿐이므로 컬럼은 지금 넣어 두는 편이 안전(nullable 1개). UI는 나중에 켜도 됨. 구버전 숨김 행에도 같은 컬럼을 씀 |
| C | 사용자 삭제 = 즉시 영구 삭제 | 개인정보에는 가장 안전하나 관리 목적 30일 보관과 충돌. 관리자가 "사용자가 지운 것"을 볼 수 없음 |

**이 결정은 마이그레이션 생성 전에 필요합니다**(컬럼이 달라지므로). B를 추천하되 A로 가더라도 `hiddenAt`은 구버전 기록 숨김에 쓰이므로 컬럼은 남습니다.

### 6.4 demo 세션 정리도 같은 타이머에서 (코디네이터 요청 반영)

현상 원인(✅ 소스로 설명됨): `DemoGuard.purgeExpired`는 **호출 시점이 3곳뿐**(`DemoEndpoint.signIn` demo_endpoint.dart:78, 노트·PDF 생성 직전 `requireCreateSlot` demo_guard.dart:98, 부팅 시드 demo_seed.dart:46)이고 주기 실행이 없습니다. 아무도 그 세 곳을 일으키지 않으면 24시간 지난 demo 리프레시 토큰이 남아 새로고침해도 로그인이 유지됩니다.

1. **주기 호출**: 위 `tick()`의 `demo` 블록. `DemoConfig.enabled`가 꺼져 있으면 무동작, `DemoUser.accounts`가 비어 있으면(부팅 때 계정 준비 실패) 조회만으로 채운 뒤 호출합니다(`purgeExpired` 안에도 `accounts.isEmpty || !enabled → return` 가드가 이미 있음 ✅). 삭제는 모두 멱등이라 다중 인스턴스가 동시에 돌려도 안전합니다(`DocumentCleanup.deleteFiles`는 파일이 없어도 경고만 ✅).
2. **절대 상한은 이미 있습니다 — 새 메커니즘이 필요 없습니다.** F10: 리프레시 회전은 `createdAt`을 바꾸지 않으므로 `method == 'demo' AND createdAt < now − 24h` 삭제는 **활동 중인 세션도 발급 24시간 뒤에는 끊는 절대 상한**입니다. 문제는 오직 "주기 실행이 없다"는 것이었습니다. 실질 상한은 24시간 + 타이머 지연(≤1시간) + 남은 액세스 토큰(≤10분)입니다.
3. 대안과 추천:

| 대안 | 평가 |
|---|---|
| **A. 현행 `createdAt < 24h` + 주기 타이머 (추천)** | 코드 한 줄 수준. 상한 24h ~ 25h10m |
| B. 전역 `refreshTokenLifetime` 단축 | 일반 사용자 로그인까지 짧아짐. 기각(research 026 §8) |
| C. 요청마다 `authId`(= 리프레시 토큰 id)로 행의 `createdAt` 조회해 24시간 넘으면 거절 | 정확한 상한. 요청마다 DB 조회 1회 추가. 25시간 오차가 문제일 때만 |
| D. 타이머 주기를 demo만 10분으로 | 오차를 줄이는 저비용 보강. `purgeExpired`는 인덱스 있는 질의 + `refresh_token` 소량 스캔이라 부담 낮음 |

4. **삭제 후 클라이언트(F11–F13)**: 행을 `deleteWhere`로 지우면 `authenticationRevoked` 메시지가 나가지 않아 열린 스트림이 끊기지 않고, 이미 받은 액세스 토큰은 최대 10분 더 동작합니다. 그 뒤 첫 호출이 401 → 리프레시 → `RefreshTokenNotFoundException` → `failedUnauthorized`이며, **라이브러리는 이 경우 로그아웃하지 않고** 호출에 `ServerpodClientUnauthorized`를 던질 뿐입니다. 즉:
   - **페이지를 새로 고치면**: `client.auth.initialize()`가 `validateAuthentication()`(2초 타임아웃)을 불러 `signOutDevice()` → `SignInScreen`이 로그인 화면으로 돌아갑니다(✅ 소스상). 서버가 2초 안에 응답하지 못하면 검증이 건너뛰어집니다(⚠️).
   - **탭을 열어 둔 채 시간이 지나면**: 로그아웃되지 않고 호출마다 오류가 납니다. **작은 클라이언트 훅이 필요합니다**: 앱의 공통 오류 처리(또는 `restore`/`ask`/문서 목록 호출의 `catch`)에서 `ServerpodClientUnauthorized`를 받으면 `client.auth.validateAuthentication()`을 한 번 호출합니다(실패 시 `signOutDevice()` 수행 → `authInfoListenable` 변경 → 로그인 화면). 앱 포커스 복귀 시에도 한 번 호출합니다. 대략 30줄입니다.

---

## 7. 클라이언트 설계

### 7.1 상태 구조

`_turns`(메모리)를 직접 쓰는 대신 `features/ask/ask_chat.dart`에 `AskChatController`(ChangeNotifier)를 둡니다. `AskScreen`은 컨트롤러가 가진 `turns`, `sessionId`, `questionCount/limit`, `recent`를 그리기만 합니다. `AskTurn`은 유지하고 `seq`, `status`, `AskTurn.fromMessage(AskMessageView)` 팩토리를 더합니다(기존 `AskTurn(question)` 생성자와 테스트 호환).

| 상황 | 동작 |
|---|---|
| 화면 진입 | `restore(visitorKey)` 호출(스켈레톤 없이 빈 상태 → 도착하면 채움). `current`가 있으면 그 대화로 복원, 없으면 빈 새 대화 |
| 첫 질문 | `sessionId = 0`으로 전송 → 첫 `session` 이벤트로 id·개수·한도 수신 |
| 후속 질문 | `sessionId = <id>`로 전송 |
| `restore` 실패/`enabled == false` | 메모리 방식(지금과 동일)으로 폴백. 작은 안내 "최근 대화를 불러오지 못했어요"(스낵바 아님). 질문은 `sessionId = 0`으로 보내되 응답에 `session` 이벤트가 없으면 로컬만 유지 |
| `AskLimitException.expired` | 화면의 대화를 비우고 "대화가 만료되어 새 대화로 시작해요" 안내, 같은 질문을 `sessionId = 0`으로 한 번만 자동 재전송 |
| `AskLimitException.busy` | "아직 답변을 쓰는 중이에요" 안내(입력은 유지) |
| `AskLimitException.questionLimit` | 한도 도달 상태로 전환(아래 7.3) |
| `DemoLimitException` | 지금처럼 턴 오류 문구 + 가입 유도 |
| `ServerpodClientUnauthorized` | `validateAuthentication()` (§6.4) |

복원된 답변: `AskTurnView`가 이미 `turn.answer`·`turn.citations`로 그리므로 복원된 `AskTurn`에 저장된 `answer`/`citations`(Map<int, Citation>)를 그대로 채우면 칩과 U2 하이라이트가 같은 경로로 동작합니다. 인용한 문서가 그 사이 삭제·수정됐을 수 있습니다(`quoteStart`는 "노트가 변하지 않았을 때만" 유효, 클라이언트가 이미 검색으로 폴백함). 삭제된 문서의 칩이 안전하게 실패하는지는 ⚠️ 확인하지 못했습니다(구현 중 확인 항목).

### 7.2 대화 목록과 새 대화 버튼

- 현재 "새 질문" 버튼(`newChat`)은 **너비 ≥1024의 헤더에만** 있습니다(`ask_screen.dart:220-247`). 모든 너비에서 보이도록 입력창 위에 **대화 바**를 둡니다: `[질문 3/10]  [최근 대화 ▾]  [새 대화 +]`.
- "새 대화"는 지우기 대체: 진행 중이면 구독을 취소하고(서버는 `interrupted`로 확정) `sessionId = 0`, 턴 비움, 카운터 숨김.
- "최근 대화": 너비 <600이면 바텀시트, 아니면 다이얼로그(`_pickScope`와 같은 패턴). 행: 제목(첫 질문), "질문 N개 · 12분 전", 현재 대화 표시. 하단 주석 "마지막 질문 후 30분 동안 보여요". 행을 누르면 `open(sessionId)`로 불러와 교체. 비어 있으면 "최근 30분 안의 대화가 없어요".
- 대화 개수 5개: 기본은 **목록 표시 상한**(D2). 6번째 대화를 만들면 가장 오래된 것이 목록에서 밀려납니다(저장은 유지).

### 7.3 질문 수 표시 (코디네이터 요구)

서버가 `questionCount`·`questionLimit`을 `session` 이벤트, `restore`, `open`에 실어 보내므로 **복원된 대화에서도 같은 값**이 보이고, 환경값을 바꾸면 클라이언트 수정 없이 따라갑니다.

| 상태 | 표시 | 조건 |
|---|---|---|
| 보통 | `질문 3/10` (칩, 보조 색) | 대화가 있고 `questionCount ≥ 1` |
| 임박 | `질문 8/10 · 2개 남음` + 경고 아이콘 + 굵은 글씨 | `limit − count ≤ 2` (기준은 limit에서 계산, 하드코딩 8 없음) |
| 도달 | 입력창 비활성 + 힌트 "새 대화를 시작하세요", 입력창 위 배너와 주 버튼 "새 대화 시작" | `count ≥ limit` (서버가 `questionLimit`을 던졌을 때도 동일하게 전환) |

접근성: 색에만 의존하지 않고 아이콘+텍스트로 구분합니다. `Semantics(label: ...)`로 스크린리더에 "이 대화에서 질문 10개 중 3개를 사용했어요"를 읽히고, 임박·도달 상태로 **바뀔 때 한 번** `liveRegion`/`SemanticsService.announce`로 알립니다(매 질문마다 낭독하지 않음). 새 대화 버튼에 `tooltip`과 `Semantics(button: true)`.

문구(한/영, `l10n.dart`의 `_t` 패턴):

| 키 | EN | KO |
|---|---|---|
| `askCount(n,limit)` | `Question $n/$limit` | `질문 $n/$limit` |
| `askCountLabel(n,limit)` | `$n of $limit questions used in this conversation` | `이 대화에서 질문 $limit개 중 $n개를 사용했어요` |
| `askCountLeft(left)` | `$left left` | `$left개 남음` |
| `askLimitReached(limit)` | `You have asked $limit questions in this conversation. Start a new conversation to keep asking.` | `이 대화에서 질문 $limit개를 모두 사용했어요. 새 대화를 시작해 계속 질문하세요.` |
| `askLimitHint` | `Start a new conversation` | `새 대화를 시작하세요` |
| `newConversation` | `New conversation` | `새 대화` |
| `recentChats` / `recentChatsNote` | `Recent conversations` / `Shown for 30 minutes after your last question` | `최근 대화` / `마지막 질문 후 30분 동안 보여요` |
| `askInterrupted` / `askAskAgain` | `This answer was cut off.` / `Ask again` | `답변이 중간에 끊겼어요.` / `다시 질문` |
| `askBusy` | `An answer is still being written. Please wait a moment.` | `아직 답변을 쓰는 중이에요. 잠시만 기다려 주세요.` |
| `askExpired` | `That conversation expired, so this starts a new one.` | `대화가 만료되어 새 대화로 시작해요.` |
| `historyLoadFailed` | `Couldn't load your recent conversation.` | `최근 대화를 불러오지 못했어요.` |

(`30분`은 서버 응답의 `visibleMinutes`로 문구를 채웁니다. 숫자를 문구에 하드코딩하지 않음.)

### 7.4 demo 방문자 키와 일일 상한 표시

- **키 생성·저장**: `Random.secure()`로 16바이트 → base64url 22자. `SharedPreferences`(웹은 localStorage) 키 `pb.visitorKey`에 저장합니다. 읽기·쓰기를 `try/catch`로 감싸고, 실패(사생활 모드·저장소 차단)하면 **메모리 키**를 페이지 수명 동안 씁니다 → 새로고침하면 기록이 복원되지 않을 뿐 다른 방문자 기록과는 섞이지 않습니다(서버도 키 없는 demo는 공유 버킷으로 처리하지 않음).
- 일반 사용자도 같은 키를 보내지만 서버가 무시합니다(분기 없이 단순).
- **일일 상한 표시**: 지금 `askRemaining`은 어디에도 표시되지 않습니다(✅ grep). demo일 때 카운터 옆에 "오늘 남은 데모 질문 N개"를 작게 표시하고, 질문이 `done`될 때 `refreshDemoStatus()`를 호출해 갱신합니다. 값은 인스턴스 메모리 카운터라 **인스턴스에 따라 다르게 보일 수 있습니다(F3, ⚠️)**. 후속 질문도 1질문=1회로 세며, 대화 한도(10)와 별개로 일일 상한 문구가 우선합니다.
  (개선 선택지: 이제 `ask_message`가 있어 demo 일일 사용량을 DB 집계로 낼 수 있으나 이번 범위에는 넣지 않았습니다.)

### 7.5 설정 화면

- **"내 계정 ID 복사"**: `client.auth.authInfo?.authUserId.toString()`을 `Clipboard.setData`로 복사하고 스낵바 "계정 ID를 복사했어요". 서버 호출이 필요 없습니다. demo 계정(`demoStatus.value?.isDemo`)에서는 공유 계정이라 의미가 없으므로 숨깁니다.
- **관리자 전용 "대화 기록"**: 설정 화면 진입 시 `askAdmin.isAdmin()`을 한 번 호출해 `ValueNotifier<bool>`에 캐시(로그아웃 시 초기화, `demoStatus`와 같은 방식). 참일 때만 타일을 보입니다. 실패·거절이면 숨김(사용자에게 오류를 보이지 않음).
- **관리자 화면** (`features/settings/admin_history_screen.dart`, `PaneHeader` 재사용): 상단 필터(사용자 이메일/ID 입력 · 기간 칩 `오늘/7일/30일/직접` · demo만 토글). 목록 행 = 시각 · 사용자(`demo-ko` 또는 UUID 앞 8자) · 제목 · 질문 수 · 숨김/demo 배지. 펼치면 메시지별 질문, 답변(선택·복사 가능), 인용 문서 제목 칩, 사용 모델, 시각, 상태. "더 보기"로 키셋 페이지. 읽기 전용(편집·삭제 컨트롤 없음). 상단에 "개인 노트 내용이 포함될 수 있습니다. 조회는 기록됩니다." 한 줄 안내.
- 관리자가 자기 id를 알려면 위 "계정 ID 복사"를 쓰고, 운영자가 `scloud variable set ADMIN_USER_IDS <uuid,uuid>` 후 재배포합니다.

---

## 8. 마이그레이션 배포 안전성 (가장 중요)

### 8.1 이 프로젝트에서 마이그레이션이 생성·적용되는 방식

| 단계 | 사실 | 근거 |
|---|---|---|
| 생성 | 개발자가 모델 변경 후 `serverpod create-migration`(MCP `create_migration`). `migrations/<타임스탬프>/`와 `migration_registry.txt`가 갱신되고 **저장소에 커밋** | `app/AGENTS.md`, `migrations/` |
| 이미지 포함 | Dockerfile이 `migrations/`를 런타임 이미지에 복사. `ENTRYPOINT`에는 `--apply-migrations`가 **없음** | `Dockerfile:46-50, 62` |
| 적용 | **Serverpod Cloud가 부팅 때 `applyMigrations: true`로 실행.** 운영 로그의 모든 부팅(role=monolith)에서 `applyMigrations: true` 확인 | `scloud log`: 2026-10-16 10:02 · 10:21 · 11:31 등 |
| 적용 방식 | `pg_advisory_lock` 아래 **한 트랜잭션**에서 마이그레이션 SQL 실행 + 버전 행 갱신. 실패하면 롤백 | `postgres_migration_runner.dart:29`, `migration_manager.dart:150-188, 272-295` |
| 동시 부팅 | 락으로 직렬화. 두 번째 인스턴스는 `Latest database migration already applied.` | 운영 로그(배포당 2회 부팅, 서로 다른 `serverId`) |

### 8.2 체크리스트와 근거

| # | 확인 | 결과 |
|---|---|---|
| 1 | 저장소 모델이 마지막 마이그레이션과 일치하는가 | ✅ HEAD(`2801184`)를 scratchpad에 풀어 `serverpod create-migration` → `Server migration skipped. No changes detected.` |
| 2 | 운영 DB가 마이그레이션 상태와 일치하는가 | ✅ 최근 로그 1,000건(2026-10-15 00:04 ~ 10-16 11:31)에서 `does not match`/`is missing`/`Failed to apply` **0건**. 부팅 시 `verifyDatabaseIntegrity`가 항상 실행되어 불일치면 경고를 남김(`apply_migrations.dart`) |
| 3 | 파이프라인이 실제로 마이그레이션을 적용해 왔는가 | ✅ `Applied database migration` 3회: 10-15 00:04(`20261014144327746`), 00:28(`…152214229`, `kind`/`body` 컬럼 추가), 00:47(`…154208706`, `doc_page` 테이블+`lastError`). 이후 `already applied`만 반복 |
| 4 | 이번 마이그레이션이 추가형인가 | ✅ 초안 생성 결과: `CREATE TABLE` 2, `CREATE INDEX` 3(유니크 1 포함), `ADD CONSTRAINT FOREIGN KEY` 1, `serverpod_migrations` 버전 행. `DROP`/`ALTER … DROP`/`DELETE` 없음. 기존 테이블 무변경 |
| 5 | 롤링 배포 중 구버전 인스턴스가 새 스키마와 공존하는가 | ✅ 구버전의 `verifyDatabaseIntegrity`는 **자기 target 테이블만** 대조하므로 추가 테이블은 경고도 만들지 않음(`migration_manager.dart:338-372`). 구버전 코드는 새 테이블을 쓰지 않음 |
| 6 | 구버전 클라이언트(캐시된 JS)가 새 서버와 공존하는가 | ✅ 추가 인자가 모두 선택. 구버전은 `sessionId == null` 경로(§3.1) |
| 7 | 적용 실패 시 | ✅ 트랜잭션 롤백(부분 적용 없음). 프로덕션 모노리스는 **계속 부팅**(오류 로그 후 진행, `serverpod.dart:957-994`) → 테이블이 없는 상태로 새 코드가 뜰 수 있음 → **저장은 best-effort + `ASK_HISTORY_ENABLED` 기본 꺼짐**이 안전장치 |
| 8 | 롤백(이전 이미지로 되돌리기) | ✅ 소스상 안전. 옛 코드가 더 새 버전이 설치된 DB를 만나면 `DB has migration version X registered but not found in the project files` 예외 → `Failed to apply database migrations.` 오류 로그를 **부팅마다** 남기지만 서버는 계속 뜸(role=monolith; `maintenance` 역할이었다면 종료 코드 1). 새 테이블은 고아로 남아 무해. 이후 앞으로 재배포하면 no-op. **⚠️ Cloud의 롤아웃이 이 오류 로그/종료 코드를 실패로 취급하는지는 확인하지 못함** |
| 9 | 백업 | ⚠️ **Starter에는 DB 백업이 없음**(`scloud db backup list`). `scloud db wipe`는 절대 쓰지 않음 |

### 8.3 배포 전 사용자가 직접 확인할 것 (명령 포함)

1. **다른 릴리스가 끝났는지**: `scloud --non-interactive deployment list` 맨 윗줄이 `SUCCESS`(2026-10-16 11:31:59에 `e73be598…` 성공 확인됨, 이 문서 작성 시점).
2. **마이그레이션 디렉터리와 모델 일치**(깨끗한 체크아웃 또는 워크트리에서):
   `cd app/pageblink_server && serverpod generate && serverpod create-migration`
   → 새 마이그레이션이 **한 번** 만들어지고, **바로 다시 실행하면** `No changes detected`여야 합니다.
3. **추가형 검증**:
   `grep -nE 'DROP|TRUNCATE|DELETE FROM|ALTER TABLE .* (DROP|ALTER COLUMN)' migrations/<새 디렉터리>/migration.sql` → 출력 없음.
   `grep -n '"type"' migrations/<새 디렉터리>/migration.json` → `createTable`만 나와야 함.
4. **테스트**: 서버 `dart test`(임베디드 Postgres가 `definition.sql`로 새 DB 생성). 증분 경로는 이전 커밋 DB에 새 `migration.sql`을 적용해 보는 개발 DB 시연으로 확인(로컬, `serverpod start`가 대기 중 마이그레이션을 적용).
5. **환경값**: 첫 배포에서는 `ASK_HISTORY_ENABLED`를 **설정하지 않습니다**(꺼짐).
6. (선택) 스키마 사본: `scloud db connection`으로 접속 정보를 얻어 `pg_dump --schema-only`를 한 부 떠 둠. ⚠️ 접속 방식은 이 설계에서 시험하지 않았음.

### 8.4 배포 직후 확인

```bash
cd app/pageblink_server
scloud --non-interactive log --since 15m --limit 500 --raw \
  | grep -E 'Applied database migration|^.*- 2026|already applied|Failed to apply|does not match|is missing'
```

기대: `Applied database migration:` 다음 줄 ` - <새 버전>` 한 번, 이후 인스턴스는 `Latest database migration already applied.` **나오면 안 되는 것**: `Failed to apply database migrations`, `Database does not match target state`, `Table "ask_…" is missing`. 그 뒤 `ASK_HISTORY_ENABLED=true`로 설정하고 재배포(DEMO_ENABLED와 같은 절차, `plan/012 §4-2` 7차 참고)합니다.

### 8.5 실패 시 대응

| 상황 | 대응 |
|---|---|
| 적용 실패(롤백됨) | 서버는 뜸·기능은 꺼짐. 로그 확인 후 원인 수정, 새 마이그레이션이 아니라 같은 마이그레이션을 고쳐 재배포(적용 전이므로 안전) |
| 켠 뒤 문제 | `ASK_HISTORY_ENABLED=false` + 재배포(마이그레이션 단계 없음, 즉시 효과). 테이블은 남겨 둠 |
| 이미지 롤백 | 가능하나 §8.2-8 때문에 권장하지 않음. 플래그로 끄는 쪽을 우선 |
| 테이블 제거 필요 | 새 마이그레이션(파괴적 `--force`) 별도 배포. 이번 범위 아님 |

---

## 9. 개인정보·운영

| 항목 | 내용 |
|---|---|
| 민감도 | 질문·답변·인용 문서 제목은 **개인 노트 내용을 포함할 수 있음**. 민감 데이터로 취급 |
| 접근 통제 | 사용자: 본인 `ownerId`(+demo 키 해시)만. 관리자: `ADMIN_USER_IDS`(서버 판정, demo 제외, 읽기 전용, 접근 로그) |
| **로그에 질문 내용 금지** | 코드 규칙으로 못박음: `session.log`에 질문·답변·문서 제목을 넣지 않음. 오류는 `errorCode`(짧은 코드)만 저장하고 예외 메시지를 DB에 저장하지 않음 |
| **쿼리 로그 경로 (F7·F8)** | ORM이 값을 SQL에 박으므로 **느린(≥1초)·실패한 INSERT/UPDATE는 질문·답변 원문을 `serverpod_query_log`(90일)와 Cloud 로그에 남길 수 있음.** 대응: ① 모든 이력 쓰기·읽기를 `pod.withSession(enableLogging: false)`로 수행, ② 게이트 경합이 나지 않게 사전에 읽어 판정(실패 INSERT 최소화), ③ ⚠️ 이 경로가 실제로 비는지 통합 테스트로 확인(느린 쿼리를 인위로 만들어 `serverpod_query_log`를 조회) |
| 요청 세션의 다른 쿼리 | `AskEndpoint`의 기존 쿼리(문서 검색, 키워드 폴백 `ilike '%단어%'`)는 요청 세션이라 느리거나 실패하면 질문 단어가 로그에 남을 수 있음(기존 동작). 이번 범위에서는 변경하지 않으나 알려 둠 |
| 보관 기간 | 환경값: `ASK_HISTORY_RETENTION_DAYS`(기본 30). **설정 위치는 환경변수(재배포로 반영, DEMO_ENABLED 방식)** — 코드 상수로 박지 않음 |
| demo 별도 기간 | demo 기록은 공개 샘플 노트 대상이지만 방문자가 임의 텍스트를 입력할 수 있고 계정이 공유됨 → `ASK_HISTORY_DEMO_RETENTION_DAYS`(기본 **7**). 같은 30일로 하려면 같은 값으로 설정 (결정 D3) |
| 무료 모델로 전송 | 무료 모델은 `data_collection: deny`를 보내지 않음(ADR 014, `rag_services.dart`). 멀티턴은 **이전 답변(개인 노트에서 유래)도 함께 전송**하므로 노출이 한 턴 질문+근거에서 최대 9턴 이력으로 늘어남. 현 정책("데모는 공개 문서로만")을 개인 사용자에게도 고지할지 결정 필요 (D9) |
| 세션 로그 보관 | `serverpod_log`는 기본 90일(F7). 이력 보관(30일)과 어긋나 보이면 `config/production.yaml`의 `sessionLogs` 보관을 줄이는 방안 — ⚠️ 설정 키 형식은 확인하지 않음 |
| 탈퇴/계정 삭제 | 계정 삭제 기능이 있는지, 삭제 시 이력을 지울지는 확인하지 못함(⚠️). 현재는 30일 뒤 자연 삭제 |
| 개인정보 고지 | 앱·README에 "질문과 답변이 30일간 서버에 보관되고 관리자가 조회할 수 있음"을 명시 필요 (배포 전 문구 확정) |

---

## 10. 테스트 전략

### 10.1 서버 (통합: `test/integration/ask_history_test.dart`, `withServerpod`, 임베디드 Postgres)

`RagServices.debugEmbedding`/`debugLlm`(가짜)로 키·네트워크 없이 실행합니다(기존 `demo_test.dart` 패턴).

| 영역 | 케이스 |
|---|---|
| 생성·재사용 | `sessionId=0` → 대화 생성·`session` 이벤트·`questionCount=1`. `sessionId=<id>`로 이어 `seq=2`. 남의 `sessionId` → 거절 |
| 구버전 | `sessionId=null` → 숨김 1질문 대화 기록, 사용자 목록에 안 나옴, 한도·문맥 제외, 10번 연속 질문해도 막히지 않음 |
| 만료·창 | 시계 주입으로 29분/31분: 목록 포함/제외, 31분 뒤 `ask` → `expired`. 이어보기 29초/31초 → `current` 있음/없음. 스트리밍 중(체크포인트 신선)은 활동으로 계산 |
| 한도 | 10번째 성공, 11번째 `questionLimit`. 환경값 변경 반영. 한도 거절이 demo 일일 카운트를 깎지 않음 |
| 동시성 | 같은 대화 동시 두 질문 → 한쪽 `busy`. `streamingSince`가 31초 전인 고아 → 다음 질문 통과 + 이전 메시지 `interrupted` |
| 문맥 | 예산 8,000/답변 800/질문 500에서: 최신 턴 우선, 오래된 것부터 탈락, "구멍" 없음, 9턴 모두 들어가는 짧은 대화, 가장 최근 턴만 들어가는 극단, `[n]` 제거, 안내문 제거, 서로게이트 안전 자르기. 검색 질의 600자 상한과 현재 질문 우선. `ASK_PROMPT_MAX_CHARS`가 RAG를 건드리지 않고 문맥만 줄임 |
| 프로바이더 | OpenRouter/Claude가 이력을 user/assistant 메시지로 보냄(요청 본문 단위 테스트, 기존 `openrouter_provider_test`/`claude_provider_test` 확장), 로테이션 전달 |
| 중단 저장 | 가짜 LLM이 토큰 몇 개 후 대기 → 스트림 구독 취소 → 메시지가 `interrupted`로 부분 답변·인용과 함께 저장. 확정 쓰기가 요청 세션 종료 뒤에도 성공. 오류 이벤트 → `error` + `errorCode`(메시지 원문 없음). 무결과 안내문도 `done`으로 저장 |
| 삭제 | 30일 경과/미경과 대화 혼합 → 경과분만 삭제, 메시지 cascade. 배치 200 초과 반복. demo 7일 규칙. 두 번 실행해도 동일(멱등). 두 `tick`을 동시에 실행해도 오류 없음. 기회적 정리가 20개 이하·5분 제한 |
| demo | `DemoGuard.purgeExpired`가 타이머 틱에서 호출됨, `DEMO_ENABLED` 꺼짐/계정 없음에서 무동작, 24시간 지난 `method='demo'` 토큰 삭제·미만 유지 |
| demo 분리 | 키 A/B가 서로의 대화를 `restore/open`으로 못 봄. 키 없음 → 빈 응답·기록 없음. 같은 키가 ko/en 계정 사이에서 섞이지 않음. 후속 질문이 일일 상한에서 1회씩 차감 |
| 관리자 | `ADMIN_USER_IDS` 파싱(공백·대소문자·잘못된 항목·빈 값), 비관리자 `listSessions` 거절, demo 계정이 목록에 있어도 거절, 필터(사용자·기간·demo)와 키셋 페이지네이션, 숨김 대화 포함, 접근 로그 한 줄에 질문 텍스트 없음 |
| 로그 프라이버시 | 이력 쓰기를 느리게 만든 뒤 `serverpod_query_log`에 질문 문자열이 없음(`enableLogging: false` 확인) |
| 폴백 | 테이블 없음/DB 오류를 주입 → `ask`가 기록 없이 정상 응답 |

### 10.2 클라이언트 (위젯 테스트, 기존 `demoStatusCall` 같은 `@visibleForTesting` 호출 훅 방식)

| 영역 | 케이스 |
|---|---|
| 복원 | `restore`가 `current`를 주면 턴·인용 칩이 그려지고 칩 탭이 동작(기존 `ask_citation_flash_test` 경로 재사용). `current == null`이면 빈 대화+예시 질문 |
| 중단된 턴 | `interrupted` 표시와 "다시 질문"이 입력창을 채움(자동 전송 안 함) |
| 새 대화 | 모든 너비에서 버튼이 보임, 눌러 비우면 `sessionId=0`으로 다음 질문 전송 |
| 질문 수 | `3/10` 표시, `limit − count ≤ 2`에서 강조·"2개 남음", `limit`에서 입력 비활성+배너+버튼, 복원된 대화에서도 같은 값, 한도를 5로 바꿔도 따라감, 스크린리더 라벨 문구 |
| 오류 | `busy`/`expired`/`questionLimit`/`DemoLimitException` 문구, `expired` 자동 재전송 1회 |
| 폴백 | `restore` 실패 시 메모리 방식으로 질문 가능 |
| 방문자 키 | 저장소 정상/예외 두 경우 모두 키 생성, 호출에 키 전달 |
| 최근 대화 | 목록 표시·열기, 5개 상한 표시 |
| 설정 | "계정 ID 복사"가 `authUserId`를 클립보드에, demo에서는 숨김. 관리자 타일은 `isAdmin == true`일 때만. 관리자 화면 필터·펼침·더 보기 |
| 인증 | `ServerpodClientUnauthorized` 후 `validateAuthentication` 호출 |

---

## 11. 구현 단계·규모·되돌리기

줄 수는 **추정**(테스트 포함)입니다.

| 단계 | 내용 | 서버 | 클라이언트 | 독립 배포·되돌리기 |
|---|---|---|---|---|
| **P0** (마이그레이션 없음, 먼저 단독 배포 가능) | 주기 타이머 + demo 정리 호출 + 클라이언트 `validateAuthentication` 훅 | 약 80 + 테스트 80 | 약 40 + 테스트 40 | 가능. 플래그 `ASK_HISTORY_PURGE_ENABLED`(demo 부분은 `DEMO_ENABLED`). 코드 되돌리기로 충분 |
| **P1** 마이그레이션 + 저장만 | 모델 2개, 마이그레이션, `ask()` 래퍼·게이트·체크포인트·구버전 숨김 기록, 보관 삭제(타이머+기회적) | 약 650 + 테스트 450 | 변경 없음(생성 클라이언트만) | `ASK_HISTORY_ENABLED=false`로 배포 → 마이그레이션 적용 확인 → `true`. 문제 시 `false` 재배포 |
| **P2** 복원·새 대화·목록·질문 수 UI | `AskHistoryEndpoint`, 컨트롤러, 대화 바, 카운터, 방문자 키, 폴백 | 약 250 + 테스트 150 | 약 550 + 테스트 450 | 클라이언트는 서버 플래그가 꺼져 있으면(`enabled=false`) 메모리 방식. 되돌리기 = 플래그 |
| **P3** 멀티턴 | 문자 예산 이력 구성, 검색 질의, `LlmProvider` 인터페이스·구현체 4곳 | 약 300 + 테스트 250 | 없음(턴 표시는 P2) | `ASK_CONTEXT_ENABLED=false`로 즉시 되돌림 |
| **P4** 관리자 | `ADMIN_USER_IDS`, `AskAdminEndpoint`, 설정 화면 계정 ID 복사 + 대화 기록 화면 | 약 230 + 테스트 150 | 약 500 + 테스트 300 | `ADMIN_USER_IDS` 비우면 비활성(재배포). P1만 있으면 P2·P3보다 먼저도 가능 |

총 규모(추정): 서버 약 1,500줄 + 테스트 약 1,100줄, 클라이언트 약 1,100줄 + 테스트 약 800줄. 순서는 P0 → P1 → (P4 또는 P2) → P3. **보관 삭제가 P1에 들어 있는 이유**: 저장을 켜는 순간부터 30일 규칙이 지켜져야 하기 때문입니다.

### 환경값 총정리 (비밀값 이름은 camelCase, 환경변수는 대문자. 기존 `DemoConfig` 패턴: 비밀값 우선 → 환경변수)

`ASK_HISTORY_ENABLED`(false) · `ASK_HISTORY_VISIBLE_MINUTES`(30) · `ASK_HISTORY_RESUME_SECONDS`(30) · `ASK_HISTORY_RETENTION_DAYS`(30) · `ASK_HISTORY_DEMO_RETENTION_DAYS`(7) · `ASK_MAX_QUESTIONS_PER_SESSION`(10) · `ASK_MAX_VISIBLE_SESSIONS`(5) · `ASK_STREAM_STALE_SECONDS`(30) · `ASK_CONTEXT_ENABLED`(true) · `ASK_CONTEXT_CHARS`(8000) · `ASK_CONTEXT_ANSWER_CHARS`(800) · `ASK_CONTEXT_QUESTION_CHARS`(500) · `ASK_QUESTION_MAX_CHARS`(2000) · `ASK_QUERY_MAX_CHARS`(600) · `ASK_PROMPT_MAX_CHARS`(20000) · `ASK_PURGE_INTERVAL_MINUTES`(60) · `ASK_HISTORY_PURGE_ENABLED`(true) · `ADMIN_USER_IDS`(빈 값)

### 위험 목록

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | 저장된 질문·답변이 쿼리 로그(90일)에 남음(F8) | 개인정보, 30일 규칙 위반 | `enableLogging:false` 세션, 사전 읽기, 통합 테스트로 검증 |
| R2 | 취소가 LLM 청크 대기 때문에 늦어져 `busy`가 잠깐 나옴 | UX | 체크포인트·30초 stale·안내 문구 |
| R3 | 마이그레이션 실패 상태로 새 코드가 뜸 | 이력 기능 불가 | best-effort 저장 + 플래그 꺼진 채 첫 배포 |
| R4 | 이미지 롤백 시 부팅마다 오류 로그, Cloud가 실패로 볼 가능성(⚠️) | 롤아웃 | 롤백 대신 플래그로 끄기 |
| R5 | 캐시된 구버전 클라이언트 | 기록만 되고 한도 미적용 | `sessionId == null` 규칙(§3.1) |
| R6 | demo 일일 카운터가 인스턴스별(F3) | 상한 초과·표시 불일치 | 기존 한계(plan 014 L5). DB 집계로 교체는 별도 |
| R7 | 이전 답변 전송으로 무료 모델 노출 확대 | 개인정보 | D9 결정·고지 |
| R8 | 후속 질문 검색이 직전 질문 때문에 흐려짐 | 품질 | 현재 질문 우선·길이 상한, 평가 질문으로 확인 |
| R9 | 만료 경계(31분째)에서 열린 탭이 `expired`로 대화를 잃음 | UX | 안내 + 자동 재전송 |
| R10 | 열린 탭이 로그아웃되지 않고 401만 반복(F12) | demo/일반 모두 | P0 클라이언트 훅 |
| R11 | 주기 `Timer`가 종료를 지연(⚠️) | 롤아웃 시간 | 확인 후 `cancel()` |

---

## 12. CTO가 결정할 것 (추천 포함)

| # | 결정 | 선택지 | 추천 | 시점 |
|---|---|---|---|---|
| **D1** | 사용자가 대화를 지울 수 있는가 (개인정보 vs 30일 관리 보관) | A 삭제 없음 / B 숨김(서버 30일 유지, 고지) / C 즉시 영구삭제 | **B** (스키마에 `hiddenAt` 포함, UI는 나중에도 가능) | **마이그레이션 생성 전** |
| D2 | "30분 안 5개 대화"의 의미 | A 목록 표시 상한(6번째는 오래된 것을 밀어냄) / B 생성 차단(`retryAfter` 안내) | **A** (구버전·남용 우려는 질문당 LLM 비용이 막고, 구현이 단순) | P2 전 |
| D3 | demo 기록 보관 | 7일 / 30일 / 24시간 | **7일** (환경값으로 조정) | P1 전 |
| D4 | 관리자 목록 단위 | 대화 단위 펼침 / 메시지 평면 목록 | **대화 단위 펼침**(메시지 평면이면 `ask_message`에 `ownerId`·인덱스 추가 필요) | **마이그레이션 생성 전** |
| D5 | 관리자 접근 감사 | 로그 한 줄(90일) / 감사 테이블 추가 | **로그 한 줄**로 시작(테이블 3개가 되면 스키마가 커짐) | P4 전 |
| D6 | 실패·중단된 질문도 10개에 센다 | 센다 / 안 센다 | **센다**(요청 횟수 한도를 소모하므로) | P1 전 |
| D7 | 첫 배포를 기능 꺼진 채로 나가고 다음 배포에서 켠다 | 2단계 / 한 번에 | **2단계**(마이그레이션 적용 로그를 확인한 뒤 켬) | 배포 때 |
| D8 | 스트리밍 중 새로고침 후 | 끊긴 답변 표시+"다시 질문" / 재접속해 이어받기 | **표시+다시 질문**(Serverpod 스트림은 연결에 묶여 이어받기 불가) | 확정 |
| D9 | 무료 모델로 이전 답변 전송 고지 | 고지 후 허용 / 무료 모델에는 이력 미전송 | **고지 후 허용**(현재도 근거를 보냄), 필요하면 환경값으로 무료 모델 이력 끔 추가 | P3 전 |
| D10 | 질문 길이 상한 2,000자 도입 | 자르기 / 거절 / 도입 안 함 | **자르기**(클라이언트 입력창도 2,000자 제한) | P1 전 |
| D11 | 구버전 기록을 사용자 목록에서 숨김 | 숨김 / 노출 | **숨김**(`hiddenAt`) | P1 전 |

---

## 13. ⚠️ 미확인 목록

1. Cloud 롤아웃이 옛 이미지의 `Failed to apply database migrations` 오류 로그·(maintenance 역할이면) 종료 코드 1을 실패로 보는지.
2. `pg_try_advisory_xact_lock`을 `unsafeQuery`로 부르는 코드의 동작(임베디드 Postgres 통합 테스트로 확인).
3. 느리거나 실패한 쓰기가 `enableLogging:false` 세션에서 실제로 `serverpod_query_log`를 만들지 않는지(테스트로 확인).
4. 주기 `Timer`가 Serverpod 정상 종료를 지연시키는지.
5. Starter DB 저장 한도, `sessionLogs.retentionPeriod` 설정 키 형식.
6. 계정 삭제 기능과 이력 연동 여부.
7. 삭제·수정된 문서를 가리키는 복원 칩이 안전하게 실패하는지(클라이언트).
8. 모델 컨텍스트 길이 값(코디네이터가 OpenRouter 목록에서 확인한 값을 그대로 인용, 제가 재조회하지 않음)과 §4.7의 지연 추정치.
9. 후속 질문에서 직전 질문을 붙인 검색의 품질 효과(미측정).
10. 서버 2초 안에 응답하지 못할 때 시작 시 `validateAuthentication`이 건너뛰어지는 경우의 UX.
11. demo 일일 카운터의 인스턴스별 표시 차이(기존 한계).

---

## 부록 A. 이 설계가 건드리는 파일

- 서버: `lib/src/models/` (spy.yaml 2 테이블 + DTO 약 8), `lib/src/rag_endpoints/ask_endpoint.dart`(래퍼·`_answer`), `lib/src/rag_endpoints/ask_history_endpoint.dart`·`ask_admin_endpoint.dart`(신규), `lib/src/services/ask_history_store.dart`·`ask_history_purge.dart`·`ask_config.dart`(신규), `lib/src/rag/chat_context.dart`(신규, 이력 구성), `lib/src/providers/*`(인터페이스+3곳), `lib/server.dart`(+3줄), `migrations/`(생성), `test/`.
- 클라이언트: `lib/features/ask/ask_chat.dart`·`ask_screen.dart`, `lib/features/settings/settings_screen.dart`·`admin_history_screen.dart`(신규), `lib/app/visitor_key.dart`(신규), `lib/app/l10n.dart`, `lib/main.dart`(인증 훅), 생성된 `pageblink_client`.
- 문서: `docs/adr/`(결정 D1·D2·D4·D5·D9 확정 시), `docs/plan/`(단계), `docs/reference/`(보관·관리자 고지).

---

## 출처 (코드·문서, 저장소 내)

- 코드: 저장소 소스(§1 표의 `파일:줄` 근거)
- 패키지 소스: pub 캐시의 Serverpod 4.0.4
- 운영 확인: `scloud` 읽기 전용 명령(배포 목록·로그)
- 마이그레이션 스케치: HEAD를 `git archive`로 scratchpad에 풀어 만든 복사본에서 돌린 `serverpod generate`/`create-migration` (증거용, 저장소에 없음)
- 문서: [ADR 014](../adr/014-model-catalog-and-rotation.md) · [plan 014](../plan/014-demo-account.md) · [research 021](021-sample-note-delete-and-project-edit.md) · [research 026](026-demo-account-api-verification.md)
