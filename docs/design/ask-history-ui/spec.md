# Ask 대화 선택 UI 재설계 (헤더 `[최근 대화 ▾]` + `[새 대화]`)

작성 2026-10-16 KST · 작성자 UI/UX 디자이너 · 대상 `app/pageblink_flutter` (Flutter 3.47.7)
표기: ✅ 코드·캡처·렌더 실측으로 확인 / ⚠️ 미확인·추정(위젯 테스트로 확인 필요).
**저장소 파일은 만들지도 고치지도 않았다.** 산출물은 이 폴더(`ask-history-ui/`) 안뿐이다. 서버 API·기능 규칙(030)은 바꾸지 않는다.

> 상태: 구현 완료(14·15차 작업 — 대화 헤더 `[최근 대화 ▾]`·`[새 대화]`는 15차. 15차 배포 성공 16:13). 서버 기능 규칙은 [research 030](../../research/030-ask-sessions.md).
> 문서 위치: 저장소 편입 시 `ask-history-ui/` 폴더를 `docs/design/ask-history-ui/`로 옮겼고 파일명은 `spec.md`다. 아래 표 중 `states-{light,dark}-1…5-*.png`(10장, 약 9.5MB)와 `current-{desktop,tablet,mobile}.png`(3장)는 용량 때문에 저장소에서 제외했다. `states.html`은 이 폴더에 있고, 브라우저에서 열면 같은 시안을 다시 볼 수 있다(`?t=dark`).

| 파일 | 내용 |
|---|---|
| `states.html` | 기준 시안. 라이트·다크 토큰 hex(`?t=dark`), 데스크톱 380 열 + 모바일 390, 상태 12종 + 반응형 + 대안 |
| `states-{light,dark}-1…5-*.png` | `states.html` 스크린샷(각 5장) |
| `current-{desktop,tablet,mobile}.png` | 운영(`pageblink.serverpod.space`) 데모 로그인 후 Ask 빈 상태 캡처(질문 전송 없음) |

이미지 생성 모델(OpenRouter) 호출 **0회**. 시안은 전부 손으로 쓴 HTML이다.

---

## 0. 한 장 요약

| 항목 | 결론 |
|---|---|
| 진단 | 드문 작업(대화 전환)이 가장 바쁜 영역(입력 패널)에 칩 줄로 들어 있고, 같은 동작에 이름이 둘, ▾ 모양인데 모달이 열리고, 항목마다 휴지통이 상시 노출됨 |
| CTO 제안 | **타당. 채택하되 보완 3가지**: ① 폰·태블릿엔 원래 헤더가 없으니 한 줄 추가 ② 용어 "새 대화"로 통일(결정 항목) ③ 최근 대화는 **앵커 팝오버(≥600) / 바텀시트(<600)**, 다이얼로그 폐기 |
| 추천안 | **A. 헤더 두 버튼 + 팝오버/시트** (입력창 위 대화 바 삭제, 카운터는 입력창 아래 줄 오른쪽) |
| 대안 | B 현재 대화 제목 칩+메뉴 / C 좌측 목록 패널(380 열이라 부적합) / D 입력창 위 한 줄로 축소(임시방편) |
| 서버 API | 불변. 단 **목록 행에 "끊김" 표시는 불가**(`AskSessionSummary`에 상태 필드 없음) |

---

## 1. 현재 UI 진단

근거: ✅ 운영 캡처(`current-desktop.png` 1200, `current-tablet.png` 768, `current-mobile.png` 390: 빈 상태), ✅ 코드(`ask_screen.dart`, `ask_chat.dart`는 대화 상태만 있고 UI 없음), ✅ 위젯 테스트 `ask_history_test.dart`. **`질문 n/10` 칩·한도·끊김·목록 열림은 질문을 보내야 나타나므로 캡처하지 않았고 코드·테스트에서 유도**했다(`states.html` ①이 그 재현).

