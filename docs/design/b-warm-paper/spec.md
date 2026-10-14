# 방향 B — Warm Minimal Paper

레퍼런스: Mobbin 의 Bear, Craft, Apple Notes, Google Keep. 시안은 `google/gemini-3-pro-image` 로 생성했다.

| 파일 | 내용 |
|---|---|
| `desktop.png` | 데스크톱 1440px, 16:9. 좌 사이드바, 중앙 마소너리 보드, 우 상시 Ask 패널 |
| `mobile-board.png` | 모바일 노트 보드. 2열 파스텔 카드, 하단 내비, New note FAB + PDF FAB |
| `mobile-ask.png` | 모바일 Ask 화면. 모델 선택, 스코프 칩, 답변 + ⚡ 인용 칩, 입력창 |

시안은 이미지 모델 출력이므로 카드 배치와 세부 문구는 참고용이다. 아래 토큰과 규칙이 구현 기준이다.

## 1. 컨셉

종이 위에 포스트잇을 붙여 놓은 듯한 차분한 편집 디자인이다.

- 따뜻한 크림색 종이 배경 위에 파스텔 메모 카드를 둔다. 화면은 조용하게 유지한다.
- 제목은 세리프(에디토리얼 톤), 본문과 UI는 산세리프로 가독성을 확보한다.
- 포인트 색은 따뜻한 바이올렛 하나뿐이다. ⚡ 인용 마커, 인용 칩, 주요 버튼에만 쓴다. 색이 흩어지지 않아서 "출처로 점프" 가 시각적 중심이 된다.
- 그림자는 약하게, 경계는 헤어라인으로 처리한다.
- 브랜드: 바이올렛 ⚡ 아이콘 + 세리프 `PageBlink`. 태그라인은 "Ask your notes & documents. Blink to the source."

## 2. 팔레트 (토큰)

### Light

| 토큰 | Hex | 용도 |
|---|---|---|
| `paper` (background) | `#FBF8F2` | 앱 배경 |
| `paperRaised` (surface) | `#FFFDF8` | 사이드바, 패널, 입력창 |
| `paperSunken` (surfaceContainer) | `#F3EEE4` | Ask 패널 배경, 사용자 말풍선 |
| `ink` (onSurface) | `#1F1B16` | 본문, 제목 |
| `inkMuted` (onSurfaceVariant) | `#6B6358` | 보조 텍스트, 미리보기 메타 |
| `hairline` (outlineVariant) | `#E4DDD0` | 구분선, 카드 테두리 |
| `outline` | `#B9B0A0` | 입력창 테두리 |
| `accent` (primary) | `#6B4EE6` | ⚡ 마커, 기본 버튼, 선택된 칩 |
| `onAccent` (onPrimary) | `#FFFFFF` | 기본 버튼 위 글자 |
| `accentContainer` (primaryContainer) | `#E9E3FC` | 선택된 칩, 인용 칩 배경 |
| `onAccentContainer` | `#2E1F85` | 인용 칩 글자 |
| `danger` (error) | `#B3261E` | 색인 실패 글자/아이콘 |
| `dangerContainer` | `#F8DAD6` | 색인 실패 배지 배경 |
| `noteButter` | `#FFF1B8` | 노트 카드 색 1 |
| `noteMint` | `#D9F0E1` | 노트 카드 색 2 |
| `notePeach` | `#FFDCCB` | 노트 카드 색 3 |
| `noteSky` | `#D6E8F8` | 노트 카드 색 4 (PDF 기본색으로 권장) |

### Dark (따뜻한 먹지 톤, 순수 검정 금지)

