# 025 · PDF 드래그 앤 드롭 업로드 (드롭 존) 기술 조사와 계획

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 14:18 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용 + scratchpad 실험) |
| 질문 | 노트 화면 아무 곳(또는 적절한 구역)에 PDF를 끌어다 놓으면 업로드되고, 끄는 동안 드롭 존 안내가 보이게 하려면 무엇을·어디에·얼마나 바꿔야 하나 |
| 결론 한 줄 | **`desktop_drop` 0.8.4 하나로 웹(Chrome)·macOS를 모두 덮고**, 드롭 감지는 **셸 최상위 1곳**에 둔다. 업로드 로직은 `DocumentsScreen` 안의 `_upload`에서 **화면과 무관한 서비스로 추출**해야 한다(데스크톱 Projects 탭에서는 `DocumentsScreen`이 마운트되지 않음). 제품 코드 약 350~450줄 + 테스트 약 200줄 ⚠️ |
| 반영 | 결정 대기 (ADR 후보: 드롭 구역 범위 · 대상 프로젝트 규칙). 병행 시안: [`docs/design/upload-dnd-reindex/`](../design/upload-dnd-reindex/) (PNG 목업 `dnd-1`~`dnd-8`, 문서 없음) — 시안 B(편집 중에도 "새 문서로 추가")·티어 칩 구역이 이 문서의 추천 (a)와 같은 방향. 시안의 드래그 고스트에 보이는 파일명은 OS 렌더링이고, 앱 오버레이에서는 파일명을 쓸 수 없음(§2) |

> 실험은 모두 scratchpad(`.../scratchpad/dropexp`)에서 했고 제품 코드·`test/`는 건드리지 않았습니다. 실험 파일은 조사 후 삭제했습니다.

## 핵심 결론

1. **현재 업로드는 "파일 1개 · 동기 · 화면 종속"** 입니다. `FilePicker.pickFiles`(다중 선택 가능)를 쓰면서 `picked.first`만 처리하고 나머지는 조용히 버립니다 (`documents_screen.dart:61-66`) ✅. 진행 상태 `_busy`는 `DocumentsScreen`의 로컬 상태라(`:27`) 다른 화면에서는 보이지 않습니다.
2. **서버 한계가 클라이언트에 노출되지 않습니다.** `maxRequestSize`가 512 KiB(`config/development.yaml:42` 등)라, 추출된 **텍스트 JSON**이 그보다 크면 `upload`가 실패합니다. PDF 파일 자체의 크기 상한은 클라이언트·서버 어디에도 없습니다(원본은 스토리지로 직접 업로드, `:216-227`) ✅.
3. **드롭 수단은 `desktop_drop`이 최선입니다.** 웹은 `window`의 DOM 드래그 이벤트를 직접 받고(소스 확인 ✅), macOS·Windows·Linux는 네이티브로 받습니다. Flutter 3.47.7에서 `pub get` · `flutter test` · `flutter build web --release`가 모두 통과했습니다 ✅ (scratchpad).
4. **드래그 중에는 파일 이름을 알 수 없습니다.** 실제 Chrome에서 `dragover` 때 확인된 것은 `kind=file`, `type=application/pdf`, `getAsFile()=null`, `files.length=0` 뿐입니다 ✅. 따라서 안내는 "PDF를 여기에 놓으세요"처럼 **파일명 없는 일반 문구**이고, 검증은 **드롭 후**에 합니다. (`desktop_drop`은 이 MIME 정보도 전달하지 않아서, 드래그 중 PDF 여부로 오버레이를 걸러낼 수는 없습니다.)
5. **데스크톱 레이아웃이 드롭 구역 선택을 좌우합니다.** ≥1024px에서는 `_tab == 2`이면 `_notes()`(= `DocumentsScreen`)를 아예 만들지 않고(`main.dart:346`), 노트를 열면 `Offstage`로 숨깁니다(`main.dart:209-229`). 그래서 `DocumentsScreen` 안에 드롭 감지를 두면 Projects 탭·편집기에서 꺼집니다. **셸 최상위 1곳**이 맞습니다.

## 상세

### 1. 현재 업로드 흐름 (file:line)

`app/pageblink_flutter/lib/features/documents/documents_screen.dart`

