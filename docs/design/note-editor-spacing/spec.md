# 노트 편집기 여백·세로 리듬 개선 (note-editor-spacing)

작성 2026-10-15 14:55 KST. 기준은 채택된 **AB v2**(`../ab-v2/spec.md`, 토큰은 `app/pageblink_flutter/lib/app/theme.dart`의 `Pb`)와 타입 스케일(`../ui-polish/spec.md` §3), 본문 폭 680(`../../research/018-desktop-note-typography.md`)이다. **저장소 코드는 수정하지 않았다**(측정용 복사본은 스크래치에서만 실행). 줄 번호는 다른 에이전트가 같은 영역을 고치고 있어 쓰지 않고 위젯 이름으로 가리킨다.

> 표기: ✅ 코드·실행 측정으로 확인 · ⚠️ 미확인/추정.

클라이언트 피드백: "editor의 본문 영역 상단이 너무 붙어 있다. 여백을 적절하게. 노트 영역 전체의 여백을, 디자인적인 미학을 유지하면서도 안 답답하고 편하고 예쁘게 개선."

| 파일 | 내용 |
|---|---|
| `1-desktop-top(.png/.svg, -dark)` | 데스크톱 위쪽 리듬·거터 전/후. 1:1 px, 주석 포함 |
| `2-phone(…)` | 폰 390, 툴바 하단, 키보드 닫힘 전/후 |
| `3-scroll-end(…)` | 긴 노트 스크롤 끝: 데스크톱 + 폰(키보드 열림) 전/후 |
| `4-citation-banner(…)` | 인용 배너 위·아래 간격 전/후 |
| 이 문서 | 진단, 토큰, 반응형, 레이어 호환, 구현 체크리스트 |

시안은 SVG를 직접 작성해 `rsvg-convert`로 PNG를 만들었다(이미지 생성 모델 미사용). 글꼴은 Pretendard, 제목 serif는 Fraunces 대신 나눔명조로 대체했고 아이콘은 근사다. 다크 패널 색은 `glassStrong` 위의 대략값이다(⚠️ 실기기 확인 필요).

---

## 0. 한 장 요약

1. **상단이 붙어 보이는 직접 원인은 테마의 숨은 패딩이다.** 제목·본문 `TextField` 둘 다 `contentPadding`을 지정하지 않아 `inputDecorationTheme.contentPadding`(가로 18, 세로 14)이 새어 들어온다(✅ `InputDecoration.applyDefaults`가 `contentPadding ?? theme.contentPadding`, 측정으로 확인). 그래서 본문 첫 줄은 구분선 아래 **14px**, 좌우 거터는 코드가 말하는 16이 아니라 **34**(16+18)다. 코드의 `Padding(16/8)`만 읽으면 값이 틀린다.
2. **툴바가 가운데, 글자는 왼쪽이다.** 툴바는 `SingleChildScrollView`가 느슨한 제약을 받아 400px로 줄어든 채 컬럼 가운데에 놓인다. 첫 아이콘이 본문 왼쪽 선보다 **114px 오른쪽**(✅ 측정, 컬럼 680). 위계상 "정돈되지 않아 보임"의 가장 큰 신호다.
3. **마지막 줄 아래가 14px뿐이다.** `expands: true` 필드의 `contentPadding`은 스크롤 영역 **밖**의 죽은 띠라서(✅ 코드·측정) "끝에서 편안한 여백"을 패딩만으로는 만들 수 없다. 폰에서는 마지막 줄이 툴바에 14px로 붙는다.

제안은 세 가지다. (a) 숨은 패딩을 명시적 `contentPadding` 한 곳으로 정리하고 `NoteSpacing` 토큰을 둔다. (b) 툴바를 본문 왼쪽 선에 맞추고 구분선 대신 "스크롤 시에만 나타나는 헤어라인"을 쓴다. (c) 끝 여백은 이미 `TextField`에 넘기는 `_bodyScroll`의 최대 스크롤 범위를 늘려 만든다(옵션 B, §6). 브리프가 "패딩으로만"을 요구했으므로 B는 **결정이 필요한 항목**으로 분리했다.

---

## 1. 현재 간격 표 (✅ 스크래치 복사본 위젯 테스트로 측정)

측정 방법: 저장소 `app/`을 스크래치로 복사하고 `NoteEditorView`를 `MaterialApp`에 올려 `getTopLeft/getRect`로 읽었다(뷰 1.0 DPR, 높이 800, 하단 safe 34). 테스트 창 폭 724에서는 `noteSizes`가 26을 반환해 제목 줄 높이가 32.5다. 실제 데스크톱(창 ≥ 1024)은 28/35이므로 제목 아래 값은 +2.5다.

