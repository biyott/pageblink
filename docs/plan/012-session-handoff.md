# 🤝 세션 인수인계 — 작업 방식·하네스·현재 상태

> **작성일**: 2026-10-15 16:00 KST · **최종 수정**: 2026-10-15 16:00 KST
> **관련 문서**: [검색 컬럼 계획 (010)](010-pdf-search-column.md) · [폼 입력란 폴백 (011)](011-pdf-form-field-fallback.md) · [후속 기능 명세 (005)](005-follow-up-spec.md) · [기술 스택 (003)](003-tech-stack-and-prep.md) · [UI polish 명세](../design/ui-polish/spec.md) · [research 025 (PDF 업로드)](../research/025-pdf-drag-drop-upload.md) · [ADR 019](../adr/019-pdf-drag-drop-desktop-drop-shell-web-first.md) · [`AGENTS.md`](../../AGENTS.md) · [`CLAUDE.md`](../../CLAUDE.md) · [`app/AGENTS.md`](../../app/AGENTS.md)
> **표기**: ✅ 확인 · ⚠️ 미확인/확인 필요
> **용도**: 새 세션이 **이 문서만 읽고** 이어서 작업할 수 있게 한 인수인계 문서입니다. 상태 값은 작성 시점(위 KST) 스냅샷이므로, 시작할 때 §6 점검 명령으로 다시 확인하세요.

---

## 0. 한눈에 보기

| 항목 | 값 |
|---|---|
| 제품 | PageBlink — Flutter + Serverpod 하이브리드 문서 RAG 앱 (Serverpod 해커톤 2026) |
| 라이브 | https://pageblink.serverpod.space |
| Git | `main` = `origin/main` (NFC 수정 커밋 `5a2b7d9` + 이 문서 커밋) ✅ |
| 배포 | 6회 완료, 마지막(6차) = `5a2b7d9`, 롤아웃 성공·라이브 200 ✅ |
| 미커밋 작업 | 없음 (README·run-locally는 사용자 개인 수정) ✅ |
| 다음 1순위 | ② 노트별 색 변경 + 상단 고정 (§3-2) |
| 버전 | Flutter 3.47.7 (`.fvmrc`), Serverpod 4.0.4 (모든 `serverpod*` 동일) |

---

## 1. 역할과 규칙

### 1-1. 역할

| 역할 | 하는 일 |
|---|---|
| **사용자 = 클라이언트** | 요구·결정. **결정이 PM보다 우선** |
| **메인 Claude = 리드 (PM/오케스트레이터)** | 조사·구현은 서브에이전트에 위임. 단순 사실 확인·로컬 점검만 직접. 결과를 판단해 사용자와 소통 |
| 서브에이전트 | general-purpose(구현·조사), designer(디자인), writer(문서) — `.claude/agents/{writer,designer}.md` |
| writer 에이전트 | 문서 작성. 조사 결과는 `docs/research/NNN`, 확정한 결정은 `docs/adr/NNN` |

### 1-2. 저장소 규칙 (`CLAUDE.md` · `AGENTS.md` · `app/AGENTS.md`)

| 규칙 | 내용 |
|---|---|
| 서버 | **에이전트는 서버를 직접 실행하지 않음.** 서버는 사용자가 실행 (`serverpod start`) |
| 생성 코드 | `lib/src/generated/`, `pageblink_client` **수정 금지** (모델 `.spy.yaml`·엔드포인트를 고치고 생성기 사용) |
| 비밀값 | API 키는 `config/passwords.yaml`(git 제외) 또는 Serverpod Cloud 비밀값에만 |
| LLM·임베딩 | 반드시 서버(Serverpod 엔드포인트) 경유 |
| 문서 | 쓰기 전에 해당 폴더 `README.md`(규칙·템플릿·목차)를 먼저 읽고 목차 갱신. 한국어, `NNN-kebab-주제.md`, KST는 셸 값만 (`TZ=Asia/Seoul date "+%Y-%m-%d %H:%M"`), ✅/⚠️ 표기, 지어내지 않기 |
| `app/AGENTS.md` 체크리스트 | `dart analyze` → `dart format` → (모델 변경 시) `create_migration`/`apply_migrations` → hot restart → 테스트 → 로그 확인 |

