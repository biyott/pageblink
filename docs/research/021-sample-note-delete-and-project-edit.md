# 021 · 가입 시 샘플 노트 · 노트 삭제 UI · 프로젝트 수정/삭제

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-15 11:07 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용 — 코드 수정·커밋·서버 실행 없음) |
| 질문 | (1) 가입 시 샘플 노트 자동 생성 (2) 질문 화면 예시 질문을 샘플에 맞게 (3) 노트 삭제 UI (4) 프로젝트 이름 수정·삭제를 하려면 서버/DB/클라이언트에서 무엇이 필요한가 |
| 결론 한 줄 | 샘플은 **서버 `onAfterAccountCreated` 훅이 DB 행만 삽입**(가입당 1회라 "표식 테이블" 불필요) + **첫 로그인 때 클라이언트가 `locale`을 보내 한 번만 현지화·색인**. 삭제 엔드포인트는 **이미 있고 UI만 길게 누르기뿐**. 프로젝트 `update/delete`는 **새 엔드포인트 2개**, DB 마이그레이션은 없음 |
| 반영 | 결정 대기 (§E 삭제 정책 · §A 로케일 처리(시드 시점은 서버 훅으로 확정)) · 관련: [ADR 009](../adr/009-device-tier-privacy-and-sync.md) · [ADR 010](../adr/010-acl-in-query.md) · [ADR 015](../adr/015-product-scope-notes-and-pdfs.md) · [reference 001](../reference/001-features-and-limits.md) |

## 핵심 결론

| # | 항목 | 결론 |
|---|---|---|
| A | 가입 훅 | ✅ 이메일 가입 완료 시점의 서버 콜백이 있다. `ServerpodCloudEmailIdpConfig(onAfterAccountCreated: …)`. 단 **로케일을 받지 못하고**, **가입 트랜잭션 안**에서 실행됨 |
| B | 멱등성 | 훅 방식이면 계정당 1회라 **표식이 필요 없음**. "미수정 샘플인가"는 `version == 1` + 시드 해시로 판별 → **새 모델·마이그레이션 0건** |
| C | 인덱싱 | `saveNote`와 같은 `_index`를 재사용 가능 ✅. 키 없음/402여도 노트는 생성되지만, **색인 실패한 노트는 키워드 대체 검색에도 안 잡힌다** ⚠️(§C) |
| D | 노트 삭제 | ✅ 서버 `document.delete` 이미 있음(ACL·청크·페이지·PDF 정리 포함). UI는 **카드 길게 누르기뿐** — 노트 편집 화면엔 없음 |
| E | 프로젝트 | `create/list/addMember/members`만 있음. **수정·삭제·탈퇴·멤버 제거 없음**. FK·cascade 없음 → 삭제 시 수동 정리 필요 |
| F | 클라이언트 | `serverpod generate` 1회로 서버 생성물·`pageblink_client` 갱신(둘 다 커밋 대상). 화면 5곳 + l10n |
| G | 샘플 | **할 일 목록 노트**(EN/KO 초안, §G). 한 청크(900자 미만)로 들어가 질문 답이 한 번에 검색됨 |

## A. 가입/첫 로그인 훅