### 1.1 세로 (px)

| 구간 | 코드상 값 | **실제 값** | 비고 |
|---|---|---|---|
| 헤더 하단선 → 제목 줄 상단 | `Padding.top 8` | **22** (8+숨은 14) | 헤더 `PaneHeader` 높이 56(하단선 포함) |
| 제목 줄(박스) | 28×1.25 | 필드 높이 **61**(26일 때) / 63(28일 때) | 숨은 위·아래 14씩 |
| 제목 줄 하단 → 툴바 상단 | `0` | **14** (숨은 14) | 툴바 버튼 높이 40, 아이콘 24 |
| 툴바 하단 → `Divider` | — | 0, 선 1px | 구분선은 패널 전체 폭 |
| 구분선 → 본문 첫 줄 상단 | 없음 | **14** (숨은 14) | 줄 높이 27.2의 위쪽 여유 5.6이 더해져 글자 윗선은 약 20 |
| 인용 배너 | `padding 12`, 마진 없음 | 헤더 하단선에 **0**으로 붙음, 아래로 제목까지 22 | 배너 있으면 제목 상단은 헤더 기준 70 |
| 마지막 줄 → 필드(패널) 하단 | 없음 | **14** (숨은 14) | 폰은 툴바 상단에 14로 접함 |
| 폰 하단 | `SafeArea` + 툴바 40 | 본문 필드 하단 = 툴바 상단 | 툴바 아래 safe 34 |

### 1.2 가로 (px)

| 항목 | 값 | 비고 |
|---|---|---|
| 본문·제목 텍스트 왼쪽 → 컬럼 왼쪽 | **34** (16+숨은 18), 폰·태블릿·데스크톱 동일 | ✅ 390/900/724 모두 34 |
| 본문 텍스트 폭 | 폰 390 → **322**, 컬럼 680 → **612**, 패널 564 → 496 | 폰이 화면의 83%만 쓴다 |
| 툴바 첫 아이콘 → 본문 왼쪽 선 | 컬럼 680에서 **+114** | 툴바가 400px 가운데 정렬 |
| 인용 배너 가장자리 | 컬럼 가장자리부터 시작, 글자는 +12 | 제목(+34)과 왼쪽 선이 어긋남 |

### 1.3 컬럼 폭이 실제로 몇인가 (코드 추적)

`noteSizes`는 **창 폭**을 보지만 컬럼은 **패널 폭**에 의해 정해진다. 데스크톱 중앙 패널은 `min(1100, 창폭 − 716)`(바깥 24×2 + 사이드바 240 + 간격 24×2 + Ask 380), 태블릿은 `창폭 − 152`(⚠️ 레일 폭 80 가정), 폰은 창 폭이다.

| 창 | 패널 폭 | 컬럼 | 비고 |
|---|---|---|---|
| 폰 390 | 390 | 390 | |
| 태블릿 768 | 616 | 616 | |
| 데스크톱 1024 | 308 | 308 | 제목은 28인데 본문 폭 240 ⚠️ 별도 이슈 |
| 데스크톱 1280 | **564** | 564 | 의뢰서의 "1280(컬럼 680)"은 **성립하지 않는다** |
| 데스크톱 1440 | 724 | **680** (양쪽 22) | 컬럼 680이 처음 꽉 차는 창은 1396 |
| 데스크톱 1920 | 1100 | 680 (양쪽 210) | |

→ 거터·여백 규칙은 창 폭이 아니라 **패널 폭(LayoutBuilder)** 기준이어야 한다.

### 1.4 텍스트 배율 1.5 (✅ 측정)

폭 724(macOS)에서 겹침·overflow 없음: 제목 필드 61→77, 툴바·본문이 그만큼 내려간다. 폭 390(android)에서는 본문 영역은 정상이나 **`PaneHeader`의 Row가 0.4px 오른쪽으로 넘친다**(기존 이슈, 이 작업 범위 밖, ⚠️ 별도 수정). 새 테스트가 390@1.5를 쓰면 이 예외로 실패한다.

---

## 2. 진단

