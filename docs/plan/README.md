# 📐 기획·설계 (Plan)

제품 컨셉, 아키텍처, 기술 스택, 로드맵처럼 **계속 갱신되는 계획 문서**를 둡니다. 근거는 [`../research/`](../research/), 확정한 결정은 [`../adr/`](../adr/)를 링크합니다.

## 규칙

| 항목 | 규칙 |
|---|---|
| 파일명 | `NNN-kebab-주제.md` (3자리 일련번호) |
| 머리말 | 작성일 · 최종 수정일(KST) · 관련 문서 링크 |
| 수정 | 자유롭게 갱신하되, 결정이 바뀌면 ADR을 먼저 쓰고 여기에 반영 |
| 표기 | ✅ 확인 · ⚠️ 미확인 |

## 목차

| # | 문서 | 내용 |
|---|---|---|
| [001](001-hackathon-topic-report.md) | 해커톤 주제 선정 보고서 | 30개 주제 분석, 심사 기준 역산, Top 5, 3주 로드맵 (마감 시각은 [research 004](../research/004-hackathon-deadline.md)로 정정) |
| [002](002-rag-assistant-plan.md) | 하이브리드 문서 RAG 비서 기획·아키텍처 | 온디바이스/온라인 분리, Cloud 구성, 계층·동기화·공유 설계, 차별화 15선, 로드맵 |
| [003](003-tech-stack-and-prep.md) | 기술 스택 결정 & 개발 전 준비 | SDK·패키지 버전, AI 제공자, 환경 진단, 모노레포 구조, 오늘 밤 타임라인·게이트 |
| [004](004-naming-and-feature-vocabulary.md) | 제품 이름 후보 & 기능 이름 용어집 | 숏리스트(Pinpage·Burrow·Docparty·Pagewarp·Savepoint), 후보 50개 마스터 표, 게임 용어 기능 어휘집 (결정 대기) |
| [005](005-follow-up-spec.md) | 후속 기능 명세 | 해커톤 이후 항목별 목적·사용자 스토리·구현 메모·수용 기준·우선순위(P1~P3): 원본 PDF 서버 저장, Cloak, 하이라이트, Recall, Gemini 직접, Future Calls 등 |
| [006](006-demo-script.md) | 데모 영상 대본 (2분) | 시간별 화면·영어 내레이션·보여줄 포인트, 아키텍처 슬라이드, 촬영·업로드/제출 체크리스트 |
| [007](007-landing-sign-in.md) | 첫 화면(랜딩 + 로그인) 기획 | 5초 안에 전달할 것, 영/한 카피, 데스크톱 분할·모바일 스택 레이아웃(AB Glass Paper 토큰), Flutter 위젯 트리·L getter 목록, 수용 기준 |
| [008](008-submission-kit.md) | 해커톤 제출 키트 | BuilderBase 제출용 영문 텍스트(이름·태그라인·짧은/전체 설명·기술 스택), LinkedIn·X·Bluesky 포스트(보너스), 제출 체크리스트, 영문 주장↔근거 표 |