### 사실
- ✅ 서버는 이메일 IdP만 구성: `app/pageblink_server/lib/server.dart:20-36` (`initializeAuthServices`), `:32-34` `ServerpodCloudEmailIdpConfig(appDisplayName: 'pageblink')`.
- ✅ 계정 생성 콜백이 있다. `EmailIdpConfig.onAfterAccountCreated` — `serverpod_auth_idp_server-4.0.4/lib/src/providers/email/business/email_idp_config.dart:51-59`(시그니처: `session, {email, authUserId, emailAccountId, transaction}`), `:131-135`(문서: "프로필 생성·환영 메일 등 추가 설정용"). `ServerpodCloudEmailIdpConfig` 팩토리도 같은 인자를 받는다: `serverpod_cloud_email_idp_config.dart:82, :113`. → **`server.dart:32-34`에 인자 하나만 추가하면 됨.**
- ✅ 호출 시점: `email_idp.dart:99-134` `finishRegistration` → `email_idp_account_creation_util.dart:235-241` `completeAccountCreation`이 계정을 insert한 직후 같은 `transaction`으로 호출. 프로필 생성·토큰 발급이 그 뒤에 이어진다. 즉 **인증코드 확인 → 비밀번호 설정(finishRegistration) 완료 시점**이고, 콜백이 예외를 던지면 **가입 전체가 롤백**된다.
- ✅ 콜백에 로케일이 없다. `startRegistration`은 `email`만 받고(`endpoints/email_idp_base_endpoint.dart:60-63`), `UserProfile`에는 `userName/fullName/email/image`뿐(`serverpod_auth_core_server-4.0.4/.../user_profile.spy.yaml`). 우리 앱의 로그인·가입 UI는 패키지 `EmailAuthController`를 그대로 쓰므로(`app/pageblink_flutter/lib/screens/email_sign_in.dart:1-30`) 가입 호출에 로케일을 실어 보낼 방법이 없다(엔드포인트 시그니처를 바꾸면 패키지 클라이언트와 어긋남 ⚠️).
- ⚠️ 콜백의 `session`은 `finishRegistration` 호출 세션이라 `session.request`(`serverpod-4.0.4/lib/src/server/session.dart:152, :301-302`)에서 `Accept-Language` 헤더를 읽을 수는 있다. 웹 브라우저 언어이지 **앱 언어 선택(설정)과 다를 수 있고**, 네이티브 클라이언트는 헤더를 안 보낼 수 있다 — 실측 안 함.
- ✅ 클라이언트는 이미 "해석된 앱 언어"를 서버에 보낸다: `ask_screen.dart:94-101`(`Localizations.localeOf(context).languageCode`). 같은 방식으로 `ensure…(locale)` 호출 가능. 첫 로그인 직후 한 번 호출할 자리는 `HomeShell.initState`(`main.dart:82-87`, `_loadProjects()` 옆)가 적절 — `SignInScreen`이 로그인 후에만 `HomeShell`을 만든다(`sign_in_screen.dart:94`).

### 방식 비교

| | ① 서버 훅만 (가입 시 즉시) | ② 클라이언트 첫 로그인 호출만 | ③ **훅 삽입 + 첫 로그인 현지화/색인** (추천) |
|---|---|---|---|
| 로케일 | 모름 → 영어 고정 또는 Accept-Language ⚠️ | 정확(앱 언어) | 훅은 영어로 삽입, 호출이 한 번만 현지화 |
| 멱등성 | 가입당 정확히 1회(표식 불필요) | 표식 필요(삭제 후 재생성 방지) → 새 테이블+마이그레이션 | 가입당 1회 + `version==1` 조건(§B) |
| 기존 계정 | 영향 없음(가입 시에만) | 모든 기존 사용자에게 생김(표식 로직 필요) | 영향 없음 — 호출은 샘플이 없으면 no-op |
| 가입 지연·실패 위험 | 색인(임베딩 HTTP)을 가입 트랜잭션에서 하면 지연·행(hang) 위험 ⚠️ HTTP 클라이언트에 타임아웃 없음(`embedding_provider.dart:18`) | 없음 | DB insert만 트랜잭션 안에서 → 위험 작음 |
| 구현 크기 | 파일 1~2개 | 엔드포인트+표식 모델+마이그레이션 | 훅 + 엔드포인트 1개, 마이그레이션 0 |

### 로케일 정책 비교 (요청: "가입 시 전달" vs "영어 기본 후 첫 로그인에서 한 번만 현지화")
- **가입 시 전달**: 위 사실대로 패키지 흐름에 끼울 수 없음. Accept-Language는 ⚠️ 불확실. → 단독으로는 비추천.
- **영어 기본 → 첫 로그인 현지화(미처리 샘플일 때만)** ✅ 추천: 훅은 영어 샘플을 `status='indexing'`, `version=1`로 삽입(색인 안 함). 첫 로그인에 앱 언어를 `locale`로 받는 호출(가칭 `document.prepareSample(locale)`)이 아래 **규칙**대로 한 번만 처리한다.

  | 조건 | 동작 |
  |---|---|
  | 샘플 없음(기존 계정, 이미 삭제) 또는 `version != 1` 또는 `status != 'indexing'` | no-op (이미 처리됐거나 사용자가 고침) |
  | `locale`이 샘플 언어와 같음(영어 사용자) | 제목·본문 교체 없이 `reindex`/`_index`만 호출, 처리 표시로 `version` 2로 올림 |
  | `locale`이 다름(한국어 사용자) | 제목·본문을 한국어로 교체(`contentHash` 갱신, `version` 2) 후 `_index` |

  ⚠️ **`saveNote`를 그대로 부르면 안 된다**: 제목·본문이 같으면 `return existing`(`document_endpoint.dart:108-110`)으로 색인 없이 끝나 영어 사용자의 샘플이 영원히 `indexing`이 된다. `version`도 안 올라가므로 `version==1` 검사가 꺼지지 않아 `_index`를 직접 부르면 앱을 열 때마다 재임베딩한다. 반드시 위 표처럼 **처리 시 `version`을 올려(또는 status를 `indexing`이 아니게 만들어)** 두 번 실행을 막는다. 동시 호출은 `updateWhere(where: id & version==1)`로 선점(원자적) ⚠️.
