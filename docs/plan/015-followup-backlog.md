# 📋 후속 개선 백로그 — 다른 세션이 이 문서만 읽고 이어가기 위한 인수인계

> **작성일**: 2026-10-16 16:22 KST · **최종 수정**: 2026-10-16 16:53 KST
> **관련 문서**: [세션 인수인계 (012)](012-session-handoff.md) · [devlog 012 (10~15차)](../devlog/012-releases-10-to-15.md) · [ADR 023 (OCR 미제품화)](../adr/023-no-scanned-pdf-recovery.md) · [ADR 024 (모델 기본값·로테이션)](../adr/024-ask-model-default-reasoning-off-paid-fallback.md) · [research 033 (지연·로테이션)](../research/033-llm-latency-and-rotation.md) · [research 034 (접근성 점검)](../research/034-accessibility-audit.md) · [상호작용 상태 명세](../design/interaction-states/spec.md) · [Ask 대화 UI 명세](../design/ask-history-ui/spec.md) · [research 030 (Ask 대화 기록)](../research/030-ask-sessions.md) · [`AGENTS.md`](../../AGENTS.md) · [`app/AGENTS.md`](../../app/AGENTS.md)
> **표기**: ✅ 이 문서를 쓰며 저장소(`main` `686e4aa`의 코드·`git log`)로 확인 · ⚠️ 전달받은 값이거나 미확인(그대로 믿지 말고 직접 재확인) · 확인 필요 = 값을 알지 못함
> **용도**: CTO가 "후속 개선은 다른 세션에서 하게 md로 정리하라"고 해서 만든 문서입니다. 새로 시작한 Claude 세션은 **이 대화를 전혀 모릅니다.** §1(현재 상태)과 §3(작업 방식)을 먼저 읽고, §2에서 항목을 골라 작업→검증→배포까지 진행할 수 있게 썼습니다. 우선순위·규모는 작성자의 **제안**이며 CTO 결정이 우선합니다.

---

## 1. 현재 상태 한눈에

| 항목 | 값 |
|---|---|
| 제품 | PageBlink — Flutter + Serverpod 하이브리드 문서 RAG 앱 (Serverpod 해커톤 2026) |
| Git | `main` = `686e4aa` (15차) ⚠️ 전달값. 15차 커밋 3개: `613a2fd`(OCR 제거) · `4757d20`(PDF 미리보기 표시·검색) · `686e4aa`(Ask 헤더·최근 대화 메뉴) ✅ git |
| 배포 | 15차 배포 ID `6e96b5eb-1d97-4ddb-a3d5-2664a4a207ea`, 성공 16:13 KST ⚠️ 전달값. 이전: 14차 `b64747f` / `d0ce83cf-5a48-4f18-9bc2-47a6870b4fe3` ([devlog 012](../devlog/012-releases-10-to-15.md) 표) |
| 테스트 (15차 기준) | 서버 `dart test` 316개, Flutter `flutter test` 1,369개 ⚠️ 전달값 |
| 버전 | Flutter 3.47.7 (`.fvmrc`), Serverpod 4.0.4 (모든 `serverpod*` 동일) ✅ [`AGENTS.md`](../../AGENTS.md) |
| 라이브 | 웹 https://pageblink.serverpod.space · API https://pageblink.api.serverpod.space (호출 형식 `POST /<endpoint>/<method>`) ⚠️ 전달값 |
| 호스팅 | Serverpod Cloud (`scloud`), 프로젝트 `pageblink`. `scloud.yaml`의 `pre_deploy`가 `serverpod generate`와 `serverpod run flutter_build`를 실행 ✅ |

### 1-1. DB 마이그레이션 체인 (모두 운영 적용됨 ⚠️ 전달값)

`app/pageblink_server/migrations/` 끝부분 ✅:

| 순서 | 마이그레이션 | 내용 |
|---|---|---|
| 1 | `20261016042828611-ask-history` | `ask_session` · `ask_message` 테이블 추가 (13차) |
| 2 | `20261016055710840-note-color` | `document.colorIndex` 널 허용 컬럼 (타 세션 배포) |
| 3 | `20261016062428206-pdf-recovery-and-preview` | `doc_page.source`(휴면) + `document.preview`(사용 중) 컬럼 (14차) |

새 마이그레이션은 이 체인 **뒤에 병합 후 새로 생성**합니다 (§3-1).

### 1-2. 운영 환경값 이름 (값은 이 문서에 적지 않음 — 비밀값은 `config/passwords.yaml`(git 제외) 또는 Serverpod Cloud 비밀값)

코드에서 읽는 이름 ✅ (`git grep`):

