# 방향 AB v2 — Glass Paper, Dribbble 레퍼런스 반영판

기준 문서: `../ab-glass-paper/spec.md`(토큰·컴포넌트 전체). 이 문서는 **v1 대비 델타만** 적는다. 값이 겹치면 v1 스펙이 우선하고, 아래에 "변경"이라고 쓴 것만 v2가 덮어쓴다. `ref #`는 `../references/README.md`의 번호, `규칙 #`는 같은 문서 "적용 가이드"의 번호다.

| 파일 | 내용 |
|---|---|
| `prototype/index.html` | 단일 HTML(인라인 CSS, Google Fonts Fraunces/Inter/Noto KR, 라이트+다크 토큰, 74KB). 상단 Auto/Light/Dark 토글. `?solo=<frameId>&theme=dark`로 프레임 하나만 렌더(PNG 내보내기용) |
| `desktop.png`, `desktop-dark.png` | 1440×900 @2x. 보드 + Ask 패널(답변 완료 상태) |
| `desktop-empty.png` | 1440×900 @2x. Ask 빈 상태(사이드바 Ask 활성, 중앙 스테이지) |
| `mobile-board.png`, `mobile-ask.png`, `mobile-citation.png`(+`-dark`), `mobile-editor.png`, `mobile-upload.png` | 390×844 @2x(베젤 포함 446×900) |

PNG는 프로토타입을 헤드리스 Chrome으로 캡처한 것이라 AI 이미지(v1)보다 선이 선명하다. 대신 "AI가 그린 분위기"가 아니라 **실제 CSS 토큰의 결과**이므로 Flutter 구현 기준으로 더 믿을 수 있다.

## 1. 한 줄 요약

v1은 "유리 셸 + 파스텔 카드"였고, v2는 거기에 **면의 위계(유리 62→74→단색 카드), 고정된 치수(240 / 가변 / 380, gap 24, 외곽 28), 인용 중심 Ask UX(답변 카드 구조·빈 상태·출처 시트·3행 컴포저), 보라 사용 예산(그라데이션 면 화면당 1개)** 을 규칙으로 못박았다.

## 2. 토큰 델타

### 2.1 변경 / 추가