| 토큰 | Hex |
|---|---|
| `paper` | `#1B1814` |
| `paperRaised` | `#242019` |
| `paperSunken` | `#14110E` |
| `ink` | `#F2EDE3` |
| `inkMuted` | `#A59D8F` |
| `hairline` | `#383228` |
| `outline` | `#5A5244` |
| `accent` | `#B7A6FF` |
| `onAccent` | `#251A63` |
| `accentContainer` | `#3A2F7A` |
| `onAccentContainer` | `#E9E3FC` |
| `danger` | `#F2B8B5` |
| `dangerContainer` | `#5C2B27` |
| `noteButter` | `#4A3F16` |
| `noteMint` | `#1F3D2C` |
| `notePeach` | `#4D2E21` |
| `noteSky` | `#1F3548` |

다크 모드의 노트 카드 글자는 `ink`(`#F2EDE3`)를 쓴다. 카드 색상 값은 저장하지 말고 인덱스(0~3)로 저장해서 테마에 따라 매핑한다.

## 3. 타이포그래피

Flutter 의 `google_fonts` 패키지로 사용 가능하다.

| 역할 | 폰트 | 크기 / 굵기 / 행간 |
|---|---|---|
| 브랜드, 화면 제목 (display / headline) | Fraunces (대안: Newsreader) | 28 / 600 / 1.2 |
| 카드 제목 (titleMedium) | Fraunces | 18 / 600 / 1.25 |
| 본문, 답변 (bodyLarge / bodyMedium) | Inter | 16 / 400 / 1.5, 14 / 400 / 1.45 |
| 라벨, 칩, 배지 (labelLarge / labelMedium) | Inter | 13 / 500 / 1.2, 12 / 500 |
| 한글 폴백 | Noto Serif KR (제목), Noto Sans KR (본문) | `fontFamilyFallback` 로 지정 |

- Fraunces 의 `SOFT`/`WONK` 축은 Flutter 에서 쓰지 않는다. 기본 정적 웨이트만 사용한다.
- 한글 제목(`회의록 10/14`)이 세리프로 일관되게 나오도록 `fontFamilyFallback: ['Noto Serif KR']` 를 제목 스타일에 넣는다.

## 4. Radius / 간격 / 고도

- Radius: 카드 16, 칩/배지 999(pill), 입력창 24, 말풍선 18(꼬리 쪽 모서리 6), 패널/시트 상단 24, 버튼 14.
- 간격 단위는 4. 기본값은 8/12/16/24. 화면 좌우 패딩은 모바일 16, 데스크톱 24. 카드 간격은 12.
- 카드 내부 패딩은 16. 제목과 미리보기 사이 8, 체크리스트 행 높이 28.
- 고도: 카드는 elevation 0 + 1px `hairline` 테두리 + 매우 약한 그림자(`blur 8, y 2, ink 6%`). 호버(웹)에서만 `y 6, blur 16, 10%`. FAB 는 elevation 3. Material 3 의 tonal surface tint 는 끈다(`surfaceTintColor: Colors.transparent`).
- 종이 질감: 에셋 PNG(노이즈 타일, 불투명도 3~4%)를 `paper` 배경 위에 `DecorationImage(repeat: ImageRepeat.repeat)` 로 깔 수 있다. 선택 사항이며, 없어도 디자인은 성립한다.

## 5. 핵심 컴포넌트

### 5.1 노트 카드 (마크다운 노트)
- 배경 `note*` 색 4종 중 하나, 테두리 1px 색은 `ink` 8% 불투명도.
- 구성: 세리프 제목 1~2줄, 미리보기 최대 4줄(본문 14), 체크리스트 미리보기 최대 4항목(체크박스 + 텍스트, 완료 항목은 취소선 + `inkMuted`), 하단 행에 티어 배지.
- 티어 배지: pill, 배경 `ink` 6%, 글자 12. `☁ My cloud`(내 클라우드), `👥 Hackathon`(프로젝트명). Cloak 노트는 `🛡 Device only`. 이모지가 아니라 Material 아이콘(`cloud_outlined`, `group_outlined`, `shield_outlined`)을 쓴다.
- 구현: `Card` 대신 `Material` + `InkWell` + `Ink`/`DecoratedBox`. 마소너리는 `flutter_staggered_grid_view` 의 `MasonryGridView`.

