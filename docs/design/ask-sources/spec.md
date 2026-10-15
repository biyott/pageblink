# Ask 답변 말풍선의 출처 표시 — 디자이너 검토와 개선 스펙

작성 2026-10-15 13:26 KST. 기준 방향은 채택된 **AB v2**(`../ab-v2/spec.md` §3.3 + `../ab-glass-paper/spec.md` 토큰, 구현은 `app/pageblink_flutter/lib/app/theme.dart`의 `Pb`). 새 방향이 아니라 **"AB v2가 이미 정한 알약 마커·출처 목록을 구현이 놓친 부분을 되돌리고 다듬는"** 문서다. 새 색 토큰은 만들지 않는다. **저장소 코드는 수정하지 않았다**(시안·계산은 세션 스크래치패드에서만).

> 표기: ✅ 코드·소스·실행으로 확인 · ⚠️ 미확인/추정. 줄 번호는 쓰지 않고 위젯·함수 이름으로 가리킨다.

| 파일 | 내용 |
|---|---|
| `before-after.svg` / `before-after.png` | 전/후 한 장. 라이트·다크 × (전 380 / 후 380 / 후 폰 390), 하단에 마커 상태·행 상태·플래시 곡선. SVG 직접 작성, 글꼴은 Pretendard 대체, 아이콘은 Lucide 외곽선(실제 앱 글리프) |
| 이 문서 | 진단, 마커/출처/모션 값, 구현 체크리스트, 테스트 계약 |

## 0. 한 장 요약

**진단 3줄**
1. **마커가 "보라 UI 속 노란 이모지 띠"다.** `⚡`(U+26A1)는 번들 NotoSansKR 서브셋에 없고(✅ `fc-query`로 U+26xx 없음) Inter에도 없을 가능성이 커서 OS 컬러 이모지로 폴백한다(⚠️ 기기 미확인). 배경은 `TextStyle.backgroundColor`라 **반경을 줄 수 없어** 줄 높이 전체를 덮는 사각 띠가 된다(✅ 코드). AB v2 §3.3-4가 정한 "알약 18, 번개 12 + 숫자 12/600"에서 벗어났다.
2. **출처 칩이 화면에서 가장 무겁다.** 채도 100% `accent` 1px 외곽선 + 번개 아바타 16 + `1 · 제목 p.4` 한 문자열의 `ActionChip`. 같은 번개가 N번 반복되고, 번호·제목·위치·종류의 위계가 없으며, 범위 버튼·모델 pill·예시 카드(전부 `chipBg` + `hairline`)와 말이 다르다. 긴 제목은 `maxLines` 지정이 없어 알약이 2줄로 커진다(⚠️ 코드 추론).
3. **플래시가 "번쩍"이다.** 900ms에 cos 2회(피크 간격 450ms), 글로우 알파 45%·spread 2. 끝이 급해서 시선이 도착하기 전에 꺼진다.

**새 구조**: 본문 마커 = **알약(WidgetSpan) `⚡n`**(accentContainer 채움, Lucide 번개, 반경 999). 출처 = **행(row) 카드**: 번호 배지 + 제목(1줄) + `PDF · 4쪽`/`노트` 보조줄 + `›`. 행은 composer와 같은 `chipBg` + `hairline`, 보라는 번호 배지와 헤더 번개 하나뿐. 출처 3개 초과 시 3개 + "외 N개 더 보기". 플래시는 1.6초, 비대칭 2회, 색 변화 + 부드러운 글로우(스케일 없음), 마커가 먼저 짧게 반응하고 행이 이어받는다.

## 1. 본문 인라인 마커 `⚡n`

### 1.1 선택: 텍스트 스팬 → `WidgetSpan` 알약

