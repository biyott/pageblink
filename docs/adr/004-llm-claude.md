# 004 · LLM: Claude Sonnet 5.5 (서버 경유 스트리밍)

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [research 006](../research/006-llm-embedding-providers.md) |

## 결정
- 기본 `claude-sonnet-5-5`, 속도·비용 우선 시 `claude-haiku-5-5`
- 호출은 **Serverpod `ask` 엔드포인트에서만**, 결과는 `Stream<AnswerEvent>`로 앱에 전달
- 근거 청크는 `search_result`/`document` 블록 + `citations` → 페이지 점프에 사용 (시간 부족 시 `[n]` 마커)
- `thinking: adaptive` + 낮은 effort (`budget_tokens` 금지)
- SDK `anthropic_sdk_dart` 9.0.0, 폴백 `package:http` SSE

## 대안과 기각 이유
- Gemini: Dart 서버 SDK deprecated, REST 직접 구현 필요
- 앱에서 직접 호출: API 키 노출, 스택 활용 점수 손해

## 결과
- 👍 한국어 품질, 네이티브 인용
- 👎 비공식 Dart SDK 의존 → 어댑터(`llm_provider.dart`) 뒤에 숨김