| # | 문제 | 근거 | 영향 |
|---|---|---|---|
| P1 | **위치**: 대화 관리 칩 줄(`_ChatBar`)이 입력 패널(`GlassPanel`) 안 맨 위. 패널 안 줄이 칩(대화) → 칩(출처) → 입력 → 칩(모델) 3겹 | `ask_screen.dart` ~318행 `if (historyOn) _ChatBar`, 캡처 | 380 폭에서 칩 4개+입력 한 개. 자주 하는 "질문 입력"과 드문 "대화 전환"이 섞임 |
| P2 | **용어 이중화**: 헤더 아이콘 툴팁 `새 질문`(`l.newChat`)과 칩 `새 대화`(`l.newConversation`). 비활성 조건도 다름(헤더 `turns.isEmpty` / 칩 `turns.isEmpty && sessionId == 0`). 한도 문구는 "새 대화" | `l10n.dart:629, 699`, `ask_screen.dart:255, 1374`, 데스크톱 캡처에 둘이 동시에 보임 | 같은 동작이 두 군데·두 이름. 칩은 빈 대화에서 흐려져 **고장난 것처럼** 보임(캡처) |
| P3 | **어포던스 불일치**: "최근 대화" 칩은 ▾ 아이콘인데 누르면 **가운데 모달**(≥600 `Dialog` 420, <600 시트) | `ask_screen.dart:131-166`, `ask_chat` 칩 `AppIcons.expand` | 드롭다운인 줄 알았는데 화면 전체를 가림. 어디서 열렸는지 연결이 끊김 |
| P4 | **시각적 무게**: `질문 3/10`은 버튼과 같은 테두리 칩 모양이지만 눌러도 반응 없음. 첫 질문 후에야 나타나 줄이 밀림 | `ask_chat` `ask-count` Container, 테스트 `countChip` | 눌러지는 것처럼 보이는 비상호 요소 + 레이아웃 점프 |
| P5 | **목록 항목**: 항목마다 휴지통 상시 노출. 실제 동작은 서버가 보관하는 "숨김"이고 되돌릴 수 없음 | `_RecentChats` `trailing: IconButton(AppIcons.delete)` | 삭제로 오해(불안) + 오터치 시 되돌릴 방법 없음 |
| P6 | **헤더가 ≥1024에만 있었다**: `wideHeader = width >= 1024`. 태블릿·폰의 Ask에는 새 질문 버튼 자체가 없었음 | `ask_screen.dart:232`, 768·390 캡처(헤더 없음, 전역 AppBar는 브랜드·설정·로그아웃) | 그래서 대화 바가 입력창 위로 올라간 것으로 보임 |
| P7 | **안내가 입력창 안**: `hint`(busy·expired·notFound·loadFailed)가 패널 안 칩 줄 위에 끼어 있음 | `ask_screen.dart` ~326행 | 패널이 더 높아지고 시선이 입력창 근처에 갇힘 |
| P8 | **한도 배너가 입력창 위**: 패널 안, 출처 버튼 위에 쌓임 | `_LimitBanner` | 대화가 끝났다는 사실이 스레드(내용) 안이 아니라 입력 도구 줄에 있음 |

---

## 2. CTO 제안 평가와 구체화

제안: "상단 헤더의 원래 새 질문 버튼 + 그 옆 '최근 대화' 선택 버튼".

### 2.1 평가

| 관점 | 판정 | 이유 |
|---|---|---|
| 정보 구조 | 적합 | 대화 전환·새 대화는 "화면 단위 내비게이션"이라 헤더가 맞다(ChatGPT·Claude 계열의 관례). 입력 패널은 입력만 남는다 |
| 원래 버튼 위치 | 적합 | 데스크톱 우상단 새 질문 아이콘 자리를 유지 → 근육 기억 유지 |
| 폭 | 적합 | 380 열 헤더 실측(✅ 렌더): ko 제목 88 + 버튼 216(120+88)+gap 8 = **312 / 가용 344**, en(`Recent`+`New chat`) **314 / 344**. 여유 약 30 |
| 폰·태블릿 | **보완 필요** | 원래 헤더가 없다(P6). 한 줄을 새로 추가(+52px). 기록 꺼짐일 땐 추가 안 함 |
| 영어 긴 라벨 | **보완 필요** | `Recent conversations` / `New conversation`은 380에서 못 들어감(제목 78 + 긴 라벨 > 344). 헤더 전용 짧은 라벨 필요 |
| 접근성·터치 | 적합 | 버튼 2개, 터치 영역 44, 포커스 순서 단순 |

### 2.2 선택 버튼의 형태

| 후보 | 판정 | 이유 |
|---|---|---|
| **앵커 팝오버(≥600) + 바텀시트(<600)** | **채택** | 항목이 2줄(제목+메타)이고 행마다 부가 동작(숨기기)이 있어 단순 드롭다운 메뉴 항목보다 크다. 버튼에서 열려 연결이 보이고, 폰은 엄지 영역 시트 |
| 일반 `PopupMenuButton` 메뉴 | 부적합 | 항목당 정지점 1개(숨기기 불가), 기본 최대 폭 280 |
| 세그먼트(최근 5개를 탭으로) | 부적합 | 제목이 길고(첫 질문) 개수가 변함 |
| 다이얼로그(현행) | 폐기 | P3. 태블릿(본문 ~590)에서도 앵커 팝오버가 가능 |

버튼은 `[🕘 최근 대화 ▾]` 아웃라인 pill + `[＋ 새 대화]` 톤(accentContainer) pill. 새 대화가 더 자주 쓰이는 동작이므로 면을 채우되 보라 채움(전송·CTA)은 아니다.

**답변 중(streaming)에 헤더 버튼**: `newChat()`·`openSession()`은 진행 중 스트림을 취소한다(서버는 `interrupted`로 기록). 현행 헤더 아이콘도 같다. **이 설계는 현행 동작을 유지**하고 버튼을 막지 않는다(막으면 느린 모델에서 대화를 못 떠남). 필요하면 후속으로 경고 한 줄을 검토.

### 2.3 목록 항목 구성