| # | 증상 | 원인 | 확인 |
|---|---|---|---|
| D1 | 본문 첫 줄이 구분선·툴바에 붙음 | 구분선 아래 `contentPadding.top` 14(테마 값). 구분선이 선명한 가로선이라 14가 더 좁게 읽힌다. 툴바(아이콘 24 + 위아래 8)와 구분선이 연속해 "툴바 띠 + 선 + 바로 글자" | ✅ |
| D2 | 제목-본문 위계 거리가 어색 | 제목→툴바 14, 툴바→본문 14+1. 두 간격이 같아 툴바가 제목에 속하는지 본문에 속하는지 모호. 폰은 제목→본문 28(=14+14)이라 오히려 데스크톱보다 빡빡 | ✅ |
| D3 | 왼쪽 선이 정리되지 않음 | 제목·본문 +34, 툴바 첫 아이콘 +148(가운데), 배너 글자 +12, 배너 박스 +0 | ✅ |
| D4 | 긴 노트 끝이 답답 | 필드 `contentPadding.bottom` 14는 스크롤되지 않는 죽은 띠. `scrollPadding` 기본 20은 캐럿 표시용일 뿐 스크롤 범위를 늘리지 못한다 | ✅ (측정: 최대 스크롤에서 마지막 줄-필드 하단 14) |
| D5 | 폰에서 가로가 좁음 | 거터 34×2로 본문 폭 322(≈ 한글 20자). 이중 패딩(16+18) | ✅ |
| D6 | 키보드 올라올 때 | 툴바가 키보드 위에 붙고 본문은 `Expanded`로 줄어든다. 마지막 줄 아래 여유는 여전히 14 | ✅ 구조상 |
| D7 | 컬럼 상단 | 데스크톱에서 제목이 헤더 하단선 아래 22. 패널 안쪽이 넓은데 상단만 빡빡 | ✅ |
| D8 | 인용 배너 | 헤더 구분선에 붙은 직사각형, 컬럼 가장자리에서 시작. 제목과 왼쪽 선 불일치, 모서리 반경 0(시스템의 12~16 사다리와 다름) | ✅ |
| D9 | 이중 출처 | 제목은 `Padding(16/8/16/0)` + 테마 `contentPadding`(18/14), 본문은 `Padding(16)` + 테마. 한 값을 바꾸려면 두 곳을 맞춰야 하고 테마가 바뀌면 조용히 틀어진다 | ✅ |
| D10 | 스크롤바 위치 | 데스크톱 스크롤바는 `EditableText` 가장자리(텍스트 오른쪽, 패널 가장자리 아님). 018 문서의 "스크롤바는 패널 가장자리"는 구현되지 않았다. 패딩으로는 못 바꾼다 | ⚠️ 코드 추론, 화면 미확인 |

---

## 3. 개선 토큰 `NoteSpacing` (8pt 그리드)

기준 폭 `p` = 편집기가 받는 **패널(또는 폰 전체) 폭**. 높이 규칙은 **창 높이 / 텍스트 배율**(키보드 inset으로 줄어든 높이가 아님. `../login-layout/spec.md` R6와 같은 이유: 키보드가 열릴 때 리듬이 깜빡이면 안 된다).

```
class  = p < 560 ? compact : p < 720 ? medium : wide
short  = MediaQuery.sizeOf(context).height / max(1, textScaler.scale(16) / 16) < 600
```

| 토큰 | compact (p<560) | medium (560–719) | wide (≥720) | 전 | 비고 |
|---|---|---|---|---|---|
| `gutter` 텍스트 왼쪽 inset | **20** | **24** | **32** | 34 | 제목·본문·툴바 첫 아이콘·배너 글자가 모두 이 선 |
| `titleTop` 헤더 하단선 → 제목 상단 | 24 | 24 | **32** | 22 | `short`이면 16 |
| `titleBottom` 제목 아래(필드 내부) | 8 | 8 | 8 | 14 | 제목 `contentPadding.bottom` |
| `bodyGap` 툴바(폰은 제목) 아래 → 헤어라인 | **24** | 24 | 24 | 14+1 | `short`이면 16. 핵심 값 |
| `endAir` 마지막 줄 아래(스크롤 가능) | 64 | 96 | 120 | 14 | 옵션 B. `short`이면 48 |
| `scrollBottom` `scrollPadding.bottom` | 48 | 72 | 96 | 20 | 입력 중 캐럿이 하단에서 떨어지는 거리 |
| `overlayClear` 오버레이 스택 좌우 여유 | 8 | 8 | 8 | 16 | 아래 §5 |
| `bannerTop` / `bannerToTitle` | 16 / 16 | 16 / 16 | 16 / 16 | 0 / 22 | `short`이면 12 / 12 |
| `bannerRadius` | 12 | 12 | 12 | 0 | 배너 좌우 = `gutter − 12`(글자 선 정렬) |
| 본문 `contentPadding.top` | 0 | 0 | 0 | 14 | 헤어라인이 글자 잘리는 선과 일치 |
| 본문 `contentPadding.bottom` | 0 | 0 | 0 | 14 | 옵션 B 폴백: 24 |
| 본문 `contentPadding.horizontal` | `gutter − 8` | `gutter − 8` | `gutter − 8` | 18 | `overlayClear` 8과 합쳐 `gutter` |

