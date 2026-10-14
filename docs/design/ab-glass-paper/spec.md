# 방향 AB — Glass Paper

A(Soft Glass + Bento)의 레이아웃과 유리 셸에 B(Warm Minimal Paper)의 따뜻함(웜 배경, Keep 파스텔 카드, 세리프 제목)을 합친 하이브리드. 목업은 `google/gemini-3-pro-image`로 생성했다.

| 파일 | 내용 |
|---|---|
| `desktop.png` | 데스크톱 1440, 16:9. 유리 사이드바 · bento/masonry 보드 · 상시 Ask 패널 |
| `mobile-board.png` | 모바일 9:16. 2열 카드, 하단 내비(Ask · Notes · Projects), New note FAB + 작은 PDF FAB |
| `mobile-ask.png` | 모바일 9:16. 모델 선택, 스코프 칩, 질문/답변(⚡1 ⚡2), 인용 칩 |

시안은 이미지 모델 출력이므로 카드 안 문구(미리보기 줄바꿈 등)와 픽셀 단위 값은 참고용이다. **아래 토큰과 규칙이 구현 기준**이다. 시안에서 한글 제목 "회의록 — 10월 기획 회의"가 데스크톱 폭에서 2줄로 접힌 것은 의도가 아니다(카드 폭 허용 시 1줄, 아니면 2줄 허용).

## 1. 컨셉

- 배경은 따뜻한 그라데이션(연한 라벤더 → 피치/크림) + 아주 약한 종이 질감. 차가운 하늘색 금지.
- **셸**(사이드바, Ask 패널, 하단 내비, 검색창, FAB 보조 버튼)은 A처럼 반투명 frosted glass.
- **콘텐츠**(노트 카드)는 B의 Keep 파스텔 단색 + 1px 따뜻한 헤어라인. 유리를 쓰지 않는다(성능 + 가독성). PDF 카드는 흰 종이 + 실제 첫 페이지 썸네일.
- 제목/브랜드/화면 헤더는 세리프(Fraunces), UI/본문은 산세리프(Inter).
- 포인트 색은 전기 바이올렛 `#6C4CF5` 하나. **사용처 한정**: ⚡ 인용(인라인 마커, 인용 칩), 기본 버튼(New note, 전송, 사용자 말풍선), 활성 내비. 그 외 면/아이콘에 쓰지 않는다. 경고는 따뜻한 앰버(Indexing failed / Re-index)만.
- 브랜드: "⚡ PageBlink" (바이올렛 번개 + 세리프 워드마크). 태그라인: "Ask your notes & documents. Blink to the source."
- 티어 배지: Cloak(기기 전용), My cloud, Shared Vision · Hackathon. **가격/플랜 배지(Pro/Basic/Team) 없음**, 마이크 아이콘 없음.

## 2. 팔레트 (토큰)

### 2.1 Light

| 토큰 | 값 | 용도 |
|---|---|---|
| `bgGradientStart` (lavender) | `#EDE6FA` | 배경 좌상단 |
| `bgGradientEnd` (peach cream) | `#FFE9DC` | 배경 우하단 (중간 `#F7E8EE` 경유 가능) |
| `blobLilac` / `blobPeach` | `#CDBBFA` @ 45% / `#FFC9A8` @ 45% | 장식 블러 원 (고정, 선택) |
| `grain` | 노이즈 타일 PNG, 불투명도 3~4% | 종이 질감 (선택) |
| `glassFill` | `#FFFFFF` @ 62% | 사이드바/패널/내비/검색창 |
| `glassFillStrong` | `#FFFFFF` @ 74% | 답변 카드, 입력창 |
| `glassBorder` | `#FFFFFF` @ 80% | 유리 1px 테두리 |
| `glassShadow` | `#6C4CF5` @ 10%, blur 24, y 8 | 유리 그림자 |
| `ink` | `#1F1B16` | 제목/본문 (파스텔·유리 위 모두) |
| `inkMuted` | `#6B6358` | 메타, 힌트 (흰 위 5.9:1, 버터 위 5.2:1) |
| `hairline` | `#E4DDD0` | 카드 테두리, 구분선 |
| `accent` (primary) | `#6C4CF5` | ⚡ 마커, 기본 버튼, 활성 내비 |
| `onAccent` | `#FFFFFF` | 위 글자 (5.3:1) |
| `accentContainer` | `#EAE4FD` | 선택 칩, ⚡n 인라인 pill 배경, 활성 내비 indicator |
| `onAccentContainer` | `#2E1F85` | 위 글자 |
| `accentGradient` | `#6C4CF5` → `#8F6BFF` | 사용자 말풍선, 전송 버튼, New note FAB |
| `noteButter` | `#FFF1B8` | 노트 색 0 |
| `noteMint` | `#D9F0E1` | 노트 색 1 |
| `notePeach` | `#FFDCCB` | 노트 색 2 |
| `noteSky` | `#D6E8F8` | 노트 색 3 |
| `noteLilac` | `#E9E3FC` | 노트 색 4 |
| `noteBorder` | `#1F1B16` @ 10% (또는 `hairline`) | 노트 카드 1px |
| `pdfPaper` | `#FFFFFF` | PDF 카드 배경 |
| `pageThumb` | `#FFFFFF` + 그림자 `ink` @ 14%, blur 8, y 2, radius 4 | PDF 첫 페이지 썸네일 |
| `tierBadgeBg` / `tierBadgeFg` | `#1F1B16` @ 6% / `#1F1B16` | 카드 안 티어 pill (카드색 위) |
| `warn` / `warnContainer` / `warnBorder` | `#B45309` / `#FEF3C7` / `#B45309` @ 55% | Indexing failed, Re-index |
| `error` | `#D92D20` | 일반 오류(색인 실패에는 쓰지 않음) |
| `success` | `#16A34A` | 완료 표시 |

