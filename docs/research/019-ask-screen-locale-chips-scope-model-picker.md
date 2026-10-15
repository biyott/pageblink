# 019 · Ask 화면·언어 설정 UX 이슈 3건 조사 (언어 우선순위 · 예시 칩 잘림 · 범위/모델 선택)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 09:21 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용 · 코드 수정·빌드·서버 실행 없음) |
| 질문 | ① English로 설정해도 영어로 안 나온다(시스템 로케일 우선?) ② Ask 예시 질문 칩 글자가 잘려 보인다 ③ 입력줄의 문서 선택 컨트롤이 겹치고 의미를 모르겠다 · 모델 드롭다운 글자가 너무 많다 |
| 결론 한 줄 | ① `main.dart:44-52`의 `localeResolutionCallback`이 사용자가 고른 로케일을 받고도 `platformDispatcher.locales`에 ko가 있으면 ko를 반환해 덮어씀(저장·복원·`MaterialApp.locale` 전달은 정상) · ② 예시 칩은 `ActionChip`(단일 행 설계, 내용 높이 ≈ 16px)이라 라벨이 줄바꿈되면 2행이 칩 밖으로 넘침 — 폭이 좁거나 글자 배율이 큰 환경에서 발생(⚠️ 시각 재현은 안 함) · ③ "노트 선택"은 노트 개별 선택이 아니라 `FilterChip` 토글(내 문서 / 프로젝트별)이며, 선택 시 체크마크가 아바타 아이콘 위에 겹쳐 그려짐 · 모델 항목은 `라벨 · 무료 · (서버 영어 note)` 한 줄에 중복·혼합 언어 |
| 반영 | 없음 (결정 대기 · 필요 시 ADR) · 같은 날 [017](017-flutter-ux-issues-investigation.md)과 별개 이슈 |

> 표기: ✅ 코드·Flutter SDK 소스로 확인 · ⚠️ 미확인/추정. 경로는 `app/pageblink_flutter/lib/` 기준(서버는 `app/pageblink_server/lib/src/`). Flutter SDK는 `.fvmrc`의 3.47.7. **실행하지 않았으므로 시각 증상은 정적 분석으로만 확정**했습니다.

---

## 핵심 결론

| # | 이슈 | root cause | 수정 위치 |
|---|---|---|---|
| 1 | English로 설정해도 영어가 안 나옴 | ✅ `main.dart:44-52` 콜백이 `chosen`을 무시하고 시스템 로케일 목록에서 ko를 찾음 | `main.dart` 1곳(2~3줄) |
| 2 | 예시 칩 글자 잘림 | ✅(SDK 소스) `ActionChip` 내용 높이가 한 줄 기준으로 고정 · ⚠️ 어떤 기기에서 줄바꿈되는지는 미재현 | `ask_screen.dart:581-589` (+ 필요 시 `l10n.dart:188-200` 문구) |
| 3a | 문서 선택 컨트롤 겹침·의미 불명 | ✅ `FilterChip(avatar: Icon)`의 선택 상태 체크마크가 아바타 위에 겹쳐 그려짐 · 라벨/요약 없음 | `ask_screen.dart:352-390` `_ScopeBar` |
| 3b | 모델 드롭다운 글자 과다 | ✅ 항목 1줄에 label+무료/유료+서버 note(영어·가격 포함) 연결, "자동" 항목 없음 | `ask_screen.dart:287-350` `_ModelPill`, `llm_catalog.dart` |

---

## 상세

### 1. 언어를 English로 설정해도 영어가 안 나옴

**흐름 (정상인 부분)**

| 단계 | 근거 | 판정 |
|---|---|---|
| UI | `features/settings/settings_screen.dart:28-52` 라디오 3택: 시스템(`_system`) / `en` / `ko` | ✅ 이미 "시스템/English/한국어" 3택 |
| 저장 | `app/locale_controller.dart:9` 키 `pageblink.locale`, `:22-34` `choose()`가 `SharedPreferences`에 `setString`(시스템이면 `remove`) | ✅ 영속 (웹은 localStorage) |
| 복원 | `main.dart:21` `runApp` 전에 `await localeController.load()` → `locale_controller.dart:12-20` | ✅ |
| 반영 | `main.dart:29-32` `ValueListenableBuilder` → `MaterialApp(locale: chosen, ...)` | ✅ |
| 문자열 | `app/l10n.dart:9` `Localizations.localeOf(this).languageCode == 'ko' ? L.ko : L.en` — `context.l` 전 화면 공통 | ✅ context 로케일만 사용 |

