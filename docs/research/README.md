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
| [010](010-product-naming.md) | 제품 이름 후보 30선 | Top 5: Dotori · 물어봐 · 주머니 · 햄찌 · Pagepin | 결정 대기 |
| [011](011-product-naming-global.md) | 제품 이름 후보 30선 (2차: 국내외 공용) | Top 5: Hutch · Burrow · Dogear · Hamstor · Pinpage | 결정 대기 |
| [012](012-product-naming-burrow-game-terms.md) | 제품 이름 3차: Burrow 변형 · 게임 용어 | Top 5: Pinpage · Burrowpin · Savepoint · Questpage · Pagewarp | 결정 대기 |
| [013](013-product-naming-warp-game-skills.md) | 제품 이름 4차: Warp 변형 · 게임 용어 · 기능 용어집 | Top 5: Pagewarp · Docparty · Savepoint · Pinpage · Blinkpage | 결정 대기 |
| [014](014-blink-name-conflicts.md) | Blink 계열 이름 충돌 확인 | PageBlink 1순위, Blinkit·BlinkNote 제외 | plan 004 |
| [015](015-game-skill-names.md) | 실제 게임 스킬·아이템 이름 30선 | Blink 유지(PageBlink), 기능 용어 Recall·Infrasight·Fog of War | ADR 012 |
| [016](016-openrouter.md) | OpenRouter (LLM·임베딩·무료 모델·요금) | LLM은 OpenRouter + [n] 인용, 임베딩은 DeepInfra 유지 | ADR 013 |
| [017](017-flutter-ux-issues-investigation.md) | Flutter 앱 UX 이슈 6건 (설정 전체화면 · 노트 원 모양 · 라이브 MD · 아이콘 · 문구) | 설정은 `Navigator.push`라 pane 밖 · 원 모양은 테마 enabledBorder(999)+filled가 원인 · 라이브 MD는 buildTextSpan 방식 추천 | 결정 대기 |
| [018](018-desktop-note-typography.md) | 데스크톱 노트 화면 기본 폰트 크기 조정안 | 편집 16 ↔ 미리보기 14 불일치 · h1~h4가 노트 제목보다 큼 · 폭 상한 없음 → 본문 16/1.7 + 680px 컬럼 + 제목 28/24/20/18 | 제안 단계 (ADR 대기) |
| [019](019-ask-screen-locale-chips-scope-model-picker.md) | Ask 화면·언어 설정 UX 3건 (언어 우선순위 · 예시 칩 잘림 · 범위/모델 선택) | 언어는 `main.dart` localeResolutionCallback이 선택을 덮어씀 · 예시 칩은 ActionChip 단일행 구조 · 범위는 FilterChip 체크가 아바타와 겹침, 모델 항목은 서버 note 중복 | 결정 대기 |
