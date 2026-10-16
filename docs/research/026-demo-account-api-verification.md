# 026 · demo 체험 로그인: Serverpod 4.0.4 API 소스 검증 (plan 014 §11)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 09:22 (KST) |
| 담당 | 서브에이전트 (서버 개발 엔지니어, 읽기 전용 — 앱 코드·설정 수정·서버 실행 없음) |
| 질문 | [plan 014](../plan/014-demo-account.md) §11 체크리스트 8개 + 샘플 문서 식별 · 배포 번들 디렉터리 · 커스텀 예외를 Serverpod 4.0.4 소스로 확인 |
| 결론 한 줄 | **8개 항목 모두 설계대로 구현 가능(✅)**. 단, **`DemoUser.ensure()`는 `pod.start()` _뒤_에 불러야 한다**(plan §5.1의 "앞"은 틀림 — 마이그레이션 적용이 `start()` 안이라 신규 DB에는 테이블이 아직 없음). 쿠키 모드는 설계 변경 불필요(`issueToken` 유지). 새 DB 컬럼 불필요(`contentHash` 표식으로 충분) |
| 반영 | [plan 014](../plan/014-demo-account.md) §5.1·§6.1·§6.2·§11·§13 · [ADR 020](../adr/020-demo-account-shared-user.md) 결정 3·5 (갱신은 리드 판단) |

> 방법: `~/.pub-cache/hosted/pub.dev/` 의 4.0.4 소스를 직접 읽었고, 순수 함수 2건은 **서버를 띄우지 않고** scratchpad 스크립트로 실행했으며(§1·§4), 이 문서의 코드 조각 중 "컴파일 확인" 표시는 워크스페이스 `package_config.json`에 대해 `dart compile kernel`로 타입 검사만 했습니다(실행 아님). 제품 코드·`test/`·설정은 건드리지 않았습니다.

## 핵심 결론

| # | 확인 항목 | 결론 | 한 줄 근거 |
|---|---|---|---|
| 1 | `password: null` 계정이 비밀번호로 뚫리는가 | ✅ 안 뚫림 | 해시가 빈 문자열(`''`)로 저장되고, 검증은 PHC 파싱 실패 → `false`. 4케이스 실행 확인 |
| 2 | 이메일로 계정 조회 · getter · import | ✅ | `AuthServices.instance.emailIdp.admin.findAccount(session, email:)`, 모델 `EmailAccount`(`email`·`authUserId`·`passwordHash`) |
| 3 | `AuthSuccess` 등록 메서드 | ✅ | `client.auth.updateSignedInUser(AuthSuccess?)` (`Future<void>`). 컴파일 확인 |
| 4 | `.invalid` 이메일 | ✅ | 관리자 생성 경로는 형식 검증 자체가 없고, 검증기도 `.invalid`를 통과시킴(실행 확인) |
| 5 | `demoEnabled` 읽기 · Cloud 주입 | ✅ 읽기 / ⚠️ Cloud 런타임 | 읽기 코드는 확인. `scloud variable set`(일반 환경 변수)과 `scloud password set`이 CLI 1.0.1에 **있음 ✅**(plan의 "비밀값뿐"은 낡음). 실제 주입·반영은 사용자 확인 필요 |
| 6 | 부팅 시점 · 세션 수명 | ✅ **plan과 다름** | 마이그레이션 적용→서버 시작이 `start()` 안(DB 풀은 지연 초기화). `ensure()`는 `await pod.start()` _뒤_, `maintenance` 역할만 제외. 백그라운드는 `pod.withSession`을 클로저 안에서 열고 **안에서 예외를 잡아야** 함. `signIn`은 `demoUserId`가 없으면 `ensureDemoUser`를 직접 호출 |
| 7 | 쿠키 모드 마스킹 | ✅ 설계 변경 없음 | 이 앱은 서버 `authCookie` 주석 처리 + 클라이언트 `cookieAuth` 미설정 → 항상 비쿠키. 쿠키 모드가 켜져도 `issueToken`+`updateSignedInUser`가 정상 경로. `createToken`은 오히려 틀림 |
| 8 | JWT 수명 | ✅ | 액세스 10분 · 리프레시 14일(슬라이딩), 기본값 그대로. demo만 따로 못 줄임. 만료 행 자동 삭제 없음 → 24시간 정리에 토큰 삭제를 함께 |
| + | 샘플 문서 식별 | ✅ 새 컬럼 불필요 | `Document.contentHash` 표식. 단 **빈틈 2곳**(§9.3) 막아야 함 |
| + | 배포 번들 | ✅ `web/` / ⚠️ Cloud 빌드 | 저장소 Dockerfile이 런타임에 복사하는 폴더는 `config/`·`web/`·`migrations/`뿐 |
| + | 커스텀 예외 | ✅ | `exception:` spy.yaml → `throw` → 클라이언트 `on X catch`. 저장소엔 선례 없음(기존 `AccessDeniedException`은 직렬화 불가라 500) |

### plan 014 / ADR 020의 가정과 달라진 점

| # | 문서의 가정 | 실제 | 영향 |
|---|---|---|---|
| D1 | plan §5.1: `initializeAuthServices` 이후 **`pod.start()` 전**에 `DemoUser.ensure()` | **마이그레이션 적용**(`serverpod.dart:821`)과 서버 시작(`:885`)이 `start()` 안. DB 풀은 첫 접근 때 지연 초기화되므로(`database_pool_manager.dart:25-39`) "풀이 start()에서 처음 시작"은 결정적 이유가 아님 | **`await pod.start()` 뒤로 이동.** 앞에 두면 신규 DB에서 `serverpod_auth_*` 테이블이 없다 |
| D2 | plan §6.1: 비밀값 `password set`이 "확인된 유일한 방법" | `scloud variable set`(일반·마스킹 선택)이 CLI에 존재. `--redeploy`로 변수만 반영 | 플래그는 비밀값이 아닌 **일반 변수**로 두는 게 자연스러움 |
| D3 | plan §6.4: 샘플 보호는 `_requireWrite` 한 곳이면 충분 | `upload`의 재시도 경로·`saveNote` 신규 경로는 `_requireWrite`를 안 지남. `reindexFailed`는 `AccessDeniedException`만 잡음 | 가드 3곳 추가(§9.3) |
| D4 | plan §6.2: 샘플 시드를 "임베딩 포함 백그라운드"로 — 방법 미정 | `DocumentEndpoint._index`가 라이브러리 비공개, `reindex`는 `Acl.requireUser`가 막음 | 시드용 인증 정보를 붙인 내부 세션으로 기존 엔드포인트 호출(§6.3, 컴파일 확인) |
| D5 | plan §6.4: 기존 `AccessDeniedException`과 구분되는 예외 | 기존 것은 직렬화 불가 → 클라이언트는 500만 봄 | 새 `exception:` 모델 필요(§11) — 마이그레이션은 불필요 |
| D6 | (없음) | 샘플 노트 제목이 `Sample · `로 시작하면 질문 화면이 **할 일 목록용 예시 질문**을 띄움 (`ask_suggestions.dart:7-20`) | demo 샘플 제목에 그 접두사를 쓰지 말 것 |