| 요소 | 값 |
|---|---|
| 제목 | 서버 `title`(첫 질문 앞 80자). 14px w500, **2줄까지**, 말줄임 |
| 메타 | `질문 3/10 · 12분 전` 12px muted (한도는 `status.questionLimit`). 8 이상이면 `warnText` + ⚠ + w600(카운터와 같은 규칙) |
| 현재 대화 | `accentContainer` 면 + 앞 ✓ + 제목 w700 + 메타 앞 **"현재"** 글자(색만으로 전달하지 않음). 탭하면 팝오버만 닫힘 |
| 상태(끊김 등) | **목록 행에는 표시 불가**(`AskSessionSummary` = `{id, title, questionCount, lastActiveAt}`). 끊김은 현재 열린 대화의 해당 답변 아래에서만 보임(§2.8). 서버가 요약에 상태를 싣게 되면 행에 ⚠ 추가 가능(후속) |
| 정렬 | 서버가 준 순서 그대로(최근 활동 순으로 보임, ⚠️ 서버 정렬 확인) |
| 숨기기 | 행 오른쪽 `eye-off` 아이콘 버튼. §2.4 |
| 푸터 | `마지막 질문 후 {visibleMinutes}분 동안 보여요. 목록에서 숨겨도 서버에는 {retentionDays}일 보관돼요.` (값은 `AskHistoryStatus`에서) |
| 제목 줄 | "최근 대화" 12px w700 muted. "최대 5개" 같은 값은 상태에 없어 **넣지 않음** |

### 2.4 숨기기 동작

| 항목 | 결정 |
|---|---|
| 위치 | 행 오른쪽 아이콘 버튼. 라벨 "목록에서 숨기기". 휴지통 대신 `eye-off`(삭제가 아님) |
| 노출 | 데스크톱 포인터: hover·포커스·현재 행에서만(상시 5개 노출 방지). 터치(시트): 44×44 상시. 키보드는 항상 탭으로 도달 |
| 확인 | **행 안 확인**(스낵바 실행 취소 아님). `hide`에는 unhide가 없어 취소가 불가하기 때문. 아이콘을 누르면 같은 행이 `제목 / "이 대화를 목록에서 숨길까요?" / [취소] [숨기기]`로 바뀜. 현재 대화면 "지금 보고 있는 대화예요. 숨기면 새 대화로 바뀌어요." |
| 취소 | `취소` 버튼 · Esc · 포커스가 그 행 밖으로 나가면 취소(마우스 hover 해제만으로는 취소하지 않음). 기본 포커스는 **취소** |
| 완료 | `chat.hideSession(id)`(기존). 현재 대화면 `newChat()`가 불리고 팝오버 닫힘 |
| 대안 | 즉시 숨김(확인 없음)은 결정 항목 D3 |

### 2.5 카운터 `n/10` 위치

| 후보 | 장점 | 단점 | 판정 |
|---|---|---|---|
| **입력창 아래 줄 오른쪽(모델 pill 맞은편)** | 새 줄이 안 생김. 입력 결정 지점 옆. 버튼 모양 아님 | 헤더보다 덜 눈에 띔(8개 이상은 강조로 보완) | **채택** |
| 헤더(버튼 옆) | 한눈에 | 헤더가 380에 이미 312라 못 들어감. 입력과 멀다 | 기각 |
| 팝오버 행 메타(`질문 3/10`) | 대화마다 확인 | 현재 대화의 남은 수를 보려면 열어야 함 | **보조로 병행** |

규칙: n≥1에서만 표시. 1~7 `inkMuted` 12px / 8~9 `⚠ 질문 8/10 · 2개 남음` warnText 13px w700 / 10 입력 비활성(§2.6). 키 `ask-count` 유지, 스크린리더 라벨은 기존 `askCountLabel`, 임계 안내는 기존 `SemanticsService` 유지.

### 2.6 한도 도달

| 항목 | 값 |
|---|---|
| 안내 위치 | **스레드 끝 카드**(`ask-limit-banner` 키 유지): "이 대화에서 질문 10개를 모두 사용했어요. 새 대화를 시작해 계속 질문하세요." + 보라 채움 CTA `새 대화` |
| 입력창 | 비활성 + 힌트 "새 대화를 시작하세요", 전송 비활성, 카운터 `⚠ 질문 10/10` |
| 새 대화 유도 | CTA는 카드의 1개만 채움(헤더의 새 대화는 톤 유지, 보라 채움 중복 방지). CTA와 헤더 버튼은 같은 `newChat()` 후 입력창 포커스 |
| **빈 스레드 + 한도(필수)** | `questionLimit` 거절(`drop()`)로 유일한 턴이 지워지면 `turns`는 비는데 `limitReached`는 true(테스트 `question limit refusal`이 정확히 이 경우, ✅ `ask_history_test.dart:334`). `AskEmptyHint` 대신 **`ListView`를 `turns.isNotEmpty \|\| limitReached`일 때 그린다** → 카드만 있는 스레드. 입력창엔 거절된 질문 텍스트가 돌아와 있음(기존 동작). 카드를 `AskEmptyHint` 위에 얹는 안은 예시 카드가 한도 상태에서 눌려 보이므로 기각 |
| 모바일 | 카드 아래 CTA 44px. 카드는 스크롤 끝에 있어 자동 스크롤로 보임(`_scrollToEnd`) |

