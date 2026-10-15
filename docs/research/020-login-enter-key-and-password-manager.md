# 020 · 로그인 화면 2건 조사 (Enter 키 제출 안 됨 · Chrome 비밀번호 저장 안 됨)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 10:47 (KST) |
| 담당 | 서브에이전트 (general-purpose · 패키지/Flutter SDK/웹 엔진 소스 정독, 서버·브라우저 실행 없음) |
| 질문 | ① 로그인에서 Enter를 눌러도 로그인이 안 된다 ② Chrome(웹)에서 아이디/비밀번호 저장(비밀번호 관리자)이 동작하지 않는다 — 지원하려면? |
| 결론 한 줄 | ① `serverpod_auth_idp_flutter 4.0.4`의 로그인 폼 `TextField`에 `onSubmitted`/`onEditingComplete`가 없어 Enter는 포커스만 해제함(패키지 원인, 앱 래핑·단축키 가로채기 아님) ② 같은 폼에 `autofillHints`·`AutofillGroup`이 없고 앱에서 주입할 방법이 없음 → 로그인 폼만 패키지 컨트롤러 위에 자체 구현해 해결 |
| 반영 | `app/pageblink_flutter/lib/screens/email_sign_in.dart`(신규), `sign_in_screen.dart`, `test/email_sign_in_test.dart` · ADR 없음 |

> 표기: ✅ 소스로 확인 · ⚠️ 미확인/추정. 패키지 경로는 `~/.pub-cache/hosted/pub.dev/serverpod_auth_idp_flutter-4.0.4/lib/src/`(이하 `pkg/`), Flutter SDK는 `.fvmrc`의 3.47.7(`packages/flutter/lib/src/`, 웹 엔진은 `bin/cache/flutter_web_sdk/lib/_engine/engine/`). **실제 Chrome에서 저장 프롬프트가 뜨는지는 이 환경에서 확인하지 못했습니다.**

---

## 핵심 결론

| # | 이슈 | root cause | 수정 |
|---|---|---|---|
| 1 | Enter로 로그인 안 됨 | ✅ `pkg/common/widgets/text_field.dart:44-58`, `pkg/common/widgets/password_field.dart:46-84`의 `TextField`가 `textInputAction`·`onSubmitted`·`onEditingComplete`를 주지 않음. 로그인 버튼의 `onPressed`(`pkg/email/forms/login.dart:49-58`)만 `controller.login`에 연결됨 | 자체 로그인 폼 |
| 2 | 비밀번호 저장 안 됨 | ✅ 같은 필드에 `autofillHints` 없음(`AutofillGroup`·`Form`도 패키지 전체에 0건) → 웹 엔진이 `name/id`·`autocomplete="current-password"` 없는 `<input>`을 만듦 | 자체 로그인 폼 + `AutofillGroup` |

---

## 상세

### 1. Enter가 안 되는 이유 (확정)

**패키지 쪽 (✅)**

- `pkg/` 전체에서 `textInputAction|onSubmitted|onFieldSubmitted|onEditingComplete|AutofillGroup|autofillHints|finishAutofillContext|Shortcuts|FocusTraversalGroup|Form(` 검색 결과가 로그인과 무관한 `Form` 클래스 이름(`LoginForm` 등)뿐. 즉 Enter 처리도, 자동완성 힌트도 구현돼 있지 않음.
- 폼 레이아웃 `pkg/email/forms/widgets/form_standard_layout.dart:30-47`은 `SizedBox(height: 330) > Column`일 뿐 `Form`/`Shortcuts`/`Focus`가 없음.
- Flutter `widgets/editable_text.dart:3914-3954` `_finalizeEditing`: `onEditingComplete`가 null이면 `TextInputAction.done`에서 `focusNode.unfocus()`만 하고, `onSubmitted`가 null이면 즉시 return. 기본 `inputAction`은 `done`(`:5346-5385`).
- 웹 엔진 `text_editing.dart:1716-1727` `maybeSendAction`: keyCode 13이면 `onAction(inputAction)` → 프레임워크 `performAction` → 위 `_finalizeEditing`. 그래서 Enter는 "입력창 포커스 해제"만 일어남. (IME 조합 중 Enter는 keyCode 229라 여기 오지 않음.)

**앱 래핑이 가로채는지 (✅ 아님)**

- `lib/`(노트 기능 폴더 제외) 검색: `Shortcuts|CallbackShortcuts|onKeyEvent|HardwareKeyboard|KeyboardListener|Focus(` → `features/open_item/open_item_view.dart:170-175`만 있고, 이는 홈 셸 안쪽이라 로그인 화면과 무관. `MaterialApp`(`main.dart:31`)도 `shortcuts:`를 넘기지 않음.
- `_localized(...)`(`SignInLocalizationProvider`)는 문자열 전용 InheritedWidget이라 키 이벤트와 무관. 패키지 쪽 `SignInFlowCoordinatorWidget`/`SignInWidget`에도 `Focus`/`onKeyEvent` 없음.

