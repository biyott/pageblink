# 007 · 문서 종류별 폴더 + README 정본 + AGENTS.md

| 상태 | 결정일 | 근거 |
|---|---|---|
| 일부 대체됨: [011](011-readme-only-folder-rules.md) | 2026-10-14 | 사용자 결정 · [research 009](../research/009-claude-md-agents-md-loading.md) |

## 결정
- `docs/{plan, research, adr, devlog}/` — 폴더마다 3자리 일련번호 `NNN-kebab-주제.md`
- **각 폴더 `README.md` = 규칙·템플릿·목차의 정본** (GitHub에서 보임)
- 각 폴더 `AGENTS.md` = `@README.md` 한 줄 → Claude Code·Codex 등이 그 폴더를 다룰 때 규칙을 읽음
- 루트 `AGENTS.md` = 공통 지침, 루트 `CLAUDE.md` = `@AGENTS.md` + Claude 전용(리드 역할, writer 위임)
- `docs/README.md` = 문서 종류 레지스트리
- devlog는 수행 일시(시작·완료·최종 수정, 작업 로그 타임스탬프)를 셸 시각으로 기록

## 대안과 기각 이유
- 폴더별 `CLAUDE.md`: Claude 전용이라 다른 에이전트가 못 읽음
- 규칙을 AGENTS.md에 직접: 사람용 README와 내용 중복

## 결과
- 👍 사람·에이전트가 같은 정본을 봄
- 👎 `CLAUDE.md`는 강제가 아님 → 필요 시 PreToolUse 훅