- 부작용: 훅 삽입 직후~첫 호출 전까지 노트는 `status='indexing'`, 청크 없음. 호출은 미처리인 동안 앱 시작 때마다 재시도되므로 보통 몇 초 안에 정상화. 호출이 영영 안 오면 카드에 "색인 중"만 남는다(재시도 버튼은 `failed`에만 있음 `documents_screen.dart:482`) — 다음 앱 시작 때 호출이 다시 처리한다.

### 훅 구현 시 주의
- 콜백이 던지면 가입이 롤백되므로 **savepoint로 감싸 실패해도 가입은 성공**시킨다: `Transaction.createSavepoint()` / `Savepoint.rollback()` ✅ (`serverpod_database-4.0.4/lib/src/concepts/transaction.dart:7-27`, 사용 예 `util/database_util.dart:36-70`). Postgres는 쿼리 에러 후 트랜잭션이 중단되므로 단순 try/catch만으로는 부족.
- 훅 안의 **모든 DB 호출은 가입 `transaction:`을 넘겨야** 한다(`Document.db.insertRow(session, doc, transaction: transaction)`). 안 넘기면 샘플 행이 별도 커넥션에 커밋되어, 이후 가입이 롤백될 때 소유자 없는 행이 남는다.
- 훅 안에서는 임베딩 호출을 하지 않는다(위 지연·타임아웃 이유).

## B. 멱등성 · 재생성 방지

- 현재 모델(`app/pageblink_server/lib/src/models/*.spy.yaml`)에 사용자 단위 표식을 둘 곳이 **없다**: `Document`(`document.spy.yaml:1-27`)는 문서 단위, `UserProfile`은 `userName/fullName/email/image`(위 §A), `AuthUser`는 scope/blocked(스코프 이름에 표식을 넣는 것은 JWT 클레임에 섞이는 오용이라 기각 ⚠️).
- 클라이언트 `SharedPreferences` 표식(`locale_controller.dart:9-34`처럼)은 기기·브라우저마다 달라 새 기기에서 샘플이 다시 생긴다 → 기각.
- **추천(③): 표식 불필요.** "삭제 후 재생성 방지" = 훅이 **가입당 1회**만 실행되는 성질로 충족. "현지화 1회" = `version==1 && status=='indexing'` 조건 + 처리 시 `version` 증가로 충족(§A 규칙). 샘플 식별은 `ownerId == 나 && projectId == null && kind=='note' && version == 1 && status == 'indexing' && contentHash == sha256(영어 시드 본문)`(`sha256Hex`는 `chunker.dart:15`).
- 만약 ②(클라이언트 호출만)를 택하면 표식이 필요하다. 최소안: `UserSeed(authUserId UuidValue unique, seededAt DateTime)` 모델 1개 → 변경 규모: `lib/src/models/user_seed.spy.yaml` 1개 + 생성물(`lib/src/generated/*`, `pageblink_client/**`) + 마이그레이션 디렉터리 1개(`definition.sql/definition.json/definition_project.json/migration.sql/migration.json`, 기존 `migrations/20261014154208706/` 형태) + `migration_registry.txt` 1줄. `app/AGENTS.md` 지침대로 MCP `create_migration`→`apply_migrations`. 동시 호출 경합은 표식 행을 **먼저** insert하고 unique 위반이면 중단하는 방식.

## C. 샘플 노트 인덱싱