### 1-3. 사용자 상시 지시 (✅ 세션 중 받은 지시)

| 지시 | 의미 |
|---|---|
| "나머지 결정이 필요한 것은 너가 한 게 맞아" | 추천 기본값을 승인한 것으로 간주하고 진행 |
| "이전 작업들이 완료되면 알아서 배포" | 자율 배포 후 결과 보고 |
| "gh 계정은 알아서" | 활성 gh 계정 `smnoh_gsenc`는 **쓰기 불가** → push는 아래 명령 사용 |
| config 커밋 금지 | `app/pageblink_server/config/{development,staging}.yaml`의 로컬 수정은 **공개 저장소라 커밋 금지** |
| 사용자 개인 수정 | `README.md`, `README.ko.md`, `docs/reference/002-run-locally.md`는 **건드리지 말 것** (작성 시점 작업 트리에 수정 상태로 존재) |
| 비밀값 | 출력 금지 |

```bash
# push (활성 계정이 쓰기 불가이므로 biyott 토큰 사용)
GH_TOKEN="$(gh auth token --user biyott)" git push origin main
```

로컬 설정 백업 (✅ 존재 확인):

| 파일 | 용도 |
|---|---|
| `~/.config/pageblink/config-local-changes.patch` | config yaml 로컬 수정 백업 패치 |
| `~/.config/pageblink/neon.env` | Neon DB 환경값 (**내용 출력 금지**) |

- 작성 시점 `git status`에는 `app/pageblink_server/config/*.yaml` 변경이 **보이지 않았습니다** ✅. 로컬 수정이 필요하면 백업 패치를 적용하되 **커밋에 포함하지 않습니다**.
- 훅: 이전 세션에서 `caveman`(간결 응답)·`ponytail`(최소 구현) 훅이 활성이었습니다 (⚠️ 새 세션에서 활성 여부는 환경에 따라 다름).

---

## 2. 작업 방식 (하네스)

### 2-1. 개요

```mermaid
flowchart LR
  L[리드: 브리프 작성] --> S[서브에이전트 구현]
  S --> W[작업 트리 변경]
  W --> V[깨끗한 워크트리 검증<br/>pageblink-verify]
  V --> C[검증 워크트리에서 커밋]
  C --> M[main fast-forward<br/>update-ref]
  M --> D[깨끗한 워크트리 배포<br/>pageblink-deploy]
  D --> LV[라이브 확인 · 보고]
```

### 2-2. 단계별 규칙 (✅)

| # | 단계 | 규칙 |
|---|---|---|
| 1 | 구현 위임 | general-purpose / writer / designer 서브에이전트에 **상세 브리프**로 위임. 서브에이전트에게 **`git stash`/`checkout`/`reset`/`commit` 금지, 서버 실행 금지**를 명시 |
| 2 | 검증 | 공유 파일이 섞인 작업 트리 대신 **깨끗한 워크트리**에서 검증 (아래 명령) |
| 3 | 커밋 | 검증 워크트리에서 커밋을 만들고, main은 작업 트리를 건드리지 않고 fast-forward. 명령은 `&&`로 게이트 (**`;` 금지**) |
| 4 | 배포 | 깨끗한 워크트리 `../pageblink-deploy`에서 `scloud` 배포 (아래 명령). 빌드 약 2.5분 + 롤아웃 약 1분 |
| 5 | 라이브 확인 | `/`, `main.dart.js`, `assets/FontManifest.json`, `pdfium.wasm`이 200 + 새 문자열 존재 확인, 워크트리 제거 |
| 6 | PDF 문제 | **브라우저 하니스**로 재현 (§2-4) |
| 7 | 서버 | 실제 서버는 사용자가 실행. 에이전트는 실행 금지 |

