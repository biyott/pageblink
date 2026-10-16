# 034 · 접근성·상호작용 상태 점검 (focus / hover / pressed / 시맨틱 / 터치 영역)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 (KST, 정확한 시각 확인 필요) |
| 담당 | 서브에이전트 (읽기 전용 점검: 코드 수정·커밋·서버 실행 없음) |
| 질문 | 라이브 앱과 클라이언트 코드의 상호작용 상태(포커스·호버·눌림·시맨틱·터치 영역·탭 순서)는 어떤가. 53개 항목 점검 |
| 결론 한 줄 | Ask 컴포저의 `출처`/`모델` 알약과 `적게 보기` 토글은 호버·포커스가 실제로 0(잉크가 유리 면 아래에 그려져 가려짐). 나머지 기본 Material 위젯은 호버 Δ10·포커스 Δ30 수준의 회색 덧칠뿐이고, ui-polish §5.3 "2px accent 링"은 구현되지 않았다(당시 UP-04 ⬜). |
| 반영 | 디자인 기준 [`design/interaction-states/spec.md`](../design/interaction-states/spec.md) · [plan 013](../plan/013-ui-polish-status.md) UP-04 · [devlog 012](../devlog/012-releases-10-to-15.md) |

> 상태: 14차에 구현·배포, 후속은 15차까지 이어짐(15차 배포 성공 16:13). 디자인 기준은 `docs/design/interaction-states/spec.md`. 아래 본문은 점검 시점의 스냅샷이며 "구현되지 않았다" 같은 서술은 그 시점 기준이다.
> 경로 메모: 본문의 `S/`(스크래치패드의 `a11y/`)와 `shots/`·`data/`·`*.mjs` 파일은 저장소에 없다. 스크린샷·원자료 판독이 필요하면 확인 필요.

- 점검 시각: 2026-10-16 (KST, 이 세션 기준). 코드 수정·커밋·서버 실행 없음(읽기 전용).
- 대상: 라이브 `https://pageblink.serverpod.space`(Chrome for Testing + playwright-core 1.64.1) + 저장소 `app/pageblink_flutter/lib` 정적 점검 + 위젯 테스트 1건(스크래치패드에서만 실행, 저장소에 파일 없음).
- 표기: ✅ 확인(측정·코드로 확인) / ⚠️ 미확인.
- 경로 약어: `S/` = `/private/tmp/claude-501/-Volumes-Nova-00-src-70-github-biyott-pageblink/a5666af9-28c0-4328-8234-8d574a83e873/scratchpad/a11y/`. 스크린샷은 `S/shots/`, 원자료 JSON은 `S/data/`, 스크립트는 `S/*.mjs`, 위젯 프로브는 `S/widget/show_fewer_probe_test.dart`.

## 측정 방법과 수치 읽는 법

- 호버: 마우스를 요소 중앙에 올리기 전/후 스크린샷을 요소 사각형 안에서 픽셀 비교. `Δ`는 채널 최대 차이(0~255). **Δ ≥ 25 뚜렷 / 8~24 미미(눈에 겨우 띔) / ≤ 3 없음.** 커서는 `flt-glass-pane`의 `cursor` 값.
- 포커스: 실제 `Tab` 키를 눌러 이동하며 직전 대비 변화량을 같은 방식으로 측정(접근성 켠 상태 + 끈 기본 상태 둘 다). 눈으로 본 확인은 `S/shots/m-home-focus.png` 등.
- 눌림: 마우스 버튼을 누른 채 측정, 요소 밖에서 놓아 클릭이 실행되지 않게 함.
- 한계: 데스크톱 Chrome에서 측정했으므로 Material 위젯의 터치 영역 확장(`MaterialTapTargetSize.padded`)은 실제 폰에서 달라질 수 있음(⚠️). 이 레포는 `materialTapTargetSize`를 어디서도 지정하지 않음(grep 0건).
- **고지**: 눌림 측정 중 노트/PDF 카드를 0.5초 이상 누르고 있었더니 카드의 길게 누르기(`documents_screen.dart` `onLongPress`)가 작동해 "삭제할까요?(Delete?)" 대화상자가 2회 열렸습니다(`S/shots/off-after-card.png`). 삭제 버튼은 누르지 않았고 이후 카드는 4개 그대로입니다(✅ 이후 인벤토리 "Notes 4"). 데모 계정은 세션 단위 임시 계정입니다. 이 뒤로 카드는 눌림 측정에서 제외했습니다.

---

## 1. 요약

점검한 상호작용 항목: **53개**(아래 §2 표의 번호). 한 항목이 여러 문제에 해당할 수 있습니다.

| 심각도 | 개수 | 해당 항목 번호 |
|---|---:|---|
| 키보드 접근 불가 | 7 | 5(접근성 켠 상태), 33, 34, 35, 36, 37, 38 |
| 포커스 표시 없음(또는 사실상 없음) | 5 | 19, 20, 21, 26(라이트에서 Δ8), 39(코드) |
| 호버 없음 | 4 | 7(활성 내비), 19, 20, 26(라이트) |
| 호버·포커스가 있으나 미미(회색 Δ8~12, 강조색 없음) | 9 | 6, 12, 13, 17, 18, 23, 45, 49 외 대부분의 기본 Material 위젯 |
| 시맨틱(스크린리더 이름·역할) 문제 | 3 | 2(이름 없음), 41(이름 없음), 12·18(칩이 `checkbox` 역할로 노출) |
| 터치 영역 작음(44px 미만) | 11 | 12, 16, 18, 19, 20, 37, 38, 40, 41, 50, 51 |
| 탭 순서 문제 | 1(전역) | 52 |