| 이름 | 용도 |
|---|---|
| `DEMO_ENABLED` | demo 계정 켜기 (운영 켜짐 ⚠️) |
| `DEMO_SESSION_IDLE_MINUTES` / `DEMO_SESSION_MAX_MINUTES` | demo 세션 유휴(기본 60) / 절대(기본 240) 만료 |
| `REINDEX_ON_BOOT` / `CHUNKER_VERSION` | 부팅 후 재색인 / 청크 규칙 버전 ([ADR 021](../adr/021-line-level-chunks-two-tier-context.md)) |
| `LLM_ROTATION` | `free`(코드 기본) · `all`(자동 유료 폴백) · `off`. 운영 값은 확인 필요 ⚠️ |
| `LLM_FREE_ATTEMPTS` (기본 2) · `LLM_FIRST_TOKEN_TIMEOUT_SECONDS` (기본 10) · `LLM_PAID_DAILY_CAP` (기본 300, 0이면 폴백 끔) | [ADR 024](../adr/024-ask-model-default-reasoning-off-paid-fallback.md) |
| `ASK_HISTORY_ENABLED` | Ask 대화 기록 스위치 (끄면 13차 이전 동작) |
| `ASK_HISTORY_RETENTION_DAYS` · `ASK_HISTORY_DEMO_RETENTION_DAYS` · `ASK_SESSION_MAX_QUESTIONS` · `ASK_SESSION_RESUME_SECONDS` · `ASK_SESSION_VIEW_MINUTES` · `ASK_SESSIONS_LISTED` · `ASK_CONTEXT_BUDGET_CHARS` · `ASK_CONTEXT_ANSWER_CHARS` · `ASK_PROMPT_MAX_CHARS` · `ASK_QUESTION_MAX_CHARS` · `ASK_QUERY_JOIN_CHARS` | 대화 기록·문맥 예산 조정값 |
| `ADMIN_USER_IDS` | 관리자(대화 기록 조회) 사용자 ID 목록. **현재 미설정** ⚠️ — 사용자(CTO)가 설정 화면 "내 계정 ID 복사"로 ID를 주면 설정 |
| `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` | **이제 미사용** ⚠️ (15차에서 `flutter_cache_control.dart`가 삭제됨 ✅ git). 운영에 값이 남아 있는지는 확인 필요 |
| 비밀값 `llmModel` (`passwords.yaml`) | 기본 모델 덮어쓰기. **운영에 설정돼 있지 않아야** 함 (§2-10) |

### 1-3. 데모 계정

| 계정 | 값 |
|---|---|
| 영어 | `demo@pageblink.invalid` |
| 한국어 | `demo-ko@pageblink.invalid` |
| 로그인 | `Demo.signIn(locale)` — 인자가 없거나 `ko`가 아니면 영어 ✅ (`demo_endpoint.dart`) |
| 질문 일일 상한 | 50회, **두 계정이 전역 공유** (`demoAskDailyLimit`) ✅. 라이브 확인으로 소모하면 방문자의 몫이 줄어든다 |
| 그 밖의 한도 | 생성 5개(`demoCreateLimit`), 보관 24시간(`demoRetention`) ✅ `demo_config.dart` |

---

## 2. 후속 개선 항목

> **16차 반영** (배포 후 기록 예정 ⚠️ — 배포 ID · 성공 시각은 [devlog 013](../devlog/013-release-16-ux-round2-backlog.md)에서 채움): 2-1 · 2-2 · 2-5 · 2-7 완료, 2-10 일부 확인. 검증 수치(서버 341 · Flutter 1,512, 클린 워크트리)는 devlog 013.

범례: 규모 S ≤ 0.5일 / M 1~2일 / L 3일+ (plan 013과 같은 기준). 우선순위 P1 먼저 · P2 · P3 나중 (제안).

| # | 항목 | 우선순위 | 규모 | DB 마이그레이션 |
|---|---|---|---|---|
| 1 | 안내 배너 오버플로 — ✅ 완료(16차) | P1 | S | 없음 |
| 2 | 다크 노트 카드 hover 보조 글자 대비 — ✅ 완료(16차, 잔여는 8-i) | P2 | S | 없음 |
| 3 | 권한·검증 오류 정식화 (HTTP 500 → 직렬화 예외) | P1 | M | 없음 |
| 4 | 편집기 키보드 전용 서식 경로 | P2 | L | 없음 |
| 5 | 서술형 짧은 답변 인용 보정 확대 — ✅ 완료(16차) | P2 | M | 없음 |
| 6 | 모델 로테이션 재평가 | P3 | S | 없음 |
| 7 | 한국어 계정 샘플 PDF 미리보기가 영어로 시작 — ✅ 완료(16차) | P3 | S | 없음 |
| 8 | 접근성 잔여 | P3 | M | 없음 |
| 9 | 대화 기록 후속 | P3 | M | 없음(비테이블 모델 기준) |
| 10 | 운영 확인·정리 — 1·3·4·5번 확인함(16차), 2·6번 남음 | P1 | S | 없음 |
| 11 | 보류·폐기된 것 | – | – | – |

### 2-1. 안내 배너 오버플로

> ✅ **완료 (16차, `ae262b7`, 배포 후 반영 ⚠️)**: `_HistoryNotice`가 큰 글자(시스템 글자 2배)에서 오버플로 없이 표시된다. 오버플로 매트릭스 테스트를 배너 표시 상태로 확장했다. 아래는 구현 전 분석이다.

