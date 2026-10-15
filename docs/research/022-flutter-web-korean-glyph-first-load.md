# 022 · Flutter 웹 첫 로딩 때 한글이 깨져 보이는 현상

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 11:15 (KST) |
| 담당 | 서브에이전트 (general-purpose · 읽기 전용: 코드 수정·커밋·`flutter build`·서버 기동 없음) |
| 질문 | Flutter 웹에서 "처음에 뜰 때 한글이 깨진다" — 가능한 원인을 모양별(두부 □ / mojibake / 폰트가 바뀌어 보임)로 나누고, 해결 방안의 효과·비용·위험을 비교 |
| 결론 한 줄 | 가장 가능성 높은 원인은 **한글 글리프가 번들에 없어서 첫 프레임이 두부(□)·폴백 폰트로 그려진 뒤, 네트워크로 받은 폰트로 2~3번 교체되는 것**이다. 앱이 `google_fonts`로 런타임에 받는 Noto Sans KR(6.16 MB)·Noto Serif KR(14.05 MB)가 교체 시점을 늦춘다. 인코딩(mojibake)은 소스상 가능성이 매우 낮다 |
| 반영 | 결정 대기 (추천: 한글 서브셋을 assets에 번들 — §해결 방안 A). 관련: [018](018-desktop-note-typography.md) §4 (한글 폴백명 수정이 다운로드를 늘림, "크기 미측정" → 이 문서에서 측정) |

> 표기: ✅ 소스·산출물로 확인 · ⚠️ 미확인/추정. 이 환경에서는 **빌드·브라우저 실행을 하지 않아 "화면에 실제로 어떻게 보이는지"는 확인하지 못했다.** 경로 약칭: `engine/` = `/Volumes/Nova/62-temp-data/fvm/versions/3.47.7/bin/cache/flutter_web_sdk/lib/_engine/engine/`, `tools/` = 같은 SDK의 `packages/flutter_tools/lib/src/`, `gf/` = `~/.pub-cache/hosted/pub.dev/google_fonts-8.2.1/lib/src/`.

---

## 핵심 결론

| # | 가설 | 판정 | 한 줄 근거 |
|---|---|---|---|
| 1 | CanvasKit 폴백 폰트 지연(두부 □ 후 교체) | ✅ **구조상 발생** | 번들에 한글 폰트가 없으면 엔진이 `fonts.gstatic.com`에서 Noto Sans KR 조각(woff2 124개)을 받아 교체. 받는 동안 두부 |
| 2 | 앱 자체 폰트(`google_fonts`) 런타임 로딩 | ✅ **구조상 발생, 가장 큰 기여** | `main()`이 폰트를 기다리지 않음. 첫 프레임 후 6~20 MB를 받아 교체 |
| 3 | 문자 인코딩(mojibake) | ✅ 가능성 매우 낮음 | 서빙 쪽이 `text/html; charset=utf-8` 부여(실측), JS도 `text/javascript`→charset 부여(소스). `<meta charset>` 있음 |
| 4 | HTML 초기 스플래시 | ✅ 해당 없음(스플래시 자체가 없음) | `web/index.html`에 텍스트·로딩 UI 없음 → 첫 화면은 빈 흰 화면 |
| 5 | 서비스워커·캐시 | ✅ 부차적 | Flutter 3.47의 서비스워커는 자기 해제 스텁. 옛 등록이 남은 브라우저에서 1회 새로고침 정도 |

**가장 가능성 높은 원인**: ②(+①). 이유는 (a) 한글이 들어가는 폰트 사슬 어디에도 *즉시 쓸 수 있는* 한글 폰트가 없고(번들 폰트 0개 ✅), (b) 폴백명을 고친 뒤(018) 오히려 20 MB급 다운로드가 생겼으며, (c) 그동안 화면이 두부 → 엔진 폴백 Noto Sans KR → google_fonts 폰트(+Inter, Fraunces)로 **차례로 바뀐다**. 사용자가 말한 "깨진다"는 두부 단계 또는 글꼴이 바뀌는 단계일 가능성이 높다 ⚠️(실제 모양은 미확인).

---

## 상세

### 1. 엔진 폴백 폰트 (두부 □)