| | A. 현재(TappableTextSpan) | **B. WidgetSpan 알약 (채택)** |
|---|---|---|
| 모서리 | 사각(반경 불가) | 반경 999 |
| 높이/기준선 | 줄 박스 전체 | 18 고정, `PlaceholderAlignment.middle` |
| 번개 | OS 이모지 폴백 | Lucide `zap`(accent), 이모지 아님 |
| 호버·눌림·포커스·플래시 | `hoverStyle`만 | 위젯 상태 전부, 자체 `AnimatedBuilder` |
| 줄바꿈/선택/스트리밍 | 글자 단위 | **한 덩어리(줄바꿈 불가, 선택 건너뜀, 스트리밍 reveal에서 문자 1개)** — 짧은 알약이라 허용 |
| 기존 테스트 | `_tapMarker`가 `'⚡n'` 텍스트 오프셋을 탭 | **헬퍼 교체 필요(§5.4)** |

gpt_markdown 1.3.4가 이를 공식 경로로 제공한다: `SourceTagBuildDetails.asWidgetSpan(chip, alignment: middle)`(✅ 소스, `markdown_config.dart`). 패키지의 래핑(문단 배율 추종)을 그대로 쓰므로 손으로 `WidgetSpan`을 만들지 않는다. ⚠️ 패키지 문서가 "다른 placeholder 안에 중첩되면 iOS에서 안 그려질 수 있다"고 적어 두었다. 표 셀·목록 안 마커는 실기기 확인 필요.
**B가 막히면 플랜 B**: 텍스트 스팬 유지 + `fontFamily: 'Lucide'`로 번개 글리프를 `TextSpan`에 넣고 이모지만 제거(반경은 포기). 이모지 문제는 이것만으로 해결된다.

### 1.2 치수·색 (본문 글자 크기 f 기준, 값은 모두 `f`에서 파생)

| 항목 | 값 | 근거 |
|---|---|---|
| 높이 | `min(18, 줄높이 − 2)` — 본문 15/1.55면 18 | 줄 높이를 키우면 마커 있는 줄만 벌어진다 |
| 가로 패딩 | 왼 4 · 오른 6 (번개 쪽이 시각적으로 무거워 오른쪽을 더 줌) | AB v2 §3.3-4 `0 6 0 4` |
| 번개 | Lucide `zap` **600 굵기**(`LucideIcons.zap600`, ⚠️ 존재 미확인 — 없으면 `zap` + 작은 크기에서 얇음 감수) 10px, 색 `pb.accent` | 11px 이하에서 획이 굵어야 번진다 |
| 번개–숫자 간격 | 2 | |
| 숫자 | 12 / **700** / `tabularFigures`, 색 `pb.onAccentContainer` | Hangul 서브셋에는 600까지만 있으나 숫자는 Latin(Inter)이라 700 사용 가능 |
| 채움 | **`pb.accentContainer` 불투명**(라이트 `#EAE4FD`, 다크 `#3A2F7A`) | 알파 14% 대신 불투명 → 뒤 말풍선 색이 달라도 같은 색. 시트의 `1 / 3` pill과 같은 조합 |
| 모서리 | 999 | |
| 기준선 | 알약 중심 = 줄 박스 중심 아래 0.5px(`middle`) | x-height 중간보다 살짝 아래 — 숫자가 소문자와 같은 높이로 읽힘 |
| 이웃 간격 | 좌우 투명 패딩 2(`SourceTagStyle(padding: EdgeInsets.symmetric(horizontal: 2))`) + `renderMarkers`의 공백 | `⚡1 ⚡2` 연속 시 알약 사이 ≈ 8 |
| 터치 영역 | 알약 + 가로 4 → 약 34×18 | 아래 §1.4 |

대비(✅ `contrast.py`로 계산, 말풍선 합성색 기준):

| | 라이트 | 다크 |
|---|---|---|
| 숫자 `onAccentContainer` / 채움 | 10.3 : 1 | 9.0 : 1 |
| 번개 `accent` / 채움 (비텍스트 3:1 기준) | 4.3 : 1 | 5.3 : 1 |
| 전: 숫자 / accent 14% | 10.3 : 1 | 5.8 : 1 |
| 알약 채움 / 말풍선 | 1.22 : 1 | 1.25 : 1 |

마지막 줄: 알약의 **경계** 대비는 낮다. 번개 + 숫자가 정체성을 전달하므로 허용하지만(⚠️ WCAG 1.4.11 해석상 번개 아이콘이 식별 수단이라는 가정), 더 키우려면 채움을 `accent` 14% → `accent` 20% 겹침으로 올리는 것이 한계.

