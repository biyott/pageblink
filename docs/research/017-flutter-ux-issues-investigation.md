# 017 · Flutter 앱 UX 이슈 6건 조사 (설정 화면 · 노트 편집 · 라이브 마크다운 · 아이콘 · 문구)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 09:30 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용 · 코드 수정 없음) |
| 질문 | `app/pageblink_flutter/lib`에서 ① 설정이 전체화면으로 열리는 이유와 최소 변경안 ② 노트 편집 시 본문이 동그랗게 보이는 원인 ③ 라이브 마크다운 에디터 구현안·서식 툴바 위치 ④ 눈 아이콘의 용도 ⑤ "새 채팅" 문구 ⑥ 아이콘 사용 현황 |
| 결론 한 줄 | ① 설정만 `Navigator.push`로 루트 라우트에 올려 전체화면 · ② 테마의 `enabledBorder`(반경 999 pill) + `filled`가 `border: InputBorder.none`을 덮어써 포커스 전 본문 필드가 동그란 pill로 그려짐 · ③ 현 저장 포맷이 markdown 문자열이라 `TextEditingController.buildTextSpan` 방식(①)이 왕복 100% · ④ 눈 = 편집↔미리보기 토글 · ⑤ 라벨은 "새 대화"이고 실제 동작은 화면의 Q&A 목록 비우기 · ⑥ Material `Icons.*` 67곳 하드코딩, 래퍼 없음 |
| 반영 | 없음 (결정 대기 · 필요 시 ADR) |

> 표기: ✅ 코드·pub.dev로 확인 · ⚠️ 미확인/추정. 경로는 `app/pageblink_flutter/lib/` 기준. **빌드·실행은 하지 않았으므로 시각적 증상은 정적 분석으로만 확정**했습니다.

---

## 핵심 결론

| # | 이슈 | 결론 | 변경 규모 |
|---|---|---|---|
| 1 | 설정 전체화면 | `main.dart:203`, `:447`이 `Navigator.push(MaterialPageRoute(SettingsScreen))`. 다른 기능은 `OpenItem` 계열(`openItem()`)로 열림. `OpenItem.settings` 변종을 추가해 같은 경로로 열면 됨 | 4~5개 파일 |
| 2 | 본문이 원 모양 | ✅ 확정(정적 분석): `theme.dart:274-277` `enabledBorder` radius 999 + `filled: true`가 `note_editor_screen.dart:220` `border: InputBorder.none`을 이김. `expands: true`라 큰 타원/pill로 보임 | 1개 파일(2곳) |
| 3 | 라이브 마크다운 | 추천 ①: 기존 TextField + 커스텀 컨트롤러 `buildTextSpan` (패키지 추가 0, 왕복 100%). 툴바는 데스크톱에서 상단 고정 + 단축키 | 신규 1 + 수정 1~2 |
| 4 | 눈 아이콘 | `note_editor_screen.dart:155-161` 편집 중엔 눈(미리보기로), 미리보기 중엔 연필(편집으로). 라벨 달린 `SegmentedButton`으로 교체 제안 | 1개 파일 |
| 5 | 새 채팅 문구 | `l10n.dart:332` `newChat` = `New conversation` / `새 대화`. 동작은 `_turns.clear()`(서버 대화 기억 없음). 후보: 새 질문 / 답변 지우기 / 처음부터 | 2개 파일 |
| 6 | 아이콘 | 전부 Material `Icons.*` (9개 파일 · 67회 · 38종). `AppIcons` 같은 래퍼 없음 | 래퍼 도입 시 10개 파일 |

---

## 상세

### 1. 설정이 전체화면으로 열림

**다른 기능이 열리는 방식 ✅**

