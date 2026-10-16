# 상호작용 상태 기준안 (focus · hover · pressed · disabled · selected)

작성 2026-10-16 KST · 작성자 UI/UX 디자이너 · 대상 `app/pageblink_flutter` (Flutter 3.47.7 SDK 소스 기준)
표기: ✅ 코드·SDK 소스·실측·계산으로 확인 / ⚠️ 미확인·추정. **저장소 파일은 만들지도 고치지도 않았다.** 산출물은 모두 이 폴더(`a11y-design/`) 안이다.

> 상태: 구현 완료(14·15차 — 14차에 `PbInteractive`·`PbFocusRing`·전역 테마로 구현·배포, 15차까지 후속 반영. 15차 배포 성공 16:13). 점검 근거는 [research 034](../../research/034-accessibility-audit.md).
> 결정 반영: §8 결정 1(링 색 `ink`)은 CTO 위임(2026-10-16)으로 채택돼 [ui-polish/spec.md](../ui-polish/spec.md) §5.3을 뒤집었다. 결정 3(`controlEdge`)·4(hover 6%)·6(터치 36/44)은 코드에 있다 ✅ (`theme.dart`, `pb_interactive.dart`). 결정 2·5·7·8의 확정 여부는 확인 필요.
> 문서 위치: 저장소 편입 시 `a11y-design/` 폴더를 이 폴더(`docs/design/interaction-states/`)로 옮겼다. 파일명은 `spec.md`.

---

## 0. 한 장 요약

1. **"효과가 없다"의 1순위 원인은 색 값이 아니라 구조다.** `InkWell`의 hover/focus/splash는 **가장 가까운 `Material` 조상 캔버스에 그려지고, 그 Material은 자식보다 먼저 그려진다**(SDK `material.dart`의 `_RenderInkFeatures.paint`: 잉크를 칠한 뒤 `super.paint`). 그런데 답변 카드(`Container(color: glassStrong)`)와 `GlassPanel`은 Material이 아니라서, 그 안의 `InkWell`(적게 보기, 출처 범위 pill, 모델 pill)은 **74% 불투명 흰 면 뒤에 칠해져 세기가 약 26%로 줄어든다.** 같은 구조를 위젯 테스트로 렌더해 읽었더니 라이트에서 hover는 ΔL* **0.8**(명도비 1.02:1), focus는 ΔL* **2.5**(1.07:1)로 사실상 구별되지 않았다. 다른 엔지니어가 **실제 `AskTurnView`** 로 잰 값도 같다(라이트: hover 최대 채널차 3/255, 변한 픽셀 0.0% · focus 8/255. 다크: hover 8 · focus 24, 면이 얇아서 일부 비침; `a11y/widget/run1.log`, `run2.log`). 즉 **'안 보인다'는 느낌은 정확하며, 특히 라이트에서 심하다**(§1).
2. 그래서 **색 토큰만 바꾸면 안 되고** (P0) 잉크가 가려지지 않게 하는 구조 수정이 먼저다. 한 줄 수정(`Material(type: transparency)`를 카드 안에 삽입)으로 정상 세기로 돌아오는 것도 실측했다.
3. 질문(보내기) 버튼은 다른 문제다. 자체 Material이 있어서 hover/focus가 그려지지만 **M3 기본 상태층이 8~10% 흰색**이라 보라 위에서 거의 안 보이고(ΔL* 3.9~5.0, 명도비 1.15~1.20:1), **포커스 링이 없다.**
4. 기준안: **포커스 링 = 2px 단색 링 + 2px 간격, 색은 `ink`(라이트 `#1F1B16` / 다크 `#F2EDE3`)**. 보라가 아니다. 모든 표면에서 3:1을 넘는다(라이트 최소 11.3:1, 다크 최소 4.5:1). **hover = 6%, pressed = 12%**(라이트는 `ink`, 다크는 흰색 오버레이), 채움(보라) 버튼은 검정 8%/14%.
5. 구현 단위: ① **전역 테마**(`hoverColor`/`focusColor`/`splashFactory`/버튼 스타일 `overlayColor`/`mouseCursor`) ② **공통 위젯 `PbFocusRing` + `PbInteractive`**(커스텀 pill·행·토글용) ③ 구조 수정(Material 투명 삽입). ①만으로는 "링"이 안 생기고, ②만으로는 가려진 잉크가 안 살아난다. 셋은 같이 가야 한다.

---

## 1. 진단 — 왜 안 보이는가 (P0)

### 1.1 실측 (✅ 위젯 테스트 렌더, 픽셀 판독)

방법: Flutter 3.47.7 `flutter_test`로 앱과 같은 순서(`MaterialApp.builder`에서 배경 `ColoredBox(#F7E8EE)`가 Navigator·`Scaffold`(transparent, 자체 Material) **위가 아니라 아래**, `main.dart:63`의 `PbBackground`와 동일) 아래 `Container(색 0xBDFFFFFF = 앱의 glassStrong)` 구조를 만들고, 마우스 hover·키보드 포커스(`FocusHighlightStrategy.alwaysTraditional`) 상태에서 `RepaintBoundary.toImage`로 같은 점의 RGB를 읽었다. 테스트 파일 `probe/test/ink_test.dart`, `probe/test/pb_test.dart`(이 폴더, 저장소 아님).

| 케이스 | 구조 | rest | hover | focus | 결론 |
|---|---|---|---|---|---|
| A | `Container(glassStrong)` 안의 `InkWell` (적게 보기 · 출처 범위 pill · 모델 pill과 같은 구조) | (253,249,251) | **(250,247,248)** ΔL* 0.8 | **(245,242,243)** ΔL* 2.5 | 잉크가 면 뒤에 칠해져 26%로 감쇠 → 사실상 안 보임 |
| B | 같은 `InkWell`을 자체 `Material` 위에 | (253,249,251) | (243,239,241) ΔL* 3.5 | (222,219,220) ΔL* 10.6 | 기본값대로 그려짐(hover는 약함) |
| D | A 구조에 `Material(type: MaterialType.transparency)`만 끼움 | (253,249,251) | (243,239,241) | (222,219,220) | **한 줄 수정으로 B와 동일하게 복구**(감쇠 4.4배 → 1배) |
| C | `IconButton.filled` 보내기 버튼(보라 `#6C4CF5`, 앱 설정과 동일) | (108,76,245) | (120,90,246) | (123,94,246) | 그려지지만 약함: hover ΔL* 3.9 / 1.15:1, focus ΔL* 5.0 / 1.20:1, **링 없음** |

- B의 기본 hover는 ΔL* 3.5(명도비 1.09:1). 기본값이 원래 약하다: `ThemeData`가 `hoverColor`를 검정/흰색 **4%**, `focusColor`를 **12%**로 채운다(✅ SDK `theme_data.dart` 467-468행). 그래서 구조를 고쳐도 hover는 "있긴 한데 안 보이는" 수준이다 → 색 단계도 같이 올려야 한다(§3).
- 마우스 클릭은 포커스를 옮기지 않는다(✅ 테스트: `IconButton` 클릭 후 `hasFocus == false`). 따라서 `:focus-visible`에 해당하는 "클릭 때는 링이 없다"는 동작은 **Flutter가 이미 갖고 있고**, 키보드로 이동했을 때만 링이 나온다.
- 이 실측에서 **처음 하네스를 잘못 짰다**: 배경 `ColoredBox`를 `Scaffold` 안쪽에 둬 잉크를 완전히 덮었고 그 결과 'rest=hover=focus 동일'로 읽혔다. 배경을 앱과 같은 순서(Material 아래)로 고쳐 다시 재면 위 표의 A 값이 나오고, 이는 실제 위젯 측정과 일치한다. (정정 기록)
- `GlassPanel` 안(`BackdropFilter` blur 18 + glass 62%)에서는 감쇠가 더 커진다: 단순 합성으로 (1−0.62)×(1−0.74) ≈ 10%. BackdropFilter 자체의 영향은 미렌더(⚠️).
- 다크는 `glassStrong`이 14%뿐이라 잉크가 대부분 비친다(실위젯: hover 8, focus 24). 그래서 **문제는 라이트에서 가장 크고**, 다크는 "보이긴 하나 약하다"가 정확하다.

### 1.2 문제 예시와 그 외 위치 (코드 근거, ✅ 줄 번호는 현재 작업 트리)

