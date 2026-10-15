# 🎨 UI polish(UP-01~UP-22) 현황 감사와 남은 일 계획

> **작성일**: 2026-10-15 16:17 KST · **최종 수정**: 2026-10-15 16:17 KST
> **관련 문서**: [UI polish 명세](../design/ui-polish/spec.md) · [인수인계 (012)](012-session-handoff.md) · [업로드 DnD·재색인 명세](../design/upload-dnd-reindex/spec.md) · [출처 UI v2 명세](../design/ask-sources-v2/spec.md) · [편집기 여백 명세](../design/note-editor-spacing/spec.md) · [ADR 018 (Pretendard)](../adr/018-body-font-pretendard-single-family.md) · [ADR 019 (PDF 드롭)](../adr/019-pdf-drag-drop-desktop-drop-shell-web-first.md) · [`AGENTS.md`](../../AGENTS.md)
> **표기**: ✅ 확인 · ⚠️ 미확인/추정 (사실 표기, README 규칙). **상태 열 전용**: ✅ 완료 · 🟡 부분 · ⬜ 미착수 · ⛔ 보류/대체
> **용도**: 세션을 닫았다 다시 열어도 UI polish를 이어갈 수 있게, **코드를 직접 보고** 판정한 현황과 재정렬한 실행 순서를 남깁니다. 코드·서버·DB는 이 작업에서 수정하지 않았습니다(문서만). 판정은 §7 명령으로 1분 안에 다시 확인할 수 있습니다.

---

## 0. 한눈에 보기

| 상태 | 항목 |
|---|---|
| ✅ 완료 (1) | UP-01 |
| 🟡 부분 (4) | UP-02(화면별 리터럴 잔여) · UP-06(폰 AppBar만) · UP-16(다크 노트·glassStrong만) · UP-18(sticky 없음) |
| ⬜ 미착수 (15) | UP-03 · 04 · 05 · 08 · 09 · 10 · 11 · 12 · 13 · 14 · 15 · 17 · 19 · 20 · 21 |
| ⛔ 보류/대체 (2) | UP-07(재색인 UX로 대체) · UP-22(클라이언트 결정 전 금지) |

> 합계 ✅ 1 + 🟡 4 + ⬜ 15 + ⛔ 2 = **22**. 줄별 근거는 §2.

| 항목 | 값 |
|---|---|
| 기준 커밋 | `1cd31ba` (main = origin/main) ✅ |
| 작업 트리 | 사용자 개인 수정 `README.md`, `README.ko.md`, `docs/reference/002-run-locally.md`만 (건드리지 말 것) ✅ |
| 명세 | `docs/design/ui-polish/spec.md` (14:13 작성, 14:18 커밋 `4e66c79`) |
| 테스트 | 이 감사에서 `flutter test`는 다시 돌리지 않음. 012 기록은 1,106개 통과(`5a2b7d9`) ⚠️ 그 이후 코드 변경 없음 |
| 다음 한 걸음 | §4 묶음 A (보드 카드·헤더: UP-03 → UP-05 → UP-02 잔여) |

---

## 1. 감사 방법과 이 문서가 바로잡는 것

### 1-1. 방법

- 각 UP-nn을 spec §4 표의 "제안" 문장 기준으로 `app/pageblink_flutter/lib`의 코드와 `git log`에서 직접 확인했습니다. 렌더(스크린샷)·실기기 확인은 하지 않았습니다 → 시각 판정이 필요한 곳은 ⚠️로 표시했습니다.
- UP 작업이 들어간 커밋은 **`7612e3e` 하나**입니다. 제목이 "PDF upload service … + UI polish 1 (type scale, inkMuted, Korean keep-all, brand star)" 로 UP-02·UP-01·UP-06(폰 AppBar)·UP-16(일부)을 PDF 업로드 서비스와 한 커밋에 담았습니다 ✅ (`git show --stat 7612e3e`).
- 그 뒤 커밋 `81a34ba`(드롭·재색인 UX, 사이드바 브랜드 크기, `계층`→`저장 공간`)가 `documents_screen.dart`를 크게 바꿨지만 UP 항목 구현이 아니라 **UP-07을 대체**하는 작업입니다(§2의 UP-07).

### 1-2. 명세 §0·§10의 전제가 이제 틀립니다 (순서에 영향)

| 명세의 전제 | 현재 |
|---|---|
| "다른 에이전트가 Pretendard 작업을 진행 중(uncommitted) → UP-02는 그 머지 뒤" | ✅ 이미 머지됨(`a954276`). `pbSansFamily = 'PretendardSubset'`, 400/500/600 |
| "`ask_screen.dart`·`ask_sources.dart`·`notes/*`는 다른 에이전트가 작업 중 → UP-10/18은 그 뒤" | ✅ 작업 트리가 깨끗함. 해당 작업은 출처 UI v2(`a46b5c5`, `0e47987`)로 이미 커밋됨. **대기 사유 소멸** |
| 캡처 기준 "HEAD = `df73b98`" | 이후 커밋 12개 이상이 UI를 바꿈. 명세의 "현재 모습" 서술(예: `_FailedBlock` overflow, 배너, 5색 다크)은 **상당 부분 낡음** → 항목별 판정은 §2를 따를 것 |

### 1-3. 012의 ⑤ 줄이 틀린 곳 (→ 012를 이 문서를 가리키게 수정함)