### 2.7 빈 목록 · 오류

| 상태 | 표시 |
|---|---|
| 빈 목록 | 버튼은 **비활성 아님**(열림). `🕘 최근 30분 안의 대화가 없어요 / 마지막 질문 후 30분 동안 보여요.` + 푸터 |
| 열 때 갱신 | `refreshRecent()`(기존). 이전 목록을 먼저 보이고 조용히 교체. 실패는 기존처럼 조용히(목록 유지) |
| `notFound`(열었더니 사라짐) · `expired` · `loadFailed` | 팝오버가 닫힌 뒤 **스레드와 입력 패널 사이 한 줄 안내**(패널 밖, `aria-live polite`). `busy`도 같은 자리 |

### 2.8 끊긴 답변

위치 그대로(해당 답변 카드 아래 `AskTurnView`, `turn.cutOff`). 개선만: `다시 질문` 버튼을 칩급 pill로(터치 44 / 데스크톱 36), 시맨틱 힌트 "질문을 입력창에 채워 줘요"(전송하지 않음). 목록 행에는 표시하지 않음(API 불변).

### 2.9 고지 문구 위치

| 항목 | 값 |
|---|---|
| 현행 | 스레드 위 닫을 수 있는 배너(`_HistoryNotice`) + 설정 화면(`settings_screen.dart:119`) |
| 제안 | **배너는 그대로 둠**. 팝오버 푸터에 한 줄(보관 사실)을 **추가**: 숨기기 동작이 거기 있으니 같은 자리에서 사실을 알려 주는 것이 정직함 |
| 주의 | 고지 문구 자체·위치는 research 030의 결정 D9(무료 모델 이력 전송 고지)와 맞닿음. **배너를 옮기거나 문구를 바꾸는 것은 D9 결정 후** — 이 설계는 푸터 한 줄 추가만 제안(결정 D2) |

### 2.10 키보드·스크린리더

| 대상 | 규칙 |
|---|---|
| 포커스 순서 | 헤더: 최근 대화 → 새 대화 → (팝오버 열림: 첫 행) → 스레드 → 입력 … |
| 최근 대화 버튼 | `PbInteractive`, `label: "최근 대화"`, `expanded: _open`, Enter/Space로 열기, 열리면 **현재 행**에 포커스(없으면 첫 행) |
| 팝오버 | ↑↓ 행 이동, ←→ 행 안(선택 ↔ 숨기기), Enter 선택, Esc 닫고 버튼으로 포커스 복귀. ⚠️ 자체 `PopupMenuEntry` 안 두 정지점의 화살표 동작은 **위젯 테스트로 확인 전까지 미확인**(앱 기본 단축키 `DirectionalFocusIntent`는 웹·데스크톱에서 ✅ 확인) |
| 행 | `Semantics(button, selected: 현재, label: "{제목}, 질문 3/10, 12분 전, 현재 대화")` |
| 숨기기 | 라벨 "목록에서 숨기기: {제목}". 확인 행은 `liveRegion` + 취소에 포커스 |
| 카운터 | 기존 라벨 유지(시각 텍스트는 `excludeSemantics`) |
| 링 | `focusRing` 2px ink + 2px 간격(`PbInteractive`에 내장). 팝오버 행은 inset 링 2px(클리핑 회피, 채움 보라 위 아님) |

### 2.11 기록 꺼짐 (현행과 동일해야 함)

`historyStatus` 꺼짐·실패·null: **새 헤더·카운터·대화 바 모두 없음.**

| 폭 | 헤더 |
|---|---|
| ≥1024 | 원래 그대로: `💬 질문` + 새 질문 아이콘 버튼(`tooltip: 새 질문`, `turns.isEmpty`면 비활성) |
| <1024 | 헤더 없음(원래도 없었음) |

이 상태에서만 "새 질문"이라는 원래 이름을 유지(대화·문맥이 없고 화면만 비움). 회귀 테스트 `flag off`, `status fails` 유지(§6.5).

---

## 3. 대안 비교

