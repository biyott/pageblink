# 001 · Serverpod ORM·Cloud와 pgvector

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Serverpod가 pgvector를 지원하나? Serverpod Cloud DB에서 쓸 수 있나? Cloud가 RAG에 필요한 기능을 주나? |
| 결론 한 줄 | ORM은 완전 지원 ✅, **Cloud DB의 pgvector는 문서에 없음 ⚠️ → 배포 테스트로 확인** |
| 반영 | [ADR 005](../adr/005-backend-split.md) · [ADR 008](../adr/008-pgvector-fallback.md) · [plan 002 §4](../plan/002-rag-assistant-plan.md) |

## 핵심 결론

1. 최신 안정판은 **Serverpod 4.0.4** (4.1.0-beta.3은 프리릴리스) ✅
2. `Vector` 필드와 HNSW·IVFFLAT 인덱스는 **2.8.0**부터 지원합니다. 2.9.0에서 `HalfVector`·`SparseVector`·`Bit`가 추가됐고, 4.0.0부터 pgvector와 PostGIS가 포함된 Postgres 바이너리를 함께 배포합니다 ✅
3. **Serverpod Cloud DB 문서에는 확장 모듈 목록이 없습니다 ⚠️**. "PostgreSQL 17, TLS 필수, 커넥션 풀링, 오토스케일"만 명시돼 있습니다
4. Cloud 요금제: **Starter($5)는 Future Calls 비활성화**, Growth($20+사용량)에서 활성화 ✅

## 상세

### ORM 벡터 기능 ✅
- 거리 함수: `distanceL2`, `distanceCosine`, `distanceInnerProduct`, `distanceL1`, 그리고 `Bit` 전용 `distanceHamming`, `distanceJaccard`. `where`와 `orderBy` 모두에서 사용 가능
- HNSW 파라미터: `m`(기본 16), `ef_construction`(기본 64, 2·m 이상). IVFFLAT: `lists`(기본 100). 인덱스 1개당 벡터 필드 1개
- 로컬 주의: SQLite에서는 벡터 쿼리가 동작하지 않습니다. 내장 개발용 Postgres에 pgvector가 있는지는 **문서끼리 엇갈립니다 ⚠️** (한 페이지는 없다, 새 페이지는 0.8.3 포함이라고 함)

```yaml
class: DocChunk
table: doc_chunk
fields:
  content: String
  embedding: Vector(1536)
indexes:
  chunk_emb_idx:
    fields: embedding
    type: hnsw
    distanceFunction: cosine
    parameters: { m: 16, ef_construction: 64 }
```

```dart
final hits = await DocChunk.db.find(session,
  where: (t) => t.embedding.distanceCosine(q) < 0.5,
  orderBy: (t) => t.embedding.distanceCosine(q),
  limit: 10);
```

### Serverpod Cloud 제공 기능 ✅
- 관리형 Postgres(자동 마이그레이션·백업), 프로젝트당 private/public 스토리지 버킷, 커스텀 도메인 + TLS, CLI로 비밀번호·비밀값·환경변수 관리, 로그
- Redis(pub/sub, 글로벌 캐시)는 직접 연결해야 하는 외부 서비스
- 비밀값 3단계: passwords(`getPassword`), secrets(환경변수로 주입), 평문 변수

| 플랜 | 가격 | 내용 |
|---|---|---|
| Starter | $5/월 | small podlet 1개, small DB 1개, $5 사용 크레딧, 버킷 2개, **Future Calls 비활성** |
| Growth | $20/월 + 사용량 | Future Calls, 오토스케일, 커스텀 도메인 1개 |
| Enterprise | $799/월 + 사용량 | |
| 무료 체험 | 첫 프로젝트 1개월 | 신용카드 불필요 |

- Podlet 크기: S(256MB) ~ XXL(4GB). DB 크기: S(1GB) ~ L+ 오토스케일(4~64GB)
- 리전, 요청 타임아웃, 외부 HTTP 제한은 **문서에서 찾지 못함 ⚠️**

