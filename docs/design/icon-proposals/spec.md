# 아이콘 시안 — 앱 아이콘 3안 + UI 아이콘 세트 3안

작성 2026-10-15 09:21 KST. 기준 방향은 채택된 **AB v2**(`../ab-v2/spec.md`, 구현은 `app/pageblink_flutter/lib/app/theme.dart`). 색·타이포·규칙은 거기 값을 그대로 쓰고 여기서는 **아이콘에 필요한 부분만** 적는다. 코드는 건드리지 않았다.

✅ = 직접 확인(파일·pub.dev API·README) / ⚠️ = 미확인 또는 추정.

## 0. 파일

| 경로 | 내용 |
|---|---|
| `app-icon/overview.png` (+`.svg`) | 3안 비교판: 라이트/다크 변형, iOS 라운드·Android 원형 마스크, 실제 16/32/48px 래스터(1배·3배) |
| `app-icon/adaptive-safe-zone-check.png` | 3안 전경을 원형 마스크 + 626px 안전 원(점선)과 겹쳐 확인 |
| `app-icon/p1-folded-page/` | P1. `master-light.svg/png`, `master-dark.svg/png`(1024 풀블리드, 불투명), `adaptive-foreground.svg/png`, `adaptive-background.svg/png`, `ios-dark-transparent.svg/png`(투명 글리프), `macos-light.svg/png` |
| `app-icon/p2-bookmark-bolt/` | P2. 동일 구성 |
| `app-icon/p3-highlight-line/` | P3. 동일 구성 |
| `ui-icons/s1-lucide-stroke.svg/png` | S1 라운드 스트로크(Lucide). 24px 그리드, 라이트·다크, 12개 + tier 2종 + 읽기/편집 토글 |
| `ui-icons/s2-phosphor-duotone.svg/png` | S2 듀오톤(Phosphor) + 아래 줄에 Material Symbols Rounded Fill 비교 |
| `ui-icons/s3-custom-bold.svg/png` | S3 굵은 심플·커스텀 모서리(직접 그린 세트) |

앱 아이콘 SVG는 전부 손으로 쓴 결정적 SVG(자체 번개 폴리곤, 외부 에셋 없음)이고 PNG는 `rsvg-convert`로 렌더했다. 이미지 생성 모델은 쓰지 않았다. S1·S2 글리프는 실제 오픈소스 세트의 SVG를 그대로 배치한 것이고, S3만 이 시안용으로 그린 경로다.

## 1. 현재 상태 (✅ 확인)

- `app/pageblink_flutter`에 android / ios / linux / macos / web / windows 폴더가 있다. 아이콘은 Flutter 기본(`web/icons/Icon-192·512·maskable`, `macos/.../app_icon_*.png`, `ios/.../Icon-App-*`, `android/.../mipmap-*/ic_launcher.png`). 웹 `manifest.json`의 `background_color`/`theme_color`는 기본값 `#0175C2`다.
- `pubspec.yaml`에 아이콘 패키지는 `cupertino_icons`뿐이고, 코드는 Material `Icons.*` 약 40종을 쓴다. 가장 많은 것: `groups_outlined` 8, `bolt` 7, `sticky_note_2_outlined` 5, `cloud_outlined` 4.
- 헷갈리는 의미 두 곳: ① `note_editor_screen.dart`는 `visibility_outlined`/`edit_outlined`를 토글 아이콘으로 쓴다(현재 모드가 아니라 **다음 모드**를 보여줘서 모호). ② `documents_screen.dart`는 Cloak 티어에 `visibility_off_outlined`를 쓴다(눈 모양이지만 의미는 "기기 전용·보이지 않음"이라 미리보기와 충돌).

## 2. 팔레트 (아이콘 관점, 값은 ab-v2 `theme.dart`에서 확인, 표시한 행만 이 시안 신규)

