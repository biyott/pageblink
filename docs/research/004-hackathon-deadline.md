# 004 · 해커톤 마감 시각

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | "Build Something Real: The Serverpod Hackathon"의 정확한 제출 마감(날짜·시각·시간대)은? 한국 시간으로 10/14인가 10/15인가? |
| 결론 한 줄 | **2026-10-14 21:59 UTC = 10/15(목) 06:59 KST** (유럽 CEST 10/14 23:59로 추정) |
| 반영 | [README](../../README.md) · [plan 002](../plan/002-rag-assistant-plan.md) · [plan 003](../plan/003-tech-stack-and-prep.md) |

## 핵심 결론

| 시간대 | 마감 |
|---|---|
| UTC | 10/14 21:59 |
| CEST (UTC+2, 주최사 시간대 추정) | 10/14 23:59 |
| **KST (UTC+9)** | **10/15 06:59** |

## 상세

### ✅ 확인된 것 (행사 페이지에 포함된 이벤트 메타데이터, JSON-LD)
- 시작: `"startDate":"2026-09-15T15:30:00+00:00"`
- 종료: `"endDate":"2026-10-14T21:59:00+00:00"`
- 화면 문구: 5주간, 상금 $20,000, 에이전트 코딩 지원
- 이 값이 "제출 마감"이라고 명시된 곳은 없고, 화면에 시간대 표시도 없음

### ⚠️ 미확인
- Serverpod(스웨덴) 주최 → 서머타임(10/25까지)이므로 "10/14 23:59 CEST" 마감으로 추정
- LinkedIn(Serverpod Growth Lead): "Our hackathon is on until Oct 14th. $20,000 in prizes." — 시각·시간대 없음
- Meetup: "Tue, Sep 15 · 1:00 PM BRT" (= 16:00 UTC, 시작 시각과 대략 일치)
- 검색 요약: Serverpod가 백엔드를 구동해야 함, 개인·팀 참가 가능, Devpost로 데모 영상·설명 제출 — 다른 Serverpod 해커톤일 수도 있고 Devpost 페이지는 403/410
- 심사 기간·수상 발표일은 찾지 못함
- BuilderBase 데이터 API는 `"Authentication required"`

### 기존 보고서와의 차이
- [plan 001](../plan/001-hackathon-topic-report.md)의 "10/14 23:59"는 시간대가 없었음 → 한국 시간 기준으로 읽으면 **7시간 일찍** 잡은 셈

## 권장
- **절대 마감: 10/15 06:59 KST**. 제출 폼이나 Discord에 다른 시각이 있으면 그것을 따름
- 여유를 두고 06:15 전후 제출 목표

## 출처
- https://builderbase.com/event/build-something-real-the-serverpod-hackathon
- https://se.linkedin.com/in/viktorlidholt
- https://www.meetup.com/flutter-joao-pessoa/
- https://serverpod.devpost.com/ (403)