| 요소 | 위치 | 역할 |
|---|---|---|
| `OpenItem` (노트/인용 변종) | `app/open_item_controller.dart:9-25` | 열린 항목 모델. `isNote` 게터(`:24`)는 `citation == null`이면 노트로 취급 |
| `OpenItemController.open/close` | `app/open_item_controller.dart:46-58` | 중앙 pane에 항목을 올리고(저장 flush 후) 닫음. `wide`(`:34`)는 `width >= 600`일 때 `main.dart:234`에서 세팅 |
| `openItem(context, item)` | `features/open_item/open_item_view.dart:16-29` | `controller.wide`면 `controller.open`(pane), 아니면 `Navigator.of(context).push(OpenItemPage)` (탭 네비게이터, 하단 바 유지) |
| `OpenItemView` 분기 | `features/open_item/open_item_view.dart:46-75` | `citation == null` → `NoteEditorView`, `kind == 'note'` → `_CitedNote`, 그 외 → `PdfPageView` |
| `OpenItemPane` | `features/open_item/open_item_view.dart:155-185` | 유리 패널 + Esc 닫기(`:166-169`) |
| `PaneHeader` | `app/pane_header.dart:9-72` | embedded면 `← Notes / 제목` + 닫기(`:38-46`, `:62-67`), 아니면 뒤로 화살표 |
| 쉘 | `main.dart:171-191` `_withPane`, `:277-283` `guard` | pane을 base 위에 겹침, 뒤로가기는 pane 먼저 닫음 |

**설정이 다른 이유 ✅**

- `main.dart:200-207` (AppBar 설정 아이콘, 폰·태블릿)과 `main.dart:443-451` (데스크톱 사이드바 `_NavItem`)이 **`Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))`** 를 직접 호출합니다.
- `SettingsScreen`은 자체 `Scaffold` + `AppBar`(`settings_screen.dart:17-18`)를 가진 독립 페이지입니다. `OpenItem`을 거치지 않으므로 pane도, `guard`도, Esc도 적용되지 않습니다.
- AppBar 쪽 `context`는 `HomeShell.build`의 컨텍스트이고 `OpenItemScope`보다 **위**에 있어(`main.dart:216`) `OpenItemScope.maybeOf`가 null을 반환합니다. 그래서 폰에서는 루트 `Navigator`에 올라 하단 `NavigationBar`까지 덮습니다. (논리적 추론 ✅, 실행 확인 ⚠️)
- 데스크톱 사이드바의 `_NavItem`은 `OpenItemScope` 아래이므로 `openItem(context, ...)`가 동작합니다.

**최소 변경안**

| 파일 | 위치 | 변경 |
|---|---|---|
| `app/open_item_controller.dart` | `:9-25` | `OpenItem.settings()` 생성자 + `bool get isSettings`. `isNote`(`:24`)는 `!isSettings && (citation == null \|\| ...)`로 보정 |
| `features/open_item/open_item_view.dart` | `:46-49` | `if (item.isSettings) return SettingsView(embedded:, onClose:)`를 `citation == null` 분기보다 **앞에** 둠 |
| `features/settings/settings_screen.dart` | 전체 | `Scaffold/AppBar` → `Column(PaneHeader(...), Expanded(ListView(...)))`. 로그아웃(`:57-60`)의 `Navigator.pop(context)`는 pane 모드에서 루트 라우트를 팝할 수 있으므로 `onClose` 호출로 교체(또는 제거: 로그아웃하면 `HomeShell`이 사라짐 ⚠️ 동작 확인 필요) |
| `app/pane_header.dart` | `:42` | (선택) `backLabel` 파라미터. 현재 embedded 헤더의 `l.tabNotes`가 하드코딩이라 설정에서 `← Notes / Settings`로 읽힘 |
| `main.dart` | `:203`, `:447` | 사이드바: `openItem(context, OpenItem.settings())`. AppBar(`:203`): `wide`면 `_open.open(OpenItem.settings())`, 폰이면 `_openInNotesTab`(`:113-121`)와 같은 방식으로 `_navKeys[_tab].currentState?.push(MaterialPageRoute(builder: (_) => OpenItemPage(item: ...)))` |

**동작 (변경 후)**

| 레이아웃 | 동작 |
|---|---|
| 데스크톱 ≥1024 | 가운데 pane에 설정이 열리고 사이드바·Ask 패널 유지. Esc/뒤로가기로 닫힘 (`:166-169`, `:277-283`). 사이드바 탭 전환 시 `_select`(`:124-127`)가 닫음 |
| 태블릿 600~1023 | rail 유지, `Expanded` 영역에 pane (`:349-355`) |
| 폰 <600 | 현재 탭 네비게이터에 push → 하단 바 유지, `deep`(`:239`)이 true라 AppBar 숨김 + `PaneHeader` 뒤로 화살표 |