- ✅ 한글 코드포인트가 현재 폰트 사슬에 없으면 엔진이 폴백 폰트를 **네트워크에서** 받는다. 기본 URL은 `https://fonts.gstatic.com/s/` (`engine/configuration.dart:363-365`), 다운로드·재시도·"서비스 비활성화" 로직은 `engine/font_fallback_service.dart:483-570`.
- ✅ 폴백 목록에 Noto Sans KR 조각이 **124개**(`notosanskr/v36/….{0..123}.woff2`, `engine/font_fallback_data.dart:1051-` 부근). 화면에 나온 글자가 속한 조각만 받는다.
- ✅ 다운로드가 끝나기 전 해당 글자는 Skia가 `.notdef`(두부)로 그린다. 끝나면 `sendFontChangeMessage()`로 프레임워크가 다시 레이아웃한다(`font_fallback_service.dart` `_notifyFontsChanged`). 즉 **"두부 → 정상 글자"로 바뀌는 것이 설계된 동작**이다.
- ✅ 기본 폰트 Roboto도 CDN: `engine/canvaskit/fonts.dart:14-15`, `:116-132`. 앱 에셋에 `Roboto`가 없으면 `fonts.gstatic.com/s/roboto/v32/…woff2`를 **첫 프레임 전에** 받는다(`loadAssetFonts`, 런앱 전).
- ✅ CanvasKit 본체도 기본은 CDN: `https://www.gstatic.com/flutter-canvaskit/<engineRevision>/` (`tools/build_system/targets/web.dart:129-137`, `flutter_js/flutter.js`의 canvasKitBaseUrl 결정부). 이 파일은 5~7 MB(`canvaskit.wasm` 5.2 MB, 크롬용 chromium 변형; 풀 변형 6.9 MB ✅ 로컬 SDK 크기).
- ✅ 지원 렌더러는 **canvaskit / skwasm 두 가지뿐**이다(`tools/web/compile.dart:186-209`, HTML 렌더러 없음). 기본 `flutter build web`은 canvaskit, `--wasm`은 skwasm(+canvaskit 폴백). skwasm도 같은 `fontFallbackBaseUrl`을 쓴다(`engine/skwasm/skwasm_impl/font_collection.dart`) → **`--wasm`은 한글 문제를 해결하지 않는다.**
- ✅ 네트워크가 `fonts.gstatic.com`을 막으면(사내망·방화벽·광고 차단) 재시도 3회 후 "permanently unavailable", 전역 실패가 누적되면 서비스 자체를 끈다(`font_fallback_service.dart:560-570`) → **한글이 계속 두부**. 이 경우는 "처음에만"이 아니라 계속된다.

### 2. 앱 자체 폰트 (`google_fonts`)

- ✅ `app/pageblink_flutter/lib/app/theme.dart:163-177`: 본문 `GoogleFonts.interTextTheme`, 한글 폴백 `GoogleFonts.notoSansKr().fontFamily!`, 제목 `GoogleFonts.fraunces` + 폴백 `GoogleFonts.notoSerifKr(fontWeight: w600)`. `note_editor_screen.dart:35`도 Inter 굵기별 호출.
- ✅ `google_fonts` 동작(`gf/google_fonts_base.dart`):
  - 스타일을 만들 때 `loadFontIfNecessary`를 **fire-and-forget**으로 시작하고, 반환 스타일은 `fontFamily: 'NotoSansKR_regular'`(아직 미등록) + `fontFamilyFallback: ['NotoSansKR']` (`:52-110`). 로딩이 끝나야 비로소 등록(`FontLoader`) → 그 전 첫 프레임은 다른 폰트로 그려진다.
  - 순서: ① assets에 일치 파일 있으면 사용 ② 기기 파일시스템 캐시(**웹은 stub이라 항상 빈 값**, `gf/file_io.dart`) ③ HTTP(`https://fonts.gstatic.com/s/a/<해시>.ttf`, `google_fonts_descriptor.dart:47`). 웹에서는 브라우저 HTTP 캐시만 의존.
  - `GoogleFonts.config.allowRuntimeFetching`(기본 true), `GoogleFonts.pendingFonts()`(= `Future.wait(pendingFontFutures)`, `gf/google_fonts_all_parts.dart:110`)로 완료를 기다릴 수 있다.