| 토큰 | Light | Dark | 아이콘에서의 용도 |
|---|---|---|---|
| `ink` | `#1F1B16` | `#F2EDE3` | 모든 UI 아이콘 기본색 |
| `inkMuted` | `#6B6358` | `#A59D8F` | 비활성 탭 아이콘, 토글의 비선택 쪽 |
| `accent` | `#6C4CF5` | `#B7A6FF` | **⚡ 인용 아이콘과 활성 내비만.** 그 외 아이콘에 쓰지 않는다(ab-v2 규칙 14) |
| `accentContainer` / `onAccentContainer` | `#EAE4FD` / `#2E1F85` | `#3A2F7A` / `#E9E3FC` | 읽기\|편집 토글의 선택 세그먼트, 활성 내비 indicator |
| `hairline` | `#E4DDD0` | `#FFFFFF` 14% (`0x24FFFFFF`) | 토글 외곽선 |
| 앱 아이콘 전용(이 시안에서 새로 정함, ab-v2 값 아님) | 접힌 코너 `#DCD2FB`/`#CFC4F5`, 잉크 타일 `#2B2620→#1F1B16`, 다크 타일 `#2A1F3F→#1E1830`·`#241A3D→#17122A`, 다크 알약 `#7A5CFF` | | 앱 아이콘 면 |
| 앱 아이콘이 재사용한 ab-v2 값 | 그라데이션 `#6C4CF5→#8F6BFF`, 배경 `#EDE6FA→#F7E8EE→#FFE9DC`, 코너 글로우 `#CDBBFA`/`#FFC9A8` | 배경 `#1E1830→#251C27→#2A1F1C` | |

아이콘은 글자를 포함하지 않으므로 타이포 규칙(Fraunces 제목 / Inter 본문)은 그대로 두고, 앱 아이콘에 워드마크를 넣지 않는다(작은 크기에서 읽히지 않음).

## 3. A. 앱 아이콘 모양 3안

세 안 모두 **글리프를 반지름 313px(1024 기준 66% 안전 원) 안에** 그리고, 마스터에서는 1.2배로 키운다(안드로이드 적응형 전경은 1.0배). 번개 폴리곤은 같은 도형을 공유해 사이드바의 `⚡ PageBlink` 브랜드 마크와 이어진다.

### P1 Folded Page — 접힌 페이지 + 번개
- **컨셉**: 모서리가 접힌 흰 페이지 위의 바이올렛 번개 = "문서에서 ⚡ 인용으로 깜빡 이동". 브랜드 마크(바이올렛 번개)를 가장 직접 확장.
- **라이트**: 바이올렛 그라데이션 타일 + 흰 페이지 + 바이올렛 번개(접힌 코너는 `#DCD2FB`).
- **다크**: `#2A1F3F→#1E1830` 타일 + 크림(`#F2EDE3`) 페이지 + 바이올렛 번개. 타일이 어두워도 페이지가 밝아 실루엣이 유지된다.
- **작은 크기(overview.png에서 직접 확인)**: 48/32px에서 "페이지+번개"가 분명하다. 16px에서는 번개가 2~3px 점으로 줄지만 **밝은 페이지 실루엣이 보라 타일 위에 남아 식별된다**. 세 안 중 가장 안전.
- **약점**: "문서 + 번개" 조합은 흔하다(차별성 중간).

### P2 Bookmark — 책갈피 + 번개
- **컨셉**: 아래가 V자로 파인 책갈피 리본(= 출처 위치 표시) 안에 번개. "원문에 꽂힌 책갈피로 점프".
- **라이트**: 파스텔 글래스 페이퍼 배경(라벤더→피치 + 코너 글로우) + 잉크색 리본 + 바이올렛 번개. 앱 배경과 가장 닮아 따뜻하다.
- **다크**: `#1E1830→#2A1F1C` 배경 + 라벤더(`#B7A6FF`) 리본 + 진한 번개(`#251A63`).
- **작은 크기**: 32/48px에서는 리본+번개가 읽힌다. **16px에서는 번개가 사라지고 일반 책갈피 아이콘**으로 보인다(브랜드 식별은 색 조합뿐). 파스텔 타일은 밝은 배경 위에서 테두리가 약해진다.
- **약점**: 번개가 리본 안에서 작다. 책갈피는 제품의 핵심 동사(질문→원문 이동)와 연결되지만 "노트/PDF 앱"이라는 느낌은 약하다.

