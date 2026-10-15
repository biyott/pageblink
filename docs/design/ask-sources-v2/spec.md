# Ask 출처 표시 v2 — 회색 알약·노란 번개·무지개 outer glow(선택 후 유지)

작성 2026-10-15 14:35 KST. 앞선 `../ask-sources/spec.md`(구조·마커·행 규칙)와 커밋 `d509b49`(중립 회색 되돌림)를 이어받아, 클라이언트 피드백 "채팅의 출처 chip: 번개는 노랑, 배경은 회색류, 글씨색도 다시 고민 / 클릭 시 효과와 outer glow는 무지개색이고 끝나도 유지"에 맞춰 색과 선택 효과만 다시 설계한다. **저장소 코드는 수정하지 않았다.** 시안은 SVG를 직접 써서 PNG로 변환했고 이미지 생성 모델은 쓰지 않았다(스크래치패드 스크립트, 모든 수치는 계산값).

> 표기: ✅ 코드·계산으로 확인 · ⚠️ 미확인/추정. 줄 번호 대신 위젯·함수 이름으로 가리킨다.

| 파일 | 내용 |
|---|---|
| `ask-sources-v2-1-rest.png` | 평상시 (라이트 / 다크, 380 패널 안 말풍선 폭 320) |
| `ask-sources-v2-2-hover.png` | 호버 · 키보드 포커스 |
| `ask-sources-v2-3-press.png` | 눌림 |
| `ask-sources-v2-4-peak.png` | 선택 직후 피크(탭 후 1132ms, 중심 빛 + 링 상승) |
| `ask-sources-v2-5-settled.png` | 정착: 무지개 outer glow 유지 |
| `ask-sources-v2-6-marker-link.png` | 마커 탭 → 마커 ack + 행 상승 연동(탭 후 320ms) |
| `ask-sources-v2-7-gray-compare.png` | 회색류 후보 A/B/C 비교(라이트·다크) |
| `ask-sources-v2-8-rainbow-timeline.png` | 무지개 12색 · 링 구조 · 타임라인 그래프 |
| `ask-sources-v2-9-contrast.png` | 글씨색·번개 대비 표 |
| `*.svg` | 위 PNG의 원본(수정 가능). 글꼴 Pretendard, 아이콘 Lucide 외곽선 |

시안의 한계(⚠️): 정적 프레임이라 모션은 §5 표로만 판단한다. 번짐은 SVG `feGaussianBlur`로 그렸고 Flutter `MaskFilter.blur`와 시각 강도가 조금 다를 수 있다. 실기기에서 알파를 미세 조정해야 한다.

## 0. 결정 요약

| 항목 | 결정 |
|---|---|
| 마커 알약 | **라이트(개정 2): 사이드바 계층 아이콘 타일과 같은 톤 `Pb.tile`(`#1F1B16` 8% 알파)** + 숫자 **`#1F1B16`(`ink`) 12/600** + 번개 **`#FFCB2E` 채움 + `#1F1B16` 얇은 윤곽**. 숫자 14 : 1, 윤곽 14 : 1(채움만은 1.3 : 1). **다크: 슬레이트 `#626874` + `#FFD54A` 번개 + 흰 숫자(변경 없음)**. 라이트 개정 사유와 수치는 §10 끝 |
| 번호 배지 | 마커와 **같은 색 그대로**(원 22). 번호로 짝이 읽힌다. 번개는 넣지 않는다 |
| 출처 행 | 중립 회색 면(라이트 `#F2F3F5` 불투명 / 다크 흰색 6%) + 중립 테두리. 보라는 포커스에만 남긴다 |
| 글씨색 | 제목 `ink` / 보조줄·`›`·종류 아이콘 **슬레이트 `#555B67`(라이트), `#D2D4DA`(다크)** |
| 선택 | **12색 파스텔 무지개 고리**(스윕 그라디언트 + 번짐 2겹)가 행 바깥에 정착해 **다음 선택·새 턴까지 유지**. 안쪽은 중립 회색 |
| 상태 신호 | 선택됨의 3 : 1 신호는 **중립 선택 테두리**(`#858B96`/`#B4B9C4`)가 맡는다. 무지개는 장식이다 |
| 총 시간 | 1540 → **1440ms**(리드 120 포함) |
| 느린 반짝임 | **넣지 않는다**(§5.5) |

## 1. 진단: 왜 번개 대비가 안 올랐나

1. ✅ **밝은 회색 알약 위의 노란 번개는 물리적으로 3 : 1에 못 닿는다.** 노랑·호박은 명도가 높아(상대 휘도 0.45~0.70) 밝은 회색(0.75~0.80)과 비슷하다. 라이트에서 후보 `#E6E7EB` 위 `#E3A500`은 1.8 : 1, 현재 `#E9E8E6` 위 `#D99A00`은 2.0 : 1이다.
2. ✅ **"알약 배경을 한 단계 진하게"는 반대로 대비를 낮춘다.** `#E4E6EB`→`#DCE0E7`로 어둡게 하면 번개 대비가 1.69 → 1.60으로 떨어진다(번개 휘도에 다가가기 때문). 3 : 1에 닿으려면 휘도 0.17 이하(`#6E7480` 안팎)까지 **한참** 내려가야 한다.
3. ✅ **호박을 더 진하게 하면 갈색(주황 톤)이 된다.** `#C48500`으로 2.5 : 1이지만 "노랑"이 아니다. 이전 피드백(주황 섞임)과 부딪히므로 택하지 않는다.
4. 결론: 번개 3 : 1을 지키려면 알약이 **중간 이상 어두운 회색**이어야 한다. 이것이 시안 7의 B다. 다크는 이미 이 방식이었고(`#4A4850` + `#FFD54A`, 6.4 : 1) 라이트만 달랐다. 한 값(`#626874`)으로 양쪽을 통일한다.