| 위치 | 파일:줄 | 구조 | 증상 |
|---|---|---|---|
| 적게 보기 / N개 더 보기 | `ask_sources.dart:1135-1170` | 답변 카드(`ask_screen.dart:1047` `Container(glassStrong)`) 안 `InkWell`, 조상에 Material 없음 | hover·focus·splash가 26%로 감쇠 (케이스 A) |
| 출처 범위 pill ("내 문서 · 프로젝트 2") | `ask_screen.dart:587-623` | `GlassPanel(strong)` 안 `InkWell` > `Container(border, color)` | 위와 동일. 게다가 `empty`일 때는 자기 `Container`가 `warnContainer`로 칠해져 어떤 잉크도 가린다 |
| 모델 pill ("자동 ▾") | `ask_screen.dart:448-534` | `PopupMenuButton(child:)`는 child를 `InkWell`로 감싼다 → child의 `Container(chipBg 55% 흰색)`이 잉크를 가림. 모양도 사각(`borderRadius` 없음) | 위와 동일 + 열림/닫힘 상태 표시 없음 |
| 보내기 버튼 | `ask_screen.dart:379-392` | `IconButton.filled` (자체 Material) | 상태층 약함, 링 없음 (케이스 C) |
| 예시 질문 카드 | `ask_screen.dart:1232-1250` | 자체 `Material` + `InkWell` | 그려지지만 hover 4%·focus 12% 기본값이라 약하고 링 없음 |
| 보조 아이콘/텍스트 버튼 다수 | `IconButton`, `TextButton`, `ActionChip` 전역 | M3 기본 | 상태층만 있고 링 없음 |
| 사이드바 `_NavItem` | `main.dart:679-715` | `Material`+`InkWell` | 자체 Material이라 그려지지만 활성(보라 채움) 위 상태 구분이 약함 |
| `SourceRow` | `ask_sources.dart:750-760` | 자체 Material + `InkWell`, `onFocusChange`로 2px `accent` 테두리 | **이미 가장 잘 만든 예**. 단 ① 링이 보라(`accent`)라 인용 선택 링과 혼동 ② 다크에서 `accent #B7A6FF`가 답변 카드 스택 위 3.95:1, 인용 pulse 위 2.49:1(§3.2) ③ `onFocusChange`는 원시 포커스라 hover/키보드 모드를 구분하지 않음 |
| `CiteMarker` ⚡n | `ask_sources.dart:517-566` | `FocusableActionDetector.onShowFocusHighlight` (모드 인식) + `accent` 2px | 올바른 방식. 링 색만 바꾸면 된다 |
| 컴포저 입력창 | `ask_screen.dart:341-370` | `InputBorder.none` 3종 | **포커스 표시가 캐럿뿐** |

### 1.3 SDK에서 확인한 동작 (키보드 전용 링 규칙의 근거)

- `FocusManager`의 `FocusHighlightMode`: 키보드 이벤트 → `traditional`, 터치·스타일러스 → `touch`, **마우스는 모드를 바꾸지 않는다**(✅ `focus_manager.dart` `handlePointerEvent`: mouse 분기가 빈 case). 초기값은 플랫폼 기본(모바일 = touch, 데스크톱/웹 = traditional).
- `FocusableActionDetector`는 `onShowFocusHighlight`와 `onShowHoverHighlight`를 **모드가 traditional일 때만** 호출한다(✅ `actions.dart` 1274-1279, 1332-). 포커스 쪽은 CSS `:focus-visible`에 가장 가까운 장치라 링에 쓴다. **hover 쪽은 이 게이트가 단점**이다(아래). `InkWell`의 **포커스** 하이라이트도 같은 모드를 본다(`ink_well.dart` `updateFocusHighlights`)지만 **hover는 모드와 무관**하게 마우스 진입으로 그려진다(✅ 아래 Android 테스트에서 일반 `InkWell` hover는 그려졌다). 반면 `InkWell.onFocusChange`와 `WidgetState.focused`는 **원시 포커스**다(`ink_well.dart` `handleFocusUpdate` 주석).
- 결과: **`FocusableActionDetector.onShowHoverHighlight`로 hover를 그리면** 터치 기본 플랫폼(Android/iOS 웹·앱)에서 키보드가 안 눌린 동안 hover가 안 나온다. 같은 Android 설정에서 일반 `Material`+`InkWell`은 hover가 그려졌고(255→245) `FocusableActionDetector` 기반 스케치는 안 그려졌다(재현 ✅, `probe/test/mode_test.dart`; 이 하네스는 파일 안 전역 포커스 상태가 섞여 `highlightMode`가 traditional로 찍혀 '터치 기본 상태' 자체는 깨끗이 재현하지 못했다 ⚠️). **그래서 `PbInteractive`는 hover를 `MouseRegion`(onEnter/onExit)에서 받고, `onShowFocusHighlight`는 링에만 쓴다**(고친 뒤 같은 Android 설정에서 hover (255→224) 그려짐 ✅). 태블릿+마우스 사용자에게 회귀를 만들지 않으려는 규칙이다.
- 키보드로 포커스를 준 뒤 마우스로 옮겨 다녀도 링은 **포커스 노드에 남는다**(✅ 테스트 `ring band while hovering with focus kept`). 브라우저의 `:focus-visible`과 같은 동작이라 정상으로 본다.
- `MouseCursor`: 버튼류 기본값이 `WidgetStateMouseCursor.adaptiveClickable`인데 **웹에서만 `click`, 웹이 아닌 데스크톱에서는 `basic`(화살표)** 이다(✅ `widget_state.dart` 435-440). 웹 배포만 한다면 문제없고, macOS/Windows 데스크톱 빌드를 낸다면 명시가 필요하다.

---

## 2. 원칙 (6줄)

1. 상태는 **색만으로 전달하지 않는다**: 링(형태) + 틴트(색) + 아이콘/텍스트(선택 체크, 펼침 화살표 회전).
2. **보라(`accent`)는 ⚡ 인용 전용**(ab-glass-paper 규칙). 포커스·hover에 보라를 쓰지 않는다. 채움 버튼(보내기, 새 노트)의 면 색은 기존대로.
3. **포커스 링은 중립(ink)**, 모양은 컴포넌트 반경을 따르고, 간격 2px로 **표면과 컨트롤 사이에 숨 쉬는 틈**을 둔다. 링은 컨트롤 면이 아니라 **주변 표면** 위에 놓이므로 컨트롤 색(보라 채움 포함)과 상관없이 대비가 결정된다.
4. 같은 의미는 같은 값: hover 6%, pressed 12%, 링 2/2. 컴포넌트별 예외는 §5 표에 적은 것뿐.
5. 잉크(`InkWell` 스플래시)에 의존하지 않는 쪽으로 간다: 장식이 있는 커스텀 컨트롤은 **상태를 자기 `decoration` 색으로** 그린다(가려질 수 없다).
6. 모션은 120ms 이하, `disableAnimations`이면 즉시.

---

## 3. 토큰

새 토큰은 `Pb` 확장(또는 `ThemeExtension`)에 추가한다. 알파는 8비트 헥스까지 적었다. 계산 기준 표면은 `theme.dart` 값(라이트 glass `0x9E`=62%, glassStrong `0xBD`=74%, 다크 `0x14`=8%, `0x24`=14%)으로 **패널 위 카드 중첩(스택)** 까지 합성한 것이다(데스크톱에서 답변 카드는 Ask `GlassPanel` 위에 있다).

### 3.1 값

| 토큰 | 라이트 | 다크 | 용도 / 근거 |
|---|---|---|---|
| `focusRing` | `#1F1B16` (=`ink`) | `#F2EDE3` (=`ink`) | 키보드 포커스 링. 보라 아님 |
| `ringWidth` / `ringOffset` | 2 / 2 | 2 / 2 | 데스크톱·모바일 동일. 인라인 ⚡n pill만 offset 1 |
| `hover` | `ink` 6% = `0x0F1F1B16` | 흰색 6% = `0x0FFFFFFF` | 투명·파스텔·유리 면 위 hover 틴트. ΔL* 라이트 4.2~4.7 / 다크 4.0~6.2 |
| `press` | `ink` 12% = `0x1F1F1B16` | 흰색 12% = `0x1FFFFFFF` | 눌림 틴트. ΔL* 8.6~9.5 / 8.0~12.2 |
| `filledHover` | 검정 8% = `0x14000000` | 검정 8% = `0x14000000` | 보라 채움 위 hover(어둡게). 흰 글자 6.0:1 / 다크 `#251A63` 글자 5.98:1로 글자 대비가 오히려 올라간다 |
| `filledPress` | 검정 14% = `0x24000000` | 검정 14% = `0x24000000` | 보라 채움 눌림 |
| `disabledFg` | `ink` 38% = `0x611F1B16` | `ink` 38% = `0x61F2EDE3` | 비활성 글자·아이콘 (WCAG 비활성은 예외, M3 38%) |
| `disabledBg` | `ink` 8% = `0x141F1B16` | 흰색 8% = `0x14FFFFFF` | 비활성 채움 |
| `controlEdge` (선택) | `ink` 50% = `0x801F1B16` | `ink` 50% = `0x80F2EDE3` | 입력 필드 경계(1.4.11 3:1). §8 결정 3 |
| 선택 채움/글자 | `accentContainer` `#EAE4FD` / `onAccentContainer` `#2E1F85` | `#3A2F7A` / `#E9E3FC` | 기존 토큰 재사용. 글자 10.3:1 / 9.0:1 |
| `warnHover` | `warn` 8% | `warnText` 8% | 앰버 면(범위 비어 있음) hover |