핵심 한 줄: **(a)** Ask 컴포저의 `출처`/`모델` 알약과 답변 아래 `적게 보기` 토글은 호버·포커스가 실제로 0입니다(원인은 같음: 잉크가 유리 면 아래에 그려져 가려짐). **(b)** 나머지 기본 Material 위젯은 호버 Δ10·포커스 Δ30 수준의 회색 덧칠뿐이라 "효과 없음"으로 느껴지고, 설계 명세(`ui-polish/spec.md` §5.3 "2px accent 링")는 구현되지 않았습니다(UP-04 ⬜, `013-ui-polish-status.md`).

---

## 2. 화면별 문제 표

열: 위치 = `파일:줄`(`lib/` 기준) · 호버/포커스/눌림은 측정 Δ(없으면 코드 판단) · 시맨틱 · 크기(측정 px) · 키보드(Tab·Enter) · 스크린샷.
(`h` = 호버, `f` = 포커스, `p` = 눌림. 접근성 켠 상태에서 얻은 값이며, 끈 상태에서도 같은 순서·같은 표시 확인 ✅ `S/data/home-tab-off.json`.)

### 2-1. 로그인 / 가입 (`S/shots/d-login.png`, `d-register.png`, `m-login.png`, `m-login-focus.png`)

| # | 위치 | 위젯 | 호버 | 포커스 | 눌림 | 시맨틱 | 크기 | 키보드 | 판정 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `screens/sign_in_screen.dart:395` | 언어 `PopupMenuButton`(child) | Δ10, 커서 click | Δ30, **모서리 각진 사각형**(InkWell에 radius 없음) | Δ23 | 버튼+라벨 ✅ | 110×48 | ✅ | 경미: 강조 모양이 각짐 |
| 2 | `screens/email_sign_in.dart:196`, `email_register_forms.dart:493` | 비밀번호 보기 `IconButton` | Δ22 | 회색 원 Δ176(캐럿 포함) | Δ165 | **라벨 없음**(aria-label `""`, tooltip 미지정) | 40×40 | ✅ | **시맨틱 없음**. 아이콘 색이 `Colors.grey[400]` 하드코딩(흰 카드 위 대비 낮음) |
| 3 | `email_sign_in.dart:147,208`, `email_register_forms.dart:163,410` | `Forgot password?`/`Sign up`/`Sign in` 링크 `TextButton` | Δ13 | **연보라 알약 Δ17~19**(좋음) | Δ73 | ✅ | 140×32, 73×32 | ✅ | 좋은 예 |
| 4 | `email_register_forms.dart:90` | `Sign in`/`Continue` `ElevatedButton` | ⚠️ 비활성 상태만 관찰(입력 안 함) | ⚠️ | ⚠️ | ✅ | 354×44 | – | ⚠️ 활성 상태 미확인 |
| 5 | `features/demo/demo_widgets.dart:141`(래퍼 `Semantics` `:135`) | `Try the demo` `OutlinedButton.icon` | Δ18, click | 회색 Δ(끈 상태에서 보임, `m-login-focus.png` 마지막 칸) | – | `excludeSemantics: true` 래퍼 | 354×40 | **접근성 켠 상태에서 `tabindex` 없음 → Tab으로 도달 불가**(끈 상태는 도달 ✅) | **키보드 접근 불가(스크린리더·접근성 모드)** |

### 2-2. 셸 / 사이드바 / 보드 (`p3-home.png`, `home-tab-on-end.png`, `m-home-focus.png`)

| # | 위치 | 위젯 | 호버 | 포커스 | 눌림 | 시맨틱 | 크기 | 키보드 | 판정 |
|---|---|---|---|---|---|---|---|---|---|
| 6 | `main.dart:682` | `_NavItem`(Notes/Projects/Settings/Sign out) `Material`+`InkWell` | Δ10(미미) | 회색 Δ30, 링 없음 | Δ19~27 | ✅(라벨+개수) | 206×40 | ✅ | 호버·포커스 약함 |
| 7 | `main.dart:682` | 활성 `_NavItem`(보라 채움) | **라이트 Δ10, 다크 Δ4(없음)** | 보라 위 회색 Δ30 | 라이트 Δ68 | ✅ | 206×40 | ✅ | **호버 없음(다크)** |
| 8 | `demo/demo_widgets.dart:85,91` | 배너 정보 `IconButton`, `Sign up` `TextButton` | Δ16 | Δ20 | Δ22~26 | ✅ | 40×40, 67×36 | ✅ | 정상(미미) |
| 9 | `documents_screen.dart`(검색 `TextField`) | 검색 입력 | Δ10 | 테두리 변화 ✅ | – | ✅ | 443×49 | ✅ | 정상 |
| 10 | `documents_screen.dart:360` | `New note` `FilledButton.icon` | **Δ39 뚜렷** | Δ18 | Δ39 | ✅ | 128×36 | ✅ | 좋은 예(호버). 코드는 `minimumSize 44`인데 측정 36 ⚠️ 불일치 원인 미확인 |
| 11 | `documents_screen.dart:367` | `Upload PDF` `OutlinedButton.icon` | Δ18 | Δ24 | Δ38 | ✅ | 142×36 | ✅ | 정상 |
| 12 | `documents_screen.dart:293` | 필터 `ChoiceChip` ×3 | Δ10 | 회색 Δ31 | Δ27 | **역할이 `checkbox`로 노출**(ChoiceChip인데 선택 위젯 역할 아님 ⚠️ 원인 미확인) | 76~80×30 | ✅ | 미미 + 시맨틱 + 작음 |
| 13 | `documents_screen.dart:632`(`Card`+`InkWell`) | 노트/PDF 카드 | Δ10 | 카드 전체 회색 Δ30 | Δ22~29 | ✅(제목·메타) | 231×250 | ✅ | 미미. **길게 누르기 → 삭제 확인 대화상자**(마우스에서도 발동) |
| 14 | `documents_screen.dart:666` | 카드 `⋮` `PopupMenuButton` | **Δ29** | Δ22 | Δ28 | ✅(`More`) | 40×40 | ✅ | 정상 |