012 §3 ⑤는 "UI polish 잔여 UP-03/04/05/08/09/10/11 · 미착수"였습니다 (⚠️ 기억 기반, 검증 안 됨). 코드와 대조하면:

| 012의 서술 | 실제 |
|---|---|
| 나열한 7개(03·04·05·08·09·10·11) | ✅ 7개 모두 실제로 ⬜. 틀리지 않았지만 **전체의 일부** |
| 나열에서 빠진 항목 | **UP-06(🟡) · 12 · 13 · 14 · 15 · 17 · 19 · 20 · 21(⬜) · UP-02 잔여(🟡) · UP-16 잔여(🟡) · UP-18(🟡)** 이 목록에 없음 → 새 세션이 "7개만 남았다"고 오해할 수 있음 |
| "UI polish 잔여" = 이미 끝난 것이 없는 듯한 서술 | **UP-01(keep-all)·UP-02(타입 스케일) 대부분은 이미 배포됨**(`7612e3e`, 4차 배포 이후). 012에 "끝난 UP" 기록이 없었음 |
| "UP-07은 superseded" | ✅ 맞음. 근거 보강: ADR 019 결과 절, `upload-dnd-reindex/spec.md` §6 |
| 22 → 항목 수 | UP-22는 ⛔(결정 대기)로 "남은 일"이 아니라 "묻는 일" |

---

## 2. 항목별 판정 (22건)

비용·효과는 spec §4 값 그대로입니다(S ≤ 0.5일 / M 1~2일 / L 3일+). 파일은 `app/pageblink_flutter/lib/` 기준. 줄 번호는 기준 커밋 `1cd31ba` 값입니다.