### 3.2 포커스 링 대비 계산 (✅ `contrast_states.py`)

링은 간격 2px 때문에 **주변 표면**과만 맞닿는다. 따라서 아래 표면 전부에 대해 링 vs 표면 ≥ 3:1(WCAG 1.4.11 비텍스트, 2.4.13 기준)을 만족해야 한다.

| 표면 (합성값) | 라이트 `#1F1B16` | | 다크 `#F2EDE3` | |
|---|---|---|---|---|
| | 표면색 | 대비 | 표면색 | 대비 |
| 배경 그라데이션 3점 | `#EDE6FA` `#F7E8EE` `#FFE9DC` | 14.1~14.6 | `#1E1830` `#251C27` `#2A1F1C` | 13.7~14.7 |
| 블롭(최악) | `#DFD3FA` / `#FFDBC5` | 12.1~13.2 | `#2F235B` / `#483027` | 10.4~11.9 |
| 유리 패널 (glass) | `#F8F5FD`~`#FFF7F2` | 15.9~16.1 | `#302A40`~`#3B312E` | 10.9~11.8 |
| 답변 카드 스택 (glassStrong over glass) | `#FDFDFF`~`#FFFDFC` | 16.4~16.9 | `#4D485B`~`#564E4B` | 7.0~9.1 |
| 노트 파스텔 5색 | `#FFF1B8` … `#E9E3FC` | 13.3~15.1 | `#463E22` … `#342C58` | 9.1~10.9 |
| PDF 종이 | `#FFFFFF` | 17.1 | `#2A2620` | 12.9 |
| `accentContainer` 선택 칩 | `#EAE4FD` | 13.9 | `#3A2F7A` | 9.6 |
| 인용 칸: citeFill / **citePulse** 위 | `#ECE7FC` / `#D6CCFB` | 14.2 / **11.3 (라이트 최소)** | `#61586C` / `#716788` | 5.8 / **4.5 (다크 최소)** |
| 팝업 시트 | `#FEFAF8` | 16.5 | `#28202F` | 13.4 |
| **전체 최소** | | **11.3 : 1** | | **4.5 : 1** |

비교 후보의 전체 최소 대비(같은 표면 목록):

| 후보 | 라이트 최소 | 다크 최소 | 판정 |
|---|---|---|---|
| ink (`#1F1B16` / `#F2EDE3`) | 11.27 | 4.52 | **채택** |
| 슬레이트 `#33415C` / `#C3D2EE` (앱의 `selection` 계열 색상) | 6.74 | 3.46 | 통과하나 다크 여유 적고, 선택 영역 색과 닮음 |
| `selection` 원색 `#44546F` / `#9FB4D6` | 5.04 | **2.50** | 다크 실패 |
| accent `#6C4CF5` / `#B7A6FF` (현재 `SourceRow`·`CiteMarker`·입력창) | 3.47 | **2.49** | **다크 실패**, 라이트도 인용 pulse 위 마진 0.5 |
| `onAccentContainer` `#2E1F85` | 8.38 | – | 라이트만 통과, 보라 계열이라 혼동 |

- 보라와의 구분: 링 색상 hue는 ink = 33°(웜 뉴트럴) vs accent 251°이고, 모양도 다르다. 인용 표시는 **3px 좌측 레일(`citeEdge`) + 12% 면**, 포커스는 **컨트롤 전체를 두르는 2px 폐곡선**이다. ink 링 vs accent 레일의 명도비는 3.25:1(라이트)이라 나란히 있어도 서로 구별된다.
- 링이 **보라 채움 버튼 위**에 놓이지 않는 이유: 간격 2px 때문이다. 링을 컨트롤 안쪽(inset)으로 그리면 ink vs 보라가 3.25:1(라이트, 간신히), 다크는 `#F2EDE3` vs `#B7A6FF` = **1.82:1(실패)** 이다. **채움 보라 위 inset 링 금지**(규칙 R3).

### 3.3 hover/pressed 강도 후보 (✅ `tints.py`, ΔL* = CIE L* 차)

| 후보 | 라이트 ΔL* (유리·파스텔) | 다크 ΔL* | 글자 영향 | 평가 |
|---|---|---|---|---|
| H0 기본 (Flutter 4%) | 2.9~3.1 | 2.7~4.2 | ink 12.7 / 5.6 | 지금 불만의 정체. 구조를 고쳐도 약함 |
| **H1 6% (추천)** | 4.3~4.7 | 4.0~6.2 | ink ≥ 12.2 / muted 5.4 (라이트) | 보이되 면을 오염시키지 않음. 파스텔 카드 위 4.2~4.5 |
| H2 8% | 5.7~6.3 | 5.4~8.2 | ink 11.7 / muted 5.2 | 유리 위 유리 중첩이 많은 곳(컴포저)에 쓸 수 있는 상한 |
| H3 12% | 8.6~9.5 | 8.0~12.2 | ink 10.8 / muted 4.8 | 눌림 단계와 구분이 사라짐. 호버로는 과함 |

- 다크에서 `inkMuted`(`#B5AD9F`)는 hover 6% 위 2.6:1까지 내려간다. 다만 **기본 상태에서 이미 데스크톱 답변 카드 스택 위 3.8:1(⚠️ 합성 계산, 블러 미반영)** 로 4.5 미달이므로 hover 때문이 아니라 별도 이슈다(§8 결정 5).
- 보라 채움: 흰색을 얹는 M3 기본(hover 8%)은 글자 대비를 라이트 4.57:1까지 깎는다. **검정을 얹어 어둡게** 하면 6.0~6.4:1로 오히려 올라가서 hover가 보이면서 안전하다.

---

## 4. 상태 규칙

### 4.1 포커스 링

| 항목 | 값 |
|---|---|
| 모양 | 컨트롤 모서리 반경 + (offset + width)의 폐곡선. pill/원은 pill/원 |
| 두께 / 간격 | 2px / 2px(바깥). 인라인 ⚡n pill만 간격 1px(줄간 침범 방지) |
| 색 | `focusRing` (ink). 어떤 컨트롤의 면 색과도 독립 |
| 표시 조건 | 키보드 모드(`FocusHighlightMode.traditional`)에서 포커스를 가진 동안만. 마우스 클릭에는 포커스가 안 옮겨져 링이 안 생긴다(✅). **텍스트 입력은 예외로 클릭에도 표시**(브라우저 관례, §4.7) |
| 전환 | 즉시(0ms). 링은 "위치 신호"라 페이드하지 않는다 |
| 겹침 | 호버 틴트·선택 채움과 **공존**한다(링은 틴트 위에 그려지고 그 안을 건드리지 않음) |
| 클리핑 | 링은 바깥으로 4px 나간다 → 조상의 `ClipRRect`/스크롤 뷰포트에 닿는 컨트롤은 부모에 ≥4px 패딩. 불가피하면 **inset 링**(안쪽 2px)을 허용하되 **채움 보라·accentGradient 위에서는 금지** |
| z-order | 인용 선택 링(레인보우 링)·`SourceRow` 그림자보다 **위**. 선택 + 포커스가 겹쳐도 중립 링 + 2px 틈이라 구분된다 |
| 고대비(`MediaQuery.highContrast`) | 두께 3px, hover 10% |

**링 스타일 후보 비교**

| 후보 | 설명 | 장점 | 단점 |
|---|---|---|---|
| **A. 단색 링 + 간격** (추천) | 2px `ink` + 2px 틈 | 표면 무관 3:1 이상(§3.2), 컨트롤 색과 독립, 보라 채움 버튼 위에서도 안전, 구현이 단순(데코 박스 1개) | 바깥 4px 공간 필요(클리핑, 칩 줄간격 `runSpacing` 4→8) |
| B. 이중 링 | 안쪽 흰색(라이트)/어두운색(다크) 2px + 바깥 `ink` 2px | 임의의 사진·미지의 배경 위에서도 보장 | 우리 표면은 전부 알려진 파스텔/유리/그라데이션이라 과잉. 두꺼운 인상(총 4px)으로 부드러운 글라스 미감을 해침, 위젯 2겹 |
| C. 배경 틴트 + 밑줄 | 12% 틴트 + 2px 밑줄 | 텍스트 링크·메뉴 행에 자연스러움, 클리핑 문제 없음 | 틴트는 대비 1.2:1 수준이라 단독으로는 2.4.13(3:1)을 못 채움. 아이콘/pill에는 밑줄이 어색 |
| D. 보라 링(현행 계열) | 2px `accent` | 브랜드 일관 | 인용과 혼동, 다크 2.49:1 실패, 인용 pulse 위 마진 부족 |

