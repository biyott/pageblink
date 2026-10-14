# 005 · Claude Code 서브에이전트·advisor 모델 설정

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (claude-code-guide) |
| 질문 | 기본 서브에이전트를 Sonnet 5.5 + effort high로, advisor를 Opus 5.5 + high로 설정하려면? |
| 결론 한 줄 | 서브에이전트 모델은 env로 강제, effort는 에이전트 파일 frontmatter로. **advisor effort 설정은 문서에 없음** |
| 반영 | `~/.claude/settings.json`, `~/.claude/agents/{general-purpose,Explore}.md` (2026-10-14 22:00 적용) |

## 핵심 결론

### 1. 서브에이전트 모델
- 개별: 에이전트 frontmatter `model:` — `sonnet` · `opus` · `haiku` · `fable` · 전체 모델 ID · `inherit`. `sonnet` = Sonnet 5.5 ✅
- 전체: 환경변수 `CLAUDE_CODE_SUBAGENT_MODEL`. 기본값일 뿐이라 frontmatter·호출 시 지정이 우선 ✅
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`이면 그것들도 덮어씀 (v2.1.257+) ✅
- 내장 에이전트: Explore는 `opus` 고정(강제 없이는 env 무시), general-purpose는 env 따름, Plan은 메인 모델 상속 ✅
- fork: 메인 세션 모델과 동일 ✅ (fork에 frontmatter가 무시되는지는 ⚠️)

### 2. 서브에이전트 effort
- frontmatter `effort:` — `low` · `medium` · `high` · `xhigh` · `max` ✅
- 세션 레벨보다 우선, 단 `CLAUDE_CODE_EFFORT_LEVEL` 환경변수보다는 아래, `maxEffortLevel`로 상한 ✅
- 전체 서브에이전트 effort를 한 번에 거는 설정은 없음. 최상위 `effortLevel`이 frontmatter 없는 서브에이전트에 적용되는지는 ⚠️

### 3. Advisor
- `/advisor opus`(→ `advisorModel` 저장), `claude --advisor opus`, settings `"advisorModel": "opus"`, `/advisor off` ✅
- advisor는 메인 모델과 같거나 높은 등급이어야 함. 서브에이전트도 advisor를 상속하고 같은 조합 검사를 받음 ✅
- **advisor effort 설정: 문서에 없음 ⚠️**

## 적용 결과 (리드 실행)
- `settings.json` 백업: `~/.claude/settings.json.bak-20261014220019`
- `env`에 `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 추가
- `advisorModel: opus`, `effortLevel: high`는 이미 설정되어 있어 유지 (`effortLevel`은 메인 세션 effort)
- `~/.claude/agents/general-purpose.md`, `Explore.md`(읽기 전용 도구): `model: sonnet`, `effort: high`
- 재시작 후 적용. general-purpose를 같은 이름으로 덮어쓰는 방식은 ⚠️ (`/agents`로 확인)

## 출처
- https://code.claude.com/docs/en/sub-agents.md
- https://code.claude.com/docs/en/advisor.md
- https://code.claude.com/docs/en/model-config.md
- https://code.claude.com/docs/en/settings-reference.md
- https://code.claude.com/docs/en/env-vars.md (직접 확인 안 함)