**root cause (확정)** — `main.dart:43-52`

```dart
localeResolutionCallback: (locale, supported) {
  final preferred = [?locale, ...WidgetsBinding.instance.platformDispatcher.locales];
  return preferred.any((l) => l.languageCode == 'ko') ? const Locale('ko') : const Locale('en');
},
```

- ✅ Flutter 3.47.7 `widgets/localizations.dart:819-822`: `MaterialApp.locale`이 있으면 `_resolveLocales(<Locale>[_locale!], supported)`를 부르고, `:899-907`에서 **콜백을 그대로 호출**해 non-null 반환값을 채택한다(콜백은 `locale`이 지정돼도 건너뛰지 않음).
- 콜백은 `[사용자 선택, ...시스템 로케일 전체]` 중 **ko가 하나라도 있으면 ko**를 반환한다. 한국어 기기/브라우저에서 English를 고르면 첫 원소가 en이어도 뒤쪽 시스템 목록의 ko가 매치되어 **항상 한국어**. 반대로 시스템에 ko가 없을 때만 선택이 먹힌다(영어 기기 + 한국어 선택은 정상). 보고된 "시스템 로케일이 우선" 증상과 일치.
- 설정 화면 라디오(`settings_screen.dart:31`)는 `chosen` 기준이라 "English"가 선택된 채 화면은 한국어인 모순이 보인다.
- `ask_screen.dart:92`가 서버로 보내는 `Localizations.localeOf(context).languageCode`도 같은 해석된 값이라 서버 고정 문구(`ask_endpoint.dart:28,82-94,163-166`)도 같이 ko로 간다.

**시스템 로케일 직접 참조 전수 grep** (`PlatformDispatcher|platformDispatcher|localeOf|localeName|Locale\(|locale`, `lib/` 전체)

| 위치 | 용도 | 문제? |
|---|---|---|
| `main.dart:47` `platformDispatcher.locales` | 위 콜백 | ✅ **유일한 직접 참조 = root cause** |
| `app/l10n.dart:9`, `ask_screen.dart:92` | `Localizations.localeOf(context)` | 정상(해석된 값 사용) |
| `Platform.localeName` | 없음 | — |

**하드코딩·미경유 문자열**

- 한글 리터럴은 `screens/sign_in_screen.dart:164-189`(로그인 위젯용 `_koBasic/_koEmail/_koPassword`, `:153` `_localized(l, …)`가 `l.isKorean`일 때만 적용)에 한정. ✅ 의도된 분기이며 `l`을 따르므로 root cause 수정 시 같이 정상화.
- 사용자 노출 영어 하드코딩: `ask_screen.dart:110` `turn.error = '$e'`, `documents_screen.dart:56` `_error = '$e'` — 예외 원문(영어/기술 문구)이 그대로 노출 ✅. 별도 이슈이나 "English로 해도 영어가 아니다"의 반대 케이스(한국어 UI에 영어 에러)로 보일 수 있음.
- 제품명(`main.dart:198,418`)은 의도된 고정.

**서버가 내려주는 문자열**

- ✅ `ask_endpoint.dart:25-28`에서 `locale == 'ko'`로 키워드 대체 안내·무결과·실패 메시지를 ko/en 분기(`:82-94,163-166`). 단 `ask` 인자를 안 넘기는 구버전 클라이언트면 en.
- ✅ 그 외 엔드포인트의 `ArgumentError('Note not found')` 등(`document_endpoint.dart:105,147,192`, `project_endpoint.dart:50,58`)은 영어 고정 → 클라이언트 `'$e'`/`l.inviteFailed($error)`로 노출.
- ✅ `LlmCatalog`의 `note` 필드(`llm_catalog.dart:17-54`)는 **영어 고정**(한국어 UI에서도 영어) — 3b 참조.
- ✅ 답변 본문 언어: 시스템 프롬프트가 "Answer in the language of the question"(`llm_provider.dart:76`, `openrouter_llm_provider.dart:39`) → **UI 언어 설정이 아니라 질문 언어**를 따른다. 설정이 English여도 한국어로 질문하면 한국어 답변. 사용자 기대와 다를 수 있으니 안내 또는 `locale`을 프롬프트에 반영할지 결정 필요(⚠️ 정책 선택).