### 2. 앱 쪽에서 가능한 것 / 불가능한 것

| 방법 | 가능 여부 | 비고 |
|---|---|---|
| 패키지 `.pub-cache` 수정 | 금지 | — |
| `Focus(onKeyEvent)`/`CallbackShortcuts`로 Enter 가로채기 | ✅ 가능 | 버튼·링크에 포커스가 있을 때 오동작하지 않도록 `EditableText` 안인지·버튼 활성 조건을 직접 복제해야 해 취약. 자동완성 문제는 못 풂 |
| `AutofillGroup`으로 감싸기 | ⚠️ 부분 | 필드들이 같은 `<form>`에 묶이지만 힌트가 비어 있어 Chrome이 username/password 쌍으로 인식한다는 보장 없음 |
| 필드에 `autofillHints` 주입 | ✅ 불가능 | `CustomTextField`/`PasswordField`는 배럴(`serverpod_auth_idp_flutter.dart`)에서 export되지 않고 파라미터도 없음 |
| **자체 로그인 폼 + 공개 `EmailAuthController` 재사용** | ✅ 가능 (채택) | 배럴이 `EmailAuthController`·`EmailSignInWidget`·`EmailFlowScreen`을 공개. 외부 컨트롤러를 넘기면 나머지 6개 화면은 패키지 위젯 그대로 사용 |

### 3. 구현 (이번에 한 것)

- `lib/screens/email_sign_in.dart`(신규 약 200줄): `PageBlinkEmailSignIn extends EmailSignInWidget`(타입을 맞춰 `SignInWidget.emailSignInWidget`에 그대로 꽂음) — `currentScreen == login`이면 `EmailLoginForm`, 아니면 `EmailSignInWidget(controller: 같은 컨트롤러)`.
  - 이메일: `textInputAction: next`, `autofillHints: [username, email]`, `onEditingComplete` = 비밀번호가 비었으면 포커스 이동, 찼으면 제출(브라우저가 둘 다 채운 경우).
  - 비밀번호: `done`, `autofillHints: [password]`, `onEditingComplete: _submit`(unfocus 기본 동작을 피해 실패 후에도 포커스 유지). 활성 조건은 패키지 버튼과 동일(이메일·비밀번호 비어 있지 않음, `state == idle`).
  - 전체를 `AutofillGroup`으로 감쌈. 가입/비밀번호 찾기 링크로 나갈 때는 먼저 `TextInput.finishAutofillContext(shouldSave: false)`(검증 안 된 비밀번호 저장 제안 방지).
  - 로그인 라벨을 `texts.passwordLabel`로 바꿔 한국어 모드에서 "Password"가 그대로 보이던 문제도 같이 해소(패키지 `login.dart:34-37`은 라벨을 넘기지 않음).
- `lib/screens/sign_in_screen.dart`(+약 50줄): 컨트롤러를 `_SignInScreenState`가 소유(`startScreen: login`, 비밀번호 규칙, `onAuthenticated`/`onError` 스낵바를 컨트롤러로 이동 — 외부 컨트롤러 사용 시 위젯 쪽 콜백은 assert로 금지, `email_sign_in_widget.dart:116-126`). 로그인 성공 후 프레임이 끝나면 컨트롤러를 dispose해 입력값이 남지 않게 함. `_SignInCard`에 `GlobalKey`를 줘 레이아웃 breakpoint(600/1024px) 전환 때 폼·자동완성 컨텍스트가 재생성되지 않게 함.
- `test/email_sign_in_test.dart`: 이메일 Enter(next)는 비밀번호 비었을 때 제출 안 함 → 비밀번호 채운 뒤 Enter(done)는 `login()` 1회 호출, 힌트·`AutofillGroup` 존재 확인.

### 4. Chrome 비밀번호 저장 — 지원 가능 여부

