# 013 · LLM은 OpenRouter 경유 (기본 Claude Haiku 5.5)

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 (004 대체) · 일부 대체됨 → [014](014-model-catalog-and-rotation.md) | 2026-10-14 | 사용자 결정(OpenRouter 사용) · [research 016](../research/016-openrouter.md) |

## 맥락
사용자가 OpenRouter 사용을 원함. 키 하나로 Claude·Gemini 등 모델을 설정값만으로 교체할 수 있다.

## 결정
- 기본 LLM 경로: **OpenRouter** (`openrouterApiKey`), 기본 모델 `anthropic/claude-haiku-5.5` ($0.10/$0.50, 빠름). `llmModel` 설정으로 `anthropic/claude-sonnet-5.5`, `google/gemini-3.8-flash` 등으로 교체
- 인용: 출처를 `[1]..[n]`으로 번호 매기고 마커로 인용 → 서버가 첫 등장 시 `citation` 이벤트 발행, 앱은 마커를 칩으로 렌더
- 개인 문서 보호: 모든 요청에 `provider: {data_collection: "deny"}`, 무료(`:free`) 모델 비권장
- Claude 직접 호출(`ClaudeLlmProvider`, 네이티브 citations)은 `anthropicApiKey`만 있을 때의 대안으로 유지
- 임베딩은 변경 없음 (DeepInfra EmbeddingGemma 768, ADR 002) — OpenRouter에 EmbeddingGemma 없음

## 대안과 기각 이유
- Claude 직접만: 키·과금 분리, 모델 교체 유연성 낮음
- Gemini 직접: Dart 서버 SDK deprecated
- 무료 모델: 일 50회 한도, 학습 라우팅 가능성

## 결과
- 👍 모델 교체가 설정 한 줄, 데모 비용 매우 낮음
- 👎 인용 정확도는 프롬프트 마커에 의존(네이티브 citations보다 약함)
- 🔁 재검토: 인용 품질이 데모에서 부족하면 Sonnet 5.5로 상향, 또는 Claude 직접 경로
