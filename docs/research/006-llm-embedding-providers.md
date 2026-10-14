# 006 · LLM·임베딩 제공자

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Dart 서버(Serverpod)에서 쓸 스트리밍 LLM과 임베딩 모델은? 오늘 밤과 장기(온디바이스 EmbeddingGemma와 일관성) 각각의 선택은? |
| 결론 한 줄 | LLM **Claude Sonnet 5.5**(속도는 Haiku 5.5) · 임베딩 **EmbeddingGemma 768 호스팅(DeepInfra ⚠️)**, 폴백 Voyage `voyage-4-lite` |
| 반영 | [ADR 002](../adr/002-embedding-embeddinggemma-768.md) · [ADR 004](../adr/004-llm-claude.md) · [plan 003 §2-3](../plan/003-tech-stack-and-prep.md) |

## 1. LLM: Claude

| 모델 | ID | 입력 | 출력 | 캐시 읽기 (1M 토큰당) |
|---|---|---|---|---|
| Sonnet 5.5 | `claude-sonnet-5-5` | $2 | $10 | $0.10 |
| Haiku 5.5 | `claude-haiku-5-5` | $0.10 (100K 이하 프롬프트) | $0.50 | $0.01 |
| Opus 5.5 | `claude-opus-5-5` | $4 | $20 | $0.20 |

- ✅ 세 모델 모두 1M 컨텍스트. ID는 날짜 접미사 없이 그대로 사용
- ✅ 5.5 세대는 thinking 기본 활성 → 채팅 RAG는 `thinking:{type:"adaptive"}` + 낮은 `effort`. **`budget_tokens`는 400 에러**
- ✅ Dart 패키지 `anthropic_sdk_dart` 9.0.0: 커뮤니티(비공식), SSE 스트리밍·citations·`search_result` 지원, **Dart ≥ 3.12 필요**. 공식 Dart SDK 없음

```dart
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
final client = AnthropicClient.fromEnvironment(); // ANTHROPIC_API_KEY
final stream = client.messages.createStream(MessageCreateRequest(
  model: 'claude-sonnet-5-5', maxTokens: 1024,
  messages: [InputMessage.user(prompt)]));
await for (final e in stream) {
  if (e is ContentBlockDeltaEvent && e.delta is TextDelta) {
    yield (e.delta as TextDelta).text;   // Serverpod 스트림으로 전달
  }
}
```
> ⚠️ 패키지 예제는 `claude-sonnet-5`를 썼고 위 코드는 ID만 바꾼 것. 컴파일·실행 안 해 봄

- REST 폴백 ⚠️: `POST https://api.anthropic.com/v1/messages`, 헤더 `x-api-key`·`anthropic-version: 2023-06-01`·`content-type`, 본문 `{model, max_tokens, stream:true, messages}`. `data: ` 줄을 파싱해 `content_block_delta`/`text_delta`의 `delta.text`를 모으고 `message_stop`에서 종료
- ✅ **Citations**(베타 아님): 근거 청크를 `document` 블록 + `citations:{enabled:true}`로 전달 → 응답에 `cited_text`와 위치. `output_config.format`과 함께 쓰면 400. pgvector 청크에는 `search_result` 블록이 가장 적합
- ✅ Prompt caching: 캐시 읽기 0.05배. 고정 시스템 프롬프트엔 유효, 매번 바뀌는 top-k 청크엔 효과 없음
- 대안: Gemini Dart `google_generative_ai`는 **deprecated ✅**, 후속 `firebase_ai`는 Flutter 클라이언트용 → 서버는 REST. OpenAI Dart 패키지는 미확인 ⚠️

## 2. 임베딩

Anthropic은 임베딩 모델이 없고 Voyage AI를 권장 ✅

| 선택지 | 차원 | 가격 (1M 토큰) | 무료 | Dart 사용 |
|---|---|---|---|---|
| Voyage `voyage-4` / `-lite` / `-large` | 기본 1024, 256/512/2048 | $0.06 / $0.02 / $0.12 | 200M 토큰 | REST `POST https://ai.mongodb.com/v1/embeddings`, Bearer, `input_type` query/document |
| `gemini-embedding-001` | 기본 3072, MRL 128~3072 | 미확인 ⚠️ | 미표기 | REST `:embedContent`, `x-goog-api-key` |
| `gemini-embedding-2` | 기본 3072, 768 권장 | $0.20 | 있음 | 같은 REST, `task_type` 대신 텍스트 프리픽스 |
| OpenAI `text-embedding-3-small` | 1536 | ⚠️ | ⚠️ | ⚠️ |
| **EmbeddingGemma @ DeepInfra** | 768 (MRL 512/256/128) | **$0.002** | ⚠️ | OpenAI 호환 REST ⚠️ |
| EmbeddingGemma @ Cloudflare Workers AI (베타) | 미표기 | 미표기 | 미표기 | `POST .../ai/run/@cf/google/embeddinggemma-300m` |

- Voyage: 다국어 검색 최강 후보, 4 시리즈끼리 호환. `voyage-3.5`는 레거시. 한국어 전용 벤치마크는 없음 ⚠️
- `gemini-embedding-001`: 입력 2,048토큰, 차원 축소 시 수동 재정규화. `gemini-embedding-2`: 8,192토큰, 자동 재정규화
- Google 자체 호스팅 API는 Gemini Embedding이지 EmbeddingGemma가 아님. Vertex AI 목록에서 못 찾음
- 지연 시간은 측정하지 않음

## 3. 권장

- **오늘 밤**: Claude Sonnet 5.5 또는 Haiku 5.5(`anthropic_sdk_dart`, 폴백 `package:http`). 임베딩은 `voyage-4-lite`/`voyage-4`(1024) — 무료 200M, Bearer 키 한 줄. 가입이 싫으면 `gemini-embedding-2`(768)
- **장기**: LLM은 Claude 유지, 임베딩은 **EmbeddingGemma-300m 768을 기기·서버 공용**. 서버는 자체 호스팅(Ollama/ONNX ⚠️) 또는 DeepInfra/Workers AI
- 다른 모델의 벡터는 서로 비교 불가 (Gemini 768도 EmbeddingGemma와 호환 안 됨)

> 🧭 **리드 판단**: DeepInfra가 EmbeddingGemma를 실제로 제공하면 오늘부터 장기 모델과 같아져 재임베딩이 필요 없으므로 **DeepInfra를 1순위**로, 실패 시 Voyage로 → [ADR 002](../adr/002-embedding-embeddinggemma-768.md)

## 4. 임베딩 모델 교체 절차
1. 청크 테이블에 `embedding_model`, `embedding_version` 컬럼
2. 새 벡터 컬럼을 별도로 추가 (`embedding_gemma vector(768)` + HNSW). pgvector는 컬럼마다 차원이 고정이라 기존 컬럼을 바꾸지 않음
3. 백그라운드 작업으로 배치·속도 제한하며 백필. 그동안은 기존 컬럼으로 검색
4. 100% 채워지면 검색 경로 전환 (질의와 문서 벡터는 같은 모델)
5. 기존 컬럼·인덱스 삭제

## 출처
- https://platform.claude.com/docs/en/about-claude/pricing
- https://pub.dev/documentation/anthropic_sdk_dart/9.0.0/
- https://platform.claude.com/docs/en/build-with-claude/embeddings
- https://pub-web-s2.flutter-io.cn/packages/google_generative_ai
- https://ai.google.dev/gemini-api/docs/pricing
- https://deepinfra.com/google/embeddinggemma-300m
- https://developers.cloudflare.com/workers-ai/models/