결과 간격(regular 높이): 헤더 하단선 → 제목 24/24/32 → 제목 → 툴바 8 → 툴바 → 첫 줄 **25**(24 + 헤어라인 1, 전 15) → 마지막 줄 아래 64/96/120(전 14). 툴바가 없는 폰은 제목 아래 8 + 24 + 1 = **33**(전 28).

### 3.1 구분선 사용

- **정지 상태에서는 선이 없다.** 헤더 하단선이 이미 있고 툴바 아래에 두 번째 가로선이 있으면 제목 영역이 상자처럼 갇힌다.
- **스크롤하면(`pixels > 0.5`) 1px 헤어라인**(`pb.hairline`)이 120ms로 나타난다. 위치는 `bodyGap` 아래이자 본문 필드의 위쪽 가장자리라, 글자가 잘리는 선과 정확히 일치한다(= 죽은 띠가 없다).
- 선 폭은 패널 전체(헤더 하단선과 같음).

### 3.2 `contentPadding` vs `Padding`

| | 장점 | 단점 | 선택 |
|---|---|---|---|
| 가로를 `contentPadding`에 | 거터 영역도 탭(캐럿 이동)·휠 스크롤이 먹는다. `RenderEditable` 좌표계는 그대로 | 스크롤되지 않는 띠다(가로는 문제 없음) | **가로: `contentPadding`** (`gutter − 8`) |
| 가로를 바깥 `Padding`에 | 스택 원점이 텍스트 왼쪽이라 계산이 단순 | 거터는 휠·탭이 죽는다. 오버레이 클램프가 텍스트 선에 걸림 | 쓰지 않음 |
| 세로 위쪽 | 한 곳 | `contentPadding.top`은 스크롤되지 않는 띠: 글자가 선 없이 허공에서 잘림 | **바깥 `SizedBox(bodyGap)` + 필드 `top: 0`** |
| 세로 아래쪽 | 한 곳 | 같은 이유로 "끝 여백"이 안 만들어짐 | **스크롤 범위 연장(B)**, 폴백 `bottom: 24` |

**스택 원점 규칙**: 본문 `Stack`은 바깥 `Padding(horizontal: 8)`(= `overlayClear`) 안에 두고 필드의 `contentPadding.horizontal`만 `gutter − 8`로 둔다. 텍스트는 컬럼 가장자리에서 정확히 `gutter`, 오버레이(미니바·링크 팝오버·코드 블록 번짐)는 컬럼 가장자리에서 최소 8 안쪽에 머문다.

---

## 4. 반응형 규칙

의뢰서의 창 폭 구분(<600 / 600–1023 / ≥1024)을 **패널 폭**으로 환산하면 아래와 같다.

| 창 | 패널 폭 `p` | class | gutter | 컬럼 | 비고 |
|---|---|---|---|---|---|
| 폰 <600 | 창 폭(360–599) | compact (p<560) / 560–599는 medium | 20 / 24 | 전체 폭 | 툴바 하단. `endAir` 64 |
| 태블릿 600–1023 | 창 −152 = 448–871 | 창 <712 compact, 712–871 medium(창 ≥872 wide) | 20 / 24 / 32 | 패널 폭 또는 680 | 툴바 상단 |
| 데스크톱 1024–1275 | 308–559 | compact | 20 | 패널 폭 | 제목 28 그대로(별도 이슈) |
| 데스크톱 1276–1435 | 560–719 | medium | 24 | 패널 폭 | 1280은 여기 |
| 데스크톱 ≥1436 | ≥720 (최대 1100) | wide | 32 | **680 가운데 정렬** | 컬럼 가운데 유지 |