부수 발견: 로그아웃 진입점이 3곳(`main.dart:208-212`, `:488-492`, `settings_screen.dart:54-61`)입니다. 설정을 pane에 넣으면 사이드바 하단 로그아웃과 중복이 더 눈에 띕니다.

### 2. 노트 편집 시 본문이 동그란 모양

**증상 재현 경로 ✅**

1. 기존 노트를 열면 `_preview = widget.note != null`(`note_editor_screen.dart:47`)이 true → 미리보기로 시작.
2. 연필(편집) 버튼 → `_preview = false`(`:160`) → 본문 `TextField`(`:211-222`)가 그려짐.
3. `autofocus: widget.note == null`(`:213`)이라 **기존 노트는 포커스 없이** 나타남 → "unfocused" 경로 → 동그란 모양. (새 노트는 autofocus라 포커스 경로 → 정상)

**root cause ✅ (정적 분석)**

| 근거 | 위치 |
|---|---|
| 앱 테마가 모든 입력 필드를 `filled: true`, `fillColor: glassStrong`으로 설정 | `app/theme.dart:267-269` |
| `border`와 `enabledBorder` 모두 `OutlineInputBorder(borderRadius: circular(999))` | `app/theme.dart:270-277` |
| 본문 필드는 `border: InputBorder.none`만 지정 (`enabledBorder`/`focusedBorder`/`filled`는 안 건드림) | `note_editor_screen.dart:218-221` |
| `expands: true`로 필드가 영역 전체를 채움 | `note_editor_screen.dart:215` |
| Flutter는 `InputDecoration.applyDefaults`에서 `enabledBorder: enabledBorder ?? theme.enabledBorder`로 테마 값을 채움. 포커스 안 된 상태는 `decoration.enabledBorder`를, 포커스 상태는 `focusedBorder`(없으면 `border`)를 사용 | Flutter 3.32.2 SDK `input_decorator.dart` `applyDefaults`, `:2303-2310`; 배경은 `border.getOuterPath`로 칠함(`:131-132`) |
| 반경 999는 큰 사각형에서 스케일되어 사실상 큰 타원/stadium | `OutlineInputBorder.getOuterPath` → `RRect` |

즉 **포커스 전**에는 테마의 pill 테두리 + 반투명 흰 채움이, 본문 전체 영역에 그려져 "동그라미"처럼 보입니다. 필드를 탭하면 `border: none`(사각형)으로 바뀝니다. 제목 필드(`:191-198`)도 같은 원인으로 pill이지만 높이가 낮아 입력창처럼 자연스럽게 보입니다.

- ⚠️ 로컬에는 Flutter 3.32.2 SDK만 있어 `.fvmrc`의 3.47.7(`pageblink/.fvmrc`) 소스로는 직접 확인하지 못했습니다. 이 로직은 오래된 안정 동작이라 동일할 가능성이 높지만 미검증입니다.
- ✅ 같은 앱에서 이미 올바른 선례: `ask_screen.dart:217-227`이 `filled: false` + `border/enabledBorder/focusedBorder: InputBorder.none`을 모두 지정.

**후보 순위**

| 순위 | 후보 | 판단 |
|---|---|---|
| 1 | 테마 `enabledBorder`(999) + `filled` 전역 설정이 `InputBorder.none`을 덮음 | ✅ 확정 |
| 2 | `GptMarkdown`의 불릿/체크박스 렌더링 (미리보기 모드) | 증상이 "편집 버튼 클릭 후"라 해당 없음. `GptMarkdown`은 `note_editor_screen.dart:206`에서 편집 모드가 아닐 때만 사용 ✅ |
| 3 | `CircleAvatar`/`ListTile`/`Checkbox` | note_editor 안에 없음 ✅ (`grep` 결과 `ListTile`은 settings/projects/documents에만 존재) |

**확인 방법**: 기존 노트 열기 → 연필 → 본문 영역을 탭하기 전/후 모양을 비교 (탭 후 사각형이면 확정). 또는 `TextField` 한 줄 추가 후 비교.

