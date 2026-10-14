# 008 · Flutter 클라이언트 스택

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | 로그인·PDF 업로드·스트리밍 마크다운 채팅·인용 → PDF 페이지 하이라이트·공유·한영 UI를 위한 2026년 패키지와 Android 빌드 요건은? |
| 결론 한 줄 | **Flutter 3.47.7** · Riverpod 3 · go_router · pdfrx · gpt_markdown · Material은 `material_ui`로 분리 중 |
| 반영 | [plan 003 §0, §2-4](../plan/003-tech-stack-and-prep.md) |

> pub.dev API·공식 페이지에서 버전과 날짜를 직접 읽은 것은 ✅

## 7. Flutter / Dart

| 항목 | 값 |
|---|---|
| Flutter stable | **3.47.7 (2026-10-08), Dart 3.13.5** ✅ |
| Serverpod 4.0.4 요구 | Dart ^3.12.2, Flutter ^3.44.4 ✅ |
| pdfrx 2.6.5 요구 | Flutter ≥3.47.0 ✅ |

- ✅ Flutter 3.47에서 Material/Cupertino가 `material_ui` / `cupertino_ui`(1.0.0) 패키지로 분리 중. SDK 내장판은 추후 deprecated(날짜 미정)
- pdfrx는 2.5.0부터 `material_ui` 사용 → `material_ui` 로컬라이제이션 없으면 PDF 메뉴가 영어
- 새 프로젝트는 `material_ui`로 시작하거나 `dart fix --apply --code=migrate_design_widgets`, 또는 `MaterialUiCompatibilityBridge`

## 1. 상태관리 · 라우팅 · Serverpod

| 패키지 | 버전 | 비고 |
|---|---|---|
| **flutter_riverpod** | 3.4.3 (2026-09-03) ✅ | Dart ^3.12. Serverpod 스트림 → `StreamProvider`/`AsyncNotifier` |
| flutter_bloc | 9.1.1 (2025-05) ✅ | 17개월 릴리스 없음 |
| signals | 7.1.0 ✅ | 덜 흔함 |
| **go_router** | 18.0.2 (2026-09-28) ✅ | Flutter ≥3.44, `redirect` + `refreshListenable` |
| serverpod_flutter / serverpod_client | 4.0.4 (2026-10-06) ✅ | |
| **serverpod_auth_idp_flutter** | 4.0.4 ✅ | `SignInWidget`(활성 제공자 자동 감지), `FlutterAuthSessionManager` |
| serverpod_auth_core_flutter | 4.0.4 ✅ | |

- `serverpod_auth_idp_flutter`는 pub.dev에 Android·iOS·macOS만 표기. Serverpod 문서는 Web 쿠키 흐름 + `auth.html`을 설명 → **Web 사용 전 확인 ⚠️**
- Serverpod 사용자들이 어떤 상태관리를 주로 쓰는지는 출처 없음 → Riverpod 선택은 ⚠️

## 2. PDF 뷰어

| 패키지 | 버전 | 플랫폼 |
|---|---|---|
| **pdfrx** | 2.6.5 (2026-09-18) ✅ | Android·iOS·Windows·macOS·Linux·Web(WASM) |
| syncfusion_flutter_pdfviewer | 35.1.40+1 ✅ | 라이선스 ⚠️ (상용 + 소규모 커뮤니티 라이선스) |

- pdfrx: `PdfViewerController` 페이지 점프, `PdfTextSearcher`(백그라운드 검색, `matches` = `PdfPageTextRange`, 이전/다음), `pageTextMatchPaintCallback` 하이라이트, 텍스트 선택 기본 활성(`setTextSelectionPointRange`, `onTextSelectionChange`)
- 인용 하이라이트: `startTextSearch(passage)` 후 매치로 이동. 정밀 제어는 `pageOverlaysBuilder`/`pagePaintCallbacks`로 사각형 그리기 (문자 범위 기반은 추론 ⚠️)

## 3. 마크다운 · 채팅 UI