번개 모양도 바꾼다: 지금 `LucideIcons.zap600`은 10px **외곽선**이라 선이 1.5px 안팎이고, 같은 대비 수치라도 훨씬 약하게 읽힌다. **채워진 번개**(면 + 같은 색 0.9px 둥근 이음 선)로 시각 질량을 늘린다.

## 2. 토큰

새 토큰은 `Pb`(앱 전체)에 넣지 않고 `ask_sources.dart`에 `SourceTones`로 둔다(기존 `citeMarkerFill`·`subInkFor`가 이미 이 파일에 있다). 승격은 후속.

| 이름 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `pill` | `#1F1B16` 8% (`0x141F1B16`, `Pb.light.tile`과 동일) | `#626874` | 마커 알약, 번호 배지 |
| `digit` | `#1F1B16` | `#FFFFFF` | 마커·배지 숫자 |
| `bolt` | `#FFCB2E` | `#FFD54A` | 마커 안 번개(알약 위) |
| `boltOutline` | `#1F1B16` | 없음 | 번개 아래에 0.75px 더 넓게 깐 윤곽(라이트만) |
| `headerBolt` | `#E3A500` | `#FFD54A` | 헤더 `⚡ 출처 N`의 번개(말풍선 위, 장식) |
| `rowFill` | `#F2F3F5` 불투명 | `#FFFFFF` 6% (`0x0FFFFFFF`) | 출처 행 면 |
| `rowPulse` | `#E1E3E8` | `#FFFFFF` 10% (`0x1AFFFFFF`) | 선택 중 한 단계 깊은 면 |
| `rowBorder` | `#DADDE3` | `#FFFFFF` 14% (`0x24FFFFFF`, 기존 hairline) | 평상시 테두리 |
| `rowBorderSelected` | `#858B96` | `#B4B9C4` | 선택된 행 테두리(상태 신호) |
| `sub` | `#555B67` | `#D2D4DA` | 보조줄·`›`·종류 아이콘·헤더 라벨 |
| `rowHover` / `rowPress` | `ink` 4% / 8% | 흰색 6% / 10% | 행 오버레이 |
| `markerOverlay` | 검정, 호버 8% · 눌림 16% · 선택됨 14% · ack 24% | 같음 | 알약 위(누를수록 어두워짐) |
| `rainbow` | §5.1 12색 | §5.1 12색 | 고리 |
| `ringTight` / `ringWide` | 알파 0.95 / 0.75 | 0.85 / 0.60 | 번짐 2겹 |

- 제목은 기존 `pb.ink`, 포커스 링은 기존 `pb.accent`(2px) 그대로.
- **`inkMuted`는 건드리지 않는다.** `../ui-polish/spec.md`가 제안한 다크 `#B5AD9F`는 이 말풍선 합성(`#4E4750`)에서 행 위 3.4~3.5 : 1이라 **여기서는 부족**하다(그 문서의 계산은 단층 합성 `#3E3744` 기준). 그래서 출처 영역은 `sub`를 따로 쓴다. 라이트 `#555B67`은 ui-polish의 따뜻한 `#5C5348`보다 약간 차갑고, 칩 색(회색류)과 같은 계열로 읽힌다. 전역 `inkMuted`가 바뀌어도 이 값은 독립이다.
- 말풍선 합성색을 두 가지로 보수적으로 계산했다(✅): 라이트 `#FEFDFD`/`#FCF9FC`, 다크 `#4E4750`(패널 8% + 말풍선 12% 이중)/`#3E3744`(단층). **실제 어느 쪽인지는 ⚠️ 확인하지 못했다**(`ask-sources/contrast.py`는 이중, ui-polish는 단층). 표(시안 9)는 둘 중 나쁜 값이다.

## 3. 인라인 마커 `⚡n`

### 3.1 모양

| 항목 | 값 |
|---|---|
| 높이 | `min(18, 줄높이 − 2)` 유지, 반경 999 |
| 패딩 | 왼 4 · 오른 6 유지 |
| 번개 | **채워진 번개 11×11**(Feather `zap` 폴리곤 `13,2 3,14 12,14 11,22 21,10 12,10`, 24 격자). `CustomPaint`, fill + 같은 색 0.9px 둥근 이음 선. `Icon(AppIcons.citationMarker)` 대체 |
| 번개–숫자 | 2 유지 |
| 숫자 | 12 / **w600** / `tabularFigures`, `digit`. 600이다: 번들 Pretendard 서브셋은 400/500/600뿐이라 w700은 어차피 600 면으로 해석된다(커밋 `a954276`). 어두운 면 위 흰 글자는 더 굵어 보이므로 w700 필요 없음 |
| 글자 색 | **흰색 고정**(`ink` 아님). 알약이 어두워졌기 때문이며, 숫자 5.6 : 1 |
| 터치 영역 | 알약 + 가로 2씩(≈ 34×18) 유지 |