**수정안**: `note_editor_screen.dart`의 두 `TextField`(`:194-197`, `:218-221`)에 `filled: false`, `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none`을 추가하고 `contentPadding: EdgeInsets.zero`로 맞춥니다 (`ask_screen.dart:217-227` 선례). 변경 1개 파일. 대안(테마 전체 변경)은 검색창·프로젝트 다이얼로그(`documents_screen.dart:306-320`, `projects_screen.dart:24`) 영향이 있어 비추천.

### 3. 라이브 마크다운 에디터

**현재 구현 ✅**

| 항목 | 값 | 위치 |
|---|---|---|
| 편집 | 평문 `TextField` + `TextEditingController _body`(마크다운 문자열 그대로) | `note_editor_screen.dart:46`, `:211-222` |
| 미리보기 | `GptMarkdown(_body.text)` | `note_editor_screen.dart:206` |
| 서식 툴바 | 하단 가로 스크롤 `Row` 7개 버튼, `!_preview`일 때만 | `note_editor_screen.dart:225-273` |
| 서식 삽입 | `_wrap`(`:102-115`), `_linePrefix`(`:118-129`): 문자열 삽입. 헤딩은 항상 `## `(`:237`), 토글/교체 없음 → 두 번 누르면 `## ## `이 됨 |
| 저장 | `client.document.saveNote(id, title, body, projectId)`로 **markdown 문자열 그대로** 저장, 서버가 색인 | `note_editor_screen.dart:78-83`, 주석 `:10-11` |
| 의존성 | `gpt_markdown: ^1.3.4`, `google_fonts`, `pdfrx` 등. 에디터 패키지 없음. `pubspec.yaml`의 SDK `^3.12.2`, Flutter `^3.44.4`, `uses-material-design: true` | `pubspec.yaml` |
| 웹 지원 | `kIsWeb` 분기 존재 → 웹도 대상 | `app/local_pdfs.dart:21`, `:45` |

저장 포맷이 markdown 문자열이고 서버가 그 텍스트로 색인하므로, **에디터가 문자열을 바꾸지 않고 유지하는 것**이 가장 중요한 제약입니다.

**구현 방안 비교**

| 기준 | ① TextField + `buildTextSpan` | ② 에디터 패키지 | ③-a 분할 보기 / ③-b 블록별 렌더 |
|---|---|---|---|
| 개요 | `TextEditingController`를 상속해 `buildTextSpan`에서 줄별 정규식으로 `TextSpan` 스타일링(헤딩 크기/굵게/기울임/코드/인용/목록 기호). 마커는 흐리게 표시 | flutter_quill, appflowy_editor, super_editor 등 문서 모델 기반 에디터 | ③-a: 데스크톱 폭에서 좌 소스 / 우 `GptMarkdown`. ③-b: 커서가 있는 블록만 TextField, 나머지는 렌더 |
| 노력 | 소(⚠️ 추정 150~250줄, 파일 1개 + `note_editor_screen.dart` 수정) | 중~대 (모델 변환, 툴바·단축키 재작성, 테마 맞춤) | ③-a 소(~30줄) / ③-b 대 |
| 위험 | 낮음~중. 아래 제약 참조 | 중~높음 (아래) | ③-a 낮음 / ③-b 높음 (블록 간 선택·캐럿 이동) |
| 마크다운 왕복 | **100%** (문자열을 변형하지 않고 표시만 다르게) | 패키지별 상이, 손실 가능 | ③-a 100% / ③-b 100% |
| "입력 중 즉시 서식" | 부분적 (마커는 보임, 크기·굵기는 적용) | 예 (마커 숨김) | ③-a 아니오 / ③-b 예 |

**① 제약 (구현 시 주의)**
- `buildTextSpan`이 반환하는 span의 전체 텍스트는 `value.text`와 **정확히 같아야** 합니다(IME composing·선택 오프셋 보존). 따라서 마커 문자를 지워서 숨길 수 없고 흐리게만 표시할 수 있습니다. `WidgetSpan`(체크박스 위젯 등)은 길이 규칙을 깨므로 불가 ⚠️(Flutter 일반 동작, 이 저장소에서 미검증).
- 한글 IME composing 중 스타일 스팬이 깜빡일 수 있어 composing 구간이 있으면 평문 스팬으로 대체하는 안전장치 권장. 실제 기기 검증 필요 ⚠️.
- 소스/라이브 전환은 컨트롤러 플래그 하나로 처리 (같은 문자열, 스타일만 on/off).