> 추천 = **A**, 단 텍스트 링크·메뉴 행에는 **C를 보조로** 허용(링 대신 inset 링 2px + 틴트 12%). 입력창은 §4.7.

### 4.2 hover (마우스·트랙패드 전용)

| 항목 | 값 |
|---|---|
| 틴트 | `hover`(6%). 채움 보라는 `filledHover`(검정 8%) |
| 커서 | `SystemMouseCursors.click` **명시**(웹은 기본이 click이나 데스크톱 빌드는 화살표) |
| 전환 | 120ms `easeOut` 진입 · 120ms 이탈. `disableAnimations`면 0 |
| 카드 | 틴트 대신 **그림자 한 단계 + 외곽선 `ink` 10% → 22%**(카드 면 색 유지, ui-polish §2.1·§5.3). translate 금지 |
| 보조 단서 | 칩/pill: 테두리 `hairline` → `ink` 28%. 텍스트 버튼: 밑줄은 hover에서만 켜지 않는다(hover가 없는 터치/키보드에 정보가 없어지므로) — 대신 chevron·아이콘이 이동/회전 |
| 터치 기기 | hover 없음. Flutter가 마우스·트랙패드 포인터에서만 hover를 호출하므로 **고착(sticky hover)은 생기지 않는다**. 터치는 pressed로만 피드백 |
| 구현 규칙 | hover는 **`MouseRegion`** 으로 받는다. `FocusableActionDetector.onShowHoverHighlight`는 키보드 모드 게이트가 있어 태블릿+마우스에서 hover가 빠진다(§1.3) |

### 4.3 pressed

| 항목 | 값 |
|---|---|
| 틴트 | `press`(12%). 채움 보라 `filledPress`(검정 14%) |
| 스케일 | 소형 컨트롤(아이콘·칩·pill·보내기) 0.97 → 80ms `easeOut`, 놓으면 120ms 복귀. 카드·행 0.985(ui-polish §6과 동일). 모션 축소면 스케일 생략, 틴트만 |
| 스플래시·눌림 틴트 | **터치**(Android/iOS): ripple 유지, `splashColor` = `press`, `highlightColor` = 투명. **데스크톱·웹**: `NoSplash` + **`highlightColor` = 6%**(hover와 겹쳐 ≈11.6% ≈ `press`). `InkWell`의 눌림 하이라이트는 `highlightColor`가 담당하므로 투명으로 두면 데스크톱에서 눌림 피드백이 사라진다(✅ macOS 프로브: `highlightColor` 투명 → 눌렀을 때 hover 6% 값만 (242,242,241), `highlightColor`=12% → (216,216,214) 로 hover 위에 겹침) |
| 취소 | 스크롤 시작·포인터 이탈 시 즉시 해제(`onTapCancel`) |

### 4.4 disabled

| 항목 | 값 |
|---|---|
| 시각 | 글자·아이콘 `disabledFg`(38%), 채움 `disabledBg`(8%). 테두리는 유지(형태 단서). 전체 `Opacity` 0.55를 쓰는 곳(ui-polish §5.3)은 위 값으로 통일 — `Opacity`는 자식 레이어를 만들고 섹션 위계를 흐려서 |
| 커서 | `basic`. 금지 커서(`forbidden`)는 쓰지 않는다 |
| 포커스 | 포커스 불가(Flutter 기본). 비활성 사유를 알려야 하면 비활성 버튼 대신 **활성 + 안내**로 설계(예: 빈 입력에서 보내기를 눌렀을 때 입력창으로 포커스 이동) 또는 `Semantics(hint:)` |
| 스크린리더 | `onPressed == null` → 자동으로 `enabled: false`. 사유가 있으면 `Semantics(hint:)` (예: "질문을 입력하면 보낼 수 있어요") |
| 대비 | WCAG 비활성 예외. ink 38%의 실제 대비는 2.4:1 — 읽혀야 하는 정보는 비활성 글자에 두지 않는다 |

### 4.5 선택됨 / 토글 조합 (칩·토글·드롭다운 항목·세그먼트)

| 선택 | 호버 | 포커스(키보드) | 눌림 | 결과 |
|---|---|---|---|---|
| ✗ | ✗ | ✗ | ✗ | 기본 면 + `hairline` |
| ✗ | ✓ | – | – | + `hover` 틴트, 테두리 `ink` 28% |
| ✗ | – | ✓ | – | + 링 (틴트 없음) |
| ✓ | ✗ | ✗ | ✗ | `accentContainer` + 테두리 `accent` 55% + **체크 아이콘** + 글자 `onAccentContainer` |
| ✓ | ✓ | – | – | 선택 채움 위 `hover` 6% (글자 9.2:1 / 7.6:1) |
| ✓ | – | ✓ | – | 선택 채움 그대로 + 링 |
| ✓ | – | – | ✓ | 선택 채움 위 `press` 12% (글자 8.1:1 / 6.4:1) + 스케일 0.97 |
| 아무 | – | – | – | 비활성이면 위 전부 무시, `disabledFg` |

- **선택은 체크(또는 `expanded` 화살표 회전)로 반드시 이중 표시**한다. 선택 칩 테두리 `accent` 55%는 칩 면 대비 2.1:1(라이트)~2.7:1(다크)이고 채움도 면 대비 1.2:1이라 **색·테두리만으로는 3:1을 못 채운다**. 체크 아이콘(`onAccentContainer`, 10.3:1)이 비색 단서이자 대비 충족 수단이다. → `ChoiceChip.showCheckmark: true`(현행 유지) + 선택 시 `Semantics(selected: true)`.
- 선택은 포커스를 대체하지 않는다. 포커스 링은 선택 여부와 무관하게 같다.
- 드롭다운 항목(메뉴 행): 선택 항목은 체크 + 글자 w600, 시각 외 정보로 `Semantics(selected: true)`.

### 4.6 모션 축소 · 고대비 · 텍스트 확대

| 조건 | 처리 |
|---|---|
| `MediaQuery.disableAnimationsOf` | hover/pressed 전환 0ms, 스케일 생략, chevron 회전 즉시, ripple 없음. (웹은 `prefers-reduced-motion`이 이 플래그로 매핑됨 ⚠️ 미확인) |
| `MediaQuery.highContrastOf` | 링 3px, hover 10%, `hairline` → `controlEdge` |
| 텍스트 확대 | 히트 영역은 `minHeight`로 정의해 글자 크기에 따라 늘어난다. 고정 `height` 금지 |
| 강제 색상(Windows 고대비) | Flutter 웹은 미지원(⚠️). 링이 `outline`이 아니라 페인트라 사라질 수 있음 — 알려진 한계로 기록 |

### 4.7 입력창

| 항목 | 값 |
|---|---|
| 일반 `TextField` (로그인·링크·다이얼로그) | 기본 `controlEdge`(선택, §8-3) 1px → 포커스 시 **2px `focusRing`**. 클릭·키보드 모두 표시(입력은 어떤 방식으로든 포커스가 있음을 알려야 한다). 현행 `focusedBorder` 2px `accent`는 **링 언어로 통일하면 ink 2px**로 변경(결정 2) |
| 컴포저(Ask 하단 패널, `InputBorder.none`) | 포커스 시 **패널 전체에 2px `focusRing`을 inset 으로**(패널은 부모 패딩 12px 안이라 outset도 가능). `Focus(canRequestFocus:false, onFocusChange)`로 하위 입력 포커스를 감지(focus-within). 현재는 캐럿만이라 포커스가 어디인지 알 수 없다 |
| 비활성(`limitReached`) | `disabledBg` + `disabledFg` 힌트 |
| 커서 | `text` |

### 4.8 터치 영역 크기

| 기준 | 값 | 해당 |
|---|---|---|
| WCAG 2.5.8 (AA) | 24×24 이상(또는 간격으로 대체) | 최소선. 데스크톱 32/36은 통과 |
| WCAG 2.5.5 (AAA) | 44×44 | 권장 목표 |
| Material | 48dp | `MaterialTapTargetSize.padded` 기본 |

**정책**: 모바일(<600)·태블릿(600–1024)은 **히트 영역 44×44 이상**(시각 크기는 32/40이어도 됨; 이미 `IconButton`은 48 패딩). **데스크톱(>1024)은 36×36까지 허용**(포인터 정밀, 요소 사이 ≥8px). 어느 쪽이든 **시각 크기가 히트 영역보다 작으면 히트는 투명으로 확장**하고, 링은 **시각 크기 기준**으로 그린다(히트 영역이 아니라). 현재 위반/주의: `_Button`(cite_bar) 36×36(데스크톱 OK, 모바일 보강), `CiteMarker` 히트 ~34×18(24 AA는 통과, 44 미달 — 인라인 한계로 AAA 예외 기록), `_FreeBadge` 비상호작용이라 해당 없음.