### 1.3 상태

| 상태 | 채움 | 숫자/번개 | 기타 |
|---|---|---|---|
| 기본 | accentContainer | onAccentContainer / accent | |
| 호버(데스크톱) | accentContainer 위 accent **12%** | 동일 | 커서 `click`, 툴팁(선택): 문서 제목, 지연 500ms |
| 눌림 | accentContainer 위 accent **24%** | 동일 | 120ms |
| 포커스(키보드) | 기본 | 동일 | 바깥 2px `accent` 링, 오프셋 0(레이아웃 불변) |
| 탭 직후(ack) | **`accent` 불투명**으로 전환 | `onPrimary` | scale 1.0→1.08→1.0 (레이아웃 불변, §3) |
| 비활성 | 해당 번호의 출처가 아직 안 도착 | | 기본과 동일하게 둔다(탭하면 아무 일 없음 — 기존 동작). 투명도를 낮추면 스트리밍 중 깜박여 보임 |

### 1.4 터치 영역 (정직하게)

인라인 마커는 **줄 높이를 키우지 않는 한 44px에 못 닿는다**(WidgetSpan의 히트 영역은 자기 박스). 가로만 34로 넓히고 세로는 18~24로 둔다. WCAG 2.2 SC 2.5.8(최소 24×24)에는 "문장 안에 있는 인라인 대상" 예외가 있다(⚠️ 일반 지식, 원문 미확인). 접근 가능한 주 경로는 **아래 출처 행(높이 48)**이다. 마커는 보조 경로로 둔다.

## 2. 출처(SOURCES) 영역

### 2.1 구조와 위계

```
──────────── hairline ────────────
⚡ 출처  3                         ← 헤더 16: 번개 12(accent) + 라벨 11/600/+0.8 + 개수
┌──────────────────────────────────┐
│ (1)  Q3 예산 가이드라인.pdf    › │  ← 행 48: 배지 22 · 제목 13/600 · 보조줄 12/400
│      ▯ PDF · 4쪽                 │
└──────────────────────────────────┘
┌──────────────────────────────────┐
│ (2)  예산 정책 메모            › │
│      ▯ 노트                      │
└──────────────────────────────────┘
  외 2개 더 보기 ⌄                    ← 4개 이상일 때만, 32
```

| 항목 | 값 |
|---|---|
| 구분선 | `pb.hairline`, 본문과 16 간격(전: 12) |
| 헤더 | 구분선 아래 12, 높이 16. 번개 `AppIcons.citation` 12 `pb.accent`, 간격 6, 라벨 `sourcesLabel.toUpperCase()` 11/600/+0.8 `subInk`(아래), 개수 숫자 같은 스타일. **번개가 UI 전체에서 헤더와 마커 두 군데만** 남는다(ADR 016 "번개는 인용에만") |
| 헤더–목록 | 8 |
| 행 모양 | `Material(color: pb.chipBg)` + `RoundedRectangleBorder(radius 14, side: hairline 1)` — **`_SuggestionCard`와 동일 규칙** |
| 행 높이 | 최소 44, 실제 약 48(패딩 위아래 8 + 13/600 한 줄 + 12 보조줄). 행 간격 8 |
| 행 내부 | 왼 12 · 오른 12. `[배지 22] 10 [제목·보조줄 Expanded] 8 [› 16]` |
| 번호 배지 | 원 22, `pb.accentContainer`, 숫자 12/700 `onAccentContainer`. **마커와 같은 색 → 번호로 짝이 읽힘**. 번개 없음 |
| 제목 | 13/600 `pb.ink`, `maxLines: 1`, `TextOverflow.ellipsis`. Hangul 서브셋에 500이 없어 600 사용(전 500은 한글에서 400으로 합성됨) |
| 보조줄 | 아이콘 12(`AppIcons.pdf` / `AppIcons.note`) + 12/400. PDF `'${l.kindPdf} · ${l.pageN(c.page)}'`, 노트 `l.kindNote` — **`citation_sheet.dart`가 이미 쓰는 문자열과 동일**(새 l10n 불필요) |
| 후행 | `AppIcons.next` 16, `subInk`. 호버·눌림 시 `accent` |
| 종류 구분 | 텍스트(`PDF`/`노트`) + 아이콘, 색은 쓰지 않음(노트 파스텔 색을 가져오면 6색이 되어 산만) |