**② 패키지 현황 (pub.dev API 2026-10-15 조회)**

| 패키지 | 최신 | 발행일 | SDK 제약 | 마크다운 | 상태 |
|---|---|---|---|---|---|
| `flutter_quill` | 11.6.0 | 2026-09-16 | Dart ^3.12.0 / Flutter >=3.44.0 ✅ 현 프로젝트와 호환 | 문서 모델은 Delta. 변환은 별도 `markdown_quill` 4.3.0 (2025-03-08) 또는 내장 `markdown` 의존 | 유지보수 활발, 150/160점. pub 플랫폼 태그에 `platform:web`이 **없음** ⚠️ (README는 웹 지원 표기) |
| `appflowy_editor` | 6.2.0 | 2025-12-08 | Dart >=3.6.0 / Flutter >=3.32.0 ✅ | `markdown` 의존, 마크다운 인코드/디코드 내장 (⚠️ API 미확인) | 60/160점 + `has:error`, 라이선스 태그 MPL-2.0·AGPL-3.0 혼재 ⚠️ 확인 필요 |
| `super_editor` | 0.2.7 (안정) / 0.3.0-dev.52 (2026-06-11) | 안정판 2024-06-11 | Dart >=3.0.0 | 별도 `super_editor_markdown` 0.2.2 (2025-11-15) | 안정판이 오래됨, 개발판(dev) 사용 필요 ⚠️. 60/160점 + `has:error` |
| `fleather` | 1.28.0 | 2026-08-24 | Dart >=3.6.0 ✅ | 마크다운 변환 패키지 미확인 ⚠️ | 160/160점, 웹 포함 |
| `markdown_editor_live` | 0.6.0 | 2026-03-21 | Dart ^3.9.2 ✅ | WYSIWYG 마크다운 | 좋아요 7, 신생 ⚠️ 품질·왕복 미검증 |

- 공통 위험: 패키지 모델(Delta/Document)에서 markdown으로 **직렬화할 때 손실·정규화**(표·중첩 목록·HTML·공백)가 생길 수 있고, 저장할 때마다 본문이 달라지면 서버 재색인과 diff가 흔들립니다 (⚠️ 실제 손실 범위는 미실험).
- ✅ 위 호환 판정은 pub.dev의 SDK 제약 필드 기준이며, 실제 `pub get`/빌드는 하지 않았습니다 ⚠️.

**추천: ① + (선택) ③-a**
- 이유: 저장 포맷 변경 없음(왕복 100%), 의존성 0, 웹/모바일 동일, 되돌리기 쉬움. 마커를 숨기지 못하는 점은 "Typora급"은 아니지만 "헤딩이 커 보이고 굵게는 굵게 보이는" 단계까지는 충분.
- 전환 버튼: 편집 모드 안에서 `라이브 ↔ 소스` 토글(같은 `TextField`). 읽기(미리보기)는 지금처럼 `GptMarkdown`.
- 더 완전한 Obsidian식(마커 숨김)이 필요하면 별도 스파이크로 `flutter_quill` + `markdown_quill` 왕복 테스트(표·중첩 목록 포함)를 먼저 하는 것을 권장.

**PC 서식 툴바 위치 방안**

| 방안 | 내용 | 노력 | 비고 |
|---|---|---|---|
| A. 상단 고정 (추천) | 제목 아래/본문 위에 같은 `Row`를 배치. `embedded`/`wide`일 때만 상단, 폰은 키보드 위 하단 유지(`main.dart:257-258` 주석이 그 의도) | 소 (`note_editor_screen.dart:225-273` 블록을 위치 이동 + 조건) | 헤딩은 `PopupMenuButton`으로 H1/H2/H3 선택, `_linePrefix`를 교체형으로 개선 |
| B. 선택 시 플로팅 | `TextField.contextMenuBuilder`에 서식 항목 추가 (우클릭/선택 메뉴) 또는 캐럿 위치에 오버레이 | 중 (메뉴 항목) ~ 대 (캐럿 앵커 오버레이) | 선택 없이는 안 보여 발견성이 낮음 ⚠️ |
| C. 우측 사이드 레일 | 에디터 오른쪽 세로 `IconButton` 열 | 소 | 가운데 pane 폭(`main.dart:310` maxWidth 1100) 안에서 공간은 충분. 마우스 이동거리는 A보다 큼 |
| (병행) 단축키 | `Ctrl/Cmd+B`, `I`, `K` 등을 `CallbackShortcuts`로 | 소 | 이미 `OpenItemPane`이 `CallbackShortcuts`를 사용(`open_item_view.dart:166-169`) |

