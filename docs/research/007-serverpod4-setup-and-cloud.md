# 007 · Serverpod 4 셋업·Cloud 배포

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Serverpod 4 설치·생성·실행 절차, 공식 AI & RAG 튜토리얼, 인증 설정, Cloud 배포 명령, 주의점은? |
| 결론 한 줄 | `dart install serverpod_cli` → `serverpod create` → `serverpod start`(Docker 불필요) · 사용자 ID `UuidValue` · `serverpod cloud launch/deploy` |
| 반영 | [plan 003 §1, §2](../plan/003-tech-stack-and-prep.md) |

> 대부분 요약 도구를 거쳐 가져온 문서라 코드 조각은 붙여넣기 전에 확인 필요. RAG 골격 코드는 Serverpod 공식이 아니라 조사자가 구성한 것

## 1. 셋업
- ✅ CLI 설치: `dart install serverpod_cli` (업그레이드 가이드는 버전 지정 예: `dart install serverpod_cli 4.0.0-beta.1`). 구 방식 `dart pub global activate serverpod_cli`. 확인 `serverpod version`
- SDK: 업그레이드 가이드는 Dart `^3.10.3` ✅. **단 pub.dev의 4.0.4 실제 제약은 `^3.12.2`** ([008](008-flutter-client-stack.md)) → 엄격한 쪽 채택. 모든 `serverpod*` 패키지를 같은 정확한 버전으로 고정
- ✅ 생성: `serverpod create myapp` → `myapp_server`, `myapp_client`, `myapp_flutter` (greeting 엔드포인트 + `GreetingsScreen` 포함)
- ✅ 실행: 프로젝트 루트에서 `serverpod start` → 코드 생성 + 서버 기동 + 브라우저에서 Flutter 앱. **Docker 불필요.** `R` 핫리스타트, `M` 마이그레이션 생성·적용
- ⚠️ 수동 명령: `serverpod generate`, `serverpod create-migration`(`--force`), 서버 디렉터리에서 `dart bin/main.dart --apply-migrations`
- ⚠️ 로컬 pgvector: 문서 충돌 (내장 Postgres에 0.8.3 포함 vs 없음). 없으면 Docker `ghcr.io/serverpod/postgres:16`

## 2. AI & RAG 튜토리얼
- ✅ Gemini 기반 "AI & RAG" 페이지는 발표 소개만 있고 코드 없음 (Gemini 스트리밍, 벡터 DB RAG, Flutter/Serverpod 문서와 대화하는 샘플 앱)
- ✅ 가장 가까운 코드 튜토리얼은 "magic_recipe": `dartantic_ai` 패키지, `GoogleProvider`, 키는 `session.passwords['geminiApiKey']`, 모델 `gemini-3.5-flash-lite`(존재 여부 미확인 ⚠️), `String` 반환(스트림 아님)
- ✅ 모델 YAML

```yaml
class: DocChunk
table: doc_chunk
fields:
  documentId: UuidValue   # 또는 int
  content: String
  embedding: Vector(768)
indexes:
  chunk_emb_idx:
    fields: embedding
    type: hnsw
    distanceFunction: cosine
```
- ⚠️ `efConstruction` vs `ef_construction` 표기가 버전마다 다름 → 설치본 기준으로 확인
- ⚠️ 유사도 쿼리: `DocChunk.db.find(session, orderBy: (t) => t.embedding.distanceCosine(qVec), limit: 5)` 형태 (메서드명 확인 필요)
- ✅ 스트리밍 엔드포인트 형태

```dart
Stream<String> ask(Session s, String q) async* {
  // q 임베딩 → top-k 청크 검색 → LLM 답변 스트리밍
  await for (final chunk in agent.sendStream(prompt)) { yield chunk.output; }
}
```
> `agent.sendStream`은 `dartantic_ai` API 추정 ⚠️