| ID | 항목 | 상태 | 근거 (파일:줄 / 심볼 / 커밋) | 남은 일 | 효과 | 비용 | 의존·위험 |
|---|---|---|---|---|---|---|---|
| UP-01 | 한글 keep-all | ✅ | `app/text_wrap.dart` `keepAllKorean()`(U+2060, 멱등), `app/l10n.dart:30` `_k()`가 정적 긴 문구 38곳에 적용, `ask_screen.dart:1145` 제안 카드 표시 시에만 적용(서버 전송 문자열은 원본 유지), 테스트 `test/ui_polish_text_test.dart`(조인 규칙·렌더 줄바꿈), 커밋 `7612e3e` | **의도적 축소**: 카드 제목·미리보기(사용자 콘텐츠)는 적용 안 함 — `text_wrap.dart` 주석이 "사용자 콘텐츠·텍스트 필드·마크다운 답변·서버 전송 문자열 제외"로 못 박음(spec §11과 일치). 결정이 아니라 범위 | 상 | S | ⚠️ **웹 CanvasKit에서 U+2060이 실제로 줄바꿈을 막는지 실기 미확인**(spec §12, 데스크톱 `flutter test`만 확인). ⚠️ `l10n.dart`는 `_t` 197곳 / `_k` 38곳 — 중간 길이 문장(예: `askEmptyTitle`, `l10n.dart:384`)이 `_t`로 남음, 좁은 폭에서 어절 중간 줄바꿈 가능 |
| UP-02 | 타입 스케일·`inkMuted` | 🟡 | `app/theme.dart:226~`: `role()`로 자간 0, `bodyMedium` 15/1.6, `bodySmall` 12 w500, `labelSmall` 12 w600, `headlineMedium` 32/1.25/−0.3; `Pb.light.inkMuted 0xFF5C5348`, `Pb.dark.inkMuted 0xFFB5AD9F`; `subInkFor` grep 0건(우회 제거됨); 테스트 `ui_polish_text_test.dart`(대비 ≥4.5, 역할값). 커밋 `7612e3e` | **화면별 리터럴 잔여**(아래 별표): `main.dart:563` 사이드바 `저장 공간` 라벨 11 / w600 / +0.8, `documents_screen.dart:386` `최근` 11 / +0.8 — 둘 다 한글에 +0.8로 spec 규칙 (3) 위반(한글 0, 라틴 대문자만 +0.4, 크기 12). `ask_screen.dart:349`(면책 11, spec 12 w500), `:376`(모델 노트 11, spec 12), `:491`(Free 배지 10.5, spec 11 w600), `viewer/citation_sheet.dart:89~91`(11 / +0.8), `documents/upload_tray.dart:289`(11 / w400, 규칙 (2) 위반) | 상 | S | 한 번에 `grep`으로 정리 가능. `main.dart:742`(10 / +0.6)는 Cloak 행 숨김으로 **죽은 코드**. `note_editor_screen.dart:1198·1376`의 11px는 편집기 코드 블록 라벨 → **research 018/024 소관, UP 범위 밖**. `ask_sources.dart:978`(`SOURCES` 헤더 +0.8)은 출처 스펙 소관. ⚠️ ADR 018이 말한 "B 튜닝안(≤13 w500, `inkMuted` #5E564B)"은 적용되지 않았고 `#5C5348`(spec)이 적용됨 — 문서 간 값 차이만 주의 |
| UP-03 | 노트/PDF 카드 정보량 | ⬜ | `documents_screen.dart:574` 개인 노트도 `l.myCloud` 칩, `:708` 칩 항상 렌더; `:583` 메타 `l.noteMeta(ago)`(`노트 · 2분 전`, `l10n.dart:512`); `:588~590` 미리보기 `TextOverflow.fade`만, `maxLines`·`ShaderMask` 없음; `:613` 외곽선 `ink 10%`; `Pb`에 `noteHighlight` 토큰 없음(grep 0건) | 칩은 프로젝트 문서만, 메타는 시간/쪽수만, 미리보기 `maxLines` + 하단 페이드, 외곽선 → `noteHighlight`(흰 60%·다크 10%) | 상 | S | `upload-dnd-reindex` 명세가 이 항목을 **전제**로 상태 줄 위치를 정함(칩 없으면 카드 안쪽 아래 14) → 먼저 하면 상태 줄 배치가 명세대로 됨. 테스트 영향: `test`에서 카드 칩/메타 문자열을 단언하는 곳을 찾지 못함 ✅ (`documents_upload_test.dart:73`의 `'My cloud'`는 대상 선택 시트의 항목). 개인/공유 구분이 사라지는 문제 → 사이드바 티어 카운트로 보완(spec) |
| UP-04 | 컴포넌트 테마·포커스 링 | ⬜ | `theme.dart`에 `filledButtonTheme`(r14)만 있음. `outlinedButtonTheme`·`textButtonTheme`·`dialogTheme`·`bottomSheetTheme`·`popupMenuTheme`·`snackBarTheme` 없음; `GlassPanel`(`theme.dart:396`)에 `blur` 옵션 없음; 카드·`_NavItem`에 포커스 링 없음 | spec §4 UP-04 전부 | 중 | S | `filledButtonTheme` r14는 `af03088`(최초 테마)부터 있어 **진척으로 세지 않음**. `showDialog`(`documents_screen.dart`, `projects_screen.dart`)가 기본 M3 면을 쓰므로 `dialogTheme` 후 모든 다이얼로그 확인 필요. `upload-dnd-reindex`도 `snackBarTheme`·포커스 링을 채택 항목으로 요구 |
| UP-05 | 보드 헤더·필터 칩 | ⬜ | `documents_screen.dart:366` 칩 `Wrap`(폰에서 두 줄), `:305~310` 검색 필드 `border` r16 오버라이드(pill 아님), `:376` 칩↔섹션 라벨 간격 8, `:384` 섹션 라벨 11/+0.8, 칩 라벨에 카운트가 같은 문자열(`'$label $n'`, `:289`) | 칩 한 줄 가로 스크롤, 카운트 보조색, 섹션 라벨 아래 12, 검색 pill 통일 | 중 | S | 같은 파일 UP-03과 충돌 → 같은 묶음에서 직렬로 |
| UP-06 | 브랜드 마크 | 🟡 | ✅ 폰 AppBar: `main.dart:255~269` `AppIcons.brand` 별 + `PageBlink` (커밋 `7612e3e`). ⬜ 정적 문자열의 ⚡ 문자: `l10n.dart:386~387` `askEmptySubtitle`, `:440~441` `landingFeatureCiteBody`, `:607~608` `aiDisclaimer`; `note_editor_screen.dart:1095` `'⚡ “…”'`(하이라이트 배너) | 정적 ⚡를 `Text.rich` + 작은 `CiteMarker` 변형으로. `{bolt}` 치환자 도입 | 중 | S | `ask_screen.dart`와 같은 묶음(D). 로그인 화면 `screens/sign_in_screen.dart:433 '⚡ PageBlink'`·`:689~690` 칩은 **제3의 브랜드 표기**지만 로그인 레이아웃은 spec §0 "뒤집지 않는 목록"(`login-layout`) → ⚠️ **결정 필요**(§3), 작업 항목 아님 |
| UP-07 | 경고 배너·실패 블록 | ⛔ | **재색인 UX로 대체**됨. 근거: ADR 019 결과 절("UP-07은 upload-dnd-reindex 스펙이 대체"), `upload-dnd-reindex/spec.md` §6 "대체: UP-07 … 배너를 줄 링크로 대체하고 `_FailedBlock`을 삭제". 코드: `git show 81a34ba`에서 `MaterialBanner`·`_FailedBlock` 삭제 확인, 현재 `grep -rn _FailedBlock lib` 0건, `documents_screen.dart:888` `_InlineLink`가 shrinkWrap(주석에 UP-07), 상태 줄 `index_status.dart`, 사용자에게는 고정 문구만 노출(`l10n.dart:336~371` 매핑 + `debugPrint`) | 없음. `warnTint` 토큰은 코드에서 미사용(`theme.dart`에만 있음) — 정리는 선택 | – | – | 되살리지 말 것. spec §4 UP-07의 `warnTint` 타일 안은 폐기 |
| UP-08 | 모션(미세) | ⬜ | `main.dart:223` `_withPane`은 `Offstage`(`:231`) + 즉시 교체, 보드에 `AnimatedSwitcher`·호버·눌림 없음(`grep AnimatedSwitcher\|onHover lib` → 보드/pane 관련 0건; 있는 모션은 드롭 존·트레이·출처 효과·편집기뿐). `disableAnimations` 처리는 각 위젯이 개별로 함 | spec §6의 4종(pane 진입, 카드 호버/눌림, 필터 전환, 카드 등장) | 중 | S | `documents_screen.dart`·`main.dart`·`open_item_view.dart` 3파일. 카드 등장은 `_FlashRing`(업로드 직후 링)과 겹치지 않게 "신규 id만"(spec). `upload-dnd-reindex`가 카드 등장 모션(200ms, UP-08과 동일)을 채택 항목으로 지정 |
| UP-09 | 데스크톱 1024~1279 레이아웃 | ⬜ | `main.dart:375` `width >= 1024`면 사이드바 `SizedBox(width: 240)`(`:384`), Ask `SizedBox(width: 380)`(`:408`) 고정; 레일 위젯·Ask 접힘 상태 없음(`lib/app`에 `side_rail.dart` 없음). 600~1023은 기존 `NavigationRail` | spec §7 폭 규칙(레일 72 < 1280, Ask 320 < 1180, 노트 열림 + < 1440이면 Ask 64px 띠) | 상 | M | `main.dart` 레이아웃 전면. 위젯 테스트의 레이아웃 가정(1280 이상 폭) 확인. Ask 접힘 시 키보드 포커스 이동. 업로드 DnD 명세는 pane 폭에 비례하지 않아 영향 없음(upload-dnd-reindex 명세 §5) |
| UP-10 | 질문 빈 상태·컴포저 | ⬜ | `ask_screen.dart:216` 헤더 `AppIcons.ask` 26 + `:1078` 빈 상태 `AppIcons.ask` 44(중복); `:1098` 제안 카드 8장(`sampleSuggestions` 4 + `askSuggestions` 4, `ask_suggestions.dart:20`); 컴포저 3행(`_ScopeButton` `:269` / 입력 + `IconButton.filled` `:312` / `_ModelPill` `:332`); 비활성 전송 `disabledBackgroundColor: pb.hairline`(`:322`) | spec 시안 ④: 엠블럼 1개, 안내문에 실제 알약, 제안 3개 + 더 보기, 컴포저 2행, 비활성 전송 `accentContainer` | 상 | M | `ask_screen.dart`를 UP-06/11/14/18과 공유 → 직렬. spec은 "기존 테스트가 `TextField`·전송 버튼을 찾음"이라 했으나 ✅ 현재 Ask 컴포저를 직접 찾는 테스트는 확인되지 않음(`grep -ln 'TextField' test/*.dart` 결과에 ask 관련 파일 없음) — 그래도 새 컴포저에는 `Key`를 부여. 제안 문자열은 서버로 그대로 가야 함(`keepAll`은 표시 시점만, `AskEmptyHint`는 `@visibleForTesting`) |
| UP-11 | 첫 실행 보드 | ⬜ | 환영 카드·`welcome_card.dart` 없음; `isSampleTitle`(`ask_suggestions.dart:9`)은 제안 정렬에만 쓰이고 카드 "샘플" 배지·"이 노트로 질문해 보기" 없음; `shared_preferences`는 의존성에 있음(`pubspec.yaml:47`) | spec 시안 ⑤ 전체 | 상 | M | 컴포저 채움 콜백이 UP-10과 같은 파일 → UP-10 뒤. 샘플 노트 제목 접두 규칙 재사용(ADR/서버 `SampleNote`와 동기) |
| UP-12 | 프로젝트 화면 | ⬜ | `features/projects/projects_screen.dart:193` 맨 `ListTile`, 빈 목록 `Text(l.projectsEmpty)`만(`:187`); 제목·카드·수 표시 없음 | spec §4 UP-12 | 중 | M | 멤버 수는 리스트에 없음 → 1차는 노트/PDF 수만(`projectStats`는 삭제 시에만 호출 중). `app/states.dart`(UP-14)의 `EmptyState` 선행 |
| UP-13 | 설정 화면 | ⬜ | `features/settings/settings_screen.dart:55~` 라디오 3개 + `Divider` + 로그아웃 `ListTile`, 그룹 카드 없음 | 그룹 카드 2개, 세그먼트 버튼 | 하 | S | 로그아웃이 UP-17에서 설정 안으로 이동 → **UP-17과 같이** 하면 중복 작업 없음 |
| UP-14 | 로딩·빈·오류 상태 | ⬜ | `app/states.dart` 없음; 보드 로딩 `CircularProgressIndicator`(`documents_screen.dart:467`), 빈/무결과 `_Message`(`:468~470`, 정의 `:1083`), 목록 오류 `_error = '$e'`(`:98`) → `_Message(_error!)` **원시 예외 문자열**; 답변 대기 `LinearProgressIndicator`(`ask_screen.dart:965`). 카드 안 `_Skeleton`(`:997`)은 PDF 색인 중 전용이라 `PbSkeleton`이 아님 | `PbSkeleton`·`EmptyState`·`ErrorState` | 중 | M | `skeleton*` 토큰(spec §8) 신규. 시머 `disableAnimations`에서 정지. `_error` 원문 노출은 UP-14에서 해소(사용자 문구 + 접힌 상세) |
| UP-15 | PDF 카드 | ⬜ | `documents_screen.dart:603` PDF가 `ready`일 때 본문 `SizedBox.shrink()` → 큰 빈 칸. 썸네일·쪽수 알약 없음 | 1단계: 종이 일러스트 + 쪽수 알약. 2단계(L) 썸네일은 보류 | 중 | S(1단계) / L(2단계) | UP-03과 같은 카드 코드 → UP-03 뒤. 2단계는 웹에서 원본 PDF가 없을 수 있어 불가(spec) → 1단계로 충분 |
| UP-16 | 다크 팔레트 | 🟡 | ✅ `theme.dart` 다크 `notes` 5색이 spec §8 값(`463E22 223A2E 47302A 22364A 342C58`)과 일치, `glassStrong 0x24FFFFFF`(14%) — 커밋 `7612e3e`. ⬜ 다크 `pdfPaper`는 아직 `0xFF2A2620`(spec `#2B2733`). `noteHighlight`·`skeleton*` 토큰 없음 | `pdfPaper` 다크 값 변경(+ `noteHighlight`는 UP-03, `skeleton*`는 UP-14와 함께) | 중 | S~M | ⚠️ 색감은 계산상 대비만 확인, **실기 눈 확인이 아직 안 됨**(spec §8·§12). 출처 행이 노트 색을 그대로 쓰므로 `ask-sources-v2` 다크 값과 함께 점검 |
| UP-17 | 폰 헤더·FAB | ⬜ | `main.dart:271~280` AppBar에 설정 + 로그아웃 아이콘 나란히; `documents_screen.dart:442~449` FAB 2개(작은 PDF + 확장 새 노트); `main.dart:341` 업로드 트레이 위치 `bottom: _tab == 1 && !deep ? 136 : 12` (FAB 2개 가정) | 화면별 헤더, FAB 단일 `+`, 로그아웃은 설정 안으로 | 중 | M | **FAB 구조를 바꾸면 `main.dart:341`의 136 오프셋(주석 `ponytail: clears the Notes tab's two FABs`)을 같이 바꿔야 함** — 안 하면 트레이가 FAB와 겹침/떠 있음. 뒤로가기 `PopScope` 흐름 유지. UP-13과 함께 |
| UP-18 | 답변 본문·질문 말풍선 | 🟡 | ⚠️ 답변 본문: `ask_screen.dart:987` `GptMarkdown`에 스타일 인자 없음 → gpt_markdown 1.3.4가 `DefaultTextStyle.of(context)`를 상속(패키지 소스 확인)하고, 주변 Material의 `bodyMedium`은 테마상 15/1.6(`theme.dart`) → **15/1.6일 것으로 추정**, 렌더 측정은 안 함. 질문 말풍선은 `:956` `fontSize: 15, w500` 하드코딩 → 본문 ≥ 질문 역전은 해소됐을 가능성. ⬜ sticky 질문/완료 시 스크롤 없음(`ListView.builder`만, `SliverPersistentHeader` 없음) | sticky 질문(또는 답변 완료 시 질문 위치로 스크롤) | 중 | S~M | `ask_screen.dart` 직렬(묶음 D). 길이 큰 답변에서 폰 `ask-dark` 캡처로 확인 필요 |
| UP-19 | 사이드바 정보 밀도 | ⬜ | `main.dart:533` 태그라인 상시, `_TierRow`가 부제 상시(`:573~:721`), 키보드 힌트·`⌘K` 없음 | spec §4 UP-19 | 하 | S~M | `main.dart` 직렬. 클라이언트 피드백(`저장 공간` 문구·Cloak 숨김)은 이미 반영됨 → 이 항목은 그 위에서 진행. 라벨 타이포는 UP-02 잔여와 같은 줄 |
| UP-20 | 아이콘 규칙 | ⬜ | `app/app_icons.dart` 상단 주석에 크기·굵기 표 없음(브랜드·선택 변형 설명만) | 주석 + 화면별 size 정리 | 하 | S | 선택 항목. 큰 작업 뒤 마무리로 |
| UP-21 | 카드 그리드 | ⬜ | `documents_screen.dart:486` `mainAxisExtent: 250` 고정 | 높이 3단계 커스텀 `SliverGridDelegate` | 중 | M | **선택**. `upload-dnd-reindex`는 상태 줄이 카드 하단 고정이라 3단계와 호환(§6). 외부 masonry 패키지 금지(spec §11). 스크롤 성능 확인 |
| UP-22 | 보라 예산 | ⛔ | `main.dart:611` `_NavItem`(`:633`): 활성 = `scheme.primary` 채움 그대로. spec §4: "**AB v2 §3.2 '활성 = 풀폭 accent 단색 pill' 결정을 뒤집는 것 → 클라이언트 확인 전에는 하지 않는다**", §11: "AB v2의 사이드바 활성 pill을 임의로 낮추지 않는다(UP-22는 클라이언트 확인 후)" | **클라이언트에게 묻기** (§3) | 중 | S | 구현 비용은 작지만 결정 사항. 확인 전 코드 변경 금지 |