### 2-3. 명령 모음

**검증 (깨끗한 워크트리):**

```bash
git worktree add --detach ../pageblink-verify HEAD
# 변경 파일을 ../pageblink-verify 로 복사한 뒤
cd ../pageblink-verify/app/pageblink_flutter
flutter pub get && flutter analyze && flutter test
```

- 클라이언트 전체 테스트 **1,106개 통과** ✅ (NFC 테스트 포함, 클린 워크트리 기준).
- 서버 단위 테스트는 `app/pageblink_server`에서 `dart test` (내장 PostgreSQL, Docker 불필요 — `app/AGENTS.md`).

**커밋 → main 반영 (작업 트리 비접촉):**

```bash
# 검증 워크트리에서 커밋 생성 후, 메인 작업 트리에서:
git update-ref refs/heads/main <commit> HEAD \
  && git reset -q HEAD -- <path>
```

- `<commit>`은 검증 워크트리의 새 커밋 해시. `<path>`는 index에 남은 해당 경로(작업 트리 내용은 그대로 둠).
- 위 두 명령은 반드시 `&&`로 이어 실패 시 중단합니다.

**배포:**

```bash
git worktree add --detach ../pageblink-deploy HEAD   # main 최신 기준
cd ../pageblink-deploy/app/pageblink_server \
  && PATH="$HOME/Library/Application Support/Dart/install/bin:$PATH" \
     scloud --non-interactive --yes deploy
```

- `pre_deploy`가 `serverpod generate`와 Flutter web 빌드를 수행합니다 ✅.
- 배포 후 `https://pageblink.serverpod.space` 확인, 끝나면 `git worktree remove ../pageblink-deploy`.
- ⚠️ CDN은 같은 URL의 작은 파일을 `s-maxage 86400`으로 캐시한 적이 있어(FontManifest 지연), 새 배포 직후 정적 파일이 늦게 갱신될 수 있습니다.

### 2-4. PDF 브라우저 하니스

| 항목 | 내용 |
|---|---|
| 구성 | pdfrx 2.6.5 Flutter web 앱 + `playwright-core`(시스템 Chrome) + python 정적 서버 |
| 위치 | 이전 세션 scratchpad 하위 `pdfharness` — **임시라 사라졌을 수 있음 ⚠️** |
| 재구성 | 최소 Flutter 웹 앱이 `pdfrxFlutterInitialize()` 전/후로 `PdfDocument.openData` + 쪽 텍스트를 `console.log`. `node run.mjs`가 Chrome headless로 로드해 로그 수집 |
| 용도 | 엔진별 추출 문자 수 비교 (예: PDFium 0자 vs PyMuPDF 537자) — [011](011-pdf-form-field-fallback.md) |

---

## 3. 이어서 할 일 (체크리스트, 우선순위 순)

| # | 항목 | 상태 | 세부 |
|---|---|---|---|
| ① | **NFC 수정 검증 → 커밋 → 배포** | ✅ 완료·사용자 확인됨 (`5a2b7d9`, 6차 배포) | 아래 §3-1 |
| ② | **노트별 색 변경 + 상단 고정** | 미착수 | 아래 §3-2 |
| ③ | **PDF·노트 검색 컬럼** | 계획 | [010](010-pdf-search-column.md) |
| ④ | **폼 입력란 PDF 폴백 (P3)** | 계획 | [011](011-pdf-form-field-fallback.md) |
| ⑤ | **UI polish 잔여** UP-03/04/05/08/09/10/11 | 미착수 | [spec.md](../design/ui-polish/spec.md) (UP-07은 superseded) |
| ⑥ | **사용자 피드백 대기** | 대기 | 아래 §3-3 |
| ⑦ | **기타 (낮음)** | – | 아래 §3-4 |

