# 020 · 데모 체험: 서버 시작 시 만드는 공유 demo 사용자 + 환경 설정 플래그

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-16 | [plan 014](../plan/014-demo-account.md) · [research 026](../research/026-demo-account-api-verification.md) · `serverpod_auth_core_server-4.0.4` / `serverpod_auth_idp_server-4.0.4` 소스 |

> 2026-10-16 09:30 KST: research 026(소스 검증)과 PM 확정 값을 반영해 결정·결과를 구체화했다. 같은 날, 미커밋 상태의 구체화이며 결정 방향(공유 계정 + 서버 시작 시 `ensure()` + 플래그)은 바뀌지 않았다.

## 맥락

- 심사위원·첫 방문자가 이메일 인증 코드를 받는 가입 없이 앱을 직접 써 보게 하고 싶다. 로그인 카드에 `Try the demo`(KO `데모 체험하기`) 버튼을 두고, 미리 만든 계정으로 바로 들어가게 한다.
- demo 계정은 **읽기 전용이 아니다.** 일반 계정과 똑같이 동작하고 샘플 노트·PDF가 미리 들어 있을 뿐이다. 실제 Ask(RAG)도 동작한다. 문서 생성은 샘플 제외 최대 5개.
- 시스템에 미리 만들어 둔 계정을 **어떻게 만들고**, **어떻게 켜고 끌지**, **어떻게 로그인시킬지**를 정해야 한다.
- 제약: 클라이언트 설정은 `assets/config.json`의 `apiUrl`뿐이다 ✅(`app_config_route.dart`). Future Calls는 Growth 플랜이라 못 쓴다 ✅(`README.md`). 서버·웹 배포는 한 번에 나간다 ✅(012).

## 결정

1. **공유 계정 1개**를 쓴다. 이메일 `demo@pageblink.invalid`(RFC 2606 예약 TLD라 메일이 도달하지 않음, 이메일 검증기 통과 ✅ research 026 §4). 코드 이름은 `DemoUser`·`demoUserId`·`DemoEndpoint`·토큰 method `'demo'`·설정 `demoEnabled`.
2. **프로비저닝은 서버 시작 시 멱등 `DemoUser.ensure()`.** 수동 작업이 0이고, DB를 새로 만들어도 자동 복구된다.
   - **호출 시점은 `await pod.start()` 뒤(D1).** 신규 DB의 마이그레이션 적용이 `start()` 안이라 앞에서 부르면 인증 테이블이 아직 없다 ✅. `maintenance` 역할만 제외한다.
   - 사용자 생성은 **부팅 중 동기**, AuthUser와 이메일 계정을 **한 트랜잭션**으로 만든다(동시 부팅 시 고아 사용자 방지). 샘플 문서 시드(임베딩 포함)는 **백그라운드**이며 세션과 예외 처리를 클로저 안에서 한다(미처리 예외는 프로세스를 종료).
   - **`signIn`이 사용자를 직접 보장한다**: `demoUserId`가 없으면 `ensureDemoUser`를 호출해, 부팅 헬퍼가 건너뛰어도 버튼이 살아 있는 채 로그인이 죽지 않게 한다.
   - "이미 시드됨" 표식은 **특정 `contentHash` 문서의 존재**(새 컬럼·테이블 없음).
3. **`demoEnabled`는 기본 꺼짐.** 운영에서 환경 설정으로 켠다. 꺼져 있으면 ① 사용자 생성·시드를 하지 않고 ② `signIn`을 거부하고 ③ 로그인 화면에 버튼을 표시하지 않는다.
   - 읽기는 비밀번호(`getPassword`/`session.passwords`) → 환경 변수 순. 주입은 Cloud 일반 환경 변수(`scloud variable set DEMO_ENABLED true`)와 비밀번호(`scloud password set demoEnabled true`) 모두 CLI에 있다 ✅(D2). **Cloud 런타임에서의 주입 시점은 ⚠️ 확인 못 함**(배포 후 로그로 확인).
4. **버튼 표시 여부는 공개 `DemoEndpoint.status()`(requireLogin=false)** 가 `enabled`를 돌려줘 정한다. 호출 실패·false면 버튼을 숨긴다.
5. **로그인은 `DemoEndpoint.signIn()`(requireLogin=false)** → `AuthServices.instance.tokenManager.issueToken(session, authUserId: demoUserId, method: 'demo', scopes: {})`로 JWT 발급 → 클라이언트가 `client.auth.updateSignedInUser`로 세션에 등록. 이미 다른 사용자로 로그인돼 있으면 서버가 `SignInWhileAuthenticatedException`을 던지므로 클라이언트가 먼저 로그아웃한다. 쿠키 모드에서도 이 경로가 정상이다 ✅.
6. **한도·정리·보호 규칙(2026-10-16 PM 확정, 사용자가 위임)**:

   | 규칙 | 확정 값 |
   |---|---|
   | 문서 한도 | 샘플 제외 demo가 만든 문서(PDF 포함) **5개**, 상수 하나로 분리 |
   | 정리 | 샘플이 아닌 demo 문서 **24시간 후 삭제** + demo 리프레시 토큰 **24시간 후 삭제**(`signIn`·부팅 시) |
   | 샘플 | 수정·삭제·재색인 불가 |
   | 프로젝트 | 생성·초대 불가 |
   | Ask | demo 전체 **일일 50회**(메모리 카운터), 초과 시 `DemoLimitException`을 스트림 오류로 전달 |
   | 시드 콘텐츠 | 노트 2개(EN 1·KO 1) + PDF 1개(`web/samples/`), 자체 제작 사용 가이드 |