**수정안 (최소)** — `app/pageblink_flutter/lib/main.dart:43-52`

```dart
localeResolutionCallback: (locale, supported) {
  if (chosen != null) return chosen;   // 사용자가 고른 언어는 항상 우선
  final preferred = [?locale, ...WidgetsBinding.instance.platformDispatcher.locales];
  return preferred.any((l) => l.languageCode == 'ko') ? const Locale('ko') : const Locale('en');
},
```

`chosen`은 `builder`의 클로저 변수라 바로 쓸 수 있다. 시스템 선택(null)일 때만 기존 "ko가 하나라도 있으면 ko" 로직 유지. 3택 UI는 이미 있으므로 추가 제안 없음(설정 화면 문구는 "시스템 설정 / English / 한국어"로 적절). 선택적: 시스템 모드 라벨에 현재 해석 결과를 덧붙이기(예: "시스템 설정 (한국어)") — `settings_screen.dart:39`.

### 2. Ask 예시 질문 칩 글자 잘림

**위젯 위치** ✅ `features/ask/ask_screen.dart:551-595` `_EmptyHint`: `Wrap(spacing 8, runSpacing 8, center)` 안에 `ActionChip(label: Text(s))` (`:581-589`). 문구는 `l10n.dart:188-200` `askSuggestions` 4개(영어 최장 "What was decided in the meeting notes?" 38자).

**고정 높이 코드는 없음.** `SizedBox(height)`/`maxLines`/`textScaler` 지정 모두 `lib/`에서 grep 0건 ✅. 원인은 Chip 자체의 구조:

- ✅ `material/chip.dart:1953-1956` 내용 높이 `contentSize = max(32 - padding.vertical + labelPadding.vertical, rawLabelSize.height + labelPadding.vertical)`. M3 기본 `padding: all(8)`이면 한 줄(≈16px) 기준 약 16px.
- ✅ `:1952` `rawLabelSize`는 **가로 제약이 가장 넓은 상태**(`constraints.loosen()`)로 측정하고, `:1858-1877` 실제 라벨은 아바타·패딩을 뺀 더 좁은 `maxWidth`에 **`maxHeight: contentSize`**로 배치. 즉 라벨 길이가 "전체폭 ≥ 길이 > 전체폭 − 패딩(약 32px)" 구간이면 측정은 1행, 실제 배치는 2행으로 줄바꿈되고 높이는 1행분으로 고정 → 2행이 칩 밖/테두리 위로 넘쳐 잘려 보임.
- 테마 `app/theme.dart:220-243` 칩 `labelStyle` 13px, `labelPadding`·`padding`·`materialTapTargetSize` 미지정 → 위 기본값.
- ⚠️ 화면 폭 320~360dp 폰(패딩 24×2 + 칩 패딩 32 → 텍스트 가용 ≈ 230~260px), OS 글자 배율 ≥1.15, 한국어 폰트 폴백 시 줄바꿈 구간에 들어가기 쉬움. 데스크톱은 Ask 패널 폭 고정 380(`main.dart:316`)에서 가용 약 290px라 영어 최장 문구(≈250px 추정)는 보통 한 줄이지만 글자 배율 시 동일 증상 가능. **기기별 시각 재현은 하지 않음.**
- ⚠️ `labelMedium`에는 `fontFamilyFallback: ['Noto Sans KR']`이 없음(`theme.dart:177-195`에서 `bodyLarge/bodyMedium`에만 지정) → 칩 한글이 시스템 폴백 폰트로 그려져 행 높이가 달라질 수 있음.

**수정안**

