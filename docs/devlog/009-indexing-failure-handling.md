# 009 · 인덱싱 실패 처리 (원인 표시 · 재색인 · 키워드 폴백 · 선택적 Gemini 임베딩)

| 항목 | 값 |
|---|---|
| 상태 | 🚧 진행 중 (구현 완료, Cloud 배포 결과 확인 필요) |
| 단계 | Phase 0 · 서버 + 앱 |
| 시작 | 2026-10-15 00:36 KST |
| 완료 | – |
| 소요 | – |
| 최종 수정 | 2026-10-15 00:44 KST |

## 목표
- Cloud 로그에서 발견된 **인덱싱 실패**의 원인을 제거하고, 같은 종류의 실패가 다시 나도 **사용자가 이유를 알고 복구**할 수 있게 한다.
- 임베딩 공급자가 죽어도 질문이 완전히 막히지 않게 한다 (키워드 검색 폴백).

## 작업 로그
시각은 오케스트레이터가 전달한 값이다 (KST, 2026-10-15).
- `00:36` Cloud 로그에 `Indexing failed` 확인: DeepInfra **HTTP 402** `"You need positive balance to do inference"`
- `00:40`–`00:50` 구현 (아래 결과)
- `00:44` (약) 사용자가 DeepInfra 잔액 충전
- `00:51` (약) Serverpod Cloud 배포 시작 — **결과는 확인 필요**

## 원인 ✅ (로그 기준)

| 항목 | 내용 |
|---|---|
| 증상 | 문서가 `failed`로 남고 질문 검색에서 빠짐 |
| 직접 원인 | DeepInfra 계정 잔액 0 → 402 `You need positive balance to do inference` |
| 근본 원인 | [research 006](../research/006-llm-embedding-providers.md)이 DeepInfra 쪽을 ⚠️ 미확인으로 표시했는데 **사용 전에 확인하지 않았다** (리드의 누락). 코드 결함이 아니라 운영 전제 미확인 |
| 보조 문제 | 실패 이유가 앱에 안 보였고, 실패한 문서를 다시 색인하려면 재업로드해야 했음 |

## 결과

### 서버

| 항목 | 내용 |
|---|---|
| (a) `GeminiEmbeddingProvider` | `gemini-embedding-001`, `outputDimensionality: 768`, 결과 **재정규화**. `EmbeddingSpec` 프리픽스를 Gemini task type으로 매핑 (`RETRIEVAL_QUERY` / `RETRIEVAL_DOCUMENT`). **`geminiApiKey`(또는 `GEMINI_API_KEY`)가 설정된 경우에만** 사용, 없으면 기존 DeepInfra 경로 |
| (b) `DocPage` 테이블 | 페이지·노트의 **원문 텍스트**를 보관 → 실패한 문서를 재업로드 없이 재색인 |
| (c) `Document.lastError` | 사용자용 한국어 이유: 402 잔액/쿼터 · 401/403 키 · 429 호출 한도 · 5xx 장애 |
| (d) 엔드포인트 | `document.reindex(id)`, `document.reindexFailed()` |
| (f) `ask` 폴백 | 질문 임베딩이 `EmbeddingException`을 던지면 **색인된 청크에 대한 키워드 `ILIKE` 검색**으로 내려가고 사용자에게 그 사실을 알림 |
| 마이그레이션 | `app/pageblink_server/migrations/20261014154208706/` — `doc_page` 테이블, `document.lastError` 컬럼. `migration_registry.txt` 갱신, 생성 코드·클라이언트(`pageblink_client`) 갱신 |

### 앱

| 항목 | 내용 |
|---|---|
| (e) 배너 | `MaterialBanner` "색인 실패 N개 — 질문 검색에서 빠져 있어요" + **"모두 다시 색인"** |
| 카드 | 실패 카드에 **"다시 색인"** 액션, 툴팁에 `lastError` 표시 |
| 파일 | `app/pageblink_flutter/lib/features/documents/documents_screen.dart` |

