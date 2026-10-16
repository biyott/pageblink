# 013 · 16차 배포 — UX 라운드 2 + 후속 백로그 4건

| 항목 | 값 |
|---|---|
| 상태 | ✅ 배포 성공 (배포 ID `d85174e4-98de-4a24-8beb-84711110a212`, 17:01 KST). 라이브 스모크 통과 ✅. 눈으로 확인할 7개는 사용자 확인 대기 ⚠️ |
| 단계 | 기능 추가 · 운영 · 서버 + 앱 (16차) |
| 시작 | 2026-10-16 16:25 KST (첫 커밋 `d0c166a` 시각 ✅ git. 작업 착수 시각은 확인 필요) |
| 완료 | 2026-10-16 17:01 KST (배포 성공) |
| 소요 | 약 36분 (첫 커밋 16:25 ~ 배포 성공 17:01) |
| 최종 수정 | 2026-10-16 17:10 KST |

## 목표
- UX 라운드 2(노트 색 보정, 계정 블록, 설정 개편, 프로젝트 페이지)와 [plan 015](../plan/015-followup-backlog.md) 백로그 4건(2-1 · 2-2 · 2-5 · 2-7)을 **한 번에** 배포한다.
- 기준 `main` `88cd1b7`(15차 문서 커밋) 위에 커밋 14개를 얹었다. 충돌 0건.
- 근거: `git log 88cd1b7..HEAD`, 클린 워크트리 검증 출력(PM 전달), 운영 확인 결과(PM 전달).

## 작업 로그
시각은 `git log`의 커밋 작성 시각(KST, 2026-10-16)이다. 다른 브랜치에서 가져온 커밋은 원래 작성 시각이라 순서와 어긋날 수 있다.
- `16:25` `d0c166a` 색 인덱스 경합 수정 (색인 완료가 `colorIndex`를 덮어쓰지 않음)
- `16:26` `44371c0` 노트 색 팝오버 잘림 수정, 공용 `NoteColorDot` / `showNoteColor`
- `16:28` `0fbde9e` `account/me` 엔드포인트, `65401c9` UX 라운드 2 l10n 문구
- `16:32` `ae262b7` 안내 배너 큰 글자 오버플로 수정 (백로그 2-1)
- `16:37` `6281864` 편집기 헤더 노트 색 버튼
- `16:38` `af76003` 서술형 짧은 답변 인용 보정 (백로그 2-5)
- `16:40` `f05699a` 계정 블록 (사이드바 계정 행 · 아바타 메뉴 · 구분선 간격)
- `16:41` `31cfefc` 설정 계정 그룹 · 관리자 전용 계정 ID · 버전 줄 7번 탭, `c0b7cd5` 프로젝트 로드 상태 리팩터링
- `16:42` `ddd9acb` 버전 줄 테스트가 주입된 `APP_BUILD`로 동작
- `16:48` `7cab557` 프로젝트 페이지, `5b23005` 카드 메타 글자 AA 대비 (백로그 2-2)
- `16:49` `3c18216` 한국어 샘플 PDF (백로그 2-7)
- `16:53` 이 기록 작성

## 결과

### 커밋 (88cd1b7..HEAD, 14개)