- **가운데 vs 왼쪽 정렬**: 가운데를 유지한다. 패널 안쪽 좌우 여백이 22~210이고 헤더 제목·툴바가 모두 컬럼을 기준으로 정렬되므로 좌측 정렬은 헤더 아이콘들과 시선이 어긋난다. (비율로 보면 1920에서 컬럼은 패널의 62%.)
- **낮은 창(`short`: 창 높이/배율 < 600)**: `titleTop` 16, `bodyGap` 16, `endAir` 48, 배너 12/12. 세로 26 절약. 높이 500·배율 1.0, 또는 높이 800·배율 1.5(=533)에서 켜진다. 스크롤 영역(`Expanded`)을 침범하는 고정 띠는 헤더 56 + 제목 ≈ 67 + 툴바 40 + 25뿐이다.
- **텍스트 배율 1.5**: 폰트 크기에 비례해 제목·본문이 커지고 툴바 버튼(40)은 고정이다. 토큰은 px 고정(배율 곱 없음)이라 겹침은 없다(✅ 측정). 배율이 커지면 `short`가 켜져 상단이 줄어드는 것이 의도다.
- **키보드**: `short` 판정은 창 높이 기준이라 키보드로 리듬이 바뀌지 않는다. 폰에서 키보드가 열린 상태의 본문 보임 높이는 844 기준 약 278(≈ 10줄)이다.

---

## 5. 오버레이 레이어 호환 (✅ `live_check_layer.dart`, `live_code_layer.dart`, `selection_mini_bar.dart`, `link_popover.dart` 코드 확인)

레이어는 모두 `RenderEditable`의 `getBoxesForSelection`/`getTransformTo(stack)`로 좌표를 읽으므로 `contentPadding`/`Padding` 변경을 따라간다. 스크롤 범위를 늘려도(옵션 B) 같은 좌표 변환으로 따라간다(✅ 스크래치 실측: 최대 스크롤 623→743, 체크박스 레이어 rect.top 467.6→347.6, 정확히 120 이동).

스택 원점은 컬럼 가장자리 + 8, 텍스트 왼쪽 = 스택 x `gutter − 8`.

| 레이어 | 의존하는 값 | 새 값에서 | 판정 |
|---|---|---|---|
| 체크박스 18px 박스 | 줄 높이 27.2 안에서 `rect.center.dy` 기준 세로 중앙(`side/2`) | 세로 패딩 변경과 무관(줄 박스 기준). 가로 `rect.left` = 텍스트 왼쪽 | ✅ 중앙 유지 |
| 체크박스 클릭 영역 28(터치 44) | `left = max(0, prefix.left − 8)` | 스택 x 최소 `gutter − 8 − 8` = compact 4 ≥ 0, 클램프가 걸리지 않음 | ✅ |
| 체크박스 페인트 클립 | `clipRect(view)`: 필드 본체 | 필드 `top:0/bottom:0`이면 필드 전체가 보임 | ✅ |
| 코드 블록 배경(번짐 12, 반경 10, 세로 4) | `view.left − 12`가 스택 x ≥ 0 | 스택 x = `gutter − 8 − 12` → compact **0**, medium 4, wide 12 | ✅ compact는 딱 맞음. `gutter ≥ 20` 이상 필수 |
| 코드 블록 배경 클립 | `Stack.clipBehavior: Clip.none` + 페인터가 `view ± 12`로 클립 | 변경 없음 | ✅ |
| 코드 복사 버튼 | `rect.right − kFenceBleed − 4` | 텍스트 오른쪽 기준이라 변경 없음 | ✅ |
| 코드 블록 위·아래 4 | 줄 박스 ±4 | 본문 첫 줄(`top:0`)이 코드 블록이면 배경 상단이 헤어라인 위 4px 번짐 | ⚠️ 헤어라인(스크롤 시)과 겹칠 수 있음 → 페인터가 `view`로 클립해 필드 위로는 안 그려짐(✅ 코드) |
| 미니바(`TextSelectionToolbarLayoutDelegate`) | 스택 경계 `[0, width]`로 클램프 | 스택 좌우가 컬럼 가장자리 + 8이라 화면 가장자리에서 최소 8 여유(기존 16에서 감소) | ✅ (`selection_mini_bar.dart` `_Floating` 읽음) |
| 링크 팝오버 | 자체 `_BelowDelegate`: 링크 아래(+6), 자리가 없으면 위, 가로 `[0, 스택폭 − 폭]`, 세로 스택 안으로 클램프. 폭 `min(360, 스택폭)` | 스택이 본문 필드 영역이라 툴바·제목을 가리지 않음. 폰 스택폭 374라 360 폭이 좌우 7 여유 | ✅ (`link_popover.dart` `_BelowDelegate` 읽음) |
| 마우스 hover 영역 | 스택 전체 | 스택이 거터 포함 | ✅ |