- ✅ `main()`(`lib/main.dart:15-20`)은 `initializeClient`, `localeController.load()`만 기다리고 폰트는 기다리지 않는다. 테마는 `MaterialApp` build 안에서 만들어진다(첫 프레임 이후 다운로드 시작).
- ✅ **파일 크기(패키지 메타데이터 `expectedLength`)**: Noto Sans KR 400 = **6.16 MB**, Noto Serif KR 600 = **14.05 MB**, Inter ≈ 0.33 MB/굵기, Fraunces ≈ 0.07 MB/굵기. 이 앱 첫 로딩에 필요한 최소 합 ≈ **20.5 MB**(Sans KR 400 + Serif KR 600 + Inter/Fraunces). 노트 편집 화면에서 Inter 600/700을 추가 호출한다.
- ✅ 폴백 적용 범위: `sansFallback`은 `bodyLarge`/`bodyMedium`에만(`theme.dart:185-192`). `labelLarge` 등 다른 스타일은 한글 폴백 지정이 없어 엔진 폴백(§1)에 의존한다.
- ✅ 저장소에 폰트 파일이 하나도 없다(`*.ttf|otf|woff*` 검색 0건). `pubspec.yaml`의 `fonts:` 섹션 없음, `assets:`는 `assets/config.json`뿐.
- ⚠️ 시간 순서(순서는 소스 흐름에서 도출, 각 단계의 소요 시간은 미측정): 빈 흰 화면(CanvasKit·Roboto 다운로드) → 첫 프레임: Latin은 Roboto, 한글은 두부 → 엔진이 Noto Sans KR 조각 도착, 한글이 sans로 표시 → `google_fonts`의 Inter 도착(Latin 글꼴·자간 변경) → NotoSansKR_regular(6 MB) 도착 → Fraunces·NotoSerifKR_600(14 MB) 도착(제목이 sans→serif로 변경). 마지막 단계가 **가장 늦고 가장 눈에 띄는 교체**다. 각 단계의 실제 시간은 네트워크에 따라 다르며 측정하지 못했다.

### 3. 인코딩 (mojibake)

- ✅ `web/index.html:17`에 `<meta charset="UTF-8">`. 스크립트는 `flutter.js`가 `<script>`를 만들 때 charset 속성이 없어 **문서 인코딩(UTF-8)을 상속**한다. 따라서 응답 헤더에 charset이 없어도 한글 리터럴이 깨질 가능성은 낮다.
- ✅ 서빙: `server.dart:57-64`의 `FlutterRoute`(serverpod 4.0.4) → `StaticRoute.directory` → relic `StaticHandler`. MIME은 `package:mime` 확장자 매핑(`.js`·`.mjs`→`text/javascript`, `.html`→`text/html`, `.json`→`application/json`), `MimeType.isText`이면 본문 인코딩을 `utf8`로 지정해 **`; charset=utf-8`이 붙는다**(`relic_io-2.0.0-rc.2/lib/src/io/static/static_handler.dart:331-345, 578-588`, `mime-2.x default_extension_map.dart:371`).
- ✅ 실측: 로컬에서 이미 떠 있던 서버(`:8082`)에 `curl -sI`로 확인 — `content-type: text/html; charset=utf-8`. (그 서버에는 `web/app`이 없어 "build_flutter_app" 안내 페이지가 응답한 것이므로 **JS 번들 헤더는 실측하지 못했다** ⚠️. 같은 핸들러라 동일할 것으로 보는 것은 소스 근거.)
- ✅ API 응답: `server.dart:597`(serverpod)에서 `Body.fromString(…, mimeType: MimeType.json)` → 기본 utf8 → `application/json; charset=utf-8`. 브라우저 클라이언트는 `http`의 `response.body`로 디코딩(`serverpod_client_browser.dart:81`)하는데, charset이 없으면 latin1로 읽는 패키지(`http-1.6.0 response.dart:71-76`)이므로 **헤더가 charset을 가진 현재 구조에서만 안전**하다.
- ✅ 개발 중 `flutter run -d chrome`(`scripts/run.sh app`)의 dev 서버는 JS를 `application/javascript`(charset 없음)로 낸다(`tools/isolated/web_asset_server.dart:480`). 위와 같은 이유로 문서 인코딩(UTF-8)을 상속하므로 영향은 낮다 ⚠️(실행 검증 없음).
- 결론: mojibake(`í•œê¸€`, `�` 모양)는 가능성이 매우 낮다. 아래 §확인 절차로 한 번에 배제할 수 있다.

