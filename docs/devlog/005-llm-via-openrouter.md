# 005 · LLM을 OpenRouter로

| 항목 | 값 |
|---|---|
| 상태 | ✅ 완료 |
| 단계 | Phase 0 · 서버 |
| 시작 | 2026-10-14 23:46 KST |
| 완료 | 2026-10-14 23:51 KST |
| 소요 | 약 5분 |
| 최종 수정 | 2026-10-14 23:57 KST |

## 목표
사용자 요청에 따라 답변 LLM 호출을 OpenRouter 경유로 바꾼다 (Gemini 사용 가능 여부도 문의됨).

## 작업 로그
- `23:46` 시작. 사용자가 OpenRouter 사용 희망, Gemini도 문의 → research 016
- 구현 (세부 시각 확인 필요): `lib/src/providers/openrouter_llm_provider.dart`
  - 기본 모델 `anthropic/claude-haiku-5.5`
  - `provider.data_collection=deny`
  - 누적 텍스트에서 `[n]`이 처음 나타날 때 `LlmCitation` 발행
- `RagServices`: `openrouterApiKey`가 있으면 OpenRouter, 없으면 `anthropicApiKey`로 Claude 직접 호출
- 단위 테스트 2개 추가 (주석 줄 · 분할된 마커 · 스트림 오류)
- `23:51` [ADR 013](../adr/013-llm-via-openrouter.md) 채택 (ADR 004 대체), 커밋 `c2ed837`

## 결과

### research 016 요약

| 항목 | 내용 |
|---|---|
| SSE 형식 | OpenAI 호환. `: ` 주석 줄 무시, `data: [DONE]` 종료, 스트림 도중 `error` 객체 가능 |
| Claude 네이티브 citations | OpenRouter 경유 시 근거 없음 → **`[n]` 마커 방식** 사용 |
| 임베딩 | OpenRouter에 EmbeddingGemma 없음 → **DeepInfra 유지** |
| 무료 모델 | 일 50회 제한, 학습 라우팅 가능성 → 비권장 |

### passwords 키

| 키 | 용도 |
|---|---|
| `openrouterApiKey` | OpenRouter (있으면 우선) |
| `llmModel` | OpenRouter 모델 교체 (선택) |
| `anthropicApiKey` | Claude 직접 호출 (폴백) |
| `claudeModel` | Claude 모델 교체 (선택) |
| `deepinfraApiKey` | 임베딩 |

## 문제와 해결
- 기록된 문제 없음. ⚠️ OpenRouter 실호출 검증 여부는 확인 필요 (키 입력 후 확인)

## 결정 (→ ADR 링크)
- LLM 호출을 OpenRouter 경유로, 인용은 `[n]` 마커로 → [ADR 013](../adr/013-llm-via-openrouter.md) (ADR 004 대체)

## 다음 할 일
- `openrouterApiKey` · `deepinfraApiKey` 입력 후 실호출 검증

## 변경 이력
- `2026-10-14 23:57` 최초 작성