> 별표 — UP-02 잔여 리터럴 목록은 `grep -rnE 'fontSize: *(9|10|10\.5|11|11\.5)\b' lib`와 `grep -rnE 'letterSpacing: *[0-9.-]+' lib`로 뽑은 것입니다(§7).

---

## 3. 이미 반영된 클라이언트 피드백과 결정 대기

### 3-1. 반영 완료 (UP 항목이 아니라 별도 커밋)

| 클라이언트 피드백 | 상태 | 근거 |
|---|---|---|
| 노트 편집기 영역 구분선·툴바 띠 | ✅ | `6584613` 툴바 아래 전폭 선, `ec0b196` 편집기 여백(패딩 누수 제거·툴바 아래 24px·말단 공기 64/96/120) |
| 출처 칩 = 사이드바 타일 톤(8% 잉크) | ✅ | `0e47987`(인용 마커 알약 = 티어 타일 톤, 어두운 숫자 + 윤곽 번개), 그 앞 `a46b5c5` 출처 v2 |
| 사이드바 `계층` → `저장 공간` | ✅ | `81a34ba`, `l10n.dart:493` `tiers = _t('Tiers', '저장 공간')` |
| Cloak 행 숨김 | ✅ | `b113859`, `main.dart` `_showCloakTier = false`(코드 유지) |
| 사이드바 브랜드 크기 | ✅ | `81a34ba`, `main.dart` 아이콘 26 + 24px 워드마크 |
| 드롭·재색인 UX(UP-07 대체) | ✅ | `81a34ba`, ADR 019 |