### 4. HTML 초기 화면

- ✅ `web/index.html`에 로딩 문구·스플래시·스타일이 없고 `flutter_bootstrap.js`만 `async`로 로드한다. 첫 프레임 전은 빈 흰 화면. 이 상태에서 한글이 "깨진다"는 일은 없다. `<title>pageblink_flutter</title>`, `description="A new Flutter project."`은 템플릿 그대로(별개 정리 대상).

### 5. 서비스워커·캐시

- ✅ 3.47.7의 서비스워커는 설치 즉시 자기 등록을 해제하고 열린 창을 `navigate`(새로고침)하는 스텁이다(`tools/web/file_generators/js/flutter_service_worker.js`). 로더는 **이미 등록된 서비스워커가 있을 때만** 다시 등록한다(`flutter_js/src/service_worker_loader.js` `loadServiceWorker`). 따라서 옛 Flutter 빌드를 같은 origin(예: localhost)에서 열어 본 브라우저에서만 1회 새로고침이 생길 수 있다. 구버전 번들 혼재 위험은 낮다.
- ✅ `FlutterRoute` 기본 `Cache-Control: private, no-cache`(ETag 재검증) — 번들이 오래 캐시되지는 않는다. `main.dart.js` 등은 매 방문 재검증 왕복이 있다.

---

## 해결 방안 비교

