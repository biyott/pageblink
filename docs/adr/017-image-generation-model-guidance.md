# 017 · 이미지 생성 모델 사용 지침: 목업은 Nano Banana 2.1, 로고·아이콘 최종본은 손으로 쓴 SVG

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-15 | 클라이언트(사용자) 결정 · [Recraft 시험 노트](../design/icon-proposals/recraft-trials/notes.md) · 커밋 `1704da5` |

## 맥락
designer 에이전트의 기본 이미지 모델은 `google/gemini-3-pro-image`였다. OpenRouter `/models` 조회로 이미지 출력 모델 59개를 확인했다(✅ 2026-10-15). 앱 아이콘 시안 작업에서 `recraft/recraft-v4.1-vector`로 SVG를 4장 시험 생성했고, 결과를 손으로 쓴 시안(P1)과 비교했다.

## 결정
- **목업·무드보드 기본 모델은 `google/gemini-nano-banana-2.1`.** 오류 시 `google/gemini-3.1-flash-image` → `google/gemini-3-pro-image` 순으로 폴백한다.
- **로고·아이콘 최종본은 모델 생성물이 아니라 손으로 작성한 SVG**를 쓴다. `recraft/recraft-v4.1-vector`는 **형태 탐색용**으로만 쓴다.
- 대량 생성 전에 첫 1~2장의 실제 비용을 OpenRouter usage에서 확인한다(단가는 출력 토큰 기준).

## 대안과 기각 이유
| 대안 | 기각 이유 |
|---|---|
| 기본 모델을 `gemini-3-pro-image` 유지 | Nano Banana 2.1이 더 저렴하다는 판단(⚠️ 단가 추정, 아래 근거 참고) |
| Recraft V4.1 Vector 결과를 아이콘 최종본으로 사용 | 아래 시험 결과: 팔레트 이탈·메타데이터 비대·비정규 좌표·비결정성 (✅ 파일 직접 계측) |

## 근거 (시험 결과)
| 항목 | 결과 |
|---|---|
| 엔드포인트 | chat/completions가 아니라 `POST /api/v1/images` (`output_format:"svg"`) ✅ |
| 비용 | 장당 $0.08, 4장 합계 $0.32 (응답 `usage.cost`). generation id가 없어 `/generation` 교차 확인 못 함 ⚠️ |
| 팔레트 | 프롬프트의 `#7C5CFF`와 달리 `#6C2EFC`~`#6822F8`로 불일치, 장마다 값이 다름 ✅ |
| 파일 | C2PA 메타데이터 17.7KB가 파일의 76~96% ✅. `viewBox` 2048, 전체 캔버스 배경 path, 흔들리는 베지어 ✅ |
| 재현성 | seed 미지원 ✅ → 같은 프롬프트라도 매번 다름 |
| 한계 | 4장 1회 시험이라 통계적 결론 아님. 가격·파라미터는 2026-10-15 API 응답 기준 |

⚠️ Nano Banana Pro 장당 약 $0.134는 토큰 단가 × 1,120토큰으로 계산한 **추정**이며 실측하지 않았다. 다른 모델의 장당 추정도 미검증이므로, 첫 1~2장을 실측한 뒤 대량 생성한다.

## 결과
- 👍 목업 반복 비용이 줄어듦 (⚠️ 절감 폭은 실측 전)
- 👍 아이콘 최종본은 토큰 기반 결정적 SVG라 라이트·다크·적응형 변형을 일관되게 파생할 수 있음
- 👎 로고·아이콘은 사람이(또는 에이전트가 직접 SVG를) 작도해야 함
- 📝 변경된 파일: `.claude/agents/designer.md` (커밋 `1704da5`). ⚠️ 그 커밋의 문구는 "For logos and icons use `recraft/recraft-v4.1-vector`"라서 이 ADR의 "형태 탐색용으로만"과 어긋난다. 파일 수정은 이 ADR 범위 밖이며 후속으로 맞춘다
- 🔁 재검토: Recraft `controls`(팔레트 고정)·`input_references` 시험에서 최종본 품질이 나오면 (둘 다 미실행 ⚠️)
