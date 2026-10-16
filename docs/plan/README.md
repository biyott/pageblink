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
| [009](009-demo-video-plan.md) | 데모 영상 제작 계획 (자동 녹화·편집) | 영어 전용 2:00 스토리보드, 실제 녹화(Playwright) vs Higgsfield(인트로·아웃트로만), 시드 데이터, TTS·자막·ffmpeg 파이프라인, 사용자 수동 작업, 위험, cli-hub 판단 |
| [010](010-pdf-search-column.md) | PDF·노트 검색용 컬럼(`searchText`) 수정 계획 | PDF 본문 검색 불가 원인(NFD/NFC 포함), 제목+주요 텍스트만 담은 검색 컬럼, 서버 `searchDocuments`(ILIKE·ACL), 마이그레이션·백필, 작업 분해·수용 기준·테스트·위험·롤아웃 |
| [011](011-pdf-form-field-fallback.md) | 폼 입력란 전용 PDF 텍스트 추출 폴백(pdf.js) 계획 | PDFium 0자 vs PyMuPDF 537자 재현, 후보 비교(pdf.js·pdf-lib·PDFium 직접·서버 비추), JS interop 구현·수용 기준·위험 (P3) |
| [012](012-session-handoff.md) | 세션 인수인계: 작업 방식·하네스·현재 상태 | 역할·규칙, 워크트리 검증·무접촉 커밋·scloud 배포 절차, 현재 git·배포 상태, 이어서 할 일 체크리스트, 알려진 주의사항 |
| [013](013-ui-polish-status.md) | UI polish(UP-01~22) 현황 감사와 남은 일 | 코드로 검증한 항목별 상태(✅1·🟡5·⬜14·⛔2, UP-04는 14차 구현 반영)·근거(파일:줄)·효과/비용/의존, 클라이언트 피드백 반영 현황, 묶음별 실행 순서·수용 기준·검증, 012 ⑤ 정정, 재검증 명령 |
| [014](014-demo-account.md) | 데모 체험 로그인(demo 계정) 설계 명세 | `Try the demo` 버튼, `pod.start()` 뒤 멱등 `DemoUser.ensure()`, `demoEnabled` 플래그(기본 꺼짐), 쓰기 가능한 공유 계정의 한도·정리·보호(§10 확정 값), 변경 지점·데이터 흐름·테스트·구현 순서·위험, §11 소스 검증 결과([research 026](../research/026-demo-account-api-verification.md)) (배포 완료 9차 `2801184` — 언어별 demo 계정·`SamplePack`([ADR 022](../adr/022-per-locale-demo-accounts-sample-pack.md), §8.2·§13.4), 8차 `c99822f` 샘플 보강, 7차 `8445f02`, §12.2 수동 확인 ⚠️ 대기) |
| [015](015-followup-backlog.md) | 후속 개선 백로그 (다른 세션 인수인계) | 현재 상태(15차 `686e4aa`, 마이그레이션 체인, 환경값 이름, 라이브·demo 계정), 후속 개선 11개 항목(증거·파일·접근·완료 기준·위험·테스트·규모), 충돌 방지 규칙과 검증→커밋→배포 절차, 권장 진행 순서·의존 관계 |