### 3-1. ① NFC 수정 (완료)

원인과 파일 목록은 [010 §1-2](010-pdf-search-column.md#1-2-같이-발견된-제목-검색-버그-nfdnfc)에 있습니다.

| 체크 | 상태 |
|---|---|
| 클라이언트·서버 `text_norm.dart` 쌍둥이(주석으로 짝 표기) | ✅ |
| 깨끗한 워크트리에서 `flutter analyze` 이슈 0, `flutter test` 1,106개 통과 | ✅ |
| 서버 `dart analyze` 이슈 0, `test/unit/text_norm_test.dart` 2개 통과 | ✅ |
| NFC 관련 8개 파일만 커밋 (README·run-locally·config 제외) | ✅ `5a2b7d9` |
| main → push → 배포(6차) → 라이브 200 | ✅ |
| 라이브에서 NFD 파일명 PDF(예: `부산 여행 계획.pdf`)를 한글 IME 입력으로 제목 검색 | ✅ 사용자 확인됨 (이미 저장된 NFD 제목도 잡힘, 텍스트 PDF 질문도 동작) |

### 3-2. ② 노트별 색 변경 + 상단 고정 (설계)

| 영역 | 내용 |
|---|---|
| 서버 모델 | `Document.colorIndex int?`, `pinnedAt DateTime?` + 마이그레이션 |
| 엔드포인트 | `setNoteColor`, `setPinned` — **쓰기 권한 검사**(`_requireWrite` 계열), **재색인·`updatedAt` 갱신 없음** |
| UI | 카드 `⋯` 메뉴, 편집기 `⋯` 메뉴 |
| 색 | `pb.notes` **8색 팔레트 + 자동** |
| 고정 | 고정 섹션을 목록 **상단**에. **노트만**, **문서 단위 공유**(공유 프로젝트 문서면 모두에게 같은 색·고정) |
| 마이그레이션 주의 | 널 허용 컬럼 추가. 생성된 `migration.sql` 비파괴 여부 확인 |
| 후속 문서화 | ADR 보강(색·고정) |

### 3-3. ⑥ 사용자 피드백 대기

| 항목 | 내용 |
|---|---|
| 노트 목록 한글 제목이 얇아 보임 | 스크린샷 필요. 폰트 외곽선은 동일함이 측정됨 ✅. 완화안: 카드 제목 18 → 19 |
| 다크 모드 출처 알약 | 타일보다 진해 보일 수 있음 (⚠️ 미확인) |

### 3-4. ⑦ 기타 (낮음)

- macOS 엔타이틀먼트 `user-selected.read-only` (드롭용)
- 권한 오류 구분 표시
- `maxRequestSize` 결정
- 데모 영상 스토리보드 갱신 ([009](009-demo-video-plan.md))
- ADR 보강: 출처 UI, 색·고정

---

## 4. 현재 상태

### 4-1. Git

| 항목 | 값 |
|---|---|
| 브랜치 | `main` = `origin/main` (NFC 수정 `5a2b7d9`, 그 뒤 plan 010~012 문서 커밋) ✅ |
| 코드 최신 커밋 | `5a2b7d9` "fix(app,server): normalize Hangul to NFC for titles and search…" (그 앞 `85de144` 캐럿·링크) |
| 추가 워크트리 | 없음 (`git worktree list`에 main만) ✅ |

**작업 트리 (커밋 후 `git status` ✅):** 사용자 개인 수정 `README.md`, `README.ko.md`, `docs/reference/002-run-locally.md`만 남음 (**건드리지 말 것**).

### 4-2. 배포 이력 (6회)

| 차수 | 내용 |
|---|---|
| 4차 | PDF 엔진 초기화(`pdfrxFlutterInitialize`) 수정, 드래그 앤 드롭 업로드 트레이, 재색인 UX 조정, 편집기 툴바 아래 항상 선, 출처 칩 타일 톤, 사이드바 `계층` → `저장 공간`, Cloak 행 숨김 (플래그 `_showCloakTier`, `main.dart`) |
| 5차 (`85de144`) | 툴바 블록 서식 적용 후 캐럿이 마커 뒤에 위치, 링크 팝오버 기본값 `https://` |
| 6차 (`5a2b7d9`) | 한글 NFC 정규화: 제목·검색이 macOS NFD 파일명을 찾도록 (클라이언트 검색 양쪽 정규화, 업로드·saveNote 저장 시 NFC). DB 마이그레이션 없음 |
| 1~3차 | 이 문서에 기록 없음 (확인 필요 ⚠️) — `docs/devlog/`와 `git log` 참조 |

### 4-3. 앱 스택

| 항목 | 값 |
|---|---|
| Flutter / Serverpod | 3.47.7 (`.fvmrc`) / 4.0.4 |
| 폰트 | Pretendard 서브셋(`PretendardSubset`), NotoSerifKR 서브셋, Fraunces |
| 에디터 | 라이브 마크다운: `TextField` + `LiveMarkdownController.buildTextSpan` — **텍스트 불변, IME 안전** |
| PDF | pdfrx 2.6.5 / pdfrx_engine 0.6.1 (PDFium WASM), 텍스트는 클라이언트 추출 ([ADR 003](../adr/003-pdf-extract-on-client.md)) |
| 호스팅 | Serverpod Cloud (`scloud`), 라이브 https://pageblink.serverpod.space |

---

## 5. 알려진 사실과 주의

| # | 사실·주의 | 상태 |
|---|---|---|
| 1 | **한글 NFD**: macOS 파일명은 자모 분리형. 비교 전 NFC 정규화 필요 (현재 `nfc()`는 한글 자모 조합 한정) | ✅ |
| 2 | **핫 리로드**: `const` 클래스의 필드를 제거하면 거부됨 → hot restart (`R`) | ✅ |
| 3 | **CDN 캐시**: 같은 URL의 작은 파일을 `s-maxage 86400`으로 캐시 (FontManifest 지연 경험) | ✅ |
| 4 | **편집기 레이어**(체크박스·코드): `RenderEditable` 좌표를 사용. 본문 위 공기 24px을 `contentPadding`으로 두고 레이어 클립을 `topAir`만큼 확장 | ✅ |
| 5 | 링크/미니바 앵커의 **공기 구간 동작** | ⚠️ 미확인 |
| 6 | PDFium은 폼 입력란 전용 PDF를 0자로 읽음 → [011](011-pdf-form-field-fallback.md) | ✅ |
| 7 | 처음의 "Can't open this PDF"는 `pdfrxFlutterInitialize()` 누락 때문 (4차에서 해결) | ✅ |
| 8 | 배포는 서버·웹을 한 번에 내보냄. 모델 변경이 있으면 마이그레이션이 같이 적용됨 | ✅ ([010 §6](010-pdf-search-column.md#6-위험과-롤아웃) 참조) |

---

## 6. 새 세션 시작 절차

```bash
cd /Volumes/Nova/00-src/70-github@biyott/pageblink
git status --short            # 미커밋 파일이 §4-1과 같은지
git log --oneline -3          # 5a2b7d9 이후 커밋이 있는지
git worktree list             # 남은 pageblink-verify / pageblink-deploy 가 있는지
TZ=Asia/Seoul date "+%Y-%m-%d %H:%M"
```

1. `CLAUDE.md` → `AGENTS.md` → `app/AGENTS.md`를 읽는다.
2. §3 체크리스트 ①부터 상태를 확인하고 사용자에게 진행 상황을 보고한다.
3. 문서를 쓸 때는 대상 폴더 `README.md`를 먼저 읽고 목차를 갱신한다.
4. 새 결정은 ADR, 조사 결과는 research로 남기고, 이 문서의 §3·§4를 갱신한다.