### 2.2 Dark (따뜻한 먹지 톤, 순수 검정 금지)

| 토큰 | 값 |
|---|---|
| `bgGradientStart` | `#1E1830` (딥 플럼) |
| `bgGradientEnd` | `#2A1F1C` (웜 브라운) |
| `blobLilac` / `blobPeach` | `#6C4CF5` @ 22% / `#FF9A6B` @ 14% |
| `glassFill` | `#FFFFFF` @ 8% |
| `glassFillStrong` | `#FFFFFF` @ 12% |
| `glassBorder` | `#FFFFFF` @ 16% |
| `glassShadow` | `#000000` @ 30%, blur 24, y 8 |
| `ink` | `#F2EDE3` |
| `inkMuted` | `#A59D8F` |
| `hairline` | `#FFFFFF` @ 14% |
| `accent` | `#B7A6FF` (어두운 배경 위 8.3:1) |
| `onAccent` | `#251A63` |
| `accentContainer` | `#3A2F7A` |
| `onAccentContainer` | `#E9E3FC` |
| `accentGradient` | `#7A5CFF` → `#9C84FF` (글자 `#FFFFFF`는 큰 글자/굵게만, 작은 글자는 `#14102B`) |
| `noteButter` | `#4A3F16` |
| `noteMint` | `#1F3D2C` |
| `notePeach` | `#4D2E21` |
| `noteSky` | `#1F3548` |
| `noteLilac` | `#35295E` |
| `noteBorder` | `#FFFFFF` @ 12% |
| `pdfPaper` | `#2A2620` (썸네일은 그대로 흰 종이 `#F7F3EA`) |
| `tierBadgeBg` / `Fg` | `#FFFFFF` @ 10% / `#F2EDE3` |
| `warn` / `warnContainer` / `warnBorder` | `#FBBF24` / `#3A2A0A` / `#FBBF24` @ 50% |
| `error` | `#F97066` |
| `success` | `#4ADE80` |

노트 카드 색은 값이 아니라 **인덱스(0~4)** 로 저장하고 테마에 따라 매핑한다. 다크에서 카드 글자는 `ink`(`#F2EDE3`), 파스텔 위 대비 8.9~10.4:1.

## 3. 타이포그래피 (`google_fonts`)

| 역할 | 폰트 | 크기 / 굵기 / 행간 |
|---|---|---|
| 브랜드 워드마크, 화면 제목(Notes, Ask) | **Fraunces** | 28 / 600 / 1.2 (데스크톱 32) |
| 노트/PDF 카드 제목 (titleMedium) | **Fraunces** | 18 / 600 / 1.25 |
| 본문·답변 (bodyLarge / bodyMedium) | **Inter** | 16 / 400 / 1.5, 14 / 400 / 1.45 |
| 버튼·내비·라벨 (labelLarge) | **Inter** (대안: Plus Jakarta Sans) | 14 / 600 / 1.2 |
| 칩·배지 (labelMedium / labelSmall) | **Inter** | 13 / 500, 12 / 500 |
| 한글 폴백 | **Noto Serif KR**(제목), **Noto Sans KR**(본문) | `fontFamilyFallback` |

