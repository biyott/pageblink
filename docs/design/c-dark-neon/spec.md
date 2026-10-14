# 방향 C — Dark Neon Gamer

목업: `desktop.png`(1440 데스크톱), `mobile-board.png`(노트 보드), `mobile-ask.png`(질문 화면).
모델: `google/gemini-3-pro-image` (OpenRouter). 이미지는 레이아웃·분위기 참고용이며 일부 텍스트가 깨져 있음(아래 "목업 주의점").

## 1. 컨셉

게임 HUD 느낌의 다크 UI. 기능 이름을 게임 용어로 노출하되 본문은 읽기 쉬운 Inter 로 유지한다. 네온은 "상태/포커스/출처" 신호에만 쓰고, 카드 본문은 차분한 어두운 표면으로 둔다.

| 기능 | UI 용어 | 비고 |
|---|---|---|
| 출처로 점프 | **Blink** | 인용 칩 탭 → 원문 위치 |
| 동기화 | **Recall** | 사이드바/앱바의 싱크 상태 |
| 기기 내 전용 | **Cloak** | 티어 배지(보라, 자물쇠) |
| 프로젝트 공유 | **Shared Vision** | 티어 배지(그린-마젠타 테두리, 눈 아이콘) |
| 알림 | **Ping** | 사이드바 항목 + 배지 |

티어: Cloak(기기 전용) / My cloud(시안, 구름) / Shared Vision · 프로젝트명.

## 2. 팔레트 (hex 토큰)

### Dark (기본)
| 토큰 | 값 | 용도 |
|---|---|---|
| bg | `#0B0D17` | 배경 |
| surface | `#121528` | 카드/패널 |
| surfaceHigh | `#1A1E36` | 칩, 입력창, 사이드바 선택 |
| outline | `#2A2F52` | 기본 1px 테두리 |
| primary (violet) | `#8B5CF6` | 주 액션, Cloak, 사용자 말풍선 |
| secondary (cyan) | `#22D3EE` | My cloud, PDF, 답변 테두리, 인용 칩 2 |
| tertiary (green) | `#34D399` | Shared Vision |
| warning/error | `#FB923C` / `#F43F5E` | Re-index 실패 카드 |
| text | `#E6E8F5` | 본문 |
| textMuted | `#8A90B0` | 보조 |
| glow | primary/secondary 의 35% alpha | BoxShadow blur 12–20 |

### Light (보조 — 이 방향은 다크 우선, 라이트는 대응용)
| 토큰 | 값 |
|---|---|
| bg | `#F5F6FB` |
| surface | `#FFFFFF` |
| surfaceHigh | `#ECEEF8` |
| outline | `#D5D8EA` |
| primary | `#6D3FE0` |
| secondary | `#0891B2` |
| tertiary | `#059669` |
| error | `#E11D48` |
| text / textMuted | `#14162A` / `#5B6182` |

라이트에서는 글로우를 끄고(elevation 1 그림자) 테두리 색만 유지한다.

## 3. 타이포그래피 (google_fonts, 이미 pubspec 에 있음)

- 디스플레이: **Space Grotesk** (대안 Rajdhani) — 로고, 화면 제목, 카드 제목, 칩 라벨. w600–700.
- 본문: **Inter** — 노트 미리보기, 답변 마크다운, 입력창. w400/500.
- 스케일: 로고 24 / 화면 제목 20 / 카드 제목 16 / 본문 14 (모바일 15) / 캡션·배지 12.
- 인용 마커 `⚡1` 은 본문 안에서 superscript 스타일(WidgetSpan 또는 `TextSpan` + 작은 폰트), 색 amber `#FBBF24`.

## 4. 반경 / 간격 / 엘리베이션

- 반경: 카드·패널 16, 칩·배지·pill 999(full), 버튼 12, 입력창 16.
- 간격: 4 배수. 카드 내부 padding 14, 카드 간 gap 12(모바일) / 16(데스크톱), 화면 gutter 16 / 24.
- 테두리: 기본 1px `outline`, 활성/포커스 1.5px 네온(primary 또는 secondary).
- 엘리베이션: M3 그림자 대신 `BoxShadow(color: neon.withOpacity(.35), blurRadius: 16)` 로 글로우. 비활성 카드는 글로우 없음.
- HUD 디테일(선택): 카드 모서리 코너 브래킷, 배경 그리드. `CustomPainter` 로 배경에 12–32px 격자를 alpha 4–6% 로 그린다. 성능이 걱정되면 생략 가능(핵심 아님).

## 5. 핵심 컴포넌트