| 조건 | 판정 | 근거 |
|---|---|---|
| 웹 렌더러(CanvasKit/skwasm) 제약 | ✅ 무관 | 자동완성은 렌더러가 아니라 DOM 기반 텍스트 편집 계층(`_engine/engine/text_editing/`)이 처리. 포커스된 필드마다 실제 `<input>`을 만들고 `AutofillGroup` 필드는 숨겨진 `<form>`에 모음(`text_editing.dart:296-399`) |
| 힌트 → DOM 속성 | ✅ | `applyToDomElement`(`:584-612`): `name`/`id`=힌트, `autocomplete`=힌트(`password`→`current-password`, `username`→`username`; `autofill_hint.dart`). 힌트 없으면 `autocomplete="on"`뿐. 포커스 안 된 비밀번호 필드는 **힌트에 `password`가 있어야** `type=password`가 됨(`:595-596`; 포커스된 필드는 `obscureText`로 `:1444`) |
| 저장 트리거 | ✅ | `TextInput.finishAutofillContext(shouldSave: true)`(기본값) → 엔진 `saveForms()`가 숨겨진 폼의 submit 버튼을 `click()`(`:2324-2352`), 폼은 `preventDefault` 처리돼 페이지 이동 없음. 최상위 `AutofillGroup`은 dispose 시 자동 호출(`widgets/autofill.dart:235-243`) → 로그인 성공으로 폼이 사라질 때 저장됨 |
| 실제로 Chrome이 "비밀번호 저장" 프롬프트를 띄우는지 | ⚠️ 미확인 | Chrome의 저장 휴리스틱(폼 제출 후 비밀번호 필드 사라짐 판단 등)은 브라우저 구현이며 이 환경에서 실행하지 않음 |
| 자동 채우기(저장된 계정 선택) | ⚠️ 미확인 | 위 속성은 갖췄으나 실기기 확인 필요. 웹은 `TextInput.requestAutofill`을 무시하고 브라우저 UI에 맡김(`:2415-2426`) |
| HTTPS | ⚠️ 미확인 | Chrome은 비보안 컨텍스트에서 저장 UI를 제한할 수 있음(localhost는 예외로 알려져 있으나 이 환경에서 미확인) |

### 5. 남은 범위 (이번에 하지 않은 것)

- 가입(이메일 입력 → 인증 코드 → 비밀번호 설정)과 비밀번호 재설정 화면은 여전히 패키지 폼: Enter 미동작, `newPassword` 힌트 없음. 가입 직후 자동 로그인 시 Chrome 저장은 이 경로에서는 힌트 부재로 보장 못 함(⚠️).
- 규모 추정: 같은 방식(컨트롤러 재사용)으로 나머지 5개 폼(시작·인증·비밀번호 설정·재설정 시작·재설정 완료)을 옮기면 `email_sign_in.dart` +150~250줄. 더 싼 대안은 Enter만 `Focus(onKeyEvent)`로 처리하는 것(+30줄, 자동완성 힌트는 못 줌).

## 미확인 · 리스크

- ⚠️ 실기기(Chrome) 저장 프롬프트·자동 채우기 동작 미검증 — 확인 절차는 아래.
- ⚠️ 패키지의 `EmailAuthController` 이메일 디바운스 타이머(500ms)는 `dispose`에서 취소되지 않음(`email_auth_controller.dart:129-145,293-299`). 이전에도 패키지 위젯이 같은 방식으로 dispose했으므로 새로 생긴 문제는 아니지만, 마지막 입력 후 500ms 안에 로그인 성공 → 디버그 빌드에서 "disposed 후 notify" 단언이 날 가능성.
- 로그인 폼은 패키지 `LoginForm`의 복제라, 패키지 업그레이드 때 문구·동작 변경을 따라가야 함.
- `flutter test` 전체에서 `test/markdown_live_test.dart`의 "quote highlight finds exact…" 1건 실패 — 같은 시점 다른 에이전트가 작업 중인 `lib/features/notes/markdown_live.dart`(미추적 파일) 관련이며 이번 변경과 무관.

**실기기 확인 절차 (Chrome)**: ① `serverpod start`로 웹 실행, 이메일 계정으로 로그인 폼 열기 ② 이메일·비밀번호 입력 후 비밀번호 칸에서 Enter → 로그인되는지 ③ 로그인 성공 직후 주소창 오른쪽 열쇠 아이콘/"비밀번호 저장" 프롬프트 확인, `chrome://password-manager`에서 항목 확인 ④ 로그아웃 후 이메일 칸 클릭 → 저장된 계정 제안 표시·선택 시 두 칸이 채워지는지 ⑤ DevTools Elements에서 `flt-text-editing-host` 아래 `<form>`의 `input` `name`/`autocomplete`/`type` 확인 ⑥ "비밀번호를 잊으셨나요?" 링크로 이동했을 때 저장 프롬프트가 뜨지 않는지 확인.

## 출처

- `~/.pub-cache/hosted/pub.dev/serverpod_auth_idp_flutter-4.0.4/lib/src/common/widgets/{text_field,password_field}.dart`, `email/forms/login.dart`, `email/forms/widgets/form_standard_layout.dart`, `email/email_sign_in_widget.dart`, `email/email_auth_controller.dart`, `sign_in_widget.dart`
- Flutter 3.47.7: `packages/flutter/lib/src/widgets/{editable_text,autofill}.dart`, `services/{autofill,text_input}.dart`
- Flutter 3.47.7 웹 엔진: `bin/cache/flutter_web_sdk/lib/_engine/engine/text_editing/{text_editing,autofill_hint,input_action}.dart`
- 앱: `app/pageblink_flutter/lib/screens/{sign_in_screen,email_sign_in}.dart`, `lib/main.dart`