| 묶음 | 커밋 | 내용 |
|---|---|---|
| 서버 · 노트 색 | `d0c166a` | 색인 완료가 `colorIndex`를 덮어쓰지 않음 (경합 수정) |
| 서버 · 계정 | `0fbde9e` | `AccountEndpoint.me` → `AccountInfo(email?, isDemo)`, 호출자 본인만 |
| 앱 · 노트 색 | `44371c0` | 색 팝오버 잘림 수정, 공용 `NoteColorDot` / `showNoteColor` |
| 앱 · 노트 색 | `6281864` | 편집기 헤더 노트 색 버튼 (무지개 포함) |
| 앱 · 문구 | `65401c9` | UX 라운드 2 l10n 문구 |
| 앱 · 계정 | `f05699a` | 사이드바 52dp 계정 행(아바타 · 이메일 · 쉐브론), 위로 열리는 메뉴(계정 · 로그아웃; demo는 공유 계정 안내 · 가입), 1024 미만 AppBar 아바타 버튼(600 이상 메뉴 · 폰은 바텀시트), 이메일은 `account.me()`, 사이드바 구분선 위 · 아래 12dp 간격 |
| 앱 · 설정 | `31cfefc` | 계정 그룹 최상단(신원 · 계정 ID · 로그아웃), 언어 섹션 그룹화, 계정 ID 행은 관리자에게만(demo 제외), 일반 계정은 버전 줄 7번 탭으로 그 방문 동안 공개(3초 유휴면 카운트 리셋), 버전 줄 `PageBlink v1.0.0 · <git 짧은 해시>` (`app_version.dart`) |
| 앱 · 설정 | `ddd9acb` | 버전 줄 테스트가 주입된 `APP_BUILD`로 동작 |
| 앱 · 프로젝트 | `c0b7cd5` | `ProjectsModel` 로드 상태(loading / loaded / error) — 읽기 실패가 빈 목록처럼 보이지 않음 |
| 앱 · 프로젝트 | `7cab557` | 프로젝트 페이지: 헤더 · 카드 그리드 · 로딩 / 오류 / 빈 상태 (`empty_state.dart`) |
| 백로그 2-1 | `ae262b7` | `_HistoryNotice` 큰 글자에서 오버플로 없음, 매트릭스 테스트 확장 |
| 백로그 2-2 | `5b23005` | 노트 · PDF 카드 메타 글자가 다크 hover에서도 AA 유지 |
| 백로그 2-5 | `af76003` | 구별 토큰(날짜 · 숫자+단위 등) 기반 서버 인용 보정 (`citation_infer.dart`, 케이스 `citation_infer_cases.dart`) |
| 백로그 2-7 | `3c18216` | 한국어 전용 샘플 PDF `web/samples/pageblink-guide-ko.pdf` (`scripts/build_sample_pdf_ko.sh`로 생성), `SamplePack.pdf` 언어별 지정(`demoPdfKo`), 영어 팩은 기존 영 · 한 병기 PDF 유지, `DemoSeed.run`이 다른 팩의 샘플 PDF 행을 계정에서 제거 |

- 편집기 헤딩 H1~H3 제한(`b37fb3d`)은 앞선 배포에서 이미 나갔다. 이번 배포가 아니다 ✅.
- 사이드바 구분선 간격(12dp)은 `f05699a`에 포함돼 있다.

### 검증 (클린 워크트리, 실제 출력 — PM 전달)

| 항목 | 결과 | 15차 대비 |
|---|---|---|
| 서버 `dart analyze` | 이슈 0 ✅ | – |
| 서버 `dart format` | 변경 0 ✅ | – |
| 서버 `dart test` | **341개** 통과 ✅ | 316 → 341 |
| Flutter `flutter analyze` | 이슈 0 ✅ | – |
| Flutter `flutter test` | **1,512개** 통과 ✅ | 1,369 → 1,512 |
| `serverpod run flutter_build` | 성공 ✅. `main.dart.js`에 `PageBlink v1.0.0 · 3c18216` 포함 | – |
| `serverpod generate` 재실행 | diff 없음 ✅ | – |
| `serverpod create-migration` | No changes detected ✅ | – |

### DB 마이그레이션
없음 ✅. `AccountInfo`는 비테이블 모델이라 테이블 변경이 없다.

### 운영 확인 (백로그 2-10, 코드 변경 없음 — PM 전달)

| 항목 | 결과 |
|---|---|
| `ADMIN_USER_IDS` | 운영 **미설정** ✅ — 관리자 계정이 아직 없음 |
| `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` | 변수가 **아직 남아 있음** (미사용). 삭제 여부 결정 필요 |
| 비밀값 `llmModel` | **미설정** ✅ |
| 정리 타이머 | 동작 확인 ✅ |

### 눈으로 확인할 것 (⚠️ 사용자 확인 대기)

| # | 확인 | 비고 |
|---|---|---|
| 1 | 다크 모드의 아쿠아 · 라임 · 무지개 노트 색 | 타 세션 배포분 포함 계속 대기 |
| 2 | 다크 카드 제목 – 메타 글자 대비 | `5b23005` 이후 hover 포함 |
| 3 | 데스크톱 색 팝오버 (잘림 없음) | `44371c0` |
| 4 | 데스크톱 · 폰의 계정 블록과 메뉴 | 사이드바 계정 행, AppBar 아바타(폰은 바텀시트), demo 계정 안내 |
| 5 | 프로젝트 페이지 | 헤더 · 카드 그리드 · 로딩 / 오류 / 빈 상태 |
| 6 | 설정 버전 줄 7번 탭 공개 | 일반 계정: 7번 탭 → 계정 ID 행 공개, 3초 유휴 시 카운트 리셋 |
| 7 | `PageBlink v1.0.0 · <해시>` 줄 | 라이브 `main.dart.js`에 `PageBlink v1.0.0 · 481c486` 확인 ✅ (배포한 `main` = `481c486`) |