| 토큰 | v1 | v2 | 근거 |
|---|---|---|---|
| `glass` (L1: 사이드바·Ask 패널·하단 내비·시트) | 프로토 `#FFF` 58% | **`#FFF` 62%**, blur **sigma 18** (+saturate 1.4) | 규칙 2, ref 07·08 |
| `glassStrong` (L2: 답변 카드·컴포저·제안 카드·검색창) | 프로토 66% | **74%** | 규칙 2, ref 08(계층은 불투명도만으로) |
| `glassShadow` | 보라 18%, blur 40 | **`#6C4CF5` 10%, blur 24, y 8** | 규칙 2 |
| 배경 | 좌상·우상·우하 블러 3개 | **좌상·우하 구석 글로우 2개** + 선형 `#EDE6FA→#F7E8EE→#FFE9DC`. 라이트 글로우 알파 55%(프레임이 작을 때 45% 미만이면 죽는다. 구현은 45~55) | 규칙 1, ref 06·09·12 |
| 그레인 | 6% | **4.5%** (다크 7%) | 글자 뒤 노이즈 최소화 |
| `accent` 채움(버튼/활성 내비/전송) | 그라데이션 | **단색 `#6C4CF5`**(다크 `#B7A6FF` + `onAccent #251A63`) | 규칙 14 "그라데이션 면 최대 1" |
| `accentGradient` | 버튼·FAB·말풍선·로고 전부 | **화면당 1곳만**: 데스크톱·모바일 Ask = 사용자 말풍선, 모바일 보드 = New note FAB, 빈 상태 = 없음 | 규칙 14, ref 09 |
| `accentGradient` 다크 | `#7A5CFF→#9C84FF` + 흰 글자 | **`#6C4CF5→#7A5CFF`** + 흰 글자(끝 4.4:1, 15/500) | 계산: 흰 글자는 `#9C84FF` 위 2.93:1로 실패. `#14102B`(6.29:1) 대안도 가능 |
| 선택 칩(스코프, 필터 All) | 잉크 채움(검정) | **`accentContainer` 채움 + `accent` 55% 테두리 + 체크**, 글자 `onAccentContainer` | 규칙 14, ref 15, v1 스펙 5.5 |
| 인용 칩 `.cchip` | 글로우 포함 | 글로우 제거, 투명 유리 + 1px accent 테두리, 다크에서 글자 `accent` | 규칙 9 |
| 인용된 카드 링 | 2px + 28px 글로우 | **1.5px accent 55% + 약한 그림자** | 한 화면에 3장이 동시에 떠도 시끄럽지 않게 |
| `tile` (신규) | — | 카드 안 종류 아이콘 타일 배경 `ink` 8% (다크 `#FFF` 12%) | 규칙 5, ref 04 |
| `thumbBg` (신규) | — | PDF 썸네일 뒤 패널 `ink` 4.5% (다크 `#FFF` 5%) | ref 02 |
| `warnTint` (신규) | 카드 전체 앰버 채움 | **`#FFF8EC`**(다크 `#2D2410`) + 1.5px `warnBorder` | v1 스펙 5.3 원문 / 버터 노트와 색 혼동 제거 |
| `chipBg` (신규) | — | `#FFF` 55% (다크 5%) | 칩 배경 |
| `scrim`, `sheet` (신규) | — | `#1E160C` 40% / 라이트 `#FFFDFA` 86%(다크 `#282130` 88%) | 시트 |
| 노트 `lilac` | 프로토 `#E6DDFB` | 스펙값 `#E9E3FC`로 복귀 | v1 프로토가 스펙에서 벗어났었음 |
| 노트 그림자 | 이중 그림자 | **`ink` 6%, blur 8, y 2**, 호버 `ink` 10%, blur 16, y 6(translate 없음) | 규칙 5, 13 |

### 2.2 치수 (변경)

| 항목 | v1 프로토 | v2 | 근거 |
|---|---|---|---|
| 데스크톱 프레임 | 반경 28, 패딩 16, gap 16 | 반경 **28**, 패딩 **24**, gap **24** | 규칙 3, ref 14 |
| 열 | 248 / 1fr / 400 | **240 / 1fr(가변, 1440에서 724) / 380** | 규칙 3, ref 05·17 |
| 사이드바 항목 | 44 | **40**, 활성 = 풀폭 `accent` 단색 pill | 규칙 3 |
| 보드 제목 | 36 | **32** / -0.3 | 규칙 4 |
| 노트 상세 제목 | 34 | **28/600, -0.3** | 규칙 4, ref 11 |
| 섹션 라벨 | 11/.08em | **11/600, +0.8px, 대문자, `inkMuted`**, 우측 원형 `+` | 규칙 14, ref 07·09 |
| 시트 상단 반경 | 28 | **24**, 핸들 **36×4** | 규칙 10 |
| 컴포저 입력 행 | 52 pill | 데스크톱 **56** / 모바일 **52**, 컨테이너 반경 20(3행이라 pill 불가) | 규칙 7 |

타입 스케일은 규칙 4 그대로: 빈 상태 헤드라인 40(데스크톱, 모바일 28~32), 답변 15/1.55, 카드 제목 18/600/1.25, 라벨 13/500.

## 3. 컴포넌트 델타

