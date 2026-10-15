# 018 · 본문 폰트를 Pretendard 한 가족으로 통일

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-15 | 클라이언트(사용자) 결정 · [research 022](../research/022-flutter-web-korean-glyph-first-load.md) · 커밋 `a954276` |

## 맥락
- 첫 로드에서 한글이 □(두부)로 보이는 문제가 있었다 ([research 022](../research/022-flutter-web-korean-glyph-first-load.md)). ✅
- 런타임 다운로드 폰트가 컸다: Inter는 굵기마다 약 325 KB(400 324,796 / 500 325,280 / 600 326,024 / 700 326,444 B), Noto Sans KR 런타임은 약 20 MB. ✅ 실측
- 영문(Inter)과 한글(Noto)이 두 폰트라 굵기·글자 높이가 어긋나, 작은 한글이 어설퍼 보였다. ✅ 캡처 확인

## 결정
- **라틴·한글 본문은 Pretendard(SIL OFL 1.1) 서브셋 400/500/600 한 가족**으로 통일한다: `assets/fonts/Pretendard-{400,500,600}-subset.otf`.
- 영문 제목 Fraunces 600은 번들한다: `assets/google_fonts/Fraunces-SemiBold.ttf`. 한글 제목은 Noto Serif KR 600 서브셋을 유지한다.
- **Inter 런타임 다운로드와 Noto Sans KR 서브셋은 제거**한다.
- 700/bold는 번들하지 않고 가장 가까운 600 면으로 매칭한다. w700 요청 시 600과 픽셀 동일 ✅ 네이티브 테스트 · 웹 CanvasKit ⚠️ 미확인.
- **라이선스**: Pretendard가 예약한 이름("Pretendard", Inter, Source 등) 때문에 서브셋 내부 이름을 "PageBlink Sans"로 바꿨다. 파일명·Flutter family는 `PretendardSubset`. `assets/fonts/OFL-Pretendard.txt`에 전문과 변경 고지를 둔다.

## 대안과 기각 이유
| 대안 | 기각 이유 |
|---|---|
| A+B: Noto Sans KR 500·700 추가 + 튜닝 | 첫 로드 합계가 약 4.1~4.8 MB로 늘어남. 두 폰트 혼용 문제도 그대로 |
| D: 힌팅 포함 정적 폰트 | 효과 불확실 ⚠️ |
| 현 상태 유지 | □ 문제와 20 MB 런타임 다운로드가 남음 |

## 결과
**번들 크기** ✅ 실측

| 파일 | 크기 (B) |
|---|---|
| Pretendard 400/500/600 서브셋 | 1,061,296 (4굵기였다면 약 1.41 MB, 400+600만이면 706,944) |
| Fraunces 600 | 71,608 |
| Noto Serif KR 600 서브셋 | 1,473,372 |

- 👍 첫 로드 폰트 전송 약 3.2~3.8 MB → 약 2.6 MB. 한글이 같은 px에서 약 6% 좁아짐(캡처 비교)
- 👍 한 가족이라 영문·한글의 굵기·높이가 맞음. 런타임 폰트 다운로드 의존이 사라짐
- 👎 Bold(700) 면이 없어 굵기 구분이 500/600 두 단계로 제한됨
- 👎 **CDN 캐시 지연**: Google CDN(`s-maxage=86400`)이 같은 URL의 `FontManifest.json`을 최대 24시간 캐시해, 배포 후 폰트 선언 반영이 늦어질 수 있음. ✅ 실측: origin 2,661 B vs CDN 2,493 B (research 022 조사 후 확인)
- 📝 **미적용 제안**: B 튜닝안(≤13px w500, bodySmall 12→13, `inkMuted` 라이트 `#5E564B`·다크 `#B5AD9F`)은 제안만 있고 적용 전. [ui-polish](../design/ui-polish/spec.md) UP-02가 같은 방향
- 📝 한글 제목 폰트 1.47 MB가 단일 최대 파일. 약 1,000자로 줄이면 약 0.65 MB 가능하나 미적용
- 🔁 **되돌리기**: 커밋 `a954276` 하나를 `git revert` (삭제된 Noto Sans KR 파일도 함께 복구)
- 🔁 재검토: 웹 CanvasKit에서 w700 매칭이 어색하게 보이면, 또는 Pretendard 700 면이 필요한 디자인이 생기면

관련: [ADR 016](016-app-icon-and-ui-icon-direction.md) · [ADR 017](017-image-generation-model-guidance.md) (같은 날 결정된 디자인 방향)