| 순서 | 내용 | 위치 |
|---|---|---|
| 1 | 파일 선택: `FilePicker.pickFiles(type: custom, allowedExtensions: ['pdf'])` → **`picked.first`만 사용** | `:61-66` |
| 2 | 대상 선택: `_chooseTier()` 바텀시트. **프로젝트가 0개여도 항상 띄움**(`_openNote`는 0개면 생략, `:187`). Cloak 항목은 비활성 | `:69-70`, `:216-251` |
| 3 | `_busy = l.reading(name)` → `file.readAsBytes()`(전체를 메모리로) | `:72-74` |
| 4 | **클라이언트 추출**(ADR 003): `extractPages(bytes, name)` → `PdfDocument.openData`, 페이지마다 `loadStructuredText().fullText`, 순차 | `:75`, `pdf_text.dart:9-21` |
| 5 | `client.document.upload(title, pages, sha256, projectId)` — 텍스트 전체를 **한 요청**으로 | `:81-86` |
| 6 | `LocalPdfs.save(id, bytes)` (웹은 메모리만, `local_pdfs.dart:19-26`) | `:87` |
| 7 | 원본 저장 `_storeOriginal`: `pdfUploadDescription` → `FileUploader.uploadByteData` → `confirmPdfUpload`. **실패해도 치명적이지 않음**(스낵바만) | `:88-89`, `:106-119` |
| 8 | `status == 'failed'`면 스낵바, 예외는 `l.uploadFailed(e)`(예외 문자열 그대로), `finally`에서 `_busy = null` + `_refresh()` | `:90-102` |

- **진행 표시**: `_busy` 문자열 + 상단 `LinearProgressIndicator` (`:444-447`). 파일 단위 진행·취소 없음. 업로드 버튼은 `_busy != null`이면 비활성(`:358`, `:413`).
- **프로젝트 결정**: "현재 범위" 개념이 노트 화면에 없습니다. 보드는 개인+전 프로젝트 문서를 섞어 보여 주고(`document_endpoint.dart:list`), Projects 화면에는 문서가 없습니다. 대상은 **매번 바텀시트로 묻는 방식**뿐입니다. Ask 화면의 범위 칩은 검색 범위이지 업로드 대상이 아닙니다.
- **권한**: 서버 `upload`는 프로젝트 대상이면 `owner/editor`만 허용(`document_endpoint.dart:56-63`). 그런데 클라이언트 `Project` 모델에는 역할 필드가 없어(`project.spy.yaml`) **viewer도 시트에 그대로 보이고**, 실패하면 `AccessDeniedException` 문자열이 그대로 스낵바에 나옵니다 ✅(기존 결함).
- **중복**: 서버가 `(contentHash, ownerId, projectId)`가 같고 `ready`면 기존 행을 그대로 반환합니다(`:65-72`). 클라이언트는 그래도 `LocalPdfs.save`와 `_storeOriginal`을 다시 실행해 **원본을 다시 업로드**하고, 사용자에게는 아무 알림이 없습니다.
- **스캔(이미지) PDF**: 텍스트가 비어 `chunks.isEmpty` → 서버는 임베딩을 건너뛰고 **`status='ready'`로 끝냅니다**(`document_endpoint.dart:365-367, 378`). 카드는 정상처럼 보이지만 질문 검색에서는 절대 인용되지 않습니다 ✅(소스 판독; 실제 실행은 ⚠️).
- **암호 PDF**: `openData`에 `passwordProvider`를 안 넘기므로 `PdfPasswordException`이 날 것으로 추정(클래스 존재 ✅, 동작은 ⚠️ 미실행). 현재는 `uploadFailed(e)`의 원문 예외로 보입니다.
- **한도 정리**

| 한도 | 값 | 어디서 | 비고 |
|---|---|---|---|
| API 요청 크기 | **512 KiB** (`maxRequestSize: 524288`) | `config/{development,staging,production}.yaml` | `upload`의 `pages` JSON 전체에 적용. 한글은 UTF-8 3바이트라 대략 17만 자 안팎 ⚠️ |
| PDF 파일 크기 | **없음** | — | 원본은 스토리지 직접 업로드. 전체를 메모리에 올림 |
| 페이지 수 | **없음** | — | 텍스트 합계가 512 KiB를 넘으면 실패 |
| 색인 시간 | 임베딩 배치당 60초, 10분 넘으면 stale → failed | `document_endpoint.dart:15` | 서버 쪽 회수 로직 있음 |
| **클라이언트 호출 타임아웃** | **기본 20초** | `serverpod_client` 4.0.4 `serverpod_client_shared.dart:111-112, 163` (`connectionTimeout ?? Duration(seconds: 20)`), 앱 `lib/client.dart`는 `Client(await serverUrl)`로 덮어쓰지 않음 | `upload`는 **추출 후 색인(임베딩 최대 약 19배치 × 60초)을 한 RPC에서 동기로** 수행. 큰 PDF는 서버가 계속 색인해 `ready`로 끝내도 클라이언트는 20초에 `TimeoutException` → "업로드 실패"로 보임. 재시도하면 해시 단축 경로(`:65-72`)로 기존 행을 받고 원본을 또 업로드. 실제 발생은 ⚠️ 미실행(서버 실행 금지) |
| 파일 선택기 | 다중 선택 가능한데 1개만 처리 | `:61-66` | 드롭 기능과 함께 고치는 것이 자연스러움 |