---

## 5. 컴포넌트 분류별 적용 명세

공통: 링 = `focusRing` 2/2 바깥. "—"는 해당 없음. 틴트는 §3.1. 시각 값은 라이트/다크 순.

### 5.1 기본(채움) 버튼 — `FilledButton`, FAB, 보내기, 새 노트

| 상태 | 값 |
|---|---|
| 기본 | 면 `accent` `#6C4CF5` / `#B7A6FF`, 글자 `onPrimary` 흰색 5.26:1 / `#251A63` 7.05:1. 그라데이션 면(`accentGradient`)은 끝 색 `#8F6BFF`에서 흰 글자 3.67:1이므로 **버튼 글자는 큰 글자(≥18.66px 굵게/24px)가 아니면 `#6C4CF5` 평면을 쓴다** (⚠️ 사용처 확인 필요) |
| hover | + `filledHover`(검정 8%) → `#6346E1` / `#A899EB`. 그림자 y +1 |
| focus | 링(바깥, offset 2). 면 변화 없음 |
| pressed | + `filledPress`(검정 14%), 스케일 0.97(소형) / 0.985(큰 버튼), 80ms |
| disabled | 면 `disabledBg`, 글자 `disabledFg`, 그림자 없음 |
| selected | — |
| 크기 | 높이 44(모바일) / 40(데스크톱 허용 36), 반경 14 |

### 5.2 보조 버튼 — `OutlinedButton`, ghost

| 상태 | 값 |
|---|---|
| 기본 | 면 `chipBg`(55% 흰 / 5% 흰) + 1px `hairline`, 글자 `ink` w600 |
| hover | + `hover`, 테두리 `ink` 28% |
| focus | 링 |
| pressed | + `press`, 스케일 0.97 |
| disabled | 면 투명, 테두리 `hairline`, 글자 `disabledFg` |
| 경고형(재색인) | 테두리 `warnBorder`, 글자 `warnText`; hover = `warnHover`(warn 8%: 글자 5.75:1 유지) |
| 크기 | 높이 40(36 컴팩트) |

### 5.3 텍스트 버튼 · 링크 — `TextButton`, `_InlineLink`

| 상태 | 값 |
|---|---|
| 기본 | 글자 `ink`(앱 본문 링크는 `linkInk`: 라이트 `#2E1F85` 12.5:1, **다크 `#B7A6FF` 는 답변 카드 위 3.95:1이라 13px에서 미달 → 답변 카드 안에서는 `ink` 사용**), w600 |
| hover | 면 `hover`(반경 10) + 화살표/아이콘 보조 이동 |
| focus | 링(반경 10). 한 줄 텍스트는 간격 offset 1~2 |
| pressed | 면 `press` |
| disabled | 글자 `disabledFg` |
| 크기 | 히트 44(모바일)/36(데스크톱) 높이, 가로 패딩 8~12 |

### 5.4 아이콘 버튼 — `IconButton`, 닫기, ⋯, 복사

| 상태 | 값 |
|---|---|
| 기본 | 아이콘 `inkMuted`(라이트 `#5C5348` 7:1) / 다크 `#B5AD9F`, 투명 면 |
| hover | 원형 `hover` 틴트(지름 36~40), 아이콘 `ink` |
| focus | 링(원형, 시각 36~40 기준) |
| pressed | 원형 `press`, 스케일 0.97 |
| disabled | 아이콘 `disabledFg` (`cite_bar`의 `color.withValues(alpha: 0.35)` 는 0.38로) |
| 크기 | 시각 36~40, 히트 48(모바일)/40(데스크톱). **툴팁 필수**(§7.4) |
| selected(토글형) | `accentContainer` 면 + `onAccentContainer`; 서식 도구줄(`FormatButton`)과 동일 |

### 5.5 칩 — 예시 질문 · 인용 · 필터 · 범위

| 상태 | 필터/범위 칩 (`ChoiceChip`·`ActionChip`) | 예시 질문 카드 (`_SuggestionCard`) | 인용 칩 (`SourceRow`) |
|---|---|---|---|
| 기본 | `chipBg` + `hairline` 1px, 글자 13/500 `ink` | `chipBg` + `hairline`, 반경 14, 글자 `ink` | 현행 `rowFill` + `rowBorder` |
| hover | + `hover`, 테두리 `ink` 28% | 동일 | 현행 `rowHover`(유지) + 칩 ›아이콘 `accent` → **`ink`** (보라 한정) |
| focus | 링 | 링 | 현행 2px `accent` 테두리 → **링(ink)** 로 교체, 레인보우 링보다 위 |
| pressed | + `press`, 0.97 | + `press`, 0.985 | 현행 `rowPress` |
| disabled | `disabledBg`/`disabledFg` | — | — |
| selected | `accentContainer` + `accent` 55% 테두리 + **체크** | — | 선택(pick) 상태는 현행 레인보우 링 유지; 접근성 상태는 `Semantics(selected:)`(현행) |
| 크기 | 시각 32, 히트 44/36 | 최소 44 | 최소 44(현행) |

- 줄바꿈하는 칩 행은 **`runSpacing` ≥ 8**(링 4px 바깥 확보). 현행 `_ChatBar`의 `runSpacing: 4`는 8로.

### 5.6 드롭다운 · 팝업 메뉴 — 출처(범위) pill, 모델 pill

pill: 높이 32(시각), 히트 44/36, 반경 16, 글자 13/500, 오른쪽 chevron 18.

| 상태 | pill | 메뉴 패널 | 메뉴 행 |
|---|---|---|---|
| 기본 | `chipBg` + `hairline`, 글자 `ink`, chevron `inkMuted` | 면 `sheet`(라이트 `#FEFAF8` / 다크 `#28202F`), 반경 14, 그림자 `glassShadow` | 높이 44(터치)/36(데스크톱), 패딩 12, 글자 13 |
| hover | + `hover`, 테두리 `ink` 28% | — | 행 `hover` |
| focus | 링 | 첫 항목(또는 선택 항목)에 포커스 | 행 **inset 링** 2px + 틴트 12%(링이 패널 밖으로 잘리지 않게 inset) |
| pressed / 열림 | `press` 유지 + chevron **180° 회전**(160ms, 모션 축소면 즉시) + `Semantics(expanded: true)` | 열림 | 행 `press` |
| disabled | `disabledBg`/`disabledFg` | — | `disabledFg`(비활성 항목 `재색인` 등) |
| selected | — | — | 체크 18 + 글자 w600 + `Semantics(selected: true)` |
| 경고(범위 없음) | 면 `warnContainer`, 테두리 `warnBorder`, **글자·아이콘 `warnText`**(현행 `warn`은 4.51:1로 간신히, hover 시 4.07:1 미달), hover = `warnHover` | — | — |

- **구현상 필수**: pill은 자기 `decoration`을 가지므로 `InkWell` 잉크가 아니라 **상태를 decoration 색에 직접 반영**한다(§7 `PbInteractive`). 이래야 가려지지 않는다.
- 접근성 이름: "답변 모델: 자동" 처럼 **이름 + 현재 값**을 한 노드로 묶는다. 현재는 `Tooltip`(`answerModel`)이 이름이고 값 텍스트가 같은 노드에 합쳐질지는 ⚠️ 스크린리더 확인 필요.

### 5.7 토글 · 체크 — 내 문서/프로젝트 (`CheckboxListTile`), 설정 라디오

| 상태 | 값 |
|---|---|
| 기본 | 박스 18, 1.5px `ink` 50% 테두리(3:1), 행 전체가 탭 영역(높이 ≥ 48) |
| hover | 행 `hover`(반경 12) + 박스 주변 원형 상태층 |
| focus | 행 링(inset 2px, 시트 가장자리 클리핑 방지) |
| pressed | 행 `press` |
| disabled | 박스·글자 `disabledFg` |
| selected | 박스 채움 `accent`/`#B7A6FF` 위 체크 `onPrimary`. **보라는 선택 표시이므로 허용**(채움 면 규칙: 선택 칩과 같음) — 단 체크 마크로 이중 표시 |
| 스크린리더 | `Semantics(checked:)` 자동. 부제(`onlyYou`)는 같은 노드에 묶음 |
| 테마 | `checkboxTheme`/`radioTheme`/`switchTheme`의 `overlayColor`, `side`(WidgetStateBorderSide)로 전역 처리 가능 |

### 5.8 리스트 행 · 카드 — 노트/PDF 카드, 대화 목록, 설정 `ListTile`, 프로젝트 행