| 방안 | 가능? | 효과 (첫 로딩 한글) | 용량 · 로딩 영향 | 구현 규모 | 위험 |
|---|---|---|---|---|---|
| **A. 한글 폰트를 assets에 번들** (Noto Sans KR 서브셋 + `pubspec fonts:` + `fontFamilyFallback`) | ✅ 가능 | **가장 큼**. `fonts:`에 선언된 폰트는 엔진이 `runApp` 전에 로드(`initialization.dart:154,206-219`에서 `await`, `canvaskit/fonts.dart:114-132`)해 첫 프레임부터 한글이 나옴. 두부·교체 없음(서브셋 밖 글자 제외) | 400+700 두 굵기 서브셋 약 0.7~1.5 MB(⚠️ 추정, 아래 참고). 현재 ~20 MB 대비 크게 감소, 서버가 직접 제공 | 중. 폰트 파일 추가 + `pubspec.yaml` + `theme.dart`의 `GoogleFonts.notoSansKr/notoSerifKr` 호출 교체. **번들 한글 패밀리를 `bodyLarge/Medium`만이 아니라 TextTheme 전체(`labelLarge`·칩·`titleSmall`·내비 라벨 등)의 `fontFamilyFallback`에 넣어야 함** — 앱이 등록한 폰트는 엔진 전역 폴백(`globalFontFallbacks=['Roboto']`, `font_fallbacks.dart:39`)에 들어가지 않아, 빠뜨린 스타일은 번들 후에도 CDN 조각이 올 때까지 두부 | 서브셋 밖 한글은 여전히 엔진 폴백(드물게 두부). 굵기가 한 파일뿐이면 합성 굵기(⚠️ 미검증). 저장소 크기 증가. 폰트 라이선스(OFL 1.1) 고지 파일 동봉 필요 |
| **B. `google_fonts` 오프라인 번들** (`allowRuntimeFetching=false` + assets) | ✅ 가능 | 네트워크 제거. 단 `google_fonts`는 asset을 **비동기로** 로드(`assetManifest` 읽은 뒤 `FontLoader`)해 첫 프레임과 경합 → 교체가 짧게 남을 수 있음 | **전체 TTF 그대로**면 Sans KR 6 MB × 굵기 + Serif KR 14 MB → 서브셋 없이는 이점 작음 | 소. 파일을 `google_fonts/`에 넣고 pubspec assets 선언 + 설정 1줄. 파일명은 API 규칙(`NotoSansKR-Regular.ttf`) 필수 | 파일명 어긋나면 조용히 네트워크로 폴백(`allowRuntimeFetching=false`면 예외·로그). 서브셋 파일을 같은 파일명으로 넣는 방식은 ⚠️ 동작 미검증 |
| **C. 빌드 플래그** `--no-web-resources-cdn` | △ **부분적** | CanvasKit과 Roboto(첫 프레임 전 필수)를 자체 서빙(`tools/runner/flutter_command.dart:811-816, 1490-1496`, `web.dart:702-750`). **한글 폴백(Noto)은 여전히 `fonts.gstatic.com`**(번들하는 것은 Roboto뿐) | CanvasKit 5~7 MB가 우리 서버 부하로 이동. 외부 CDN 의존이 줄어 로딩 안정 | 소. `app/pageblink_server/pubspec.yaml` `serverpod.scripts.flutter_build.posix`의 `set -- web --base-href / --output …`에 플래그 추가 (`scloud.yaml` `pre_deploy`가 이 스크립트를 호출) | 한글 문제 자체는 해결 못 함. 한글 폴백을 자체 호스팅하려면 `flutter_bootstrap.js`의 `config.fontFallbackBaseUrl`로 Noto 조각을 직접 올려야 하며(SDK에 파일 없음 ✅, 별도 수집 필요) 유지 부담 큼 |
| **D. 첫 프레임 전 폰트 대기** (`main()`에서 `GoogleFonts.pendingFonts()` 또는 `FontLoader`) + `index.html` 스플래시 | ✅ 가능 | 교체(swap) 제거. 두부 없음 (`main()`에서 `buildPbTheme()`를 먼저 호출해 스타일을 만들어야 `pendingFonts`가 대기 대상을 가짐: 예 `await GoogleFonts.pendingFonts([buildPbTheme(Brightness.light)])`. 안 그러면 즉시 완료. 엔진 Noto 조각 다운로드는 `pendingFonts` 범위 밖) | 현재 상태에서는 **20 MB를 다 받을 때까지 빈 화면**(역효과). A와 같이 쓸 때만 의미 있음 | 소~중 (`main.dart`에 몇 줄, `index.html`에 CSS 스플래시, 첫 프레임 후 제거 로직) | 폰트 서버 장애 시 무한 대기 → 타임아웃 필수. 스플래시는 엔진 첫 프레임에 사라지므로 폰트 대기는 반드시 `main()`에서 |
| **E. 서버가 `charset=utf-8` 부여** | ✅ **불필요** | 이미 부여됨(§3). 가설 3이 맞다면 필요했을 방안 | – | – | – (확인 절차로 배제) |
| **F. 못 고칠 때 완화** (스플래시, 레이아웃 점프 완화) | ✅ 가능 | 부분적. 교체 자체는 남고 깜빡임만 줄임 | 없음 | 소 | Flutter 캔버스 텍스트에는 CSS `font-display`가 적용되지 않음 ✅(캔버스에 직접 그림) → `font-display`는 사실상 쓸 수 없음 |
| (참고) `--wasm` | ✅ 가능하나 **무관** | 한글 폴백 방식 동일(§1) | skwasm 3.4 MB + JS 폴백 병행 | 중 (`server.dart:61`의 `enableWasmHeaders`를 `true`로) | COOP/COEP 헤더로 외부 임베드·CDN 리소스 영향 |

**서브셋 크기·도구 메모 (A)**
- KS X 1001 한글 2,350자 + 라틴/기호 서브셋의 대략 크기: TTF 0.4~0.8 MB/굵기, woff2 0.2~0.4 MB/굵기 ⚠️ **추정**(실제 생성하지 않음). 전체 11,172자는 파일당 수 MB(위 6.16 MB가 그 규모).
- 로컬 도구: `pyftsubset` 없음, `python3 -c "import fontTools"` 실패 → 사용하려면 `pip install fonttools brotli` 필요(미실행). 예시(검증 안 됨): `pyftsubset NotoSansKR-Regular.ttf --unicodes=U+0020-007E,U+3131-318E,U+AC00-D7A3 --layout-features='*' --flavor=woff2 --output-file=NotoSansKR-Regular-sub.woff2` — 위 유니코드 범위는 **전체 한글 음절(11,172자)** 이므로 용량 절감을 하려면 KS X 1001 2,350자 목록(텍스트 파일)을 `--text-file=`로 넘겨야 한다.
- 라이선스: Noto Sans/Serif KR은 SIL OFL 1.1(재배포·서브셋 허용, ⚠️ 서브셋 파일의 이름 변경·라이선스 고지 요건은 해당 폰트의 OFL.txt 본문으로 확인 필요). `google_fonts` README도 OFL 파일 동봉을 안내(`google_fonts/OFL.txt`) ✅.
- ⚠️ Flutter가 웹에서 `.woff2`를 pubspec `fonts:` 자산으로 받는지는 공식 문서상 `.ttf/.otf/.ttc`만 명시되어 있어 **확인하지 못함**. 안전하게는 TTF 서브셋을 쓰고, `google_fonts`는 웹에서 `.woff2` 자산도 탐색한다(`gf/google_fonts_base.dart` `findFamilyWithVariantAssetPath`, ✅).