### 2-3. Ask 패널 (`p3-home.png`, `m-home-focus.png`, `crops/home-hover-*.png`, `m-dark-pills.png`)

| # | 위치 | 위젯 | 호버 | 포커스 | 눌림 | 시맨틱 | 크기 | 키보드 | 판정 |
|---|---|---|---|---|---|---|---|---|---|
| 15 | `ask_screen.dart:253` | 새 대화 `IconButton`(넓은 화면 헤더) | – | – | – | tooltip ✅ | 40×40 | 비활성(빈 대화) | 정상 |
| 16 | `ask_screen.dart:1285` | 기록 안내 닫기 `IconButton`(compact) | Δ14 | Δ19 | Δ23 | tooltip ✅ | **34×32** | ✅ | 터치 작음 |
| 17 | `ask_screen.dart:1235` | **질문 예시 카드** `Material`+`InkWell` | Δ10 **회색 덧칠**(`crops/home-hover-23.png`) | 회색 Δ31, 강조 링 없음(`m-home-focus.png` 3번째) | 물결 Δ20~28 | ✅ | 330×48 | ✅ | 효과는 있으나 **회색이라 약함·브랜드색 없음**(사용자 지적 "질문 버튼"의 실체) |
| 18 | `ask_screen.dart:1361,1367` | `Recent conversations`/`New conversation` `ActionChip` | Δ10 | 회색 Δ31 | Δ22~30 | **`checkbox` 역할로 노출** | 178×30, 157×30 | ✅(New는 비활성) | 미미 + 시맨틱 + 작음 |
| 19 | `ask_screen.dart:587`(`InkWell`→`Container`) | **출처 알약** `_ScopeButton` | **0**(Δ1, `crops/home-hover-29.png`) | **0**(Δ2, `m-home-focus.png` 5번째) | **0**(Δ1) | tooltip+버튼 ✅ | 233×32 | Tab 이동은 되나 **어디 있는지 안 보임** | **호버 없음 + 포커스 표시 없음**, 터치 작음 |
| 20 | `ask_screen.dart:448,505`(`PopupMenuButton`→`Container`) | **모델(Auto) 알약** `_ModelPill` | **0**(Δ1) | **0**(Δ2, `m-home-focus.png` 6번째) | **0**(Δ1) | tooltip ✅ | 72×32 | 동일 | **호버 없음 + 포커스 표시 없음**, 터치 작음 |
| 21 | `ask_screen.dart:341~369` | 질문 입력 `TextField` | 커서 text | **입력창에 포커스 표시 없음**: `border/enabledBorder/focusedBorder` 모두 `InputBorder.none`(`:361~363`), 감싼 `GlassPanel`에도 변화 없음. 캐럿만 보임(Δ173, 영역 0.2%) | – | ✅ | 280×48 | ✅ | **포커스 표시 없음(입력창)** |
| 22 | `ask_screen.dart:379` | 전송 `IconButton.filled` | ⚠️ 입력해야 활성 → 미측정(비활성은 `hairline` 회색) | ⚠️ | ⚠️ | tooltip ✅ | 40×40 | – | ⚠️ 활성 상태 미확인 |
| 23 | `ask_screen.dart:695~742`(시트) | 출처 대화상자: `TextButton`×2, `CheckboxListTile`×2, `FilledButton Done` | TextButton Δ12, **체크 타일 Δ9**, Done Δ36 | 타일 Δ29, Done Δ29, Clear Δ15 | – | ✅ | 420×63 타일 | ✅ | 체크 타일 호버 약함(`pop-scope-open.png`) |
| 24 | `ask_screen.dart:452~503` | 모델 메뉴 `PopupMenuItem` ×8 | Δ10 | Δ30 | – | `menuitem` ✅ | 280×48 | ✅ | 정상(미미) |
| 25 | `ask_screen.dart:1423~`(`_RecentChats`) | 최근 대화 대화상자 | – | – | – | – | – | 대화 목록이 비면 **포커스 가능한 요소가 하나도 없고 닫기 버튼도 없음**(Esc/바깥 클릭만) | 경미 |
| 26 | `ask_sources.dart:1135`(`InkWell`, 키 `sources-toggle`) | **`적게 보기`/`N개 더 보기` 토글** | **라이트: 0**(Δ3), 다크 Δ8(미미) | 라이트 Δ8(거의 없음), 다크 Δ24 | – | `button`+`expanded`+라벨 ✅ | 44 높이 ✅ | ✅(Tab·Enter) | **호버 없음 + 포커스 사실상 없음(라이트)**. 위젯 테스트로 확인(§3) |
| 27 | `ask_sources.dart:750` | 출처 행 `SourceRow` | 전용 `rowHover` | 2px 강조 테두리 | `rowPress` | ✅ | ≥44 | ✅ | **좋은 예**(§4) |
| 28 | `ask_sources.dart:517` | 인용 마커 `CiteMarker` | 전용 알파 | 2px 강조 테두리 | 전용 | ✅ | ~34×18 시각, 히트 확장 | ✅(Enter) | **좋은 예**(§4) |
| 29 | `ask_screen.dart:1089,1136,1412` | 복사 `IconButton`, `Ask again` `TextButton`, 한도 배너 `FilledButton` | ⚠️ 답변이 있어야 나타남 → 라이브 미측정 | ⚠️ | ⚠️ | 코드상 tooltip ✅ | compact | – | ⚠️ 표준 Material, 라이브 미확인 |