### 3.2 상태

| 상태 | 알약 | 번개 / 숫자 | 기타 |
|---|---|---|---|
| 평상시 | 라이트 `Pb.tile`(말풍선 위 `#EDEBEB`) / 다크 `#626874` | 아래 수치는 다크 기준(라이트는 §10 끝) | |
| 호버(포인터) | 검정 8% 겹침 → `#5A606B` | 번개 4.5 / 숫자 6.3 : 1 | 커서 `click` |
| 눌림 | 검정 16% → `#525761` | 5.1 / 7.3 | |
| 키보드 포커스 | 평상시 | 동일 | 바깥 2px `accent` 링 (레이아웃 불변) |
| 선택됨(picked) | 검정 14% → `#545964` + **얇은 무지개 링(강도 0.65)** | 5.0 / 7.0 | 다른 선택·새 턴까지 유지 |
| ack(탭 직후) | 검정 24% → `#4A4F58`, scale 1.0 → 1.08 → 1.0, 링 강도 1.0 | 5.8 / 8.2 | 0–120 상승, 120–200 유지, 200–600 소멸(기존 `citeAckCurve`) |

규칙: **눌릴수록 어두워진다.** 번개와 숫자의 대비는 상태가 진행될수록 오히려 오른다(다크도 같은 규칙. 기존 hover가 accent 12%/24%를 섞던 것을 제거 — 보라가 섞이지 않는다).

### 3.3 마커 링(선택됨·ack)

알약 바깥에 **얇은 스윕 링**만 둔다: 선명 링 stroke 1.8·σ 0.6, 번짐 stroke 4.5(ack 5.5)·σ 1.3(ack 1.8), 클립 반경 5px. 줄 상자가 알약 위아래에 남기는 여백이 약 2.5px라 번짐을 크게 키우면 이웃 줄을 번지게 한다(⚠️ 실기기에서 줄 간격 15/1.55 기준 확인 필요). 정착 상태는 링 강도 0.65로 약하게만.

### 3.4 접근성

`Semantics(button: true, selected: <선택 번호와 같음>, label: citeMarkerLabel)`. **`Semantics`를 `AnimatedBuilder` 안으로 옮겨야 한다**: 지금은 바깥에 있어 `selected()`가 바뀌어도 시맨틱이 갱신되지 않는다.

## 4. 출처 행 (채팅 하단)

### 4.1 색과 구성

| 요소 | 값 |
|---|---|
| 면 | `rowFill` (라이트는 불투명이라 이웃 행의 번짐이 비치지 않는다) |
| 테두리 | `rowBorder` 1px, 선택 시 `rowBorderSelected` |
| 번호 배지 | 원 22, `pill` + `digit` 12/600 (마커와 동일) |
| 제목 | 13/600 `pb.ink`, 1줄 말줄임 |
| 보조줄 | 아이콘 14 + 12/400, `sub` |
| `›` | 16, `sub`. 호버·눌림 시 `accent`(기존) |
| 종류 구분 | 아이콘과 텍스트(PDF·노트), 색 없음 |
| 헤더 | `⚡`(채워진 번개 12, `headerBolt`) + `출처 N` 12/600 `sub`. 장식이라 `ExcludeSemantics`, 의미는 라벨이 전달 |
| 호버 / 눌림 | `rowHover` / `rowPress` 오버레이(InkWell `overlayColor`, 보라 8%/14% 제거) |
| 포커스 | 테두리 2px `accent`(기존) |

번호 배지는 세 안을 비교해 마커와 같은 색으로 정했다: ① 현재 `accentContainer`(보라 연한 면)는 알약이 회색이 되면 번호끼리 색이 달라 짝이 안 읽힌다, ② 회색 배지 + 번개 아이콘은 번개가 N번 반복돼(이전 진단 항목) 거절, ③ 같은 회색 + 숫자만(채택).

### 4.2 이웃 행과 겹침

행 간격은 8px(`Wrap.runSpacing`, 2열일 때 가로도 8). 고리 번짐은 **세로 8px·가로 12px 안**에서만 그린다(§6.3). 선택 행의 번짐이 이웃 행 안쪽까지 들어가거나 이전 행 위에 덧그려지지 않는다. 시안 5·4·6의 행 1·3이 그 상태다. 라이트 행 면을 불투명으로 바꾼 것도 같은 목적이다(다크는 흰색 6%라 비치지만 번짐이 이웃 안쪽에 닿지 않아 문제 없음).

## 5. 선택(클릭) 효과 — 무지개 outer glow, 끝나도 유지

### 5.1 무지개 12색

OKLCH 기준, 색상 간격 약 30°, 노랑 구간만 명도를 올려 올리브로 탁해지는 것을 막았다. 고리로 닫힌다(마지막 → 첫 번째).