- **플랫폼 차이**: `file_picker` 13.1.0은 웹·macOS·Android 등을 지원(`pubspec.lock`). `PlatformFile`은 `xFile`·`readAsBytes()`·`length()`를 제공 ✅. `LocalPdfs`는 웹에서 메모리만 보관(`kIsWeb`).
- ⚠️ **macOS 샌드박스**: `macos/Runner/{DebugProfile,Release}.entitlements`에 `com.apple.security.files.user-selected.read-only`가 **없습니다**(`app-sandbox`, `network.client` 등만). 이 상태에서 macOS 파일 선택기·드롭이 파일을 읽을 수 있는지는 **미검증**입니다. 주력 배포가 웹이라 우선순위는 낮지만, macOS 데스크톱을 쓸 거면 먼저 실기 확인이 필요합니다.

### 2. 드래그 앤 드롭 수단 비교

| 수단 | 웹(Chrome) | macOS | 모바일 | 버전·유지보수 | 라이선스 | 크기·의존성 | 비고 |
|---|---|---|---|---|---|---|---|
| **`desktop_drop`** | ✅ (DOM `window` 이벤트) | ✅ | Android 프리뷰, iOS 없음 | 0.8.4, 약 43일 전(≈2026-09-02) 게시, 0.8.x가 최근 2개월에 5회 | Apache-2.0 | tgz 약 180 KB. 의존: `cross_file`·`web`·`flutter_web_plugins`·`universal_platform`(이미 있거나 가벼움), `dbus`(Linux 전용, 순수 Dart) | 469 likes, 845k 다운로드(pub.dev). `DropTarget`의 `onDragEntered/Updated/Exited/Done`, 파일은 `XFile`(= `cross_file`, 이미 `file_picker`가 사용) |
| `flutter_dropzone` | ✅ (플랫폼 뷰) | ❌ (웹 전용) | ❌ | 4.2.1, 약 23개월 전(≈2024-11), 잦은 breaking | MIT | 작음 | `DropzoneView`를 `Stack` 뒤에 둬야 함, 파일은 `DropzoneFileInterface`라 `XFile` 변환 필요. macOS를 못 덮음 |
| `super_drag_and_drop` | ✅ (단, 웹은 **외부→앱 드롭만**) | ✅ | ✅ | 0.9.1, 약 16개월 전(≈2025-06) | MIT | Rust 네이티브 확장, Android는 NDK 약 1 GB | 앱 내부 드래그·다중 포맷까지 가능하지만 이 용도엔 과함. Flutter 3.47.7 호환 ⚠️ 미확인 |
| Flutter 내장 `DragTarget`/`Draggable` | ❌ | ❌ | ❌ | SDK | BSD-3 | 0 | **앱 내부 위젯 간** 드래그 전용. OS가 주는 파일 드롭은 받지 못함(엔진이 파일 드래그 이벤트를 전달하지 않음) ✅ API 정의상 |
| 직접 구현 (`package:web` + `dart:js_interop`) | ✅ | ❌ (별도 구현) | ❌ | — | — | `web` 1.1.1이 이미 lockfile에 있음(직접 의존성으로 승격만 하면 됨), 조건부 import + 스텁 필요, 약 80~120줄 | `desktop_drop`의 웹 구현이 사실상 같은 코드 |

**추천: `desktop_drop` 0.8.4.** 웹과 macOS를 한 API로 덮고, 받는 타입이 `XFile`이라 `file_picker`의 `PlatformFile.xFile`과 같은 서비스 함수로 합칠 수 있습니다. 모바일에는 드롭 개념이 없으므로 기존 FAB·버튼이 유지됩니다(키보드 사용자 대체 경로도 동일).
**폴백**: 웹 단일 타깃으로 좁히거나 `desktop_drop` 웹 이슈가 생기면 `package:web`로 직접 구현(위 표 마지막 줄).

#### `desktop_drop` 웹 동작 (소스 + 실제 브라우저 실험)