**제약**: `gutter`의 최소값은 `kFenceBleed(12) + overlayClear(8)` = **20**이다. 토큰 상수 옆에 이 부등식을 단언으로 둔다.

---

## 6. 끝 여백: 옵션 A(패딩만) vs 옵션 B(스크롤 범위 연장) — 결정 필요

**의뢰서의 두 요구가 충돌한다.** (1) "`TextField`의 `contentPadding`/`Padding`으로만 변경", (2) "스크롤 끝에서 마지막 줄 아래 최소 96~160px". `expands: true` 필드의 `contentPadding.bottom`은 스크롤 영역 밖이라 (2)를 만족시키지 못한다.

| | 옵션 A: 패딩만 | **옵션 B: 스크롤 범위 연장(권장)** |
|---|---|---|
| 방법 | `contentPadding.bottom: 24` | 이미 `TextField`에 넘기는 `_bodyScroll`을 서브클래스로 바꿔 `applyContentDimensions(min, max + endAir)`. 내용이 넘칠 때(`max > 0`)만 연장 |
| 마지막 줄 아래 | 24 (죽은 띠, 글자가 허공에서 잘림) | 64/96/120, 실제로 스크롤됨 |
| 짧은 노트 | 변화 없음 | 변화 없음(✅ 측정: 최대 스크롤 0 유지) |
| 레이어 | 영향 없음 | 영향 없음(✅ 체크 레이어 rect가 정확히 따라감) |
| 위험 | 없음 | Flutter 내부 API(`ScrollPositionWithSingleContext`) 서브클래스. 3.47.7 고정이라 현재는 안전하나 업그레이드 시 확인 필요. `ScrollbarThumb` 길이가 연장분만큼 달라짐(의도) |

옵션 B 구현은 20줄이다. 위치가 `air` 값이 아니라 컨트롤러를 참조해야 중단점이 바뀔 때(`build`에서 `air` 갱신) 다음 레이아웃부터 반영된다(✅ 스크래치: `air` 120→64 후 `maxScrollExtent` 56 감소).

```dart
class _EndAirPosition extends ScrollPositionWithSingleContext {
  _EndAirPosition({required super.physics, required super.context,
      super.oldPosition, required this.owner});
  final NoteScrollController owner; // 값이 아니라 컨트롤러를 잡는다: air 변경이 반영됨
  @override
  bool applyContentDimensions(double min, double max) =>
      super.applyContentDimensions(min, max > 0 ? max + owner.air : max);
}

class NoteScrollController extends ScrollController {
  NoteScrollController(this.air);
  double air;
  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
          ScrollContext context, ScrollPosition? oldPosition) =>
      _EndAirPosition(physics: physics, context: context,
          oldPosition: oldPosition, owner: this);
}
```

- **위쪽은 스크롤 범위를 늘리지 않는다.** 위쪽 여백은 고정(`bodyGap`)이면 충분하고, 위쪽까지 스크롤화하면 초기 오프셋·캐럿 표시·내용이 짧을 때의 고정 처리가 모두 위험해진다.
- 옵션 B를 거부하면 §3 표의 `endAir`를 버리고 `contentPadding.bottom: 24`, `scrollPadding.bottom: 32`로 대체한다. 폰의 "툴바에서 14 → 24"만 개선되고 96~160은 포기한다.
- ⚠️ 입력 중 캐럿 이동(실제 타이핑)에서 `scrollPadding.bottom`이 `endAir` 안쪽까지 스크롤하는지는 `enterText` 테스트로 확인하지 못했다(캐럿 표시 스크롤이 테스트 환경에서 일어나지 않음). 실기기 확인 필요.

### 레이아웃 순서 결정(옵션 C, 이번 제안에는 포함하지 않음)

현재 데스크톱은 제목과 본문 사이에 툴바가 낀다. 제목과 본문을 붙이고 툴바를 헤더 바로 아래로 올리면 위계("제목 → 본문")가 더 분명하고 §3의 간격 문제가 거의 사라진다. 그러나 `note_editor_layout_test.dart`가 "툴바가 본문 위"만 단언하므로 통과는 하지만, 제품 판단(툴바를 헤더에 붙여 두는 편집기 관습)이 필요해 이번에는 **현재 순서를 유지**했다.

---

## 7. 시안 요약