### 4. 눈 모양 아이콘

| 항목 | 값 |
|---|---|
| 위치 | 노트 편집기 헤더 `PaneHeader.actions` 첫 번째 버튼, `note_editor_screen.dart:155-161` (저장 체크 `Icons.check`는 `:171-175`) |
| 용도 | `_preview`를 토글. **편집 중**에는 눈(`Icons.visibility_outlined`, tooltip `미리보기`)이 보이고 누르면 렌더 보기, **미리보기 중**에는 연필(`Icons.edit_outlined`, tooltip `편집`). 문자열은 `l10n.dart:78-79` |
| 혼동 요인 | 눈은 "현재 상태"가 아니라 "다음 동작"을 표시. 툴바 버튼(`_wrap`/`_linePrefix`)이 `_preview=false`로 강제 전환(`:114`, `:128`). 바로 옆 `check`는 "저장하고 닫기"라 의미가 겹쳐 보임 |
| 다른 눈 아이콘 | `documents_screen.dart:226` `Icons.visibility_off_outlined` = 저장 위치 선택의 Cloak(기기 전용, 비활성) 항목. 편집/미리보기와 무관 |

**제안**: 헤더 `actions`의 아이콘 버튼을 `SegmentedButton<bool>`(편집 · 미리보기, 라벨 포함, `visualDensity: compact`)로 교체. 문자열은 기존 `l.edit`/`l.preview` 재사용(신규 l10n 없음). 폰 폭이 좁으면 아이콘만 + tooltip. ③ 라이브 에디터를 도입하면 세그먼트를 `읽기 | 라이브 | 소스` 3단으로 확장(신규 문자열 2~3개). 변경 1개 파일(`note_editor_screen.dart`).

### 5. "새 채팅" 문구

| 항목 | 값 |
|---|---|
| 문자열 | `l10n.dart:332` `String get newChat => _t('New conversation', '새 대화');` ✅ `새 채팅`이라는 문자열은 저장소에 없음 (grep 확인). 가장 가까운 것이 `새 대화` |
| 사용처 | 단 1곳: `ask_screen.dart:162` `IconButton(tooltip: context.l.newChat, icon: Icons.edit_outlined)` — 연필 아이콘의 **툴팁** |
| 노출 조건 | `wideHeader = width >= 1024`(`ask_screen.dart:144`, `:147`)일 때만. 폰·태블릿에는 버튼 자체가 없음 |
| 실제 동작 | `onPressed: _turns.isEmpty ? null : () => setState(() => _turns.clear())` (`:163-165`). 화면의 Q&A 목록만 비움 |
| 서버 측 | 질문마다 독립 호출: `client.ask.ask(question, projectIds, includePersonal, modelId, locale)` (`ask_screen.dart:86-93`), 서버 시그니처에도 대화 이력 파라미터 없음 (`pageblink_server/lib/src/rag_endpoints/ask_endpoint.dart:19-26`) → **대화 맥락/기억이 없음, 저장도 안 됨** |
| 부수 발견 | 비우기가 진행 중 스트림을 취소하지 않음: `_subscription`은 `dispose`에서만 cancel(`:67`), 새 질문 시 덮어씀(`:86`). 스트리밍 중 비우면 이전 스트림이 계속 실행됨 (`_streaming`(`:73`)이 false로 보여 재질문 가능) |
| 아이콘 충돌 | 연필(`edit_outlined`)이 노트 편집기에서는 "편집"(`note_editor_screen.dart:158`)을 뜻함 |