### 구현 순서에 영향을 주는 위험

| # | 위험 | 대응 |
|---|---|---|
| R-A | `ensure()`를 `start()` 앞에 넣으면 첫 배포(빈 DB)에서 실패. 또 부팅 헬퍼가 조용히 건너뛰면(역할·플래그·예외) 버튼은 보이는데 `signIn`이 죽음 | D1대로 `start()` 뒤. **`signIn`은 `demoUserId`가 없으면 재조회가 아니라 `ensureDemoUser`를 직접 호출**(멱등·경합 안전, §2) |
| R-B | 백그라운드 시드의 **미처리 예외는 프로세스를 죽임**(`run()`은 `runZonedGuarded` 밖) | 클로저 안에서 try/catch (§6.2 코드) |
| R-C | 다중 인스턴스 동시 부팅 → AuthUser만 만들어지고 이메일 계정 삽입이 실패하면 고아 사용자 | 두 호출을 **한 트랜잭션**에 넣고 실패 시 재조회 (§2 코드) |
| R-D | `signIn`마다 리프레시 토큰 행 누적, 만료 행은 자동 삭제 안 됨 | `signIn`·부팅 때 24시간 지난 demo 토큰 삭제 (§8) |
| R-E | 방문자가 샘플과 같은 본문으로 노트를 만들면 "샘플"로 분류돼 한도·정리를 피함 | `saveNote`에서 표식 해시 본문 거부 (§9.3) |
| R-F | 샘플 PDF가 `failed`일 때 `upload`의 재시도 경로가 방문자 텍스트로 **샘플을 덮어쓸 수 있음** | `upload` 시작부에서 표식 해시면 기존 행 반환 (§9.3) |
| R-G | Cloud 빌드 이미지가 `web/` 밖 폴더를 복사하는지 로컬 확인 불가 | 샘플 PDF는 `web/samples/`에 두고 `--wet-run --show-files`·부팅 로그로 확인 (§10) |

---

## 상세

### §1 `createEmailAuthentication(password: null)` 계정은 비밀번호로 뚫리지 않는다 ✅

**근거**

| 사실 | 위치 |
|---|---|
| `password == null`이면 `passwordHash`를 `''`로 저장 | `serverpod_auth_idp_server-4.0.4/lib/src/providers/email/business/utils/email_idp_account_creation_util.dart:272-276` |
| 라이브러리 주석이 같은 의도를 설명: "비밀번호 재설정이나 `setPassword`를 거쳐야 로그인 가능" | 같은 파일 `:255-262` |
| 로그인은 `validateHashFromString(secret: password, hashString: account.passwordHash)`가 `false`면 `EmailAuthenticationInvalidCredentialsException` | `.../email_idp_authentication_util.dart:73-77` |
| 해시 파싱 실패는 예외가 아니라 `false` (`catch → return false`) | `serverpod_auth_core_server-4.0.4/lib/src/common/utils/argon2_hash_util.dart:189-198` |
| 빈 문자열은 `split('$')`가 1조각이라 `length != 6` → `ArgumentError` → 위의 `false` | 같은 파일 `:358` |
| `passwordHash.isNotEmpty`를 "비밀번호 있음"으로 쓰는 공식 확장 | `.../email_idp_admin.dart:268` |

**실행 확인(서버 미실행, scratchpad)**: `Argon2HashUtil(...).validateHashFromString(secret: s, hashString: '')`를 `s = ''`, `'x'`, `'password'`, 가짜 PHC 문자열로 호출 → 4건 모두 `false`.

**남는 경로**: 비밀번호 재설정(`startPasswordReset`)은 검증 코드를 `demo@pageblink.invalid`로 보내므로 방문자가 코드를 받을 수 없다(`.../email_idp_password_reset_util.dart:64`~). 개발 모드에서는 코드가 서버 콘솔에 찍힌다(`serverpod_cloud_email_idp_config.dart`의 `session.alert`) — 서버 운영자만 본다. 운영에서 `.invalid` 수신자에게 Cloud 이메일 API가 호출되는 것은 **무해하지만 ⚠️ 서비스 쪽 처리(거부·반송 집계)는 확인 못 함**. 발송 실패는 로그만 남기고 예외를 던지지 않는다(같은 파일, 클래스 주석).

→ plan §11-1 "실패하면 랜덤 긴 비밀번호" **대체안 불필요**.

### §2 이메일 계정 조회 · getter · import ✅

| 질문 | 답 | 근거 |
|---|---|---|
| 모델 | `EmailAccount` (테이블 `serverpod_auth_idp_email_account`, `serverOnly`). 필드 `id`, `authUser`(→ `authUserId: UuidValue`), `createdAt`, `email`(소문자 저장), `passwordHash`. `email`에 **유니크 인덱스** | `.../email/models/email_account.spy.yaml:1-30` |
| getter | `AuthServices.instance.emailIdp` (확장 `EmailIdpGetter on AuthServices`) → `.admin` (`final EmailIdpAdmin admin`) | `.../email/business/email_idp.dart:27`·`:321-324`, 엔드포인트 쪽 사용 `.../email_idp_base_endpoint.dart:23` |
| 조회 | `admin.findAccount(session, email:)` → `EmailAccount?` (내부에서 `trim().toLowerCase()` 정규화) | `.../email_idp_admin.dart:191`, `.../email_idp_account_utils.dart:62`, `.../util/email_string_extension.dart` |
| 생성 | `admin.createEmailAuthentication(session, authUserId:, email:, password:, transaction:)` → 계정 ID. 이메일을 "검증됨"으로 취급하고 `onAfterAccountCreated` 훅을 **타지 않음** | `.../email_idp_admin.dart:18`, `.../email_idp_account_creation_util.dart:265-290` |
| AuthUser 생성 | `AuthServices.instance.authUsers.create(session, scopes:, blocked:, transaction:)` → `AuthUserModel`(`.id`) | `serverpod_auth_core_server-4.0.4/lib/src/common/business/auth_services.dart:154`, `.../auth_user/business/auth_users.dart:41` |
| import | `package:serverpod_auth_idp_server/core.dart` (`AuthServices`·`AuthUsers`·`JwtTokenManager`·`RefreshToken`), `package:serverpod_auth_idp_server/providers/email.dart` (`EmailIdp`·`EmailIdpAdmin`·`EmailAccount`·`emailIdp` 확장). **`lib/server.dart`가 이미 둘 다 import** | `serverpod_auth_idp_server-4.0.4/lib/core.dart`, `.../providers/email.dart` |

