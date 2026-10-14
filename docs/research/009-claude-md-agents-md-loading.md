# 009 · CLAUDE.md / AGENTS.md 로딩 규칙

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (claude-code-guide) |
| 질문 | 폴더별 문서 종류 규칙을 사람(GitHub)과 에이전트(Claude Code, Codex 등)가 함께 따르게 하려면 어떤 파일에 둬야 하나? |
| 결론 한 줄 | **폴더 `README.md`를 정본**으로, 같은 폴더 `AGENTS.md`에 `@README.md` 한 줄 · 루트는 `AGENTS.md` + `CLAUDE.md`(`@AGENTS.md`) |
| 반영 | [ADR 007](../adr/007-docs-structure-and-agent-files.md) · 루트 `AGENTS.md`, `CLAUDE.md` · `docs/*/AGENTS.md` |

## 1. AGENTS.md 지원 ✅
- Claude Code는 **v2.1.277부터 AGENTS.md를 기본으로 읽음** (Bedrock·텔레메트리 비활성 세션은 v2.1.281). 이전 버전은 CLAUDE.md만
- 기본 설정 `claude-md-or-agents-md`:
  - 작업 디렉터리나 상위에 `CLAUDE.md`/`CLAUDE.local.md`가 있으면 그것만 읽고 `AGENTS.md`는 무시
  - 없으면 루트 `AGENTS.md`와 `.claude/AGENTS.md`를 시작 시 로드
  - 하위 폴더 `AGENTS.md`는 그 폴더 파일을 읽을 때 로드 (그 폴더에 `CLAUDE.md`가 없을 때)
- 둘 다 읽게 하려면 `claude-md-and-agents-md`. 같은 파일을 두 번 읽지는 않음
- 권장 공유 방식: `CLAUDE.md`에 `@AGENTS.md` + 아래에 Claude 전용 내용. 심볼릭 링크도 되지만 Edit/Write가 링크를 통해 쓰지 않고, Windows 체크아웃에서 깨짐

## 2. 하위 폴더 파일과 경로별 규칙 ✅
- 상위 디렉터리의 `CLAUDE.md`는 시작 시 로드
- 하위 폴더 `CLAUDE.md`(예: `docs/devlog/CLAUDE.md`)는 **지연 로드** — 그 폴더의 파일을 읽기·쓰기·편집할 때 (`cat`/`head`도 읽기로 침)
- `.claude/rules/*.md`: `paths:` 없으면 시작 시, `paths:` 글롭이 있으면 일치 파일을 다룰 때 로드
- 각 `CLAUDE.md`는 200줄 이하 권장. `@import`한 파일은 시작 시 로드되므로 컨텍스트 절약 효과 없음

## 3. 서브에이전트 ✅
- 커스텀 서브에이전트는 메인과 같은 `CLAUDE.md` 계층(프로젝트 규칙, 로드된 `AGENTS.md` 포함)을 받음
- 예외: 내장 Explore·Plan, `omitClaudeMd`를 설정한 커스텀 에이전트. 그래도 하위 폴더 `CLAUDE.md`와 경로 규칙은 해당 파일 작업 시 로드
- 메인의 자동 메모리는 서브에이전트에 전달되지 않음 → 필요하면 `memory` frontmatter

## 4. 권장 구성 (조사자 제안, 공식 가이드 아님 ⚠️)
- 폴더 규칙은 그 폴더 `README.md`에 → GitHub 렌더링 + 단일 정본
- 같은 폴더에 `AGENTS.md` 한 줄 `@README.md` (import는 그 파일 기준 상대 경로) → 그 폴더를 다룰 때 지연 로드, Cursor·Codex도 같은 `AGENTS.md`를 읽음
- 루트 `AGENTS.md`에는 짧은 색인만
- 루트 `CLAUDE.md`가 있으면 루트 `AGENTS.md`가 무시되므로 `CLAUDE.md`에 `@AGENTS.md`를 넣음
- 확인: `/context`로 로드된 메모리 파일 목록
- 강제가 필요하면 PreToolUse 훅 (`CLAUDE.md`는 강제가 아니라 맥락)

## 출처
- https://code.claude.com/docs/en/memory (#agents-md)
- https://code.claude.com/docs/en/sub-agents ("What loads at startup")