### 3.1 노트·PDF 카드 (규칙 5, 11, v1 5.1–5.3 / ref 04, 07, 10)
- **헤더 행 추가**: 종류 아이콘 타일 32(모바일 28, 반경 10, `tile`) + `종류 · 날짜` 12px `inkMuted`(예: `Note · 2m ago`, `PDF · 12 pages`). 하단 푸터에는 티어 배지만 남긴다.
- **PDF 카드는 흰 종이**(`pdfPaper`) + 헤어라인. v1 프로토는 하늘색이었다(스펙 위반). 썸네일은 `thumbBg` 패널 안에서 **아래가 잘린 흰 페이지**로 표시(높이 116). 인용된 구절은 `accent` 18% 하이라이트.
- **색인 실패 카드**: 흰/`warnTint` 배경 + 1.5px `warnBorder`, 안쪽에 `warnContainer` 상태 블록(경고 아이콘 + `Indexing failed`) 아래 줄에 **Re-index 외곽 pill(32)**, 그 아래 `Keyword search only`(데스크톱). 카드 폭 230에서 한 줄에 다 안 들어가서 세로 배치로 확정.
- 인용된 카드 상단 태그: `⚡n`, PDF는 `⚡1 · p.4`(accent 단색 pill 22).

### 3.2 데스크톱 셸 (규칙 3, 2 / ref 05, 08, 14)
- 사이드바: `⚡`(accent 24, **타일 없음**) + 세리프 워드마크 → 태그라인 → Ask / Notes(카운트) / Projects / **Settings** → `TIERS` 라벨 + 티어 3행 → 하단 **키보드 힌트**(`⌘K Search everything`, `Esc Close preview`, ref 16). **아바타/계정 블록 제거**(v1 스펙 5.7 "아바타 없음"을 프로토가 어겼었다).
- 보드는 컨테이너 없이 배경 위에 직접(v1 스펙 6). 제목 32 → 메타 → 검색(44, 반경 16, `⌘K` 힌트) + `New note`(단색 accent) + `Upload PDF`(보조) → 필터 칩(`All 8 / Notes 6 / PDFs 2 / ⚠ 1 needs attention`) → `RECENT` 라벨 + 원형 `+` → 3열 masonry(gap 16, 하단 10% 페이드).
- Ask 패널: 헤더 `⚡ Ask`(세리프 28) + 우측 원형 아이콘 2개(기록, 새 대화). **스코프 칩과 모델 pill은 헤더가 아니라 컴포저로 이동**(ref 17).

### 3.3 답변 카드 (규칙 8, 9 / ref 01, 03, 19, 20)
위에서 아래 순서 고정:
1. 시간 스탬프 → 사용자 말풍선(**violet 그라데이션**, 흰 글자 15/500, 반경 18/우하 6, 최대 80%). v1 프로토는 버터색이었다(스펙은 violet).
2. **단계 로그 한 줄**(접힘): `✓ Searched 8 items · read 2 PDFs · 2.8 s ⌄`(12px `inkMuted`, 체크만 `success`) (ref 20). 생성 중에는 줄이 120ms 간격으로 나타난다.
3. 답변 카드(`glassStrong`, 반경 **좌상 6 / 나머지 18**, 최대 92%, 패딩 16): 본문 15/1.55 + 인라인 `⚡n` → `hairline` → `SOURCES`(11/600 대문자) → 인용 칩 행 → **액션 행**(복사 · 다시 생성 · 👍, 20px `inkMuted`, 히트 32) + 우측 `Gemma 4 26B · 2.8 s`(데스크톱).
4. 인라인 `⚡n`: 높이 18, 패딩 0 6 0 4, `accentContainer`/`onAccentContainer`, 번개 12 + 숫자 12/600, **구두점과 `nowrap`으로 묶는다**(`⚡1` 뒤 마침표가 다음 줄로 떨어지는 문제를 프로토에서 확인함 — Flutter에서는 `WidgetSpan` 뒤에 `⁠`(word joiner) 또는 마침표를 같은 `TextSpan`에 `WidgetSpan`과 함께 둔다).
5. 하단 칩: 높이 32, 1px accent 테두리, `⚡1 · Spec.pdf p.4` / `⚡2 · Budget memo` / `⚡3 · 회의록`. **번호는 답변 안 등장 순서**이며 보드 카드 태그와 같은 번호를 쓴다(보드의 Spec.pdf = `⚡1 · p.4`). 3개 초과 시 모바일은 리스트 행(규칙 9).