| # | 색상(hue) | 이름 | 라이트 (L≈0.79~0.90, C≈0.10~0.13) | 다크 (L +0.02, C −0.015) |
|---|---|---|---|---|
| 1 | 15 | 빨강-산호 | `#FE9FA6` | `#FFA9AF` |
| 2 | 45 | 주황 | `#FEA47C` | `#FEAE8B` |
| 3 | 78 | 호박 | `#FBC369` | `#FCCB7E` |
| 4 | 103 | 노랑 | `#EEE276` | `#F2E88B` |
| 5 | 138 | 연두 | `#A0DA8D` | `#ACDE9B` |
| 6 | 168 | 초록-청록 | `#70DCB6` | `#85E0BE` |
| 7 | 200 | 청록 | `#65D9DF` | `#7EDDE2` |
| 8 | 232 | 하늘 | `#6DCAF8` | `#82CFF7` |
| 9 | 262 | 파랑 | `#9BBEFE` | `#A5C5FE` |
| 10 | 292 | 보라 | `#BCADFE` | `#C2B5FD` |
| 11 | 322 | 자홍 | `#E2A3EC` | `#E4ADED` |
| 12 | 350 | 분홍 | `#F69FC8` | `#F6A9CD` |

- ✅ sRGB 범위 안으로 채도를 줄여 맞춘 값(`oklch → sRGB` 계산).
- 알파는 정지점 색에 곱한다: 선명 링 라이트 0.95 / 다크 0.85, 번짐 0.75 / 0.60, 모두 정착 강도 1.0 기준. 파스텔은 흰 말풍선 위에서 알파 0.3으로는 거의 사라진다(시안 렌더로 확인했고, 위 값에서 자연스럽게 읽힌다).
- **안쪽 채움에는 쓰지 않는다**(이전 "주황 톤 섞임" 피드백). 주황·호박은 바깥 번짐에서만 등장한다.
- 색상 보간은 sRGB(`SweepGradient` 기본). 이웃 정지점이 30° 간격이라 중간색이 탁해지지 않는다.

### 5.2 링 구성(바깥에서 안쪽, 시안 8)

| 층 | 그리는 법 | 값 |
|---|---|---|
| ① 넓은 번짐 | 행 둘레(`RRect`, 반경 14)에 stroke, `MaskFilter.blur(normal, σ)`, 스윕 셰이더 | stroke 9 · σ 3.0 · 알파 0.75 / 0.60 |
| ② 얇은 선명 링 | 같은 방식 | stroke 3.5 · σ 1.3 · 알파 0.95 / 0.85 |
| ③ 행 본체 | 기존 `Material` + `RoundedRectangleBorder` | 불투명 중립 면 + 1px 선택 테두리. 행이 stroke의 안쪽 절반을 덮는다 |
| 클립 | 기존 `_OutsideClip`(evenOdd)의 inflate를 `80` → `Rect.inflate` 대신 `fromLTRB(-12, -8, +12, +8)` | 번짐이 8px 간격을 못 넘는다 |

번짐을 크게 하고 8px에서 자르면 클립 경계가 사각형 윤곽으로 보인다(첫 시도에서 확인). 그래서 σ를 줄이고 알파로 보충해 **8px 지점에서 알파가 5% 안팎**이 되도록 잡았다. 실기기에서 윤곽이 보이면 행 간격을 8 → 10으로 올리는 것이 우선 대응이다.

색 분포: ✅ **스윕을 행 중심에 두는 기본형**이면 288×48 행에서 긴 변은 각각 약 161°(44.7%), 짧은 변은 약 19°가 되어 둘레 길이 비율(42.9% / 7.1%)과 거의 같다. 즉 색이 둘레를 따라 고르게 지나간다. 그래서 `_Ellipse` 같은 정사각형 정규화를 **쓰지 않는다**(쓰면 48px 짧은 변이 90°를 받아 색이 급변한다). 2열(폭 240) 행에서도 비슷하다.

### 5.3 타임라인(전 → 후)

탭 후 ms, 스크롤 없는 경우. 스크롤이 필요하면 리드가 스크롤 뒤에 시작한다(기존 `sourceFlashSkipLead`).

| 박 | 시작 | 길이 | 안쪽 채움 `fill` | 링 강도 `halo` | 기타 | 곡선 |
|---|---|---|---|---|---|---|
| 리드 | 0 | 120 (전 140) | – | – | 마커 ack 0–600ms 병행 | – |
| ① 채움 상승 | 120 | 200 (전 245) | 0 → 1.0 | 0 → 0.55 | | easeOutCubic |
| ② 숨 고르기 | 320 | 340 (전 420) | 1.0 → 0.35 | 0.55 → 0.30 | | easeInOutSine |
| ③ 재상승 | 660 | 220 (전 262) | 0.35 → 0.85 | 0.30 → 0.60 | | easeInOutSine |
| ④ 중심 밝아짐 | 880 | 560 중 앞부분 | 0.85 유지 후 감소 | 0.60 ↑ | 흰색 타원 빛 반경 0.08 → 0.78, 알파 `sin(πu)` | easeOutCubic |
| ⑤ 복귀 + 정착 | 880 | 560 (전 473) | 0.85 → 0 (u 0.25–1) | 0.60 → 1.0 (u 0.15–1) | 스윕 −50° → 0° | easeInOutCubic / `Curves.easeInOut` |
| 정착 | 1440 | ∞ | 0 | 1.0 | 정적 | – |

합계 1440ms(전 1540ms, −6.5%). 전체를 줄이면서 ④⑤ 구간만 늘려 무지개가 "떠오르는" 시간을 확보했다. 링은 ①~③에서 정착값(1.0)보다 약하게(최대 0.6) 맥동하고 ⑤에서 정착값까지 오르므로 끝이 "도착"으로 읽힌다. **같은 출처를 다시 선택(replay)**하면 링은 1.0을 유지한 채 채움 맥동과 중심 빛만 다시 돈다.

