# 016 · OpenRouter (LLM · 임베딩 · 무료 모델 · 요금)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Dart 서버에서 OpenRouter로 스트리밍 답변·인용·임베딩을 할 수 있나? 어떤 모델이 좋은가? |
| 결론 한 줄 | LLM은 OpenRouter(기본 `anthropic/claude-haiku-5.5`), 인용은 `[n]` 마커, **임베딩은 DeepInfra EmbeddingGemma 유지** |
| 반영 | [ADR 013](../adr/013-llm-via-openrouter.md) |

## 1. Chat Completions ✅
- `POST https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer`, 선택 헤더 `HTTP-Referer`, `X-OpenRouter-Title`(`X-Title` 허용). OpenAI 호환
- SSE: `data: {...}`의 `choices[0].delta.content`, 종료 `data: [DONE]`. `: OPENROUTER PROCESSING` 같은 `:` 주석 줄은 무시
- 마지막 직전 청크에 `usage`(prompt/completion tokens, cost)
- 스트림 중 오류: HTTP 200 이후 최상위 `error:{code,message}` + `finish_reason:"error"`
- 연결 끊으면 취소(Anthropic은 지원, Google은 미지원)

## 2. Anthropic 고유 기능
- 프롬프트 캐싱 ✅: 최상위 `cache_control` 또는 블록 브레이크포인트 최대 4개, TTL 5분/1h
- reasoning ✅: `reasoning:{effort|max_tokens, exclude, enabled}`, 스트림 `delta.reasoning_details`
- **citations ⚠️ 근거 없음** → 출처를 `[1] 제목, p.N`으로 번호 매기고 `[n]` 마커로 인용시키는 방식(모든 모델 공통)

## 3. 임베딩 ✅
- `POST /api/v1/embeddings`, `GET /api/v1/embeddings/models`
- **`google/embeddinggemma-300m` 없음**, 768차원 다국어 모델 없음(768은 영어 중심 gte-base, e5-base-v2, bge-base-en, mpnet)
- 다국어: `baai/bge-m3`(1024, ~$0.01/M), `intfloat/multilingual-e5-large`(1024), qwen3-embedding, gemini-embedding
- → 768차원 DB를 유지하려면 DeepInfra EmbeddingGemma 유지

## 4. 모델 ($/M 토큰, 입력/출력, 컨텍스트 1M) ✅
| 슬러그 | 가격 |
|---|---|
| `anthropic/claude-haiku-5.5` | 0.10 / 0.50 |
| `anthropic/claude-sonnet-5.5` | 2 / 10 |
| `anthropic/claude-opus-5.5` | 4 / 20 |
| `google/gemini-3.8-flash` | 0.75 / 3.75 |
| `google/gemini-3.5-flash-lite` | 0.30 / 2.50 |
| `google/gemini-3.1-flash-lite` | 0.25 / 1.50 |

- `:batch` 변형은 반값
- 무료(`:free`) 후보: `google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`, `nvidia/nemotron-3-super-120b-a12b:free` 등 (한국어 품질 미확인)
- 무료 한도 ✅: 분당 20회, 일 50회(크레딧 미구매) / 1,000회(10크레딧 이상 구매)
- 무료 모델 프라이버시 ⚠️: 학습·로깅 제공자로 라우팅될 수 있음 → `provider:{data_collection:"deny"}` 또는 `zdr:true`. 개인 문서에는 무료 모델 비권장

## 5. 요금 ✅
- 추론 마크업 없음, 크레딧 충전 수수료 5.5%(최소 $0.80)
- BYOK는 월 $25,000 상당까지 무수수료

## 6. Dart
- `openrouter_sdk` 0.0.8(신생), `openrouter_api` deprecated → `package:http` 직접 호출 권장

## 출처
- https://openrouter.ai/docs/api-reference/overview · /streaming · /embeddings · /limits
- https://openrouter.ai/docs/guides/best-practices/prompt-caching · /reasoning-tokens
- https://openrouter.ai/docs/guides/privacy/logging · https://openrouter.ai/docs/guides/routing/provider-selection
- https://openrouter.ai/docs/faq · https://openrouter.ai/api/v1/models
