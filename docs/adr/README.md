# ⚖️ 결정 기록 (ADR)

리드가 확정한 결정을 **결정 1건 = 파일 1개**로 남깁니다. 근거가 된 사실은 [`../research/`](../research/)를 링크합니다.

## 규칙

| 항목 | 규칙 |
|---|---|
| 파일명 | `NNN-kebab-주제.md` (3자리 일련번호) |
| 상태 | `제안` → `채택` → (`대체됨: NNN` / `폐기`) |
| 수정 | 본문은 고치지 않고 상태만 바꿉니다. 결정이 바뀌면 새 ADR을 쓰고 서로 링크합니다 |
| 길이 | 한 화면 안. 길어지면 상세는 plan/research로 |

## 템플릿

```markdown
# NNN · 결정 제목

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | research NNN |

## 맥락
## 결정
## 대안과 기각 이유
## 결과 (좋아지는 점 · 감수할 점 · 재검토 조건)
```

## 목차

| # | 결정 | 상태 |
|---|---|---|
| [001](001-offline-retrieval-online-generation.md) | v1 온디바이스 범위: 오프라인 검색 + 온라인 생성 | 채택 |
| [002](002-embedding-embeddinggemma-768.md) | 임베딩: EmbeddingGemma-300m 768차원 (기기·서버 공용) | 채택 |
| [003](003-pdf-extract-on-client.md) | PDF 텍스트는 앱(pdfrx)에서 추출 | 채택 |
| [004](004-llm-claude.md) | LLM: Claude Sonnet 5.5 (서버 경유 스트리밍) | 대체됨 → 013 |
| [005](005-backend-split.md) | 백엔드: Serverpod 메인 + AI 워커/외부 API | 채택 |
| [006](006-monorepo-app-folder.md) | 모노레포: 패키지명 `ragpod`, 바깥 폴더 `app/` | 채택 |
| [007](007-docs-structure-and-agent-files.md) | 문서 종류별 폴더 + README 정본 + AGENTS.md | 일부 대체됨 → 011 |
| [008](008-pgvector-fallback.md) | pgvector 폴백 순서 (Cloud → Neon → Dart 코사인) | 채택 · G2 통과 (폴백 불필요) |
| [009](009-device-tier-privacy-and-sync.md) | Device 계층 프라이버시 · 승격 · 동기화 원칙 | 채택 |
| [010](010-acl-in-query.md) | 접근 제어는 검색 쿼리 안에서, 서버가 멤버십 계산 | 채택 |
| [011](011-readme-only-folder-rules.md) | 폴더 규칙은 README.md만 (폴더별 AGENTS.md 제거) | 채택 |
| [012](012-product-name-pageblink.md) | 제품 이름 PageBlink, 패키지명까지 변경 | 채택 (006 일부 대체) |
| [013](013-llm-via-openrouter.md) | LLM은 OpenRouter 경유 (기본 Claude Haiku 5.5) | 채택 (004 대체) · 일부 대체됨 → 014 |
| [014](014-model-catalog-and-rotation.md) | 모델 카탈로그 + 자동 로테이션 (무료 모델 기본) | 채택 (013 일부 대체) |
| [015](015-product-scope-notes-and-pdfs.md) | 제품 범위: Keep 스타일 마크다운 노트 + PDF 업로드, 둘 다에 RAG (실시간 협업 보류) | 채택 |
| [016](016-app-icon-and-ui-icon-direction.md) | 앱 아이콘 V1b Sparkle Fold, UI 아이콘 Lucide 스트로크 먼저 (실패 시 S3 커스텀) | 채택 |
| [017](017-image-generation-model-guidance.md) | 이미지 생성: 목업은 Nano Banana 2.1, 로고·아이콘 최종본은 손으로 쓴 SVG | 채택 |
| [018](018-body-font-pretendard-single-family.md) | 본문 폰트를 Pretendard 한 가족으로 통일 (Inter·Noto Sans KR 제거) | 채택 |
| [019](019-pdf-drag-drop-desktop-drop-shell-web-first.md) | PDF 드래그 앤 드롭: `desktop_drop`, 앱 셸 수준, 웹 우선 | 채택 |