소스 `lib/desktop_drop_web.dart`(0.8.4) 확인 ✅:
- `web.window.ondrop/ondragenter/ondragover/ondragleave`에 **프로퍼티로 단일 핸들러**를 겁니다. 네 이벤트 모두 `preventDefault()`를 호출합니다. 즉 **브라우저 기본 동작(PDF를 탭에서 열기)이 막힙니다**. 지금 앱은 이 핸들러가 없어서, PDF를 앱 창에 놓으면 브라우저 기본 동작이 일어날 수 있습니다(DOM 규칙상 그렇다는 것 ✅ MDN, 이 앱에서 직접 재현은 ⚠️ 미실행).
- 드롭 시 `dataTransfer.items`를 **동기적으로** 읽어 `webkitGetAsEntry()`로 파일/폴더를 구분하고, 폴더는 `readEntries`를 반복해 전부 펼칩니다(100개 제한 처리됨). 파일은 `URL.createObjectURL(file)`(blob URL, **해제 안 함** → 소규모 누수)로 `XFile`을 만들고, `name/size/type`이 즉시 채워집니다.
- `webkitGetAsEntry()!`를 쓰므로 **파일이 아닌 드래그(텍스트·링크)** 를 놓으면 JS 예외가 납니다(소스 판독, 앱 영향은 미미 ⚠️ 미재현).
- 모든 드래그(파일 여부 불문)에서 `entered`가 올라옵니다. `types`를 전달하지 않아 **텍스트 드래그에도 오버레이가 뜰 수 있습니다**.

**실제 Chrome 실험** (headless Chrome + CDP `Input.dispatchDragEvent`, 파일 드래그를 에뮬레이트. scratchpad 앱 = `DropTarget` + 자동 포커스 `TextField`, 상태는 `document.title`로 관측) ✅:

| 시나리오 | 결과 |
|---|---|
| 빈 영역 `dragEnter`/`dragOver` | `onDragEntered` 발생 |
| `dragover` 중 `dataTransfer` | `types=["Files"]`, `items[0]={kind:"file", type:"application/pdf", getAsFile():null}`, `files.length=0` → **파일명 불가, MIME은 Chrome에서 가능** |
| 드롭 | `onDragDone`에 파일 1개, `name=a.pdf`, `mimeType=application/pdf`, `length=2000`, `readAsBytes()` 2000바이트 정상(`XFile` 웹 구현이 blob URL을 XHR로 다시 읽음) |
| **포커스된 TextField 위로 이동** | 마우스가 `<flutter-view>`→`<input>` 요소로 넘어가며 `dragleave` 발생 → **`onDragExited`가 한 번 나가고 다음 `dragover`에서 다시 `entered`**. 오버레이가 약 50 ms 깜빡임 |
| **TextField 위에서 드롭** | 정상 수신(`done`), 페이지 URL 불변(탐색 없음). 즉 편집기 위 드롭도 이벤트가 `window`까지 버블링됨 |
| `dragCancel`(창 이탈·Esc 에뮬레이션) | **`onDragExited`가 오지 않음** (CDP 에뮬레이션 한계일 수 있음, 실제 브라우저에서는 ⚠️ 미확인) |

설계 반영: (a) `exited` 후 **150 ms 지연**을 두고 오버레이를 끄고(그 사이 `updated`가 오면 취소), (b) `onDragUpdated`가 **일정 시간(예 400 ms) 없으면 강제로 끄는 안전 타이머**를 둡니다. `dragover`는 브라우저가 약 50 ms마다 계속 쏘므로 안전 타이머가 정상 드래그를 끊지 않습니다.

> CanvasKit 위 동작: 핸들러가 Flutter 캔버스가 아니라 `window` DOM 이벤트라서 렌더러와 무관합니다. 실험은 `flutter build web --release` 기본 렌더러(CanvasKit)로 했고, Wasm 드라이런도 통과했습니다 ✅. 앱 자체에 `package:web` 직접 의존성은 없고(`pubspec.yaml`), 이미 lockfile에 `web 1.1.1`이 있습니다.

#### 항목별 확인

| 질문 | 답 |
|---|---|
| 드롭 **전**에 PDF인지 알 수 있나 | 웹 Chrome: MIME(`application/pdf`)은 `dragover`에서 읽힘 ✅. 파일명·크기는 불가 ✅. Firefox·Safari 동작은 ⚠️ 미확인. **`desktop_drop`은 이 정보를 전달하지 않으므로 사실상 불가** → 일반 문구 안내 + 드롭 후 검증 |
| 여러 파일 | `onDragDone.files`가 목록으로 옴 ✅(웹 소스), 현재 `_upload`는 1개만 처리 |
| 폴더 | 웹: `DropItemDirectory`와 `children`(재귀)로 옴. macOS: `DropItemDirectory`에 children 없음(`channel.dart`의 `const []`). → **폴더는 "지원 안 함"으로 처리**하는 것이 단순 |
| 용량 | 드롭 시점에 웹은 `size`가 즉시 있음, 네이티브는 `length()` 필요 |
| 브라우저 보안 | 드롭 전 파일 내용·이름 접근 불가(보호 모드), 드롭 이벤트에서만 접근 가능 ✅ MDN |
| 확장자 대소문자 | `.PDF`도 허용해야 함. 네이티브(macOS)는 `mimeType`이 null일 수 있어 **확장자 + 매직 바이트(`%PDF-`)** 로 판정 권장 |