| 패키지 | 버전 | 상태 |
|---|---|---|
| flutter_markdown | 0.7.7+1 | **개발 중단** ✅ → flutter_markdown_plus |
| flutter_markdown_plus | 1.0.12 ✅ | 활발 |
| **gpt_markdown** | 1.3.4 (2026-10-08) ✅ | LLM 출력용(LaTeX·표·코드) |
| markdown_widget | 2.3.2+8 (2025-04) ✅ | 정체 |
| flutter_streaming_text_markdown | 1.11.1 ✅ | 신생 |
| flutter_chat_ui + flutter_chat_core | 2.12.0 / 2.9.1 ✅ | v2가 현행 |

- 추천: `gpt_markdown`. 토큰마다 다시 그리되 30~50ms 스로틀. `[1]` 같은 마커는 커스텀 인라인 컴포넌트(⚠️) 또는 `cite://id` 링크로 전처리
- 채팅 UI는 직접 만든 `ListView`가 스트리밍 말풍선·칩 제어에 유리

## 4. 파일 · 공유 · 저장

| 패키지 | 버전 |
|---|---|
| file_picker | 13.1.0 ✅ (전 플랫폼, 월 430만 다운로드) |
| receive_sharing_intent | 1.9.0 ✅ (Android·iOS) |
| flutter_sharing_intent | 2.0.4 (2025-11) ✅ 덜 활발 |
| shared_preferences | 2.5.6 ✅ |
| drift | 2.35.2 ✅ |
| hive_ce | 2.21.0 ✅ |

- 공유 인텐트: 매니페스트 `SEND`·`SEND_MULTIPLE`(`*/*` 또는 `application/pdf`), `launchMode="singleTask"`, 콜드 스타트 `getInitialMedia()` 후 `reset()`, 실행 중 `getMediaStream()`, Kotlin 2.4 필요 ✅
- 원조 `hive`·`isar`는 피하고 `hive_ce`·`isar_community`

## 5. 다국어 · 테마
- `intl` 0.20.3 ✅, `flutter_localizations`(Material 델리게이트는 `material_ui`로 이동 중) ✅, `slang` 4.19.2 ✅, `dynamic_color` 2.1.0 ✅
- ARB(`gen_l10n`) 한/영이면 충분. Material 3 + `ColorScheme.fromSeed`

## 6. Android 빌드 요건

| 항목 | 값 |
|---|---|
| Flutter 3.47.7 기본값 | compileSdk 36, targetSdk 36, minSdk 24, NDK 28.2.13676358, Java ≥17 ✅ |
| Flutter 도구의 AGP | 8.11.1 ✅ (새 프로젝트 템플릿 AGP는 미확인) |
| Play 타깃 API | **2026-08-31부터 신규·업데이트 모두 API 36** (11-01까지 연장 신청 가능) ✅ |
| 16KB 페이지 | API 35+ 타깃은 필수, **2027-02-01부터 미지원 업데이트 출시 불가** ✅ |

- AGP ≥8.5.1 + NDK r28+면 16KB 기본 호환. pdfrx는 16KB 정렬 명시 ✅. LiteRT 등은 미확인 ⚠️ → `check_elf_alignment.sh`, `zipalign -c -P 16`
- 테스트: Android 15+ 16KB 에뮬레이터, `adb shell getconf PAGE_SIZE` = 16384

## 권장 스택
flutter_riverpod 3.4.3 · go_router 18.0.2 · serverpod_flutter 4.0.4 · serverpod_auth_idp_flutter 4.0.4 · pdfrx 2.6.5 · gpt_markdown 1.3.4 · file_picker 13.1.0 · receive_sharing_intent 1.9.0 · shared_preferences 2.5.6 · intl 0.20.3 · material_ui 1.0.0

## 출처
- https://pub.dev/api/packages/{name} (위 패키지 전부 조회)
- https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
- https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
- https://docs.serverpod.dev/concepts/authentication/setup
- https://github.com/espresso3389/pdfrx/blob/master/doc/Text-Search.md · https://pub.dev/packages/pdfrx
- https://developer.android.com/guide/practices/page-sizes
- https://developer.android.com/google/play/requirements/target-sdk
