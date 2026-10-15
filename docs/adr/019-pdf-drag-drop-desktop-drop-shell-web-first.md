# 019 · PDF 드래그 앤 드롭 업로드: `desktop_drop`, 앱 셸 수준, 웹 우선

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-15 | 클라이언트(사용자) 결정 · [research 025](../research/025-pdf-drag-drop-upload.md) · [디자인 스펙](../design/upload-dnd-reindex/spec.md) |

## 맥락
- 업로드는 파일 선택기 버튼뿐이었고, 드래그 앤 드롭이 없었다.
- Flutter의 `DragTarget`은 OS 파일 드롭을 받지 못한다. ✅ research 025
- 조사 중 기존 업로드 경로의 결함도 함께 드러났다 (아래 "함께 고치는 결함").

## 결정
- **드롭 수단**: `desktop_drop` 0.8.4 (Apache-2.0, 약 180 KB). 웹·macOS·Windows·Linux ✅, Android preview, iOS 미지원.
- **감지 위치**: 드롭 감지와 오버레이는 **앱 셸 최상위 한 곳**에 둔다. 노트가 열려 있어도, 어느 탭에서도 동작한다.
- **범위**: **웹(데스크톱 브라우저) 우선**. macOS(엔타이틀먼트 `user-selected.read-only` 포함)는 다음 단계.
- **터치 기기**: 모바일 웹·iOS·Android는 드래그 상호작용이 없으므로 기존 업로드 버튼(파일 선택기)만 유지하고, 드롭 안내는 표시하지 않는다.
- **편집기가 열려 있을 때**: 드롭은 편집 중인 노트를 건드리지 않고 **새 문서로 추가**한다 (디자인 안 B).
- **드래그 중 표시**: 브라우저는 드래그 중 파일명을 노출하지 않고 MIME만 준다. 그래서 일반 안내("PDF를 여기에 놓아 추가")를 보이고, PDF 검증은 **드롭 후**에 한다.

### 함께 고치는 업로드 결함 (research 025)
| 결함 | 
|---|
| 첫 파일만 업로드 (`picked.first`) |
| 요청 상한 512 KiB 안내 없음 |
| 클라이언트 20초 타임아웃과 동기 색인 불일치 |
| 스캔 PDF가 조용히 `ready`로 표시됨 |
| 중복 업로드 알림 없음 |
| viewer 권한 실패 시 원문 에러 노출 |

업로드 로직은 `uploadPdfs` 서비스(바이트+이름 입력)로 추출해 **버튼과 드롭이 공유**한다.

## 대안과 기각 이유
| 대안 | 기각 이유 |
|---|---|
| 보드(DocumentsScreen)에서만 감지 | 데스크톱 프로젝트 탭·노트 열림 상태에서 드롭이 꺼짐 |
| `desktop_drop` 없이 웹 직접 구현(`package:web`) | 웹 전용이라 macOS 단계에서 어차피 패키지가 필요. 코드량·이중 작업 |
| `flutter_dropzone` | 웹 전용, 약 23개월 미갱신 |
| `super_drag_and_drop` | Rust/NDK 필요 |

## 근거 (검증)
- scratchpad에서 Flutter 3.47.7로 `pub get` / `flutter test` / `flutter build web` 통과 ✅
- 헤드리스 Chrome(CDP 에뮬레이션)에서 포커스된 TextField 위 드롭이 수신되고 페이지 이동 없음 ✅

## 결과
- 👍 한 번에 여러 PDF를 올릴 수 있고, 업로드 실패·한계가 사용자에게 설명됨
- 👍 업로드 로직이 한 곳이라 버튼·드롭 동작이 어긋나지 않음
- 👎 웹은 창 단위 `dragover`/`drop` 기본 동작 차단이 필수. 빠뜨리면 브라우저가 PDF를 열어 버림 (디자인 스펙 구현 시 주의)
- 📝 [ui-polish 스펙](../design/ui-polish/spec.md)의 UP-07은 [upload-dnd-reindex 스펙](../design/upload-dnd-reindex/spec.md)이 대체한다
- ⚠️ **미확인 리스크**: Safari·Firefox 동작 · Esc/창 이탈 취소 · `<textarea>` 위 드롭 · macOS/Windows/Linux 빌드 · 암호화 PDF 예외 경로
- 🔁 재검토: 위 ⚠️ 항목에서 `desktop_drop`으로 해결 안 되는 문제가 나오면 웹 직접 구현으로 전환 검토

관련: [ADR 003](003-pdf-extract-on-client.md) · [ADR 015](015-product-scope-notes-and-pdfs.md)