### 3. 드롭 구역 설계

현재 레이아웃(`main.dart:263-397`): 폰(<600)은 탭별 Navigator + `IndexedStack`, 태블릿(<1024)은 레일 + 한 화면, 데스크톱(≥1024)은 사이드바 | 중앙(노트 보드 또는 열린 항목 또는 Projects) | Ask 380px.

| 위치 | 장점 | 단점 |
|---|---|---|
| **(a) 셸 최상위 (추천)** | 어느 탭·편집기·Ask에서도 동작. 한 곳만 구현. 웹의 `window.on*` 핸들러는 플러그인 등록 시점(`registerWith`)부터 `DropTarget` 유무·`enable`과 무관하게 항상 켜져 있어, (b)처럼 보드 밖에 놓으면 브라우저 기본 동작만 막히고 **아무 반응도 없는** 상태가 됨 | "어디에 넣을지"가 모호 → 대상 규칙이 필요. 노트 편집 중 실수 드롭 가능 |
| (b) 노트 보드(`DocumentsScreen`)만 | 의도가 명확 | 데스크톱 Projects 탭·편집기 열린 상태에서 꺼짐(`main.dart:346`, `Offstage`). `DropTarget.enable`을 직접 관리해야 함(주석에 "보이지 않아도 이벤트를 받는다"고 명시) |
| (c) 편집기만 | — | 가장 나쁨: 노트 편집과 PDF 추가가 개념적으로 섞임 |
| (d) Ask 패널만 | "올리고 바로 질문" 흐름 | 개인/프로젝트 선택 문맥이 없음, 폰에서 Ask 탭 |

**추천 (a)**: `HomeShell.build`의 최상위(`OpenItemScope` 바깥 또는 안쪽)에 `DropTarget` 1개 + 전체를 덮는 오버레이 + 하단 상태 바.
- **편집기가 열려 있을 때**: 드롭을 **받습니다**(PDF를 새 문서로 추가, 편집기·미저장 내용은 건드리지 않음). 웹 실험에서 TextField 위 드롭도 같은 경로로 들어옵니다 ✅. 무시하면 오히려 브라우저가 PDF를 열어 버리므로(핸들러가 있어도 우리가 버리면 아무 반응이 없어 혼란) 받는 쪽이 안전합니다.
- **진행 표시는 전역**이어야 합니다: 데스크톱에서 노트를 열면 보드가 `Offstage`라 현재 `LinearProgressIndicator`(`:444`)가 안 보입니다.
- **세 레이아웃 모두 같은 `DropTarget`이 덮습니다.** 분기는 기기 종류가 아니라 창 폭(`main.dart:269-321`)이므로 데스크톱 Chrome을 900px(레일)·500px(하단 `NavigationBar`)로 줄여도 실제 드롭이 옵니다. 전역 상태 바·스낵바는 <600px 레이아웃의 하단 `NavigationBar`(`:293-306`)와 겹치지 않게 그 위쪽에 둡니다. 순수 모바일 브라우저·앱에는 파일 드래그가 없어 코드가 있어도 무해하고, 기존 FAB·버튼이 대체 경로입니다.

**대상 프로젝트 규칙 (추천안)**

| 조건 | 동작 |
|---|---|
| 프로젝트 0개 | 시트 없이 **개인(My cloud)** 로 바로 업로드 (`_openNote`와 동일 규칙, `:187`) |
| 프로젝트 ≥1개 | **드롭당 1회** 기존 `_chooseTier` 시트(제목에 "PDF N개" 표시). 취소하면 전체 취소 |
| (후속 옵션) | 오버레이에 구역 카드("내 클라우드" / 프로젝트별)를 그려 **놓은 위치로 대상 결정**(`onDragUpdated`/`onDragDone`의 `localPosition` 사용, 약 +100줄) → 클라이언트 원문의 "적절한 구역"에 가장 가까움 |

"마지막으로 쓴 대상 기억"은 viewer 프로젝트가 걸리면 매번 실패하므로 권한 정보(클라이언트에 역할 없음)부터 필요 → 이번 범위 밖.

### 4. 상태 기계와 오류 케이스

