# 001 · 기획·조사 세션 (개발 착수 전)

| 항목 | 값 |
|---|---|
| 상태 | ✅ 완료 |
| 단계 | Phase 0 · 착수 전 |
| 시작 | 확인 필요 (세션 시작 시각 기록 없음) |
| 완료 | 2026-10-14 22:38 KST |
| 소요 | 확인 필요 |
| 최종 수정 | 2026-10-14 22:41 KST |

## 목표
주제 #8(개인 문서 RAG 비서)을 하이브리드(기기/서버) RAG로 구체화하고, 개발 전에 필요한 조사·결정·문서 체계를 갖춘다.

## 작업 로그
> 시각은 파일 수정 시각과 셸 출력으로 확인된 것만 적었습니다.

- `19:09` 주제 선정 보고서 저장 (plan 001, 파일 수정 시각)
- `(시각 미기록)` 서브에이전트 3개 병렬 조사: Serverpod/Cloud · Flutter 온디바이스 · 경쟁 제품 → research 001~003
- `(시각 미기록)` 기획·아키텍처 문서 작성 → plan 002
- `(시각 미기록)` 마감 시각 조사: 10/15 06:59 KST로 정정 → research 004
- `22:00` 서브에이전트 Sonnet/high 설정 적용, settings.json 백업 → research 005
- `22:05` 로컬 환경 진단: Flutter 3.24.5 / Dart 3.5.4, Serverpod CLI·Docker·Android SDK·Java 없음
- `(시각 미기록)` 조사 3건 병렬: LLM·임베딩 / Serverpod 4 셋업 / Flutter 클라이언트 → research 006~008
- `22:10` 기술 스택 & 준비 문서 작성 → plan 003
- `(시각 미기록)` 모노레포 구조 설계, 프로젝트명 `ragpod` · 폴더 `app/` 확정 → ADR 006
- `22:27` devlog 폴더·writer 에이전트(`.claude/agents/writer.md`) 생성
- `(시각 미기록)` CLAUDE.md/AGENTS.md 로딩 규칙 조사 → research 009
- `22:38` 문서 종류별 폴더 재구성(plan/research/adr/devlog), 조사·결정 기록 정리

- `22:41` 폴더별 `AGENTS.md` 제거, README.md 단일 정본으로 정리 → ADR 011

## 결과
- 📐 plan 3건 · 🔎 research 9건 · ⚖️ ADR 11건
- 루트 `AGENTS.md`, `CLAUDE.md`, `docs/README.md`(문서 레지스트리)

## 문제와 해결
| 문제 | 해결 |
|---|---|
| 보고서의 마감 "10/14 23:59"에 시간대 없음 | 메타데이터 확인 → 10/14 21:59 UTC = 10/15 06:59 KST |
| 로컬 SDK가 Serverpod 4 요건 미달 | Flutter 3.47.7로 업그레이드 예정 (fvm) |
| Cloud DB pgvector 미확인 | ADR 008 폴백 순서, 게이트 G2에서 검증 |

## 결정
ADR [001](../adr/001-offline-retrieval-online-generation.md) ~ [010](../adr/010-acl-in-query.md)

## 다음 할 일
- [ ] Flutter 3.47.7 업그레이드 (`fvm install 3.47.7 && fvm global 3.47.7 && fvm use 3.47.7`)
- [ ] `dart install serverpod_cli` → `serverpod create ragpod` → `mv ragpod app`
- [ ] G1: 로컬 `Vector(768)` 마이그레이션
- [ ] Claude Code 재시작 → `/agents`에서 writer 확인

## 변경 이력
- `2026-10-14 22:38` 최초 작성 (리드)
- `2026-10-14 22:41` 폴더별 AGENTS.md 제거 반영 (ADR 011)
