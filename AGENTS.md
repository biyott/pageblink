# AGENTS.md — ragpod 에이전트 공통 지침

이 저장소는 **ragpod**(Flutter + Serverpod 하이브리드 문서 RAG 앱, Serverpod 해커톤 2026)의 모노레포입니다.

## 구조
- `app/` — Serverpod 프로젝트 (`ragpod_server`, `ragpod_client`(자동 생성, 수정 금지), `ragpod_flutter`)
- `packages/` — 공유 패키지 (Phase 1부터)
- `docs/` — 문서. **종류별 폴더 규칙은 `docs/README.md`와 각 폴더 `README.md`가 정본**입니다

## 문서 작성 규칙 (요약)
- **`docs/` 하위 폴더에 문서를 쓰거나 고치기 전에, 반드시 그 폴더의 `README.md`(규칙·템플릿·목차)를 먼저 읽고 따릅니다.** 문서를 추가하면 그 README의 목차도 갱신합니다
- 문서는 한국어, `docs/<종류>/NNN-kebab-주제.md` (3자리 일련번호)
- 시간은 KST, 셸에서 얻은 값만 사용 (`TZ=Asia/Seoul date "+%Y-%m-%d %H:%M"`)
- 사실 표기: ✅ 확인 / ⚠️ 미확인. 결과·버전·출력을 지어내지 않습니다

## 개발 규칙
- 버전 고정: Flutter 3.47.7 (`.fvmrc`), Serverpod 4.0.4 (모든 `serverpod*` 패키지 동일 버전)
- API 키는 `config/passwords.yaml`(git 제외) 또는 Serverpod Cloud 비밀값에만 둡니다
- LLM·임베딩 호출은 반드시 서버(Serverpod 엔드포인트)를 거칩니다
- 상세: `docs/plan/003-tech-stack-and-prep.md`