- 사용하는 패키지 폰트는 `GoogleFonts.fraunces`, `GoogleFonts.inter`, 폴백 `GoogleFonts.notoSerifKr`, `GoogleFonts.notoSansKr` 네 개. (Plus Jakarta Sans는 선택, 쓰지 않아도 디자인이 성립한다.)
- Fraunces의 `SOFT`/`WONK` 축은 쓰지 않는다(정적 웨이트만). 한글 제목이 세리프로 일관되도록 제목 스타일에 `fontFamilyFallback: ['Noto Serif KR']`.
- 오프라인/번들 요구가 있으면 폰트 파일을 `assets/fonts`에 포함하고 `GoogleFonts.config.allowRuntimeFetching = false`.

## 4. Radius / 간격 / 고도

- Radius: 유리 패널(사이드바/Ask/하단 내비/시트) 24, 노트·PDF 카드 16, 칩/배지 999, 입력창·검색창 999(모바일) / 16(데스크톱 검색), 버튼 14, 말풍선 18(꼬리 쪽 6), 페이지 썸네일 4~6.
- 간격(4pt): 4 · 8 · 12 · 16 · 24 · 32. 화면 좌우 패딩 모바일 16 / 태블릿 24 / 데스크톱 24(패널 사이 gap 24). 카드 gap 12(모바일) · 16(데스크톱). 카드 패딩 16, 제목-미리보기 8, 체크리스트 행 28.
- 고도: **노트 카드** elevation 0 + 1px `noteBorder` + `BoxShadow(ink @ 6%, blur 8, y 2)`. 호버(웹)만 `y 6, blur 16, ink 10%`. **유리 패널** `glassShadow` + 1px `glassBorder`. FAB/기본 버튼 `accent @ 35%`, blur 20, y 8. Material 3 surface tint 끈다(`surfaceTintColor: transparent`).
- 유리: `ClipRRect` + `BackdropFilter(ImageFilter.blur(sigmaX: 18, sigmaY: 18))` + `glassFill` + 1px `glassBorder`.

## 5. 핵심 컴포넌트

### 5.1 노트 카드 (마크다운)
- 배경 `note*`(단색, 유리 아님), 테두리 1px `noteBorder`, radius 16, 패딩 16.
- 구성: 세리프 제목 1~2줄 → 미리보기 최대 3~4줄(본문 14, 마크다운 기호 제거) → 체크리스트 최대 3~4항목(체크박스 + 텍스트, 완료는 체크 표시 + 취소선/`inkMuted`) → 하단 티어 pill.
- 체크 표시는 깔끔한 체크 마크(X 금지). 높이 가변(masonry).

### 5.2 PDF 카드
- 배경 `pdfPaper`(흰색) + `noteBorder`. 제목 세리프(Fraunces, 파일명 전체, 2줄 말줄임), 메타 `PDF · 12 pages`(`inkMuted`), 티어 pill.
- **실제 페이지 썸네일**: 서버 저장 PDF 1쪽을 렌더링(`pdfx`/`printing`의 래스터라이즈 또는 서버 생성 PNG)해 흰 미니 페이지로 표시(`pageThumb`: radius 4, 약한 그림자). 데스크톱은 카드 상단/중앙에 큰 썸네일(약 150×190), 모바일은 왼쪽에 작은 썸네일 + 오른쪽 제목/메타(시안 기준).
- 썸네일을 만들 수 없으면 `picture_as_pdf_outlined` 아이콘으로 대체.

### 5.3 색인 실패 (Indexing failed · Re-index)
- 카드 테두리 `warnBorder`(1.5px), 카드 배경은 흰색 유지 또는 아주 옅은 앰버 틴트(`#FFF8EC`).
- 메타 아래에 `warnContainer` 행: `warning_amber_rounded` 아이콘 + `Indexing failed`(`warn`) + 외곽선 pill 버튼 **Re-index**(`OutlinedButton`, `warn` 글자/테두리, 높이 32). 행은 썸네일과 겹치지 않고 그 아래에 놓는다.
- 탭 → 스피너("Indexing…", `LinearProgressIndicator` `accent`) → 성공 시 일반 PDF 카드. 키워드 폴백이면 `Keyword search only` 보조 텍스트.
- 앰버는 이 상태에서만 쓴다. 색만으로 구분하지 않는다(아이콘 + 문구).