**구현 코드 (컴파일 확인)**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

const demoEmail = 'demo@pageblink.invalid';

/// demo 사용자의 authUserId. 없으면 만든다. 멱등·다중 인스턴스 안전.
Future<UuidValue> ensureDemoUser(Session session) async {
  final admin = AuthServices.instance.emailIdp.admin;
  Future<UuidValue?> find() async =>
      (await admin.findAccount(session, email: demoEmail))?.authUserId;

  final existing = await find();
  if (existing != null) return existing;
  try {
    // 한 트랜잭션: 이메일 계정 삽입이 유니크 위반으로 실패하면 AuthUser도 롤백.
    return await session.db.transaction((tx) async {
      final user = await AuthServices.instance.authUsers.create(
        session,
        transaction: tx,
      );
      await admin.createEmailAuthentication(
        session,
        authUserId: user.id,
        email: demoEmail,
        password: null,
        transaction: tx,
      );
      return user.id;
    });
  } catch (_) {
    final raced = await find(); // 다른 인스턴스가 먼저 만들었다
    if (raced != null) return raced;
    rethrow;
  }
}
```

**미구현 선택**: 가입 경로는 `UserProfile`도 만든다(`email_idp.dart` `finishRegistration`). 이 앱은 프로필 API를 쓰지 않으므로(`grep UserProfile` 0건) demo 사용자에겐 만들지 않아도 된다 ⚠️ 이후 프로필 화면을 붙이면 필요.

### §3 클라이언트: `AuthSuccess`를 세션으로 등록 ✅

| 사실 | 위치 |
|---|---|
| 시그니처 `Future<void> updateSignedInUser(AuthSuccess? authInfo)`. 저장소 저장 → `_authInfo` 갱신 → 사용자(identity)가 바뀌면 열린 스트림을 정상 종료 → `onAuthInfoChanged` | `serverpod_auth_core_client-4.0.4/lib/src/session_manager.dart:175-190` |
| 앱의 `FlutterAuthSessionManager`는 `onAuthInfoChanged`에서 `authInfoNotifier.value`를 갱신 → `authInfoListenable` 구독 UI(`sign_in_screen.dart:56`)가 자동 전환 | `serverpod_auth_core_flutter-4.0.4/lib/src/session_manager.dart:49-52` |
| 공식 컨트롤러가 같은 패턴: `final s = await endpoint.login(...); await client.auth.updateSignedInUser(s);` | `serverpod_auth_idp_flutter-4.0.4/lib/src/anonymous/anonymous_auth_controller.dart:63-64` (email·google·apple도 동일) |
| `client.auth`는 `ServerpodClientShared`의 확장 getter. 앱은 이미 `client.auth.signOutDevice()`를 씀 | `session_manager.dart` 하단, `app/pageblink_flutter/lib/main.dart:279` |

**구현 코드 (컴파일 확인 — `serverpod_auth_core_client` 기준, 앱에서는 `serverpod_auth_idp_flutter` import로 같은 타입)**

```dart
Future<void> demoSignIn() async {
  // 이미 다른 사용자로 로그인된 상태(다른 탭 등)면 서버가 SignInWhileAuthenticatedException.
  if (client.auth.isAuthenticated) await client.auth.signOutDevice();
  final authSuccess = await client.demo.signIn();   // 생성될 DemoEndpoint
  await client.auth.updateSignedInUser(authSuccess);
}
```

참고: 로그인 화면은 `_isSignedIn`이 아닐 때만 보이므로(`sign_in_screen.dart:102`) 위 `signOutDevice()`는 거의 안 타는 안전장치다. `signOutDevice`는 실패해도 `finally`에서 `updateSignedInUser(null)`을 호출한다(`session_manager.dart:266`, `_signOut`).

### §4 `.invalid` 이메일 ✅

| 사실 | 위치 |
|---|---|
| 형식 검증(`EmailValidator.validate`)은 **공개 가입 경로 `startRegistration` 한 곳**에만 있음 | `.../email_idp_account_creation_util.dart:73` |
| `createEmailAuthentication`(관리자 경로)은 `normalizedEmail`(trim+소문자)만 하고 검증하지 않음 | 같은 파일 `:265-290` |
| 검증기는 구문만 본다(TLD 목록 없음, 점이 있는 도메인이면 통과) | `email_validator-3.0.0/lib/email_validator.dart` `validate` |

**실행 확인(서버 미실행)**: `EmailValidator.validate`
`demo@pageblink.invalid` = true · `demo@pageblink.test` = true · `demo@pageblink.example` = true · `demo@example.invalid` = true · `demo@localhost` = false (점 없는 도메인).

→ `demo@pageblink.invalid` **그대로 사용**. 대체안 불필요. 단 `.invalid`로 가입 흐름 `startRegistration`을 부르면 `EmailAccountAlreadyRegisteredException`이 나므로(`:83`) 방문자가 같은 이메일을 가입으로 가로챌 수는 없다.

### §5 `demoEnabled` 읽기와 Serverpod Cloud 주입

**읽기 코드 (컴파일 확인)** — `rag_services.dart:16-20`의 `_secret()`과 같은 순서(비밀번호 → 환경 변수, 빈 문자열은 없음 취급). `_secret`은 `RagServices`의 `private static`이라 그대로 못 쓰므로 새 헬퍼를 둔다(또는 `_secret`을 공개로 바꿔 재사용).

```dart
import 'dart:io';
import 'package:serverpod/serverpod.dart';

bool _truthy(String? v) =>
    const {'true', '1', 'yes', 'on'}.contains(v?.trim().toLowerCase());

class DemoConfig {
  static const _password = 'demoEnabled';
  static const _env = 'DEMO_ENABLED';

  /// 부팅 때(세션 없음): Serverpod.getPassword = passwords.yaml + SERVERPOD_PASSWORD_*
  static bool enabledForPod(Serverpod pod) =>
      _truthy(pod.getPassword(_password) ?? Platform.environment[_env]);