### 3.4 컴포저 (규칙 7 / ref 17, 20, 18)
`glassStrong` 컨테이너(반경 20, 패딩 12) 안 3행: **① 스코프 칩**(28, `My notes ✓` · `Hackathon ✓` · `+ Scope`) → **② 입력**(56/52, 힌트 `Ask your notes & documents…`) → **③ 하단 행**: 첨부 `+`(36 원형, PDF 업로드) · 모델 pill(32, `Gemma 4 26B [free] ⌄`) · 우측 **전송 40×40**. 빈 입력의 전송은 `hairline` 채움 + `inkMuted` 아이콘, 입력이 있으면 `accent` 단색. 포커스 시 **하단 가장자리에만** `accent` 글로우(높이 2, blur 16, 120ms 페이드)가 켜진다(`desktop-empty.png`에서 포커스 상태). 컴포저 아래 면책 한 줄 `AI can make mistakes. Check the ⚡ sources.`(11.5 `inkMuted`).
**전송 버튼은 그라데이션이 아니라 단색**: 규칙 7은 `accentGradient`, 규칙 14는 "화면당 1개"라 충돌한다. v2는 14를 우선하고 그라데이션은 말풍선/FAB에만 쓴다.

### 3.5 Ask 빈 상태 (규칙 6 / ref 18, 03, 05, 17)
`desktop-empty.png`: 사이드바 Ask 활성 + 중앙 `glass` 스테이지(상단에 라벤더/피치 글로우, ref 06). 폭 760 중앙 컬럼: 유리 엠블럼 56(`⚡` 28 accent) → **세리프 40 "Ask your notes anything."** → 서브카피 `Every answer links back to a ⚡1 source — tap it to blink to the page.`(실제 `⚡n` pill 인라인) → **제안 카드 4열**(높이 124, 반경 16, `glassStrong`, 아이콘 타일 32는 노트 파스텔 4색, 제목 14/600, 설명 12 두 줄 말줄임) → 포커스 컴포저 → 면책 + `⏎ send / ⇧⏎ new line`. 규칙 6은 112를 제안했으나 설명 2줄이 잘려서 **124**로 상향. 제안 문구는 실제 노트에서 만든다(`Summarize 회의록`, `Check a PDF page` 등). 모바일은 2열 가로 스크롤(프로토에는 없음, 데스크톱만 확정).

### 3.6 출처 시트 (규칙 10 / ref 01, 16)
`mobile-citation.png`: Ask 화면 위 스크림(`ink` 40%) + 하단 시트 **높이 화면의 62%(523)**, 반경 24, 핸들 36×4.
`CITED IN AI ANSWER`(11/600 대문자) ↔ `‹ Source 1 of 3 ›`(accentContainer pill 28) → 출처 행(문서 아이콘 40 + 세리프 18 `Spec.pdf` + `PDF · Hackathon` + **`Page 4 of 12 ⌄`** 선택) → 종이 패널(흰, 반경 12, 높이 236, 세리프 소제목 + 본문 13/1.6, **하이라이트 `accent` 18% 반경 4**, 하단 페이드, 쪽 번호) → **`Open full page`**(accent 단색 48) → `Esc to close`. 종이 패널은 다크에서도 종이색(`#F7F3EA`)과 어두운 글자를 유지한다. 데스크톱은 v1 그대로 보드 위 오버레이(최대 440), Ask 패널 유지.