`subInk`(보조 글자색): 라이트 `pb.inkMuted`(5.9 : 1), **다크 `pb.ink` 알파 75%**(4.6 : 1). 다크 `inkMuted`는 말풍선·행 위에서 **2.9~3.3 : 1로 AA 미달**이다(✅ 계산). 이 문서에서는 파생 색으로 처리하고, `Pb.dark.inkMuted`를 전역으로 올리는 일은 후속 과제로 남긴다(⚠️ 앱 전체 영향 — 별도 검토).

### 2.2 왜 외곽선 알약이 어색했나 (비교)

| | 현재 칩 | 이 안 |
|---|---|---|
| 채도 | accent 100% 외곽선 | hairline + 보라는 22px 배지뿐 |
| 번개 | 칩마다 1개(N개) | 헤더 1개 |
| 정보 | `1 · 제목 p.4` 한 줄 문자열 | 번호 / 제목 / 종류·위치 분리 |
| 긴 제목 | 줄바꿈으로 알약 2줄(⚠️ 추론) | 1줄 말줄임 |
| 일관성 | 범위 버튼·모델 pill과 다른 말 | `chipBg` + `hairline` + 14 반경 |
| 터치 | ActionChip compact ≈ 28~32 | 행 ≥ 44 |

### 2.3 배치·폭 규칙

말풍선 안쪽 폭 = `(패널폭 − 목록 패딩 32) × 0.92 − 패딩 32`(✅ 코드). 계산: 380 패널 → (348)×0.92−32 = **288**, 폰 390 → 358×0.92−32 = **297**, 폰 360 → 328×0.92−32 = **270**.

| 규칙 | 값 |
|---|---|
| 행 최소 폭 | **240**(배지 22 + 10 + 제목 ≥ 112 + 8 + › 16 + 패딩 24 + 여유) |
| 열 수 | `cols = ((inner + 8) / (240 + 8)).floor().clamp(1, 2)` — `LayoutBuilder` |
| 2열 조건 | inner ≥ 488 ≈ 말풍선 폭 ≥ 520 → 목록 폭 ≥ 565. 태블릿(600 이상 전체 폭 Ask 탭)에서만 해당 |
| 380 패널·폰 360~390 | 항상 **1열 전폭**(2열이면 행당 ≈ 140이라 제목이 60~70px만 남는다) |
| 열 사이 | 가로 8, 세로 8. 홀수 개의 마지막 행은 반폭(늘이지 않는다) |
| 최대 폭 | 행은 열 폭을 그대로 채움. 말풍선이 매우 넓은 화면(>720)에서는 말풍선 `maxWidth: 720` 권장(⚠️ 이 문서 범위 밖, 별도 확인) |

### 2.4 많을 때 (접기)

- 출처 ≤ 4: 모두 표시. ≥ 5: 처음 3개 + 텍스트 버튼 **"외 N개 더 보기 ⌄"**(13/600 `pb.ink`, 높이 32, 히트 44 확보: 위아래 투명 패딩 6). 펼치면 "접기 ⌃".
- 다크에서 accent 텍스트는 4.2 : 1(AA 미달)이라 버튼 글자는 `ink`.
- 전개 애니메이션 `AnimatedSize` 200ms `easeOutCubic`(reduced motion: 즉시).
- **마커가 접힌 출처를 가리키면 먼저 펼친다**: 현재 `_cite`는 `_chipKeys[index]?.currentContext == null`이면 조용히 반환한다. 접힘 도입 시 반드시 `setState(() => _expanded = true)` → `await WidgetsBinding.instance.endOfFrame` → 그다음 `ensureVisible` + 플래시.
- 스트리밍 중 새 출처가 도착하면 행이 그냥 나타난다(레이아웃 점프 허용; 접힘 임계값 때문에 4→5번째에서 마지막 행이 접힘 버튼으로 바뀔 수 있음 — 완료 후에만 접기 적용 권장: `turn.done`일 때 접는다).