  /// 요청 처리 중(status/signIn): session.passwords
  static bool enabled(Session session) =>
      _truthy(session.passwords[_password] ?? Platform.environment[_env]);
}
```

| 사실 | 위치 |
|---|---|
| `Serverpod.getPassword(key)` = 로드된 비밀번호 맵 조회 | `serverpod-4.0.4/lib/src/server/serverpod.dart:1162` |
| 비밀번호는 `passwords.yaml`(shared → 실행 모드) → **`SERVERPOD_PASSWORD_<이름>` 환경 변수** 순으로 합쳐짐 | `serverpod_shared-4.0.4/lib/src/password_manager.dart:28-46`, `_findUserDefinedPasswordsFromEnv` |
| **`passwords.yaml` 값은 문자열이어야 함.** 따옴표 없는 `true`는 `StateError`로 서버가 안 뜸 | `.../password_manager.dart:85` |

**로컬 개발**: `config/passwords.yaml`(git 제외 ✅ `app/pageblink_server/.gitignore`)의 `development:` 아래 `demoEnabled: 'true'` (**따옴표 필수**). 끄려면 줄을 지우거나 `'false'`.

**Serverpod Cloud** (CLI 1.0.1 소스 ✅, 서버 런타임 반영은 ⚠️):

| 방법 | 명령 | 런타임에 보이는 이름 | 근거 |
|---|---|---|---|
| 일반 환경 변수(마스킹 없음, 평문 표시) — **플래그에 추천** | `scloud variable set DEMO_ENABLED true` | `Platform.environment['DEMO_ENABLED']` | `variable_command.dart:12`, 사용 예 `scloud variable set SERVICE_EMAIL support@example.com` |
| 비밀값 | `scloud variable set --secret DEMO_ENABLED true` | 〃 | 같은 파일 `--secret` 옵션 |
| 비밀번호(`SERVERPOD_PASSWORD_` 접두사 자동) | `scloud password set demoEnabled true` | `getPassword('demoEnabled')` | `password_command.dart:18` "injected as environment variables" |
| 변수만 바꾸고 재시작 | `scloud deploy --redeploy` ("최신 variables·secrets로 현재 빌드를 재배포, 업로드 생략") | — | `deploy_command.dart:53-58` |

→ 위 `DemoConfig`는 두 경로(비밀번호·환경 변수)를 모두 읽으므로 어느 쪽으로 켜도 동작한다.

**사용자가 실행할 확인 명령 (⚠️ 이 문서가 확인하지 못한 부분)**

```bash
scloud variable --help                # 하위 명령 set/list/unset 존재 확인 (CLI 1.0.1 ✅ 소스에는 있음)
scloud variable set DEMO_ENABLED true
scloud variable list                  # 값이 보이는지
scloud deploy --redeploy              # 또는 일반 배포
# 반영 확인: 서버가 부팅 때 "demo enabled"를 로그에 남기게 하고 `scloud log`로 확인
```

⚠️ 남는 불확실성: ① 일반 변수가 컨테이너 환경 변수로 주입되는 시점(`--redeploy`만으로 충분한지) ② 변수명이 예약어와 충돌하는지. 둘 다 위 명령으로 사용자가 확인한다. 값 형식은 위 `_truthy`가 `'true'`·`'1'`을 받는다.

### §6 부팅 시점 · 세션 수명

#### §6.1 `DemoUser.ensure()`는 `await pod.start()` _뒤_ ✅ (plan과 다름)

| 사실 | 위치 |
|---|---|
| `start()` 안(`_unguardedStart`)에서 **마이그레이션 적용** — 신규 DB는 여기서 테이블이 생김 | `serverpod.dart:821` |
| 그 다음 API·웹 서버 시작 | `serverpod.dart:885` |
| DB 풀 자체는 생성자에서 만들고 첫 접근 때 **지연 초기화**(`start()`는 종료 후 재시작용) — 그래서 "앞에서 DB를 건드리면 실패"의 근거는 풀이 아니라 **마이그레이션 시점** | `serverpod.dart:644`·`:794-799`, `serverpod_database-4.0.4/lib/src/interface/database_pool_manager.dart:25-39` |
| `start()`는 시작이 끝나면 반환(블로킹 아님). 저장소도 `await pod.start();`가 마지막 줄 | `lib/server.dart:107` |
| 시작 훅(`registerStartHook`)은 `start()` **첫 줄**이라 DB 이전 — 쓸모 없음 | `serverpod.dart:792` |
| `monolith`·`serverless` 역할은 둘 다 사용자용 서버를 시작하고 `maintenance`는 요청을 받지 않음 → **`maintenance`만 제외**(Cloud가 어느 역할로 띄우는지는 로컬에서 ⚠️ 모름) | `serverpod.dart:862`, `serverpod_shared-4.0.4/lib/src/enums.dart:5-17` |
| `ServerpodRole`은 `package:serverpod/serverpod.dart`로 export 안 됨(컴파일 오류 확인) → `pod.config.role.name`으로 비교 | 컴파일 확인 |

→ 첫 배포(빈 DB)에서 `start()` 앞에 두면 `serverpod_auth_*` 테이블이 아직 없다. 앞에서 호출했을 때 정확히 어떻게 실패하는지는 ⚠️ 실행하지 않았다(실행하지 말 것).

⚠️ `serverless` 역할로 뜨는 호스트라면 응답 뒤의 백그라운드 작업(시드)이 CPU 제한을 받을 수 있다 — 로컬에서 확인 불가. 그 경우를 대비해 `signIn`이 사용자 단계는 직접 보장하고(아래 코드), 시드 복구는 §6.3대로 멱등으로 둔다.

#### §6.2 코드 (사용자 생성만 컴파일 확인, 시드 자리는 자리표시자)

`lib/server.dart` 맨 끝:

```dart
  await pod.start();
  await bootDemo(pod);   // ← 추가. 던지지 않는 함수여야 함
}
```

```dart
import 'dart:async';
import 'dart:io';

