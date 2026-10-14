# 방향 A — Soft Glass + Bento

레퍼런스: Dribbble "AI notes app", Linear / Raycast 웹사이트. 목업: `desktop.png`(데스크톱 3열), `mobile-board.png`(모바일 노트 보드), `mobile-ask.png`(모바일 Ask). 이미지는 생성 모델 산출물이라 일부 문구/세부(예: 카드 안 Pro/Basic/Team 배지)는 실제 스펙이 아니며, 아래 스펙이 우선한다.

## 1. 컨셉

- 연한 라벤더 → 스카이 그라데이션 배경 위에 반투명 유리(frosted glass) 카드를 띄우는 모던 SaaS 룩.
- 노트 보드는 크기가 다른 카드가 맞물리는 bento/masonry 그리드. 시선은 전기 바이올렛(#6C4CF5) 한 가지 포인트와 일렉트릭 블루 보조색에 집중.
- 브랜드: "⚡ PageBlink" (번개 마크 + 워드마크). 태그라인: "Ask your notes & documents. Blink to the source."
- 여백을 넉넉히, 그림자는 바이올렛 틴트의 부드러운 그림자, 선은 1px 흰색 반투명 테두리로만 구분.
- 티어 표현: ☁ My cloud / 👥 프로젝트명(Shared Vision) / Cloak(기기 전용, "Coming soon" 비활성).

## 2. 팔레트 (토큰)

| 토큰 | Light | Dark |
|---|---|---|
| primary (전기 바이올렛) | `#6C4CF5` | `#8B7BFF` |
| onPrimary | `#FFFFFF` | `#14102B` |
| secondary (전기 블루) | `#2F7BFF` | `#6AA2FF` |
| bgGradientStart (lavender) | `#EDE9FE` | `#14112B` |
| bgGradientEnd (sky) | `#DBEAFE` | `#0F1A33` |
| glassFill (카드) | `#FFFFFF` @ 60% | `#FFFFFF` @ 8% |
| glassFillStrong (사이드/패널) | `#FFFFFF` @ 72% | `#FFFFFF` @ 12% |
| glassBorder | `#FFFFFF` @ 80% | `#FFFFFF` @ 16% |
| textPrimary | `#14122B` | `#F2F0FF` |
| textSecondary | `#5B5878` | `#A9A6C8` |
| outline / divider | `#6C4CF5` @ 12% | `#FFFFFF` @ 14% |
| tierCloud (배지 배경 / 글자) | `#E6F0FF` / `#1D5FD1` | `#1E2F55` / `#8DB8FF` |
| tierProject (배지 배경 / 글자) | `#EDE7FF` / `#5236C9` | `#2A2250` / `#B9A9FF` |
| tierCloak (비활성) | `#EEEDF5` / `#8C89A5` | `#24223A` / `#7F7C9D` |
| citationChip (테두리 / 글자) | `#2F7BFF` / `#1D5FD1` | `#6AA2FF` / `#8DB8FF` |
| warning (Re-index 실패) | `#B45309` bg `#FEF3C7` | `#FBBF24` bg `#3A2A0A` |
| error | `#D92D20` | `#F97066` |
| success | `#16A34A` | `#4ADE80` |

보조 그라데이션: primaryGradient = `#6C4CF5` → `#8F6BFF` (사용자 말풍선, FAB, 전송 버튼).
대비: 본문 텍스트는 유리 카드 위에서도 WCAG AA(4.5:1) 이상 — 유리 위 텍스트는 항상 textPrimary 사용, 투명도 낮은 글자 금지.

## 3. 타이포그래피 (Google Fonts, `google_fonts` 패키지)

- 영문/숫자: **Plus Jakarta Sans** (제목, 브랜드), **Inter** (본문, 라벨). 한글은 시스템 폴백 대신 **Noto Sans KR** 지정(fontFamilyFallback).
- 스케일(sp): displayLarge 32/40 w700(Jakarta) · headlineMedium 24/32 w700 · titleLarge 20/28 w600 · titleMedium 16/24 w600 · bodyLarge 16/24 w400(Inter) · bodyMedium 14/20 · labelLarge 14/20 w600 · labelSmall 12/16 w500(배지/칩).
- 노트 카드 제목은 titleMedium, 프리뷰는 bodyMedium(최대 3~4줄 ellipsis).

## 4. 반경 / 간격 / 고도

- Radius: 카드 20, 패널/시트 24, 칩/배지 full(999), 입력창 full, 말풍선 20(꼬리 쪽 모서리 6), 버튼 14.
- Spacing(4pt 그리드): 4 · 8 · 12 · 16 · 24 · 32. 화면 좌우 패딩 모바일 16 / 태블릿 24 / 데스크톱 32. 그리드 gap 12(모바일) · 16(데스크톱).
- Elevation: 유리 카드는 Material elevation 대신 커스텀 `BoxShadow(color: #6C4CF5 @ 12%, blurRadius: 24, offset: (0, 8))` + 1px glassBorder. FAB/primary 버튼은 `#6C4CF5 @ 35%`, blur 20, offset (0, 8).
- 유리 효과: `ClipRRect` + `BackdropFilter(ImageFilter.blur(sigmaX: 16, sigmaY: 16))` + glassFill. 리스트 안 카드마다 blur를 쓰면 성능이 떨어지므로 아래 구현 노트 참고.

## 5. 핵심 컴포넌트

### 5.1 노트 카드 (Markdown)
- glass 카드(radius 20, padding 16). 상단: 제목(titleMedium) → 프리뷰 3줄(마크다운 기호 제거한 plain text) → 체크리스트 최대 3개(체크박스 20px, 체크 시 primary 채움, 완료 항목은 취소선 없이 textSecondary) → 하단 티어 배지.
- 높이는 내용에 따라 가변(masonry). 탭: 상세/편집, 길게 누르기: 선택/삭제.

### 5.2 PDF 카드
- 상단에 PDF 아이콘(48px 둥근 문서, 로즈-바이올렛 그라데이션 `#C2416C`→`#8B3FB8`), 파일명(titleMedium), 메타 "PDF · 12 pages"(textSecondary), 하단 티어 배지.
- **인덱싱 실패 상태**: 메타 아래에 ⚠ "Indexing failed"(warning 색) + 외곽선형 **Re-index** 버튼(`OutlinedButton`, warning 색 테두리). 카드 테두리는 warning @ 40%. 인덱싱 중일 땐 같은 위치에 `LinearProgressIndicator`(primary) + "Indexing…".

### 5.3 티어 배지
- full 라운드 pill, labelSmall. 아이콘 + 텍스트: `☁ My cloud`(tierCloud), `👥 Hackathon`(tierProject), `Cloak`(tierCloak, 잠금 아이콘, "Coming soon"). 이모지 대신 Material 아이콘(`cloud_outlined`, `group_outlined`, `lock_outline`) 사용.

### 5.4 Ask 패널 / 화면
- 헤더: "⚡ Ask" + 모델 선택 pill("Gemma 4 26B · free ▾", `MenuAnchor` 또는 `PopupMenuButton`, 무료 모델에 "free" 서브라벨).
- 스코프 칩: `FilterChip` 다중 선택(My notes, Project: Hackathon, + Scope). 선택 시 primary 채움 + ✓.
- 입력창: full 라운드 glass 필드 "Ask your notes & documents…" + 우측 primaryGradient 원형 전송 버튼.

### 5.5 답변 말풍선 + 인용 칩
- 사용자 말풍선: 우측 정렬, primaryGradient, 흰 글자. 어시스턴트: 좌측 정렬 glass 카드(radius 20), 마크다운 렌더(굵게, 불릿) + 스트리밍 중 끝에 깜빡이는 커서(바이올렛 2px 바).
- 본문 속 인라인 마커 ⚡1 ⚡2: 작은 pill(primary @ 14% 배경, primary 글자, labelSmall)을 `WidgetSpan`으로 삽입, 탭하면 해당 출처로 blink(이동).
- 인용 칩 행: `ActionChip`형 외곽선 pill(citationChip 테두리 1px, 배경 glass) — "⚡1 · Budget memo", "⚡2 · Spec.pdf p.4". 가로 스크롤 허용. 탭 → 노트 상세 또는 PDF 해당 페이지로 이동(blink 애니메이션: 대상 카드에 primary 링 0.6초 펄스).

### 5.6 내비게이션
- 모바일: 하단 glass 내비게이션 바(`NavigationBar`, 항목 Ask · Notes · Projects, 선택 시 primary 아이콘 + 라벨, indicator는 primary @ 12%). 노트 화면 우하단: 확장 FAB "+ New note"(primaryGradient) 위에 작은 원형 glass FAB(PDF 업로드).
- 데스크톱: 좌측 사이드바(`NavigationRail` extended 또는 커스텀, 폭 240) Ask / Notes / Projects / Settings, 활성 항목은 primary 채움 pill. 상단에 "⚡ PageBlink" 마크, 하단에 아바타.

### 5.7 업로드 티어 시트
- `showModalBottomSheet`(데스크톱은 중앙 `Dialog`), glass 시트 radius 24 상단. 제목 "Where should this live?" + 3개 라디오 카드(`RadioListTile`형 카드):
  - **Cloak** — "Device only. Never leaves your phone." / 비활성, "Coming soon" 배지.
  - **My cloud** — "Private to you, searchable anywhere." (기본 선택)
  - **Shared Vision** — "Share with a project" + 프로젝트 드롭다운(Hackathon).
- 하단 "Upload" primary 버튼. (이 시트는 목업 이미지로 생성하지 않았고 텍스트 스펙만 제공.)

## 6. 반응형 레이아웃

| 구간 | 레이아웃 |
|---|---|
| 모바일 < 600 | 단일 컬럼 화면. 노트 보드 2열 masonry. 하단 NavigationBar(Ask · Notes · Projects). Ask는 별도 탭 풀스크린. 시트는 bottom sheet. |
| 태블릿 600–1024 | 좌측 NavigationRail(아이콘 + 라벨) + 노트 보드 3열. Ask는 우측에서 슬라이드되는 폭 380 사이드 패널(토글) 또는 별도 탭. |
| 데스크톱 > 1024 | 3열: 사이드바 240 · 노트 보드(남은 폭, 3~4열 bento, 최대 폭 1100) · 상시 표시 Ask 패널 폭 360~400. 콘텐츠 최대 폭 1440 중앙 정렬. |

- bento 그리드: `flutter_staggered_grid_view`의 `MasonryGridView.count`(crossAxisCount 2/3/4, spacing 12~16). 큰 카드(예: 긴 노트)는 `StaggeredGrid`로 2칸 span 가능.
- 브레이크포인트는 `LayoutBuilder` / `MediaQuery.sizeOf(context).width`로 판단.

## 7. Flutter 구현 노트 (Material 3)

```dart
final scheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6C4CF5), brightness: Brightness.light,
).copyWith(
  primary: const Color(0xFF6C4CF5), onPrimary: Colors.white,
  secondary: const Color(0xFF2F7BFF),
  surface: const Color(0xFFF7F5FF), onSurface: const Color(0xFF14122B),
  outline: const Color(0x1F6C4CF5),
);
ThemeData(
  useMaterial3: true, colorScheme: scheme,
  textTheme: GoogleFonts.interTextTheme().copyWith(
    headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600),
  ),
  scaffoldBackgroundColor: Colors.transparent, // 배경은 별도 그라데이션 위젯
  chipTheme: ChipThemeData(shape: StadiumBorder(), side: BorderSide(color: scheme.outline)),
  navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.transparent,
    indicatorColor: scheme.primary.withOpacity(.12)),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
);
```

- 다크: `ColorScheme.fromSeed(brightness: Brightness.dark)` + 위 Dark 토큰으로 `copyWith`. 토큰(glassFill, glassBorder, tier 색 등)은 `ThemeExtension<PageBlinkTokens>`로 light/dark 각각 정의.
- 배경: 루트에 `DecoratedBox(gradient: LinearGradient(begin: topLeft, end: bottomRight, colors: [lavender, sky]))` + 장식용 블러 원 2~3개(`Positioned` + `ImageFiltered`) — 스크롤과 무관하게 고정.
- `GlassCard` 공통 위젯 하나로 통일(ClipRRect + BackdropFilter + DecoratedBox + 1px border). **성능 주의**: bento 그리드 항목 전부에 BackdropFilter를 쓰면 모바일 저사양에서 프레임 드랍 — 그리드 카드는 BackdropFilter 없이 반투명 fill + 그림자만 사용하고, BackdropFilter는 사이드바/Ask 패널/하단 바/시트 등 큰 표면에만 적용한다. 웹(CanvasKit)에서도 blur 영역을 최소화.
- 마크다운 렌더: `flutter_markdown`(또는 `gpt_markdown`)의 `MarkdownStyleSheet`를 테마에 맞추고, 인라인 ⚡n 마커는 커스텀 `MarkdownElementBuilder`/`InlineSyntax`로 `WidgetSpan` 변환.
- 스트리밍 커서: `AnimatedOpacity` 반복(0.5s) 2px 바.
- 접근성: 유리 위 텍스트 대비 AA, 터치 타깃 최소 48dp(칩/배지는 시각 높이 28~32 + `materialTapTargetSize`로 확장), `prefers-reduced-motion`에서 blink 펄스 생략.