### 2-4. 노트 편집기 / 뷰어 (`note-open.png`, `d-note.png`, `d-pdf.png`, `crops/d-note-hover-*.png`)

| # | 위치 | 위젯 | 호버 | 포커스 | 눌림 | 시맨틱 | 크기 | 키보드 | 판정 |
|---|---|---|---|---|---|---|---|---|---|
| 30 | `app/pane_header.dart:44,53` | 뒤로 `TextButton.icon`/`IconButton` | Δ14 | Δ19 | Δ21 | ✅ | 92×32 | ✅ | 정상 |
| 31 | `note_editor_screen.dart:1174` | `Live｜Source` `SegmentedButton` | Δ16~18 | Δ20~24 | – | ✅ | 70×32 | ✅ | 정상(작음) |
| 32 | `note_editor_screen.dart:1204,1224`, `pane_header.dart:68` | `More`/`Save`/`Close` `IconButton` | Δ14~20 | Δ19~26 | Δ28 | tooltip ✅ | 40×40 | ✅ | 정상 |
| 33 | `selection_mini_bar.dart:31`(`FormatButton`), `note_editor_screen.dart:1044,1066`(`ExcludeFocus`) | 서식 툴바 B/I/S/목록/번호/체크/인용/코드/링크 | Δ14 | **`ExcludeFocus` 의도적: 포커스 불가**. 접근성 켠 상태에서는 DOM만 포커스되고 화면 표시 없이 Tab이 여러 번 헛돎(`probe_note2.mjs` 32~37단계) | Δ20~24 | ✅(tooltip) | 40×32 | **Tab 불가**. 단축키는 Ctrl/Cmd+B·I뿐(`:1410~1420`) → 나머지 서식은 키보드로 못 씀 | **키보드 접근 불가** |
| 34 | `note_editor_screen.dart:976` | 제목(H) `PopupMenuButton` | Δ10 | 위와 같이 포커스 불가 | Δ20 | ✅ | 40×40 | **불가** | **키보드 접근 불가** |
| 35 | `notes/live_check_layer.dart:152`(`GestureDetector`+`CustomPaint`) | 체크박스(캔버스에 그림) | **호버 윤곽 ✅(Δ145), 커서 click ✅**(`note_editor_screen.dart:1340`) | 없음 | – | `checked`+`onTap` 시맨틱 ✅ | 42×28, 38×28 | **`tabindex` 없음**(Tab 불가). 캐럿 줄에서 Enter로 토글(`:1415`)하는 대체 경로는 있음 | **키보드 접근 불가(대체 경로 있음)** |
| 36 | `notes/live_code_layer.dart:352` | 코드 블록 복사 버튼(캔버스) | `hoverFill` ✅ | 없음 | – | 시맨틱 ✅(`:446~467`) | ⚠️ 미측정(코드 블록 필요) | Tab 불가 | **키보드 접근 불가** ⚠️ 라이브 미측정 |
| 37 | `selection_mini_bar.dart:174` | 선택 미니바 `H1~H3` `InkWell` | ⚠️ 선택해야 보임 → 미측정 | `ExcludeFocus` → 포커스 불가 | – | tooltip ✅ | 32×32 | **불가** | 키보드 접근 불가 + 작음 ⚠️ 라이브 미측정 |
| 38 | `notes/link_popover.dart:146,157` | 링크 팝오버 아이콘 4개(열기/복사/편집/해제) | ⚠️ | `ExcludeFocus` → 포커스 불가 | – | tooltip ✅ | **36×36** | **불가** | 키보드 접근 불가 + 작음 ⚠️ 라이브 미측정(링크 선택 필요) |
| 39 | `link_popover.dart:122~129`(`deco`) | 링크 편집 `TextField` | – | `focusedBorder: const OutlineInputBorder()` = `enabledBorder`와 **동일 기본 테두리**라 포커스 때 테두리 변화 없음(라벨 색만 변함) | – | ✅ | – | ✅ | **포커스 표시 약함(코드 판단)** ⚠️ 라이브 미측정 |
| 40 | `viewer/cite_bar.dart:122` | 인용 바 이전/다음/닫기 `IconButton` | ⚠️ 인용으로 열어야 보임 → 미측정 | ⚠️ | ⚠️ | tooltip ✅ | **36×36**(코드 `tightFor`) | ✅ | 터치 작음 ⚠️ 라이브 미측정 |
| 41 | `viewer/citation_sheet.dart:241` | 인용 시트 이전/다음 `InkResponse` `_Step` | 기본 작은 원 | 기본 | 기본 | **라벨·tooltip·`Semantics` 없음** | ~26×18 | ✅ | **시맨틱 없음 + 터치 매우 작음**(폰 전용 시트 ⚠️ 라이브 미측정) |
| 42 | PDF 뷰어(`page_viewer_screen.dart`, pdfrx) | 본문 | – | – | – | 접근성 켠 상태에서 PDF 글줄 노드마다 `tabindex=0`(약 14개)가 생겨 Tab이 긺(`d-pdf-inv.json`) ⚠️ 의미 있는 노드인지 미확인 | – | – | ⚠️ 미확인 |

### 2-5. 설정 / 프로젝트 / 모바일 / 기타