### P3 Highlight Line — 인용 하이라이트 줄
- **컨셉**: 텍스트 줄 사이에서 한 줄만 바이올렛 알약으로 하이라이트되고 앞에 번개 = PDF/노트 안에서 인용 구절이 "깜빡" 하이라이트되는 실제 화면.
- **라이트**: 따뜻한 잉크 타일(`#2B2620→#1F1B16`) + 크림 줄 2개 + 바이올렛 알약(흰 번개 + 흰 줄).
- **다크**: `#241A3D→#17122A` 타일 + 밝은 바이올렛(`#7A5CFF`) 알약. 다크 홈 화면에서는 어두운 타일이 배경에 묻힐 수 있다(경계선은 OS 마스크와 어긋나 마스터에 넣지 않았다. 필요하면 배경을 약간 밝게).
- **작은 크기**: 48/32px에서 "줄 3개 + 보라 알약"이 읽히고 가장 독특한 실루엣이다. **16px에서는 번개가 뭉개져 "목록/메뉴 줄"처럼 보여** 채팅·목록 앱과 혼동될 수 있다. 번개를 키우거나 줄을 2개로 줄이는 16px 전용 단순판이 필요할 수 있다.
- **약점**: 홈 화면에서 다크 타일이 두드러지지만 앱 배경(파스텔)과 톤 연결은 가장 약하다.

### 3.1 공통 제작·적용 경로

| 대상 | 원본/해상도 | 비고 |
|---|---|---|
| 마스터 | `master-light.png` 1024×1024 | **풀블리드·불투명**(둥근 모서리·투명도 없음. 마스크는 OS가 적용). 생성 도구가 알파 제거를 지원하는지는 아래 표 |
| iOS | 1024 마스터 1장 | iOS 18 다크는 README상 **투명 배경 권장** → `ios-dark-transparent.png`(글리프만, 투명)를 따로 둠. `master-dark.png`는 불투명 다크 표면 미리보기이며 iOS 다크 자산이 아니다. 틴티드는 그레이스케일 파일이 따로 필요(시안 미포함, ⚠️) |
| Android 적응형 | 전경 `adaptive-foreground.png/svg`(투명, 108dp 캔버스 중 66dp 안전 영역 = 1024px 기준 약 626px) + 배경 `adaptive-background.png/svg`. 안전 원 안에 들어가는지 `adaptive-safe-zone-check.png`로 확인(3안 모두 통과) | 단색/이미지 배경. Android 13+ 테마 아이콘(monochrome)은 전경의 단색 실루엣이 필요(시안 미포함, P1은 페이지 실루엣을 그대로 쓰면 됨) |
| macOS | `macos-light.png` | macOS는 OS가 마스크하지 않으므로 **824px 둥근 본체 + 100px 여백 + 그림자**를 직접 그린 판(Apple 템플릿 관례, ⚠️ 정확한 반경 수치는 Apple 공식 템플릿 대조 전) |
| Web | favicon 16/32/48, `Icon-192/512`, maskable 192/512 | maskable은 중앙 80% 안전 영역에 글리프를 넣어야 함. 소형 favicon은 위 3안 중 P1이 가장 안전 |

`flutter_launcher_icons` 0.14.4(pub.dev API 확인, 2025-06-10, MIT)의 README에서 확인한 키:
✅ `adaptive_icon_background`, `adaptive_icon_foreground`(둘 다 지정해야 생성), `adaptive_icon_foreground_inset`(기본 16%), `adaptive_icon_monochrome`, `remove_alpha_ios`, `background_color_ios`, `image_path_ios_dark_transparent`, `image_path_ios_tinted_grayscale`, `web.background_color`/`web.theme_color`, `macos.image_path`.
⚠️ 이 저장소에서 실제로 실행해 결과를 확인하지는 않았다(코드/설정 수정 금지 범위). `windows`/`linux` 지원 범위와 기본 inset 16%가 우리 전경 안전 영역과 맞는지는 적용 시 확인 필요.

적용 시 `pubspec.yaml`에 `flutter_launcher_icons` 설정 블록을 추가하고(⚠️ dev_dependency 추가 필요) 위 PNG를 `assets/icon/`에 두는 흐름을 가정한다. `web/manifest.json`의 `#0175C2`는 `#6C4CF5`(또는 앱 배경 `#EDE6FA`)로 바꿔야 한다.

## 4. B. UI 아이콘 세트 3안

### 4.1 비교표 (pub.dev API로 확인한 값, 조회일 2026-10-15)

