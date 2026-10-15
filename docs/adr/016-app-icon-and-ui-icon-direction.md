# 016 · 앱 아이콘은 V1b Sparkle Fold, UI 아이콘은 Lucide 스트로크 먼저

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-15 | 클라이언트(사용자) 결정 · [1차 시안 spec](../design/icon-proposals/spec.md) · [2차 시안 spec](../design/icon-proposals/app-icon-v2/spec.md) · [research 017 §6](../research/017-flutter-ux-issues-investigation.md) |

## 맥락
앱 아이콘이 Flutter 기본이고(✅), 앱 안 아이콘은 Material `Icons.*`를 `AppIcons` 같은 래퍼 없이 직접 쓴다(✅ 9개 파일 · 67회 · 38종, research 017 §6). 1차 시안은 번개 기반(P1~P3)이었고 클라이언트가 "앱 아이콘에서 번개를 빼고 반짝 별을 선호"한다는 피드백을 주어 2차(V1a~V4)를 그렸다. 읽기/편집 토글의 눈(`visibility`) 아이콘은 다음 모드를 보여줘서 모호하다(✅ 1차 spec §1).

## 결정
1. **앱 아이콘은 V1b "Sparkle Fold"로 확정.** 접힌 페이지 모서리가 4꼭지 반짝 별이 되는 안이며 번개는 없다.
2. **앱 안 UI 아이콘 세트는 S1 Lucide 스트로크(`lucide_icons_flutter`)를 먼저 적용**하고, 마음에 들지 않으면 **S3 커스텀 bold로 교체**한다(클라이언트가 명시한 순서).
3. **번개(⚡)는 앱 아이콘에서 빼고 앱 안 인용 칩 `⚡n`에만 남긴다.**
4. **눈(visibility) 아이콘은 라벨 있는 읽기 | 편집 세그먼트 토글로 대체한다.**

## 대안과 기각 이유
| 대안 | 기각 이유 |
|---|---|
| 1차 P1 접힌 페이지+번개 / P2 책갈피+번개 / P3 하이라이트 줄 | 번개를 앱 아이콘에서 빼기로 함 (P1은 1차 spec의 추천안이었음) |
| 2차 V1a 하이라이트 끝 반짝 | 16px에서 화살표(→)로 오독, 요소가 가장 많음 |
| 2차 V2 커서 페이지 / V4 접힌 모서리 | 의미·차별성 부족 |
| 2차 V3 인용 괄호 `[ ✦ ]` | **차선.** 노트 앱 느낌이 약하고 코드 앱처럼 보일 수 있음 |
| UI 세트 S2 Phosphor duotone (`phosphor_flutter`) | pub.dev에 플랫폼 태그 없음 + `has:error`(✅), **원인 미확인 ⚠️**. 듀오톤 면이 파스텔 카드와 겹쳐 탁해질 수 있음(시안 판단) |

## 결과
- 👍 앱 아이콘이 "노트 + 깜빡"을 한 표식으로 전달하고, V1b는 16px 식별이 2차 5안 중 가장 안정적(✅ 시안 spec, 눈으로 확인)
- 👍 번개는 "지금 근거로 점프"(앱 안), 반짝은 "근거를 찾아 줌"(아이콘)으로 역할이 갈림
- 👍 Lucide 변환표가 현재 `Icons.*_outlined`와 거의 1:1이라 교체 비용이 작음
- 👎 V1b는 우상단 별 때문에 일반 "AI 반짝" 배지와 비슷해 보일 수 있음 (디자이너 약점 메모)
- 👎 16px 전용 단순판, Android adaptive 적용본, macOS판, monochrome(테마 아이콘)·iOS 틴티드는 **미제작 ⚠️**
- 🔁 재검토: S1 적용 후 클라이언트가 톤이 맞지 않다고 하면 S3 커스텀 bold로 교체 (세트 교체 비용은 `AppIcons` 래퍼 한 곳으로 한정)

## 후속 (미실행 ⚠️)
- `AppIcons` 래퍼 도입 + Lucide로 교체 (research 017 §6 제안: 신규 1 + 기존 9개 파일 약 67곳)
- V1b 앱 아이콘을 플랫폼 폴더에 적용: 시안 자산은 `docs/design/icon-proposals/app-icon-v2/v1b-sparkle-fold/`에 있고, `flutter_launcher_icons` 실행·적용은 아직 안 함
- 읽기 | 편집 세그먼트 토글 구현 (`SegmentedButton`, 시안 spec §4.3)