| 항목 | 내용 |
|---|---|
| 문제와 증거 | Ask 화면의 기록 안내 배너 `_HistoryNotice`가 시스템 글자 크기 **2배**에서 세로로 넘친다(RenderFlex overflow). 전달받은 측정(⚠️): 클린 `b64747f`에서 320×700·영어·2배일 때 135px, 15차 후 28px, **배너를 닫으면 0**. 위젯은 `Container` 안의 `Row`(정보 아이콘 + `Expanded(Text 12px)` + 닫기 `IconButton`)이고 높이 제한이 없다 ✅ |
| 관련 파일 | `app/pageblink_flutter/lib/features/ask/ask_screen.dart` — 클래스 `_HistoryNotice`(약 1493줄), 사용처 `if (historyOn && _noticeShown)`(약 303줄) ✅. 문구는 `l.historyNotice(status!.retentionDays)`(`l10n.dart`) |
| 시도했다 폐기한 접근 (미완) | 배너 최대 높이를 **창 높이의 20%(최소 72 ~ 최대 200)** 로 제한하고 그 안에서 `SingleChildScrollView`로 스크롤. 완성·검증하지 못하고 접었다. 같은 접근을 쓸 수도, 더 나은 방법을 찾을 수도 있다 |
| 제안 접근 | 위 접근 + 스크린리더가 **전체 문구를 읽어야** 하므로 `Semantics`로 스크롤 영역이 아니라 전체 텍스트를 노출(잘린 문구를 읽지 않게). 닫기 버튼은 스크롤과 무관하게 항상 보이게 |
| 완료 기준 | 320/390/768/1280 × 한/영 × 1배/2배 모두 오버플로 0, **배너가 보이는 상태에서도**. 닫기 동작·`dismissNotice()` 저장은 그대로 |
| 위험 | 20% 제한이 아주 낮은 창(키보드가 올라온 모바일)에서 본문을 가림. 스크롤 영역 안의 텍스트 선택·접근성 노드 중복 |
| 필요한 테스트 | 기존 오버플로 매트릭스를 **배너 표시 상태**로 확장. 현재 `test/ask_header_test.dart`가 `textScaler`로 크기를 바꾸며(`_pump(..., scale: 2)`, 320×1500 ·320×700 등) 돌지만 **닫은 상태**로 실행한다 ✅. 배너를 닫지 않은 `status`로 같은 매트릭스를 돌리는 케이스를 추가 |

### 2-2. 다크 노트 카드 hover 보조 글자 대비

> ✅ **완료 (16차, `5b23005`, 배포 후 반영 ⚠️)**: 노트 · PDF 카드 메타 글자가 다크 hover에서도 AA(4.5:1)를 유지한다. **남은 것**: 다크 `inkMuted`가 Ask 답변 카드 · 인용 하이라이트 위에서 **2.1~3.9:1** — 이번에 고치지 않았다 → §2-8 i의 잔여. 아래는 구현 전 분석이다.

| 항목 | 내용 |
|---|---|
| 문제와 증거 | 노트 팔레트(`colorIndex` 0..7 단색, 8 무지개)와 PDF 카드(`pb.pdfPaper`) 위에서 hover(흰 6%)일 때 12px 메타 글자(`inkMuted`)의 대비가 **다크에서 최소 4.09:1**(AA 4.5 미달). hover 없음 4.79, 라이트 최소 5.19 ⚠️ 전달 측정값 |
| 관련 파일 | `app/pageblink_flutter/lib/app/theme.dart`(`Pb.dark`의 `hover` `0x0FFFFFFF`, `inkMuted`, `notes` 팔레트, `pdfPaper`), `lib/features/documents/documents_screen.dart`(카드 메타 글자), 값의 설계 근거 [ui-polish/spec.md §8](../design/ui-polish/spec.md) |
| 제안 접근 | 후보 ① 다크 카드 hover 틴트를 6→4%로 낮춤 ② 카드 메타 글자 색을 다크에서 한 단계 올림. 카드는 "면 색 유지 + 그림자"가 원칙([interaction-states §5.8](../design/interaction-states/spec.md))이므로 ②가 UI 변화가 작다 |
| 완료 기준 | 팔레트 전부 × 라이트/다크 × 기본/hover/pressed에서 **합성 배경 위** 메타 글자 대비 ≥ 4.5:1. 무지개(8)는 양 끝·중간 3곳 |
| 위험 | `inkMuted`는 전역 토큰이라 다른 화면에 번질 수 있음 → 카드 전용 색으로 분리하는 편이 안전. 다크 합성값은 BackdropFilter 미반영 계산이라 실기 확인 필요([interaction-states §9](../design/interaction-states/spec.md)) |
| 필요한 테스트 | `test/a11y_states_test.dart`의 대비 계산(`the text on the new hover/pressed faces keeps its contrast` 등)을 확장해 위 매트릭스를 단언 ✅ 파일 존재 |

### 2-3. 권한·검증 오류 정식화 (HTTP 500 → 직렬화 예외)