## 3. 반짝임(플래시) 모션

### 3.1 값 (전 → 후)

| 항목 | 전 | **후** |
|---|---|---|
| 총 시간 | 900ms | **1600ms** (+ 시작 지연, 아래) |
| 맥동 | `(1−cos 4πt)/2` 대칭 2회, 피크 225·675ms, 바닥 0 | **비대칭 2회**: 1.0 → 0.35 → 0.75 → 0. 피크 280·1060ms, 중간 바닥 0.35(완전히 꺼지지 않음) |
| 곡선 | 선형 시간 + cos | 상승 `easeOutCubic`(280ms), 나머지 `easeInOutSine` |
| 행 채움 | 투명 → accent 22% | `chipBg` → **`accentContainer` 불투명**(g로 lerp) |
| 행 테두리 | 고정 accent 1px | `hairline` → `accent` 55% 1px (두께 불변) |
| 글로우 | accent 45% × g, blur 14, spread 2 | accent **30%**(다크 38%) × g, **blur 20, spread 0, offset (0, 2)** |
| 스케일 | 없음 | 행 **없음**(소수 배율에서 글자 번짐·가장자리 흔들림) |
| 마커 반응 | 없음 | 600ms: 채움 accentContainer → accent, 숫자 → onPrimary, scale 1.0 → 1.08 → 1.0 |
| 시작 | 스크롤 끝나자마자 | 스크롤 끝난 뒤, 이미 보이면 **160ms 지연** 후 |
| 스크롤 | 300ms `easeOutCubic`, alignment 0.4 | 360ms `easeInOutCubic`, alignment 0.4 (유지) |
| reduced motion | g=1 고정, 900ms | g=1 고정 **1200ms**, 마커는 채움 전환만(scale 없음), 글로우 blur 고정 12, 램프 없음 |

### 3.2 행 플래시 g(t)

| 구간 | 시간(ms) | g | 곡선 |
|---|---|---|---|
| 상승 | 0 – 280 | 0 → 1.0 | easeOutCubic |
| 1차 하강 | 280 – 760 | 1.0 → 0.35 | easeInOutSine |
| 2차 상승 | 760 – 1060 | 0.35 → 0.75 | easeInOutSine |
| 소멸 | 1060 – 1600 | 0.75 → 0 | easeInOutSine |

구현: `AnimationController(duration: 1600ms)` + `TweenSequence`(가중치 280/480/300/540). 행에는 `Color.lerp`와 `BoxShadow`만 쓰며 레이아웃을 건드리지 않는다.

### 3.3 마커 → 행 연출 (순차)

| 시점 | 마커 | 행 |
|---|---|---|
| 0ms (탭) | ack 시작: 0–120 상승, 120–200 유지, 200–600 `easeOutCubic` 소멸 | 스크롤 필요하면 동시에 시작(360ms) |
| 160ms (이미 보임) 또는 스크롤 끝 | 소멸 중 | **플래시 시작**(위 g(t)) |
| ≈ 1.8s | 끝 | 끝(스크롤 없을 때 0.16 + 1.6) |

시선이 마커 → 행으로 한 번에 이동하도록 두 효과가 **겹치는 구간(약 160~600ms)**을 의도했다. 같은 번호의 마커가 본문에 여러 개면 모두 ack.
빠르게 두 번 탭하면: 이전 `Future`를 토큰으로 무효화하고 `forward(from: 0)`으로 재시작(기존 동작 유지).

## 4. 본문과의 어울림 (말풍선 리듬, 4pt 격자)

| 구간 | 전 | 후 |
|---|---|---|
| 말풍선 | 반경 6/18/18/18, 패딩 16, `glassStrong` + `glassBorder`, 폭 92% | **유지** |
| 본문 → 구분선 | 12 | **16** |
| 구분선 → 헤더 | 10 | **12** |
| 헤더 → 행 | 8 | 8 |
| 행 사이 | 8(칩 runSpacing) | 8 |
| 목록 → 복사 줄 | 8 | **12** |
| 복사 줄 | `IconButton` compact 20, 모델명 12 | 유지 |
| 본문 글자 | **⚠️ 미확인**: `GptMarkdown`에 `style`을 주지 않아 상위 `DefaultTextStyle`(테마 `bodyMedium` 14/1.45로 추정)을 받는다. 과제 설명은 16/1.6, AB v2는 15/1.55 | 마커·행 치수를 `f`에서 파생시켜 어느 값이든 맞춘다. **본문 15/1.55를 명시**하면 AB v2와 일치(권장, 별도 변경) |