| 항목 | S1 `lucide_icons_flutter` | S2 `phosphor_flutter` | (비교) `material_symbols_icons` | S3 커스텀 |
|---|---|---|---|---|
| 스타일 | 2px 라운드 스트로크, 아웃라인 | Thin/Light/Regular/Bold/Fill/Duotone 6종, 듀오톤 | Material Symbols, Rounded·Outlined·Sharp, Fill/Weight/Grade 축 | 2.25px, 3px 반경, 페이지 코너 접힘 |
| 최신 버전 / 게시일 | 3.1.25 / 2026-10-12 ✅ | 2.1.0 / 2024-05-10 ✅ | 4.2960.0 / 2026-07-23 ✅ | — |
| 라이선스 | 패키지 MIT, 아이콘 ISC ✅ | MIT ✅ | Apache-2.0 ✅ | 자체(문제 없음) |
| likes / points | 207 / 160 ✅ | 168 / 55 ✅ | 303 / 130 ✅ | — |
| 플랫폼 태그 | android·ios·web·macos·windows·linux ✅ | **태그 없음 + `has:error`** ✅(원인 ⚠️ 미확인, pubspec 제약 `sdk >=2.12`, `flutter >=1.17`로 해석은 가능) | android·ios·web·macos·windows·linux ✅ | — |
| 굵기 조절 | 파일명 접미사 100~600 ✅(README) | 스타일 enum | 가변 폰트 축 ⚠️ | 고정 |
| 12개 커버 | 11개 직접 + PDF는 `file-text`로 대체 | 11개 + 새 대화는 `note-pencil`로 대체 | 12개 직접(Ask는 `forum` 대체) | 12개 직접 |
| Flutter 적용 난이도 | 낮음: `Icon(LucideIcons.zap)` | 낮음~중: 듀오톤은 `PhosphorIcon(..., duotoneSecondaryColor:)` ⚠️ 추정, 패키지 건강 이슈 | 가장 낮음: 이름이 `Icons.*`와 비슷 | 높음: SVG→아이콘 폰트 변환 또는 `flutter_svg` 에셋, 색·크기 연동 별도 구현 ⚠️ |
| 번들 크기 | 폰트 1개(아이콘 1500+) | 6 스타일 폰트 | 폰트 큼(가변 폰트) ⚠️ 정량 미확인 | 12~20개만 |

Flutter 상수 이름은 npm SVG 파일명을 기준으로 적었다. 패키지 상수는 camelCase(`LucideIcons.messageCircleQuestionMark`/`messageCircleQuestion` 등)이며 **정확한 이름은 `pub get` 후 확인 필요(⚠️)**.

### 4.2 12개 샘플 매핑 (시안 SVG와 동일)

| 의미 | S1 Lucide | S2 Phosphor duotone | Material Symbols Rounded Fill | S3 |
|---|---|---|---|---|
| 노트 | `sticky-note` | `notepad` | `sticky_note_2` | 코너 접힌 페이지 + 줄 |
| 문서/PDF | `file-text` | `file-pdf` | `picture_as_pdf` | 코너 접힌 페이지 + P |
| 프로젝트 | `folder-kanban` | `folders` | `folder_copy` | 폴더 + 줄 |
| 질문/Ask | `message-circle-question-mark` | `chat-teardrop-text` | `forum`(⚠️ `question_answer`는 npm 404) | 말풍선 + ? |
| 새 대화 | `message-square-plus` | `note-pencil`(대체: Phosphor에 chat+plus 없음) | `add_comment` | 열린 말풍선 + + |
| 설정 | `settings` | `gear` | `settings` | 슬라이더 |
| 검색 | `search` | `magnifying-glass` | `search` | 돋보기 |
| 편집 | `pencil` | `pencil-simple-line` | `edit` | 연필 |
| 읽기/미리보기 | `book-open` | `book-open` | `auto_stories` | 펼친 책 |
| 인용 ⚡ | `zap` | `lightning` | `bolt` | 번개 아웃라인 |
| 티어: 클라우드 / 기기 | `cloud` / `smartphone` | `cloud` / `device-mobile` | `cloud` / `mobile-fill`(npm 이름) | 구름 / 폰 |
| 삭제 | `trash-2` | `trash` | `delete` | 휴지통 |

### 4.3 눈 모양 대체: 읽기 | 편집 쌍 토글

세 시안 공통 원칙: **눈 아이콘을 쓰지 않고, 상태가 아니라 "두 모드를 함께 보여주는 세그먼트"**로 바꾼다. 시안 시트 하단에 읽기 선택/편집 선택 두 상태를 그렸다.

| 시안 | 읽기(미리보기) | 편집 | 표현 |
|---|---|---|---|
| S1 | `book-open` | `pencil` | M3 `SegmentedButton` 2칸, 선택 칸 `accentContainer` + 아이콘 `onAccentContainer`, 비선택 `inkMuted` |
| S2 | `book-open`(듀오톤) | `pencil-simple-line`(듀오톤) | 동일. 듀오톤 보조 색은 기본 20% 틴트 유지 |
| S3 | 펼친 책(굵은 선) | 연필 | 동일 |

