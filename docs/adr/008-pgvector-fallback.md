# 008 · pgvector 폴백 순서

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 (G2에서 검증) | 2026-10-14 | [research 001](../research/001-serverpod-cloud-pgvector.md) · [research 007](../research/007-serverpod4-setup-and-cloud.md) |

## 맥락
Serverpod ORM은 `Vector`를 지원하지만 Cloud 관리형 DB의 pgvector 확장 여부가 문서에 없다.

## 결정 (게이트 G2, 23:15 KST 목표)
1. **Cloud 관리형 DB**에 더미 `Vector(768)` 모델 배포 → 성공하면 그대로
2. 실패 → **Neon(pgvector)**을 `SERVERPOD_DATABASE_*`로 연결
3. 그것도 실패 → `List<double>` 저장 + Dart 코사인 계산 (개인 규모면 충분)
4. 로컬(G1): 내장 Postgres에 pgvector가 없으면 Docker `ghcr.io/serverpod/postgres`

## 결과
- 결과는 devlog에 기록하고 이 ADR 상태를 갱신
