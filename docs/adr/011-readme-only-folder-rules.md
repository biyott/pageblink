# 011 · 폴더 규칙은 README.md만 (폴더별 AGENTS.md 제거)

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 (007 일부 대체) | 2026-10-14 | 사용자 결정 · [research 009](../research/009-claude-md-agents-md-loading.md) |

## 맥락
ADR 007은 폴더마다 `README.md`(정본)와 `AGENTS.md`(`@README.md` 한 줄)를 함께 두었다. 같은 규칙을 가리키는 파일이 둘이라 구조가 복잡하다.

## 결정
- `docs/*/AGENTS.md`를 **제거**하고 폴더 규칙은 **`README.md` 하나**에만 둔다
- 루트 `AGENTS.md`에 "docs 하위 폴더에 쓰기 전에 그 폴더 README.md를 먼저 읽고, 추가 시 목차 갱신" 규칙을 명시
- writer 에이전트 지침도 같은 규칙을 따름 (이미 반영됨)
- 루트 `AGENTS.md` + `CLAUDE.md`(`@AGENTS.md`)는 유지

## 대안과 기각 이유
- README 제거, AGENTS.md에 규칙 직접 작성: GitHub에서 폴더를 열 때 설명·목차가 보이지 않음 (심사위원 열람에 불리)
- 기존 유지(README + AGENTS.md): 자동 로드 이점은 있으나 파일 중복

## 결과
- 👍 정본 1개, 파일 수 감소
- 👎 폴더 진입 시 자동 로드 없음 → 에이전트가 지침을 놓칠 수 있음
- 🔁 재검토: 에이전트가 폴더 규칙을 반복해서 어기면 폴더별 AGENTS.md(또는 경로 규칙 `.claude/rules/`) 재도입