### 임베딩 공급자 전환 주의 ⚠️

Gemini 임베딩은 EmbeddingGemma(DeepInfra)와 **다른 벡터 공간**이다. 같은 768차원이어도 섞어 검색하면 의미가 없다.

- **배포당 공급자는 하나**만 쓴다. `Document.embeddingModel = provider.modelId`로 문서마다 기록한다.
- 공급자를 바꾸면 기존 문서를 **전부 재임베딩**해야 한다 → [research 006 §4](../research/006-llm-embedding-providers.md), [ADR 002](../adr/002-embedding-embeddinggemma-768.md). 자동 전환은 [plan 005 항목 13](../plan/005-follow-up-spec.md#13-자동-재시도상태-동기화)에 후속으로 둔다.

### 제약
- **이 배포 이전에 올린 PDF**는 `DocPage` 행이 없다 → `reindex`가 "다시 업로드해 주세요"라고 안내한다.
- **노트**는 `body`에서 바로 재색인된다.

### 검증

| 항목 | 결과 |
|---|---|
| 서버 테스트 | ✅ 13개 통과 (오케스트레이터 전달값) |
| `flutter analyze` | ✅ 이슈 없음 (오케스트레이터 전달값) |
| Cloud 배포 | ⚠️ 00:51경 시작, 결과 확인 필요 |
| 마이그레이션 적용 (Cloud) | ⚠️ 확인 필요 |
| 충전 후 실제 재색인 성공 (Cloud E2E) | ⚠️ 확인 필요 |
| Gemini 임베딩 실호출 | ⚠️ 확인 필요 (키 설정·검증 기록 없음) |
| 키워드 폴백 실동작 | ⚠️ 확인 필요 (단위·통합 테스트 범위는 별도 확인 필요) |

## 문제와 해결
| # | 문제 | 해결 |
|---|---|---|
| 1 | DeepInfra 잔액 0 (402)로 인덱싱 실패 | 사용자가 충전 (약 00:44). 재발 대비로 이유 표시 · 재색인 · 폴백 구현 |
| 2 | 실패 문서 복구에 재업로드 필요 | `DocPage`에 원문 보관 + `reindex` / `reindexFailed` |
| 3 | 임베딩 장애 시 질문 자체가 실패 | 키워드 `ILIKE` 폴백 + 사용자 안내 |
| 4 | 전달받은 시각(충전 약 00:44, 배포 약 00:51)이 이 문서 작성 시점의 서버 시계(2026-10-15 00:44)보다 뒤 | 전달값을 그대로 기록. 정확한 시각은 확인 필요 (devlog 008과 같은 유형) |

## 결정 (→ ADR 링크)
- 새 ADR 없음. 공급자 전환 시 재임베딩 정책은 기존 [ADR 002](../adr/002-embedding-embeddinggemma-768.md)와 research 006 §4를 따른다. Gemini를 기본 공급자로 승격하거나 자동 전환을 도입할 때 ADR 필요.

## 다음 할 일
- Cloud 배포 결과와 마이그레이션 적용 확인
- 충전 후 실패 문서 "모두 다시 색인" → `ready` 전환을 Cloud에서 확인 (E2E)
- 배포 이전 PDF는 재업로드 안내가 제대로 보이는지 확인
- 운영 전제 점검: 외부 API 사용 전에 요금·잔액·무료 한도를 확인하고 research 문서의 ⚠️를 해소한다
- 후속: [plan 005 항목 13](../plan/005-follow-up-spec.md#13-자동-재시도상태-동기화) 자동 재시도 · 상태 동기화 · 공급자 헬스체크 · 재임베딩 마이그레이션

## 변경 이력
- `2026-10-15 00:44` 최초 작성 (사실은 오케스트레이터가 전달한 값, 작업 트리 확인으로 보강)