| 항목 | 내용 |
|---|---|
| 문제와 증거 | 일반 `Exception`/`ArgumentError`는 Serverpod이 직렬화하지 못해 클라이언트에는 **HTTP 500**으로 도달하고 서버에는 ERROR 스택이 남는다. 근거: `lib/src/services/acl.dart:43`의 `AccessDeniedException implements Exception`(`Acl.requireUser` 11줄, `Acl.requireRole` 37줄에서 throw) ✅, `Acl.require*` 호출처는 `git grep` 기준 **32곳**(전달받은 추정은 약 17곳 — 직접 센 값을 따르세요) ✅, `lib/src/demo/demo_endpoint.dart:59`(`signIn`: demo 꺼짐 → `AccessDeniedException`) ✅, `lib/src/rag_endpoints/document_endpoint.dart`: 439줄 `ownerId` 불일치 시 `AccessDeniedException`, 413줄 `on AccessDeniedException`(재색인 루프에서 삼킴), `setNoteColor` 부근 218줄 `ArgumentError('Invalid color')` · 222줄 `ArgumentError('Note not found')`, 그 밖에 186 · 327 · 372줄의 `ArgumentError`(Note/PDF/Document not found) ✅ |
| 이미 정식인 것 | `DemoLimitException`, `AskAdminException`, `AskLimitException` (`lib/src/models/*_exception.spy.yaml`) ✅ — 새 예외의 모델 |
| 조사 포인트 | **Serverpod 4.0.4 표준**(서버가 던진 예외를 403/400으로 매핑하는 기능이 있는지) 확인. 없으면 `exception:` 모델 추가 후보: `AccessDenied{reason}`, `InvalidRequest{field}`. 기존 `AskAdminException`(14차)이 모양의 선례 |
| 제안 접근 | ① 표준 확인 → ② 모델 추가 + `serverpod generate` → ③ `AccessDeniedException`을 새 예외로 교체(호출처는 `Acl` 두 곳이 대부분이라 영향 작음) → ④ `setNoteColor`(잘못된 값·없는 노트·샘플 잠금)·PDF 관련 오류를 `InvalidRequest`로 → ⑤ 클라이언트는 **한곳**에서 한/영 문구로 변환(`lib/features/auth/session_end.dart`의 `SessionGuard`가 401 처리 중이므로 **이중 처리 금지**) |
| 완료 기준 | 권한·검증 실패가 클라이언트에서 정해진 예외 타입으로 오고 서버 로그에 ERROR 스택이 쌓이지 않는다. 라이브에서 비로그인 401은 그대로, 샘플 잠금은 기존 `DemoLimitException(sampleLocked)` 400 유지 |
| 위험 | 생성 코드·`l10n.dart`를 건드려 다른 UI 작업과 충돌(§4). 기존 클라이언트가 500을 가정한 곳(예: 재색인 루프의 `on AccessDeniedException` 삼킴)이 깨짐. 다른 세션(`pageblink-f9`)이 "`setNoteColor` invalid-value / PDF errors를 500에서 400으로 완화"를 요청할 수 있음 ⚠️ — 겹치지 않게 먼저 조율 |
| 필요한 테스트 | 서버: 비로그인·비멤버·잘못된 색·없는 노트·demo 꺼짐 각각의 예외 타입 단언(`test/integration`). 클라이언트: 예외→문구 변환과 `SessionGuard` 무간섭 |

### 2-4. 편집기 키보드 전용 서식 경로

| 항목 | 내용 |
|---|---|
| 문제와 증거 | 노트 편집기의 툴바 · 제목 메뉴 · 링크 팝오버 · 선택 미니바가 `ExcludeFocus`로 감싸여(본문 캐럿·선택 유지가 설계 의도) 키보드로 쓸 수 없다. 현재 단축키는 **Ctrl/Cmd+B · I뿐** ✅ (`note_editor_screen.dart` 1422~1424줄). `ExcludeFocus` 위치 ✅: `note_editor_screen.dart:1046`(툴바), `link_popover.dart:160`, `selection_mini_bar.dart:120` |
| 관련 파일 | `app/pageblink_flutter/lib/features/notes/`(`note_editor_screen.dart`, `markdown_live.dart`, `link_popover.dart`, `selection_mini_bar.dart`) |
| 제안 순서 | ① **단축키 추가**: 링크 Mod+K, 취소선·목록·인용·코드, 제목은 **H1~H3만**(편집기가 H1~H3로 제한됨, `b37fb3d`) Alt+1~3 ② 서식 메뉴를 단축키로 열면 메뉴로 포커스를 옮기고, 닫으면 **본문 캐럿과 선택을 복원** ③ **Alt+F10으로 툴바 로빙 포커스**, Esc로 본문 복귀. 툴팁에 단축키 표기 |
| 완료 기준 | 마우스 없이 서식 적용·링크 입력이 가능. 포커스 이동 뒤에도 캐럿 위치·선택 범위·IME 조합이 유지 |
| 위험 / 주의 | **IME·선택 오프셋 불변 원칙**: `markdown_live.dart` 머리 주석(텍스트를 바꾸지 않고 `buildTextSpan`으로만 스타일). 편집기 서식 버튼 터치 영역이 **40×32**이고 간격을 단언하는 테스트가 이 크기에 고정돼 있다는 전달이 있음 ⚠️ (테스트 위치는 이 문서를 쓰며 `git grep`으로 찾지 못함 — 확인 필요). 단축키가 브라우저·OS 기본 단축키(Alt+숫자 등)와 겹치는지 웹에서 실측 |
| 필요한 테스트 | 위젯 테스트: 단축키별 결과, 메뉴 닫은 뒤 선택 복원, IME 조합 중 단축키 무시. 기존 `note_editor_live_ui_test.dart` · `markdown_live_rules_test.dart` 회귀 |

### 2-5. 서술형 짧은 답변 인용 보정 확대

> ✅ **완료 (16차, `af76003`, 배포 후 반영 ⚠️)**: 구별 토큰(날짜 · 숫자+단위 등) 기반 서버 보정을 `citation_infer.dart`에 추가하고 테스트 케이스를 `citation_infer_cases.dart`에 두었다. 운영에서의 오연결 빈도는 서버 로그 `ask: inferred citations n=…`로 확인 필요 ⚠️. 아래는 구현 전 분석이다.