### 5.4 티어 배지
- pill, 높이 24, labelSmall, 배경 `tierBadgeBg`, Material 아웃라인 아이콘: `shield_outlined` **Cloak**, `cloud_outlined` **My cloud**, `group_outlined` **Hackathon**(사이드바 티어 목록에서는 `Cloak · device only`, `My cloud`, `Shared Vision · Hackathon`). 이모지 사용 금지.

### 5.5 Ask 패널 / 화면 (유리)
- 헤더: 세리프 "Ask" + 번개 아이콘(`accent`, 아웃라인). 다음 행: 모델 선택 pill `Gemma 4 26B · free` + `arrow_drop_down`(`MenuAnchor`), 항목은 모델명 + `free` + 한 줄 설명.
- 스코프 칩(`FilterChip`): 선택 시 `accentContainer` 배경 + `accent` 테두리 + 체크, 미선택 `glassFillStrong` + `hairline`. `My notes`, `Project: Hackathon`, `+ Scope`. 칩은 줄바꿈 허용(Wrap) 또는 가로 스크롤.
- 입력창: pill, `glassFillStrong`, 힌트 `Ask your notes & documents…`, 우측 `accentGradient` 원형 전송 버튼. (마이크 버튼 없음.)

### 5.6 답변 말풍선 + 인용
- 질문: 우측 정렬, `accentGradient`, 흰 글자, radius 18(우하단 6), 최대 폭 80%.
- 답변: 좌측 정렬, `glassFillStrong` + `glassBorder`, 본문 Inter 15~16, 굵게/목록 마크다운, 최대 폭 92%.
- 인라인 `⚡1`/`⚡2`: `WidgetSpan` 작은 pill(`accentContainer`, `accent` 글자·`Icons.bolt` 12 + 숫자). 탭 → 출처로 blink.
- 인용 칩(`ActionChip`): 높이 32, 투명/glass 배경, 1px `accent` 테두리, 글자 `onAccentContainer`. 내용 `⚡1 · Budget memo`, `⚡2 · Spec.pdf p.4`. 모바일은 답변 아래 `Sources` 라벨 + 칩 행.
- blink: 대상 카드에 `accent` 링 펄스 0.6s(reduced motion이면 생략), PDF는 해당 쪽으로 이동 + 구절 `accent` 18% 하이라이트.

### 5.7 내비게이션
- 모바일: 하단 유리 `NavigationBar` — Ask(`bolt`), Notes(`sticky_note_2_outlined`), Projects(`folder_outlined`). 활성 = `accent` 아이콘/라벨 + `accentContainer` indicator, 비활성 `inkMuted`. 세 아이콘은 모두 아웃라인으로 통일.
- 노트 보드 FAB: 확장 FAB `+ New note`(`accentGradient`, 흰 글자, plus 아이콘) 위에 작은 원형 glass FAB(`upload_file`). 오른쪽 하단 여백에 두고 마지막 카드 행이 FAB 영역을 침범하지 않도록 리스트 `padding.bottom = 하단 내비 높이 + 96`.
- 데스크톱 사이드바(폭 240, 유리): 상단 `⚡ PageBlink` + 태그라인(`inkMuted`) → Ask / Notes / Projects / Settings(활성 = `accent` 채움 pill + 흰 글자) → 하단 `Tiers` 섹션(Cloak · device only / My cloud / Shared Vision · Hackathon). 아바타 없음.
- 상단 바(데스크톱 보드): 세리프 "Notes" + 유리 검색창 `Search notes & PDFs…` + `+ New note`(`accentGradient`).

## 6. 반응형

| 구간 | 레이아웃 |
|---|---|
| 모바일 < 600 | 풀블리드 그라데이션 위 단일 컬럼. 헤더(⚡ PageBlink → 세리프 Notes → 검색). 2열 masonry(gap 12, 좌우 16). 하단 유리 NavigationBar. FAB 2개(New note + PDF). Ask는 별도 탭 풀스크린. |
| 태블릿 600–1024 | 접힌 유리 NavigationRail(아이콘 + 라벨) + 3열 masonry. Ask는 우측 폭 380 슬라이드 패널(토글) 또는 풀스크린. |
| 데스크톱 > 1024 | 3열: 유리 사이드바 240 · 보드(3열 bento, 최대 폭 1100, 카드 위에 컨테이너 없음) · 상시 Ask 패널 360~400(유리). 패널 사이 gap 24, 바깥 여백 24~32. 최대 콘텐츠 폭 1440 중앙 정렬. |

