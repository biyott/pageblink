# 018 · 데스크톱(PC) 노트 화면 기본 폰트 크기 조정안

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 09:19 (KST) |
| 담당 | 서브에이전트 (product designer) — 코드 정독 + 패키지 소스(pub.dev 아카이브) 확인. 앱 실행·스크린샷 측정은 하지 않음 |
| 질문 | 데스크톱(>1024px) 노트 화면의 글자 크기·위계·본문 폭을 어떻게 조정하면 읽기 편한가. 현재 값과 원인, 최소 변경 지점 |
| 결론 한 줄 | 문제는 "전체가 작다"가 아니라 **(1) 편집 16px ↔ 미리보기 14px 불일치, (2) 마크다운 제목이 노트 제목보다 크고 h1·h2 위계가 뒤집힘, (3) 본문 폭 제한 없음(1920px에서 1068px), (4) 한글 폴백 폰트명 오류 가능성**이다. 본문 16/1.7 통일 + 680px 컬럼 + 제목 28/24/20/18 위계를 `note_editor_screen.dart` 안에서 로컬로 적용하는 것을 권장 |
| 반영 | 없음 (제안 단계). 채택 시 ADR로 확정 후 구현 |

> 이 문서는 research 규칙(스냅샷, 수정 없이 새 번호로 정정)에 따라 쓴 **디자인 제안 스냅샷**입니다. 채택 여부 판단은 `docs/adr/`에서 합니다.
> 관련: [017](017-flutter-ux-issues-investigation.md)이 다루는 "라이브 마크다운 편집"이 채택되면 편집/미리보기 구분이 사라지므로, 아래 표의 `body`·제목 값은 그 에디터의 스타일에도 그대로 쓴다(구현 지점 #3~#7은 그 위젯으로 이동).
> 표기: ✅ 소스/문서로 확인 · ⚠️ 미확인·추정. 크기는 모두 논리 픽셀(dp, CSS px와 동일하게 취급).

## 핵심 결론

1. **편집 모드와 미리보기 모드의 본문 크기가 다르다.** 본문 `TextField`(`note_editor_screen.dart:211-221`)는 `style`이 없어 M3 기본인 `bodyLarge` = 16/1.5(`theme.dart:180-184`), 미리보기 `GptMarkdown`(`:206`)도 `style`이 없어 주변 `DefaultTextStyle` = `bodyMedium` = 14/1.45(`theme.dart:185-189`)를 상속한다. 미리보기 토글 때마다 글자가 14% 줄어든다. 데스크톱에서 "작다"는 느낌의 가장 직접적인 원인이다.
2. **마크다운 제목이 노트 제목을 압도한다.** gpt_markdown은 h1~h6을 `headlineLarge/Medium/Small, titleLarge/Medium/Small`에 매핑한다(✅ gpt_markdown 1.3.4 `theme.dart:102-107`). 앱 테마는 `headlineLarge`를 덮어쓰지 않아 h1이 Inter 32/w400(⚠️ Flutter 기본 타이포그래피 값, 실행 측정 안 함)으로 나오고, h2는 Fraunces 30, h3은 26이다. h1~h4(32·30·26·22)가 모두 노트 제목(`titleLarge` 22)과 같거나 크다. h1은 얇고(w400) h2는 굵어(w600) 서로 다른 계열이라 위계가 오히려 뒤집힌다. h1 아래에는 자동 구분선도 붙는다(`autoAddDividerLineAfterH1: true`, `theme.dart:112`).
3. **본문 폭 상한이 없다.** 데스크톱 중앙 패널은 `min(1100, W − 716)`px이고(좌우 패딩 48 + 사이드바 240 + 간격 48 + Ask 380), 편집기 좌우 패딩 16이 더해질 뿐 폭 제한이 없다. 1920px 창에서는 1068px 폭에 14px 글자가 들어가 한 줄이 라틴 약 150자, 한글 약 76자가 된다.
4. **기본 폰트 체인에 한글 폴백이 의도대로 걸리지 않을 가능성이 높다 (⚠️→소스상 확인).** `theme.dart:163`의 `'Noto Sans KR'`(공백 포함 문자열)은 google_fonts가 등록하는 패밀리명이 아니다. google_fonts 8.1.0은 `'NotoSansKR_<variant>'` 형식으로 등록한다(✅ `google_fonts_family_with_variant.dart`의 `'${family}_$variant'`, `part_n.dart`의 `fontFamily: 'NotoSansKR'`). 같은 파일의 serif 경로는 `GoogleFonts.notoSerifKr().fontFamily!`로 올바르게 쓰고 있어 sans 쪽만 어긋난다. 그 결과 본문 한글은 Noto Sans KR이 아니라 플랫폼 기본 한글 폰트(⚠️ 웹은 브라우저/CanvasKit 폴백)로 그려질 수 있다.

## 상세

### 1. 현재 값 (file:line)

**폰트 패밀리·TextTheme** — `app/pageblink_flutter/lib/app/theme.dart`

| 위치 | 값 | 비고 |
|---|---|---|
| `:163-166` | 본문 계열 Inter (`GoogleFonts.interTextTheme`), 폴백 `['Noto Sans KR']` | 폴백명 문제 (위 4번) |
| `:167-173` | `serif()` = Fraunces, 기본 w600, height 1.2, 폴백 `notoSerifKr().fontFamily` | 폴백은 regular 변형만 → w600 한글 제목은 가짜 굵기(faux bold) 가능 ⚠️ |
| `:176` `:177` | `headlineMedium` serif 30 · `headlineSmall` serif 26 | |
| `:178` `:179` | `titleLarge` serif 22 · `titleMedium` serif 18 | |
| `:180-184` | `bodyLarge` Inter 16 / 1.5 (+한글 폴백) | 편집 TextField 기본 |
| `:185-189` | `bodyMedium` Inter 14 / 1.45 (+한글 폴백) | 미리보기·사이드바 기본 |
| `:190-193` | `labelLarge` 14 w600 | |
| 미지정 | `headlineLarge` 32/w400, `titleSmall` 14/w500, `bodySmall` 12, `labelMedium` 12, `labelSmall` 11 | Flutter M3 기본값 ⚠️ |
| `:207` | AppBar title serif 22 | |
| `:234` `:239` | Chip label 13 w500 | |
| 없음 | `textScaler`, `visualDensity` 전역 설정, 폰트 크기 설정 UI | 전체 grep 결과 0건. OS/브라우저 텍스트 배율만 반영 |

**노트 편집·미리보기** — `features/notes/note_editor_screen.dart`, `app/pane_header.dart`

| 요소 | 위치 | 실제 크기 |
|---|---|---|
| 상단 헤더 제목 | `pane_header.dart:29,54` (`titleMedium`) | serif 18 / 1.2, 1줄 말줄임, 높이 56 |
| 인용(⚡) 배너 | `note_editor_screen.dart:183` | 스타일 없음 → 14 / 1.45 |
| 노트 제목 입력 | `:193` (`titleLarge`) | serif 22 / 1.2 w600 |
| 본문 입력(편집) | `:211-221` (스타일 없음) | **16 / 1.5** (bodyLarge) |
| 본문 미리보기 | `:206` (`GptMarkdown`, 스타일 없음) | **14 / 1.45** (bodyMedium, Material이 주는 DefaultTextStyle ✅) |
| 좌우 패딩 / 폭 상한 | `:190` `:203` `:210` | 16px / 없음 |
| 서식 툴바 | `:225-273` | 아이콘만, 텍스트 없음 |
| 인용 노트 폴백 | `viewer/page_viewer_screen.dart:106,110` | `bodySmall` 12 / `bodyLarge` 16 |

**마크다운 렌더링 (미리보기, gpt_markdown ^1.3.4 소스 기준 ⚠️ pubspec.lock 없음 → 실제 해석 버전 미확인)**

| 요소 | 크기·폰트 | 근거 |
|---|---|---|
| h1 | Inter 32 / w400 + 아래 구분선 | `theme.dart:102,112` (gpt_markdown) |
| h2 | Fraunces 30 / w600 | `headlineMedium` = 앱 `theme.dart:176` |
| h3 | Fraunces 26 / w600 | `headlineSmall` = `:177` |
| h4 | Fraunces 22 / w600 | `titleLarge` = `:178` |
| h5 | Fraunces 18 / w600 | `titleMedium` = `:179` |
| h6 | Inter 14 / w500 | `titleSmall` 기본값. 본문과 같은 크기 |
| 본문·인용·목록 | 14 / 1.45 상속 (불릿 크기 = 글자의 0.3배) | `shared_render.dart:610` |
| 인라인 코드 | 본문 × 0.94 ≈ 13.2, 패키지 내장 GeistMono | `inline_code.dart:159` ⚠️ GeistMono는 한글 미포함 추정 |
| 코드 블록 | 본문 크기 상속(`fontSize` null), 언어 라벨 11 | `code_block_style.dart:127` |

**노트 목록·카드·사이드바 (데스크톱 노트 탭에서 같이 보이는 것)**

| 요소 | 위치 | 크기 |
|---|---|---|
| 화면 제목 "Notes" | `documents_screen.dart:335` | headlineMedium → 32 (≥600) / 28 |
| 개수 서브텍스트 | `:342` | bodyMedium 14, muted |
| "RECENT" 라벨 | `:386` | 11 / w600 / ls 0.8 |
| 카드 메타(시간·페이지) | `:585` | 12 |
| 카드 제목 | `:598` | titleMedium = serif 18 / w600, 2줄 |
| 카드 미리보기 | `:617` | bodySmall 12 |
| 카드 티어 칩 / 상태 | `:640` `:651` | labelSmall 11 |
| 카드 그리드 | `:467-471` | 최대 셀 280, 높이 250, 간격 16 |
| 사이드바 브랜드 | `main.dart:418` | titleLarge 22 |
| 사이드바 항목 | `main.dart:541` | 크기 미지정 → 14 ⚠️ (w500/w600) |
| 프로젝트 행 제목 / 부제 / 배지 | `main.dart:606` `:614` `:631` | 14 w600 / 12 / **10** |
| 섹션 라벨 | `main.dart:458` | 11 |
| Ask 질문 말풍선 / 답변 | `ask_screen.dart:433` / `:464` | 15 w500 / GptMarkdown 14 (**h1이 380px 패널에서 32**) |

**레이아웃 (현재)**: 데스크톱 판정 `width >= 1024` (`main.dart:286`), 바깥 패딩 24 (`:291`), 사이드바 240 (`:295`), 중앙 `maxWidth: 1100` (`:310`), Ask 380 (`:316`). 태블릿 600~1024는 레일 + 한 화면(`:326~`), 폰은 <600 (`main.dart:238`).

### 2. 문제 진단

| 증상 | 원인 | 확인 |
|---|---|---|
| 미리보기가 작게 느껴짐 | 14px. 편집 16px와 불일치 | ✅ Material이 `bodyMedium`을 DefaultTextStyle로 제공, M3 `TextField`는 `bodyLarge` 사용 |
| 큰 창에서 글이 "가늘고 길게" 느껴짐 | 폭 상한 없음(최대 1068px), 14px 라틴 약 150자/줄 | 계산 (아래 표) |
| 제목과 본문의 위계가 불분명 | 노트 제목 22 < 마크다운 h1 32·h2 30·h3 26. h1만 Inter w400 | ✅ 소스 |
| 사이드/카드 보조 텍스트가 흐림 | 10·11·12px가 다수, `inkMuted`(#6B6358)까지 겹침 | ✅ 값 / 가독성은 ⚠️ 실측 안 함 |
| 모바일 기준값을 그대로 씀 | 편집기에 breakpoint 분기 없음. 모바일 값과 데스크톱 값이 같음 | ✅ grep: 노트 화면에 `MediaQuery`/`LayoutBuilder` 없음 |
| 사용자가 키울 방법 없음 | 설정에 글자 크기 없음, `textScaler` 미사용 → OS 배율만 반영 | ✅ grep |

**중앙 패널 폭과 한 줄 글자 수** (패널 = min(1100, W − 716), 텍스트 폭 = 패널 − 32. 라틴 평균 글자폭 ≈ 0.5em, 한글 ≈ 1em로 추정 ⚠️)

| 창 폭 W | 패널 | 텍스트 폭 | 현재 14px 라틴 / 한글 | 제안 16px(상한 680) 라틴 / 한글 |
|---|---|---|---|---|
| 1024 | 308 | 276 | 39 / 20 | 34 / 17 (너무 좁음, 아래 리스크) |
| 1280 | 564 | 532 | 76 / 38 | 66 / 33 |
| 1440 | 724 | 692 | 99 / 49 | 85 / 42 (상한 680 적용) |
| 1920 | 1100 | 1068 | 152 / 76 | 85 / 42 |

### 3. 제안: 데스크톱 노트 폰트 위계

**원칙**: 본문 글자 크기는 breakpoint와 무관하게 **16px 고정**(모바일 입력 확대 방지 기준이자 데스크톱 장시간 읽기 하한). 데스크톱에서는 글자를 키우는 대신 **줄 높이 1.7과 컬럼 폭 상한 680px**로 읽기 편함을 만든다. 제목류만 breakpoint에 따라 0.86~1.0배로 조정한다.

| 역할 | 모바일 <600 | 태블릿 600–1024 | **데스크톱 >1024** | weight | 계열 |
|---|---|---|---|---|---|
| 노트 제목(편집기 title) | 24 / 1.25 | 26 / 1.25 | **28 / 1.25** | 600 (Noto Serif KR w600 변형 사용) | Fraunces + Noto Serif KR |
| 본문(편집·미리보기 동일) | 16 / 1.65 | 16 / 1.7 | **16 / 1.7** (27.2px) | 400 | Inter + Noto Sans KR |
| h1 | 22 / 1.3 | 24 / 1.3 | **24 / 1.3** | 600 | Fraunces |
| h2 | 19 / 1.35 | 20 / 1.35 | **20 / 1.35** | 600 | Fraunces |
| h3 | 17 / 1.4 | 18 / 1.4 | **18 / 1.4** | 600 | Fraunces |
| h4~h6 | 16 / 1.5 | 16 / 1.5 | **16 / 1.5** | 600 (h6은 muted) | Inter |
| 인용(blockquote) | 16 / 1.7 | 동일 | **16 / 1.7**, 좌측 3px 선 + `inkMuted` | 400 | 본문과 동일 |
| 목록 | 16 / 1.65 | 동일 | **16 / 1.7**, 항목 간격 +4 | 400 | 본문 |
| 코드(인라인/블록) | 14 / 1.6 | 14 / 1.6 | **14 / 1.6** (본문의 0.875배) | 400 | 모노 + 한글 폴백 |
| 캡션·메타(시간, 페이지, 라벨) | 12 / 1.4 | 12 / 1.4 | **12 / 1.4** | 500 | Inter, `inkMuted` |
| 상단 헤더 제목(PaneHeader) | 18 (유지) | 18 | **18** (유지, 높이 56) | 600 | serif |
| 사이드·목록 항목 제목 | 14 / 1.35 | 14 | **14 / 1.35** (활성 w600, 비활성 w500) | | Inter |
| 사이드·목록 보조/배지 | 12 · 11 | 12 · 11 | **12 · 11** (10 → 11) | 500 | Inter |
| 카드 제목 | 18 (유지) | 18 | **18 / 1.3** | 600 | serif |
| 카드 미리보기 | 13 / 1.5 | 13 | **13 / 1.5** (12 → 13) | 400 | Inter |

- **스케일 비율**: 본문·캡션 = 모바일 : 태블릿 : 데스크톱 = 1 : 1 : 1. 제목(title·h1~h3) = 약 0.86~0.92 : 0.96~1.0 : 1.0. 노트 제목 28 > h1 24 > h2 20 > h3 18 > 본문 16로 비율 약 1.17~1.25(Major Third 근사)를 유지해 위계가 뒤집히지 않는다.
- **최소 글자 크기**: 11px 미만 금지(현재 `main.dart:631`의 10px 제거).
- **본문 최대 폭**: **680px** (허용 640~720). 16px에서 라틴 약 85자·한글 약 42자, 한영 혼용 문서는 대략 55~65자/줄. 한글은 글자가 1em 폭이라 "60~75자" 기준을 그대로 쓰면 960px를 넘어 과도하므로 px로 정한다. 컬럼은 패널 안에서 가운데 정렬하고 스크롤바는 패널 가장자리에 둔다. 제목 입력·인용 배너도 같은 컬럼 폭.
- **폰트 패밀리**: 유지 + 수정. (a) 본문 Inter + **Noto Sans KR** (`GoogleFonts.notoSansKr`, w400~700 지원 ✅) — 폴백명만 바로잡는다. (b) 한영 혼용에서 라틴/한글 x-height 차이가 거슬리면 대안으로 **IBM Plex Sans KR**(라틴·한글 한 패밀리), **Gothic A1**, Nanum Gothic이 `google_fonts`에 있다 ✅. (c) **Pretendard는 google_fonts 8.1.0에 없다** ✅(소스 grep). 쓰려면 assets 번들이 필요하며 라이선스·용량은 별도 확인 ⚠️. 지금은 도입하지 않는다. (d) 코드는 gpt_markdown 내장 GeistMono가 한글을 갖지 않을 것으로 추정되므로 `fontFamilyFallback`에 Noto Sans KR을 추가하거나 `GoogleFonts.jetBrainsMono`/`ibmPlexMono`로 교체. (e) serif 한글 제목은 `notoSerifKr(fontWeight: …)`로 같은 굵기 변형을 폴백에 쓴다.
- **글자 크기 슬라이더**: **지금은 불필요**. 이유: 본문이 이미 16px이고 OS 텍스트 배율이 반영되며, 데스크톱 웹은 브라우저 줌(Ctrl/⌘ +/-)이 있다. 다만 macOS/Windows 네이티브 앱에는 줌이 없고 Flutter 웹이 브라우저의 기본 글자 크기 설정을 따르는지는 ⚠️ 미확인이다. 요구가 생기면 `settings_screen.dart`의 언어 `RadioListTile` 옆에 **3단 `SegmentedButton`(작게 0.9 / 보통 1.0 / 크게 1.15)**을 두고, 노트 편집기 영역에만 `MediaQuery.copyWith(textScaler: TextScaler.linear(s))`로 적용하며 `locale_controller.dart` 방식으로 저장한다. 연속 슬라이더는 위계 비율 검증 비용 때문에 권하지 않는다.

### 4. 구현 노트 (최소 변경)

원칙: **전역 `TextTheme`을 키우지 않는다.** 전역을 바꾸면 사이드바·카드·Ask·AppBar까지 같이 변해 범위가 커진다. 노트 화면 안에서만 로컬 스타일을 준다. (코드 수정은 이 작업에서 하지 않았다.)

| # | 파일·위치 | 변경 | 비고 |
|---|---|---|---|
| 1 | `app/theme.dart:163` | `const sansFallback = ['Noto Sans KR']` → `final sansFallback = [GoogleFonts.notoSansKr().fontFamily!]` | `:173`의 serif 방식과 동일. 폰트 다운로드가 늘어남(⚠️ 크기 미측정) |
| 2 | `app/theme.dart:167-173` | serif 폴백을 `GoogleFonts.notoSerifKr(fontWeight: weight).fontFamily!`로 | w600 한글 제목의 faux bold 방지 ⚠️ |
| 3 | `features/notes/note_editor_screen.dart` | 파일 안에 작은 헬퍼 추가: `final w = MediaQuery.sizeOf(context).width;` `w < 600 / w < 1024 / else`로 위 표의 title·body·h1~h3·code 값을 고르는 record 한 개 | breakpoint 판별은 기존 방식 재사용: `MediaQuery.sizeOf(context).width >= 1024` (`ask_screen.dart:144`), `< 600` (`ask_screen.dart:125`, `main.dart:238`), `>= 600` (`documents_screen.dart:402`). 새 상수 체계를 만들지 않는다. `OpenItemController.wide`는 ≥600 의미이므로 데스크톱 판별에 쓰지 않는다 |
| 4 | 같은 파일 `:193` | 제목 `style:`을 표의 title 값으로 | |
| 5 | 같은 파일 `:211-221` | 본문 `TextField`에 `style: body` 명시 (16 / 1.7) | 편집·미리보기가 같은 `body`를 공유 → 불일치 해소 |
| 6 | 같은 파일 `:206` | `GptMarkdown(_body.text, style: body)`를 `GptMarkdownTheme(gptThemeData: GptMarkdownThemeData(brightness: …, h1: …, h2: …, h3: …, h4: …, h5: …, h6: …))`로 감싼다 | ✅ `GptMarkdownTheme.of`는 InheritedWidget → ThemeData 확장 → 기본값 순으로 해석(`theme.dart:275-286`)하므로 로컬 래퍼가 우선. 팩토리는 지정하지 않은 필드를 기본값으로 채운다(`:23-60`). h1 구분선은 `autoAddDividerLineAfterH1: false` 권장(노트 제목과 중복) |
| 7 | 같은 파일 `:189-223` | 제목·본문을 `Align(topCenter) + ConstrainedBox(maxWidth: 680)`로 감싼다. 스크롤 영역은 전체 폭 유지 | 폭 상한은 데스크톱 폭에서만 의미 있음. 모바일·태블릿 패널은 680보다 좁아 영향 없음 |
| 8 | `features/open_item/open_item_view.dart`, `app/pane_header.dart` | 변경 없음 | 헤더 18/56 유지 |
| 9 | (선택) `app/theme.dart:200` `extensions: [pb]` | `GptMarkdownThemeData`를 추가해 **Ask 답변 말풍선**의 h1~h3을 20/18/16로 낮춤 | Ask 패널 380px에서 h1 32가 나오는 문제. 로컬 래퍼(#6)가 노트에서는 우선하므로 충돌 없음 |
| 10 | (선택) `main.dart:631`, `documents_screen.dart:617` | 배지 10 → 11, 카드 미리보기 12 → 13 | 사이드·카드 소형 텍스트 정리 |

`ColorScheme`·색 토큰(`Pb`)은 건드리지 않는다. `useMaterial3: true`는 이미 켜져 있다(`theme.dart:197`). M3 `TextField`·`SegmentedButton`·`MediaQuery.textScaler`만 사용하므로 모두 Flutter Material 3 범위다.

## 미확인 · 리스크

- ⚠️ **실행·스크린샷 측정을 하지 않았다.** 모든 크기는 소스상의 값이고, Hangul/Latin 글자 수는 평균 글자폭 추정이다. 구현 후 1280·1440·1920 폭에서 한영 혼용 샘플로 확인이 필요하다.
- ⚠️ `pubspec.lock`이 없어 gpt_markdown 실제 해석 버전을 확인하지 못했다. 분석은 `pubspec.yaml`의 `^1.3.4`가 가리키는 1.3.4 아카이브(pub.dev) 기준이다. 코드 블록·인용문의 세부 스타일은 소스에서 일부만 확인했다.
- ⚠️ Flutter 기본 M3 타이포그래피(`headlineLarge` 32/w400 등)는 Flutter 문서 값이며 이 앱에서 렌더링해 측정하지 않았다.
- ⚠️ **1024~1180px에서 중앙 패널이 308~480px로 너무 좁다**(사이드바 240 + Ask 380 고정). 글자 크기로 풀 수 없는 레이아웃 문제다. 후속 과제로 "1180px 미만에서 Ask 패널을 접기" 또는 "노트를 열면 Ask 패널을 접기"를 검토할 것. 이 문서의 폰트 제안은 그대로 유효하다.
- ⚠️ Noto Sans KR/Serif KR을 google_fonts로 받으면 런타임 다운로드가 늘어난다. 오프라인·Cloak(기기 전용) 모드에서 폰트 로딩 실패 시 시스템 폴백으로 내려간다. 필요하면 assets 번들을 검토한다.
- ⚠️ Flutter 웹이 브라우저의 기본 글자 크기 설정을 따르는지는 확인하지 못했다.

## 출처

- gpt_markdown 1.3.4 소스 (pub.dev 아카이브): https://pub.dev/api/archives/gpt_markdown-1.3.4.tar.gz — `lib/theme.dart`, `lib/shared_render.dart`, `lib/custom_widgets/inline_code.dart`, `lib/styles/code_block_style.dart`, `lib/md_widget.dart`
- google_fonts 8.1.0 소스 (pub.dev 아카이브): https://pub.dev/api/archives/google_fonts-8.1.0.tar.gz — `lib/src/google_fonts_base.dart`, `google_fonts_family_with_variant.dart`, `google_fonts_parts/part_n.dart`
- gpt_markdown 패키지: https://pub.dev/packages/gpt_markdown
- google_fonts 패키지: https://pub.dev/packages/google_fonts
- Flutter `TextTheme` (M3 기본 스케일): https://api.flutter.dev/flutter/material/TextTheme-class.html
- Flutter `Material` (DefaultTextStyle = bodyMedium): https://api.flutter.dev/flutter/material/Material-class.html
- Flutter `TextField` / `MediaQueryData.textScaler`: https://api.flutter.dev/flutter/material/TextField-class.html · https://api.flutter.dev/flutter/widgets/MediaQueryData/textScaler.html
- Noto Sans KR: https://fonts.google.com/specimen/Noto+Sans+KR
- 앱 소스 (이 저장소): `app/pageblink_flutter/lib/app/theme.dart`, `main.dart`, `features/notes/note_editor_screen.dart`, `features/documents/documents_screen.dart`, `features/ask/ask_screen.dart`, `app/pane_header.dart`