| 항목 | 내용 |
|---|---|
| 문제와 증거 | 모델이 `[n]` 마커를 하나도 안 쓴 답변에 서버가 보정 인용을 붙인다(`Citation.inferred`). `lib/src/rag/citation_infer.dart` ✅: **정방향**(근거 줄이 답변에 포함, 정규화 후 6자 이상) + **역방향**(답변 구절 6~80자가 근거 줄에 포함, 같은 구절이 **근거 4줄 이상**에 있으면 모호로 무시, 최대 3개). "출시일은 2026년 11월 18일입니다."처럼 어미·주어가 붙은 답변은 구절 전체가 근거 줄에 없어서 못 잡는다 |
| 관련 파일 | `app/pageblink_server/lib/src/rag/citation_infer.dart`, 호출부 `rag_endpoints/ask_endpoint.dart`(`session.log('ask: inferred citations n=…')` 약 431줄 ✅), 테스트 `test/unit/citation_infer_test.dart` |
| 제안 접근 | 문장 전체 일치 대신 날짜 · 숫자+단위 같은 **구별 토큰** 단위 일치. 오연결 방지: 구별 토큰 **2개 이상** 또는 긴 토큰만 인정, 여러 근거에 걸리면 무시(현 모호 규칙 유지) |
| 평가 방법 (필수) | 진단 답변 30개 — scratchpad `citefix/results_ab.jsonl`, `results_c.jsonl`(스크립트 `run.py`, `lexmatch.py`) ⚠️ **임시 폴더라 사라졌을 수 있음**. 없으면 합성 서술형 답변으로 직접 만든다. **오연결 수를 직접 계산해 보고**한다(정확도 주장만 쓰지 않기). 운영 빈도는 서버 로그 `ask: inferred citations n=…` 줄을 며칠 모아 확인 |
| 참고 수치 | 마커 없는 답변 비율: 진단값 **약 35%**(커밋 `af4259f` 메시지 ✅), 프롬프트 보강 후 라이브 9회 중 1회 ⚠️ 전달값 |
| 완료 기준 | 진단 세트에서 새로 붙은 인용의 오연결 0(또는 보고된 수 이하), 기존 테스트 통과 |
| 위험 | 오연결은 "근거 있는 척" 하는 거짓 출처라 미연결보다 해롭다 → 보수적으로. 한국어 조사·어미 변형 |
| 필요한 테스트 | 단위 테스트에 서술형 케이스(맞는 연결 / 모호 / 숫자만 같은 오연결 후보) 추가 |

### 2-6. 모델 로테이션 재평가

| 항목 | 내용 |
|---|---|
| 현재 | 기본 `nvidia/nemotron-3-super-120b-a12b:free`(추론 끔), 자동 로테이션 super → ultra → `google/gemini-3.1-flash-lite` → `google/gemini-3.8-flash`. gemma(35분간 429)·lightning(무응답)·nano(불안정)는 수동 선택 전용 ✅ [`llm_catalog.dart`](../../app/pageblink_server/lib/src/services/llm_catalog.dart) · [ADR 024](../adr/024-ask-model-default-reasoning-off-paid-fallback.md) |
| 할 일 | 무료 모델 상류 한도가 풀리면 [research 033](../research/033-llm-latency-and-rotation.md) 방식으로 **재측정**. 스크립트는 scratchpad `bench/bench2.py`(측정) · `agg.py`(집계) ⚠️ 임시 폴더 — 없으면 문서의 요청 형식(`openrouter_llm_provider.dart`와 동일, 유료 모델만 `provider.data_collection: deny`)대로 다시 작성. gemma 재측정 예: `python3 bench.py results4.jsonl 300 google/gemma-4-26b-a4b-it:free` (research 033 §A 7) |
| 규칙 | **API 키는 환경변수**로만(파일·출력에 쓰지 않음), 프롬프트는 **합성 텍스트만**(무료 모델은 입력이 수집될 수 있음), 요청 간격 5초 이상, 429 뒤 쉬고 재시도, 호출 수 상한을 미리 정할 것 |
| 미평가 | 추론을 끈 모델의 **답변 품질**(인용 정확도 포함)은 평가한 적 없음 ⚠️ |
| 완료 기준 | 새 측정으로 `docs/research/`에 다음 일련번호의 조사 문서를 작성, 필요하면 ADR로 순서·기본값 변경 |

### 2-7. 한국어 계정 샘플 PDF 미리보기가 영어로 시작

> ✅ **완료 (16차, `3c18216`, 배포 후 반영 ⚠️)** — 구현 내용: 한국어 팩 전용 PDF `web/samples/pageblink-guide-ko.pdf`(한국어만, 3쪽, 약 20KB)와 `SamplePacks.demoPdfKo`를 추가하고 `demoKo.pdf`가 이를 가리킨다. 영어 팩의 `demoPdf`(영·한 병기, 영어 먼저)는 **바이트 단위로 그대로**라 영어 계정은 재시드되지 않는다. 생성 스크립트는 `scripts/build_sample_pdf_ko.sh`(XeLaTeX + Pretendard, 같은 입력이면 같은 바이트). 한국어 계정은 새 해시의 PDF가 새로 시드되고, 옛 영어 먼저 PDF 행은 `DemoSeed.run`이 지운다(PDF 해시만, 방문자 문서·다른 팩 노트는 건드리지 않음). 아래 표는 구현 전 분석이다.