| 안 | 내용 | 평가 |
|---|---|---|
| A (추천) | `ActionChip` 제거 → 직접 만든 제안 카드: `Material`+`InkWell`+`Container(constraints: BoxConstraints(minHeight: 44, maxWidth: 420), padding: 12~14)` + `Text`(줄 수 제한 없음 또는 `maxLines: 2`+ellipsis). 세로 리스트(폭 100%)로 배치 | 줄바꿈 자유·터치 높이 44 보장·모바일/데스크톱 동일. 글자 배율에도 안전 |
| B | `Wrap` 유지 + 칩 대신 같은 커스텀 위젯(높이 = 내용 기반, `minHeight` 40) | 가로 배치 유지, 칩 느낌 유지. 긴 문구는 다음 줄로 넘어감 |
| C | `ActionChip`에 `labelPadding: vertical 8`·`padding`만 늘림 | 구조 한계(한 줄 가정)를 못 없앰 → 비추천 |

모바일: 폭이 좁아도 카드가 자연스레 2행. 데스크톱 380px 패널: 카드 1열이 가독성 좋음. 문구도 20자 이내로 줄이면 더 안전(`l10n.dart:188-200`).

### 3a. 입력줄의 문서(노트) 선택 컨트롤

**구조** ✅ `ask_screen.dart:200-210`(입력 카드 맨 위) → `_ScopeBar`(`:352-390`): 가로 `SingleChildScrollView` + `Row` 안 `FilterChip` 나열.
- 첫 칩 "내 문서/My docs"(`l10n.dart:182`, `avatar: Icons.cloud_outlined`) — `includePersonal` 토글 (`:372-377`).
- 이어서 프로젝트마다 칩(`avatar: Icons.groups_outlined`) — `_selectedProjects` 토글 (`:378-386`).
- `l10n.dart:315` `scope`('범위') 문자열은 정의만 있고 **어디에서도 쓰지 않음**(grep) → 컨트롤에 제목/설명이 없다.

**실제 동작** ✅ `ask_endpoint.dart:36-42`: 검색 범위 `= (내 개인 문서: ownerId=나 & projectId=null) if includePersonal  OR  선택한 프로젝트들의 청크`. 즉 **개별 노트·PDF 선택이 아니라 "내 문서 전체" 및 "프로젝트 단위" 범위 선택**이다. 멤버십은 서버가 교집합으로 재검증(`:30-33`).
- 기본값: 내 문서 ON, 프로젝트 전부 OFF(`:40-41`) — 공유 프로젝트는 칩을 눌러야 포함됨(발견성 낮음).
- 프로젝트가 없으면 `projectIds=[]`(`:83-85`)이고 "내 문서"를 끄면 범위가 비어 `:88-97` "관련 내용을 찾지 못했어요"만 나옴 — 범위를 모두 껐다는 안내·전송 차단 없음 ✅.
- 칩이 가로 스크롤인데 스크롤 힌트/잘림 표시 없음(프로젝트가 많으면 뒤쪽이 안 보임).

**겹침 원인 (확정)**

- ✅ `FilterChip`에 `avatar`가 있고 선택되면 `chip.dart:2174-2194` `_paintSelectionOverlay`가 **체크마크를 아바타 아이콘 바로 위에 덧그림**(아바타에 어두운 스크림 `:2176-2187` + 체크 `:2189-2193`). 구름/그룹 아이콘 위에 ✓가 겹쳐 "아이콘이 글씨랑 겹친다 / 체크박스인가?"로 보임. 체크 색은 테마(`theme.dart:231` `checkmarkColor`)가 지정한 `onAccentContainer`라 아바타 아이콘과 비슷한 색이면 더 뭉개짐.
- 아바타 슬롯은 칩 내용 높이(≈16~18px)에 맞춰지는데 아이콘은 `size: 18`(`:373,381`)이라 슬롯과 거의 같거나 넘침.
- Row 오버플로·Stack·고정 폭은 없음(가로 스크롤 Row) ✅ — 겹침은 레이아웃 오버플로가 아니라 **칩 선택 표시와 아바타의 이중 표현**.

**개선안**

