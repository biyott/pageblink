# 005 · 백엔드: Serverpod 메인 + AI 워커/외부 API

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [research 001](../research/001-serverpod-cloud-pgvector.md) · [research 006](../research/006-llm-embedding-providers.md) |

## 결정
- **Serverpod(Dart)가 유일한 입구**: API·인증·권한·파일·DB·스트리밍
- 무거운 ML은 외부로: 오늘은 외부 API(Claude, DeepInfra), Phase 1+는 Python AI 워커(`services/embedder/`: TEI/Ollama, OCR)
- AI 워커는 내부 서비스 — 인증·권한·저장을 맡지 않음
- DB는 하나(Postgres + pgvector). 별도 벡터 DB 금지

## 대안과 기각 이유
- Python 메인 백엔드: 해커톤 필수 요건·스택 활용 점수와 충돌, 계약 자동 생성 이점 상실
- 별도 벡터 DB(Pinecone 등): ORM 벡터 쿼리 상실, ACL 이중 관리

## 결과
- 👍 권한 체크·데이터 접근이 한 곳
- 👎 외부 API 의존(키·비용 관리) → [plan 003 §6](../plan/003-tech-stack-and-prep.md)
