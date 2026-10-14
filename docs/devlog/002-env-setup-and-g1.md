# 002 · 개발 환경 구성 · 프로젝트 생성 · G1(로컬 pgvector)

| 항목 | 값 |
|---|---|
| 상태 | ✅ 완료 |
| 단계 | Phase 0 · G1 |
| 시작 | 2026-10-14 22:42 KST |
| 완료 | 2026-10-14 22:46 KST |
| 소요 | 약 4분 |
| 최종 수정 | 2026-10-14 22:46 KST |

## 목표
Serverpod 4 요건에 맞게 SDK를 올리고, `ragpod` 프로젝트를 `app/`에 만든 뒤, 로컬 DB에서 pgvector가 동작하는지 확인한다 (게이트 G1).

## 작업 로그
- `22:42` 문서 정리 커밋 `80c8908`
- `22:42` `fvm install 3.47.7` 완료 (7.9초, 캐시 사용) → `fvm global 3.47.7`, `fvm use 3.47.7` (`.fvmrc`)
- `22:43` `dart install serverpod_cli` → Serverpod 4.0.4. PATH에 `~/.local/state/Dart/install/bin` 추가 (`~/.bashrc`)
- `22:44` `serverpod create ragpod --database --auth --no-redis --webapp --no-website --ide claude --ide codex` → `mv ragpod app`
- `22:44` 데이터 모델 7개 작성 → `serverpod generate` → `serverpod create-migration` (`20261014134518641`)
- `22:45` G1 스모크 테스트 통과 (내장 Postgres, 6초)
- `22:46` 커밋 `07d3488`, 태그 `g1`

## 결과

| 항목 | 값 |
|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5 ✅ |
| Serverpod CLI | 4.0.4 ✅ |
| 구조 | `app/` = pub workspace 루트 (`name: _`, `sdk: ^3.12.2`, workspace: client·server·flutter) |
| 생성물 | `app/AGENTS.md`(Serverpod 에이전트 지침), `app/.claude/skills/`(serverpod-* 등), `app/.mcp.json`(serverpod·dart MCP) — skills·mcp는 `app/.gitignore`로 커밋 제외 |
| DB | 개발: 내장 Postgres `localhost:8090`, 테스트: `9090` — **Docker 불필요** ✅ |
| 모델 | `Project`, `ProjectMember`, `Document`, `DocChunk`(`Vector(768)` + HNSW cosine), `PageText`, `Citation`, `AnswerEvent` |
| G1 | ✅ **내장 Postgres에 pgvector 있음** — 768차원 3건 저장 후 `distanceCosine` 정렬로 최근접 반환 (`test/integration/pgvector_smoke_test.dart`) |

생성된 마이그레이션은 pgvector가 없으면 명시적으로 실패합니다 (Cloud G2 판정에 그대로 쓸 수 있음):

```sql
IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
  EXECUTE 'CREATE EXTENSION IF NOT EXISTS vector';
ELSE
  RAISE EXCEPTION 'Required extension "vector" is not available on this instance. ...';
```

## 문제와 해결
| 문제 | 해결 |
|---|---|
| `dart install` 후 `serverpod` 명령을 못 찾음 | `~/.local/state/Dart/install/bin`을 PATH에 추가 |
| research 007의 문서 충돌(내장 DB pgvector 유무) | 실측으로 **있음** 확정 → Docker 대안 불필요 |

## 결정
- [ADR 008](../adr/008-pgvector-fallback.md) 4단계(로컬 Docker)는 불필요
- `app/AGENTS.md` 지침: **개발 서버(`serverpod start`)는 사용자가 실행**, 에이전트는 MCP 도구 사용

## 다음 할 일
- [ ] (사용자) `serverpod cloud auth login` → G2: Cloud 배포로 pgvector 확인
- [ ] (사용자) Anthropic · DeepInfra 키 발급 → `passwords.yaml`
- [ ] 서버: 업로드·청킹·임베딩 서비스, `ask` 스트림

## 변경 이력
- `2026-10-14 22:46` 최초 작성 (리드)