| 안 | 내용 | 장단 |
|---|---|---|
| A (추천) | **범위 요약 버튼 + 바텀시트/팝오버 체크리스트.** 입력 카드 위에 한 줄 버튼 "출처: 내 문서 · 프로젝트 2개 ▾" (`Sources: My docs + 2 projects ▾`). 탭하면 모바일은 `showModalBottomSheet`, 데스크톱(≥600)은 `MenuAnchor`/`PopupMenu`로 제목 "검색할 출처"(`Search in`) 아래 체크리스트(내 문서, 각 프로젝트) + "모두 선택/모두 해제". 선택 개수 배지, 0개면 빨간 안내 + 전송 비활성 | 의미 명확, 칩 겹침 소멸, 항목이 많아도 확장 가능. 구현 중간 |
| B | 칩 유지하되 `avatar` 제거 + `showCheckmark: true`만 사용하고 맨 앞에 라벨 "검색 범위"(`l.scope` 재사용) 추가, 가로 스크롤 대신 `Wrap` | 변경 최소(1파일 소폭). 개수 많으면 줄이 늘어남 |
| C | `SegmentedButton`/`ToggleButtons`: [내 문서] [프로젝트…] | 항목 수가 적을 때만 적합, 프로젝트 증가에 약함 |

추천 A. 문구 예: 라벨 `Sources`/`검색 범위`, 버튼 값 `My docs`·`My docs + 2 projects`/`내 문서`·`내 문서 + 프로젝트 2개`, 시트 제목 `Search in`/`어디서 찾을까요?`, 힌트 `Answers only use the sources you check.`/`체크한 곳의 문서에서만 답해요.`, 빈 선택 `Pick at least one source.`/`출처를 하나 이상 선택하세요.`.

### 3b. 모델 선택 드롭다운

**현재 표시** ✅ `ask_screen.dart:287-350` `_ModelPill`(`PopupMenuButton<String>`).
- 버튼(`:316-347`): 높이 32, `current.label` + `무료/유료`(`l10n.dart:320-321`) + ▾. 라벨은 `Flexible`+ellipsis라 긴 모델명이 잘림.
- 항목(`:307-314`): `'${m.label} · ${m.free ? l.free : l.paid}${m.note == null ? '' : ' · ${m.note}'}'` **한 줄 Text**(줄 수 제한 없음 → `PopupMenu` 최대폭에서 2~3줄로 줄바꿈). 현재 선택 표시(체크)·구분 없음.

**데이터 출처** ✅ `models/llm_model.spy.yaml`(id·label·provider·free·note) → `services/llm_catalog.dart:12-60` 7개 → `rag_endpoints/model_endpoint.dart:10` `list`, `:12-13` `defaultModel`(`llmModel` 설정 또는 `gemma-4-26b-a4b-it:free`) → ADR 014.
- `note`는 **영어 고정 문자열**이고 `free · recommended · multilingual · fast`처럼 "free"를 이미 포함, 유료는 `paid $0.25/$1.50 · fast` 가격까지 포함 → 한국어 UI에서 `Gemma 4 26B · 무료 · free · recommended · multilingual · fast`처럼 **언어 혼합 + 무료 중복**.
- `provider`는 UI에서 미사용. 7개 중 NVIDIA 4개가 긴 이름("Nemotron 3 Nano Omni (reasoning)").
- 로테이션: 선택 모델이 먼저, 실패 시 나머지 무료 모델로(`llm_catalog.dart:63-69`, `rotating_llm_provider.dart`). 별도의 "자동" 항목은 없고 `defaultModel`이 사실상 선택된 상태로 시작.
- ✅ 부수 발견: 서버는 실제 응답 모델을 `AnswerEvent(type:'model')`로 내려주지만(`ask_endpoint.dart:146-147`) 클라이언트 `switch`(`ask_screen.dart:96-106`)에 `'model'` 케이스가 없고, 답변 말풍선 하단 배지는 **선택한 모델 라벨**(`:80`)만 쓴다 → 로테이션이 일어나면 배지가 실제 답한 모델과 달라짐. `_Turn.modelId`(`:30`)는 선언만 있고 쓰이지 않음.
- 선택값은 화면 상태(`_modelId`)로만 있고 저장되지 않음.

**개선안**

