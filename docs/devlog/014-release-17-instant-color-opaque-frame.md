# 014 · 17차 배포 — 노트 색 즉시 반영 + 관리자 대화 기록 불투명 프레임

| 항목 | 값 |
|---|---|
| 상태 | ✅ 배포 성공 (배포 ID `e262e7a4-4a4b-4339-a723-c5d9ca52da4f`, 17:24 KST). 라이브 스모크 통과 ✅. 눈으로 확인할 3개는 사용자 확인 대기 ⚠️ |
| 단계 | 수정 · 운영 · 앱 (17차, 클라이언트 전용) |
| 시작 | 2026-10-16 17:15 KST (두 수정 커밋 작성 시각 ✅ git) |
| 완료 | 2026-10-16 17:24 KST (배포 성공) |
| 소요 | 약 9분 (수정 커밋 17:15 ~ 배포 성공 17:24) |
| 최종 수정 | 2026-10-16 17:20 KST |

## 목표
- 사용자 눈 확인에서 나온 클라이언트 수정 2건을 `origin/main` `9340779` 위에 얹어 배포한다. 서버 · 생성 코드 · 마이그레이션 변경 없음.
  1. 노트 색을 고르면 서버 응답을 기다리지 않고 바로 바뀐다(낙관적 갱신 + 짧은 페이드). 실패하면 이전 색으로 되돌리고 오류를 보인다.
  2. 관리자 대화 기록 페이지가 이전 화면이 비치는 투명 `Scaffold`가 아니라 표준 불투명 프레임을 쓴다.

## 작업 로그
- `17:15` 수정 2건 작성(원본 `1b33c47` · `f54ad3c`, 각각 별도 워크트리 브랜치)
- `17:16` `origin/main` `9340779` 기준 새 워크트리(브랜치 `release17`)에 cherry-pick: `13657b2`(색 즉시 반영) → `6f6c28b`(불투명 프레임). **충돌 0건**
- `17:20` 검증(아래 결과) 전부 통과 후 문서 커밋

## 결과

### 커밋

| 커밋 | 원본 | 내용 | 파일 |
|---|---|---|---|
| `13657b2` | `1b33c47` | 노트 색 낙관적 갱신 + 짧은 페이드 | `documents_screen.dart`, `note_editor_screen.dart`, 테스트 `note_color_instant_test.dart`(신규) · `note_editor_color_test.dart` |
| `6f6c28b` | `f54ad3c` | `PbPage` 신설(불투명 `PbBackground`, 600px 이상은 강한 `GlassPanel` 안에 배치). 관리자 대화 기록 페이지와 `OpenItemPage`가 사용, 관리자 화면은 600px 이상에서 `embedded` | `theme.dart`, `admin_history_screen.dart`, `open_item_view.dart`, 테스트 `pushed_page_frame_test.dart`(신규) |

두 커밋의 파일은 겹치지 않는다(`git diff --stat`: 8개 파일, +805 −128).

### 검증 (클린 워크트리 `../pageblink-release17`, 실제 출력)

| 항목 | 결과 |
|---|---|
| 서버 `dart analyze` | 이슈 0 ✅ |
| 서버 `dart test` | **341개** 통과 ✅ (16차와 동일, 서버 변경 없음) |
| Flutter `flutter analyze` | 이슈 0 ✅ |
| Flutter `flutter test` | **1,535개** 통과 ✅ (16차 1,512 → +23: 신규 테스트 파일 2개 · 기존 확장) |
| `serverpod generate` | 재실행 후 `git status` 변경 없음 ✅ |
| `serverpod create-migration` | 재실행 후 `git status` 변경 없음 ✅ (마이그레이션 체인 끝 `20261016062428206-pdf-recovery-and-preview`) |
| `serverpod run flutter_build` | 성공 ✅. `main.dart.js`에 `PageBlink v1.0.0 \xb7 6f6c28b`(검증 빌드의 HEAD) 포함 |

### 배포와 라이브 스모크 (✅ 실제 출력)
- 배포한 `main` = `6b9b5dd`(문서 커밋, 코드는 `13657b2` `6f6c28b`). 깨끗한 새 워크트리에서 `scloud --non-interactive --yes deploy`. 배포 전 `scloud deployment list`에 진행 중 배포 없음(직전 `d85174e4` SUCCESS).
- 배포 ID `e262e7a4-4a4b-4339-a723-c5d9ca52da4f`, SUCCESS (시작 17:21:28 ~ 17:24:47, 클라우드 빌드 127초 · 롤아웃 68초). 부팅 로그: `Latest database migration already applied`(새 마이그레이션 없음, 체인 끝 `20261016062428206-pdf-recovery-and-preview`), `maintenance: timer started jobs=demo-tokens,auth-tokens,demo-documents,ask-history`, `chunk-migration: done ok=0 skipped=0 failed=0`.
- 웹 루트 200. 라이브 `main.dart.js`에 `PageBlink v1.0.0 \xb7 6b9b5dd` 포함(`\xb7`은 `·`의 JS 이스케이프).
- API(demo 영어 계정, Ask 질문은 쓰지 않음): 노트 생성 200 → `setNoteColor` 5 → 5, null → null → 목록에서 null → 삭제 200 → 목록에서 사라짐.
- 배포 후 10분 로그의 ERROR 8줄은 모두 스모크 도중 내가 잘못 보낸 요청(깨진 `Content-Type` 헤더, `Error reading request. HttpException: Failed to parse header value`)이고 앱 오류가 아니다. 그 밖의 ERROR · WARN 없음.

## 문제와 해결
- 충돌 없음. 해시가 달라진 것은 cherry-pick 때문(원본 `1b33c47` → `13657b2`, `f54ad3c` → `6f6c28b`).

## 결정 (→ ADR 링크)
새 ADR 없음.

## 다음 할 일
- 사용자가 눈으로 확인할 것: 목록과 편집기에서 노트 색이 즉시 바뀌고 부드럽게 전환되는지, 관리자 대화 기록 페이지의 프레임(데스크톱 · 태블릿 · 폰), 폰에서 `OpenItemPage`가 슬라이드로 들어올 때 뒤 화면이 비치지 않는지.

## 변경 이력
- `2026-10-16 17:20` 최초 작성 (배포 전 기록: 커밋, 검증 수치). 배포 ID · 스모크는 배포 후 채움
- `2026-10-16 17:26` 배포 성공 · 라이브 스모크 기록, 상태를 ✅로
