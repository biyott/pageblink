# 003 · 서버 RAG 파이프라인 (청킹 · 임베딩 · 스트리밍 답변 · ACL)

| 항목 | 값 |
|---|---|
| 상태 | ✅ 완료 |
| 단계 | Phase 0 · 서버 |
| 시작 | 2026-10-14 22:48 KST |
| 완료 | 2026-10-14 23:01 KST |
| 소요 | 약 13분 |
| 최종 수정 | 2026-10-14 23:03 KST |

## 목표
업로드된 문서를 청킹·임베딩해 저장하고, `ask` 엔드포인트가 검색 결과를 근거(citation)와 함께 Claude 답변 스트림으로 돌려주는 서버 RAG 파이프라인을 만든다. 접근 제어(ACL)는 서버에서 계산한다.

## 작업 로그
- `22:48` claude-api 스킬 확인
  - Dart는 공식 SDK가 없어 **raw HTTP + SSE**로 구현 (스킬 지침)
  - 기본 모델은 스킬 규칙상 `claude-opus-5-5` (사용자가 Sonnet을 명시하지 않음). `passwords`의 `claudeModel`로 교체 가능
  - `fallbacks: "default"` + 베타 헤더 `server-side-fallback-2026-07-01` 기본 적용
- `22:50` `app/ragpod_server/lib/src/rag/chunker.dart`, `embedding_spec.dart` — Serverpod import 없는 순수 Dart (Phase 1에 `packages/ragpod_core`로 이동 예정, [ADR 006](../adr/006-monorepo-app-folder.md))
- `22:52` `providers/embedding_provider.dart`
  - DeepInfra OpenAI 호환 `/v1/openai/embeddings`, 모델 `google/embeddinggemma-300m` (⚠️ 실제 호출 미검증)
  - 32개 배치, L2 정규화, 768차원 검증
- `22:52` `providers/llm_provider.dart`
  - Claude Messages API SSE, thinking `adaptive`, effort `low`
  - 각 청크를 `text` document 블록 + `citations` enabled로 전달
  - `text_delta` / `citations_delta` 파싱, `stop_reason: refusal` 처리
- `22:56` `services/acl.dart` — 서버가 `ProjectMember`로 멤버십을 계산하고 클라이언트가 보낸 `projectIds`와 교집합 ([ADR 010](../adr/010-acl-in-query.md))
- `22:56` `services/rag_services.dart` — `session.passwords`에서 `anthropicApiKey`, `deepinfraApiKey`, `claudeModel` 읽음
- `22:57` `rag_endpoints/` — `DocumentEndpoint`(upload/list/delete), `AskEndpoint`(`ask` → `Stream<AnswerEvent>`: token / citation / done / error), `ProjectEndpoint`(create/list/addMember(email→`EmailAccount` 조회)/members). 모두 `requireLogin`
- `22:58` 컴파일 오류 4건 수정 (아래 "문제와 해결")
- `23:00` 단위 테스트 5개 통과 (`test/unit/chunker_test.dart`, `claude_provider_test.dart` — `MockClient`로 SSE 파싱·refusal 검증). `dart analyze` 이슈 0 ✅
- `23:00` `config/passwords.yaml`(git 제외)의 `shared`에 `anthropicApiKey`, `deepinfraApiKey` 빈 자리 추가
- `23:01` 커밋 `fc423af`

## 결과

### 파일 (`app/ragpod_server/` 기준)

| 구분 | 파일 |
|---|---|
| 청킹·스펙 (순수 Dart) | `lib/src/rag/chunker.dart`, `lib/src/rag/embedding_spec.dart` |
| 외부 API | `lib/src/providers/embedding_provider.dart`, `lib/src/providers/llm_provider.dart` |
| 서비스 | `lib/src/services/acl.dart`, `lib/src/services/rag_services.dart` |
| 엔드포인트 | `lib/src/rag_endpoints/document_endpoint.dart`, `ask_endpoint.dart`, `project_endpoint.dart` |
| 테스트 | `test/unit/chunker_test.dart`, `test/unit/claude_provider_test.dart` |
| 생성물 | `lib/src/generated/*`, `ragpod_client/lib/src/protocol/*`, `test_tools/serverpod_test_tools.dart` |

### 엔드포인트 시그니처

| 엔드포인트 | 메서드 | 반환 |
|---|---|---|
| `document` | `upload(title, List<PageText> pages, contentHash, int? projectId)` | `Document` |
| `document` | `list()` | `List<Document>` |
| `document` | `delete(documentId)` | – |
| `ask` | `ask(question, List<int> projectIds, bool includePersonal)` | `Stream<AnswerEvent>` |
| `project` | `create(name)` | – |
| `project` | `list()` | – |
| `project` | `addMember(projectId, email, role)` | – |
| `project` | `members(projectId)` | – |

`project.*`의 반환 타입은 확인 필요.

### 검증 상태

| 항목 | 상태 |
|---|---|
| 청킹 · SSE 파싱 · refusal 단위 테스트 5개 | ✅ 통과 |
| `dart analyze` | ✅ 이슈 0 |
| DeepInfra 임베딩 실호출 | ⚠️ 미검증 (키 필요) |
| Claude 실호출 (실제 API) | ⚠️ 미검증 (단위 테스트는 `MockClient`) |
| Cloud 배포 · pgvector (G2) | ⚠️ 미검증 |

## 문제와 해결

| 문제 | 해결 |
|---|---|
| `authUserId` 확장을 찾지 못함 | `package:serverpod_auth_idp_server/core.dart` import 필요 |
| `NotAuthorizedException` 이름 충돌 | `AccessDeniedException`으로 변경 |
| `find`에 `orderDescending` 없음 | `orderByList: (t) => [t.updatedAt.desc()]` 사용 |
| (위 외 컴파일 오류 1건) | 세부 내용 확인 필요 — 총 4건 수정 |

## 결정 (→ ADR 링크)
- [ADR 004](../adr/004-llm-claude.md)(기본 `claude-sonnet-5-5`)와 실제 기본값(`claude-opus-5-5`)이 **다름** → 사용자 결정 대기. 결정 후 **새 ADR**로 기록 예정 (ADR 본문은 수정 금지 규칙)
- ADR 004의 SDK 항목(`anthropic_sdk_dart`)과 달리, 이번 구현은 raw HTTP + SSE (ADR 004 자체의 "폴백 `package:http` SSE"에 해당)
- ACL: 서버에서 멤버십 계산 후 클라이언트 `projectIds`와 교집합 ([ADR 010](../adr/010-acl-in-query.md))

## 다음 할 일
- [ ] (사용자) Anthropic · DeepInfra API 키를 `passwords.yaml`에 입력
- [ ] (사용자) `serverpod cloud auth login` → G2
- [ ] DeepInfra 임베딩 실호출 검증
- [ ] 모델 기본값 결정 → 새 ADR
- [ ] Flutter 앱: 로그인 · 업로드 · 채팅 · 뷰어

## 변경 이력
- `2026-10-14 23:03` 최초 작성
