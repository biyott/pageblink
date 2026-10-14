# 008 · 노트 기능 (제품 범위 확장: Keep 스타일 노트 + PDF)

| 항목 | 값 |
|---|---|
| 상태 | 🚧 진행 중 (Cloud 배포 결과 확인 필요) |
| 단계 | Phase 0 · 서버 + 앱 |
| 시작 | 2026-10-15 00:22 KST |
| 완료 | – |
| 소요 | – |
| 최종 수정 | 2026-10-15 00:24 KST |

## 목표
- 제품 범위 변경 반영: PageBlink는 PDF 전용 RAG가 아니라 **Google Keep 스타일 마크다운 노트 앱**이고, PDF도 올릴 수 있으며, **노트와 PDF 전체에 질문**한다. → [ADR 015](../adr/015-product-scope-notes-and-pdfs.md)
- Notion 같은 실시간 동기화·풍부한 편집은 **나중** 기능 → [plan 005](../plan/005-follow-up-spec.md) 항목 10~12.

## 작업 로그
시각은 오케스트레이터가 전달한 값이다.
- `2026-10-15 약 00:20` 사용자가 제품 범위 변경 결정
- `00:17`–`00:21` (노트와 별개) 가입 비밀번호 규칙을 클라이언트에서 완화하고 재배포: 12–50자, 소문자 + 숫자, 대문자 **또는** 특수문자. 커밋 `fe15fbf`
- `00:22`–`00:30` 노트 기능 구현 (아래 결과). 서버 `Document.kind` / `body`, `saveNote` / `get`, `Citation.kind`, 새 마이그레이션 `20261014152214229`. 앱 "노트" 탭 · `NoteEditorScreen`
- `00:24` ADR 015, README, plan 005, 이 기록 작성 (문서 작성 시점, 서버 시계 기준)
- 이후 Serverpod Cloud에 배포 중 (결과 확인 필요)

## 결과

### 서버

| 항목 | 내용 |
|---|---|
| `Document.kind` | `'note'` \| `'pdf'`, 기본 `'pdf'` (기존 문서는 그대로 PDF) |
| `Document.body` | 노트의 마크다운 본문 (`String?`, PDF는 null) |
| `document.saveNote(documentId?, title, body, projectId?)` | 노트 생성 또는 수정. 저장 시 `_index()`로 재청킹·재임베딩. 노트는 **page 1** 한 장으로 인덱싱. 기존 문서가 노트가 아니면 거절 |
| `document.get(documentId)` | 노트 열기용 단건 조회, ACL 확인 |
| `_index()` | `upload`와 `saveNote`가 공유하는 청킹·임베딩·저장 (이전 청크 교체) |
| `Citation.kind` | `'note'` \| `'pdf'`, 기본 `'pdf'`. 앱이 인용을 어디로 열지 결정 |
| 마이그레이션 | `app/pageblink_server/migrations/20261014152214229/` 추가 (`migration_registry.txt` 갱신). 생성 코드(`protocol`, `endpoints`)와 클라이언트(`pageblink_client`)도 갱신 |

### 앱

| 항목 | 내용 |
|---|---|
| "노트" 탭 | Keep 스타일 **노트 카드 그리드 + PDF 카드** |
| 버튼 | "새 노트" 확장 FAB + 작은 PDF FAB |
| `NoteEditorScreen` | 제목, 마크다운 본문, 툴바(제목 / 굵게 / 기울임 / 목록 / 체크박스 / 인용 / 코드), 미리보기 토글(`gpt_markdown`), **뒤로 가면 저장**. 기존 노트는 미리보기로 열림 |
| 노트 인용 | ⚡ 인용 탭 → 노트 편집 화면이 열리고 인용 구절이 상단에 표시됨 (코드상 `highlight` 배너 `⚡ “구절”`. 본문 안 하이라이트는 아님) |
| 파일 | `app/pageblink_flutter/lib/features/notes/note_editor_screen.dart` (신규), `documents_screen.dart` · `page_viewer_screen.dart` 수정 |

### 검증

| 항목 | 결과 |
|---|---|
| 코드가 작업 트리에 존재 | ✅ (`document_endpoint.dart`의 `saveNote` · `get` · `_index`, `document.spy.yaml` · `citation.spy.yaml`의 `kind` 확인) |
| 서버 테스트 · `flutter analyze` 결과 | ⚠️ 이 기록에서는 확인 못 함 (확인 필요) |
| 노트 저장 → 질문 → 노트 인용 → 편집 화면 E2E | ⚠️ 확인 필요 |
| Cloud 배포·마이그레이션 적용 | ⚠️ 배포 중, 결과 확인 필요 |
| 비밀번호 규칙 | 클라이언트에서만 검사 ⚠️ 서버 측 규칙 변경 여부는 확인 필요 |

## 문제와 해결
| # | 문제 | 해결 |
|---|---|---|
| 1 | 오케스트레이터가 전달한 구현 시각(`00:22`–`00:30`)의 끝이 문서 작성 시점의 서버 시계(`00:24`)보다 뒤 | 전달값을 그대로 기록. 정확한 완료 시각은 확인 필요 |

## 결정 (→ ADR 링크)
- [ADR 015](../adr/015-product-scope-notes-and-pdfs.md): 범위 = Keep 스타일 노트 + PDF, 둘 다에 RAG. 실시간 협업은 보류

## 다음 할 일
- Cloud 배포 결과 확인, 새 마이그레이션 적용 확인
- E2E: 노트 작성 → 저장 → 질문 → 노트 인용 ⚡ → 편집 화면
- 후속 기능: [plan 005](../plan/005-follow-up-spec.md) 항목 10 (실시간 동기화·협업), 11 (에디터 고도화), 12 (버전 기록)
- 완료 후 이 기록의 `상태` · `완료` · `소요` 채우고 [목차](README.md) 갱신

## 변경 이력
- `2026-10-15 00:24` 최초 작성 (사실은 오케스트레이터가 전달한 값, 코드 확인으로 보강)