### RAG 관련 Serverpod 기능 ✅
- **파일 업로드**: 서버가 `createUploadDescription` → 클라이언트가 `FileUploader`로 스토리지에 직접 업로드 → 서버가 `verifyUpload`. 기본 `maxFileSize` 10MiB. 백엔드: S3·GCP·Cloudflare R2
- **비공개 파일**: `temporaryDownloadUrl`로 기한부 서명 링크. 발급 전에 서버가 권한을 확인해야 함 → 문서별 권한 체크 지점
- **스트리밍**: `Stream<T>`를 반환하는 엔드포인트 메서드가 공유 WebSocket으로 동작. 시작 시 인증 확인, 권한 회수 시 종료. 30초 핑, 유휴 시 `MethodStreamIdleTimeoutException`
- **Future Calls**: DB에 저장, 지연·특정 시각·주기·cron 지원. **드물게 두 번 실행될 수 있어 멱등하게 설계해야 함**. 동시성 기본 1
- **인증** (`serverpod_auth_idp`): Email, Google, Apple, Facebook, GitHub, Microsoft, Firebase, Passkey(실험), Anonymous(실험), 커스텀
- **캐시**: 메모리 `local`·`localPrio`(각 1만 항목), Redis 기반 `global`, `query` 캐시
- **공유·ACL 기능은 내장되어 있지 않음** → `DocumentShare` 같은 테이블로 직접 구현 (설계 패턴, 문서화된 기능 아님 ⚠️)

### 클라이언트 플랫폼
- Google 로그인은 iOS·Android·Web 공식 지원 ✅
- Flutter Web에서 스트리밍 제약은 문서에 없음 ⚠️. `StreamingConnectionHandler`로 자동 재연결 가능

### Cloud에 pgvector가 없을 때의 선택지
- Serverpod는 `SERVERPOD_DATABASE_HOST/_PORT/_NAME/_USER/_REQUIRE_SSL`과 `SERVERPOD_DATABASE_PASSWORD`로 DB 연결을 읽습니다 ✅
- 따라서 Cloud 서버에 외부 Neon/Supabase를 붙이는 것은 원리상 가능하나, **Cloud가 주입하는 DB 변수가 덮어쓰는지 확인되지 않음 ⚠️**

| 순위 | 안 | 특징 |
|---|---|---|
| (a) | Cloud 서버 + 외부 Postgres(pgvector) | DB 하나, 마이그레이션 유지 |
| (b) | Docker 자체 호스팅 (Fly/Render/GCP) + Serverpod pgvector 이미지 ✅ | 운영 부담 증가 |
| (c) | Cloud 관리형 DB + 별도 벡터 스토어 | 가장 복잡, ORM 벡터 쿼리 상실 |

## 미확인 · 리스크
- ⚠️ Cloud DB의 pgvector 확장 → 더미 `Vector` 모델 배포로 확인, 안 되면 Discord 문의
- ⚠️ Cloud가 외부 DB 환경변수를 덮어쓰는지
- ⚠️ 256MB podlet에서 PDF 파싱·임베딩 시 메모리

## 출처
- https://pub.dev/packages/serverpod/changelog
- https://docs.serverpod.dev/concepts/data-and-the-database/database/filtering.md
- https://docs.serverpod.dev/next/concepts/data-and-the-database/database/indexing.md
- https://docs.serverpod.dev/next/concepts/data-and-the-database/database/vector-and-geography-fields.md
- https://docs.serverpod.dev/cloud/concepts/database.md
- https://docs.serverpod.dev/upgrading/archive/upgrade-to-pgvector.md
- https://docs.serverpod.dev/cloud.md
- https://docs.serverpod.dev/cloud/concepts/passwords-secrets-env-vars.md
- https://serverpod.dev/cloud
- https://docs.serverpod.dev/next/deployments/deploy-to-serverpod-cloud.md
- https://docs.serverpod.dev/next/concepts/endpoints-and-apis/file-uploads.md
- https://docs.serverpod.dev/cloud/concepts/storage.md
- https://docs.serverpod.dev/next/concepts/endpoints-and-apis/streaming.md
- https://docs.serverpod.dev/next/concepts/scheduling/overview
- https://docs.serverpod.dev/concepts/lookups/configuration-reference.md
- https://docs.serverpod.dev/next/concepts/authentication/setup.md
- https://docs.serverpod.dev/next/concepts/endpoints-and-apis/caching
- https://docs.serverpod.dev/concepts/authentication/providers/google/setup.md
- https://docs.serverpod.dev/deployments/deployment-strategy