| | **A 헤더 두 버튼 + 팝오버/시트 (추천)** | B 제목 칩 + 메뉴 | C 좌측 대화 패널 | D 입력창 위 한 줄로 축소 |
|---|---|---|---|---|
| 개요 | `[🕘 최근 대화 ▾][＋ 새 대화]` | `[🕘 4분기 출시 계획… ▾]` 메뉴 첫 항목이 "새 대화" | 대화 목록을 항상 보이는 열로 | 현행 칩 줄을 12px 한 줄로 |
| 새 대화 | 1탭, 항상 보임 | 2탭(메뉴 안) | 1탭 | 1탭 |
| 현재 대화 인지 | 팝오버에서 확인 | **제목이 항상 보임** | 항상 보임 | 약함 |
| 입력창 혼잡 | 칩 줄 1개 감소 | 감소 | 감소 | 변화 적음 |
| 380 열 | 적합(312/344) | 적합, 제목이 길면 폭 잠식 | **부적합**: 목록 96이면 스레드 260. 인용 카드·칩 붕괴 | 적합 |
| 폰 | 헤더 +52 | 동일 | 드로어 필요(구현 2갈래) | 변화 없음 |
| CTO 제안 | 일치 | 부분 | 아님 | 아님 |
| 단점 | 헤더 한 줄 추가(폰) | 자주 쓰는 동작이 숨음 | 최대 5개·30분 목록에 상시 면적 | 근본 원인(혼잡·헤더 부재) 그대로 |

C가 부적합한 숫자: 데스크톱 Ask 열은 `main.dart`에서 **380 고정**. 목록 패널 96을 빼면 스레드 폭 ≈ 260.

**추천 = A.** 이유: ① CTO 요구와 일치 ② 입력 패널에서 대화 관리를 제거(P1·P7·P8 해결) ③ 이름·조건 하나로 통일(P2) ④ 앵커 팝오버로 열려 어포던스와 동작이 맞음(P3) ⑤ 380·390에서 가로 여유가 있음 ⑥ 기존 `PbInteractive`·`pbShowMenu`·시트 코드를 재사용.

---

## 4. 반응형

| 폭 | 헤더 | 최근 대화 | 높이·터치 | 비고 |
|---|---|---|---|---|
| **데스크톱 ≥1024** (Ask 열 380) | `💬 질문`(좌, 기존) + `[최근 대화 ▾][＋ 새 대화]`(우, 원래 새 질문 아이콘 자리) | **앵커 팝오버** 폭 340, 버튼 아래 오른쪽 정렬 | 버튼 36(pbTarget), 행 56+ | 팝오버가 열(380) 밖으로 안 나감 |
| **태블릿 600–1023** (본문 ~590) | **제목 없이** 두 버튼 좌측 정렬, Ask 본문 위 한 줄(기록 켜짐일 때만) | **앵커 팝오버** 폭 360(다이얼로그 폐기) | 버튼 40(터치 영역 44) | 마우스+터치 모두. 전역 AppBar는 그대로 |
| **모바일 <600** | 태블릿과 같은 한 줄(AppBar 아래), +52px | **바텀시트**(`showModalBottomSheet`, 드래그 핸들, 현행 코드 재사용) | 버튼 40(터치 44), 행 64, 숨기기 44×44 | 엄지 영역. 입력 패널은 칩 줄 1개 감소로 높이 상쇄 |
| 폭 모자람(가용 <약 300 또는 텍스트 배율↑) | `새 대화` 라벨 접어 **아이콘만**(툴팁·시맨틱 유지) | 라벨 유지 | 36/44 | `LayoutBuilder`. ✅ 시안 ⑬ |

헤더 구현 폭 기준: 아이콘 버튼 전환 임계값은 구현 때 `TextPainter`로 측정(⚠️ 임계값 미정).

---

## 5. 시안 안내 (`states.html`)

| 절 | 내용 |
|---|---|
| ① | 현재 UI 재현(데스크톱·모바일) + 문제 요약 |
| ② 기본 | 새 대화(빈 상태), 새 대화 버튼은 활성(입력창 포커스) |
| ③ 대화 중 | 카운터 `질문 3/10` 입력창 아래 줄 오른쪽 |
| ④ 최근 대화 열림 | 팝오버/시트, 현재 대화 강조, hover 행의 숨기기 |
| ⑤ 숨기기 확인 | 행 안 확인, 현재 대화 문구 |
| ⑥ 빈 목록 | 이유 안내 |
| ⑦ 8개 이상 | `⚠ 질문 8/10 · 2개 남음` |
| ⑧ 한도 도달 | 스레드 끝 카드 + 비활성 입력 |
| ⑨ 끊긴 답변 | 다시 질문 |
| ⑩ 기록 꺼짐 | 현행 헤더(데스크톱 아이콘만, 폰 없음) |
| ⑪ 포커스·hover | 링 2px ink |
| ⑫ 영어 | `Recent` / `New chat`, 팝오버 `Recent chats` |
| ⑬ 아이콘 전용 | 폭 부족 |
| ⑭ 안내 줄 | busy / expired / notFound / loadFailed |
| ⑮ 반응형 | 1200 / 768 / 390 배치 |
| ⑯⑰ | 대안 B·C·D 스케치와 비교표 |

토큰은 `theme.dart`(`Pb.light`/`Pb.dark`)와 `interaction-states-spec.md` §3.1 값:

| 토큰 | 라이트 | 다크 | 이 설계의 쓰임 |
|---|---|---|---|
| `ink` / `inkMuted` | `#1F1B16` / `#5C5348` | `#F2EDE3` / `#B5AD9F` | 제목 / 메타·카운터 |
| `hairline` | `#E4DDD0` | `rgba(255,255,255,.14)` | pill 테두리 |
| `chipBg` | `rgba(255,255,255,.55)` | `rgba(255,255,255,.05)` | 최근 대화 pill 면 |
| `accentContainer` / `onAccentContainer` | `#EAE4FD` / `#2E1F85` | `#3A2F7A` / `#E9E3FC` | 새 대화 pill, 현재 행 |
| `sheet` | `#FEFAF8`(⚠️ 시안값, 앱은 `0xDBFFFDFA` 알파) | `#282130` | 팝오버·시트 면 |
| `warnText` / `warnContainer` / `warnBorder` | `#92400E` / `#FEF3C7` / `#B45309`@55% | `#FBBF24` / `#3A2A0A` / `#FBBF24`@50% | 8개 이상·한도·숨기기 확인 |
| `hover` / `press` | `ink`@6% / 12% | 흰색@6% / 12% | 행·버튼 상태 |
| `focusRing` | `#1F1B16` | `#F2EDE3` | 2px + 간격 2px |
| `accent` | `#6C4CF5` | `#B7A6FF` | 한도 CTA(채움)만 |

---

## 6. 구현 명세 (Flutter Material 3)

### 6.1 변경 파일

| 파일 | 변경 |
|---|---|
| `lib/features/ask/ask_screen.dart` | ① `_body`의 헤더(`if (wideHeader)` 블록) → `historyOn ? _AskHeader(...) : (wideHeader ? 원래 헤더 : 없음)` ② 컴포저의 `_ChatBar` 호출과 클래스 삭제 ③ `hint`를 `GlassPanel` 밖(스레드와 패널 사이)으로 ④ `_LimitBanner`를 스레드 `ListView` 마지막 항목으로 ⑤ `_ModelPill` 줄을 `Row(모델 pill, Spacer, _AskCounter)`로 ⑥ `_pickChat`: <600 시트 유지, ≥600은 앵커 메뉴(다이얼로그 제거) ⑦ `_RecentChats` → `_RecentList`(행·확인·푸터) |
| `lib/app/pb_interactive.dart` | `pbShowMenu`에 선택 인자 `BoxConstraints? constraints` 추가(`showMenu`가 지원 ✅; 기본 최대 폭 280이라 340 필요) |
| `lib/app/app_icons.dart` | `history = LucideIcons.history`, `hideChat = LucideIcons.eyeOff` 추가 |
| `lib/app/l10n.dart` | §6.4 문구 |
| `test/ask_history_test.dart` | §6.6 |
| **변경 없음** | `ask_chat.dart`(`newChat`·`hideSession`·`openSession`·`refreshRecent`·`level` 그대로), 서버·클라이언트 프로토콜 |

### 6.2 위젯 매핑

| UI | 위젯 | 메모 |
|---|---|---|
| 헤더 | `_AskHeader`(신규, `LayoutBuilder` + `Row`/`Wrap`) | ≥1024: 제목 + 우측 버튼. <1024: 제목 없이 좌측 정렬. 패딩 데스크톱 `fromLTRB(20,18,12,4)`(기존), 폰·태블릿 `fromLTRB(16,8,16,4)` |
| `[최근 대화 ▾]` | `PbInteractive`(+ `pbTint`, `pbShowMenu` 패턴; `_ModelPill`과 동일 구조) | 높이 36/40, 반경 999, `expanded: _open`, `label`, key `ask-recent`, 열린 동안 pressed 면 + ▾ 180° |
| `[＋ 새 대화]` | `PbInteractive`, 면 `accentContainer`, 아이콘 `AppIcons.newQuestion` | key `ask-new-chat`. `onTap`: 빈 대화면 `_inputFocus.requestFocus()`, 아니면 `_chat.newChat()` 후 포커스. **항상 활성**(`disabled` 없음) |
| 아이콘 전용 | 같은 위젯, 라벨 숨김 + `Tooltip` | 가용 폭 부족 시 |
| 팝오버 ≥600 | `pbShowMenu<int>(context, _anchor, [_RecentMenuEntry(...)], constraints: BoxConstraints.tightFor(width: 340))` | `_RecentMenuEntry extends PopupMenuEntry<int>`가 제목+행+푸터를 한 번에 그림. 내부 `ListenableBuilder(chat)`로 숨김 반영. 반경 14, 면 `sheet` |
| 시트 <600 | `showModalBottomSheet`(현행) + `_RecentList` | `showDragHandle`, `SafeArea` |
| 행 | `PbInteractive(expand: true)` 2개(선택 영역, 숨기기 버튼) | 행 면은 자체 `decoration` 색으로 그려 잉크 가림 문제 회피(기준안 원칙 5) |
| 숨기기 확인 | 같은 행 위치에서 `AnimatedSwitcher`(120ms) | 취소 버튼에 `autofocus` |
| 카운터 | `_AskCounter`(기존 `ask-count` 컨테이너를 테두리·배경 없는 `Text`로) | key `ask-count`, `Semantics(label: askCountLabel, excludeSemantics: true)` |
| 한도 카드 | 기존 `_LimitBanner`(key `ask-limit-banner`), `FilledButton` 유지, 스레드 `ListView`의 마지막 항목 | `itemCount: turns.length + (limitReached ? 1 : 0)`, 스레드 분기는 `turns.isEmpty && !limitReached ? AskEmptyHint : ListView` (§2.6 빈 스레드 행) |
| 안내 줄 | `Padding` + `Row(Icon, Text)` + `Semantics(liveRegion: true)` | `Expanded` 스레드와 `SafeArea` 컴포저 사이 |