Future<void> bootDemo(Serverpod pod) async {
  // maintenance(마이그레이션·예약 작업 전용, 요청을 받지 않음)만 제외한다.
  // monolith·serverless는 둘 다 요청을 받으므로 프로비저닝한다.
  if (pod.config.role.name == 'maintenance') return;
  if (!DemoConfig.enabledForPod(pod)) return;
  try {
    // A. 사용자: 짧고 동기. withSession이 끝나면 세션을 닫는다.
    final demoId = await pod.withSession((s) => ensureDemoUser(s));
    DemoState.userId = demoId;

    // B. 샘플 시드: 부팅을 막지 않는다. 세션은 *클로저 안에서* 열린다.
    unawaited(pod.withSession((s) async {
      try {
        s.updateAuthenticated(
          AuthenticationInfo(demoId.toString(), const {}, authId: 'demo-seed'),
        );
        await DemoSeed.run(s, demoId); // 자리표시자 — §6.3
      } catch (e, st) {
        // 반드시 여기서 잡는다: 미처리 비동기 예외는 프로세스를 종료시킨다.
        s.log('demo seed failed', level: LogLevel.error, exception: e, stackTrace: st);
      }
    }));
  } catch (e) {
    stderr.writeln('demo boot failed: $e'); // 서버는 계속 뜬다
  }
}
```

| 사실 | 위치 |
|---|---|
| `pod.withSession<T>(callback)`: 세션을 만들고 콜백 후 닫음(예외 시 오류와 함께 닫고 rethrow) | `serverpod.dart:1204-1220` |
| `pod.createSession()`도 있으나 직접 `close()`해야 함 | `serverpod.dart:1188-1194` |
| `start()`만 `runZonedGuarded` 안. `run()` 본문 나머지는 가드 밖 → `unawaited` 미처리 예외는 루트 존 오류 | `serverpod.dart:762-785` |
| `Session.updateAuthenticated(AuthenticationInfo?)` 공개 | `serverpod-4.0.4/lib/src/server/session.dart:77` |

**세션 수명 함정**: 부팅용 세션을 `unawaited` 안에서 쓰면 바깥 `withSession`이 먼저 닫힌다. 위처럼 **백그라운드 쪽이 자기 세션을 연다**.

**`signIn` 쪽 안전망** (부팅 헬퍼가 건너뛰었거나 실패했어도 데모가 죽지 않게):

```dart
Future<AuthSuccess> signIn(Session session) async {
  if (!DemoConfig.enabled(session)) throw ...;   // 거부
  final id = DemoState.userId ??= await ensureDemoUser(session); // §2, 멱등
  await purgeExpired(session, id);                 // §8·§9.2
  return issueDemoToken(session, id);              // §7
}
```

`status().enabled`도 `flag && (DemoState.userId != null || 조회 성공)`으로 두면 사용자 생성이 실패한 환경에서 버튼이 안 보인다.

#### §6.3 시드 문서를 만드는 방법 — 선택지

`DocumentEndpoint._index`는 라이브러리 비공개이고, `reindex`·`saveNote`는 `Acl.requireUser`(= `session.authenticated`)를 요구한다(`acl.dart:9-12`).

| 선택지 | 내용 | 장단 |
|---|---|---|
| **A (추천, 최소 변경)** | 위 코드처럼 내부 세션에 `updateAuthenticated(...)`로 demo 사용자를 붙이고 `DocumentEndpoint().saveNote(s, null, title, body, null)`·`upload(s, title, pages, markerHash, null)`을 직접 호출. **컴파일 확인**: `Endpoint`는 인자 없는 생성자로 만들 수 있고 두 호출 모두 타입 검사 통과 | 색인·재시도 로직을 그대로 재사용. 시드 문서가 한도 가드에 걸리지 않는지 테스트로 확인 필요(표식 해시라 카운트 제외). 실행은 안 해 봄 |
| B | `_index`를 `DocumentIndexer` 같은 공용 클래스로 추출 | 깔끔하지만 핫패스(`document_endpoint.dart:355-448`)를 건드림 |

PDF 시드 후 원본 저장은 기존 `confirmPdfUpload`와 같은 경로·ID 규칙(`pdfs/<id>.pdf`, `document_endpoint.dart:228`·`:246-263`)을 쓰되 직접 업로드 대신 `session.storage.storeFile(storageId: 'private', path:, byteData:)`(`session.dart:402`)를 호출하고 `storagePath`를 갱신한다 ⚠️ 이 부분은 컴파일 확인 안 함.

**재시도**: 시드 도중 서버가 종료되면 문서가 `indexing`으로 남고, `document.list`가 10분 뒤 `failed/interrupted`로 바꾼다(`document_endpoint.dart:458-466`). 시드 루틴은 "표식 해시 행이 없으면 삽입+색인, 있는데 `ready`가 아니면 재색인"으로 멱등하게 쓰고, 방문자는 샘플을 `reindex`할 수 없으므로(§9.3) **서버 측 복구**가 필요하다.

### §7 쿠키 모드(웹)와 `issueToken` ✅ 설계 변경 없음

| 사실 | 위치 |
|---|---|
| `isWebAuthCookieRequest` = 서버 `authCookie` 설정이 있고 **그리고** 요청 헤더에 쿠키 모드 표식이 있을 때만 참 | `serverpod-4.0.4/lib/src/server/auth_cookie.dart:30-35` |
| 이 저장소의 `authCookie`는 3개 설정 모두 주석 처리 | `config/development.yaml:61`, `production.yaml:61`, `staging.yaml:65` |
| 클라이언트의 `cookieAuth` 기본값 `false`. 켜는 곳을 찾지 못함: `serverpod_flutter-4.0.4/lib`·생성 클라이언트 `app/pageblink_client/lib`·`app/pageblink_flutter/lib`에서 `cookieAuth` 0건, 브라우저 클라이언트에는 setter만 있고 기본값 설정 없음 | `serverpod_client-4.0.4/lib/src/cookie_auth.dart:16`, `.../serverpod_client_browser.dart:37-58` |
| 헤더 표식은 `cookieAuth`가 켜진 클라이언트만 보냄 → **서버가 Cloud에서 `authCookie`를 켜도 표식이 없으면 비쿠키** | `cookie_auth.dart:34-41` |
| `issueToken`: 쿠키 모드면 리프레시 토큰을 쿠키로 쓰고 본문에서 가림(`CookieAuthSuccess`), 아니면 그대로 반환 | `serverpod_auth_core_server-4.0.4/lib/src/common/integrations/token_manager.dart:65-103` |
| 이메일 로그인도 같은 `issueToken`을 씀 → demo `signIn`은 **기존 로그인과 같은 동작** | `.../email/business/email_idp.dart:126`·`:162` (`finishRegistration`·`login`) |
| 쿠키 모드 클라이언트의 `updateSignedInUser`는 가려진 응답(토큰 빈 값)을 기대하고 검증·정리함. **본문에 토큰이 오면 `StateError`** | `session_manager.dart:176-215` |

**판단**: `issueToken` 유지가 맞다. `createToken`은
- 정책 검사(`SignInWhileAuthenticatedException`)를 건너뛰고(`token_manager.dart:70-76`),
- 쿠키 모드가 되면 비밀이 본문에 그대로 실려 클라이언트가 `StateError`를 던지고 쿠키도 안 써진다.

즉 지금도, 나중에 쿠키 모드로 가도 `issueToken`이 안전하다. (⚠️ Cloud가 관리하는 `production.yaml`에 `authCookie`가 실제로 켜져 있는지는 로컬에서 알 수 없지만, 위 이유로 영향이 없다.)

**서버 코드 (컴파일 확인)**

```dart
Future<AuthSuccess> signIn(Session session, UuidValue demoUserId) =>
    AuthServices.instance.tokenManager.issueToken(
      session,
      authUserId: demoUserId,
      method: 'demo',
      scopes: const <Scope>{},   // null이면 AuthUser의 scope 전체(jwt.dart:140) — 지금도 빈 집합
    );