```text
idle
 └─ onDragEntered ─▶ dragging (오버레이 표시, 문구: "PDF를 여기에 놓아 추가")
     ├─ onDragExited(+150ms) / 400ms 무신호 ─▶ idle
     └─ onDragDone ─▶ validating
          ├─ 유효 0개 ─▶ idle + 스낵바 (이유별 메시지)
          └─ 유효 ≥1 ─▶ choosingTier(프로젝트 ≥1일 때만)
               ├─ 취소 ─▶ idle
               └─ 선택 ─▶ queued ─▶ uploading(파일별 순차: 읽기→추출→upload→원본 저장)
                    ├─ 파일별 성공/실패/건너뜀 기록
                    └─ 모두 끝 ─▶ summary(스낵바 1개) ─▶ idle  (+ boardRefresh, 새 카드 강조는 선택)
```

| 케이스 | 처리 |
|---|---|
| 비 PDF만 | "PDF만 올릴 수 있어요" (파일명 최대 1개 표기) |
| 일부 비 PDF | 유효 파일만 진행, 요약에 "N개 건너뜀" |
| 폴더 | "폴더는 지원하지 않아요" (내부 파일을 펼치지 않음, 단순화) |
| 개수 상한 | 제안: 드롭당 **10개**, 초과분 건너뜀 안내 ⚠️ 값은 결정 필요 |
| 파일 크기 | 현재 상한 없음. 제안: **50 MB** 초과 경고 ⚠️ 값은 결정 필요(웹 메모리: 바이트 + PDFium WASM 복사본) |
| 같은 파일(해시) 중복 | **업로드 전** `documentsNotifier.value`에서 `contentHash`+`projectId` 비교(서버 변경 불필요) → "이미 있어요" 건너뜀. 같은 드롭 안의 중복도 제거 |
| 텍스트 추출 결과가 모두 빈 값 | 업로드는 하되 "텍스트가 없어 검색되지 않아요(스캔 PDF)" 경고 — 현재는 조용히 `ready` |
| 암호 PDF / 손상 PDF | 예외 분류 → "열 수 없는 PDF" (원문 예외 노출 금지) |
| 텍스트 JSON > ~500 KiB | 추출 후 직렬화 크기를 **사전 점검**해 "너무 커서 색인할 수 없어요"로 조기 실패(서버 오류 문구 대신). 근본 해결은 서버 청크 업로드(범위 밖) |
| 권한(viewer) | 서버 `AccessDeniedException` → "이 프로젝트에는 올릴 권한이 없어요". 파일 단위 실패, 나머지 계속 |
| 오프라인·네트워크 | 파일 단위 실패 + 요약. 재시도 버튼은 후속 |
| 타임아웃(20초) | `TimeoutException`은 "실패"가 아니라 "서버에서 색인 중일 수 있어요"로 안내하고 보드를 새로고침해 상태 확인. 근본 해결은 `connectionTimeout` 상향(예 120초, `lib/client.dart`) 또는 `upload`를 업로드/색인 2단계로 분리 — 결정 필요 |
| 동시성 | **순차 처리**(동시 1개). 이유: 메모리, 임베딩 제공자 rate limit(`friendlyIndexingError`의 `rate`), 진행 표시 단순화. 이미 진행 중이면 새 드롭은 **큐에 추가** |
| 취소 | 큐에서 대기 중인 파일만 취소(진행 중 파일은 서버 요청이라 중단 불가) |
| 색인 대기 | `upload`가 색인까지 동기로 끝내므로(`_index` 호출) 응답 시점에 `ready/failed`를 알 수 있음 → 별도 폴링 불필요 |

**중복 구현을 피하는 구조 (제안)**

```text
lib/features/documents/pdf_upload_service.dart   // 신규
  Future<UploadReport> uploadPdfs(List<XFile> files, {required int? projectId, ...})
  PdfDropCheck classifyDrops(List<XFile> files, {existing: List<Document>, projectId}) // 순수 함수
  final uploadState = ValueNotifier<UploadState>(...)  // documentsNotifier와 같은 전역 패턴
lib/app/drop_zone.dart                            // 신규: DropTarget + 오버레이 + 상태 바
```

- `documents_screen.dart`의 `_upload`는 `picked.map((f) => f.xFile)`를 같은 `uploadPdfs`에 넘기도록 바꾸고(다중 선택도 자연히 해결), `_busy`·`LinearProgressIndicator`는 `uploadState`를 구독하게 합니다.
- 스낵바는 화면 State의 `context`가 아니라 **`MaterialApp`의 `scaffoldMessengerKey`** 로 띄워야 화면이 사라져도 안전합니다(`main.dart:30`의 `MaterialApp`에 키 추가).
- 기존 `_storeOriginal`, `extractPages`, `contentHash`, `LocalPdfs.save`를 **그대로 재사용**합니다.

