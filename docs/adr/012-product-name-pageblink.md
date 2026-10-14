# 012 · 제품 이름 PageBlink, 패키지명까지 변경

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 (006 일부 대체: 패키지명) | 2026-10-14 | 사용자 결정 · [research 010~014](../research/) · [plan 004](../plan/004-naming-and-feature-vocabulary.md) |

## 맥락
작업명 `ragpod`는 RAG를 아는 개발자 외에는 뜻이 전달되지 않는다. 이름은 국내외(영어 데모·개발자 심사위원 + 한국 사용자) 모두에 통해야 한다. 4차례 조사로 약 110개 후보를 검토했다.

## 결정
- 제품 이름: **PageBlink** (페이지블링크). 태그라인 "Ask your documents. Blink to the page."
  - Blink = 오버워치 트레이서·스타2 추적자·WoW 마법사의 점멸 → "인용 탭 → 페이지로 즉시 이동"
  - 기능 이름은 게임 용어집(plan 004 §4) 사용: Cloak(기기 전용) · Recall(동기화) · Shared Vision(공유) · Ping(인용 공유)
- **코드 패키지명도 변경**: `pageblink_server` / `pageblink_client` / `pageblink_flutter`, 바깥 폴더는 `app/` 유지 (사용자 지시)
  - 방법: `serverpod create pageblink`로 재생성 후 기존 커스텀 코드(models·rag·providers·services·rag_endpoints·tests)를 이식. 마이그레이션은 새로 생성 (배포된 DB 없음)
- Cloud 프로젝트 ID 후보: `pageblink` (사용 가능 여부 미확인)

## 대안과 기각 이유
- Pagewarp: 개발자 도구 Warp(warp.dev, 문서 동기화 기능 보유)와 연상 충돌, warp = 뒤틀림
- Blink it: 인도 퀵커머스 앱 Blinkit과 동일 발음 / BlinkNote: 동명 iOS 노트 앱
- 패키지명 `ragpod_*` 유지: 사용자가 전체 변경을 지시

## 결과
- 👍 데모 스토리와 기능 용어가 한 세계관 (Blink · Recall · Cloak · Shared Vision)
- 👎 Blinkist(책 요약, PDF 질의 기능 보유)와 "Blink~" 소리 근접 → 정식 출시 전 상표(Class 9, 42) 확인
- 🔁 재검토: 상표·스토어 조사에서 충돌 확인 시