### 6.3 제거할 기존 위젯

| 제거 | 위치 |
|---|---|
| 입력 패널 위 대화 바 `_ChatBar`(칩 3개: `ask-count` 칩, `ask-recent` ActionChip, `ask-new-chat` ActionChip) | `ask_screen.dart` ~318행 호출, 1430–1513행 클래스 |
| 패널 안 `hint` 텍스트 | ~326–340행 |
| 패널 안 `_LimitBanner` 호출 | ~341행 |
| ≥600 최근 대화 `showDialog` 분기 | `_pickChat` |
| 목록 행 휴지통 `AppIcons.delete` `trailing` | `_RecentChats` |

### 6.4 문구 (ko / en)

| 키 | ko | en |
|---|---|---|
| `recentShort`(헤더 버튼, 신규) | 최근 대화 | Recent |
| `recentChats`(팝오버 제목·접근성, 값 변경) | 최근 대화 | Recent chats |
| `newConversation`(헤더·CTA·툴팁, **en 값 변경**) | 새 대화 | New chat |
| `chatMetaN`(신규: 질문 수/한도·시각) | 질문 {n}/{m} · {ago} | Question {n}/{m} · {ago} |
| `currentChat`(기존) | 현재 | Current |
| `hideFromList`(신규, `removeFromList` 대체) | 목록에서 숨기기 | Hide from list |
| `hideAsk`(신규) | 이 대화를 목록에서 숨길까요? | Hide this chat from the list? |
| `hideAskCurrent`(신규) | 지금 보고 있는 대화예요. 숨기면 새 대화로 바뀌어요. | This is the chat you are viewing. Hiding it starts a new chat. |
| `hide` / `cancel` | 숨기기 / 취소 | Hide / Cancel |
| `recentChatsEmpty`(기존 문구 분리) | 최근 {m}분 안의 대화가 없어요 | No chats in the last {m} minutes |
| `recentFooter`(신규, `recentChatsNote` 확장) | 마지막 질문 후 {m}분 동안 보여요. 목록에서 숨겨도 서버에는 {d}일 보관돼요. | Shown for {m} minutes after your last question. Hidden chats are still kept on the server for {d} days. |
| `askAskAgainHint`(신규, 시맨틱 힌트) | 질문을 입력창에 채워 줘요 | Fills the question box |
| `newChat`(기록 꺼짐 헤더 전용, 기존) | 새 질문 | New question |

그 외(`askCount`·`askCountLeft`·`askLimitReached`·`askLimitHint` 등)는 그대로. "대화"를 쓰는 한국어는 이미 일관됨. 영어는 현재 "New conversation / New question"이 섞여 있어 "New chat"으로 통일.

### 6.5 접근성 라벨 요약

| 대상 | 라벨 |
|---|---|
| 최근 대화 버튼 | "최근 대화" · `expanded` |
| 새 대화 버튼 | "새 대화" (아이콘 전용일 때도) |
| 행 | "{제목}, 질문 3/10, 12분 전, 현재 대화" · `selected` |
| 숨기기 | "목록에서 숨기기: {제목}" |
| 확인 행 | `liveRegion` "이 대화를 목록에서 숨길까요?" |
| 카운터 | "이 대화에서 질문 10개 중 3개를 사용했어요"(기존) |

### 6.6 테스트 항목

**유지**(키가 같아서 대부분 그대로): `ask-count`, `ask-recent`, `ask-new-chat`, `recent-<id>`, `ask-limit-banner`.