- ✅ 저장 경로: `saveNote`(`document_endpoint.dart:64-124`)가 Document insert/update 후 `_index`(`:273-351`)를 호출. `_index`는 ① `DocPage` 원문 저장(`:279-293`) → ② `chunkPages`(≤900자/청크, `chunker.dart` `maxChars=900`) → ③ 임베딩(`:298-304`) → ④ `DocChunk` 교체(`:306-330`). 같은 클래스의 새 메서드에서 `saveNote(session, null, title, body, null)` 또는 `_index`를 그대로 호출하면 재사용 ✅ (코드 중복 0).
- 실패 동작 ✅: ②~④는 `try/catch`(`:294-349`) 안이라 임베딩 키 없음(`rag_services.dart:31` `StateError`)·402(`embedding_provider.dart:51-55` → `_friendlyError` `:235-242` `'quota'`)·타임아웃 모두 **노트는 생성**되고 `status='failed'` + `lastError`로 남는다. 카드에 "다시 색인" 버튼이 뜬다(`documents_screen.dart:482, :601-610`).
- ⚠️ **키워드 대체 검색은 이 노트를 못 찾는다.** `ask_endpoint.dart:57-79`의 대체 경로는 `DocChunk.text`를 `ilike`로 검색하는데, 임베딩이 실패하면 청크 insert(`document_endpoint.dart:306-330`)에 도달하지 않아 **청크가 0개**다(DocPage 원문만 있음). 즉 "키 없음/402인 환경의 신규 가입자"에게는 샘플이 있어도 질문에 답이 안 나온다. 또 키가 없을 때는 질의 임베딩이 `StateError`(`rag_services.dart:31`)라 `on EmbeddingException`(`ask_endpoint.dart:57`)에 안 걸려 대체 검색 없이 바로 오류 응답으로 간다(`ask_endpoint.dart:153-165` 바깥 catch) ⚠️. 개선 여지(결정 필요, 이번 범위 밖): 대체 검색을 `DocPage.text`/`Document.body`에서도 하게 하기.
- 비용·지연: 샘플은 1청크 → 가입자당 임베딩 요청 **1회**(`embed`는 32개 단위 배치, `embedding_provider.dart:34-55`). 지연은 측정 기록 없음 ⚠️. 샘플 본문이 짧고 현지화 때 교체하면 요청은 총 1회(훅은 임베딩 안 함).
- 요청 경로에서 동기 처리: 훅(가입 트랜잭션)에서는 ✗(위 §A). 첫 로그인 호출은 `await`해도 무방하나 **UI를 막지 않도록 클라이언트는 fire-and-forget 후 완료 시 `boardRefresh.value++`**(`open_item_controller.dart:5`). HTTP 타임아웃이 없으므로(`embedding_provider.dart:18`) 호출에 타임아웃을 두는 것을 권장 ⚠️.

## D. 삭제 기능 현황

- ✅ 서버: `document.delete(documentId)` — `document_endpoint.dart:368-394`. ACL `_requireWrite`(`:255-270`): 개인 문서는 소유자만, 프로젝트 문서는 owner/editor(**viewer 불가**, 작성자 무관 — 편집자가 남의 문서도 삭제 가능). 정리: PDF 원본 `session.storage.deleteFile`(실패는 경고 로그만, `:373-380`), 트랜잭션으로 `DocChunk`·`DocPage`·`Document` 삭제(`:381-393`). 없는 문서는 조용히 반환.
- ✅ 클라이언트: `documents_screen.dart:156-182` `_delete`(확인 `AlertDialog` → `client.document.delete` → `_refresh()`), 트리거는 **카드 `onLongPress`뿐**(`:481`). PDF·노트 공통. 데스크톱에서는 길게 누르기가 발견되기 어렵다.
- 갭: ① 노트 편집 화면(`note_editor_screen.dart:281-333` `PaneHeader.actions`)에 삭제 없음 ② 카드에 메뉴/아이콘 없음 ③ `LocalPdfs`에 삭제 메서드 없음(`local_pdfs.dart`: save/fetch/load만) — 기기 로컬 PDF 복사본이 남음(경미) ④ 삭제된 문서를 가리키는 이전 답변의 인용을 열면 `get`이 null(`document_endpoint.dart:127-130`) ⚠️ 화면 동작 미확인.
- 서버 변경: **없음** (이름·시그니처 그대로).

## E. 프로젝트 수정/삭제