단, `저장 공간` 라벨의 **타이포는 아직 11 / w600 / +0.8 / 대문자 변환**(`main.dart:563`) → UP-02 잔여에서 정리(한글에는 `toUpperCase`가 무의미하고 자간만 벌어짐).

### 3-2. 결정·확인 대기 (코드 전에 사용자 응답 필요)

| # | 질문 | 영향 | 현재 처리 |
|---|---|---|---|
| 1 | **한글 카드 제목이 얇아 보임** — 스크린샷 대기. 완화안: 카드 제목 18 → 19 | UP-02 타입 스케일(카드 제목 18 / w600 / 1.3) | 폰트 외곽선 두께는 같다고 측정됨(012 §3-3 ✅). **주의**: spec §11 "글자 크기만 키우는 해법은 쓰지 않는다"와 긴장 관계. 클라이언트 결정이 PM·명세보다 우선하므로(012 §1-1), 스크린샷을 보고 **클라이언트가 원하면** 18→19를 *예외*로 적용. 대안: 굵기·색(`ink` 이미 최대) 대신 행간 1.3→1.35 |
| 2 | UP-22 사이드바 활성 pill을 낮출 것인가 | 보라 채움 3곳 → 1곳 | 묻기 전엔 안 함 |
| 3 | 로그인 화면의 `⚡ PageBlink`(`sign_in_screen.dart:433`)와 칩 `⚡1 …`을 별 + 알약으로 통일할 것인가 | UP-06 범위 | 로그인 레이아웃은 뒤집지 않는 목록이라 질문만 남김 |
| 4 | 카드 제목·미리보기에 keep-all을 표시용으로만 적용할 것인가 | UP-01 | 현 정책(제외) 유지. 하려면 복사·검색 영향(`SelectableText` 여부) 확인 필요 ⚠️ |
| 5 | 다크 출처 알약이 타일보다 진해 보일 수 있음 | UP-16 눈 확인 | 012 §3-3 ⚠️ 미확인 그대로 |