| 테스트(`ask_history_test.dart`) | 변경 |
|---|---|
| **`question limit refusal: banner…` (334행)** | **영향 큼**: 빈 스레드에서 배너를 기대하므로 §2.6 "빈 스레드 + 한도" 규칙을 구현해야 통과. 단언은 그대로(`ask-limit-banner` 1개, 입력 텍스트 유지) |
| `restore…`, `a cut-off turn…`, `a turn the server is still finishing…`, `expired…`, `busy…`, `the input stops…`, `the notice shows once…`, `opening a conversation that is gone…`, `a restore that fails…` | 헤더 버튼·카운터 위치가 달라도 키·텍스트로 찾으므로 대체로 무변경. busy·expired 안내는 위치 이동뿐 |
| `counter: emphasis near the limit` (229행) | 카운터 텍스트는 같다. `AppIcons.warning` 개수와 배너 위치(`ask-limit-banner`가 스레드 안) 확인으로 갱신. "New conversation" 텍스트를 "New chat"으로 |
| `new conversation sends 0…` (209행) | 탭 대상은 키(`ask-new-chat`, 221행)라 그대로. 활성 상태 단언은 없음 ✅(비활성 규칙을 검증하는 테스트 없음). 364행 `findsNothing`은 기록 꺼짐 케이스라 유지 |
| **`recent list: rows, open, remove from list` (412행)** | **변경 필요**: `find.byIcon(AppIcons.delete)` → `AppIcons.hideChat`, 숨기기 후 **확인 단계(`숨기기` 버튼 탭)** 추가, 메타 문구 `3 questions · 12 min ago` → `Question 3/10 · 12 min ago`, 푸터 문구 |
| **`works on a phone width without overflow` (494행)** | **변경 필요**: 360 폭에서 헤더 한 줄(+`ask-recent`·`ask-new-chat`)과 하단 카운터 줄이 오버플로 없이 그려지는지. 텍스트 배율 1.3에서 새 대화가 아이콘만 남는지 추가 |
| **`flag off` / `status fails` (353행)** | **변경 필요**: 새 헤더 부재 확인 강화 — `ask-recent`·`ask-new-chat`·`ask-count` 없음 + **데스크톱(≥1024)에서 원래 새 질문 아이콘 버튼 있음·빈 대화에서 비활성, 폰 폭에서 헤더 없음** |
| 신규: 헤더 폭 | 380 열 ko·en 헤더 오버플로 없음(≥1024 레이아웃 폭 380 `SizedBox`) |
| 신규: 새 대화 빈 상태 | 빈 대화에서 새 대화 탭 → 서버 호출 없음, 입력창 포커스 |
| 신규: 키보드 | Tab 순서(최근 대화 → 새 대화), Enter로 열기, 열리면 현재 행 포커스, ↑↓로 행 이동, ←→로 행↔숨기기, Esc로 닫고 버튼에 포커스 복귀. ⚠️ 이 절은 **통과 전까지 미확인** |
| 신규: 시맨틱 | 행 `selected`, 최근 대화 `expanded`, 확인 행 `liveRegion` (`tester.getSemantics`) |
| 신규: 숨기기 확인 | 아이콘 탭 → 확인 행, 취소 → 원복(`askHideCall` 미호출), 확인 → 호출, 현재 대화 숨기기 → `newChat` |
| 신규: 모바일 시트 / 태블릿 팝오버 | 359 폭 시트, 768 폭 팝오버(다이얼로그 아님) |
| 신규: 한도 카드 | 카드가 스레드 마지막 항목, 입력 비활성, CTA로 `newChat` |
| 신규: **빈 스레드 + 한도** | `question limit refusal` 시나리오에서 `ask-limit-banner`가 보이고 `AskEmptyHint`는 없음, 입력창에 거절된 텍스트 유지, CTA 후 빈 상태(예시 질문)로 복귀 |
| 신규: 스트리밍 중 헤더 | 답변 중 `새 대화`·목록 선택 시 스트림이 끊기고 새 상태로 바뀜(현행 동작 보존) |
| 신규: 링 | `pbFocusRingKey`로 버튼 포커스 시 링 표시(기존 `pb_interactive` 테스트 패턴) |

---

## 7. 결정이 필요한 항목

| # | 질문 | 선택지 | 추천 |
|---|---|---|---|
| D1 | 동작 이름 | (a) "새 대화"로 통일 / (b) CTO 표현 "새 질문" 유지 | **(a)** 후속 질문도 "새 질문"이라 헷갈리고, 한도 문구·시트가 이미 "대화". 단 기록 꺼짐 헤더는 원래 "새 질문" 유지 |
| D2 | 고지 | (a) 배너 그대로 + 팝오버 푸터 한 줄 추가 / (b) 배너 제거, 푸터·설정만 / (c) 아무것도 안 바꿈 | **(a)**. 배너 이동·문구 변경은 D9 결정 뒤에 |
| D3 | 숨기기 확인 | (a) 행 안 확인 / (b) 즉시 숨김 | **(a)** unhide가 없어서 |
| D4 | 카운터 위치 | (a) 입력창 아래 줄 오른쪽 / (b) 헤더 | **(a)** 헤더는 380에서 여유 약 30 |
| D5 | 한도 카드 위치 | (a) 스레드 끝 / (b) 현행(입력창 위) | **(a)** |
| D6 | 태블릿 다이얼로그 | (a) 앵커 팝오버로 교체 / (b) 유지 | **(a)** |

미확인 요약(⚠️): 행 안 두 정지점의 화살표 이동, `PopupMenuEntry` 한 덩어리 안의 포커스 복귀, 서버 목록 정렬 순서, 시트 면 색의 실제 알파(`sheet` `0xDBFFFDFA`), 아이콘 전용 전환 임계 폭. 모두 위젯 테스트(§6.6)로 확인한다.