- 열 수: `crossAxisCount = (boardWidth / 220).floor().clamp(2, 4)`.
- 데스크톱에서 인용 칩 → 보드 위 노트/PDF 미리보기 오버레이, 모바일은 전체 화면 라우트.

## 7. Flutter 구현 노트 (Material 3)

```dart
const accent = Color(0xFF6C4CF5);
final scheme = ColorScheme(
  brightness: Brightness.light,
  primary: accent, onPrimary: Colors.white,
  primaryContainer: Color(0xFFEAE4FD), onPrimaryContainer: Color(0xFF2E1F85),
  secondary: Color(0xFF6B6358), onSecondary: Colors.white,
  error: Color(0xFFD92D20), onError: Colors.white,
  surface: Color(0xFFFBF7F2), onSurface: Color(0xFF1F1B16),
  onSurfaceVariant: Color(0xFF6B6358),
  outline: Color(0xFFB9B0A0), outlineVariant: Color(0xFFE4DDD0),
);
final text = GoogleFonts.interTextTheme().copyWith(
  displaySmall: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w600,
      fontFamilyFallback: const ['Noto Serif KR']),
  headlineSmall: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600,
      fontFamilyFallback: const ['Noto Serif KR']),
  titleMedium: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600,
      fontFamilyFallback: const ['Noto Serif KR']),
);
ThemeData(useMaterial3: true, colorScheme: scheme, textTheme: text,
  scaffoldBackgroundColor: Colors.transparent, // 배경은 루트 그라데이션 위젯
  chipTheme: const ChipThemeData(shape: StadiumBorder()),
  navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
);
```

- 토큰은 `ThemeExtension<PageBlinkTokens>` 하나에 light/dark로 정의: `bgGradient*`, `glassFill*`, `glassBorder`, `glassShadow`, `note0..4`, `noteBorder`, `pdfPaper`, `warn*`, `tierBadge*`. 노트 색은 인덱스 → `tokens.noteColor(i)`.
- 배경: 루트 `DecoratedBox(LinearGradient(topLeft→bottomRight, [bgGradientStart, bgGradientEnd]))` + (선택) 블러 원 2개(`ImageFiltered`) + (선택) 노이즈 타일 `DecorationImage(repeat: ImageRepeat.repeat)` 3~4%. 스크롤과 무관하게 고정.
- `GlassPanel` 위젯 하나로 통일(ClipRRect + BackdropFilter + DecoratedBox + 1px border). **BackdropFilter는 사이드바 / Ask 패널 / 하단 내비 / 검색창 / 시트 같은 큰 표면에만** 쓴다. **노트·PDF 카드는 BackdropFilter 없이 단색 + 헤어라인 + 약한 그림자**(성능, 웹 CanvasKit 포함). 그래서 이 방향은 A보다 그리드 성능이 좋다.
- 카드: `Material` + `InkWell` + `DecoratedBox`. 마소너리: `flutter_staggered_grid_view`의 `MasonryGridView`. 마크다운: `flutter_markdown`, ⚡n는 `InlineSyntax` → `WidgetSpan`.
- 패키지: `google_fonts`, `flutter_staggered_grid_view`, `flutter_markdown`, (PDF 썸네일) `pdfx` 또는 서버 생성 PNG.
- 접근성: 본문 `ink` 대비 13~15:1(파스텔 위), `accent`/흰 5.3:1, `inkMuted`/버터 5.2:1, `warn`/`warnContainer` 4.5:1(굵게 13+ 이상에서만 사용). 터치 타깃 48dp(칩/배지는 `materialTapTargetSize`로 확장). 색만으로 상태 구분 금지.
- 다크: 같은 구조의 `ColorScheme(brightness: dark)`를 2.2 표로 구성. 유리는 `glassFill` 8~12% 흰색이라 배경 그라데이션(딥 플럼 → 웜 브라운) 위에서 대비가 유지된다.

## 8. 시안 한계

- 데스크톱 시안에서 PDF 썸네일 본문은 해상도상 읽을 수 없다(실제 구현은 서버 렌더 이미지).
- 모바일 보드 시안의 Reading list 내용은 문서 예시와 다르다(모델이 바꿈). 모바일 Ask 시안은 `+ Scope` 칩이 오른쪽 가장자리에 가깝다 → 구현에서는 Wrap 처리.