| # | 위치 | 위젯 | 호버 | 포커스 | 눌림 | 시맨틱 | 크기 | 키보드 | 판정 |
|---|---|---|---|---|---|---|---|---|---|
| 43 | `settings/settings_screen.dart:67~75` | 언어 `RadioListTile`×3 | Δ10 | Δ31 | Δ20~24 | `radio` ✅ | 722×48 | ✅ | 정상(미미) |
| 44 | `settings_screen.dart:85,106,128` | `ListTile`(계정 ID 복사/관리자/로그아웃) | Δ10 | – | Δ15 | `button` ✅ | 722×48 | ✅ | 정상. 헤더에 `Back`과 `Close`가 같은 일을 하는 버튼 2개(경미) |
| 45 | `projects/projects_screen.dart:198` | `New project` FAB.extended | **Δ9** | **Δ11** | Δ11 | ✅ | 146×56 | ✅ | 보라 위 회색 덧칠이라 미미 |
| 46 | `projects_screen.dart:213~237` | 프로젝트 `ListTile`, 초대 `IconButton`, `⋮` `PopupMenuButton` | ⚠️ 데모에 프로젝트 없음 → 미측정 | ⚠️ | ⚠️ | tooltip ✅(코드) | – | – | ⚠️ 미확인 |
| 47 | `main.dart:396` | 하단 `NavigationBar`(폰) | Δ10~16 | Δ31 | – | `tab` ✅ | 130×80 | ✅ | 정상 |
| 48 | `documents_screen.dart:459,466` | 폰 FAB 2개 | Δ10 | Δ31 | – | tooltip ✅ | 40×40, 130×56 | ✅ | 정상 |
| 49 | `main.dart:295,300` | 폰 AppBar `IconButton`(설정·로그아웃) | Δ17 | Δ23 | – | tooltip ✅ | **40×40** | ✅ | 44 미만(실기기에서 padded면 48 ⚠️) |
| 50 | `documents/upload_tray.dart:103,116,216,350` | 업로드 트레이 `IconButton` compact, 재시도 `TextButton` | ⚠️ 업로드해야 보임 → 미측정 | ⚠️ | ⚠️ | tooltip ✅ | compact·`minimumSize 32` | – | 터치 작음 ⚠️ 라이브 미측정 |
| 51 | `documents_screen.dart:914~928`(`_InlineLink`) | 인라인 링크 `TextButton`(`shrinkWrap`, 32) | – | – | – | ✅ | 32 높이 | ✅ | 터치 작음 ⚠️ 라이브 미측정 |
| 52 | 전역 | **탭 순서** | – | – | – | – | – | `FocusTraversalGroup` 없음(grep 0건) → 시각 위치(위→아래) 순서. 사이드바 → 보드 → Ask 패널이 섞여 나옴(예: `Notes`→검색→새 노트→업로드→**Ask의 닫기**→`Projects`→필터…, `Sign out`이 Ask 입력 뒤, 모델 알약은 맨 끝 근처). 열린 노트에서는 마지막 클릭 위치에 따라 시작점이 달라짐 | **탭 순서 불합리** |
| 53 | `confirm_dialog.dart`, `documents_screen.dart:199,203`, `projects_screen.dart:74,78`, `tier_sheet.dart:26~40`, `session_end.dart:109` | 대화상자 `TextButton`/`FilledButton`, 시트 `ListTile`, 세션 종료 배너 `IconButton` | Material 기본 | Material 기본 | – | ✅ | – | ✅ | 정상(기본값 수준). ⚠️ 라이브 일부만 확인(삭제 확인창 외관은 `off-after-card.png`) |

(관리자 전용 `settings/admin_history_screen.dart:152,193,259`의 `ChoiceChip`/`TextButton`은 데모 계정에 없어 ⚠️ 미확인.)

---

## 3. 사용자가 짚은 예시의 구체 원인

### 3-1. `적게 보기(show fewer)` 토글 — `ask_sources.dart:1126~1171`
- 구조: `Align` > **`InkWell`**(키 `sources-toggle`) > `ConstrainedBox(minHeight 44)` > 글자+화살표. **`Material`이 직접 부모가 아닙니다.**
- 이유: `InkWell`의 호버·포커스·눌림 색은 "가장 가까운 `Material`"의 캔버스에 그려집니다. 이 토글은 Ask 답변 말풍선 `Container(color: pb.glassStrong …)`(`ask_screen.dart:1047~1058`) 안에 있어서, 잉크가 **말풍선의 74% 불투명 흰색 면 아래**에 그려져 보이지 않습니다. 가까운 `Material`은 `Scaffold`(투명)입니다.
- 증거(✅ 위젯 테스트, `S/widget/show_fewer_probe_test.dart`, 실제 `AskTurnView`+실제 테마):
  - 라이트: 호버 변화 0.0%, 최대 Δ3 → **호버 없음**. 포커스 최대 Δ8 → 사실상 안 보임. 다크: 호버 Δ8, 포커스 Δ24(다크는 유리 면이 14% 투명해 일부 보임).
  - 대조 실험: 같은 `InkWell`을 `Container(color: glassStrong)` 아래에 두면 호버 0%/Δ3, `Material(color: glassStrong)` 아래에 두면 83%/Δ10. → **부모가 `Container`냐 `Material`이냐가 원인**.
  - 파일: `S/shots/w-fewer-light-rest.png` / `-hover.png` / `-focus.png`, `w-fewer-dark-*.png`, `w-control-container.png`, `w-control-material.png`.