**용어 규칙 대조**: `docs/plan/004-naming-and-feature-vocabulary.md`는 제품 이름과 기능 용어(Cloak, Warp Gate, Recall, Shared Vision, Ping, Blink, Fog of War, Minimap — §4)를 다루며 "새 대화/채팅/비우기" 항목은 없음 ✅. 앱 내 기존 어휘는 탭 `Ask`/`질문`(`l10n.dart:41`), `새 노트`(`:93`), `새 프로젝트`(`:56`). 이 앱은 챗봇이 아니라 "노트·문서에 묻고 출처를 확인"하는 도구라 chat/conversation은 제품 어휘와도 어긋남.

| 순위 | EN | KO | 근거 |
|---|---|---|---|
| 1 (추천) | New question | 새 질문 | `새 노트`/`새 프로젝트` 패턴과 일치, Ask 탭 어휘와 정합. 동작에 입력창 포커스를 같이 주면 의미가 완전해짐 |
| 2 | Clear answers | 답변 지우기 | 동작에 가장 정확(저장 안 되는 목록 비우기). 파괴적 뉘앙스 |
| 3 | Start over | 처음부터 | 중립적, 아이콘 `restart_alt` 계열과 어울림 |

아이콘도 `edit_outlined` 대신 `Icons.add_comment_outlined`/`Icons.restart_alt` 등으로 교체 권장 (⚠️ 아이콘 이름은 Flutter Icons 카탈로그 기준, 저장소에서 미사용). 폰/태블릿에서도 쓰려면 `wideHeader` 조건 완화 필요. 변경: `l10n.dart` + `ask_screen.dart` 2개 파일.

### 6. 아이콘 사용 현황

**소스 ✅**: 전부 Flutter 내장 Material Icons (`pubspec.yaml`의 `uses-material-design: true`). 커스텀 SVG/이미지 아이콘 없음(assets는 `assets/config.json`뿐). `cupertino_icons: ^1.0.5`는 선언만 있고 `CupertinoIcons` 사용은 0건 ✅ (미사용 의존성). 브랜드 마크는 텍스트 이모지 `⚡`(`main.dart:198`, `sign_in_screen.dart:275`, `ask_screen.dart:284` 등)와 `Icons.bolt`를 병용.

**집계**: `Icons.*` 67회 · 38종 · 9개 파일 (`grep` 전수).

| 파일 | 대표 아이콘 |
|---|---|
| `main.dart` | `bolt`/`bolt_outlined`, `sticky_note_2(_outlined)`, `groups(_outlined)`, `settings_outlined`, `logout`, `cloud_outlined`, `shield_outlined` |
| `app/pane_header.dart` | `arrow_back`(2), `close` |
| `features/ask/ask_screen.dart` | `bolt`(3), `edit_outlined`, `arrow_upward`, `copy_outlined`, `cloud_outlined`, `groups_outlined`, `keyboard_arrow_down` |
| `features/documents/documents_screen.dart` | `picture_as_pdf_outlined`(2), `cloud_outlined`(2), `groups_outlined`(2), `error_outline`(2), `add`, `edit_note`, `refresh`, `search`, `sticky_note_2_outlined`, `sync_problem`, `upload_outlined`, `visibility_off_outlined` |
| `features/notes/note_editor_screen.dart` | `title`, `format_bold`, `format_italic`, `format_list_bulleted`, `check_box_outlined`, `format_quote`, `code`, `visibility_outlined`, `edit_outlined`, `check` |
| `features/projects/projects_screen.dart` | `group_add_outlined`, `groups_outlined`, `person_add_alt` |
| `features/settings/settings_screen.dart` | `logout` |
| `features/viewer/citation_sheet.dart` | `chevron_left`, `chevron_right`, `picture_as_pdf_outlined`, `sticky_note_2_outlined` |
| `screens/sign_in_screen.dart` | `bolt`(2), `groups_outlined`, `shield_outlined`, `sticky_note_2_outlined` |

**교체 구조 ✅ 없음**: `AppIcons` 등 래퍼 grep 0건. 의미가 같은 아이콘이 파일마다 흩어져 있음 (예: `groups_outlined` 8회/5개 파일, `bolt` 7회/3개 파일, `sticky_note_2_outlined` 5회, `picture_as_pdf_outlined` 3회). 부분 집중화는 `main.dart:129-143` `_destinations` 레코드 한 곳뿐이고 다른 곳은 `Icons.x`를 직접 씀.