### 현황 ✅
- 엔드포인트 4개: `create`(`project_endpoint.dart:12-27`, 생성자를 `owner`로 insert), `list`(`:29-38`), `addMember`(`:41-71`, owner만, role `editor|viewer`, 이미 멤버면 role 갱신), `members`(`:73-80`, 클라이언트에서 호출처 없음).
- **없는 것**: 이름 수정, 삭제, 탈퇴(leave), 멤버 제거, 소유권 이전. README의 `delete` 언급(`README.md:75`)은 `document.delete`다.
- 모델 `Project`: `name, ownerId, createdAt`뿐(`project.spy.yaml:3-7`) → 수정 가능 필드는 **이름만**. `ProjectMember`(`project_member.spy.yaml`): `projectId, userId, role`, `(projectId,userId)` unique.
- 권한 `Acl.requireRole`(`acl.dart:26-40`): 멤버십+역할 확인. `addMember`가 owner를 못 만들므로 **프로젝트당 owner는 생성자 1명**.
- `create`는 이름을 서버에서 검증하지 않음(`project_endpoint.dart:12-17`; 클라이언트가 trim/빈값만 거름 `projects_screen.dart:50`) ⚠️.
- 삭제 영향 범위: ✅ **FK·cascade 없음** — `project`/`project_member`/`document`/`doc_chunk`/`doc_page`에 외래키가 없고(`migrations/20261014154208706/definition.sql`의 FOREIGN KEY는 `serverpod_*` 테이블뿐) `projectId`는 단순 정수 컬럼. 따라서 삭제는 **서버 코드가 직접** `DocChunk`·`DocPage`·`Document`·`ProjectMember`·`Project`를 지우고, PDF 스토리지 파일(`pdfs/{documentId}.pdf`, `document_endpoint.dart:139`)을 별도로 지워야 한다. 청크에 `projectId`가 **비정규화**되어 있어(`doc_chunk.spy.yaml:6-7`) "개인 영역으로 이동"은 `Document`와 `DocChunk` 둘 다 갱신해야 한다(`updateWhere` 사용 가능 ✅ `generated/document.dart:790`).

### 제안 시그니처 (선택 위치 인자는 기존 `ask`가 `[String? locale]`로 이미 사용 ✅ `ask_endpoint.dart:25`; 기본값 `= false` 표기는 ⚠️ `serverpod generate`로 확인)
```dart
/// Owner only. Trims; 1..60 chars.
Future<Project> updateProject(Session session, int projectId, String name);

/// Owner only. Returns how many documents were deleted.
/// deleteDocuments=false (default): throws ArgumentError('not_empty') if documents exist.
Future<int> deleteProject(Session session, int projectId, [bool? deleteDocuments]);
```
- ACL: 둘 다 `Acl.requireRole(..., roles: {'owner'})`. (이름 변경을 editor까지 허용할지는 선택지 — 추천은 owner만.)
- 삭제 순서: ① 트랜잭션 안에서 청크→페이지→문서→멤버→프로젝트 삭제(또는 이동) ② 트랜잭션 밖에서 PDF 파일 삭제(실패는 경고 로그, `document.delete`와 동일 패턴 `:373-380`). 문서 삭제 로직은 `document.delete`의 본문을 private 헬퍼로 빼 재사용.
- (범위 밖, 후속 후보) `leaveProject`(owner 제외 본인 멤버십 삭제), `removeMember`(owner).

### 삭제 정책 옵션

| 옵션 | 동작 | 장점 | 단점 |
|---|---|---|---|
| 1. 문서도 함께 삭제 | 확인 후 문서·청크·PDF·멤버 전부 삭제 | 구현 단순, 잔여물 없음 | 다른 멤버가 올린 문서까지 사라짐(되돌릴 수 없음) |
| 2. **비어 있을 때만 삭제** (추천) | 문서가 있으면 거절(개수 반환) → 사용자가 문서를 먼저 정리 | 가장 안전·단순, 의도치 않은 파괴 없음 | 문서가 많으면 번거로움. owner는 프로젝트 문서를 삭제할 수 있어 막히지는 않음(`_requireWrite`) |
| 3. 문서를 개인 영역으로 이동 | 문서의 `projectId`→null, **작성자(`ownerId`)의 개인 문서**가 됨 | 비파괴 | 다른 멤버 문서가 그 멤버 개인 문서가 되어 공유 범위가 갑자기 바뀜 · owner는 자기 것만 가짐 · `Document`+`DocChunk` 2테이블 동시 갱신 필요 |

**추천: 옵션 2를 기본**으로 하고, 확인 다이얼로그에 문서 개수와 "문서까지 모두 삭제" 명시 체크(→ `deleteDocuments=true`, 옵션 1)를 선택 기능으로 둔다. 옵션 3은 공유 범위 변화 때문에 비추천.

## F. 클라이언트 영향