- 에디터 앱바(모바일 폭이 좁을 때)는 세그먼트 대신 **현재 모드의 아이콘 하나 + 툴팁 "Read"/"Edit"**를 쓰되, 아이콘이 가리키는 것은 **현재 상태**로 통일한다(지금처럼 "다음 모드"를 보여주지 않는다). 데스크톱·태블릿은 항상 세그먼트.
- Cloak(기기 전용) 티어는 눈 대신 `smartphone`(S1/S2/S3) + 라벨 `Cloak`. 클라우드 `cloud`, Shared Vision은 현재 `groups_outlined` → `users`(S1) 유지.

### 4.4 현재 `Icons.*` → 추천 세트(S1 Lucide) 변환표

Lucide 이름은 lucide-static 1.57.0에 존재함을 확인했다(✅). Flutter 상수명은 ⚠️.

| 현재 | 변환 | 현재 | 변환 |
|---|---|---|---|
| `bolt`, `bolt_outlined` | `zap` | `groups_outlined`, `groups` | `users` |
| `sticky_note_2(_outlined)` | `sticky-note` | `group_add_outlined`, `person_add_alt` | `user-plus` |
| `picture_as_pdf_outlined` | `file-text` | `shield_outlined` | `shield` |
| `cloud_outlined` | `cloud` | `visibility_off_outlined`(Cloak) | `smartphone` |
| `settings_outlined` | `settings` | `visibility_outlined`(미리보기) | `book-open` |
| `search` | `search` | `edit_outlined`, `edit_note` | `pencil`, `square-pen` |
| `error_outline`, `sync_problem` | `circle-alert`, `refresh-cw-off` | `logout` | `log-out` |
| `upload_outlined`, `refresh`, `copy_outlined` | `upload`, `refresh-cw`, `copy` | `title` | `heading` |
| `arrow_back`, `arrow_upward` | `arrow-left`, `arrow-up` | `format_quote/list_bulleted/italic/bold`, `code` | `quote`, `list`, `italic`, `bold`, `code` |
| `chevron_left/right`, `keyboard_arrow_down` | `chevron-left/right/down` | `check`, `close`, `add`, `check_box_outlined` | `check`, `x`, `plus`, `square-check` |

## 5. 컴포넌트·반응형 적용

| 컴포넌트 | 아이콘 규칙 |
|---|---|
| 노트/PDF 카드 헤더 | 종류 타일 32(모바일 28, 반경 10, `tile`) 안 아이콘 20(모바일 18), 색 `ink`. PDF 카드는 `file-text`(S1)로 노트와 구분 |
| 인용 칩 `⚡n` | 번개 12, `accent`. 인라인 pill 안에서만 바이올렛 |
| 답변 카드 액션 | 복사/다시 생성/👍 20px, `inkMuted`, 히트 32 |
| 컴포저 | 첨부 `plus` 36 원형, 전송 `arrow-up` 40 원형(입력 시 `accent` 단색) |
| 내비 | 하단 `NavigationBar` 아이콘 24, 활성 = `accent` + indicator `accentContainer`. 사이드바 항목 아이콘 20(행 40) |
| 읽기\|편집 | 4.3 |

| 폭 | 아이콘 | 비고 |
|---|---|---|
| 모바일 <600 | 내비 24, 카드 타일 28/아이콘 18, 에디터 앱바는 모드 아이콘 1개 | 터치 타깃 ≥48 |
| 태블릿 600–1024 | NavigationRail 24, 카드 타일 32/20 | 읽기\|편집 세그먼트 |
| 데스크톱 >1024 | 사이드바 20, 헤더 우측 36 원형 아이콘 버튼, 키보드 힌트 `⌘K` | 세 패널 모두 같은 24 그리드 |

## 6. C. 비교와 추천

| 기준 | P1 Folded Page | P2 Bookmark | P3 Highlight Line |
|---|---|---|---|
| 16px 식별 | 좋음(페이지 실루엣) | 책갈피로만 식별, 번개 소실 | 줄 묶음으로 보여 목록 앱과 혼동 가능 |
| 제품 의미 | 문서 + ⚡ | 출처 점프 | 인용 하이라이트(가장 구체적) |
| 앱 배경 톤과의 연결 | 중간(바이올렛) | 높음(파스텔) | 낮음(잉크) |
| 차별성 | 중간 | 중간 | 높음 |