### 5.2 PDF 카드
- 기본 배경 `noteSky`. 제목은 세리프, 파일명 전체 표시(2줄 말줄임).
- `PDF · 12 pages` 메타 pill(배경 `ink` 8%). 첫 페이지 썸네일은 흰 종이 미니 페이지(radius 6, 얇은 그림자)로 오른쪽 위나 카드 하단에 둔다.
- 모바일은 썸네일을 오른쪽에, 데스크톱은 카드 폭이 넓으면 하단에 크게 둔다.
- 서버에 저장된 원본 PDF 로 썸네일을 만들 수 없으면 `picture_as_pdf_outlined` 아이콘으로 대체한다.

### 5.3 색인 실패 상태 (Re-index)
- 배경 `dangerContainer`(카드 색 대신 단색), 제목 아래에 `error_outline` 아이콘 + `Indexing failed` 배지(글자 `danger`).
- `Re-index` 버튼: `OutlinedButton`, 글자 `accent`, 높이 32. 탭하면 재시도 후 진행 중 스피너, 성공하면 일반 PDF 카드로 전환한다.
- 키워드 검색 폴백 중이면 배지 옆에 작은 `Keyword search only` 텍스트를 추가로 표시할 수 있다.

### 5.4 인용 칩 (⚡ citation chip)
- pill, 높이 32, 배경 `accentContainer`, 글자 `onAccentContainer`, 1px `accent` 30% 테두리.
- 내용: `⚡{n} · {제목}` 또는 `⚡{n} · {파일명} p.{쪽}`. ⚡ 는 `Icons.bolt`(크기 14, `accent`) 로 그린다.
- 탭하면 해당 노트를 열거나 PDF 를 해당 쪽으로 이동하고(“blink to the source”), 해당 구절을 `accent` 18% 로 하이라이트한다.
- 구현: `ActionChip` 또는 `InputChip`, `ChipThemeData` 로 스타일 통일.

### 5.5 답변 말풍선 / 질문 말풍선
- 질문: 오른쪽 정렬, 배경 `noteButter`(모바일 시안) 또는 `paperSunken`(데스크톱 시안). 최대 폭 80%.
- 답변: 왼쪽 정렬, 배경 `paperRaised` + 1px `hairline`, 폭 최대 92%. 마크다운 렌더링(`flutter_markdown`: 굵게, 목록, 코드).
- 본문 안의 `⚡1` 마커는 `WidgetSpan` 으로 렌더링한다: 작은 `bolt` 아이콘 + 윗첨자 숫자, 색 `accent`. 탭하면 해당 인용 칩과 동일하게 동작한다.
- 스트리밍 중에는 끝에 깜빡이는 `accent` 커서(500ms)를 붙이고, 답변 하단 `Sources` 라벨 아래에 칩이 도착하는 순서대로 추가한다.

### 5.6 모델 선택 / 스코프 칩
- 모델 선택: pill 버튼 `Gemma 4 26B · free` + `arrow_drop_down`. `MenuAnchor` 또는 `PopupMenuButton`. 항목은 모델명 + `free` 뱃지 + 설명 한 줄.
- 스코프 칩: `FilterChip`. 선택 시 `accentContainer` 배경 + `accent` 테두리 + 체크 아이콘, 미선택 시 `paperRaised` + `hairline` 테두리. `My notes`, `Project: Hackathon`, `+ scope`(프로젝트 추가 선택 시트).

### 5.7 내비게이션
- 모바일: `NavigationBar` 3개 목적지 — Ask(`bolt`), Notes(`sticky_note_2_outlined`), Projects(`folder_outlined`). 선택 인디케이터는 `accentContainer`. 배경 `paperRaised`, 상단 1px `hairline`.
- 데스크톱: `NavigationRail` 확장형 또는 직접 만든 사이드바(폭 240): 로고, Notes / PDFs / Projects / Archive / Settings, 하단 Tiers 섹션(Cloak · device only / My cloud / Shared Vision · {프로젝트}).
- FAB(모바일 보드): `FloatingActionButton.extended` `+ New note`(`accent` 배경, 흰 글자) + 그 위에 `FloatingActionButton.small` PDF 업로드(`upload_file`). 하단 내비 위 16 간격.