`1-desktop-top.png`(라이트)·`-dark.png`: 창 1440, 패널 724, 컬럼 680(의뢰서의 1280은 패널 564, 같은 규칙에서 medium 24가 적용된다). 빨강 = 전 값, 초록 = 후 값, 점선 = 컬럼 가장자리.

| 시안 | 전 → 후 |
|---|---|
| ① 데스크톱 | 제목 위 22→32, 제목→툴바 14→8, 툴바→첫 줄 15→25, 거터 34→32, 툴바 정렬 +114→0, 본문 폭 612→616 |
| ② 폰 390 | 거터 34→20(본문 폭 322→350), 제목→본문 28→33, 제목 위 22→24 |
| ③ 스크롤 끝 | 데스크톱 마지막 줄 아래 14→120, 폰(키보드) 14→64. 후에는 헤어라인이 글자가 잘리는 선에 맞는다 |
| ④ 인용 배너 | 헤더 하단선에서 0→16, 둥근 카드 12, 좌우 `gutter − 12`, 배너→제목 22→16 |

---

## 8. 구현 체크리스트

수정 파일은 **`app/pageblink_flutter/lib/features/notes/note_editor_screen.dart`** 하나(+ 새 테스트)다. `theme.dart`의 전역 `inputDecorationTheme`은 건드리지 않는다(다른 화면의 필드가 18/14에 의존).

### 8.1 위젯별 수정 지점 (`_NoteEditorViewState.build`)

| # | 위치 | 수정 |
|---|---|---|
| 1 | 파일 상단 `noteColumnWidth` 근처 | `NoteSpacing` 상수 묶음 추가: `static NoteSpacing of(double paneWidth, {required bool short})` → `gutter, titleTop, titleBottom, bodyGap, endAir, scrollBottom`. `overlayClear = 8`, `bannerRadius = 12`. 값은 §3 표 |
| 2 | `build` 최상단 | `PopScope.child`를 `LayoutBuilder`로 감싸 `c.maxWidth`로 `sp` 계산. `short`는 `MediaQuery.sizeOf(context).height / textScale` |
| 3 | `PaneHeader` | 변경 없음 |
| 4 | 인용 배너 `Container` | `margin: EdgeInsets.fromLTRB(g − 12, bannerTop, g − 12, 0)`, `decoration`에 `borderRadius: 12`. 컬럼 `ConstrainedBox` 안(지금처럼) |
| 5 | 제목 `Padding(16/8/16/0)` + `TextField` | 바깥 `Padding` 삭제. `TextField.decoration`에 `contentPadding: EdgeInsets.fromLTRB(g, banner ? bannerToTitle : titleTop, g, titleBottom)` |
| 6 | 데스크톱 툴바 `Padding(horizontal: 8)` | 이 패딩은 **삭제**하고 호출부에는 `Align(alignment: Alignment.centerLeft)`(또는 전체 폭 래퍼)만 둔다. 왼쪽 inset은 11번의 `_toolbar` 안에서만 준다(중복 방지) |
| 7 | 데스크톱 `Divider(height: 1)` | `SizedBox(height: bodyGap)` + `_ScrolledHairline`(`ListenableBuilder(_bodyScroll)`, `AnimatedOpacity`). **폰도 같은 위치**(제목 아래)에 둔다 |
| 8 | 본문 `Padding(horizontal: 16)` | `Padding(horizontal: NoteSpacing.overlayClear)` |
| 9 | 본문 `TextField.decoration` | `contentPadding: EdgeInsets.fromLTRB(g − 8, 0, g − 8, 0)`, `scrollPadding: EdgeInsets.fromLTRB(20, 20, 20, sp.scrollBottom)` |
| 10 | `_bodyScroll` | 옵션 B 채택 시 `NoteScrollController(sp.endAir)`로 교체. 필드는 `late final`이라 `air`는 `build`에서 갱신(`_bodyScroll.air = sp.endAir`) |
| 11 | `_toolbar`(데스크톱·폰 공용) | `SingleChildScrollView(padding: EdgeInsets.only(left: g − 8), …)`. 폰은 행과 함께 스크롤된다. 폰 하단 `SafeArea` + `Material` 구조는 유지 |

`_hover`, `_codeUi`, `_stackKey`, 레이어 위젯, `_syncBar`는 변경하지 않는다.

### 8.2 테스트

신규 `test/note_editor_spacing_test.dart`(기존 `note_editor_layout_test.dart`의 `_pump` 방식 재사용). 아래는 스크래치에서 읽은 지표 그대로 단언할 수 있다.