### 5. 테스트 전략

| 가능 (위젯/단위 테스트) | 불가능·수동 |
|---|---|
| **순수 함수** `classifyDrops`: PDF/비 PDF/폴더/대소문자/개수·크기 상한/중복 해시/혼합 | OS 드래그 이벤트 자체(Finder→창) |
| `DropTarget` 자체를 **채널 메시지 주입**으로 구동: `desktop_drop` MethodChannel에 `entered`/`exited`/`performOperation`을 `defaultBinaryMessenger.handlePlatformMessage`로 보냄 → 오버레이 표시·숨김, `onDragDone` 파일 전달 ✅ scratchpad에서 통과 확인 | 브라우저 DOM 이벤트(웹 `window.ondrop`), blob URL 읽기 |
| 가짜 업로더를 주입해 `uploadPdfs` 큐 동작(순차, 일부 실패 요약, 중복 건너뜀, 권한 오류 분류) | 실제 `pdfrx` 추출(네이티브/WASM 필요) — 추출은 `extractPages`를 함수로 주입해 대체 |
| 오버레이 안전 타이머(`fakeAsync`), `enable` 토글 | CanvasKit 위 깜빡임·z-order |
| 반응형: 오버레이가 폭 360/800/1280에서 오버플로 없이 그려짐(기존 `auth_layout_overflow_test.dart` 패턴) | 실제 화면 읽기 프로그램 |

주의: 위젯 테스트에서 채널 메시지를 `await Future.delayed`로 기다리면 `testWidgets`의 fake async에서 **멈춥니다**(실험 중 확인). `pump()`만 쓰세요.

**수동 확인 절차 (Chrome 배포 사이트)**
1. 노트 탭에서 Finder의 PDF 1개를 창 중앙으로 끌기 → 오버레이 표시 확인
2. 창 밖으로 끌고 나갔다 오기, Esc로 취소 → 오버레이가 남지 않는지
3. 드롭 → 카드가 생기고 색인 완료 스낵바
4. 같은 파일 재드롭 → "이미 있어요"
5. 텍스트 파일·폴더·PDF 3개+비 PDF 1개 혼합 드롭
6. 노트 편집기 열고 텍스트 입력 칸 위에 드롭 → 새 PDF 카드만 생기고 노트 내용 불변
7. 프로젝트가 있는 계정에서 시트 표시 / viewer 프로젝트 선택 시 오류 문구
8. 텍스트(링크·선택 영역) 드래그 시 오버레이가 뜨는지 확인 후 허용 여부 판단
9. 오프라인(DevTools Network offline)에서 드롭

### 6. 규모 추정

| 구분 | 파일 | 줄 수(대략) |
|---|---|---|
| 변경 | `pubspec.yaml` (+1) | 1 |
| 변경 | `lib/features/documents/documents_screen.dart` (`_upload`·`_busy` 정리) | −45 / +25 |
| 변경 | `lib/main.dart` (셸에 드롭 존 래핑, `scaffoldMessengerKey`) | +15 |
| 변경 | `lib/app/l10n.dart` (오버레이·요약·오류 문구 약 10~12개, 영/한) ⚠️ 다른 에이전트가 같이 만질 수 있어 충돌 주의 | +30 |
| 신규 | `lib/features/documents/pdf_upload_service.dart` (검증·큐·상태) | 150~200 |
| 신규 | `lib/app/drop_zone.dart` (DropTarget·오버레이·상태 바·안전 타이머) | 120~160 |
| 신규 테스트 | `test/pdf_drop_classify_test.dart`, `test/pdf_drop_zone_test.dart`, `test/pdf_upload_service_test.dart` | 약 8~12개 테스트, 200~250 |
| 후속 옵션 | 구역 카드(놓은 위치로 대상 결정) | +100 |

합계: **제품 코드 약 350~450줄, 변경 4 · 신규 2, 테스트 약 200~250줄 · 8~12개** ⚠️ (추정).

**위험**