## 문제와 해결
- **병합 순서 문제 (중단 후 재시도로 해소)**: 프로젝트 페이지 커밋(원본 `e7f85a7`, 다른 브랜치)이 같은 브랜치의 item 3 커밋 복사본을 품고 있었다. 원본 4개를 먼저 적용하고 `e7f85a7`만 따로 적용해 해소했다 (이 브랜치에서는 `7cab557`). 충돌 자체는 0건.
- **백로그 2-2 잔여**: 다크 `inkMuted`가 Ask 답변 카드 · 인용 하이라이트 위에서 2.1~3.9:1이다. 이번에 고치지 않았다 → [plan 015 §2-8 i](../plan/015-followup-backlog.md)에 남김.
- ⚠️ 버전 줄의 해시는 빌드 시점 `git rev-parse --short HEAD`다. 검증 빌드의 `3c18216`은 이 브랜치 끝 커밋이며, 배포 빌드는 `main` `481c486`(문서 커밋)에서 돌았고 라이브 `main.dart.js`에 `PageBlink v1.0.0 · 481c486`이 들어 있다 ✅. 이 배포 기록 커밋은 문서만 바꾸므로 이후 `main`은 이 해시보다 앞서 있다.

## 결정 (→ ADR 링크)
새 ADR 없음. 계정 ID 행의 관리자 전용 노출 · 7번 탭 공개 규칙은 이 기록과 [plan 012](../plan/012-session-handoff.md) §4-2에 적었다.

## 배포와 라이브 스모크 (✅ 실제 출력)
- 배포 ID `d85174e4-98de-4a24-8beb-84711110a212`, 성공 17:01 KST (시작 16:57:30 ~ 17:01:02, 빌드 141초 · 롤아웃 68초, `scloud deployment list` ✅). 부팅 로그: `Latest database migration already applied`(새 마이그레이션 없음), `maintenance: timer started jobs=demo-tokens,auth-tokens,demo-documents,ask-history`, `chunk-migration: done ok=0 skipped=0 failed=0`.
- 웹 루트 200, `main.dart.js` 200, 한국어 샘플 PDF `/samples/pageblink-guide-ko.pdf` 200.
- API(demo 계정, Ask 질문은 쓰지 않음): 비로그인 `account/me` 401. demo 영어·한국어 `account/me` = `isDemo: true`, `email: null`. 노트 생성 → `setNoteColor` 8 → 8, null → null, 목록에서 null, 삭제 200.
- 샘플 PDF 카드 `preview`: 한국어 계정은 한국어("문서 추가하기 직접 쓴 노트와 올린 PDF에…")로, 영어 계정은 영어("Adding your documents PageBlink turns…")로 시작 ✅.
- 배포 후 12분 로그에 ERROR · WARN 줄 없음 ✅.

## 다음 할 일
- 위 "눈으로 확인할 것" 7개의 사용자 확인.
- `SERVERPOD_WEB_SERVER_FLUTTER_CACHE_CONTROL` 변수 삭제 여부 결정.
- 관리자 지정: 사용자가 설정의 계정 ID를 주면 `ADMIN_USER_IDS` 설정 (아직 관리자 없음).
- 남은 백로그: [plan 015](../plan/015-followup-backlog.md) 2-3 · 2-4 · 2-6 · 2-8 · 2-9와 2-10의 2 · 6번.

## 변경 이력
- `2026-10-16 16:53` 최초 작성 (16차 배포 전 기록: 커밋 14개, 검증 수치, 운영 확인, 눈 확인 목록). 배포 ID · 성공 시각은 배포 후 아래에 채움
- `2026-10-16 17:02` 배포 성공(`d85174e4-98de-4a24-8beb-84711110a212`, 17:01) · 라이브 스모크 통과 기록, 상태를 ✅로
- `2026-10-16 17:10` 운영 변수 `ADMIN_USER_IDS`를 소유자 계정으로 설정 후 `--redeploy`(코드 동일 `481c486`), 관리자 조회 사용 가능 ([plan 012 §4-2](../plan/012-session-handoff.md))