채움 색은 이제 `rowFill → rowPulse`(중립 회색 한 단계)이다. 전의 `accentContainer`(연보라)는 쓰지 않는다. 테두리는 같은 `fill` 값으로 `rowBorder → rowBorderSelected`로 이동하고, 정착 후에도 `rowBorderSelected`로 남는다.

### 5.4 해제·전환·접근성·모션 줄이기

| 규칙 | 값 |
|---|---|
| 다른 출처/마커 선택 | 이전 행·마커의 링이 **200ms `easeOut`으로 페이드아웃**(강도 1 → 0), 동시에 새 행 시퀀스가 시작. 기존 "즉시 사라짐"에서 변경 |
| 새 턴 | 즉시 초기화(기존 `didUpdateWidget` 규칙 유지) |
| 선택 해제 수단 | 다른 선택·새 턴만(빈 곳 탭으로는 해제하지 않음) |
| 시맨틱 | 행: `Semantics(button: true, selected: _selected == index, ...)`, 마커도 동일. 선택은 탭 즉시 `selected: true`(애니메이션 시작을 기다리지 않음). 새 l10n 문자열 없음 |
| 모션 줄이기(`disableAnimations`) | 링 강도 1.0·채움 0·스윕 0의 **정착 상태를 즉시** 표시, 중심 빛·ack scale 없음, 페이드아웃도 즉시(기존 `_reduced` 규칙과 동일) |
| 고대비/`forcedColors` | ⚠️ 미확인: 시스템 강제 색 상태에서는 테두리(`rowBorderSelected`)가 상태를 담당하므로 무지개가 없어도 선택이 구분된다 |

### 5.5 정착 후 느린 반짝임(6초 hue 회전): 하지 않는다

| 장점 | 단점 |
|---|---|
| 정착 상태가 "살아 있어" 보인다 | 선택 행이 있는 동안 **영구 티커**(애니메이션 컨트롤러)가 돌며 번짐 층을 매 프레임 다시 그린다. 정적일 때만 가능한 `RepaintBoundary` 캐시가 깨진다(모바일 배터리, 웹 유휴 CPU) |
| | 본문을 읽는 곁에서 움직이는 색은 산만하다. 본문·출처가 한 화면에 있다 |
| | WCAG 2.2.2(Pause, Stop, Hide): 5초 넘게 자동으로 움직이는 정보는 일시 정지 수단이 필요하다 |
| | 선택 상태를 알리는 일에는 아무 기여가 없다 |

**추천: 정지.** 대신 정착 시 −50° → 0° 스윕이 한 번만 "떠오르는" 감각을 준다. 그래도 원하면 `halo` 알파만 0.85 ↔ 1.0으로 8초 주기로 움직이게 하고(색 회전 아님), 화면이 포커스를 잃거나 행이 안 보이면 멈추는 옵션을 후속으로 둔다.

## 6. 구현 방식(Flutter 3.47로 가능한 것만)

### 6.1 왜 `BoxShadow`가 아닌가

`BoxShadow`는 한 층에 한 색이다. 다색 고리는 네 개로 흉내 내도(현 구현) 그림자 오프셋 방향별로만 색이 갈려 고리처럼 닫히지 않는다. **`CustomPaint` + `SweepGradient` 셰이더 + `MaskFilter.blur`**가 정석이다. `ShaderMask`는 자식 영역 안만 칠하므로 번짐(바깥) 용도로는 쓰지 않는다.

### 6.2 painter 골격(⚠️ 이 환경에서 컴파일하지 않음)

```dart
class RainbowRingPainter extends CustomPainter {
  const RainbowRingPainter({
    required this.colors, // 12색 + 첫 색 한 번 더
    required this.strength, // 0..1 (SourceFx.halo)
    required this.sweep, // 라디안, GradientRotation
    required this.tightAlpha,
    required this.wideAlpha,
    this.radius = 14,
  });
  final List<Color> colors;
  final double strength, sweep, tightAlpha, wideAlpha, radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    void layer(double width, double sigma, double alpha) {
      final a = alpha * strength;
      final shader = SweepGradient(
        colors: [for (final c in colors) c.withValues(alpha: a)],
        transform: GradientRotation(sweep),
      ).createShader(rect);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
    layer(9, 3.0, wideAlpha);
    layer(3.5, 1.3, tightAlpha);
  }

  @override
  bool shouldRepaint(RainbowRingPainter o) =>
      o.strength != strength || o.sweep != sweep || o.colors != colors;
}
```

### 6.3 레이어와 `source-chip-n` 계약

기존 `SourceRow`의 `Stack`(halo 층 → `Material` 행) 구조를 그대로 쓴다. halo 층의 키드 `DecoratedBox(ValueKey('source-chip-n'))`는 `ShapeDecoration.shadows`에 **중립 그림자 1겹**(라이트 검정 6%, 다크 검정 28%, blur 12, offset (0, 4))을 `halo > 0`일 때만 두고(= 선택 신호, 평상시 `null`), 그 `child`로 `RepaintBoundary > CustomPaint(key: ValueKey('source-ring-n'), painter: RainbowRingPainter)`를 둔다. 바깥 `ClipPath(_OutsideClip)`가 안쪽을 비워 두므로 행의 안쪽 색은 그대로다. 그림자가 "선택된 행이 살짝 떠 있다"는 약한 깊이감도 준다.