7. **샘플 보호는 4곳(D3)**: `_requireWrite`, `upload`의 재시도 경로(샘플 PDF 덮어쓰기 방지), `saveNote` 신규(샘플과 같은 본문 거부 + 한도), `reindexFailed`.
8. **시드는 방식 A(D4)**: 내부 세션에 demo 사용자 인증을 붙여 기존 `DocumentEndpoint`를 호출한다.
9. **한도 초과는 새 직렬화 예외 `DemoLimitException`(D5)**: `reason`(`noteLimit`/`askLimit`/`sampleLocked`)·`limit?`. 기존 `AccessDeniedException`은 직렬화되지 않아 클라이언트가 500만 본다.
10. **샘플 노트 제목에 `Sample · `/`샘플 · ` 접두를 쓰지 않는다(D6)** — 질문 화면이 할 일 목록용 예시 질문을 띄운다.

## 대안과 기각 이유

### 프로비저닝 방식

| 대안 | 기각 이유 |
|---|---|
| 1회용 부트스트랩 엔드포인트 | 공격면이 늘고, 새 환경마다 수동 호출이 필요하며, 호출을 잊으면 버튼이 죽는다 |
| 첫 로그인 시 lazy 생성 | PDF 임베딩이 느려 첫 방문자가 대기하거나 실패한다 |
| 마이그레이션 SQL로 삽입 | auth 패키지 테이블·비밀번호 해시 스키마에 직접 의존한다(패키지 업데이트에 깨짐) |
| 로컬 스크립트로 운영 DB 시드 | Neon 접속 정보가 필요하고, PDF는 Cloud 저장소 업로드 때문에 로컬에서 안 될 수 있다(⚠️ 미확인) |

### 시드 방식

| 대안 | 기각 이유 |
|---|---|
| **B: `DocumentEndpoint._index`를 공용 클래스로 추출** | 색인 핫패스(`document_endpoint.dart`)를 건드린다. 시드 하나 때문에 일반 업로드 경로의 회귀 위험을 지지 않는다. 방식 A(내부 세션 + 기존 엔드포인트 호출)로 충분 |

### 이름·계정 모델

| 대안 | 기각 이유 |
|---|---|
| 기능 이름 "test user" | QA 픽스처로 읽혀 공개 기능 이름으로 부적절. 체험은 "demo"가 방문자에게 자연스럽다 |
| 방문자마다 임시 계정(`AnonymousIdp`, ✅ 4.0.4 내장) | 한도·격리가 자연스럽지만 계정 누적과 정리 로직이 필요. **후속 후보**로 남김 |
| 읽기 전용 계정 | 사용자 결정: 실제로 쓰고 Ask까지 해 봐야 체험이 된다 |

## 결과 (좋아지는 점 · 감수할 점 · 재검토 조건)

**좋아지는 점**

- 방문자는 한 번의 탭으로 실제 기능을 체험한다(가입·인증 코드 없음).
- 배포 후 수동 작업이 없고 DB를 새로 만들어도 자동 복구된다. 플래그를 꺼 두면 기능이 통째로 사라져 일반 환경에 영향이 없다.
- 기존 부품을 재사용한다: `issueToken`, `DocumentCleanup`, `_requireWrite`, 비밀값 읽기 패턴(`rag_services.dart`), 기존 `DocumentEndpoint`(시드).
- 새 DB 컬럼·테이블이 없다(`contentHash` 표식). `password: null` 계정이 비밀번호로 뚫리지 않음을 소스·실행으로 확인했다 ✅(research 026 §1).

**감수할 점**

- 모든 방문자가 **같은 계정**을 쓴다. 다른 방문자의 노트가 서로 보이고(개인정보 금지 안내 필요), 한도(5개)는 합산이며, 서로의 문서를 지울 수 있다.
- Ask 상한 카운터는 서버 메모리라 재시작·다중 인스턴스에서 초기화된다.
- 공개 `signIn`은 호출마다 토큰을 발급한다. 토큰 행 누적은 24시간 삭제로 완화하되(전역 토큰 수명은 그대로: 액세스 10분·리프레시 14일), 남용 자체는 막지 않는다(plan 014 R1).
- 공개 인증 모듈의 `signOutAllDevices`로 한 방문자가 모든 demo 세션을 끊을 수 있다 — **허용 위험**(plan 014 R16, ⚠️).
- 한도 검사와 삽입은 원자적이지 않아 동시 요청이면 한도를 1~2개 넘길 수 있다(시연용 허용).
- 확정 값은 사용자가 직접 고른 것이 아니라 **PM이 위임받아 정한 기본값**이다(사용자에게 한 질문에 답이 없었음).

**재검토 조건**

- 슬롯 고갈·개인정보 노출이 실제 문제가 되면 → `AnonymousIdp` 방식으로 전환(새 ADR, 이 문서와 상호 링크).
- Serverpod Cloud에서 환경 변수 주입이 안 되면 → 플래그를 비밀번호(`password set`)로만 주입하거나 방식을 바꾼다. (일반 변수와 비밀번호 두 경로 모두 코드가 읽으므로 코드 변경은 불필요)
- Cloud 빌드 이미지가 `web/samples/`를 포함하지 않으면 → 시드를 텍스트 전용으로 전환(원본 뷰어 없음).
- Future Calls(Growth 플랜)를 쓰게 되면 → 24시간 정리를 예약 작업으로 옮긴다.