| 상태 | 노트·PDF 카드 | 리스트 행 (`ListTile`, 대화 목록) |
|---|---|---|
| 기본 | 자기 파스텔/종이 색 유지, 1px `ink` 10%, 그림자 y2 blur8 6% | 투명 |
| hover | **면 색 유지**, 그림자 y6 blur16 10%, 외곽선 `ink` 22%(120ms). 카드는 `Card` 자체가 Material이라 잉크가 보인다 — 틴트는 쓰지 않음 | 행 `hover`(반경 12) |
| focus | 링(바깥, 반경 16+4). 그리드 gap 12/16이라 클리핑 없음 | inset 링 2px (리스트 가장자리) |
| pressed | 스케일 0.985, 그림자 rest 로 복귀, 80ms | 행 `press` |
| disabled | 불투명도 대신 `disabledFg` 글자 + 카드 `disabledBg` | `disabledFg` |
| selected | 열려 있는 항목: 선택 채움이 아니라 **좌측 3px 레일은 쓰지 않음**(인용 레일과 혼동) → `ink` 28% 외곽선 | 같은 규칙 |
| 중첩 | 카드 안 ⋯(`PopupMenuButton`)은 카드 `InkWell` 안에 있으므로 포커스 순서 = 카드 → ⋯, 카드 링과 ⋯ 링은 서로 겹치지 않게 ⋯ 히트 40 유지 |

### 5.9 탭 · 세그먼트 · 내비 — 라이브|소스 `SegmentedButton`, 하단 내비, 레일, 사이드바

| 상태 | 값 |
|---|---|
| 기본 | 세그먼트: 투명 + `hairline`; 선택 세그먼트: `accentContainer` + 체크 생략(`showSelectedIcon:false`) → **글자 w600 + `Semantics(selected:)`** 로 이중 표시 |
| hover | `hover` 틴트 |
| focus | 세그먼트 단위 링(inset 2, 세그먼트 경계 겹침 방지) / 내비 항목 링(바깥) |
| pressed | `press` |
| disabled | `disabledFg` |
| selected (내비) | 현행: 아이콘·라벨 `accent` + `accentContainer` indicator (사이드바 `_NavItem`은 보라 채움 + 흰 글자). 상태 겹침: 활성 + hover → `filledHover`, 활성 + focus → 링 |
| 키보드 | 좌우/상하 화살표 이동 + Enter/Space 활성(레일은 기본 제공, 커스텀 `_NavItem`은 ⚠️ 확인) |

### 5.10 입력창 — §4.7 참조 (컴포저, 검색, 폼)

---

## 6. 문제 예시 세 가지 — 현황과 개선

### 6.1 '적게 보기' / 'N개 더 보기' 토글 (`ask_sources.dart:1127-1171`)

**현재 (코드 + 실측)**

| 항목 | 상태 |
|---|---|
| hover / focus / splash | 케이스 A: 답변 카드 `Container(glassStrong)`가 잉크를 덮어 **세기 26%로 감쇠**(라이트 hover ΔL* 0.8, focus 2.5). 실위젯 측정도 라이트 hover 변한 픽셀 0.0% |
| 시각 단서(affordance) | 글자 `ink` 13/600 + chevron 16뿐. 링크색도 밑줄도 없어 **일반 텍스트처럼 보인다** |
| 키보드 | 포커스는 가지만 표시가 없다 |
| 크기 | 높이 44는 충족. 폭은 글자 + 8px라 좁다(히트 폭 ≈ 글자 폭) |
| 접근성 이름 | `Semantics(button, expanded, label: 적게 보기 / N개 더 보기)` — 보이는 글자와 이름 일치 ✅ |
| 펼침 시 | chevron이 `RotatedBox`로 **즉시** 뒤집힘 |

**개선**

| 항목 | 값 |
|---|---|
| 구조 | `Material(type: transparency)`를 답변 카드 `Container` 안에 한 번 삽입(P0) **또는** 이 토글을 `PbInteractive`로 교체 |
| 모양 | 글자 `ink` 13/600, chevron 16. 가로 패딩 10 → 면 pill 반경 10, 높이 44(모바일)/36(데스크톱) |
| hover | 면 `hover` 6%(120ms), chevron이 방향으로 1px 이동 |
| focus | 링: `focusRing` 2px, offset 2, 반경 10+4 |
| pressed | 면 `press` 12% + 스케일 0.98 80ms |
| 펼침/접힘 | chevron 160ms 회전(모션 축소면 즉시), `Semantics(expanded:)` 유지 |
| 색 | 보라 쓰지 않는다(답변 카드 안에 ⚡n pill이 있어 혼동 방지) |
| 아래 간격 | 다음 요소(복사 버튼)와 링이 겹치지 않게 ≥ 8px (현행 12) |

### 6.2 '출처 · 자동' 드롭다운 (`_ScopeButton`, `_ModelPill`)

**현재**

| 항목 | 출처(범위) pill | 모델(자동) pill |
|---|---|---|
| hover/focus | 케이스 A로 감쇠. `empty`(범위 없음)일 때는 `warnContainer`가 불투명이라 잉크가 **완전히** 가려짐 | `PopupMenuButton` child의 InkWell이 사각이고 `chipBg`(55% 흰)에 감쇠 |
| 열림 표시 | 시트가 열리므로 pill은 변화 없음 | 메뉴가 열려도 pill/chevron 변화 없음 |
| 글자 대비 | `empty`: `warn #B45309` on `#FEF3C7` = **4.51:1(간신히)**, hover 틴트 시 4.07:1 | 13/500 `ink` OK; `_FreeBadge` 10.5px는 spec 최소 11 미달 |
| 접근성 이름 | `Tooltip(scope)` + 글자 | 메뉴 항목의 선택 상태가 **체크 아이콘만**. 실제 웹 DOM을 다른 엔지니어가 점검한 결과(`a11y/data/popups.json`) 모델 메뉴 8개 항목은 `role=menuitem`이고 `checked`/`selected`가 **전부 비어 있어** 스크린리더가 현재 선택을 알 수 없다 ✅ |
| 반경 | 16 | pill 16 (InkWell 영역은 사각) |

**개선** — §5.6 표 그대로. 요점:
1. pill을 `PbInteractive`로 만들어 hover·pressed를 **자기 decoration 색**으로 그린다(가려질 수 없음), 링은 pill 모양.
2. 열림 상태: `press` 유지 + chevron 180° + `Semantics(expanded:)`, 이름은 "범위: 내 문서 · 프로젝트 2", "답변 모델: 자동".
3. 모델 메뉴는 `PopupMenuButton` 유지 가능(`popupMenuTheme`: 색 `sheet`, 반경 14, 행 hover/focus는 전역 `hoverColor`/`focusColor`가 처리)하되, 트리거를 `PbInteractive`로 바꾸려면 **`MenuAnchor` + `MenuItemButton`** 으로 이전(`ab-glass-paper/spec.md` 5.5가 이미 `MenuAnchor` 지정). 이때 Escape 닫기 후 포커스가 트리거로 돌아오는지 ⚠️ 확인 필요.
4. `empty` 경고형은 글자·아이콘 `warnText`(6.37:1)로, hover는 `warnHover`.
5. 선택 항목: 체크 + w600 + `Semantics(selected: true)`, 체크 아이콘은 `ExcludeSemantics`.

### 6.3 질문(보내기) 버튼과 예시 질문 (`ask_screen.dart:379-392`, `_SuggestionCard`)

**현재**

| 항목 | 보내기 버튼 | 예시 질문 카드 |
|---|---|---|
| hover | 보라 위 흰색 상태층이라 (108,76,245) → (120,90,246): ΔL* 3.9, **1.15:1** | `chipBg` 위 기본 4%: ΔL* ≈ 3 |
| focus | → (123,94,246): ΔL* 5.0, 1.20:1, **링 없음** | 기본 12% 틴트만 |
| pressed | 동일 값(123,94,246) → hover/focus/pressed 구별 불가 | 기본 |
| disabled | `hairline` 면 + `inkMuted` 아이콘(유리 위 1.33:1, 비활성이라 예외이나 "죽은 버튼"으로 읽힘) | — |
| 크기 | 시각 40, 히트 48(M3 padded) ✅ | 최소 높이 44 ✅ |
| 이름 | `tooltip: askTooltip` → 이름 OK | 텍스트 |
| 키보드 | 포커스 가능 (보라 위 12% 흰색으로는 위치 불명) | 링 없음 |

**개선**