| 항목 | 내용 |
|---|---|
| 문제와 증거 | 샘플 PDF `app/pageblink_server/web/samples/pageblink-guide.pdf` ✅ 가 영·한 병기이고 **첫 쪽이 영어**라, 한국어 계정 PDF 카드의 `preview`가 영어로 시작한다 ⚠️ 전달값 |
| 제안 접근 | 한국어 전용 PDF를 따로 두거나(`SamplePack`의 `pdf` 필드로 언어별 지정, [ADR 022](../adr/022-per-locale-demo-accounts-sample-pack.md)) 앞쪽 구성을 바꾼다. **PDF를 다시 만들어야 함** |
| 주의 | PDF 본문의 숫자(**5개 · 24시간 · 50회**)가 `lib/src/demo/demo_config.dart`의 상수(`demoCreateLimit=5`, `demoRetention=24h`, `demoAskDailyLimit=50`)와 **일치**해야 한다 ✅. 상수를 바꾸면 PDF도 다시 만든다 |
| 규모 / 영향 | 영향 작음. 기존 샘플 PDF 문서 행은 `contentHash` 표식으로 관리되므로 PDF를 바꾸면 재시드 동작을 확인([plan 014](014-demo-account.md)) |
| 필요한 테스트 | `SamplePack`의 `evidence`가 PDF/노트 본문에 있는지 확인하는 기존 단위 테스트(ADR 022) 유지 |

### 2-8. 접근성 잔여

근거: [research 034](../research/034-accessibility-audit.md), 기준 [상호작용 상태 명세](../design/interaction-states/spec.md). 항목 번호 #는 034의 53개 점검 번호입니다.