### 추천 순서

1. **A (+ Inter·Fraunces도 같은 방식으로 번들)** — 근본 해결. 한글 서브셋(Sans 400/700, 제목용 Serif는 용량 때문에 Sans 대체 또는 서브셋 한 굵기만) 번들, `theme.dart`에서 번들 패밀리명을 직접 지정해 `google_fonts` 호출을 줄인다. 이 단계 후 `GoogleFonts.config.allowRuntimeFetching = false`(B)로 실수 방지.
2. **D** — A로 폰트가 작아진 뒤에만. 남은 교체가 있으면 `main()`에서 기다리고(타임아웃 2~3초) 빈 화면 대신 CSS 스플래시를 둔다.
3. **C** — CDN 의존(CanvasKit·Roboto) 제거가 필요하면. 한글에는 영향 없음.
4. 즉시 효과를 보고 싶은 임시안(⚠️ 결정 사항): `notoSerifKr`를 쓰지 않고 제목 한글을 엔진 폴백(sans)에 맡기면 14 MB가 사라진다. 시각 일관성은 희생.
5. E는 불필요. `--wasm`은 이 문제와 무관.

---

## 사용자가 직접 해볼 확인 절차

두부 / mojibake / 폰트 교체를 구분하는 법.

1. **모양 구분**
   - 글자가 **□(네모 칸)** 이고 잠시 뒤 정상 글자로 바뀜 → §1·§2 (두부 후 교체).
   - 글자가 **`í•œê¸€`, `ë¬¸ì„œ`, `�`** 처럼 이상한 라틴 문자 → 인코딩(§3). 이 경우 아래 2번.
   - 글자는 읽히는데 **글꼴·굵기·간격이 순간 바뀜**(제목이 고딕 → 명조) → §2의 단계별 교체.
2. **인코딩 확인** (실제 배포 URL 또는 `web/app`을 서빙 중인 서버로)
   ```bash
   curl -sI <URL>/ | grep -i content-type
   curl -sI <URL>/main.dart.js | grep -i content-type        # text/javascript; charset=utf-8 이면 정상
   curl -sI <URL>/assets/FontManifest.json | grep -i content-type
   ```
   브라우저 콘솔에서 `document.characterSet`이 `UTF-8`인지 확인.
3. **DevTools → Network** (Disable cache 체크, Throttling `Slow 4G`로 재현이 쉬움)
   - 필터 `font` 또는 `gstatic`. 확인할 요청: `fonts.gstatic.com/s/notosanskr/v36/….woff2`(엔진 폴백), `fonts.gstatic.com/s/a/<해시>.ttf`(google_fonts, 6 MB·14 MB 항목), `…/roboto/v32/….woff2`, `www.gstatic.com/flutter-canvaskit/…/canvaskit.wasm`.
   - 첫 프레임(화면에 처음 글자가 보인 시점)보다 **늦게 끝나는 폰트 요청**이 있으면 그 폰트가 교체의 원인.
   - 요청이 **빨강(실패)** 이면 `fonts.gstatic.com` 접근이 막힌 것 → 계속 두부.
4. **Console**: `Font … is permanently unavailable`, `Could not find a set of Noto fonts to display all missing characters`, `google_fonts was unable to load font …` 경고가 있으면 폴백 실패.
5. **재현 보조**: Network → `fonts.gstatic.com` 도메인 차단(Request blocking)하면 "항상 두부"를 확인할 수 있다.
6. **프로덕션 번들로 확인**: `flutter run -d chrome`(디버그, DDC)은 느려서 증상이 과장된다. 판단은 `serverpod run flutter_build` 산출물로 하는 것이 정확하다.