| 장치 | 이유 |
|---|---|
| `RepaintBoundary` | 정착 후엔 컨트롤러가 멈춰 재래스터가 일어나지 않는다. 애니메이션 중에도 행 하나만 다시 그린다 |
| `AnimatedBuilder(animation: _flash)` | 정착 후 `_flash.isCompleted` → 리빌드 없음 |
| `Clip.none` 유지 | 번짐이 `Stack` 밖으로 나가야 한다(기존 주석) |
| 페이드아웃 | `_release` 컨트롤러(200ms)가 `halo`를 1 → 0으로 곱한다 |

성능(⚠️ 미측정): 번짐은 약 300×60 크기의 가우시안 두 겹이라 애니메이션 중 프레임당 비용이 작다고 예상한다. 정착 후엔 0. 웹 CanvasKit·모바일 Impeller 모두 `MaskFilter.blur`를 지원한다. 선택은 한 번에 한 행(+같은 번호 마커 몇 개)이라 동시 번짐은 적다.

## 7. 반응형

| 폭 | 적용 |
|---|---|
| 모바일 < 600 | 1열. 행 폭 270~297, 가로 번짐 12px는 목록 패딩 16 안. 호버는 없고 눌림·선택만. 터치 행 ≥ 44 유지 |
| 태블릿 600–1024 | 말풍선 폭 ≥ 520이면 2열(행 폭 ≥ 240). 열 사이 가로 8 → 번짐 클립 가로도 8로 낮춘다(`2열일 때 inflate.horizontal = 8`) |
| 데스크톱 > 1024 | 380 패널(1열). 호버·포커스 링·툴팁 가능. 폭이 넓은 중앙 컬럼에서도 말풍선 `maxWidth` 정책은 그대로(별도 과제) |

마커는 모든 폭에서 18px 알약이다. 크기를 키우지 않는다(줄 높이 유지).

## 8. 구현자 체크리스트

### 8.1 파일·함수

| 위치 | 변경 |
|---|---|
| `ask_sources.dart` 상단 상수 | `_lead 140→120`, `_rise 245→200`, `_dip 420→340`, `_rise2 262→220`, `_bloomMs 473→560`(④⑤ 공유, 이름은 `_settle` 권장), `sourceFlashDuration 1540→1440`, `sourceFlashLead 120` |
| `SourceFx` | `rainbow`(0..1) → **`sweep`(라디안)**. `halo`는 링 강도로 의미 유지. `settled = SourceFx(halo: 1)` |
| `sourceFx(v, {replay})` | §5.3 표대로 `fill`/`halo`/`sweep`/`bloom` 재작성. ③ 이후 `halo`는 0.60까지 올라야 한다. replay는 `halo` 1.0 고정 |
| `citeMarkerFill/Bolt/Picked` | 삭제, `SourceTones`로 교체. `subInkFor` 우회(다크 ink 75%)도 `sub`로 대체 |
| `CiteMarker` | 채운 번개 painter(`_BoltPainter`), 상태 오버레이 검정 계열, 링 `CustomPaint`, `Semantics(selected:)`를 `AnimatedBuilder` 안으로 |
| `SourceRow` | `fill` 색을 `rowFill → rowPulse`, 테두리 lerp, 오버레이 중립, `Semantics(selected:)`, `_halo()`를 중립 그림자 1겹으로 교체 + `RainbowRingPainter`, `_OutsideClip` inflate를 `(12, 8)`로 |
| `_Badge` | `pill` + `digit` |
| `SourcesList` 헤더 | `Icon(AppIcons.citation, accent)` → 채운 번개 12 `headerBolt` |
| `ask_screen.dart` `_AskTurnViewState` | `_release` 컨트롤러(200ms, `TickerProviderStateMixin` 이미 있음), `_releasing` 번호, `_cite()`에서 선택이 바뀌면 이전 번호를 `_releasing`으로 옮기고 `forward(from: 0)`, `_fx()`가 `_releasing`이면 `SourceFx(halo: 1 - _release.value)`, `_sourceRow`의 `animation`을 `Listenable.merge([_flash, _release])`, `_markerTick`에도 `_release` 추가 |
| `theme.dart` | **변경 없음** |
| `l10n.dart` | 변경 없음 |

### 8.2 테스트 계약 변경 (`test/ask_citation_flash_test.dart`)

유지: `source-chip-n` 키와 `DecoratedBox`·`ShapeDecoration.shadows` 규약(평상시 `null`, 선택 시 비어 있지 않음 → `_glow` 헬퍼 그대로), `cite-marker-n` 탭 헬퍼, `renderMarkers` 그룹.

깨지는 것(바꿔야 한다):