```

`DemoEndpoint.signIn`의 반환형은 `Future<AuthSuccess>`로 충분하다(`emailIdp.login`도 같은 모듈 모델을 반환, 생성 클라이언트 `app/pageblink_client/lib/src/protocol/client.dart:50`).

### §8 JWT 수명과 demo 세션 ✅

| 항목 | 값 | 위치 |
|---|---|---|
| 액세스 토큰 | **10분** | `jwt_config.dart:184` |
| 리프레시 토큰 | **14일, 슬라이딩**(회전 때마다 `lastUpdatedAt` 갱신 → 계속 쓰면 안 만료) | `jwt_config.dart:185`, `jwt_admin.dart:249` (`isExpired`) |
| 설정 위치 | `lib/server.dart:24` `JwtConfigFromPasswords()` — 인자 없음 = 기본값. `accessTokenLifetime:`·`refreshTokenLifetime:` 인자로 바꿈 | `jwt_config.dart:219-230` |
| 메서드별(demo만) 수명 | **없음.** 값은 설정 하나. 훅은 `extraClaimsProvider`·`onRefreshTokenCreated`뿐 | `jwt_config.dart` |
| 만료 행 자동 삭제 | **없음.** `deleteExpiredRefreshTokens`는 정의만 있고 인증 패키지·서버 어디서도 호출하지 않음(grep) | `jwt_admin.dart:34` |

**영향**: 활성 방문자의 demo 세션은 사실상 끝나지 않고, `signIn`마다 `serverpod_auth_core_jwt_refresh_token` 행이 쌓인다(plan R1).

**추천**: 전역 수명은 건드리지 않는다(일반 사용자에게 영향). `signIn`·부팅 때 **24시간 지난 demo 토큰만 삭제**해 문서 24시간 정리와 맞춘다. `createdAt`은 최초 발급 시각이라 활성 방문자도 24시간 뒤엔 다음 리프레시에서 로그아웃된다(= 의도된 상한).

```dart
// 컴파일 확인 (RefreshToken은 core.dart가 export)
Future<void> purgeOldDemoTokens(Session session) async {
  final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
  await RefreshToken.db.deleteWhere(
    session,
    where: (t) => t.method.equals('demo') & (t.createdAt < cutoff),
  );
}
```

만료(14일 무사용) 행 전반의 정리는 별도로 `AuthServices.getTokenManager<JwtTokenManager>().jwt.admin.deleteExpiredRefreshTokens(session)`(컴파일 확인)을 부팅 때 한 번 부르면 된다 — demo와 무관한 일반 사용자 행도 쌓이므로 선택 사항.

**공개 `signIn` 남용(R1) 완화 옵션**: 패키지의 `DatabaseRateLimiter`(`RateLimiterConfig(domain:'demo', source:'sign_in', maxAttempts:…, timeframe:…)`, `core.dart` export, `rate_limiter.dart:56`)를 전역 키 하나로 쓸 수 있다 ⚠️ 이 문서에서 컴파일하지 않았다. 필수 아님.

### §9 샘플 문서 식별 · 한도 · 정리 (새 컬럼 없이 가능 ✅)

#### §9.1 현황

| 사실 | 위치 |
|---|---|
| `Document` 필드: `ownerId`, `projectId?`, `kind`(`note`\|`pdf`), `title`, `body?`, **`contentHash`**, `version`, `pageCount`, `storagePath?`, `status`, `lastError?`, `embeddingModel`, `createdAt`, `updatedAt`. 인덱스 `ownerId`·`projectId` | `lib/src/models/document.spy.yaml` |
| 노트의 `contentHash = sha256Hex(body)`, PDF는 클라이언트가 보낸 값 | `document_endpoint.dart:146`, `:66` |
| `SampleNote.seedHash = sha256Hex(en.body)` — 가입 훅이 넣는 영어 샘플 한 건의 표식. `ensureSample`은 `version==1 & status=='indexing' & contentHash==seedHash & kind=='note' & projectId==null`인 **자기 행만** 원자적으로 `version=2`로 선점 | `sample_note.dart:53`, `document_endpoint.dart:183-213` |
| demo 사용자는 `onAfterAccountCreated`를 타지 않으므로 `seedHash` 문서가 없음 → `ensureSample`은 `null`을 반환하고 끝 | `email_idp_account_creation_util.dart:265-290` |
| `contentHash`에는 `notInSet(Set<String>)`·`equals`를 쓸 수 있고, 빈 집합이면 `notInSet`은 전체 일치 | `serverpod_database-4.0.4/lib/src/concepts/columns.dart:641-646` |

#### §9.2 구현 (컴파일 확인)

표식 = 시드 본문의 `sha256Hex`(노트) + PDF의 고정 해시 상수. 새 DB 컬럼·테이블·마이그레이션 없음.

```dart
// 방문자가 직접 만든(샘플 제외) demo 문서 수 — 한도 판정
Future<int> countUserDocs(Session s, UuidValue demo, Set<String> markers) =>
    Document.db.count(s,
      where: (t) => t.ownerId.equals(demo) & t.contentHash.notInSet(markers));