- 라이브 사이트에서는 질문을 보내지 않았으므로 이 토글을 직접 못 봤습니다(⚠️). 위 테스트가 대체 증거입니다.

### 3-2. 드롭다운 `출처(Sources…)`와 `자동(Auto)` — `ask_screen.dart:587`, `:448~535`
- 라이브 측정(✅): 호버 Δ1, 포커스 Δ2, 눌림 Δ1. 라이트·다크 모두 0(`crops/home-hover-29.png`, `m-home-focus.png` 5·6번째 칸, `m-dark-pills.png` 위 두 줄).
- 이유 ① 둘 다 **`GlassPanel(strong)`(컴포저, `ask_screen.dart:293`) 안**에 있고 `GlassPanel`은 `Container(color: glassStrong)`로 `Material` 위에 불투명 면을 깝니다(`theme.dart:463~469`). 잉크가 그 아래에 그려짐 = 3-1과 같은 원인.
- 이유 ② `_ModelPill`은 `PopupMenuButton(child: Container(decoration: color chipBg …))`(`:505~510`)라서 **`InkWell`의 자식 `Container`가 잉크 위에 반투명 흰색을 한 번 더 덮습니다.** 부모 쪽만 고쳐도(예: `GlassPanel`에 투명 `Material` 삽입) 이 알약은 안 고쳐집니다. `_SuggestionCard`처럼 `Material(color)`+`InkWell`로 바꿔야 합니다.
- `_ScopeButton`은 `InkWell`의 자식 `Container` 색이 투명(비어 있을 때만 `warnContainer`)이라 ②는 해당 없음, ①만 해당.
- 보너스: 클릭하면 열리는 메뉴 항목·대화상자 안은 정상(호버 Δ10, 포커스 Δ29~30, `pop-scope-open.png`). 문제는 닫힌 알약뿐.

### 3-3. 질문 예시 버튼(`_SuggestionCard`, `ask_screen.dart:1213~1255`)
- 구조는 올바릅니다(`Material(color: chipBg)`+`InkWell(customBorder)`). 호버·포커스·눌림 모두 **작동**합니다(호버 Δ10, 포커스 Δ31, 눌림 물결 Δ20~28, 커서 click).
- 문제는 "없음"이 아니라 **너무 약하고 회색**이라는 점입니다: 호버는 파스텔 면 위의 회색 덧칠(`crops/home-hover-23.png`), 포커스는 회색 사각 칠(`m-home-focus.png` 3번째 칸)이며 브랜드 보라(accent)도, 2px 링도 없습니다. 이는 테마에 `hoverColor`/`focusColor`/`highlightColor`/`splashColor`가 비어 M3 기본값(onSurface 4%·12%)이 쓰이기 때문입니다(§5).

---

## 4. 이미 잘 된 컴포넌트 (재사용 기준 후보)

| 컴포넌트 | 위치 | 패턴 | 왜 좋은가 |
|---|---|---|---|
| `SourceRow` | `ask_sources.dart:634~866` | `Semantics(button, selected, label, excludeSemantics, onTap)` > `Material(color, shape)` > `InkWell(customBorder: shape, overlayColor: pressed→rowPress / hovered→rowHover, onFocusChange→_focus)`, 포커스 시 `shape.side = BorderSide(accent, 2)`, `minHeight 44` | 호버·눌림 색을 토큰(`SourceTones`)으로 명시, **2px 강조 포커스 링**, 의미 라벨, 44px |
| `CiteMarker` | `ask_sources.dart:454~610` | `Semantics(button, label)` > `FocusableActionDetector(mouseCursor click, onShowHoverHighlight, onShowFocusHighlight, actions: ActivateIntent)` > `Listener`(눌림) > 그리는 알약, 포커스 때 2px 강조 테두리 | 잉크 없이도 호버·눌림·포커스·Enter 활성화를 직접 구현. `InkWell`을 쓸 수 없는 인라인 위젯의 기준 |
| `_SuggestionCard` | `ask_screen.dart:1213~1255` | `Material(color)` 바로 아래 `InkWell(customBorder)`, `minHeight 44` | **`Material`이 부모**여서 잉크가 보임(올바른 구조). 단 색을 `overlayColor`로 브랜드화하면 완성 |
| `_NavItem` | `main.dart:633~` | `Material(color)`+`InkWell(borderRadius)` | 같은 올바른 구조 |
| `TextButton`(`Forgot password?` 등) | `email_sign_in.dart:208` | 기본 `TextButton` | **기본 포커스가 연보라 알약**(primary 12%)으로 보라 브랜드와 어울림 |
| `New note` | `documents_screen.dart:360` | `FilledButton.icon` | 호버 Δ39로 뚜렷 |
| 체크박스 레이어 | `live_check_layer.dart:99~`, `note_editor_screen.dart:1340` | `MouseRegion` 호버 윤곽 + click 커서 + `semanticsBuilder` | 캔버스 위젯인데 호버·커서·시맨틱을 직접 제공 |
| 팝업 메뉴·대화상자 내부 | `ask_screen.dart:452~`, `:695~` | Material 기본 | 호버 Δ10, 포커스 Δ29~30 |

---

## 5. 공통 원인 분석

### 5-1. 원인 1 — 잉크가 불투명 면 아래에 그려짐 (구조 문제, 항목 19·20·26 + 약한 호버 다수)
`InkWell`/`ListTile` 등 잉크 위젯은 가장 가까운 `Material`에 그립니다. 이 앱은 `scaffoldBackgroundColor: transparent`(`theme.dart:298`)에 유리 면(`GlassPanel`, 답변 말풍선 `Container`)을 `Material` 위에 깔기 때문에, 그 안의 맨 `InkWell`은 효과가 가려집니다. `Material`을 직접 부모로 둔 위젯(`_SuggestionCard`, `SourceRow`, `_NavItem`, 카드 `Card`)과 버튼류(`TextButton` 등은 내부 `Material` 보유)는 정상입니다.