**제안**: `app/app_icons.dart`에 `abstract final class AppIcons { static const note = Icons.sticky_note_2_outlined; ... }` 형태로 의미 단위 상수(note, pdf, project, cloud, cloak, ask, settings, signOut, edit, preview, back, close …)를 두고 호출부를 치환. `IconData`는 const라 `material_symbols_icons`/`phosphor_flutter` 같은 패키지로 교체할 때도 이 파일만 바꾸면 됨. 변경: 신규 1 + 기존 9개 파일 약 67곳 기계적 치환. 이 이슈 단독으로는 우선순위가 낮고, ①~⑤ 수정 때 같이 하면 비용이 작음.

---

## 변경 규모 요약

| # | 수정 파일 | 개수 |
|---|---|---|
| 1 | `open_item_controller.dart`, `open_item_view.dart`, `settings_screen.dart`, `main.dart` (+ 선택: `pane_header.dart`) | 4~5 |
| 2 | `note_editor_screen.dart` | 1 |
| 3 | 신규 컨트롤러 1 + `note_editor_screen.dart` (+ 툴바 이동 시 같은 파일) | 2 |
| 4 | `note_editor_screen.dart` (3과 동일 파일) | 1 |
| 5 | `l10n.dart`, `ask_screen.dart` | 2 |
| 6 | 신규 `app_icons.dart` + 9개 파일 | 10 |

권장 순서: 2(1파일, 즉효) → 4 → 5 → 1 → 3 → 6.

## 미확인 · 리스크

- ⚠️ 빌드·실행·스크린샷 미수행. 2번 root cause는 SDK 소스(3.32.2) 정적 분석이며 `.fvmrc`의 3.47.7과 다를 수 있음.
- ⚠️ 1번 폰 AppBar 경로의 `OpenItemScope.maybeOf == null`은 위젯 트리 위치 기반 추론, 실행 미확인.
- ⚠️ 로그아웃 시 `HomeShell` 소멸 여부(설정 pane에서 `Navigator.pop` 제거 가능 여부)는 `SignInScreen` 구현(`screens/sign_in_screen.dart`)을 끝까지 확인하지 않음.
- ⚠️ 에디터 패키지의 마크다운 왕복 손실 범위, 웹 동작, appflowy/super_editor의 `has:error` 원인, appflowy 라이선스(MPL-2.0 vs AGPL-3.0 태그)는 미검증.
- ⚠️ `buildTextSpan` 접근의 한글 IME 동작은 실기기 검증 필요.
- 이 문서는 스냅샷입니다. 코드가 바뀌면 줄 번호가 어긋납니다.

## 출처

**저장소 코드 (조사 시점 `main`, 로컬 파일)**
- `app/pageblink_flutter/lib/main.dart`, `app/open_item_controller.dart`, `app/pane_header.dart`, `app/theme.dart`, `app/l10n.dart`
- `features/open_item/open_item_view.dart`, `features/settings/settings_screen.dart`, `features/notes/note_editor_screen.dart`, `features/ask/ask_screen.dart`, `features/documents/documents_screen.dart`
- `app/pageblink_flutter/pubspec.yaml`, `app/pageblink_server/lib/src/rag_endpoints/ask_endpoint.dart`
- `docs/plan/004-naming-and-feature-vocabulary.md`
- Flutter SDK 소스(로컬 3.32.2): `packages/flutter/lib/src/material/input_decorator.dart`, `input_border.dart`

**pub.dev (API 조회 2026-10-15)**
- https://pub.dev/api/packages/flutter_quill · https://pub.dev/packages/flutter_quill
- https://pub.dev/api/packages/appflowy_editor · https://pub.dev/packages/appflowy_editor
- https://pub.dev/api/packages/super_editor · https://pub.dev/packages/super_editor
- https://pub.dev/api/packages/super_editor_markdown
- https://pub.dev/api/packages/markdown_quill
- https://pub.dev/api/packages/fleather
- https://pub.dev/api/packages/markdown_editor_live
- https://pub.dev/api/packages/gpt_markdown