- **노트 카드**(마크다운): surface + 1px 테두리(티어색), 제목(Space Grotesk 16), 미리보기 2줄 ellipsis, 체크리스트 최대 3줄(체크박스 + 라벨), 하단/우상단 티어 배지. 한국어 제목 정상 표시(Inter + Noto Sans KR fallback).
- **PDF 카드**: 시안 테두리, PDF 아이콘, 파일명, `PDF · 12 pages` 캡션, 티어 배지.
- **티어 배지**: 작은 pill(높이 22), 아이콘 + 라벨. Cloak=보라 자물쇠 / My cloud=시안 구름 / Shared Vision · Hackathon=그린 눈 아이콘.
- **실패 카드(Re-index)**: warning 테두리 + 연한 warning 배경(alpha 8%), 경고 아이콘, "Indexing failed · Re-index" 라벨, `Retry` 버튼. 본문은 읽을 수 있게 dim 하지 않는다.
- **인용 칩(스킬 버튼)**: pill, 아이콘 `bolt` + `1 · Budget memo`. 색은 출처 순서별로 violet/cyan 교대, 얇은 네온 테두리 + 약한 글로우. 탭 = Blink(원문으로 점프, PDF 는 페이지 이동).
- **답변 버블**: surface, 시안 1.5px 테두리, 마크다운(굵게/목록) + 인라인 `⚡n`, 스트리밍 중 끝에 깜빡이는 커서(AnimatedOpacity). 사용자 버블은 보라 테두리, 우측 정렬.
- **모델 선택**: pill 버튼 `Gemma 4 26B · free` + chevron (PopupMenuButton / 바텀시트).
- **범위 칩**: `FilterChip` — All / Cloak / My cloud / <프로젝트명>. 선택 시 네온 테두리 + 글로우.
- **네비게이션**: 모바일 `NavigationBar`(Ask · Notes · Projects, 선택 시 상단 네온 인디케이터), 데스크톱 좌측 사이드바(Notes, PDFs, Projects, Recall + 스피너, Ping + 배지, Settings, 하단 Cloak 토글).
- **FAB**: 주 `FloatingActionButton.extended` "New note"(violet), 보조 `FloatingActionButton.small`(cyan, PDF 업로드). 보조 FAB 은 주 FAB 위에 세로 배치(목업처럼 겹치지 않게).

## 6. 반응형 레이아웃

- **모바일 < 600**: 하단 NavigationBar 3개. Notes = 필터 칩 가로 스크롤 + 2열 masonry(`flutter_staggered_grid_view` 또는 두 개의 Column). Ask = 전체 화면, 상단 모델 pill + 범위 칩, 채팅 리스트, 하단 입력창. FAB 두 개는 NavigationBar 위 우측.
- **태블릿 600–1024**: NavigationRail(아이콘 + 라벨), 보드 3열, Ask 는 오른쪽 슬라이드 패널(폭 360, 토글) 또는 별도 화면.
- **데스크톱 > 1024**: 3분할 — 좌 사이드바 240, 중앙 보드(3–4열 masonry), 우 Ask 패널 380 상시 고정(네온 테두리). 중앙 최대 폭 제한 없음, 카드 열 수는 `LayoutBuilder` 로 280px 기준 계산.

## 7. Flutter 구현 노트 (Material 3)

- `ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.dark(primary: 0xFF8B5CF6, secondary: 0xFF22D3EE, tertiary: 0xFF34D399, surface: 0xFF121528, error: 0xFFF43F5E, outline: 0xFF2A2F52), scaffoldBackgroundColor: 0xFF0B0D17)`. 라이트는 위 라이트 토큰으로 `ColorScheme.light`.
- `textTheme`: `GoogleFonts.interTextTheme()` 에 `displayLarge…titleMedium` 만 `GoogleFonts.spaceGrotesk` 로 교체.
- 카드: `Card` 대신 `Container(decoration: BoxDecoration(color: surface, borderRadius: 16, border: Border.all(color: neon.withOpacity(.6)), boxShadow: [glow]))` 를 감싼 `NeonCard` 위젯 하나로 통일. `ThemeExtension<NeonTheme>` 에 glow/티어 색 보관.
- 칩/버튼: `ChipThemeData`, `FilledButtonThemeData`, `NavigationBarThemeData`(indicatorColor primary 15%) 로 전역 스타일링, 개별 위젯 하드코딩 최소화.
- 글로우는 BoxShadow 만 사용(ImageFilter blur/shader 불필요). 목록에서 글로우 카드 수가 많으면 활성/호버 카드에만 적용해 성능 확보.
- 접근성: 네온 텍스트는 본문 색으로 쓰지 말고 테두리/아이콘에만 사용. 대비(text on surface)는 4.5:1 이상 유지. 실패 상태는 색 + 아이콘 + 문구를 함께 표시.

## 8. 목업 주의점 (이미지 한계)

- `desktop.png`: 일부 체크리스트 문구가 생성 오류로 깨져 있음(예: "Nor nond assues"). 구조/색/배치만 참고.
- `mobile-board.png`: 하단 Ask 탭 아이콘이 마이크로 그려짐(말풍선/번개로 구현), 두 FAB 이 카드와 겹침(구현 시 세로 스택), 실패 카드 본문이 dim 되어 있음(구현 시 dim 하지 않음).
- `mobile-ask.png`: 범위 칩이 가로 스크롤로 잘리는 것은 의도(스크롤 가능 표시).
- 첫 시도의 두 모바일 이미지는 화면 혼입(보드+Ask)이 있어 "단일 화면만" 제약을 추가해 1회 재생성했고, 현재 파일이 재생성본이다.
