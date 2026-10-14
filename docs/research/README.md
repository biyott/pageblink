# 🔎 조사 (Research)

서브에이전트가 조사한 결과를 **그 시점의 스냅샷**으로 남깁니다. 판단(결정)은 여기 쓰지 않고 [`../adr/`](../adr/)에 씁니다.

## 규칙

| 항목 | 규칙 |
|---|---|
| 파일명 | `NNN-kebab-주제.md` (3자리 일련번호) |
| 단위 | 조사 요청 1건 = 파일 1개 |
| 표기 | ✅ 공식 문서·pub.dev로 확인 · ⚠️ 미확인/추정/출처끼리 충돌 |
| 출처 | **필수**. 문서 끝에 URL 목록 |
| 수정 | 하지 않습니다. 정정이나 재조사는 새 번호로 쓰고 서로 링크합니다 |

## 템플릿

```markdown
# NNN · 제목

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose / claude-code-guide …) |
| 질문 | 무엇을 알아내려 했나 |
| 결론 한 줄 | |
| 반영 | 관련 ADR · plan 링크 |

## 핵심 결론
## 상세
## 미확인 · 리스크
## 출처
```

## 목차

| # | 제목 | 핵심 결론 | 반영 |
|---|---|---|---|
| [001](001-serverpod-cloud-pgvector.md) | Serverpod ORM·Cloud와 pgvector | ORM은 2.8.0+부터 Vector 지원 ✅ · Cloud DB의 pgvector는 문서 없음 ⚠️ | ADR 005, 008 |
| [002](002-flutter-ondevice-rag-stack.md) | Flutter 온디바이스 RAG 스택 | 오프라인 검색 + 온라인 생성이 v1 정답 · EmbeddingGemma 공용 | ADR 001, 002 |
| [003](003-competitors-and-gaps.md) | 경쟁 제품과 빈틈 | 문서 단위로 계층을 오가는 제품 없음 | plan 002 |
| [004](004-hackathon-deadline.md) | 해커톤 마감 시각 | 10/14 21:59 UTC = **10/15 06:59 KST** | README |
| [005](005-claude-code-agent-config.md) | Claude Code 서브에이전트·advisor 설정 | env + 에이전트 파일로 Sonnet/high 지정 · advisor effort 설정 없음 | ~/.claude 설정 |
| [006](006-llm-embedding-providers.md) | LLM·임베딩 제공자 | Claude Sonnet 5.5 + EmbeddingGemma(DeepInfra) | ADR 002, 004 |
| [007](007-serverpod4-setup-and-cloud.md) | Serverpod 4 셋업·Cloud 배포 | Dart ^3.12.2 · 사용자 ID UuidValue · `serverpod start` | plan 003 |
| [008](008-flutter-client-stack.md) | Flutter 클라이언트 스택 | Flutter 3.47.7 · Riverpod · pdfrx · gpt_markdown | plan 003 |
| [009](009-claude-md-agents-md-loading.md) | CLAUDE.md / AGENTS.md 로딩 규칙 | 폴더 README.md를 정본, AGENTS.md는 `@README.md` | ADR 007 |
