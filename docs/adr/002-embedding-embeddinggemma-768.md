# 002 · 임베딩: EmbeddingGemma-300m 768차원 (기기·서버 공용)

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [research 002](../research/002-flutter-ondevice-rag-stack.md) · [research 006](../research/006-llm-embedding-providers.md) |

## 맥락
기기와 서버가 같은 벡터 공간을 써야 혼합 검색과 승격이 가능하다. pgvector 컬럼은 차원이 고정이다.

## 결정
- 모델: **EmbeddingGemma-300m, 768차원, L2 정규화**
- 프리픽스: 질의 `task: search result | query: …` / 문서 `title: … | text: …`
- 서버: 오늘은 **DeepInfra 호스팅**(⚠️ 제공 확인 필요), 장기는 자체 호스팅(TEI/Ollama) 또는 DeepInfra
- 기기: `flutter_edge_ai` (Phase 1)
- 청크마다 `embeddingModel` 기록

## 대안과 기각 이유
- Voyage `voyage-4-lite`(1024): 품질·무료 한도 좋지만 기기 모델과 공간이 달라 나중에 재임베딩 필요 → **DeepInfra 실패 시 폴백**
- `gemini-embedding-2`(768): 차원은 같아도 다른 벡터 공간
- multilingual-e5-small(384): 기기·서버 공용 가능한 2순위

## 결과
- 👍 오늘 만든 서버 벡터를 Phase 1에서도 그대로 사용
- 👎 한국어 검색 품질 미검증 → `tools/eval` 한국어 30문항으로 측정
- 🔁 재검토: Recall@5가 기준 미달이면 research 후 교체(새 컬럼 백필 절차, research 006 §4)