- 재생성: 새 엔드포인트 메서드(`updateProject`, `deleteProject`, `document.<sample>`)와 인자 변경이 생성물에 반영된다. `serverpod start`가 증분 생성하며, 안 되면 서버 패키지에서 `serverpod generate`(`app/AGENTS.md`). 생성물 `app/pageblink_server/lib/src/generated/*`와 `app/pageblink_client/**`는 **저장소에 커밋됨**(`git ls-files` 확인 ✅)이라 diff가 생긴다. 수동 편집 금지.
- DB 마이그레이션: ③ 방식은 **0건**. ②로 가면 §B의 `UserSeed` 1건.
- 화면별 변경:

| 파일 | 변경 |
|---|---|
| `features/documents/documents_screen.dart` | 카드에 `⋮` 메뉴(삭제) 추가 — 길게 누르기도 유지(`:481`). 삭제 후 `_refresh()`는 이미 있음(`:181`). viewer는 메뉴 숨김(현재 role은 클라이언트가 모름 → 프로젝트 `ownerId`/삭제 시 서버 `AccessDeniedException`을 스낵바로, 또는 `members` 호출 ⚠️) |
| `features/notes/note_editor_screen.dart` | `PaneHeader.actions`(`:293-332`)에 삭제 버튼 + 확인 다이얼로그(기존 `_delete` 로직을 공용 함수로 이동). **주의**: 삭제 직후 닫을 때 `_flush`(`:156-180`)가 다시 `saveNote(_id…)`를 부르면 "Note not found" → 삭제 성공 시 `_savedTitle/_savedBody`를 현재 값으로 맞추거나 `_deleted` 플래그로 `_flush`가 즉시 `true`를 반환하게 해야 함. 이후 `boardRefresh.value++` + 창 닫기(`onClose`) |
| `features/projects/projects_screen.dart` | `ListTile.trailing`(`:103-107`)을 초대 아이콘 → `PopupMenuButton`(초대/이름 변경/삭제)로. 소유자 판별 `project.ownerId == client.auth.authInfo?.authUserId` ✅(`session_manager.dart:65`, `auth_success.dart`); 소유자가 아니면 초대·수정·삭제 숨김 |
| `main.dart` | 프로젝트 변경 후 `_loadProjects()`(이미 `onChanged`로 연결 `:173`) + 삭제 시 `boardRefresh.value++`로 보드·사이드바 개수 갱신(`main.dart:417` `documentsNotifier`). `HomeShell.initState`(`:82-87`)에서 샘플 호출(fire-and-forget) |
| `features/ask/ask_screen.dart` | `_EmptyHint`(`:840-`)가 샘플 존재 시 샘플 질문을 앞에 표시(§G). `_selectedProjects`(`:41`)에 삭제된 프로젝트 id가 남아도 서버가 멤버십과 교집합을 하므로 무해(`ask_endpoint.dart:30-33`), 표시 개수는 `widget.projects` 기준이라 정상(`ask_screen.dart:77-78`) |
| `app/l10n.dart` | 신규 문자열(삭제 확인·프로젝트 이름 변경·삭제·"비어 있지 않음"·샘플 질문). 재사용: `delete`(`:29`), `deleteQuestion`(`:136`), `deleteFailed`(`:137`), `cancel/ok`(`:26-27`) |

- UX 제안: 확인 다이얼로그에는 제목과 함께 영향 설명 — 노트: "‘{제목}’을 삭제할까요? 색인된 검색 내용도 함께 지워집니다"; 프로젝트: "문서 N개 · 멤버 M명", 문서가 있으면 "먼저 문서를 삭제하거나, 아래 체크로 함께 삭제". **되돌리기**: 서버가 하드 삭제라 진짜 undo는 소프트 삭제(`Document.deletedAt` 컬럼 → 마이그레이션) 필요 → v1은 확인 다이얼로그만. 선택적으로 노트에 한해 스낵바 "되돌리기"(보관한 제목·본문·`projectId`로 `saveNote(null, …)` 재생성, id·작성일 달라지고 이전 인용은 끊김) — 서버 변경 없음.
- 삭제 후 갱신 흐름: `await client.document.delete` → `boardRefresh.value++`(`open_item_controller.dart:5`) → `DocumentsScreen._refresh`(`documents_screen.dart:37, :46-59`) → `documentsNotifier`(`:52`)로 사이드바 개수 갱신. 열린 항목이 삭제 대상이면 `OpenItemController.close()`(`open_item_controller.dart:66-71`).

