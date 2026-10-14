# 006 · Flutter 앱 1차

| 항목 | 값 |
|---|---|
| 상태 | ✅ 빌드 성공 · ⚠️ 실서버 E2E 미검증 |
| 단계 | Phase 0 · 앱 |
| 시작 | 2026-10-14 23:51 KST |
| 완료 | 2026-10-14 23:56 KST |
| 소요 | 약 5분 |
| 최종 수정 | 2026-10-14 23:57 KST |

## 목표
질문(스트리밍 답변) · 문서 업로드 · 프로젝트 · 인용 페이지 뷰어(blink-to-page)를 갖춘 Flutter 앱 1차 버전을 만든다.

## 작업 로그
- 의존성: `file_picker` 13.1.0, `pdfrx` 2.6.5, `crypto`, `gpt_markdown` 1.3.4, `path_provider`
- 계획(plan 003)의 Riverpod · go_router는 시간 관계상 생략하고 `StatefulWidget`으로 구현 (해커톤 범위 단순화)
- 서버 수정: `Citation.index = sourceIndex + 1` (모델이 쓰는 `[n]`과 일치), 출처당 1회만 발행
- 커밋 `735c2e9`

## 결과

### 화면

`HomeShell` (하단 탭 질문 · 문서 · 프로젝트, 로그아웃) 안에 `SignInScreen`(Serverpod 생성 위젯)을 래핑.

| 화면 | 동작 |
|---|---|
| 질문 `AskScreen` | 범위 칩(내 문서/프로젝트) → `client.ask.ask` 스트림을 `gpt_markdown`으로 실시간 렌더. `[n]`을 `⚡n`으로 표시. 인용 칩 탭 → `PageViewerScreen` |
| 뷰어 | 이 기기에 원본이 있으면 `pdfrx PdfViewer`를 인용 페이지(`initialPageNumber`)로 열고 인용 구절 배너 표시. 없으면 인용 구절만 표시 (원본 서버 저장은 다음 단계) |
| 문서 | PDF 선택 → 기기에서 `pdfrx`로 페이지별 텍스트 추출(`loadStructuredText().fullText`) → SHA-256 → 계층 선택 시트 → `client.document.upload` → 원본을 `LocalPdfs`(앱 문서 폴더)에 저장 |
| 프로젝트 | 생성, 이메일로 초대 (editor) |

계층 선택 시트: Cloak(기기 전용)은 "곧 지원"으로 비활성, 내 클라우드, Shared Vision · 프로젝트.

### 검증

| 항목 | 결과 |
|---|---|
| `flutter analyze` | ✅ 이슈 0 |
| `flutter build web` | ✅ 성공 (35.8초) |
| 서버 테스트 | ✅ 9개 통과 |
| 실서버 E2E | ⚠️ 미검증 (API 키 미입력) |

## 문제와 해결

| # | 문제 | 해결 |
|---|---|---|
| 1 | Dart 레코드 패턴 대입은 필드에 쓸 수 없음 | 일반 대입으로 수정 |
| 2 | `client.auth` 사용에 `serverpod_auth_idp_flutter` import 필요 | import 추가 |
| 3 | `dart fix --apply`가 Flutter 패키지 `pubspec`의 `flutter_driver(sdk)`를 망가뜨림 | 복구. **Flutter 패키지에서는 `dart fix` 대신 `flutter` 명령 사용** |

## 결정 (→ ADR 링크)
- 상태 관리 · 라우팅 라이브러리(Riverpod · go_router) 생략, `StatefulWidget` 사용 — 해커톤 범위 단순화 (별도 ADR 없음)

## 다음 할 일
- (사용자) `openrouterApiKey` · `deepinfraApiKey` 입력
- `serverpod start`로 로컬 E2E
- Cloud launch (G2)
- DeepInfra 실호출 검증
- 데모 PDF 준비, README · 영상

## 변경 이력
- `2026-10-14 23:57` 최초 작성