---

## 4. 권장 실행 순서 (spec §10을 현재 상태로 재정렬)

원칙: ① 파일 충돌이 있는 항목은 **같은 파일 안에서 직렬**, ② 시각 효과가 큰 순서, ③ 상태 줄·카드 규칙을 먼저 정해야 뒤 항목이 흔들리지 않음, ④ 각 묶음은 **독립 커밋 1~2개**(012 §2 하네스: 깨끗한 워크트리 검증 → 무접촉 커밋 → 배포).

### 4-0. spec §10 대비 바뀐 점

| spec §10 | 지금 |
|---|---|
| 1차 UP-02 → 01 → 03 → 05 → 07 → 06 | 02·01·06(AppBar)은 끝, 07은 ⛔. **남은 것: 03 → 05 → 02 잔여** |
| 2차 04 → 08 → 09 → 14 → 13 | 그대로. 단 14는 `documents_screen`(보드)만 먼저, Ask는 묶음 D에서 |
| 3차 10 → 11 → 12 → 16 → 17 → 15 → 19 → 18 | "ask_screen 작업 뒤" 조건 소멸. 15는 03 직후로 당김(같은 카드 코드) |
| 보류 15(2단계)·20·21·22 | 15(2단계)·22는 보류 유지, 20·21은 선택 |

### 4-1. 묶음별 계획