## G. 샘플 노트 내용 설계안 (할 일 목록)

설계 원칙: 본문을 **한 청크(900자 미만)**로 유지해 질문 답이 한 번에 검색되도록 하고, `Today / This week / Later` 3개 헤딩 + 체크됨 `- [x]`·미완료 `- [ ]` + 마감/메모가 든 항목 3개를 둔다. 서버가 본문을 보유하므로 클라이언트는 `locale`만 보낸다. 판별을 위해 제목은 영어 `Sample · …`, 한국어 `샘플 · …`.

### EN
제목: `Sample · My to-do list`

```markdown
# My to-do list

## Today
- [x] Reply to Sam about the venue
- [x] Buy coffee beans
- [ ] Send the invoice to Acme (due 5 pm)

## This week
- [ ] Book the dentist (call before Wednesday)
- [ ] Finish the slides for Friday's team meeting
- [ ] Renew passport (needs 2 photos)

## Later
- [ ] Plan a weekend trip to Busan
- [ ] Clean out the garage
```

예시 질문 (답이 노트 안에 있음):
1. What is left to do this week? → 치과 예약, 금요일 회의 슬라이드, 여권 갱신
2. What have I already finished? → Sam 답장, 커피 원두
3. What is due today? → Acme 청구서 (오후 5시)
4. What do I need to renew my passport? → 사진 2장

### KO
제목: `샘플 · 할 일 목록`

```markdown
# 내 할 일 목록

## 오늘
- [x] 민수에게 장소 관련 답장 보내기
- [x] 커피 원두 사기
- [ ] 한빛상사에 청구서 보내기 (오후 5시까지)

## 이번 주
- [ ] 치과 예약하기 (수요일 전에 전화)
- [ ] 금요일 팀 회의 발표 자료 마무리
- [ ] 여권 갱신하기 (사진 2장 필요)

## 나중에
- [ ] 주말 부산 여행 계획 세우기
- [ ] 창고 정리하기
```

예시 질문:
1. 이번 주에 남은 일은 뭐야?
2. 이미 끝낸 일은 뭐야?
3. 오늘 마감인 일은?
4. 여권 갱신에 뭐가 필요해?

### 질문 화면 반영
- 현재 `askSuggestions`(`l10n.dart:192-204`, 4개 일반 문구)를 유지하고, 샘플 질문용 `sampleSuggestions`(위 4개 ×2언어)를 **앞에** 둔다. `_EmptyHint`(`ask_screen.dart:840-`)의 `for (final s in context.l.askSuggestions)`(`:870`)를 `[...sample(있을 때만), ...askSuggestions]`로.
- 표시 조건: 보드에 샘플이 있을 때만 샘플 질문을 앞세운다 — 사용자가 샘플을 지웠는데 질문 칩이 남으면 "관련 내용을 찾지 못했어요"가 나온다(`ask_endpoint.dart:88-96`). 판별: `documentsNotifier`(`documents_screen.dart:498`, `IndexedStack`이라 처음부터 채워짐 `main.dart:262-266`)에서 `kind=='note'`이고 제목이 `Sample · `/`샘플 · `로 시작하는 노트. 사용자가 제목을 바꾸면 일반 질문으로 되돌아가는 정도는 허용.
- 질문 언어는 UI 언어(`context.l`) 기준. 노트 언어와 달라도 임베딩 모델은 다국어라 동작은 하나 정확도는 ⚠️ 미확인. 테스트는 `test/ask_l10n_test.dart` 스타일로 추가.

### 라이브 에디터에서 체크리스트가 보이는 방식
- ✅ `- [ ] `/`- [x] ` 마커는 **글자 그대로 남고** 흐린 색으로만 표시된다(`markdown_live.dart:1-9` 주석, `:300-306` → `st.marker`). 체크된 항목(`[x]`) 본문은 흐린 색 + 취소선(`markdown_live.dart:305`, 스타일 `note_editor_screen.dart:81-84`). 헤딩 `##`은 마커를 흐리게 하고 글자만 키운다(`:282-292`).
- ✅ 체크박스를 **탭해서 토글하는 기능은 없다**(reference 001 "checkboxes cannot be toggled in the preview"). 체크하려면 `[ ]`의 공백을 `x`로 직접 고치거나, 툴바 체크리스트 버튼(`toggleCheck`, `markdown_live.dart:518-523`)으로 줄을 `- [ ] `로 바꾼다. 이 때문에 샘플의 "체크 표시된 항목"은 보기에는 취소선으로 구분된다.
- 카드 미리보기는 `- [ ] ` 접두를 제거한 텍스트만 보여 준다(`documents_screen.dart:535`).