## 3. 인증
```dart
pod.initializeAuthServices(
  tokenManagerBuilders: [JwtConfigFromPasswords()],
  identityProviderBuilders: [EmailIdpConfigFromPasswords(), GoogleIdpConfigFromPasswords()],
);
```
- ✅ 엔드포인트: `EmailIdpBaseEndpoint`, Google 기본 엔드포인트, `core.RefreshJwtTokensEndpoint`를 상속
- ✅ passwords: `jwtRefreshTokenHashPepper`, `jwtHmacSha512PrivateKey`, `emailSecretHashPepper`, `googleClientSecret`
- ✅ 패키지: `serverpod_auth_idp_server` / `_client` / `_flutter` (4.0.0)
- ✅ Flutter: `FlutterAuthSessionManager`, `await client.auth.initialize()`, `SignInWidget(client: client)`. `onAuthenticated`에서 화면 이동하지 말고 `authInfoListenable` 구독
- ✅ Web Google 로그인: `web/auth.html` + Google Cloud Console 리디렉트 URI
- ✅ **사용자 ID 타입은 `UuidValue`**: `(await session.authenticated)?.authUserId`

## 4. Serverpod Cloud
- ✅ 명령: `serverpod cloud launch`, `serverpod cloud password set`, `serverpod cloud deploy` (`scloud`는 같은 CLI의 단독 이름)
- ✅ `scloud auth login`(CI용 토큰 가능), `serverpod cloud log`, `serverpod cloud db connection`, `serverpod cloud db user create <name>`, `scloud deployment build-secret`(0.32.0+)
- ✅ 비밀값: `launch`가 `config/passwords.yaml` 항목을 Cloud로 복사 제안. `password set` 후 재배포. 코드에서는 `session.passwords['…']`
- ✅ DB: PostgreSQL 17, TLS, 배포 때마다 마이그레이션 적용
- ⚠️ pgvector: Cloud 문서에 확장 언급 없음. 벡터 컬럼이 있는 첫 마이그레이션이 확장을 자동 활성화(호스트가 지원하면) → **더미 배포로 확인**. 폴백: `List<double>`/`ByteData` 저장 + Dart 코사인 계산 (개인 규모면 충분)
- ✅ 스토리지: `server.dart`에서 `ServerpodCloudProvider.private/public(fallback: () => DatabaseCloudStorage(...))` 등록, `session.storage.temporaryDownloadUrl`. 파일당 크기 제한은 문서에 없음
- 가장 단순한 PDF 경로: 바이트(`ByteData`)를 엔드포인트로 보내 서버에서 텍스트 추출, 원본 보관이 필요 없으면 스토리지 생략

## 5. 주의점
- ✅ 스트리밍은 WebSocket → Web·Android 모두 동작. 소켓 끊김·권한 회수 시 종료, `MethodStreamException` 하위 타입. 짧은 유휴 타임아웃 프록시 뒤에서는 `SERVERPOD_WEBSOCKET_PING_INTERVAL`(기본 30초)을 줄임
- ⚠️ Web CORS: 조사 안 함, 배포 후 웹 빌드로 조기 확인
- ⚠️ 업로드 크기 제한 문서 없음 → PDF를 작게
- ⚠️ Cloud의 Future Calls·podlet: 다룬 문서 없음 → 의존하지 말 것. 무거운 PDF 작업은 요청 안에서 처리하거나 await하지 않는 `Future`(재배포 시 끊길 수 있음)
- ✅ 핫 리로드는 클라이언트를 다시 만들지 않음 → 엔드포인트 변경 후엔 핫 리스타트

## 출처
- https://docs.serverpod.dev/next/concepts/cli/introduction
- https://docs.serverpod.dev/next/upgrading/upgrade-to-four.md
- https://docs.serverpod.dev/get-started/creating-endpoints.md
- https://docs.serverpod.dev/next/concepts/data-and-the-database/database/vector-and-geography-fields.md
- https://docs.serverpod.dev/upgrading/upgrade-to-pgvector.md
- https://docs.serverpod.dev/next/concepts/data-and-the-database/database/indexing.md
- https://docs.serverpod.dev/concepts/endpoints-and-apis/streaming.md
- https://docs.serverpod.dev/concepts/authentication/setup.md
- https://docs.serverpod.dev/concepts/authentication/basics.md
- https://docs.serverpod.dev/cloud/concepts/database.md
- https://docs.serverpod.dev/cloud/concepts/storage.md