// 24시간 지난 비샘플 삭제 — 기존 DocumentCleanup 재사용
Future<void> purge(Session s, UuidValue demo, Set<String> markers) async {
  final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
  final stale = await Document.db.find(s,
    where: (t) =>
        t.ownerId.equals(demo) &
        t.contentHash.notInSet(markers) &
        (t.createdAt < cutoff));
  if (stale.isEmpty) return;
  await DocumentCleanup.deleteFiles(s, stale.map((d) => d.storagePath));
  await s.db.transaction((tx) => DocumentCleanup.deleteRows(
      s, {for (final d in stale) d.id!}, transaction: tx));
}
```

한도 검사와 삽입은 원자적이지 않다(동시 요청이면 한도를 1~2개 넘길 수 있음). 시연용으로 허용 가능 — 필요하면 ⚠️ 별도 판단.

#### §9.3 `_requireWrite`와 쓰기 메서드 — 가드가 필요한 곳

`_requireWrite`(`document_endpoint.dart:337-352`)를 거치는 호출자는 5곳이다.

| 메서드 | `_requireWrite` | 비고 |
|---|---|---|
| `saveNote` (수정) | `:160` ✅ | **신규(`documentId == null`)는 안 거침** → 한도 가드 + 표식 해시 본문 거부 필요 |
| `pdfUploadDescription` | `:238` ✅ | |
| `confirmPdfUpload` | `:250` ✅ | |
| `reindex` | `:282` ✅ | 방문자는 샘플을 재색인 못 함 → 서버 측 복구 필요(§6.3) |
| `delete` | `:478` ✅ | |
| `upload` | ❌ 거치지 않음 (`:79-111`) | 한도 가드 + **재시도 경로 가드(아래 R-F)** |
| `reindexFailed` | (`reindex`에 위임, `:313-324`) | **`AccessDeniedException`만 잡음**(`:319`) |

plan 014 §6.4의 "`_requireWrite` 한 곳"에 더해 아래 3곳을 막아야 한다.

1. **`reindexFailed`**: 가드가 새 예외(`DemoLimitException`)를 던지면 `:319`의 catch에 안 걸려 호출 전체가 실패한다. 목록에서 샘플을 제외(`!isSample(d.contentHash)`)하거나 새 예외도 잡는다.
2. **`upload`의 재시도 경로 (R-F)**: `existing`이 `failed`/`indexing`이면 `updateRow` 후 **방문자가 보낸 `pages`로 재색인**한다(`:90-111`). 샘플 PDF가 `failed`인 동안 같은 `contentHash`로 가짜 텍스트를 보내면 샘플이 덮어써진다. demo이고 `contentHash`가 표식이면 `existing`을 그대로 반환하도록 시작부에서 막는다.
3. **`saveNote` 신규 (R-E)**: 방문자가 샘플과 **같은 본문**으로 새 노트를 만들면 `contentHash`가 표식과 같아 "샘플"로 분류돼 한도·정리를 피한다. 신규·수정 모두 `sha256Hex(body)`가 표식이면 거부(또는 기존 샘플 반환).

샘플 판정 함수는 `contentHash`만 보면 된다: `bool isSample(String hash) => markers.contains(hash)`.

#### §9.4 앱 쪽 함정 (D6)

`lib/features/ask/ask_suggestions.dart:7`의 `sampleTitlePrefixes = ['Sample · ', '샘플 · ']`로 질문 화면은 **노트 제목이 이 접두사면 할 일 목록용 예시 질문**을 띄운다(`:17-20`). demo 샘플 노트 제목을 같은 접두사로 짓지 않거나, 이 판별을 `seedHash`와 연동해야 한다.

### §10 배포 번들에 들어가는 디렉터리

| 사실 | 위치 |
|---|---|
| 런타임 이미지가 복사하는 폴더: `config/`, **`web/`**, `migrations/`, `lib/src/generated/protocol.yaml`. 그 외 서버 폴더(`assets/` 등)는 **복사하지 않음** | `app/pageblink_server/Dockerfile:45-50` |
| 서버는 `web/app`, `web/pages/…`, `web/static`을 **작업 디렉터리 기준 상대 경로**로 읽음 → `File('web/samples/x.pdf')`도 같은 방식 | `lib/server.dart:57`·`:73`, `lib/src/cache_busting.dart:10` |
| `/web` 마운트는 `web/static`만, Flutter 앱은 `web/app`만 서빙 → **`web/samples/`는 공개되지 않음** | `cache_busting.dart`, `server.dart:57-64` |
| 업로드 제외 규칙: `app/.scloudignore`(저장소에 있음 ✅)가 `config/*.yaml`·`passwords.yaml`을 무시하고 `!lib/src/generated/**`·`!web/**`·`!.scloud/**`를 되살림 | `app/.scloudignore` |
| CLI는 숨김 파일(`.**`)을 기본 무시하고 `.gitignore`·`.scloudignore`를 폴더별로 적용 | `serverpod_cloud_cli-1.0.1/lib/project_zipper/project_zipper.dart:168-172`, `.../helpers/project_files.dart` |
| `app/pageblink_server/.gitignore`는 `web/app`만 무시 → `web/samples/*.pdf`는 커밋·업로드됨 | `.gitignore:9` |
| `scloud.yaml`의 `pre_deploy`는 `serverpod generate`와 `serverpod run flutter_build`뿐 — 번들 규칙 없음 | `app/pageblink_server/scloud.yaml` |

**추천 위치**: `app/pageblink_server/web/samples/pageblink-guide.pdf` (커밋 대상). 샘플 **텍스트**(페이지별)는 `sample_note.dart`처럼 Dart 상수로 두고, PDF 바이너리는 뷰어용 원본일 뿐이다. 두 쪽의 페이지 수·내용이 어긋나면 출처 칩의 페이지 번호가 틀어지므로 같은 원본에서 만든다.

**⚠️ 확인 못 한 것**: Serverpod Cloud가 자체 빌드 이미지에서 어떤 폴더를 런타임에 복사하는지는 로컬에 문서가 없다(저장소 Dockerfile은 Cloud의 것이라는 근거가 없음). `web/`는 Dockerfile·`.scloudignore` 양쪽에서 포함이 확인되는 유일한 후보다. 사용자 확인:

```bash
cd app/pageblink_server
scloud deploy --wet-run --show-files    # 업로드될 파일 트리에 web/samples/*.pdf가 있는지 (CLI 옵션 deploy_command.dart:40)
# 배포 후: 시드 루틴이 File('web/samples/…').existsSync() 결과와 바이트 수를 로그에 남기게 하고 scloud log로 확인
```

PDF가 없을 때의 대체: 시드를 **텍스트 전용**으로 두면(원본 뷰어 없음) 이 문제가 사라진다(plan §8 마지막 ⚠️).

### §11 커스텀 예외 모델 ✅

**현황**: 저장소에는 직렬화 가능한 예외가 없다. `AccessDeniedException`은 일반 `Exception`이라 클라이언트는 HTTP 500만 받는다(`acl.dart:43`, `upload_service.dart:58-62` 주석). 모듈의 예외 정의가 선례다.

**정의 (4.0.4 형식 — 모듈 파일 기준)**

```yaml
# app/pageblink_server/lib/src/models/demo_limit_reason.spy.yaml
### 어느 한도에 걸렸는가.
enum: DemoLimitReason
serialized: byName
values:
  - noteLimit
  - askLimit
  - sampleLocked
```

```yaml
# app/pageblink_server/lib/src/models/demo_limit_exception.spy.yaml
### demo 계정의 한도·보호 규칙에 걸렸을 때 던진다. 권한 오류(AccessDenied)와 다르다.
exception: DemoLimitException
fields:
  reason: DemoLimitReason
  limit: int?
```

참고 형식: `serverpod_auth_idp_server-4.0.4/lib/src/providers/email/models/exceptions/email_account_login_exception.spy.yaml`, `...login_exception_reason.spy.yaml`(`enum:`+`serialized: byName`+`default`).

**던지기 / 받기**

```dart
// 서버 — 엔드포인트 안에서
throw DemoLimitException(reason: DemoLimitReason.noteLimit, limit: 5);

// 클라이언트 — 단발 호출(unary)
try {
  await client.document.saveNote(null, title, body, null);
} on DemoLimitException catch (e) {
  // e.reason, e.limit → demoLimitReached 안내 + [가입하기]
}
```

| 사실 | 위치 |
|---|---|
| 서버: `SerializableException`이면 HTTP 400 + 타입이 붙은 JSON | `serverpod-4.0.4/lib/src/server/server.dart:262-267` |
| 클라이언트: 응답을 역직렬화해 `SerializableException`이면 **그 객체를 그대로 던짐**(아니면 `ServerpodClientBadRequest` 등) | `serverpod_client-4.0.4/lib/src/serverpod_client_shared_private.dart:35-37` |
| 스트림(`ask`): 서버가 `SerializableException`을 스트림 오류 메시지로 보내고, 클라이언트 스트림에 `addError` | `serverpod_client-4.0.4/lib/src/client_method_stream_manager.dart:313-323`, `:494-510` |
| 클라이언트 패키지(`pageblink_client`)는 `serverpod generate`가 만든다 — 직접 수정 금지(`app/AGENTS.md`) | |

- **마이그레이션 불필요 ✅(저장소 선례)**: `answer_event`·`citation`·`page_text` 등 `table:` 없는 모델은 마이그레이션 대상이 아니다. 이번 `exception`·`enum`·`DemoStatus`(plain class)도 같다. ⚠️ `serverpod generate` 결과로 최종 확인.
- **스트림 선택지**: `ask`는 기존에 `AnswerEvent(type: 'error')`를 쓴다(`answer_event.spy.yaml`). ① 같은 `DemoLimitException`을 던지면 `await for`에서 한 종류로 처리(일관) ② `AnswerEvent.type`에 `'demo_limit'`를 추가(스트림 오류 경로 불필요, 단 `type`은 String이라 앱의 switch가 새 값을 처리해야 함). 추천 ①, ⚠️ 실제 스트림 오류 경로는 실행 확인 안 함.
- `reindexFailed`처럼 `AccessDeniedException`만 잡는 호출처가 있으므로(§9.3) 새 예외는 호출처를 점검한다.

---

## 미확인 · 리스크

| # | 항목 | 상태 |
|---|---|---|
| U1 | Cloud에서 일반 변수(`scloud variable set`)가 런타임 환경 변수로 주입되는 시점·방식 | ⚠️ CLI 소스·도움말은 있으나 서버 쪽 확인 필요 (§5 명령) |
| U2 | Cloud 빌드 이미지가 `web/` 외 폴더를 복사하는지, `web/samples/`가 이미지에 들어가는지 | ⚠️ (§10 `--wet-run --show-files` + 부팅 로그) |
| U3 | `.invalid` 수신자로 Cloud 이메일 API를 호출했을 때의 서비스 쪽 처리 | ⚠️ 방문자가 `startPasswordReset`을 호출하면 발생. 실패는 로그만(예외 없음) |
| U4 | `start()` 앞에서 DB를 건드리면 던지는지 멈추는지 | ⚠️ 실행하지 않음. 어느 쪽이든 앞에 두지 않는다 |
| U5 | `DemoEndpoint`를 `lib/src/demo/`에 둬도 생성기가 찾는지 | ⚠️ 기존 엔드포인트가 `auth/`·`greetings/`·`rag_endpoints/`에 흩어져 있어 가능성 높음. `serverpod generate`로 확인 |
| U6 | 공개 `signIn`·`status` 남용, 한 방문자가 `signOutAllDevices`(생성 클라이언트에 노출된 인증 모듈 `status` 엔드포인트)로 모든 demo 세션을 끊을 수 있음 | ⚠️ 허용 가능한 위험으로 기록. 막으려면 모듈 `StatusEndpoint`를 확장해 demo 사용자면 거부 |
| U7 | 한도 검사와 삽입이 원자적이지 않음 | ⚠️ 시연용 허용 |
| U8 | 서버를 실행한 통합 확인(로그인 → 홈 → Ask → 출처) | ⚠️ 이 조사는 소스 읽기 + 순수 함수 실행 + 컴파일 타입 검사까지. 수동 시나리오는 plan §12 |

## 사용자가 실행할 명령 (모아서)

```bash
# 1) Cloud 변수
scloud variable --help
scloud variable set DEMO_ENABLED true
scloud variable list
# 2) 번들 확인 (서버 코드 추가 후)
cd app/pageblink_server && scloud deploy --wet-run --show-files
# 3) 로컬 플래그: app/pageblink_server/config/passwords.yaml 의 development: 에
#      demoEnabled: 'true'      # 따옴표 필수
```

## 출처

로컬 소스(pub-cache `~/.pub-cache/hosted/pub.dev/`, 모두 4.0.4 · CLI는 1.0.1)를 직접 읽음. 웹 문서는 조회하지 않았다.

- `serverpod_auth_core_server-4.0.4` — https://pub.dev/packages/serverpod_auth_core_server/versions/4.0.4
- `serverpod_auth_idp_server-4.0.4` — https://pub.dev/packages/serverpod_auth_idp_server/versions/4.0.4
- `serverpod_auth_core_client-4.0.4` — https://pub.dev/packages/serverpod_auth_core_client/versions/4.0.4
- `serverpod_auth_core_flutter-4.0.4` · `serverpod_auth_idp_flutter-4.0.4` — https://pub.dev/packages/serverpod_auth_core_flutter/versions/4.0.4 · https://pub.dev/packages/serverpod_auth_idp_flutter/versions/4.0.4
- `serverpod-4.0.4` · `serverpod_shared-4.0.4` · `serverpod_client-4.0.4` · `serverpod_database-4.0.4` — https://pub.dev/packages/serverpod/versions/4.0.4
- `serverpod_cloud_cli-1.0.1` — https://pub.dev/packages/serverpod_cloud_cli/versions/1.0.1
- `email_validator-3.0.0` — https://pub.dev/packages/email_validator/versions/3.0.0
- 저장소: `docs/plan/014-demo-account.md` · `docs/adr/020-demo-account-shared-user.md` · `app/pageblink_server/lib/server.dart` · `lib/src/rag_endpoints/document_endpoint.dart` · `lib/src/sample/sample_note.dart` · `lib/src/services/{rag_services,acl,document_cleanup}.dart` · `config/*.yaml` · `Dockerfile` · `app/.scloudignore` · `app/pageblink_flutter/lib/{client.dart,screens/sign_in_screen.dart,features/ask/ask_suggestions.dart}`