| 묶음 | 항목 (순서) | 건드리는 파일 | 수용 기준 (보이는 결과) | 검증 |
|---|---|---|---|---|
| **A. 보드 카드·헤더** (가장 먼저) | UP-03 → UP-15(1단계) → UP-05 → UP-02 잔여(`최근`·`저장 공간`·면책 등) → UP-16 `pdfPaper` 다크 | `documents_screen.dart`, `theme.dart`(`noteHighlight`, `pdfPaper`), `main.dart:563`(라벨만), `l10n.dart`(메타 문구) | ① 개인 노트 카드에 `내 클라우드` 칩이 없고 프로젝트 노트에만 있음 ② 메타가 `2분 전` / `12쪽`만 ③ 미리보기 마지막 줄이 칩과 겹치지 않고 아래가 페이드 ④ 노트 카드 외곽선이 어두운 선이 아니라 옅은 안쪽 하이라이트 ⑤ PDF 카드가 빈 흰 칸이 아니라 종이 + 쪽수 알약 ⑥ 폰(390)에서 필터 칩이 한 줄 가로 스크롤 ⑦ `최근`·`저장 공간` 라벨이 12px·자간 0 | **위젯 테스트**: `DocumentCard`를 개인/프로젝트 두 문서로 렌더해 칩 존재 여부 단언(기존 `documents_reindex_test.dart` 패턴 재사용), `ui_polish_text_test.dart`에 라벨 자간 0 단언 추가(`Text.style.letterSpacing`), `Pb.dark.pdfPaper` 값 테스트. **수동**: 라이트·다크 × 1440/390 캡처 비교. `flutter analyze`·`flutter test` 전체 |
| **B. 골격 (테마·모션·상태)** | UP-04 → UP-08 → UP-14(보드: `PbSkeleton`·`EmptyState`·`ErrorState`) | `theme.dart`, `GlassPanel`, `open_item_view.dart`, `main.dart`(`_withPane`), `documents_screen.dart`, 신규 `app/states.dart` | ① 다이얼로그·시트·메뉴·스낵바가 같은 r14/r24 모양 ② Tab 키로 카드·내비 항목에 2px accent 링 ③ 노트를 열면 220ms 페이드 + 위로 8px(`disableAnimations`면 즉시) ④ 보드 로딩이 스피너가 아니라 카드 6장 시머 ⑤ 목록 오류에 `Exception: …` 원문이 보이지 않고 "불러오지 못했어요 / 다시 시도" | **위젯 테스트**: `buildPbTheme`의 `dialogTheme.shape`·`snackBarTheme.behavior` 값, `MediaQuery(disableAnimations: true)`에서 `pumpAndSettle` 즉시 종료, `BoardApi.list`가 throw할 때 `find.textContaining('Exception')` 없음. **수동**: 키보드 포커스 이동, 필터 크로스페이드 |
| **C. 레이아웃·셸** | UP-09 → UP-19 → UP-13 + UP-17(같이) | `main.dart`(`_layout`, `_Sidebar`), 신규 `app/side_rail.dart`, `settings_screen.dart`, `documents_screen.dart`(FAB) | ① 폭 1024~1179: 레일 72 + Ask 320 + 중앙 ≥ 536 ② 1180~1279: 레일 72 + Ask 380 ③ 노트를 열고 < 1440이면 Ask가 64px 띠, 아이콘으로 오버레이 펼침·`Esc` 닫힘 ④ 사이드바 태그라인은 ≥ 1280만 ⑤ 폰: FAB 하나, 로그아웃은 설정 안, 업로드 트레이가 FAB와 겹치지 않음 | **위젯 테스트**: `tester.view.physicalSize`를 1024/1100/1180/1280/1440로 바꿔 중앙 패널 폭 단언(spec §7 표), 레일 `Tooltip`. **수동**: 1024에서 카드 2열·메타 잘림 없음, 트레이 위치(`main.dart:341`) |
| **D. 질문 화면 (`ask_screen.dart` 직렬)** | UP-06 잔여(정적 ⚡) → UP-10 → UP-11(첫 실행) → UP-18 sticky → UP-14(답변 대기 스켈레톤) | `ask_screen.dart`, `l10n.dart`, `documents_screen.dart`(첫 실행), 신규 `app/welcome_card.dart` | ① 안내문에 문자 ⚡ 대신 알약 ② 빈 상태 아이콘 1개, 제안 3개 + 더 보기 ③ 컴포저 2행, 빈 입력의 전송 버튼이 회색 원이 아니라 옅은 보라 ④ 가입 직후 환영 카드(닫으면 다시 안 뜸), 샘플 노트의 "이 노트로 질문해 보기"가 컴포저를 채우고 전송 ⑤ 긴 답변에서 질문이 위로 사라지지 않음 | **위젯 테스트**: `AskEmptyHint` 제안 수·아이콘 수, 컴포저 `Key`로 `TextField`·전송 버튼 탐색, 환영 카드는 `SharedPreferences.setMockInitialValues`. 서버로 가는 제안 문자열에 U+2060이 없음(기존 `ui_polish_text_test.dart` 유지). **수동**: 폰 `ask-dark` 긴 답변 |
| **E. 나머지** | UP-12 → UP-20 → UP-21(선택) | `projects_screen.dart`, `app_icons.dart` 주석, `documents_screen.dart` | ① 프로젝트가 카드로 보이고 빈 상태에 CTA ② `AppIcons` 상단에 크기·굵기 표 ③ (UP-21) 짧은 노트가 큰 빈 칸을 남기지 않음 | 위젯 테스트(프로젝트 수 0/N 렌더), 수동 스크롤 성능(웹) |
| **보류** | UP-15 2단계(썸네일), UP-22(보라 예산), UP-07(대체됨) | – | – | UP-22는 클라이언트 결정(§3-2 #2) 뒤에만 |

### 4-2. 파일 충돌 직렬화 (같은 파일을 두 묶음이 건드림)

| 파일 | 건드리는 항목 (이 순서로) |
|---|---|
| `features/documents/documents_screen.dart` | UP-03 → 15 → 05 → 02잔여 → 08 → 14 → 17(FAB) → 11 → 21 |
| `features/ask/ask_screen.dart` | UP-02잔여(면책·모델 노트·Free 배지) → 06 → 10 → 11(컴포저 채움) → 18 → 14 |
| `main.dart` | UP-02잔여(`저장 공간`) → 08(`_withPane`) → 09 → 19 → 17 (+ 22는 결정 후) |
| `app/theme.dart` | UP-03(`noteHighlight`) → 16(`pdfPaper`) → 04 → 14(`skeleton*`) |
| `app/l10n.dart` | UP-03(메타) → 06(`{bolt}`) → 10/11 문구 |

### 4-3. 위험 메모

- **UP-17 ↔ 업로드 트레이**: 트레이는 `main.dart:341`에서 폰 Notes 탭의 FAB 2개(~124px)를 피하려고 136을 씁니다. FAB 구조를 바꾸면 반드시 같이 고칩니다(`upload-dnd-reindex` §6의 "충돌 가능").
- **UP-03 ↔ 상태 줄**: 명세는 상태 줄을 "프로젝트 칩 바로 위 8px, 칩이 없으면 카드 안쪽 아래 14"로 정했는데 현재 코드는 칩이 항상 있어 이 규칙의 후반부가 아직 안 쓰입니다. UP-03을 하면 상태 줄 위치를 눈으로 다시 확인합니다.
- **키 부여**: UP-10에서 컴포저 구조가 바뀝니다. 현재 Ask 컴포저를 직접 찾는 테스트는 확인되지 않았지만(✅ grep) `ask_citation_flash_test.dart`(51KB)는 `AskTurnView`·출처 효과를 다루므로 ⚠️ 전체 테스트로 확인합니다.
- **웹 확인**: UP-01·UP-02의 한글 결과는 CanvasKit 실기 확인이 남아 있습니다. 묶음 A 배포 후 라이브에서 `최근`·카드 제목 줄바꿈을 한 번 봅니다.
- **폰트 번들 변경 금지**: 400/500/600만(spec §11). 18→19 같은 크기 조정만 `theme.dart`에서.

---

## 5. 각 묶음 완료 시 갱신할 것

1. 이 문서 §2의 해당 행 상태·근거(줄 번호 포함)와 §0 요약, 최종 수정 시각(셸 `TZ=Asia/Seoul date "+%Y-%m-%d %H:%M"`).
2. `docs/design/ui-polish/spec.md`는 **고치지 않는다**(감사 기준 문서). 변경이 필요하면 이 문서에 기록.
3. 012 §3 ⑤ 줄은 이 문서를 가리키므로 항목 수만 맞는지 확인.

---

## 6. 재검증 명령 (1분)

```bash
cd /Volumes/Nova/00-src/70-github@biyott/pageblink/app/pageblink_flutter

git log --oneline -1                         # 1cd31ba 이후 코드 변경이 있는지
git log --oneline --grep='UI polish'         # UP 작업 커밋 (7612e3e 하나)

# UP-01: keep-all 사용처
grep -rnF 'keepAllKorean' lib                # text_wrap.dart, l10n.dart:30, ask_screen.dart:1145
grep -cF '_k(' lib/app/l10n.dart             # 38 (정적 긴 문구)

# UP-02: 우회 제거 / 잔여 리터럴
grep -rnF 'subInkFor' lib                    # 0건이어야 함
grep -rnE 'fontSize: *(9|10|10\.5|11|11\.5)\b' lib
grep -rnE 'letterSpacing: *[0-9.-]+' lib | grep -v theme.dart

# UP-03/05/14/15/21: 카드·헤더 현재 코드
grep -nE 'l\.myCloud|noteMeta|TextOverflow\.fade|Wrap\(|mainAxisExtent|CircularProgressIndicator\(\)|_error =' lib/features/documents/documents_screen.dart
grep -rnF 'noteHighlight' lib                # 0건이어야 UP-03 미착수

# UP-04/16: 테마
grep -nE 'ButtonTheme|dialogTheme|bottomSheetTheme|popupMenuTheme|snackBarTheme|pdfPaper:' lib/app/theme.dart

# UP-06: 정적 ⚡ 문자열
grep -rn '⚡' lib | grep -v '///'

# UP-07: 대체 확인
grep -rnF '_FailedBlock' lib                 # 0건
grep -rnF 'MaterialBanner' lib               # 0건

# UP-09/17/19/22: 셸
grep -nE 'width >= 1024|width: 240|width: 380|bottom: _tab|showCloakTier' lib/main.dart
ls lib/app | grep -E 'side_rail|states|welcome'    # 없어야 UP-09/14/11 미착수

# 테스트·정적 분석 (깨끗한 워크트리에서, 012 §2)
# flutter analyze && flutter test
```

---

## 7. 새 세션 시작 절차

1. `CLAUDE.md` → `AGENTS.md` → 이 문서 §0·§2를 읽는다.
2. §6 명령으로 기준 커밋 이후 변경을 확인하고 어긋나는 행을 먼저 고친다.
3. §4-1의 **묶음 A**부터. 시작 전에 `docs/design/ui-polish/spec.md`의 해당 항목(§4 표)과 `docs/design/upload-dnd-reindex/spec.md` §6(채택·충돌 목록)을 읽는다.
4. 구현은 012 §2 하네스(서브에이전트 위임 → 깨끗한 워크트리 검증 → 무접촉 커밋 → 배포)를 따른다. `git stash`/`checkout`/`reset` 금지는 서브에이전트에도 명시한다.
5. §3-2의 결정 대기 항목은 코드 전에 사용자에게 묻는다.
