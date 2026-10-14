# 004 · 제품 이름 PageBlink 확정 · 프로젝트 재생성

| 항목 | 값 |
|---|---|
| 상태 | ✅ 완료 |
| 단계 | Phase 0 · 서버 |
| 시작 | 2026-10-14 23:04 KST |
| 완료 | 2026-10-14 23:44 KST |
| 소요 | 약 40분 |
| 최종 수정 | 2026-10-14 23:57 KST |

## 목표
제품 이름을 확정하고, 프로젝트·패키지 이름을 `ragpod`에서 새 이름으로 바꾼다. 이름 후보는 기존 서비스·게임 용어와의 충돌 여부를 조사해 거른다.

## 작업 로그
- `23:04`–`23:39` 이름 조사 5라운드 (research 010~015). plan 004에 후보 50개 + 기능 용어집 정리

  | 라운드 | 범위 |
  |---|---|
  | 1차 | 한국어 로마자 |
  | 2차 | 국내외 공용 |
  | 3차 | Burrow 변형 · 게임 용어 |
  | 4차 | Warp 변형 · 블리자드/LoL 용어 · 기능 용어집 |
  | 5차 | Blink 충돌 확인 (research 014) → 실제 게임 스킬 (research 015) |

- (시각 확인 필요) 사용자 결정: **PageBlink**, 패키지명까지 변경 ([ADR 012](../adr/012-product-name-pageblink.md))
- `23:42` 프로젝트 재생성
  - 기존 커스텀 코드 백업 → `rm -rf app`
  - `serverpod create pageblink --database --auth --no-redis --webapp --no-website --ide claude --ide codex` → `mv pageblink app`
  - models · rag · providers · services · rag_endpoints · tests 이식, import 경로 `ragpod` → `pageblink` 치환
  - `http` · `crypto` 재추가, `passwords.yaml`에 키 자리 재추가
  - generate + create-migration (새 마이그레이션), `dart fix`
  - 서버 테스트 7개 통과 ✅
- `23:44` 커밋 `a8aeabe`. 문서(`AGENTS.md`, `README.md` 제목 "⚡ PageBlink", writer 지침, plan 003/004, `docs/README.md`)의 경로·이름 갱신

## 결과

### 이름 후보 탈락 사유 (주요)

| 후보 | 사유 |
|---|---|
| Burrow (단독) | Chrome 확장 "Burrow"와 충돌 |
| Pagewarp | warp.dev 연상 |
| Blinkit · BlinkNote | 동명 앱 존재 |
| **PageBlink** | ✅ 채택 |

### 도메인
- Serverpod Cloud 주소는 `<프로젝트ID>.<고정 도메인>` 형태
- Starter 플랜은 커스텀 도메인 불가 (Growth부터)
- 해커톤: 프로젝트 ID를 `pageblink`로 권장. 정식 출시 때 `pageblink.app` 등을 연결

## 문제와 해결
- 연구·ADR·과거 devlog에는 옛 이름 `ragpod`가 남아 있음 → **스냅샷이므로 유지** (이름 변경 이후 문서만 갱신)

## 결정 (→ ADR 링크)
- 제품 이름 PageBlink, 패키지 `pageblink_*` → [ADR 012](../adr/012-product-name-pageblink.md)

## 다음 할 일
- Cloud 프로젝트 ID `pageblink`로 launch (G2)
- 정식 출시 시 커스텀 도메인 연결 (Growth 플랜 이상)

## 변경 이력
- `2026-10-14 23:57` 최초 작성