| # | 단언 | 기대값 |
|---|---|---|
| T1 | 본문 `EditableText` 왼쪽 − 컬럼 왼쪽 (폭 390/559/560/719/720/1100) | 20/20/24/24/32/32 |
| T2 | 제목 `EditableText` 상단 − `PaneHeader` 하단 | 24/24/32, `short`(높이 500) 16 |
| T3 | 본문 `EditableText` 상단 − 툴바 버튼 하단(데스크톱) / − 제목 필드 하단(폰) | 25 (= bodyGap 24 + 헤어라인 1) |
| T4 | 첫 툴바 아이콘 왼쪽(중심 −12) − 컬럼 왼쪽 | `gutter` |
| T5 | 긴 노트 `jumpTo(maxScrollExtent)` 후 필드 하단 − 마지막 줄 하단 | ≥ `endAir`(+ 줄 반 높이 여유) |
| T6 | 짧은 노트 `maxScrollExtent` | 0 |
| T7 | 상수: `gutter − overlayClear ≥ kFenceBleed` (모든 class) | 참 |
| T8 | 인용 배너: 배너 하단 → 제목 텍스트 상단 | 16 |
| T9 | 텍스트 배율 1.5, 폭 ≥ 400에서 `takeException() == null` | 참 (390은 기존 `PaneHeader` 0.4px overflow) |
| T10 | 스크롤 시 헤어라인 불투명도 0→1 | `pixels > 0.5`에서 1 |

기존 테스트 영향(✅ 파일 확인):

| 테스트 | 영향 |
|---|---|
| `note_editor_layout_test.dart` | 툴바 y vs 본문 y만 비교. 통과 |
| `note_typography_test.dart` | `noteSizes`만 검증. 변경 없음 |
| `note_editor_live_ui_test.dart`, `selection_mini_bar_test.dart` | 본문 필드 `getRect` 안에 팝오버·바 중심이 포함되는지 확인. 필드 rect가 거터만큼 넓어질 뿐이라 통과(⚠️ 실행은 안 함) |
| `note_editor_checkbox_test.dart`, `markdown_live_fence_test.dart` | 레이어 rect 기반 상대 좌표라 통과 |
| `note_editor_header_menu_test.dart` | 영향 없음 |

### 8.3 위험

| 위험 | 대응 |
|---|---|
| `LayoutBuilder` 도입 후 `findEditableText`·`_bodyKey` 조회가 깨지는가 | 키·`GlobalKey`는 그대로이고 트리 깊이만 하나 늘어난다. `find.byType(TextField).last`류 테스트 통과 예상 |
| compact 코드 블록 배경이 스택 x=0에 닿음 | 의도된 한계. `gutter < 20` 금지(T7) |
| 옵션 B의 `applyContentDimensions` 오버라이드 | 3.47.7에서 스크래치 검증. 업그레이드 시 T5·T6이 잡는다 |
| 데스크톱 스크롤바가 텍스트 오른쪽에 뜸(D10) | 이번 변경으로 악화되지 않음. 패널 가장자리로 옮기려면 본문 필드를 패널 전체 폭으로 키우고 `contentPadding.horizontal`에 컬럼 여백을 넣는 별도 작업 ⚠️ |
| 헤어라인이 스크롤 0.5px 흔들림에서 깜빡임 | 임계값 0.5와 `AnimatedOpacity 120ms`로 흡수 |
| 제목이 `short`에서 16으로 줄어 폰 키보드 열림과 겹침 | 창 높이 기준이라 키보드로 바뀌지 않음 |

---

## 9. 확인하지 못한 것 (⚠️)

- 실제 앱 화면(Flutter 렌더, 실제 Fraunces·Pretendard 글리프)에서의 시각 확인. 시안은 근사 렌더다. 다크 패널·툴바 색은 대략값.
- 옵션 B에서 실제 타이핑 중 캐럿 스크롤(`scrollPadding.bottom`)의 체감, IME(한글 조합) 중 거동, 웹 빌드.
- 데스크톱 스크롤바의 실제 위치(D10).
- 태블릿 레일 폭 80 가정(패널 폭 계산).
- 툴바 버튼 40px는 터치 목표 48에 못 미친다(별도 이슈). `PaneHeader` 390@1.5 overflow 0.4px(별도 이슈). 창 1024–1100에서 패널 308–384(별도 이슈, 레이아웃 전반).
- 기존 테스트를 실제로 새 구현에 돌려보지 못했다(구현 전).