### 5.8 입력창
- pill(radius 24), 배경 `paperRaised`, 1px `outline`, 힌트 `Ask your notes...`, 오른쪽 `IconButton.filled`(`accent`) 전송.

## 6. 반응형 레이아웃

| 구간 | 레이아웃 |
|---|---|
| 모바일 < 600 | 하단 `NavigationBar`. Notes 탭은 2열 마소너리(간격 12), Ask 는 전체 화면 탭. 상단에 검색창, 우하단에 FAB 2개. |
| 태블릿 600–1024 | `NavigationRail`(접힘, 아이콘 + 라벨) + 3열 마소너리. Ask 는 우측 슬라이드 패널(폭 360, 토글) 또는 전체 화면. |
| 데스크톱 > 1024 | 3열: 사이드바 240 / 보드(3~4열 마소너리, 최대 폭 1100) / Ask 패널 고정 폭 360~400. 시안(`desktop.png`)과 동일. Ask 패널은 `paperSunken` 배경 + 좌측 1px `hairline`. |

- 구현은 `LayoutBuilder` 로 폭에 따라 분기한다. 마소너리 열 수는 `crossAxisCount = (width / 220).floor().clamp(2, 4)`.
- 데스크톱에서 인용 칩을 누르면 보드 영역 위에 노트/PDF 미리보기 패널(오버레이)이 열린다. 모바일은 전체 화면 라우트로 이동한다.

## 7. Flutter 구현 노트 (Material 3)

```dart
final scheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6B4EE6), onPrimary: Colors.white,
  primaryContainer: Color(0xFFE9E3FC), onPrimaryContainer: Color(0xFF2E1F85),
  secondary: Color(0xFF6B6358), onSecondary: Colors.white,
  error: Color(0xFFB3261E), onError: Colors.white,
  errorContainer: Color(0xFFF8DAD6), onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFFBF8F2), onSurface: Color(0xFF1F1B16),
  surfaceContainerLowest: Color(0xFFFFFDF8),
  surfaceContainerHighest: Color(0xFFF3EEE4),
  onSurfaceVariant: Color(0xFF6B6358),
  outline: Color(0xFFB9B0A0), outlineVariant: Color(0xFFE4DDD0),
);
```

- `ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: scheme.surface)`. 다크는 2장 Dark 표로 같은 구조의 `ColorScheme` 을 만든다.
- 노트 카드 4색은 `ThemeExtension<NoteColors>` 로 정의하고 라이트/다크 값을 각각 넣는다. `Theme.of(context).extension<NoteColors>()`.
- `textTheme`: `GoogleFonts.interTextTheme()` 에서 `displaySmall`, `headlineSmall`, `titleLarge`, `titleMedium` 만 `GoogleFonts.fraunces` 로 덮어쓴다.
- 컴포넌트 테마: `CardTheme(elevation: 0, shape: RoundedRectangleBorder(borderRadius: 16, side: hairline))`, `ChipThemeData(shape: StadiumBorder(), ...)`, `NavigationBarThemeData(indicatorColor: primaryContainer)`, `InputDecorationTheme`(pill 테두리).
- 사용할 패키지: `google_fonts`, `flutter_staggered_grid_view`, `flutter_markdown`. 그 외 커스텀 페인팅은 필요 없다(종이 질감은 선택 사항인 타일 이미지뿐).
- 접근성: `ink` / `paper` 대비 약 15:1, `accent`(`#6B4EE6`) / `paper` 약 5.3:1 로 본문 글자 크기에서도 AA 를 만족한다. 파스텔 카드 위 `ink` 글자는 모두 AA 이상이다. 색만으로 상태를 구분하지 않는다(색인 실패는 아이콘 + 문구 포함).