| 항목 | 보내기 버튼 | 예시 질문 카드 |
|---|---|---|
| 기본 | 원 40, 면 `accent`/`#B7A6FF`, 아이콘 `onPrimary` | `chipBg` + `hairline`, 반경 14 |
| hover | `filledHover`(검정 8%) → `#6346E1`/`#A899EB`, ΔL* 3.6/5.3 | `hover` 6% + 테두리 `ink` 28% |
| focus | **링 2px ink, offset 2** (패딩 12 안에서 클리핑 없음) | 링 반경 14+4 |
| pressed | `filledPress`(검정 14%) + 스케일 0.94 80ms | `press` + 0.985 |
| disabled | `disabledBg`(ink 8%) + 아이콘 `disabledFg`, 커서 basic, `Semantics(hint: 질문을 입력하면 보낼 수 있어요)` | — |
| 전송 중(`_blocked`) | 스피너 아이콘으로 교체(상태 전달), `Semantics(liveRegion)` 대신 기존 `SemanticsService.sendAnnouncement`(ask_screen.dart:69) 유지 | — |
| 기타 | 입력 포커스 시 컴포저 패널에 링(§4.7) → 키보드 사용자가 "입력 → 보내기" 순서를 시각으로 추적 | 제안 카드 순서 = 시각 순서 |

---

## 7. 구현 단위와 우선순위

### 7.1 우선순위

| 순위 | 항목 | 효과 | 비용 | 비고 |
|---|---|---|---|---|
| **P0** | 구조: 가려지는 잉크 수정 — `GlassPanel` 채움 안과 답변 카드 `Container` 안에 `Material(type: MaterialType.transparency)` 삽입(또는 `Ink`/`PbInteractive` 사용) | 적게 보기·범위·모델 pill·그 외 `InkWell` 전부 복구 | S | ✅ 실측 D. 색 토큰보다 먼저. ⚠️ `Material`은 하위에 `DefaultTextStyle`(`bodyMedium`)을 씌우므로 삽입 후 `GlassPanel`·답변 카드 안 글자 스타일이 바뀌지 않았는지 확인(Scaffold의 Material 아래라 대개 no-op) |
| **P0** | 전역 테마: `hoverColor` 6%, `focusColor` 투명(링이 담당), `splashFactory`, 버튼 스타일 `overlayColor`/`mouseCursor`, `popupMenuTheme`, `listTileTheme` | 기본 위젯 hover/pressed 일괄 | S | §7.2 |
| **P1** | `PbFocusRing`(+ `PbInteractive`) 공통 위젯 + 보내기·토글·pill·예시 질문·칩·아이콘 버튼·카드·내비 적용 | 키보드 사용자 포커스 위치 | M | §7.3 |
| P1 | 컴포저 focus-within 링, 입력 `focusedBorder` ink 2px | 입력 위치 | S | |
| P2 | 모델 pill `MenuAnchor` 이전, `Semantics(expanded/selected)` 정리, `_NavItem` 키보드 | 의미·구조 | M | |
| P2 | `SourceRow`·`CiteMarker` 링 ink 교체 + `onShowFocusHighlight` 통일 | 일관성, 다크 3:1 | S | 아래 §7.5 결정 |
| P3 | 고대비·모션 축소 점검, 포커스 골든 테스트 | 회귀 방지 | S | |

### 7.2 전역 테마로 해결되는 것 (스케치)

```dart
// theme.dart 안 ThemeData(...) 에 추가할 설정 (스케치, 값은 §3.1)
final hover = isLight ? const Color(0x0F1F1B16) : const Color(0x0FFFFFFF);
final press = isLight ? const Color(0x1F1F1B16) : const Color(0x1FFFFFFF);
final touch = {TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform);

ThemeData(
  hoverColor: hover,                  // InkWell / ListTile / Chip / PopupMenuItem 기본 (기존 4%)
  focusColor: press,                  // 전환기: 링 적용 전 fallback(12%). 링 적용 후 투명으로(결정 7)
  // 눌림: InkWell 눌림 하이라이트는 highlightColor 담당 (null overlayColor일 때)
  highlightColor: touch ? Colors.transparent : hover,   // 데스크톱/웹: 6% (hover 6%와 겹쳐 ≈12%)
  splashColor: press,
  splashFactory: touch ? InkRipple.splashFactory : NoSplash.splashFactory,
  filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(
    overlayColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.pressed) ? const Color(0x24000000)
      : s.contains(WidgetState.hovered) ? const Color(0x14000000) : null),
    mouseCursor: WidgetStateMouseCursor.clickable,   // 데스크톱 빌드에서도 click
  )),
  // outlinedButtonTheme / textButtonTheme / iconButtonTheme / segmentedButtonTheme:
  //   overlayColor = hover / press 토큰, mouseCursor 동일
  popupMenuTheme: PopupMenuThemeData(color: pb.sheet, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14)), mouseCursor: WidgetStateMouseCursor.clickable),
)
```

- ⚠️ `focusColor`를 투명으로 두면 링을 달지 않은 위젯은 **포커스 표시가 아예 없어진다.** 전환 기간에는 `focusColor`를 `press`(12%)로 두고(= 현행과 같거나 더 강함), 링이 적용된 컨트롤에서만 틴트를 끄는 순서가 안전하다.
- `ChipThemeData`, `ListTileThemeData`, `PopupMenuThemeData`에는 `overlayColor`가 **없다**(✅ SDK grep). 이들은 `ThemeData.hoverColor/focusColor`로만 조절된다.
- 같은 이유로 **전역 테마만으로는 링이 생기지 않는다.** 버튼 `ButtonStyle.side`(WidgetState.focused)로 inset 링은 만들 수 있으나 §4.1 R3 때문에 보라 채움 위에서 쓸 수 없다 → 바깥 링은 래퍼가 필요하다.

### 7.3 공통 위젯 제안 — `PbFocusRing` + `PbInteractive`

| 위젯 | 역할 | 쓰는 곳 |
|---|---|---|
| `PbFocusRing(child, radius, inset=false)` | 하위 포커스(`Focus(canRequestFocus:false, onFocusChange)`) + `FocusManager.highlightMode == traditional`일 때만 `Stack(clipBehavior: none)`에 `Positioned(-4)` + `IgnorePointer(DecoratedBox(border))` 링을 그림 | Material 버튼·`IconButton`·`ActionChip`·`Card` 감싸기 |
| `PbInteractive(builder:(ctx, states), onTap, radius, selected, expanded, label)` | `FocusableActionDetector`(키보드 모드 포커스·링, Enter/Space 활성) + `MouseRegion`(커서 `click`, **hover**) + `Semantics(button, enabled, selected, expanded)` + 눌림 스케일 + 링 + **상태는 `builder`의 decoration 색으로 그림** | 커스텀 pill(범위/모델), 적게 보기 토글, 예시 질문 카드, 사이드바 `_NavItem`, 대화 목록 행 |

✅ `PbInteractive` 스케치를 `probe/lib/pb_interactive.dart`에 만들고 macOS 모드로 테스트했다(`probe/test/pb_test.dart`; 하네스는 앱과 같은 배경 순서로 수정한 뒤의 값):

| 검증 | 결과 |
|---|---|
| 유리(0xBD 흰) 위 hover (ink 6%) | rest (253,249,251) → hover **(240,236,238)** — 보임 (가려지지 않음) |
| pressed (ink 12%) | (226,222,223) |
| 마우스 클릭 후 링 | **없음** (링 밴드 = 면 색) |
| Tab 포커스 후 링 | **(31,27,22) = ink** 로 그려짐 |
| Enter | `onTap` 호출 (taps 1 → 2) |
| 키보드 포커스 유지 상태에서 hover 이동 | 링 유지 |

즉 제안한 방식은 **(1) 유리 위에서도 가려지지 않고 (2) 키보드에서만 링이 나온다.** (스케치는 저장소가 아닌 이 폴더에 있다. 채택 시 `lib/app/`에 `pb_interactive.dart`로.)

Android 설정: Tab만 보내면 링이 정상(`probe/test/android_test.dart`), hover는 위 규칙대로 `MouseRegion`으로 받아 모드와 무관하게 그려진다(`probe/test/mode_test.dart`). 마우스 제스처 뒤 같은 파일에서 링이 안 나온 한 번의 케이스는 전역 포커스 상태가 섞인 하네스 때문일 수 있고 원인은 미규명 → ⚠️ 실기 확인.

### 7.4 접근성 라벨 · 툴팁 규칙

| 규칙 | 내용 |
|---|---|
| 아이콘 버튼 | 툴팁 필수, 문구 = 접근성 이름 (동사형: "복사", "새 대화", "닫기 (Esc)"). `IconButton(tooltip:)`가 둘 다 처리 |
| 텍스트 버튼·토글 | 보이는 글자 = 접근성 이름 (WCAG 2.5.3). 상태가 바뀌면 글자와 이름이 같이 바뀌고 `expanded`를 병기 |
| 드롭다운 | 이름 = "{항목}: {값}" 한 노드, `expanded` 상태, 항목은 `selected` |
| 툴팁 | **툴팁에만 있는 정보 금지**(터치·키보드에 닿지 않음). 보조 설명만. 비활성 버튼도 툴팁 가능 |
| 비활성 | `onPressed:null` → 자동 `enabled:false`; 사유는 `hint` |
| 장식 아이콘 | `ExcludeSemantics` (예: 체크 아이콘, ⚡ 헤더) |
| 순서 | 포커스 순서 = 시각 순서 (컴포저: 범위 → 입력 → 보내기 → 모델). `ReadingOrder` 기본 정책으로 충분하나 ⚠️ 실기 확인 |