## 미확인 · 리스크
- ⚠️ 첫 로그인 호출 전 상태(`status='indexing'`, 청크 없음)에서 사용자가 질문하면 샘플은 검색되지 않음(수 초 내 정상화).
- ⚠️ Accept-Language 기반 로케일 추정, 선택 인자(`[bool? deleteDocuments]`)의 생성 동작, 임베딩 지연은 실측 안 함.
- ⚠️ 색인 실패 노트가 키워드 대체 검색에서 빠지는 문제는 샘플 외 일반 노트에도 해당(§C).
- ⚠️ 동시 호출(두 탭) 시 현지화가 두 번 실행될 수 있음 → `updateWhere(where: id & version==1)`로 선점(원자적)하면 해결 — 구현 시 확인.
- ⚠️ 콜백이 가입 트랜잭션 안에서 도는 점: savepoint 없이 예외를 삼키면 트랜잭션이 중단 상태로 남아 가입이 실패할 수 있음(§A).
- 이번 조사 범위에서 코드 실행·테스트는 하지 않았다(읽기 전용).

## 결정이 필요한 선택지
1. **시드 시점(§A) — 클라이언트 결정 완료**: 가입 시점에 서버 훅(`onAfterAccountCreated`)으로 시드한다. 남은 선택은 **로케일**뿐: (가) 영어 삽입 후 첫 로그인에 한 번 현지화(추천, 위 규칙) vs (나) 가입 시 Accept-Language 추정 ⚠️(앱 언어 선택과 어긋날 수 있음). 훅에서 즉시 색인하는 안과 클라이언트 호출만 쓰는 안(+표식 테이블)은 비추천.
2. **프로젝트 삭제 정책(§E)**: 옵션 2 "비어 있을 때만"(추천, 선택적으로 "문서까지 삭제" 체크) vs 옵션 1 vs 옵션 3.
3. 프로젝트 이름 변경 권한: owner만(추천) vs editor 포함.
4. 노트 삭제 되돌리기: 확인 다이얼로그만(추천) vs 스낵바 되돌리기(클라이언트 재생성).
5. (범위 밖) 키워드 대체 검색이 `DocPage`/`body`도 보게 할지.

## 출처
- 코드: `app/pageblink_server/lib/server.dart`, `lib/src/rag_endpoints/{document,project,ask}_endpoint.dart`, `lib/src/services/{acl,rag_services}.dart`, `lib/src/providers/embedding_provider.dart`, `lib/src/rag/chunker.dart`, `lib/src/models/*.spy.yaml`, `migrations/20261014154208706/definition.sql`
- 코드: `app/pageblink_flutter/lib/{main.dart,app/l10n.dart,app/open_item_controller.dart,app/pane_header.dart,app/local_pdfs.dart,features/documents/documents_screen.dart,features/projects/projects_screen.dart,features/notes/{note_editor_screen,markdown_live}.dart,features/ask/ask_screen.dart,screens/{sign_in_screen,email_sign_in}.dart}`
- 패키지(`~/.pub-cache/hosted/pub.dev/`): `serverpod_auth_idp_server-4.0.4/lib/src/providers/email/business/{email_idp_config,serverpod_cloud_email_idp_config,email_idp}.dart`, `.../business/utils/email_idp_account_creation_util.dart`, `.../endpoints/email_idp_base_endpoint.dart`; `serverpod_auth_core_server-4.0.4` (`user_profile.spy.yaml`); `serverpod_auth_core_client-4.0.4` (`session_manager.dart`, `auth_success.dart`); `serverpod_database-4.0.4/lib/src/{concepts/transaction.dart,util/database_util.dart}`; `serverpod-4.0.4/lib/src/server/session.dart`
- pub.dev: https://pub.dev/packages/serverpod_auth_idp_server/versions/4.0.4 · https://pub.dev/packages/serverpod_auth_core_server/versions/4.0.4 · https://pub.dev/packages/serverpod_auth_core_client/versions/4.0.4 · https://pub.dev/packages/serverpod_database/versions/4.0.4 · https://pub.dev/packages/serverpod/versions/4.0.4
- 프로젝트 문서: `AGENTS.md`, `app/AGENTS.md`, `docs/adr/009,010,015`, `docs/reference/001-features-and-limits.md`