### 5-2. 원인 2 — 테마에 상태 색·링·버튼 테마가 비어 있음 (전역, 대부분의 "미미")
`theme.dart` `buildPbTheme`에는 다음만 있습니다: `filledButtonTheme`(모양만), `chipTheme`(선택 테두리), `inputDecorationTheme`(포커스 테두리), `floatingActionButtonTheme`, 내비 테마. **없는 것**(grep ✅): `hoverColor`, `focusColor`, `highlightColor`, `splashColor`, `splashFactory`, `iconButtonTheme`, `textButtonTheme`, `outlinedButtonTheme`, `elevatedButtonTheme`, `listTileTheme`, `popupMenuTheme`, `segmentedButtonTheme`, `visualDensity`, `materialTapTargetSize`. 그래서 M3 기본(호버 onSurface ~4%, 포커스 ~12% 회색)이 쓰여 Δ10/Δ30의 회색 덧칠이 됩니다. 프로젝트 전체에서 `hoverColor|focusColor|overlayColor|mouseCursor`를 직접 지정한 곳은 `ask_sources.dart`(SourceRow, CiteMarker) 두 곳뿐입니다.
설계 명세 §5.3(호버 accent 6%, 눌림 accent 12%, 포커스 2px accent 링, 비활성 55%)은 **어디에도 구현되지 않았습니다**(`013-ui-polish-status.md` UP-04 ⬜).

### 5-3. 원인 3 — 공통 상호작용 위젯이 없음
`Pressable`류 공통 컴포넌트가 없어 같은 알약이 `InkWell+Container`(`_ScopeButton`), `PopupMenuButton+Container`(`_ModelPill`, 제목 H), `ActionChip`, `TextButton` 등으로 제각각 만들어집니다. 포커스 링이 있는 곳은 `SourceRow`·`CiteMarker` 두 곳뿐.

### 5-4. 원인 4 — 의도적 `ExcludeFocus`와 시맨틱 래퍼
- 툴바·링크 팝오버·미니바(`ExcludeFocus`): 본문 캐럿 유지를 위한 **의도적** 설계(`note_editor_screen.dart:1040~1046` 주석)지만 키보드 사용자는 서식 기능 대부분을 쓸 수 없습니다.
- `Semantics(excludeSemantics: true, onTap)`로 감싼 `Try the demo`(`demo_widgets.dart:135~140`): 자식 `OutlinedButton`의 "포커스 가능" 시맨틱이 지워져 접근성 모드에서 Tab 순서에서 빠짐. 같은 `excludeSemantics: true` 래퍼 패턴이 `SourceRow`·`CiteMarker`·`적게 보기` 토글(`ask_sources.dart`)에도 쓰입니다. 라이브에서 `Try the demo`만 `tabindex` 없음(✅)이고, 이 세 곳은 답변이 있어야 나타나 접근성 모드 Tab 도달을 확인하지 못했습니다(⚠️ 같은 문제일 수 있음; `InkWell`/`FocusableActionDetector`가 자체 포커스 노드를 갖는 점은 코드로만 확인).

### 5-5. 전역으로 한 번에 고칠 수 있는 것 vs 개별로 고쳐야 하는 것

| 구분 | 내용 | 영향 |
|---|---|---|
| **전역(테마 한 곳 `theme.dart`)** | ① `hoverColor`/`focusColor`/`highlightColor`/`splashColor`를 accent 6%/12%/…로 지정(InkWell·ListTile·칩에 즉시 반영) ② `textButtonTheme`/`outlinedButtonTheme`/`elevatedButtonTheme`/`iconButtonTheme`/`segmentedButtonTheme`에 `overlayColor`(accent)와 **포커스 시 `side` 2px accent**(`WidgetStateBorderSide`), `minimumSize 44` ③ `chipTheme` 포커스 변형 ④ `listTileTheme`/`popupMenuTheme` 호버 ⑤ `materialTapTargetSize: padded`(웹 데스크톱에서도 44~48 터치 확장) ⑥ `GlassPanel` 자식에 투명 `Material` 삽입(컴포저·패널 안 맨 InkWell 잉크 복구) | 항목 6,7,12,13,17,18,23,43,44,45 등 "미미" 대부분과 19·20의 ①번 원인, 터치 영역 일부 |
| **개별(위젯별 수정)** | `_ModelPill`(자식 `Container` 색이 잉크를 덮음 → `Material`+`InkWell` 구조로) · `ask_sources.dart:1135` 토글(말풍선 `Container`→`Material` 또는 토글만 `Material(type: transparency)`로 감싸기) · Ask 입력창 포커스 표시(`GlassPanel` 컨테이너 테두리 강조 `Focus` 감지) · `Try the demo`(`Semantics`에 `focusable` 추가 또는 래퍼 제거) · 비밀번호 보기 버튼 tooltip과 아이콘 색 · 툴바/링크 팝오버 키보드 경로(`ExcludeFocus` 정책) · `citation_sheet.dart` `_Step` 라벨·크기 · 36px짜리 `IconButton`(`cite_bar.dart:128`, `link_popover.dart:150`) 키우기 · 칩 역할(`checkbox`) 점검 · `FocusTraversalGroup`(사이드바/보드/Ask) · 활성 `_NavItem` 호버(보라 위 흰 6% 오버레이) · 언어 `PopupMenuButton` radius | 항목 2,5,19,20,21,26,33~41,52 등 |