| 안 | 내용 | 장단 |
|---|---|---|
| A (추천) | **짧은 표시명 + 배지, 상세는 2행.** 항목 = 1행 `Gemma 4 26B` + 오른쪽 배지(`무료`/`유료`) + 선택 표시 ✓, 2행(작은 글씨, muted) 한 문장 설명. 맨 위에 `자동 (무료 모델 순환)`/`Auto (rotates free models)` 기본 항목. 버튼은 `자동 ▾` 또는 `Gemma 4 26B · 무료 ▾` | 항목 폭이 일정하고 스캔 쉬움. 서버 `note`를 키(`fast`,`large`…)나 한/영 맵으로 바꾸는 작업 필요 |
| B | 무료/유료 **섹션 헤더**("무료 모델 5 / 유료 2")로 묶고 항목은 모델명만 + 툴팁/long-press로 상세 | 가장 단순. 모바일은 툴팁 접근성이 낮음 |
| C | 바텀시트 라디오 리스트(라벨 + 배지 + 한 줄 설명), 유료는 접기 | 모바일 친화·확장 쉬움, 구현 가장 큼 |

추천 A. 한/영 문구 예: 자동 `Auto · rotates free models`/`자동 · 무료 모델 순환`, 배지 `Free`·`Paid`/`무료`·`유료`, 설명 `Fast, multilingual · recommended`/`빠르고 다국어 · 추천`, `Largest · may be slow`/`가장 큼 · 느릴 수 있음`, `Reasoning · slower first token`/`추론형 · 첫 글자가 느림`, 유료 `Paid · about $0.25 per 1M input tokens`/`유료 · 입력 100만 토큰당 약 $0.25`(⚠️ 가격 표기는 카탈로그 값 그대로 쓸지 결정). 기본 모델 `defaultModelId`는 `recommended`로 표시. 무료 필터는 B의 섹션 헤더로 대체 가능.

---

## 변경 규모 요약 (코드 수정은 하지 않음)

| 항목 | 파일 | 규모 |
|---|---|---|
| 1 언어 | `app/pageblink_flutter/lib/main.dart` | 2~3줄 |
| 2 예시 칩 | `features/ask/ask_screen.dart` (`_EmptyHint`), 선택 `app/l10n.dart` | 위젯 1개 교체 |
| 3a 범위 | `features/ask/ask_screen.dart` (`_ScopeBar` 교체·전송 가드), `app/l10n.dart` 문구 6~8개 | 중 |
| 3b 모델 | `features/ask/ask_screen.dart` (`_ModelPill`·`'model'` 이벤트 처리), `app/l10n.dart`, 서버 `services/llm_catalog.dart`(note를 키/이중 언어로) | 중 (서버 클라이언트 재생성은 `LlmModel` 필드를 바꿀 때만) |

## 미확인 · 리스크

- ⚠️ 예시 칩의 시각적 잘림은 SDK 소스 레벨 추론이며 실기기 폭·글자 배율별 재현은 하지 않았다.
- ⚠️ `labelMedium`의 한글 폴백 폰트 영향은 미확인.
- ⚠️ 답변 언어를 UI 설정에 맞출지(프롬프트에 `locale` 반영)는 제품 결정 사항 — 현재는 질문 언어를 따름.
- ⚠️ "노트 개별 선택" 요구가 있다면(사용자 표현은 "노트(문서) 선택") 서버 `ask`에 `documentIds` 필터가 필요하며 현재 API(`projectIds`, `includePersonal`)로는 불가.
- 서버 `LlmModel` 모델 필드를 바꾸면 `pageblink_client` 재생성이 필요(수정 금지 영역, `serverpod generate`).

## 출처

- 코드: `app/pageblink_flutter/lib/main.dart`, `app/locale_controller.dart`, `app/l10n.dart`, `app/theme.dart`, `features/settings/settings_screen.dart`, `features/ask/ask_screen.dart`, `screens/sign_in_screen.dart`
- 서버: `app/pageblink_server/lib/src/rag_endpoints/ask_endpoint.dart`, `rag_endpoints/model_endpoint.dart`, `services/llm_catalog.dart`, `models/llm_model.spy.yaml`, `providers/rotating_llm_provider.dart`
- Flutter 3.47.7 SDK: `packages/flutter/lib/src/widgets/localizations.dart:806-910`, `material/chip.dart:1858-1877, 1949-1990, 2174-2194`
- 문서: [ADR 014](../adr/014-model-catalog-and-rotation.md), [research 017](017-flutter-ux-issues-investigation.md)