## 5. 구현자 체크리스트

### 5.1 파일·함수

| 위치 | 변경 |
|---|---|
| `ask_screen.dart` `_AskTurnViewState._marker` | `TappableTextSpan` → `tag.asWidgetSpan(_CiteMarker(...), alignment: PlaceholderAlignment.middle)`. `ValueKey('cite-marker-$n')`. 의미 라벨 `citeMarkerLabel` 유지 |
| `GptMarkdown(...)` 호출 | `styleSheet: GptMarkdownStyleSheet(sourceTag: SourceTagStyle(padding: EdgeInsets.symmetric(horizontal: 2)))`(⚠️ 생성자 필드명은 `source_tag_style.dart`에서 확인) |
| `_sourceChip` → `_sourceRow` | `ActionChip` 제거. 아래 위젯 트리 |
| `build` 의 SOURCES 블록 | 헤더 Row, `LayoutBuilder` 열 수, 접기 상태 `_expanded`(`State` 필드) |
| `_flash` | duration 1600ms, `TweenSequence`, `SingleTickerProviderStateMixin` → `TickerProviderStateMixin`(마커용 `_ack` 컨트롤러 600ms 추가) |
| `_glow` | 위 g(t)를 반환(reduced: `_reduced ? 1 : _flash.value`) |
| `_cite` | 접힘 펼치기 → 스크롤 → 마커 ack 즉시 → 160ms 지연 후 `_flash.forward(from: 0)` |
| `l10n.dart` | 아래 §5.3 |

**행 위젯 트리 (`Material + InkWell` 커스텀 권장 — `ActionChip`의 높이·패딩·라벨 줄바꿈 제어가 안 되고 상태 색을 줄 수 없음)**

```
AnimatedBuilder(key: _chipKeys[n], animation: _flash)          // ensureVisible 대상
└ DecoratedBox(key: ValueKey('source-chip-$n'),
    decoration: ShapeDecoration(shape: RoundedRectangleBorder(14),
                                shadows: g == 0 ? null : [BoxShadow(...)]))
  └ Semantics(button: true, label: sourceRowLabel(...), excludeSemantics: true)
    └ Material(color: lerp(chipBg → accentContainer, g),
               shape: RoundedRectangleBorder(14, side: lerp(hairline → accent55, g)))
      └ InkWell(customBorder: same shape, onTap: () => widget.onBlink(all, c))
        └ ConstrainedBox(minHeight: 44)
          └ Padding(h: 12, v: 8)
            └ Row[ _Badge(n), 10, Expanded(Column[title, sub]), 8, Icon(next, 16) ]
```

**마커 위젯**: `Material(transparency)` > `InkWell(customBorder: StadiumBorder, onTap: tag.onTap)` > `AnimatedBuilder(_ack)` > `DecoratedBox(StadiumBorder, color)` > `Row[Icon(zap600,10), 2, Text(n, 12/700, tabularFigures)]`. 높이 `SizedBox(height: min(18, lineHeight − 2))`.

### 5.2 토큰 (모두 기존 `Pb`/`ColorScheme`)

`pb.accentContainer`, `pb.onAccentContainer`, `pb.accent`, `pb.chipBg`, `pb.hairline`, `pb.ink`, `pb.inkMuted`(+ 다크 `subInk` = `pb.ink` 알파 0.75), `colorScheme.onPrimary`(ack 숫자), 아이콘 `AppIcons.citation / pdf / note / next / expand`. 반경 14(행) · 999(마커·배지), 간격 4·8·12·16.

### 5.3 접근성·l10n

