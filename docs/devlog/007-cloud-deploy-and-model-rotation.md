# 007 · Cloud 배포(G2) · 모델 카탈로그와 자동 로테이션

| 항목 | 값 |
|---|---|
| 상태 | ✅ (⚠️ Cloud E2E 확인 필요) |
| 단계 | Phase 0 · G2 · 서버 |
| 시작 | 2026-10-14 23:46 KST |
| 완료 | 2026-10-15 00:08 KST (재배포 시각 약) |
| 소요 | 약 22분 |
| 최종 수정 | 2026-10-15 00:18 KST |

## 목표
- Serverpod Cloud에 배포해 **Cloud Postgres의 pgvector 지원(G2)** 을 확인한다 ([ADR 008](../adr/008-pgvector-fallback.md)).
- 앱에서 답변 모델을 고르고, 모델이 막히면 자동으로 다른 모델로 넘어가게 한다.

## 작업 로그
- `2026-10-14 23:46` 사용자가 `launch`로 Cloud 프로젝트 `pageblink`(Starter 플랜) 생성
- `23:57`–`00:00` 모델 카탈로그 · 로테이션 구현 (아래 결과). 서버 테스트 13개 통과, 커밋 `0af55e0`
- `2026-10-15 00:04` 배포 로그에 "Applied database migration" → **G2 통과** (아래)
- `00:06` API 키 환경변수 폴백 추가, 커밋 `dea04b2`
- `약 00:08` 사용자가 Cloud 비밀값 `openrouterApiKey` · `deepinfraApiKey`를 설정하고 재배포
- `00:18` 이 기록으로 [ADR 014](../adr/014-model-catalog-and-rotation.md) 작성, [ADR 013](../adr/013-llm-via-openrouter.md) 일부 대체 표시, [ADR 008](../adr/008-pgvector-fallback.md) G2 통과 반영 (시각은 문서 작성 시점)
- 재배포 후 `https://pageblink.serverpod.space` · `https://pageblink.api.serverpod.space` 모두 HTTP 200 응답

## 결과

### G2: Cloud Postgres가 pgvector를 지원한다 ✅
- 마이그레이션이 `Vector(768)` 컬럼과 HNSW 인덱스를 만든다. 확장을 쓸 수 없으면 마이그레이션이 실패하도록 되어 있는데, 배포 로그에 "Applied database migration"이 찍혔다.
- 따라서 [ADR 008](../adr/008-pgvector-fallback.md)의 폴백(Neon, Dart 코사인)은 **필요 없다**.
- 근거는 배포 로그의 한 줄이다. 임베딩 저장 · 검색의 Cloud 실동작은 확인 필요.

### 모델 카탈로그 (`LlmCatalog`, 7개)

| 모델 | 구분 |
|---|---|
| `google/gemma-4-26b-a4b-it:free` | 무료 · **기본** |
| `nvidia/nemotron-3-super-120b-a12b:free` | 무료 |
| `nvidia/nemotron-3.5-lightning:free` | 무료 |
| `nvidia/nemotron-3-ultra-550b-a55b:free` | 무료 |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | 무료 (추론형) |
| `google/gemini-3.1-flash-lite` | 유료 |
| `google/gemini-3.8-flash` | 유료 |

### 서버 · 앱 변경

| 항목 | 내용 |
|---|---|
| `ModelEndpoint` | `list`(카탈로그), `defaultModel`(비밀값 `llmModel` 또는 카탈로그 기본값) |
| `RotatingLlmProvider` | 첫 글자 **전에** 재시도 가능한 오류(402/404/408/429/5xx)가 나면 다음 모델로. 글자가 나온 뒤 오류는 그대로 노출 |
| `llmRotation` | `free`(기본) · `all`(유료 포함) · `off` |
| `AnswerEvent` | `type: 'model'` 이벤트로 실제로 답한 모델 id 전달 |
| `GeminiLlmProvider` | 스텁만 있음 ("not implemented yet"). Gemini는 OpenRouter 경유로 사용 가능 |
| 무료 모델 | `data_collection: deny`를 보내지 않음 (유료 모델은 유지) |
| 앱 | 모델 선택기 + 답변마다 "답한 모델" 배지 |

### 한도 (코드 주석 기준)
OpenRouter 무료 모델 한도는 **계정 단위**다: 분당 20회, 일 50회 (크레딧 $10 이상 구매 후 일 1,000회). 로테이션은 모델별 혼잡·장애에는 도움이 되지만 **일일 한도는 늘리지 못한다.**

### API 키 환경변수 폴백
`openrouterApiKey` · `deepinfraApiKey` · `anthropicApiKey`는 Serverpod 비밀값이 없으면 `OPENROUTER_API_KEY` · `DEEPINFRA_API_KEY` · `ANTHROPIC_API_KEY`를 읽는다. `llmModel` · `llmRotation`은 환경변수 폴백이 없다 (비밀값만).

### 검증

| 항목 | 결과 |
|---|---|
| 서버 테스트 | ✅ 13개 통과 (커밋 `0af55e0` 시점) |
| Cloud 배포 · 마이그레이션 | ✅ 로그 확인 |
| 두 URL 응답 | ✅ HTTP 200 |
| Cloud에서 업로드 → 질문 → 인용 E2E | ⚠️ 확인 필요 |
| 로테이션 실동작(실제 429 상황) | ⚠️ 확인 필요 (단위 테스트만) |

## 문제와 해결

| # | 문제 | 해결 |
|---|---|---|
| 1 | 에이전트 작업 중 권한 확인 창이 계속 뜸 | 원인을 statusline-band 플러그인의 `gitStrict` 옵션으로 추적, 사용자가 설정을 다시 구성 |
| 2 | 코드 주석이 존재하지 않는 "ADR 014"를 가리킴 | [ADR 014](../adr/014-model-catalog-and-rotation.md) 작성 |

## 결정 (→ ADR 링크)
- [ADR 014](../adr/014-model-catalog-and-rotation.md): 무료 모델 기본 + 자동 로테이션 ([ADR 013](../adr/013-llm-via-openrouter.md) 일부 대체)
- [ADR 008](../adr/008-pgvector-fallback.md): G2 통과, 폴백 불필요
- ⚠️ 무료 모델에는 deny를 보내지 않으므로 **데모는 공개 문서로만** 한다.

## 다음 할 일
- Cloud에서 E2E: 가입 → PDF 업로드 → 질문 → 인용 ⚡ → 페이지 점프 (확인 필요)
- 데모 PDF 준비, 제출용 README · 영상
- 후속 기능: [plan 005](../plan/005-follow-up-spec.md)

## 변경 이력
- `2026-10-15 00:14` 최초 작성 (사실은 오케스트레이터가 전달한 값, 코드 확인으로 보강)
- `2026-10-15 00:18` 작업 로그에 ADR 작성 항목 추가