| 현재 테스트 | 변경 |
|---|---|
| `resting halo: four cool hues (violet..sky), faint` (4겹, 색상 195–275) | 삭제. 대신 `source-ring-n`의 painter가 12색+1(닫힘), 첫·마지막 색 동일, 라이트·다크 팔레트 일치, `strength == 1`, 그림자는 1겹 중립색(채도 0)임을 검사 |
| `the beats follow the timeline` (140+245+420+262, `sourceFlashDuration == 1540`) | 새 박 길이(120/200/340/220/560)와 1440 단언으로 교체. `end.rainbow == 1` → `end.sweep == 0`, `end.halo == 1` 유지 |
| `glow: one purple glow at the first peak, offset (0, 2)` | 삭제. 대신 ①끝(탭 후 320ms)에서 `fill ≈ 1`, painter `strength ≈ 0.55` |
| `the centre-out light is drawn only during the bloom` (140+245+420+262+100 시점) | 시점을 120+200+340+220+100으로 갱신 |
| `picking another source moves the halo` (이전 링이 즉시 사라짐) | 이전 행은 200ms 동안 `strength`가 1 → 0으로 줄고 이후 `isNull`. 새 행은 즉시 시작 |
| `_paper()`(= `pb.chipBg`) / `_inner == _paper` | `SourceTones.rowFill`(라이트 불투명, 다크 흰 6%)과 비교하도록 헬퍼 교체 |
| `the picked number's marker rests a little deeper` | "눌린 번호 알약이 평상시보다 어둡고 accent가 아님"은 유지, 값은 검정 14% 겹침 |
| `the pressed marker answers with a short ack` | accent 비교를 제거하고 scale 1.08·링 강도 1.0 확인 |

신규 테스트(권장): 행 `Semantics.selected`가 탭 직후 true, 마커도 true; 다른 출처 선택 후 이전 행 `selected: false`; 모션 줄이기에서 즉시 `strength == 1`; 번짐이 행 높이 + 8 안에 있음(`CustomPaint` 경계); 라이트·다크 대비 계산(`contrastRatio`)으로 숫자 ≥ 4.5, 번개 ≥ 3, 보조줄 ≥ 4.5, 선택 테두리 ≥ 3 단언.

## 9. 위험

| 위험 | 대응 |
|---|---|
| 라이트의 슬레이트 알약이 본문 속에서 무겁다(이전 "화면에서 가장 무겁다" 진단과 부딪힐 수 있다) | 시안 7에서 A와 나란히 비교 가능. 알약 18px·숫자 12라 면적은 작고, 이전 문제는 100% 채도의 보라 외곽선이었다. 본문이 `ink` 15 : 1이라 알약이 본문보다 시끄럽지는 않다. 반응이 나쁘면 **대안 A** 토큰만 바꾸면 된다(§10) |
| 번짐 클립 윤곽이 사각형으로 보임 | σ·알파 조정 완료(시안에서는 안 보임). 실기기 확인, 안 되면 행 간격 8 → 10 |
| 테스트 대규모 수정(§8.2) | 구현 전에 계약 변경을 이 문서로 합의 |
| 라이트 파스텔의 윤곽이 약함 | 상태 신호는 테두리가 맡는다. 무지개만으로는 라이트에서 1.3~1.9 : 1이라 상태 신호가 못 된다(시안 9) |
| 같은 번호 마커가 여러 개면 각각 링 | 가볍지만 본문이 화려해질 수 있다. 링을 마커에서 끄고 알약 어둡게만 두는 선택지 |
| 다크 `inkMuted` 전역과 `sub` 이중 관리 | ui-polish가 `inkMuted`를 올리더라도 출처 영역은 `sub` 유지. 합치려면 `inkMuted` 다크를 `#D2D4DA`급까지 올려야 하는데 앱 전체 영향이라 별도 검토 |

## 10. 추천 vs 대안

| | 추천 B: 슬레이트 | 대안 A: 조용한 라이트 |
|---|---|---|
| 라이트 알약 | `#626874`, 숫자 `#FFFFFF` 5.6 : 1 | `#E6E7EB`, 숫자 `#1F1B16` 13.9 : 1 |
| 라이트 번개 | `#FFD54A` **4.0 : 1** | `#E3A500` **1.8 : 1 (3 : 1 미달)** |
| 말풍선과의 경계 | 5.4 : 1 | 1.2 : 1 |
| 무게 | 눈에 띈다 | 조용하다(이전 `d509b49` 계열) |
| 다크 | `#626874`(1.6 : 1) | `#4A4850`(현재, 1.0 : 1로 말풍선과 구분 안 됨) → 다크는 B 유지 권장 |

A를 택하면 `pill/digit/bolt` 세 토큰과 `markerOverlay`(라이트 `ink` 6%/12%/10%/18%)만 바꾸면 되고 나머지(행·링·타임라인)는 그대로다. **"3 : 1 이상을 가능한 한 지킨다"는 요구와 다크와의 통일 때문에 B를 추천한다.** A는 번개 3 : 1이 물리적으로 불가능하다(§1).

### 10.1 개정: 라이트 알약을 옅게 (클라이언트 피드백 2회)

"질문 채팅의 노란 번개 옆 회색 배경이 너무 진하다"는 피드백이 반복돼 라이트 알약을 `#6E7480`(L 0.17)에서 `#C4C9D1`(L 0.58)로 바꿨다. 번호 배지(같은 `pill`)도 함께 옅어진다. 다크는 그대로다.