---

## 6. 우선순위 제안 (심각도 × 사용 빈도)

| 순위 | 작업 | 항목 | 이유 | 규모 |
|---|---|---|---|---|
| 1 | `GlassPanel`에 투명 `Material` + 컴포저 알약(`_ScopeButton`, `_ModelPill`)을 `Material+InkWell` 구조로 + 입력창 포커스 테두리 | 19, 20, 21 | 사용자 지적 항목, Ask는 사용 빈도 최고, 효과가 아예 0 | `theme.dart`, `ask_screen.dart` (2파일) |
| 2 | `적게 보기` 토글(및 말풍선 안 맨 InkWell) | 26 | 사용자 지적 항목. 같은 원인 | `ask_sources.dart`, `ask_screen.dart` (이미 포함 1~2파일) |
| 3 | 테마에 hover/focus/splash/버튼 테마 + 2px accent 포커스 링(명세 §5.3 구현) | 6,7,12,13,17,18,23,45 등 | 한 번에 가장 많은 항목 개선, 질문 예시 버튼 포함 | `theme.dart` 1파일(+필요 시 공통 위젯 1) |
| 4 | `Try the demo` 포커스(접근성 모드 Tab 도달) | 5 | 첫 화면 핵심 CTA가 접근성 모드 키보드로 못 감 | `demo_widgets.dart` 1파일 |
| 5 | 비밀번호 보기 tooltip·색, `citation_sheet` `_Step` 라벨 | 2, 41 | 스크린리더 이름 없음, 수정 쉬움 | 3파일(`email_sign_in.dart`, `email_register_forms.dart`, `citation_sheet.dart`) |
| 6 | 터치 영역(`Dismiss` 34×32, 36px IconButton들, 30px 칩, 32px 알약) | 12,16,18,19,20,38,40,50,51 | 폰 사용 빈도 높음. 전역 `materialTapTargetSize`로 일부 해결 | 위 3번에 포함 + `cite_bar.dart`, `link_popover.dart`, `upload_tray.dart`, `documents_screen.dart` |
| 7 | 키보드로 서식 툴바·링크 팝오버 쓰기 | 33,34,35,36,37,38 | 키보드 전용 사용자만 영향, 설계 변경(포커스 정책) 필요 | `note_editor_screen.dart`, `selection_mini_bar.dart`, `link_popover.dart`, `live_*_layer.dart` (4~5파일) |
| 8 | 탭 순서 `FocusTraversalGroup` | 52 | 키보드·스크린리더 | `main.dart` 1파일 |
| 9 | 시맨틱 역할(칩이 `checkbox`), 최근 대화 대화상자 닫기 버튼, 언어 메뉴 모서리 | 12,18,25,1 | 경미 | 3파일 |

예상 규모 합계: **약 12~14개 파일**(핵심 3~4개 `theme.dart`·`ask_screen.dart`·`ask_sources.dart`·`demo_widgets.dart`로 사용자 지적 항목과 대부분 해결, 나머지는 후속).

---

## 7. ⚠️ 미확인

- ⚠️ Ask 답변이 있는 상태(`적게 보기` 토글, 출처 행, 복사 버튼, `Ask again`)를 라이브에서 직접 못 봄. **질문 전송 금지 조건** 때문. 위젯 테스트로 토글만 측정.
- ⚠️ 활성 상태의 전송 버튼, 로그인 `Sign in` 버튼: 텍스트를 입력해야 활성화되어 입력을 하지 않음.
- ⚠️ 링크 팝오버·선택 미니바·코드 블록 복사 버튼·인용 바(`cite_bar`)·인용 시트(폰)·업로드 트레이·프로젝트 목록 항목: 조건 재현이 필요해(링크 선택, 코드 블록, 인용으로 열기, 업로드, 프로젝트 생성) 라이브 미측정. 코드로만 판단.
- ⚠️ 실제 폰·태블릿 터치 영역: 데스크톱 Chrome 측정. Material 위젯은 폰에서 `padded`로 확장될 수 있음.
- ⚠️ 칩이 `checkbox` 역할로 노출되는 원인(Flutter 웹 시맨틱 매핑인지 앱 설정인지)과 `New note` 버튼 높이 36(코드 `minimumSize 44`) 불일치 원인.
- ⚠️ 실제 스크린리더(VoiceOver 등)로 읽어 보지 않음. 시맨틱은 DOM 속성으로만 확인.
- ⚠️ 다크 모드는 호버/포커스 일부(`m-dark-pills.png`, 위젯 테스트)만 확인. 전 화면 다크 측정은 하지 않음.
- ⚠️ 관리자 화면(`admin_history_screen.dart`)은 데모 계정에 없어 미확인.
- ⚠️ 이 점검 중 저장소 작업 트리에 다른 세션의 변경(PDF 복구 관련 `pdf_recovery`, 서버 생성 파일 등)이 보임. 이 점검이 만든 변경이 아님. 위젯 테스트는 그 작업 트리 상태에서 컴파일·통과함.

---

## 출처

- 라이브 앱: https://pageblink.serverpod.space (Chrome for Testing + playwright-core 1.64.1로 측정)
- 코드: `app/pageblink_flutter/lib` 정적 점검 (파일:줄은 점검 시점 작업 트리 기준)
- 위젯 테스트 1건(스크래치패드에서만 실행, 저장소에 파일 없음)
- 포커스·대비 기준(WCAG)과 토큰 값은 [`design/interaction-states/spec.md`](../design/interaction-states/spec.md)를 참조
