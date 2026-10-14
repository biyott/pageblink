# 010 · 접근 제어는 검색 쿼리 안에서, 서버가 멤버십 계산

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [plan 002 §5-4](../plan/002-rag-assistant-plan.md) |

## 결정
- 서버가 인증 세션의 사용자로 `ProjectMember`를 조회해 `myProjectIds`를 만들고, **클라이언트가 보낸 projectIds와의 교집합**만 사용 (클라이언트 값 불신)
- 필터(`projectId IN …` 또는 본인 소유)를 **유사도 정렬과 같은 쿼리 안에** 둠 — top-k 후 필터 금지
- 원본 열람 `temporaryDownloadUrl`은 멤버십 확인 후에만 발급
- 역할: owner / editor / viewer

## 결과
- 👍 남의 문서가 프롬프트에 섞이는 사고 차단
- 👎 강한 필터에서 HNSW 재현율 저하 가능 → pgvector 0.8 iterative scan 확인 ⚠️
