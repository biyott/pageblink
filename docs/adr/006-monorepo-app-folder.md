# 006 · 모노레포: 패키지명 `ragpod`, 바깥 폴더 `app/`

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | 사용자 결정 · [plan 003 §3](../plan/003-tech-stack-and-prep.md) |

## 결정
- `serverpod create ragpod` 후 바깥 폴더만 `app/`으로 변경 → `app/{ragpod_server, ragpod_client, ragpod_flutter}`
- Serverpod 3종의 형제 구조는 유지 (툴링 전제)
- 공유 순수 Dart 로직은 Phase 1에 `packages/ragpod_core/`로 분리. **오늘은 `ragpod_server/lib/src/rag/`에 Serverpod import 없이 작성**
- 의존은 단방향: core ← server / app, 앱은 `ragpod_client`로만 서버 호출

## 대안과 기각 이유
- `serverpod create app`: `package:app_*`처럼 이름이 너무 일반적
- 오늘 `ragpod_core` 분리: Cloud 배포가 서버 폴더 밖 경로 의존성을 올리는지 미확인 ⚠️ → G2에서 시험

## 결과
- 🔁 재검토: `serverpod start`가 바깥 폴더명에 의존하면 / G2에서 경로 의존성 배포 성공 시 core 분리