| 위험 | 수준 | 완화 |
|---|---|---|
| 웹에서 `dragleave` 깜빡임(요소 경계 통과) | 중 — 실험으로 확인 ✅ | `exited` 지연 + `updated`로 복귀 |
| 취소(창 이탈·Esc) 시 `exited` 미수신 → 오버레이 고착 | 중 ⚠️ 에뮬레이션에서만 확인 | 400 ms 무신호 안전 타이머 |
| 텍스트 드래그에도 오버레이 | 낮음 | 드롭 후 "PDF 없음"으로 처리 |
| `window` 핸들러 단일 슬롯(다른 라이브러리와 충돌) | 낮음 | 현재 다른 사용처 없음(`file_picker_web`은 `<input>` 방식) |
| 중복 오버레이(Ask/편집기가 이미 오버레이를 그림) | 낮음 | 셸 `Stack` 최상단 1개만, `IgnorePointer` |
| 다른 에이전트의 `notes/**`·`theme.dart`·`ask/**` 수정과 충돌 | 낮음 | 본 계획은 해당 경로를 건드리지 않음. 색은 기존 `context.pb` 토큰 사용 |
| 접근성(키보드·스크린 리더) | 중 | 드롭은 보조 수단. 대체 경로는 기존 "PDF 올리기" 버튼(`:358`, `:413`). 오버레이는 `Semantics(liveRegion)`로 상태 안내 |
| macOS 샌드박스 읽기 권한 | 불명 ⚠️ | 실기 확인 후 entitlement 추가 결정 |
| 큰 PDF의 UI 멈춤(추출이 메인 isolate/WASM) | 중 ⚠️ | 파일당 진행 표시 + 크기 경고 |

## 결정이 필요한 선택지

1. **드롭 구역 범위**: (a) 셸 전체(추천) / (b) 노트 보드만
2. **대상 프로젝트**: 0개면 개인 직행 + 1개 이상이면 시트 1회(추천) / 오버레이 구역 카드(놓은 위치로 결정, +100줄)
3. **한도 값**: 드롭당 개수(제안 10), 파일 크기 경고(제안 50 MB), 512 KiB 초과 시 처리(조기 실패 안내 vs 서버 청크 업로드 추가), 클라이언트 `connectionTimeout`(기본 20초) 상향 여부
4. **기존 결함을 함께 고칠지**: 다중 선택 1개만 처리, 스캔 PDF가 `ready`로 보임, viewer 권한 오류의 원문 노출, 중복 시 원본 재업로드
5. **macOS 지원 범위**: 웹만 확인할지, macOS entitlement(`user-selected.read-only`) 추가·검증까지 할지
6. **의존성 추가**: `desktop_drop: ^0.8.4` 승인(추천) 또는 직접 구현 폴백

## 미확인 · 리스크 (⚠️)

- 큰 PDF에서 20초 타임아웃이 실제로 나는지(서버를 띄우지 않아 미실행)
- 실제 사용자 브라우저(Safari·Firefox)에서의 `dragover` MIME 노출·`dragleave` 동작
- 실제 드래그 취소(Esc·창 이탈) 시 오버레이 해제 여부 (CDP 에뮬레이션에서는 `exited`가 오지 않았음)
- `<textarea>`(노트 편집기) 위 드롭: 실험은 단일행 `<input>`으로만 확인
- macOS 앱에서 `desktop_drop`·`file_picker` 동작(샌드박스 entitlement 부재), Windows·Linux 미확인
- 암호 PDF의 실제 예외 경로, 스캔 PDF의 실제 `ready` 표시(소스 판독만)
- 512 KiB 초과 시 서버가 돌려주는 실제 오류 형태(HTTP 상태·문구)와 한글 문서 기준 페이지 환산
- 줄 수·테스트 수 추정치

## 출처

- 코드: `~/.pub-cache/.../serverpod_client-4.0.4/lib/src/serverpod_client_shared.dart`, `app/pageblink_flutter/lib/client.dart`, `app/pageblink_flutter/lib/features/documents/documents_screen.dart`, `.../documents/pdf_text.dart`, `.../app/local_pdfs.dart`, `.../app/l10n.dart`, `.../main.dart`, `app/pageblink_server/lib/src/rag_endpoints/document_endpoint.dart`, `app/pageblink_server/config/{development,staging,production}.yaml`, `app/pageblink_flutter/macos/Runner/*.entitlements`, `docs/adr/003-pdf-extract-on-client.md`
- `desktop_drop` 0.8.4 소스(`lib/desktop_drop_web.dart`, `lib/src/channel.dart`, `lib/src/drop_target.dart`, pubspec): https://pub.dev/packages/desktop_drop , https://pub.dev/packages/desktop_drop/versions
- https://pub.dev/packages/super_drag_and_drop
- https://pub.dev/packages/flutter_dropzone
- `file_picker` 13.1.0 / `file_picker_platform_interface` 4.2.0 / `cross_file` 0.3.5+5 / `pdfrx_engine` 0.6.1 소스 (pub 캐시)
- https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/Drag_data_store
- https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/File_drag_and_drop
- 실험: Flutter 3.47.7 · Dart ^3.12.2 · headless Chrome(CDP `Input.dispatchDragEvent`) · scratchpad (삭제됨)
