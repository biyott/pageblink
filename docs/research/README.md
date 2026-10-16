# 🔎 조사 (Research)

서브에이전트가 조사한 결과를 **그 시점의 스냅샷**으로 남깁니다. 판단(결정)은 여기 쓰지 않고 [`../adr/`](../adr/)에 씁니다.

## 규칙

| 항목 | 규칙 |
|---|---|
| 파일명 | `NNN-kebab-주제.md` (3자리 일련번호) |
| 단위 | 조사 요청 1건 = 파일 1개 |
| 표기 | ✅ 공식 문서·pub.dev로 확인 · ⚠️ 미확인/추정/출처끼리 충돌 |
| 출처 | **필수**. 문서 끝에 URL 목록 |
| 수정 | 하지 않습니다. 정정이나 재조사는 새 번호로 쓰고 서로 링크합니다 |

## 템플릿

```markdown
# NNN · 제목

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose / claude-code-guide …) |
| 질문 | 무엇을 알아내려 했나 |
| 결론 한 줄 | |
| 반영 | 관련 ADR · plan 링크 |

## 핵심 결론
## 상세
## 미확인 · 리스크
## 출처
```

## 목차

| # | 제목 | 핵심 결론 | 반영 |
|---|---|---|---|
| [001](001-serverpod-cloud-pgvector.md) | Serverpod ORM·Cloud와 pgvector | ORM은 2.8.0+부터 Vector 지원 ✅ · Cloud DB의 pgvector는 문서 없음 ⚠️ | ADR 005, 008 |
| [002](002-flutter-ondevice-rag-stack.md) | Flutter 온디바이스 RAG 스택 | 오프라인 검색 + 온라인 생성이 v1 정답 · EmbeddingGemma 공용 | ADR 001, 002 |
| [003](003-competitors-and-gaps.md) | 경쟁 제품과 빈틈 | 문서 단위로 계층을 오가는 제품 없음 | plan 002 |
| [004](004-hackathon-deadline.md) | 해커톤 마감 시각 | 10/14 21:59 UTC = **10/15 06:59 KST** | README |
| [005](005-claude-code-agent-config.md) | Claude Code 서브에이전트·advisor 설정 | env + 에이전트 파일로 Sonnet/high 지정 · advisor effort 설정 없음 | ~/.claude 설정 |
| [006](006-llm-embedding-providers.md) | LLM·임베딩 제공자 | Claude Sonnet 5.5 + EmbeddingGemma(DeepInfra) | ADR 002, 004 |
| [007](007-serverpod4-setup-and-cloud.md) | Serverpod 4 셋업·Cloud 배포 | Dart ^3.12.2 · 사용자 ID UuidValue · `serverpod start` | plan 003 |
| [008](008-flutter-client-stack.md) | Flutter 클라이언트 스택 | Flutter 3.47.7 · Riverpod · pdfrx · gpt_markdown | plan 003 |
| [009](009-claude-md-agents-md-loading.md) | CLAUDE.md / AGENTS.md 로딩 규칙 | 폴더 README.md를 정본, AGENTS.md는 `@README.md` | ADR 007 |
| [010](010-product-naming.md) | 제품 이름 후보 30선 | Top 5: Dotori · 물어봐 · 주머니 · 햄찌 · Pagepin | 결정 대기 |
| [011](011-product-naming-global.md) | 제품 이름 후보 30선 (2차: 국내외 공용) | Top 5: Hutch · Burrow · Dogear · Hamstor · Pinpage | 결정 대기 |
| [012](012-product-naming-burrow-game-terms.md) | 제품 이름 3차: Burrow 변형 · 게임 용어 | Top 5: Pinpage · Burrowpin · Savepoint · Questpage · Pagewarp | 결정 대기 |
| [013](013-product-naming-warp-game-skills.md) | 제품 이름 4차: Warp 변형 · 게임 용어 · 기능 용어집 | Top 5: Pagewarp · Docparty · Savepoint · Pinpage · Blinkpage | 결정 대기 |
| [014](014-blink-name-conflicts.md) | Blink 계열 이름 충돌 확인 | PageBlink 1순위, Blinkit·BlinkNote 제외 | plan 004 |
| [015](015-game-skill-names.md) | 실제 게임 스킬·아이템 이름 30선 | Blink 유지(PageBlink), 기능 용어 Recall·Infrasight·Fog of War | ADR 012 |
| [016](016-openrouter.md) | OpenRouter (LLM·임베딩·무료 모델·요금) | LLM은 OpenRouter + [n] 인용, 임베딩은 DeepInfra 유지 | ADR 013 |
| [017](017-flutter-ux-issues-investigation.md) | Flutter 앱 UX 이슈 6건 (설정 전체화면 · 노트 원 모양 · 라이브 MD · 아이콘 · 문구) | 설정은 `Navigator.push`라 pane 밖 · 원 모양은 테마 enabledBorder(999)+filled가 원인 · 라이브 MD는 buildTextSpan 방식 추천 | 결정 대기 |
| [018](018-desktop-note-typography.md) | 데스크톱 노트 화면 기본 폰트 크기 조정안 | 편집 16 ↔ 미리보기 14 불일치 · h1~h4가 노트 제목보다 큼 · 폭 상한 없음 → 본문 16/1.7 + 680px 컬럼 + 제목 28/24/20/18 | 제안 단계 (ADR 대기) |
| [019](019-ask-screen-locale-chips-scope-model-picker.md) | Ask 화면·언어 설정 UX 3건 (언어 우선순위 · 예시 칩 잘림 · 범위/모델 선택) | 언어는 `main.dart` localeResolutionCallback이 선택을 덮어씀 · 예시 칩은 ActionChip 단일행 구조 · 범위는 FilterChip 체크가 아바타와 겹침, 모델 항목은 서버 note 중복 | 결정 대기 |
| [020](020-login-enter-key-and-password-manager.md) | 로그인 Enter 제출 · Chrome 비밀번호 저장 | 패키지 로그인 폼에 `onSubmitted`·`autofillHints`·`AutofillGroup` 없음(앱 래핑 아님) → 자체 로그인 폼(공개 `EmailAuthController` 재사용) · 실제 저장 프롬프트는 ⚠️ 미확인 · 가입·재설정 6개 화면도 후속 커밋 `9330713`으로 교체(§5, 13:02 갱신) | 코드 반영 |
| [021](021-sample-note-delete-and-project-edit.md) | 가입 시 샘플 노트 · 노트 삭제 UI · 프로젝트 수정/삭제 | 서버 `onAfterAccountCreated` 훅이 영어 샘플(할 일 목록)만 삽입 + 첫 로그인에 `locale`로 1회 현지화·색인 → 표식 테이블·마이그레이션 0 · `document.delete`는 이미 있고 UI는 길게 누르기뿐 · 프로젝트 update/delete는 새 엔드포인트 2개(FK 없음, 비어 있을 때만 삭제 추천) | 결정 대기 |
| [022](022-flutter-web-korean-glyph-first-load.md) | Flutter 웹 첫 로딩 때 한글이 깨져 보임 | 원인은 한글 번들 폰트 부재 → 엔진 폴백(두부 □) 후 `google_fonts` 런타임 로딩(Noto Sans KR 6.16 MB · Serif KR 14.05 MB)으로 2~3번 교체 ✅ · mojibake는 소스상 가능성 낮음(charset=utf-8 부여) · 해결은 한글 서브셋을 assets에 번들 추천, 실제 모양·서브셋 용량은 ⚠️ 미검증 | 결정 대기 |
| [023](023-live-markdown-editor-defects-and-roadmap.md) | 노트 라이브 마크다운 에디터 결함 4건 · 규칙 세트 · 로드맵 | 같은 레벨 제목 해제는 이미 동작(문제는 상태 표시·미니바·정규식 불일치) ✅ · 코드·굵게는 파서가 줄 단위라 줄을 넘으면 스타일 소실, 툴바가 그 텍스트를 스스로 만듦 · 링크는 스타일만, 열기·자동 링크 없음(`url_launcher`는 전이 의존성) · 규칙 16 적용(지원 5·부분 8·없음 3)/7 제외 · 추천 (a) 마커 흐림 유지, 제품 코드 약 600줄 ⚠️ | 결정 대기 |
| [024](024-live-editor-visual-ui-checkbox-codeblock-link.md) | 라이브 에디터 노션식 시각 UI 3종 (체크박스 · 코드 블록 · 링크 팝오버) | WidgetSpan 마커 대체는 불가(오프셋 2칸 어긋남 ✅) · 마커 투명 처리는 레이아웃·캐럿·조합 불변 ✅ · `TextField` 뒤 `CustomPaint`가 `getBoxesForSelection`으로 같은 프레임에 블록·박스를 그림 ✅ · 클릭은 `TextSpan.recognizer`(캐럿 불변·드래그 선택 정상 ✅) · 추천 A 3단계, 제품 약 1,000줄 ⚠️ | 결정 대기 |
| [025](025-pdf-drag-drop-upload.md) | PDF 드래그 앤 드롭 업로드 (드롭 존) | `desktop_drop` 0.8.4 하나로 웹·macOS 커버(Flutter 3.47.7 빌드·테스트 ✅) · 드래그 중 파일명은 못 읽음(Chrome은 MIME만 ✅) · 드롭 감지는 셸 최상위 1곳(데스크톱 Projects 탭·편집기에서 `DocumentsScreen`이 꺼짐) · 현재 업로드는 파일 1개만 처리, 요청 512 KiB 한도·PDF 크기 상한 없음, 스캔 PDF는 조용히 `ready` · 제품 약 350~450줄 ⚠️ | 결정 대기 |
| [026](026-demo-account-api-verification.md) | demo 체험 로그인: Serverpod 4.0.4 API 소스 검증 (plan 014 §11) | 8개 항목 모두 구현 가능 ✅ · `password: null` 계정은 비밀번호로 안 뚫림(빈 해시 → 검증 `false`, 실행 확인) · **`DemoUser.ensure()`는 `pod.start()` 뒤**(DB 풀·마이그레이션이 `start()` 안, plan §5.1과 다름) · 쿠키 모드는 `issueToken` 유지(`createToken`은 틀림) · JWT 액세스 10분/리프레시 14일, 만료 행 자동 삭제 없음 · 새 DB 컬럼 불필요(`contentHash` 표식, 단 `upload` 재시도·`saveNote` 신규·`reindexFailed` 가드 필요) · 배포 번들은 `web/` 안전(Cloud 빌드는 ⚠️) · Cloud는 `scloud variable set`으로 일반 변수 가능 ⚠️ 런타임 확인 | plan 014, ADR 020 |
| [027](027-citation-span-highlight.md) | 출처 클릭 시 본문 전체가 음영이 되는 문제: 임베딩 단위 · 근거 구간 하이라이트 · 표시 UX | 원인은 임베딩 단위가 아니라 인용 데이터 ✅ · OpenRouter 경로가 `quote`를 항상 빈 문자열로 보내 서버가 청크 전체(≈900자)를 `quote`로 채우고, 노트는 대개 1청크라 본문 100%가 칠해짐(샘플 3개 실행 확인) · 청크 축소(A)로는 안 고쳐짐 · 추천 B2(서버가 청크에서 1~2문장 선택) + 표시 U2 + 선택 색 중립화 · PDF 뷰어는 페이지 이동만(본문 하이라이트 없음) · 한국어 정확도·모델 준수율 ⚠️ 미측정 | ADR 021 (구현·배포 9차) |
| [028](028-locale-samples.md) | 언어별 demo 계정과 샘플 노트·질문 예시 스키마(SamplePack) | 스키마는 하나(`SamplePack`)면 됨 · 서버 Dart 상수 단일 원천 + `sampleHints()`로 질문 전달(DB 변경 0) · demo는 언어별 계정 2개(`demo@`=en 승계, `demo-ko@`) · 질문은 샘플 내용 언어 기준(A), 교차 언어 검색 입증 시 UI 언어(B)로 확장 · Ask 상한은 전체 공유 유지 · 시드 시간·비용 ⚠️ 미측정 | ADR 022 (구현·배포 9차) |
| [029](029-line-level-chunking.md) | 줄(블록) 단위 청킹 · 맥락 접두 · 재색인 마이그레이션 설계 (방안 A) | 노트는 마크다운 블록 인지 줄 단위(청크 = 본문의 정확한 부분 문자열), PDF는 문장 묶음 ≤300자, 맥락(제목 경로)은 임베딩 입력 `title:` 칸에만 · 스키마 변경 0(`Document.embeddingModel`에 `#c2` 표식) · 재색인은 문서 단위 조건부 교체로 부팅 후 백그라운드 · 설계 완료·구현·배포 완료(9차 `2801184`) | ADR 021, devlog 011 |
| [030](030-ask-sessions.md) | Ask 대화 기록·멀티턴·관리자 조회 설계 | 테이블 2개(`ask_session`·`ask_message`) + `ask()` 래퍼로 저장·복원 · 문맥은 턴 수가 아니라 문자 예산 · 추가형 마이그레이션이라 배포 안전(조건부, Starter에는 DB 백업 없음 ⚠️) · 설계 완료 → 구현·배포 완료(13차 `de349e9`, 2026-10-16), UI 변경 15차. 설계 당시 D1(삭제 정책)·D9(이력 전송 고지)는 결정 대기였음(확정 기록 확인 필요) | devlog 012 |
| [031](031-pdf-without-text.md) | 글자를 읽지 못하는 PDF에 내용 되살리기 (유료 비전 전사 vs 요약) | 요약만 넣기는 검색에 약하고 비용도 거의 안 줄어 비추천 · 글자 없는 쪽만 이미지로 렌더해 유료 비전 모델이 전사하는 안 · 쪽당 약 $0.0007 ✅ · 조사 완료, **제품화하지 않기로 결정** | ADR 023 |
| [032](032-local-pdf-recovery.md) | 글자를 못 읽는 PDF를 외부 전송·비용 없이 읽기 (폼 값 + 브라우저 OCR) | 폼 입력란 PDF는 pdf.js·패치 PDFium으로 값 그대로 복원 ✅ · 스캔은 Tesseract.js 7.0.0 레시피로 양호한 스캔 CER 약 3%, 표·나쁜 화질은 약함, 본문 기준 첫 사용 시 약 4~7MB 지연 로드(제품화 시도 때 번들 에셋 합계는 약 12.7MB) · 실제 스캔 파일 미평가 ⚠️ · 조사 완료, **제품화하지 않기로 결정** | ADR 023 |
| [033](033-llm-latency-and-rotation.md) | LLM 응답 지연 측정과 모델 로테이션 (이력 길이별 · 모델별 · 추론 끄기) | 이력 길이는 지연 변수가 아님 · gemma 6/6회 429, lightning 무응답, nemotron-3-super는 추론 켜면 본문 0/4·끄면 첫 본문 0.5초, gemini-3.1-flash-lite 첫 본문 약 1초 | ADR 024, ADR 014 일부 대체 |
| [034](034-accessibility-audit.md) | 접근성·상호작용 상태 점검 (focus·hover·pressed·시맨틱·터치 영역) | 53개 항목 점검 · 출처/모델 알약·`적게 보기`는 잉크가 유리 면 아래라 호버·포커스 0 · 기본 Material 위젯은 Δ10~30의 약한 덧칠 · 14차 구현·배포, 15차까지 후속 | design interaction-states |
| [035](035-logo-click-effect-references.md) | 브랜드 마크(별 + PageBlink) 클릭 마이크로 인터랙션 레퍼런스 | 따라 하기 좋은 레퍼런스 5건(Josh Comeau 스파클 · Flutter 쿡북 쉬머 · flutter_animate ShimmerEffect · Discord 로고 연타 · Google I/O 2013 로고), 총 19건 · 구현은 의존성 없는 `AnimationController` + `Transform`/`CustomPainter` 1순위 · 소리·셰이더·Rive/Lottie 웹 비용은 ⚠️ 미확인 | design logo-click-effect (제안, 소유자 선택 대기) |