| 항목 (라이트) | 값 |
|---|---|
| 알약 대 말풍선 | 1.6 : 1 (테스트 하한 1.5) |
| 알약 대 `rowFill` `#F2F3F5` / `rowPulse` `#E1E3E8` | 1.5 : 1 / 1.3 : 1 (행보다 한 단계 진한 상태 유지) |
| 숫자 `#1F232B`: 평상시 / hover 8% / press 16% / picked 14% / ack 24% | 9.5 / 8.0 / 6.7 / 7.0 / 5.5 : 1 |
| 번개 윤곽 `#1F232B` (같은 상태) | 위와 같은 수치 (≥ 3 : 1) |
| 번개 채움 `#FFCB2E` 단독 | 1.1 : 1 (평상시) ~ 1.9 : 1 (ack) — 모양은 윤곽이 맡는다 |

§1의 결론(밝은 회색 위 노랑 단독은 3 : 1이 불가능)은 그대로이고, 이번에는 번개 색을 포기하는 대신 **윤곽**으로 3 : 1을 확보했다(번개를 갈색 계열로 어둡게 하면 "노란 번개"가 사라진다). 알약에는 주황·노랑을 섞지 않았다. 겹침(`markerOverlay`)은 검정이라 알약이 하얗게 날아가지 않고, 무지개 링은 `clipInset`으로 알약 바깥에만 그려진다. 행의 bloom은 행 안쪽에만 적용되며 알약과 무관하다. ⚠️ 실기기 시각 확인 전: 정적 렌더(5배)로만 번개 윤곽이 11px에서 읽히는지 봤다.

### 10.2 개정 2: 라이트 알약을 계층 아이콘 타일과 같은 톤으로 (클라이언트 피드백 3회)

"아직도 진하다. 왼쪽의 계층 아이콘 배경 정도면 적당"이라는 피드백으로 라이트 `pill`을 `#C4C9D1`에서 **`Pb.light.tile`(`0x141F1B16`, 잉크 8%)**로 바꿨다. `SourceTones`는 `const`라 `Pb`를 직접 참조하지 못해 같은 상수를 두고, 테스트가 `SourceTones.light.pill == Pb.light.tile`을 단정한다(한쪽만 바뀌면 깨진다). 알파를 그대로 둔 이유: 타일이 놓이는 면(말풍선, 출처 행)과 상관없이 "그 면보다 8%만 어둡다"는 같은 관계가 유지되고, 불투명으로 합성하면 `rowFill` 위 번호 배지가 사라진다. 무지개 링은 알약 안쪽을 클립으로 뺀 채 바깥에만 그리고, 겹침(`markerOverlay`)은 일반 source-over라 투명이어도 결과가 같다.

| 항목 (라이트) | 값 |
|---|---|
| 알약 `#EDEBEB`(말풍선 `#FEFDFD` 위) 대 말풍선 | 1.17 : 1 (타일과 같은 조용한 단차. 이전 1.64 : 1) |
| 번호 배지 대 `rowFill` `#F2F3F5`(`#E1E2E4`) / `rowPulse` `#E1E3E8`(`#D2D3D8`) | 1.17 : 1 / 1.16 : 1 (행보다 한 단계 어두움 유지, 뒤집히지 않음) |
| 숫자 `#1F1B16`: 평상시 / hover 8% / press 16% / picked 14% / ack 24% | 14.4 / 12.1 / 10.0 / 10.5 / 8.2 : 1 |
| 번개 윤곽 `#1F1B16` (같은 상태) | 위와 같은 수치 (≥ 3 : 1) |
| 번개 채움 `#FFCB2E` 단독 | 1.3 : 1 (평상시) ~ 1.4 : 1 (ack) — 모양은 윤곽이 맡는다 |

윤곽은 유지했다: 이만큼 옅은 면에서는 노랑 단독이 1.3 : 1이라 윤곽을 빼면 번개가 사라진다. 숫자·윤곽은 타일의 바탕인 `ink`(`#1F1B16`)로 맞췄다(이전 청회색 `#1F232B`는 따뜻한 타일 톤과 어긋났다). 다크는 그대로(`#626874`)이며, 다크 `Pb.tile`(흰색 12%)보다 뚜렷하지만 흰 숫자·노란 번개의 대비를 위해 두었다. ⚠️ 실기기 시각 확인 전: 수치는 계산·위젯 테스트이며, 윤곽 번개가 11px에서 읽히는지는 눈으로 보지 못했다.

## 11. 확인하지 못한 것 (⚠️)

- 말풍선의 실제 합성색(라이트 `#FEFDFD`/`#FCF9FC`, 다크 `#4E4750`/`#3E3744`)과 어느 쪽이 맞는지.
- Flutter에서의 실제 번짐 강도·클립 윤곽·프레임 비용(painter 골격은 컴파일하지 않았다). 시안은 SVG 근사.
- 채운 번개(11px) 폴리곤의 작은 크기 선명도, 둥근 이음 선의 모양.
- 줄 간격에서 마커 링이 이웃 줄에 번지는지(§3.3), 표·목록 안 마커의 WidgetSpan 중첩 렌더링(이전 문서 ⚠️ 유지).
- 본문 글자 크기(14/15/16) 확정(이전 문서 ⚠️ 유지).
- 색각 이상 시뮬레이션: 무지개 12색의 구분은 검토하지 않았다(상태는 테두리가 담당하므로 정보 손실은 없다).
- `forcedColors`/고대비 모드 동작.