---

## 미확인 · 리스크

- ⚠️ **화면에서 실제로 보이는 모양**(두부인지, 교체인지)과 사용자의 네트워크 환경은 확인하지 못함. 브라우저 실행·`flutter build`를 하지 않아 모든 시간 순서는 소스 흐름에 따른 추정이다.
- ⚠️ 프로덕션 `main.dart.js`의 응답 헤더는 실측 못 함(로컬 서버에 `web/app` 없음). 소스상 `text/javascript; charset=utf-8`.
- ⚠️ 서브셋 용량·woff2 지원·가변/합성 굵기 동작은 **빌드 후 번들 크기와 렌더링**을 직접 확인해야 한다. 절차: 서브셋 TTF 생성 → `pubspec.yaml`에 `fonts:` 선언 → `flutter build web --base-href /` (또는 `serverpod run flutter_build`) → `build/web/assets/fonts` 크기 확인 → 시크릿 창 + Slow 4G로 첫 로딩 관찰.
- ⚠️ 방화벽·한국 사내망에서 `fonts.gstatic.com`/`www.gstatic.com` 접근성은 환경별로 다르다. 해커톤 심사위원 환경이 외부 CDN을 막는다면 C+A 조합(CanvasKit·Roboto·한글 모두 자체 서빙)이 필요하고, 그 경우에도 이모지·기타 스크립트의 엔진 폴백은 남는다.
- 018의 한글 폴백명 수정(`GoogleFonts.notoSansKr().fontFamily!`)은 올바른 수정이지만 첫 로딩 다운로드를 크게 늘렸다. A를 하기 전에 이 상태를 배포하면 느린 네트워크에서 체감이 오히려 나빠질 수 있다.

## 출처

- 앱: `app/pageblink_flutter/lib/main.dart`, `lib/app/theme.dart:155-200`, `lib/features/notes/note_editor_screen.dart:30-70`, `web/index.html`, `pubspec.yaml`
- 서버·빌드: `app/pageblink_server/lib/server.dart:38-90`, `app/pageblink_server/pubspec.yaml`(serverpod scripts), `app/pageblink_server/scloud.yaml`, `scripts/run.sh`, `app/pageblink_server/Dockerfile`
- Flutter 3.47.7 웹 엔진: `bin/cache/flutter_web_sdk/lib/_engine/engine/{configuration,font_fallback_service,font_fallback_data,font_fallbacks,canvaskit/fonts}.dart`, `flutter_js/flutter.js`, `flutter_js/src/{loader,service_worker_loader,types.d.ts}`
- Flutter tools: `packages/flutter_tools/lib/src/{build_system/targets/web.dart,runner/flutter_command.dart,commands/build_web.dart,web/compile.dart,web/bootstrap.dart,isolated/web_asset_server.dart,web/file_generators/js/flutter_service_worker.js}`
- `~/.pub-cache/hosted/pub.dev/google_fonts-8.2.1/lib/src/{google_fonts_base,google_fonts_config,google_fonts_descriptor,file_io,google_fonts_all_parts}.dart`, `google_fonts_parts/part_n.dart`(Noto Sans/Serif KR 파일 크기), `README.md`(Bundling fonts)
- `~/.pub-cache/hosted/pub.dev/serverpod-4.0.4/lib/src/web_server/routes/{flutter_route,static_route}.dart`, `lib/src/server/server.dart`, `relic_io-2.0.0-rc.2/lib/src/io/static/static_handler.dart`, `relic_core-2.0.0-rc.2/lib/src/body/types/{body_type,mime_type}.dart`, `mime-2.0.0/lib/src/default_extension_map.dart`, `serverpod_client-4.0.4/lib/src/serverpod_client_browser.dart`, `http-1.6.0/lib/src/{response,utils}.dart`
- 실측: `curl -sI http://localhost:8082/` (로컬 기동 중 서버, 안내 페이지 응답 헤더)
- 관련 문서: [018](018-desktop-note-typography.md)