### 7.5 적용 후 점검 · 테스트 제안

- 위젯 테스트: `highlightStrategy = alwaysTraditional`에서 포커스 → 링 위젯(`ValueKey('pb-focus-ring')`) 존재, 마우스 탭 후 부재.
- 골든: 라이트/다크 × (rest, hover, focus, pressed, disabled, selected) × 컴포넌트 9종은 `states.html`과 같은 값으로.
- 수동: Tab/Shift+Tab 전 화면 순회, 스크린리더(VoiceOver) 이름·상태, OS 모션 줄이기, Chrome DevTools 고대비.

---

## 8. 결정이 필요한 선택지 (추천 포함)

| # | 결정 | 선택지 | 추천 · 이유 |
|---|---|---|---|
| 1 | 포커스 링 색 | (a) ink 중립 (b) 슬레이트 (c) 보라 유지 | **(a)**. 모든 표면 ≥ 3:1(다크 최소 4.5), 인용과 안 섞임, 새 색 없이 `ink` 별칭. (c)는 `ui-polish/spec.md` §5.3·UP-04가 이미 "2px accent 링"으로 정해 둔 것을 **뒤집는 결정**이다. 근거(다크 2.49:1, 인용 혼동) 때문에 갱신 제안 |
| 2 | 입력창 `focusedBorder`(현 accent 2px)와 `SourceRow`·`CiteMarker` 링 | (a) 모두 ink로 통일 (b) 입력만 accent 유지 | **(a)** — "포커스 = 중립 링, 보라 = 인용" 규칙이 깔끔. (b)도 허용(입력창은 인용과 인접하지 않고 라이트 5.3:1, 다크 B7A6FF vs 유리 6.2:1 통과). 변경 파일: `theme.dart`(inputDecorationTheme), `ask_sources.dart`(SourceRow·CiteMarker), 문서 `ui-polish/spec.md` §5.3 |
| 3 | 입력 경계 `controlEdge`(ink 50%, 3:1) | (a) 도입 (b) 현행 hairline 유지 | **(a) 폼 입력(로그인·링크·검색)만**. 현행 hairline은 1.35:1이라 WCAG 1.4.11 해석상 경계가 유일한 식별 단서인 필드는 미달. 컴포저는 패널이 식별 단서라 제외. 시각적으로 진해지는 비용이 있음 → 디자인 판단 필요 |
| 4 | hover 강도 | H1 6% / H2 8% | **H1 6%**, 컴포저 안쪽처럼 겹겹 유리 위에서만 H2 허용 |
| 5 | 다크 답변 카드(스택) 위 `inkMuted`(3.8:1)·`linkInk`(3.95:1) 미달 | (a) 카드 다크 `glassStrong`를 14% → 10%로 낮춤 (b) 카드 안 보조 글자를 `ink` 85%로 | 이 문서 범위 밖 발견이라 **별도 이슈로 분리 권장**(⚠️ BackdropFilter 미반영 합성값이라 실기 확인 후) |
| 6 | 데스크톱 터치 영역 | 36 허용 / 44 통일 | **36 허용**(WCAG 2.5.8 24 통과, 요소 간격 ≥8). 모바일·태블릿은 44 |
| 7 | 전역 `focusColor` 투명화 시점 | 즉시 / 링 적용 완료 후 | **링 적용 후**. 그 전엔 12% 틴트 유지 |
| 8 | `PopupMenuButton` → `MenuAnchor` | 유지 / 이전 | P2. 유지해도 pill만 `PbInteractive`로 바꾸면 핵심은 해결(메뉴 패널은 전역 테마) |

---

## 9. 확인하지 못한 것 (⚠️)

- 실제 앱(웹/macOS/모바일) 렌더에서의 hover·focus 모습, `BackdropFilter`가 잉크에 미치는 추가 영향. 위 실측은 같은 구조의 격리 위젯 테스트다.
- 스크린리더(VoiceOver/TalkBack/NVDA)에서의 이름·상태 낭독(드롭다운 이름+값 합쳐짐 여부, `expanded` 중복 낭독).
- Windows 강제 색상 모드, 웹 `prefers-reduced-motion` → `disableAnimations` 매핑.
- `MenuAnchor` 이전 시 Escape 후 포커스 복귀, `_NavItem` 방향키 이동.
- 다크 합성 대비(답변 카드 스택)는 블러 미반영 계산값.
- 터치 기본 플랫폼에서 `FocusableActionDetector` hover 게이트의 '깨끗한' 재현(하네스 한계). `MouseRegion`으로 우회해 문제를 피하는 설계이므로 영향은 작다.
- `app/pageblink_flutter`의 다른 에이전트 작업(`ask_screen`, `ask_sources`, `notes/*`) 진행 중이라 줄 번호는 바뀔 수 있다.

---

## 10. 산출물

| 파일 | 내용 |
|---|---|
| `docs/design/interaction-states/spec.md` | 이 문서 |
| `states.html` (이 폴더) | 실제 토큰 값으로 그린 상태 시트(라이트·다크 세로 나열, `?t=light` / `?t=dark`로 한쪽만). CSS `outline: 2px solid; outline-offset: 2px` 등 Flutter에서 같은 값으로 만들 수 있는 것만 사용 |
| `a11y-design/mockups/states-light-1-toggle-dropdown-send.png`, `states-dark-1-…png` | ① 적게 보기 현재→개선 ② 드롭다운 pill 6상태·메뉴 ③ 보내기 버튼·예시 질문 |
| `a11y-design/mockups/states-light-2-chip-card.png`, `states-dark-2-…png` | ④ 칩 선택×hover×focus ⑤ 노트 카드 |
| `a11y-design/mockups/states-light-3-ring-hover-contrast.png`, `states-dark-3-…png` | ⑥ 링 후보(A, A′ 슬레이트, B 이중, C 틴트+밑줄, D 보라) × 표면 4종 ⑦ hover 강도 후보 ⑧ 대비 근거 |
| `a11y-design/mockups/ring-options-light.png`, `ring-options-dark.png` | 이미지 모델 시안(참고용, §11) |
| `a11y-design/contrast_states.py`, `tints.py`, `extra.py` | 대비·ΔL* 계산 스크립트(재현용) |
| `a11y-design/probe/` | 실측 위젯 테스트(`test/ink_test.dart`, `test/pb_test.dart`, `test/android_test.dart`) + `lib/pb_interactive.dart` 스케치. 저장소 아님 |

## 11. 이미지 생성 기록 (정직 보고)

| 파일 | 모델 | 결과 |
|---|---|---|
| `mockups/ring-options-light.png` | `google/gemini-3.1-flash-image` | 성공(비용 $0.0674). 링 A/B/C 구도는 의도대로. 한계: 라벨 언어가 영/한 섞임, A의 "2px 간격"이 얇아 pill 이중 테두리처럼 보임, hover 칩 라벨 중복 |
| `mockups/ring-options-dark.png` | `google/gemini-3.1-flash-image` | 성공(비용 $0.0674). **부정확**: 보내기 버튼을 "40px round send" 텍스트 pill로 그렸고, hover 칩이 카드 밖에 있음, A 링이 이중선처럼 보임. 구도 참고만 |
| (시도) | `google/gemini-nano-banana-2.1` | **실패 2회**: 상류 429(일시적 속도 제한) → 규칙대로 `gemini-3.1-flash-image`로 폴백 |

- API 호출 총 4회(실패 2 + 성공 2), 8회 이내. 키는 출력·저장하지 않았다.
- **정확한 값(2px/2px 링, 6% 틴트, hex)은 이미지 모델이 재현하지 못한다.** 그래서 `states.html`(+ 그 스크린샷 PNG 6장)이 기준 시안이고, 이미지 모델 시안은 분위기 비교용이다.

> 편입 메모: 이 폴더에는 `spec.md`와 `states.html`만 둔다. §10·§11 표의 `mockups/*.png`(스크린샷 6장 + 이미지 모델 시안 2장, 합계 약 4.6MB)와 계산 스크립트 `contrast_states.py`·`tints.py`·`extra.py`는 용량·재현용이라 저장소에서 제외했다. 기준 시안은 `states.html`이며 브라우저에서 열어 다시 볼 수 있다(`?t=light` / `?t=dark`).