### 3.7 모바일 보드 / 에디터 / 업로드 (규칙 12, 11 / ref 04, 12, 11, 13)
- **보드**: 헤더 = `Good morning, Chris`(14 `inkMuted`) + 세리프 `Notes` 28 + 우측 원형 검색 버튼. **Ask 진입 pill**(높이 48, `glassStrong`, 힌트 `Ask your notes…`, 우측 36 단색 accent 원형 ⚡)이 헤더 아래 상시 노출. `RECENT` + `See all` → 2열 masonry(gap 12). FAB: `New note`(**이 화면의 유일한 그라데이션**) + 작은 유리 업로드 FAB. 하단 내비 활성 = accent 아이콘 + `accentContainer` indicator. 아바타 제거.
- **에디터**: 제목 28/600/-0.3, 메타 pill에 `⚡ Cited in 1 answer`(이 노트가 인용된 적 있음 — 보라는 ⚡ 의미일 때만), 서식 바 **맨 앞에 `⚡ Ask` 칩**(ref 12의 AI Edit), 이어서 H B I | 목록 체크 인용 코드. 화면 배경은 노트 파스텔.
- **업로드 시트**: 제목 `Add PDF`(세리프 24) → **점선 드롭 영역 140**(`hairline` dashed 1.5, 반경 16, 아이콘 + `Choose PDF`) → 선택된 파일 행(작은 페이지 썸네일 + 이름 + `12 pages · 2.4 MB` + `✓ Ready`) → `WHERE SHOULD IT LIVE?` → 티어 라디오 3행(Cloak은 Soon으로 비활성, 선택 행은 `ink` 2px 테두리) → `Upload Spec.pdf`. (색인 단계 체크리스트 `업로드→추출→임베딩→준비됨`은 이번 프로토에 그리지 않았다. 규칙 11 그대로 구현.)

## 4. 레퍼런스 → 변경 매핑 (요약)

| 변경 | ref |
|---|---|
| 구석 글로우 2개, 본문 영역은 흰 면 | 06, 09, 12 |
| 유리 62/74 + 헤어라인 + 반경 28/24/16 | 07, 08, 14 |
| 240 / 가변 / 380 + gap 24 | 05, 08, 17, 20 |
| 카드 헤더 아이콘 타일 + `종류 · 날짜`, PDF는 종이 | 04, 09, 10 |
| 답변 카드 구조(본문 → 헤어라인 → Sources → 칩 → 액션) | 01, 03, 16, 19 |
| 단계 로그 + 완료 시간 | 20 |
| 컴포저 3행(스코프/입력/첨부·모델·전송), 하단 글로우 | 17, 20, 18 |
| 빈 상태(세리프 헤드라인 + 신뢰 문구 + 제안 카드 + 면책) | 18, 03, 05 |
| 출처 시트 `Cited in AI answer · Source 1 of 3` + 하이라이트 | 01, 16 |
| 모바일 Ask 진입 pill, 인사 라벨 + 세리프 제목 | 12, 04 |
| 선택 칩/활성 탭 = accentContainer | 15 |
| 키보드 힌트, 섹션 소형 라벨 | 16, 07, 09 |
| 그라데이션 면 화면당 1개 | 09 |

## 5. Flutter 적용 체크리스트 (`app/pageblink_flutter`)

이미 있는 것: `Pb`(ThemeExtension) 토큰, `GlassPanel`, `PbBackground`, 사용자 `glass` 62% / `glassStrong` 74%(`app/theme.dart`). 아래는 **남은 변경**.

### `lib/app/theme.dart`
- [ ] `Pb`에 추가: `tile`, `thumbBg`, `warnTint`, `chipBg`, `scrim`, `sheet`, `success`, `accentGradientDark` 조정(`#6C4CF5→#7A5CFF`). `accent`(단색)를 `ColorScheme.primary`와 같은 값으로 노출해서 `FilledButton`/활성 내비/전송이 그라데이션 대신 단색을 쓰게 한다.
- [ ] `GlassPanel`: `sigma` 18 확인(18 이상이면 낮춤), `strong` 플래그(L2) 추가, 반경 기본 24, 외곽 프레임은 `Container`(28)로 분리.
- [ ] `PbBackground`: 중앙 블러 원 제거, 좌상/우하 `RadialGradient` 2개(알파 45~55%) + 선형 3색. 그레인은 선택.
- [ ] `lilac` 노트색 `#E9E3FC` 유지(프로토 이탈분은 반영 불필요).