**앱 아이콘: P1 추천.** 사이드바의 바이올렛 번개 브랜드 마크를 그대로 확장해 일관되고, 16px에서도 유일하게 "페이지 + 번개"가 유지된다. 차별성이 약하다는 점은 약점이므로, 더 개성을 원하면 P3를 고르되 16px 전용 단순판(번개 확대, 줄 2개)을 같이 만든다.

| 기준 | S1 Lucide | S2 Phosphor duotone | S3 커스텀 |
|---|---|---|---|
| 12개 커버(합성 없이) | 11 + PDF 대체 | 11 + 새 대화 대체 | 12 |
| 패키지 상태 | 2026-10-12, 플랫폼 태그 전부 | 2024-05, `has:error` | 해당 없음 |
| 마이그레이션 | `Icons.*` 약 40종 1:1 변환 가능(4.4) | 가능, 단 패키지 불안 | 높음(폰트화) |
| 톤 | 얇은 아웃라인, 글래스 페이퍼에 가장 가볍다 | 따뜻하지만 듀오톤 면이 파스텔 카드와 겹쳐 탁해질 수 있음 | 개성은 높으나 유지 비용 |

**아이콘 세트: S1 Lucide(`lucide_icons_flutter`) 추천.** 최근 게시(2026-10)로 유지되고 굵기 6단계를 제공하며, 현재 `Icons.*_outlined` 중심 UI와 결이 같아 변환표(4.4)가 거의 1:1이다. 번개/책/연필 등 제품 핵심 글리프가 모두 있고 눈 아이콘 없이 읽기|편집 쌍을 만들 수 있다. 약점: PDF 전용 글리프 없음(`file-text`로 노트와 구분이 약함 → 카드 타일 색·라벨로 보완). 최소 변경을 원하면 `material_symbols_icons`(Rounded)가 차선이다.

## 7. Flutter 구현 메모 (⚠️ 코드 미수정, 계획)

- 아이콘 색은 `IconTheme`/`IconThemeData(size: 24, color: ink)`로 한 번에 지정하고, 바이올렛은 ⚡ 위젯에서만 `pb.accent`를 명시한다.
- 교체 비용을 줄이기 위해 `lib/app/icons.dart` 같은 **한 곳의 의미 이름 상수**(`PbIcons.note`, `PbIcons.cite`, `PbIcons.preview` …)를 두고 화면은 `Icons.*`/`LucideIcons.*`를 직접 쓰지 않게 한다. 세트를 바꿔도 이 파일만 고친다.
- `NavigationBar`의 `selectedIcon`은 같은 글리프를 `accent` 색 + 굵기 한 단계 위(`...400`→`...500` ⚠️ 접미사 이름 확인 필요)로 바꾸는 방식이 `Icons.x_outlined`/`Icons.x` 쌍을 대체한다. S2(Phosphor)는 `PhosphorIconsFill`/`Duotone`으로 선택 상태를 표현.
- `SegmentedButton<_Mode>`의 `style`: `selectedBackgroundColor = accentContainer`, `selectedForegroundColor = onAccentContainer`, `side = hairline`, `showSelectedIcon: false`.
- 앱 아이콘 적용은 3.1 표 참조(⚠️ `ios-dark-transparent.png`가 `image_path_ios_dark_transparent`에 맞는지는 실행 전 미확인). `flutter_launcher_icons`는 dev_dependency 추가 + 설정 블록이 필요하며, 이번 작업에서는 추가하지 않았다.

## 8. 한계

- overview의 16/32/48 래스터는 `rsvg-convert`가 해당 픽셀 크기로 렌더한 것이다. 실제 OS 마스크·홈 화면 보정과는 다르다.
- Android 테마 아이콘(monochrome)과 iOS 틴티드는 시안을 만들지 않았다.
- S2 `phosphor_flutter`의 `has:error`는 원인을 확인하지 못했다. 채택 전 `flutter pub get`/빌드 확인이 필요하다.
- S3은 SVG 원본만 있고 폰트/위젯화는 하지 않았다.
- UI 아이콘 시트의 패널·셀 색(`#FFFFFF`/`#F7F2FA`, `#251C27`/`#322838`)과 시트 배경은 시안 표시용 값이며 ab-v2 토큰이 아니다.