| # | 잔여 | 메모 |
|---|---|---|
| a | 편집기 서식 버튼 **40×32**, 인라인 링크 **32** | 터치 44 기준 미달. §2-4와 같은 파일, 테스트가 크기에 고정 ⚠️ |
| b | 업로드 트레이 **재시도** (터치 폭에서만 44) | 데스크톱 36은 허용 정책 |
| c | 데스크톱 칩 32→36 검토 | 정책상 36까지 허용이라 필수 아님 |
| d | 키보드로 노트를 열었다 닫을 때 **포커스가 카드로 돌아오지 않음** | 라우트/패널 닫힘 시 포커스 복원 |
| e | 태블릿 레일 레이아웃의 **탭 순서 그룹** | |
| f | PDF `tabindex` (점검 #42) | |
| g | 칩이 `checkbox` 역할로 노출 (#12 · #18) | 원인(Flutter 웹 시맨틱 매핑 vs 앱 설정)은 034 §7에서도 미확인 |
| h | 전역 `focusColor` 12% 틴트 **투명화 시점** | 리스트 타일·메뉴 행·내비게이션 바는 링 경로가 없어 현재 유지 중([interaction-states §8-7](../design/interaction-states/spec.md)) |
| i | 다크에서 `inkMuted`가 hover 면 위 **2.6:1**까지 내려감 | 명세 §8-5(별도 이슈 권장). §2-2와 연계. **16차 잔여**: 카드 메타 글자는 고쳤지만(`5b23005`) 다크 `inkMuted`가 **Ask 답변 카드 · 인용 하이라이트 위에서 2.1~3.9:1**로 남아 있다 ⚠️ (전달값) |

완료 기준은 항목별로 정하되, 각 항목에 **키보드로 재현하는 위젯 테스트**를 붙인다. 실제 스크린리더(VoiceOver/TalkBack) 확인은 아직 한 적 없음 ⚠️.

### 2-9. 대화 기록 후속

| 항목 | 내용 |
|---|---|
| 최근 대화 목록 "끊김" 표시 | 서버 `AskSessionSummary`(`id`, `title`, `questionCount`, `lastActiveAt`) ✅ 에 상태 필드가 없어 불가([Ask 대화 UI 명세](../design/ask-history-ui/spec.md) 머리). 비테이블 모델이라 **마이그레이션 없이** 필드 추가 가능 |
| 숨김 해제(unhide) | 엔드포인트가 `hide`뿐(`ask_history_endpoint.dart`) ✅. 명세는 "행 안 확인"(D3)으로 오작동 방지 |
| 관리자 접근 로그 | 지금 `ask-admin: list by=… user=…` 한 줄(`ask_admin_endpoint.dart`) ✅. `session.log`(DB)와 **stdout 한 줄 둘 다** 남기도록 정리 |
| `ask-admin: denied` 알림 기준 | 직렬화 예외(`AskAdminException`)라도 Serverpod이 **ERROR 레벨 `SessionLogEntry`** 를 남긴다 → 알림을 걸 때 오탐 기준 정리 (§2-3과 연계) |
| 테스트 | `test/ask_admin_test.dart` · `ask_history_test.dart`(Flutter), 서버 `test/integration` |

### 2-10. 운영 확인·정리

체크리스트 (모두 코드 변경 없이 확인·설정):

| # | 확인 | 방법 |
|---|---|---|
| 1 | 정리 타이머가 실제로 지움 — ✅ **동작 확인(16차, PM 전달)** | `scloud log --since 15m --limit 400`에서 `maintenance: demo-tokens ran deleted=N`(작업 이름 `demo-tokens` · `auth-tokens` · `demo-documents` · `ask-history` ✅ `maintenance_timer.dart`). 1시간에 한 번 또는 삭제가 있을 때 즉시 찍힘 |
| 2 | demo 세션 만료(유휴 60분 · 절대 240분) 실사용 | 데모 로그인 후 방치/장시간 뒤 열린 탭이 로그인 화면(안내 문구)으로 가는지 |
| 3 | `ADMIN_USER_IDS` 설정 — **확인(16차): 운영 미설정, 관리자 계정 아직 없음 ✅.** 설정은 대기 | 사용자가 설정 화면 "내 계정 ID 복사"로 ID를 주면 `scloud variable set ADMIN_USER_IDS <ID>`(DEMO_ENABLED를 켠 방식과 같음, [plan 012 §4-2](012-session-handoff.md) 7차 행; 정확한 사용법은 `scloud help`로 확인) 후 재배포 |
| 4 | 운영 비밀값 `llmModel` 미설정 — ✅ **미설정 확인(16차)** | 설정돼 있으면 코드의 기본 모델(`nemotron-3-super`)을 덮어씀 ✅ `rag_services.dart` |
| 5 | `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` 정리 — **확인(16차): 변수가 아직 남아 있음(미사용). 삭제 여부 결정 필요** | 15차에서 코드가 사라져 미사용. 운영 변수에 남았으면 삭제할지 결정 |
| 6 | "스캔 PDF 지원 안 함" 안내 문구 | 14·15차에서 보류. 빈 `preview` 카드(글자 없는 PDF)에 안내를 둘지 CTO 결정 — [ADR 023](../adr/023-no-scanned-pdf-recovery.md)의 감수할 점 |

### 2-11. 보류·폐기된 것

- **스캔·폼 전용 PDF OCR**: 제품화하지 않음 ([ADR 023](../adr/023-no-scanned-pdf-recovery.md)). 코어 압축·메모리 등 OCR 관련 후속도 폐기. 재검토는 스캔 PDF 요구가 생길 때 [research 032](../research/032-local-pdf-recovery.md)에서.
- **노트에 이미지를 붙이는 기능의 OCR**: 계획 없음.
- 서버 `DocPage.source` / `PageText.source` / `Citation.source`와 `doc_page.source` 컬럼은 **휴면**(운영 DB에 적용됨). 지우려면 새 마이그레이션이 필요하며 지금은 이득이 없다.

---

## 3. 작업 방식 (필수 읽기)

### 3-1. 같은 저장소를 쓰는 다른 세션과의 충돌 방지

14차에 두 세션이 동시에 `main`을 옮겨 병합이 필요했다 (경위: [devlog 012 사건 ①](../devlog/012-releases-10-to-15.md), 규칙 원문: [plan 012 §2-5](012-session-handoff.md)). 우리 작업 트리가 옛 기준이라 그대로 커밋하면 상대의 노트 색 기능이 삭제될 뻔했다.

| # | 규칙 |
|---|---|
| 1 | `main`은 **예상값이 일치할 때만** 옮긴다: `git update-ref refs/heads/main <NEW> <OLD>` (OLD가 현재 값과 다르면 실패) |
| 2 | `main` 이동 · 배포 **전에 서로 알린다** |
| 3 | 배포는 **한 번에 한 세션**. 배포 전 `scloud deployment list`로 **진행 중인 배포가 없는지** 확인 |
| 4 | 마이그레이션은 **병합 후 새로 생성**한다 (기준이 다른 두 세션이 만든 마이그레이션은 어긋남) |
| 5 | 병합 절차 요약: 내 변경을 기준 커밋 위에 따로 커밋 → 새 `main` 위에 병합 → 생성 코드·마이그레이션 재생성 → 테스트 → 비교-교환으로 `main` 이동 → 작업 트리 동기화 |

### 3-2. 건드리면 안 되는 파일

- 사용자 개인 수정: `README.md`, `README.ko.md`, `docs/reference/002-run-locally.md` — **커밋·되돌리기 금지**.
- 루트의 `ocr-*.html` (저장소 밖 임시 OCR 테스트 도구) — 커밋·되돌리기 금지.
- 생성 코드: `app/pageblink_server/lib/src/generated/`, `app/pageblink_client/` — 직접 수정 금지 ([`app/AGENTS.md`](../../app/AGENTS.md)).
- 비밀값 출력 금지. API 키는 `config/passwords.yaml`(git 제외) 또는 Serverpod Cloud 비밀값에만.

### 3-3. 검증 → 커밋 → 배포 절차

서버는 **에이전트가 직접 실행하지 않습니다**(사용자가 `serverpod start`). 테스트만 실행합니다.

```bash
# 1) 깨끗한 워크트리 (main 최신 기준; <main>은 커밋 해시)
git worktree add --detach ../pageblink-releaseNN <main>

# 2) 서버 통합 테스트용 비밀값: gitignore된 파일을 복사만 한다 (커밋 금지).
#    끝나면 워크트리를 반드시 삭제한다 (비밀값이 남지 않게).
cp app/pageblink_server/config/passwords.yaml ../pageblink-releaseNN/app/pageblink_server/config/passwords.yaml

# 3) 서버: 분석 → 포맷 확인 → 테스트 (키를 해제하는 이유: 통합 테스트가 외부 임베딩 API를 호출하지 않게)
cd ../pageblink-releaseNN/app/pageblink_server
dart analyze && dart format --set-exit-if-changed lib test \
  && env -u GEMINI_API_KEY -u DEEPINFRA_API_KEY -u OPENROUTER_API_KEY -u ANTHROPIC_API_KEY dart test

# 4) Flutter (위 3번과 병렬로 실행)
cd ../pageblink_flutter
fvm flutter analyze && fvm flutter test

# 5) 마이그레이션 점검: 테이블 모델을 바꾸지 않았다면 "No changes detected" 여야 한다
cd ../pageblink_server && serverpod create-migration

# 6) 배포 (평균 3분 23초, 최대 4분; pre_deploy가 웹을 새로 빌드)
PATH="$HOME/Library/Application Support/Dart/install/bin:$PATH" scloud --non-interactive --yes deploy
```

- 서버 테스트와 Flutter 테스트는 **병렬 실행**한다.
- `app/AGENTS.md` 체크리스트: `dart analyze` → `dart format` → (모델 변경 시) 마이그레이션 → 테스트 → 로그 확인.
- push는 활성 gh 계정이 쓰기 불가이므로 `GH_TOKEN="$(gh auth token --user biyott)" git push origin main` ([plan 012 §1-3](012-session-handoff.md)).

### 3-4. 알려진 함정

| 함정 | 대처 |
|---|---|
| zsh에서 `git reset -q HEAD -- $paths`는 경로 변수가 쪼개지지 않는다 | 파일을 **하나씩 나열** |
| `serverpod generate`는 다른 변경과 섞여 diff가 커진다 | 실행 **전후에 `git diff --stat`** 으로 확인 |
| 병렬 엔지니어가 공유 파일(`l10n.dart`, `theme.dart`, `app_icons.dart`, `pb_interactive.dart`)을 동시에 고친다 | **편집 직전에 다시 읽기** |
| `dart format`이 남의 파일까지 바꾼다 | 자기 파일만 **개별 `dart format <파일>`** |
| zsh에서 `$M:path` 형태가 `:a` 수정자로 해석된다 | `git show main:path`처럼 리터럴로 쓰거나 `${M}` 사용 |
| CDN이 같은 URL의 작은 파일을 캐시한다 | 배포 직후 정적 파일이 늦게 갱신될 수 있음 ([plan 012 §5](012-session-handoff.md)) |

### 3-5. 라이브 확인 요령

- **대화 기록 API**: 방문자 키(임의 22자, 형식 `[A-Za-z0-9_-]{16,64}` ✅ `visitor_key.dart`)를 `restore`/`open`/`hide`에 같은 값으로 보낸다. demo 계정은 공유 계정이라 이 키로 대화를 구분한다.
- **데모 로그인**으로 확인하되 샘플 질문은 **영어 2 · 한국어 2 이내**. 일일 질문 상한 50이 전역 공유라 질문 수를 아껴 쓴다.
- **서버 로그**: `scloud log --since 15m --limit 400`.
- 정적 파일 확인: `/`, `main.dart.js`, `assets/FontManifest.json`이 200이고 새 문자열이 있는지.

### 3-6. 배포 방침

- 배포 지시를 받은 작업은 **검증 후 묻지 않고 배포**한다 (사용자 방침). 사용자(CTO)가 "배포하지 말 것"이라고 명시한 항목만 예외.
- 배포가 성공하면 **즉시 보고**하고 라이브 확인은 별도로 병행한다.
- 배포 뒤 [plan 012 §4-2](012-session-handoff.md) 배포 이력 표와 devlog에 한 줄을 남긴다 (커밋 · 배포 ID · 테스트 수치).

---

## 4. 권장 진행 순서와 의존 관계

### 4-1. 권장 순서 (작은 것부터 묶어 2회 배포 정도)

| 묶음 | 항목 | 이유 |
|---|---|---|
| **A 배포** (클라이언트·운영, 생성 코드 변경 없음) | 1 안내 배너 · 2 다크 hover 대비 · 7 샘플 PDF(필요 시) · 10 운영 확인 · 8의 a~d 중 쉬운 것 | 모두 S, 서로 파일이 거의 안 겹침(1은 `ask_screen.dart`, 2는 `theme.dart`·`documents_screen.dart`) |
| **B 배포** (서버 + 생성 코드) | 3 오류 정식화 · 9 대화 기록 후속 · 5 인용 보정 확대 | 3·9는 모델/엔드포인트를 바꿔 `serverpod generate`가 돌고 `l10n.dart`도 건드림. 5는 서버만(`citation_infer.dart`) |
| **C (선택, 별도)** | 4 편집기 키보드 경로 · 8의 나머지 · 6 모델 재측정 | 4는 L이고 IME 회귀 위험이 커서 단독 배포 권장. 6은 한도가 풀릴 때 |

### 4-2. 의존 관계

| 관계 | 설명 |
|---|---|
| 3 ↔ 다른 UI 작업 | **3번이 `l10n.dart`와 생성 코드를 건드리므로, 다른 UI 작업과 동시에 `serverpod generate`를 돌리지 말 것.** 3을 먼저 병합·배포하거나, 3 진행 중에는 UI 세션이 `l10n.dart`를 읽기만 하게 조율 |
| 3 ↔ 9 | 9의 "ERROR 로그 알림 기준"은 3의 결과에 따라 달라짐 → 3 먼저 |
| 3 ↔ `pageblink-f9` 세션 | `setNoteColor` 오류 완화 요청이 겹칠 수 있음 → 먼저 확인 ⚠️ |
| 2 ↔ 8-i | 같은 대비 문제의 두 면 → 한 번에 |
| 4 ↔ 8-a | 같은 파일·같은 40×32 터치 영역 → 4와 함께 |
| 7 ↔ `demo_config.dart` 상수 | 상수나 PDF 중 하나를 바꾸면 다른 쪽도 맞춰야 함 |
| 모든 항목 ↔ 마이그레이션 | 현재 계획에는 마이그레이션이 필요한 항목이 없다. 생기면 §3-1 규칙 4 |

---

## 5. 변경 이력

- `2026-10-16 16:22` 최초 작성 (후속 개선 11개 항목, 작업 방식, 진행 순서)
- `2026-10-16 16:53` 16차 반영: 2-1 · 2-2 · 2-5 · 2-7 완료 표시(배포 후 기록 예정 ⚠️), 2-8 i 잔여(Ask 카드 · 인용 하이라이트 위 `inkMuted`) 메모, 2-10의 1 · 3 · 4 · 5번 확인 결과 반영(2 · 6번은 그대로)