### `lib/main.dart` (셸)
- [ ] 데스크톱(≥1024): 외곽 `Container(borderRadius: 28)` 안 `Padding(24)` + `Row` gap **24**. 사이드바 `SizedBox(width: 240)`(기본 `NavigationRail` 대신 커스텀 `ListView` — 항목 높이 40, 활성 `accent` 단색 pill, 카운트, **Settings 항목**, `TIERS` 섹션, 하단 `⌘K`/`Esc` 힌트). Ask 패널 폭 **380 고정**(현재 `>=1400 ? 420`은 380으로, 넓은 화면은 보드가 늘어나게).
- [ ] 보드 최대 폭은 1100, 그 이상이면 중앙 정렬.
- [ ] 사이드바 Ask 항목 선택 시 중앙을 **Ask 빈 상태 스테이지**로 교체(데스크톱 전용 `AskStage`).
- [ ] `<600`: `NavigationBar` 활성 indicator `accentContainer`, 배경 `GlassPanel`(상단 반경 24). `AppBar` 제거하고 화면별 헤더를 직접 그린다.
- [ ] 키보드: `Shortcuts`/`Actions`로 `⌘/Ctrl+K` 검색, `Esc` 미리보기 닫기.

### `lib/features/documents/documents_screen.dart` (`_DocumentCard`, 보드)
- [ ] 카드 헤더 행: 타일 32(`tile`, 반경 10) + `종류 · 날짜` 12px. 푸터는 티어 배지만.
- [ ] PDF 카드 `pdfPaper` 흰색, 썸네일을 `thumbBg` 패널(높이 116, `ClipRRect`)에 **상단 정렬로 아래를 잘라** 배치.
- [ ] 색인 실패: `border: 1.5 warnBorder`, 배경 `warnTint`, 안에 `warnContainer` 블록(아이콘 + 문구 + 아래 줄 `OutlinedButton` 32 "Re-index"). 카드 전체를 앰버로 채우지 않는다.
- [ ] 인용된 카드: 1.5px `accent` 55% 링 + `⚡n` 태그(`Positioned(top: -10, right: 14)`), 링 펄스 0.6s(reduced motion 시 생략).
- [ ] 필터 칩: `All`이 `accentContainer` 선택 스타일, `⚠ n needs attention`은 `warnContainer`. 섹션 라벨 `RECENT`(11/600/+0.8) + 원형 `+`.
- [ ] 모바일: 헤더(인사 라벨 + 세리프 `Notes` 28) 아래 **Ask 진입 pill**(48, 탭하면 Ask 탭으로 전환), FAB는 `New note`만 `accentGradient`(+ 작은 유리 업로드 FAB), 리스트 `padding.bottom = 내비 + 96`.
- [ ] 업로드 시트 `Add PDF`: 점선 드롭 영역(`DottedBorder` 또는 `CustomPainter`, 높이 140) → 파일 행 → 티어 라디오 3행(Cloak 비활성) → 기본 버튼.