| 키 | en | ko |
|---|---|---|
| `sourceRowLabel(n, title, isNote, page)` | `Source 1: Q3 budget guide, PDF page 4` / `Source 2: Budget memo, note` | `출처 1: Q3 예산 가이드라인, PDF 4쪽` / `출처 2: 예산 정책 메모, 노트` |
| `moreSources(n)` | `Show $n more sources` | `출처 $n개 더 보기` |
| `lessSources` | `Show fewer` | `접기` |

마커 의미 라벨은 기존 `citeMarkerLabel`(`출처 n`) 유지, 버튼 역할 부여. 포커스 순서는 본문 마커 → 출처 행 → 복사. 접힘 버튼은 `expanded` 시맨틱 상태 노출. reduced motion은 `MediaQuery.disableAnimationsOf`(기존 `_reduced` 재사용).

### 5.4 기존 동작·테스트 계약 (`test/ask_citation_flash_test.dart`)

| 의존 | 바뀌는 점 |
|---|---|
| `ValueKey('source-chip-$n')`를 가진 **`DecoratedBox`**, `decoration as ShapeDecoration`의 `shadows.first` (`_glow()`) | **유지**: 키·타입·`shadows` 규약 그대로. 모양만 `StadiumBorder` → `RoundedRectangleBorder` (테스트는 shape를 보지 않음). 글로우가 0일 때 `shadows == null`도 유지 |
| `_tapMarker`: `RichText.toPlainText`에서 `⚡n`을 찾아 오프셋 탭 | **교체**: `t.tap(find.byKey(ValueKey('cite-marker-$n')).first)` (WidgetSpan은 평문에서 U+FFFC) |
| 펄스 샘플 225 / 450 / 675ms, 450ms에서 `isNull`(바닥 0) | **교체**: 탭 후 `pump(160ms)` → 시작 지연 통과. 이후 피크1 **+280ms**(`isNotNull`), 바닥 **+760ms**(`isNotNull`, g=0.35), 피크2 **+1060ms**(`isNotNull`), 끝 `pumpAndSettle` → `isNull`. 재탭 재시작 테스트는 "+160ms 시점 g=0 → `isNull`"로 확인 |
| 감소된 모션: 50ms·300ms 사이 같은 `color`, settle 후 `isNull` | 유지(고정 g=1이므로 color 동일). 지속 1200ms |
| `find.textContaining('2 · Doc 2')` | **교체**: `find.byKey(ValueKey('source-chip-2'))` 또는 `find.text('Doc 2')` |
| `renderMarkers` 그룹 | **변경 없음**(함수 불변) |
| 미도착 출처 / 알 수 없는 번호는 무동작 | 유지(`containsKey` 검사). 접힘 중 번호는 펼친 뒤 동작 — **신규 테스트**: 5개 인용 + `[5]` 탭 → 펼침 + `isNotNull` |
| 탭하면 `onBlink(all, c)` | 유지 |

신규 테스트(권장): 마커 높이 ≤ 줄 높이(줄 높이 증가 없음), `textScaler 2.0`에서 행 overflow 0, 긴 제목 1줄 말줄임, 다크 테마 빌드.

## 6. 확인하지 못한 것 (⚠️)

- 실제 본문 글자 크기(14/15/16): `GptMarkdown`이 상속하는 스타일은 코드만으로 확정하지 못했다.
- `⚡`의 OS 이모지 폴백이 실기기·웹에서 어떻게 보이는지(번들 폰트에 글리프가 없다는 것까지만 ✅).
- `ActionChip` 라벨이 줄바꿈으로 2줄 알약이 되는지(코드 추론).
- `LucideIcons.zap600` 존재, Lucide 10px 번개의 선명도.
- `WidgetSpan` 마커의 iOS 중첩 렌더링, 스트리밍 reveal 중 깜박임, 접근성 포커스 순서.
- 시안의 글자 폭은 Pretendard·추정 폭 계산이라 줄바꿈 위치는 실제와 다를 수 있다. 시안은 정적 프레임이라 모션 감각은 이 문서의 곡선 표로만 판단 가능하다.
- 말풍선 최대 폭 720 권장과 다크 `inkMuted` 전역 상향은 별도 검토 필요.
