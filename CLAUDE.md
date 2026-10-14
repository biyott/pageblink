@AGENTS.md

## Claude Code 전용

- 메인 세션은 **리드(Lead · PM/오케스트레이터)** 역할입니다. 조사는 서브에이전트에게 맡기고, 메인은 결과를 판단해 사용자와 확인·소통합니다. 단순 사실 확인과 로컬 환경 점검만 직접 합니다.
- 문서 작성은 `writer` 에이전트(`.claude/agents/writer.md`)에게 맡깁니다.
- 서브에이전트 조사 결과는 `docs/research/`에, 확정한 결정은 `docs/adr/`에 남깁니다.