### `lib/features/ask/ask_screen.dart` (`_TurnView`, `_ScopeBar`, `_ModelPicker`, `_EmptyHint`)
- [ ] `_TurnView`: 사용자 말풍선만 `accentGradient`(흰 글자 15/500). 답변은 말풍선이 아니라 `GlassPanel(strong)` 카드, `BorderRadius.only(topLeft: 6, 나머지 18)`, 최대 폭 92%.
- [ ] 답변 카드 내부 순서 고정: 본문(`⚡n`은 `WidgetSpan`, 구두점은 `⁠`로 붙임) → `Divider(hairline)` → `SOURCES` 라벨 → `Wrap(spacing 8)`의 `ActionChip` 32 → 액션 `Row`(복사, 다시 생성, 좋아요 `IconButton` 32, 아이콘 20) + 우측 모델/시간. 칩 최대 5 + `+N`, 같은 노트는 `p.4, p.7`로 합침, 모바일 3개 초과 시 리스트 행(56).
- [ ] 답변 위 **단계 로그 한 줄**(`ExpansionTile` 축소형): 검색 항목 수/읽은 PDF/걸린 시간. 스트리밍 중에는 줄을 120ms 간격으로 노출.
- [ ] `_ScopeBar` + `_ModelPicker`를 컴포저 안으로 이동: 컴포저 = `GlassPanel(strong, radius 20)` > 칩 행 → `TextField`(최소 56/52, 최대 5줄) → 하단 `Row`(첨부 `+` 36, 모델 `MenuAnchor` pill 32, `Spacer`, 전송 40 원형). 전송은 입력 비면 `hairline` 비활성, 있으면 **단색 accent**.
- [ ] 포커스 글로우: `FocusNode` 리스너 + `AnimatedContainer`/`DecoratedBox` 하단 2px `accent`(blur 16), 120ms, `MediaQuery.disableAnimations`면 생략. 마이크 없음.
- [ ] `_EmptyHint` → `AskEmpty`: 엠블럼 56 → `displaySmall`(Fraunces 40, 모바일 28~32) → 서브카피(`⚡n` pill) → 제안 카드(데스크톱 4열 `GridView`, 모바일 2열 가로 스크롤, 높이 124) → 컴포저 → 면책 한 줄. 제안 문구는 최근 노트 제목으로 생성.
- [ ] 패널 헤더: `⚡ Ask`(Fraunces 28) + 기록/새 대화 아이콘 버튼 36.

### `lib/features/viewer/page_viewer_screen.dart` (출처 시트)
- [ ] 모바일: 전체 라우트 대신 `showModalBottomSheet`(높이 `MediaQuery.height * .62`, 상단 반경 24, 핸들 36×4, `GlassPanel` 배경 + `scrim` 40%). 상단 `CITED IN AI ANSWER` ↔ `‹ Source n of N ›`(accentContainer pill, 탭/스와이프로 다음 출처), 출처 행 + 쪽 선택 `DropdownMenu`, 본문 패널(종이색), 구절 하이라이트 `accent` 18%(반경 4, `TextSpan.backgroundColor`는 반경 불가 → `WidgetSpan` 또는 `CustomPaint`), 하단 `Open full page`(→ 기존 `PageViewerScreen` 전체 화면).
- [ ] 데스크톱: 보드 위 오버레이(최대 폭 440), Ask 패널 유지, `Esc` 닫기 + 힌트 표기.
- [ ] 하이라이트 없는 마크다운 노트: 해당 단락만 스크롤 + `accentContainer` 1.2s 페이드.

### `lib/features/notes/note_editor_screen.dart` (선택)
- [ ] 제목 28/600/-0.3, 메타 pill `⚡ Cited in n answers`, 서식 툴바 맨 앞 `⚡ Ask` 칩.

## 6. 한계와 미확정

- 프로토타입의 PDF 페이지는 CSS로 그린 가짜 본문이다. 실제는 서버 렌더 PNG.
- 단계 로그의 문구/시간은 예시다. 서버가 실제로 내려주는 필드(검색한 항목 수, 읽은 PDF 수, 소요 시간)가 있는지 확인이 필요하다. 없으면 한 줄 로그는 생략하고 `Searched n items`만 쓴다.
- 모바일 빈 상태, 태블릿(600–1024) 레이아웃, 색인 진행 체크리스트는 이번 프로토에서 그리지 않았다(v1 스펙 + 규칙 6·11 유지).
- `⚡n` 인라인 pill의 `vertical-align`은 CSS로 맞췄다. Flutter에서는 `PlaceholderAlignment.middle`과 `baseline` 중 한글 본문에서 덜 흔들리는 쪽을 실기기에서 골라야 한다.
- 레퍼런스 이미지는 영감용이며 어떤 에셋도 가져오지 않았다(`../references/README.md` 사용 조건).
