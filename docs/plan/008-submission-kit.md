# 📦 해커톤 제출 키트 (Submission Kit)

> **작성일**: 2026-10-15 01:41 KST · **최종 수정**: 2026-10-15 01:41 KST
> **관련 문서**: [README](../../README.md) · [plan 006 데모 대본](006-demo-script.md) · [research 004 마감 시각](../research/004-hackathon-deadline.md) · [ADR 003](../adr/003-pdf-extract-on-client.md) · [ADR 010](../adr/010-acl-in-query.md) · [ADR 014](../adr/014-model-catalog-and-rotation.md) · [ADR 015](../adr/015-product-scope-notes-and-pdfs.md) · [devlog 007](../devlog/007-cloud-deploy-and-model-rotation.md) · [devlog 008](../devlog/008-notes-feature.md) · [devlog 009](../devlog/009-indexing-failure-handling.md) · [plan 007](007-landing-sign-in.md)
> **표기**: ✅ 코드·문서로 확인 · ⚠️ 미확인/제출 전 점검 필요
> **언어**: 문서 틀은 한국어, **복사해서 붙여넣는 텍스트(§2~§6)는 영어** (해외 심사위원용). 영어 텍스트에는 ✅/⚠️를 넣지 않았고, 근거는 §8 표에 따로 둡니다.

BuilderBase 제출 양식과 소셜 포스트(보너스)에 **그대로 붙여넣는 텍스트 모음**입니다. 주장은 [README](../../README.md)의 "Implemented now"와 **리드 세션이 전달한 최신 사실(2026-10-15 약 01:45 KST)** 에 있는 기능만 사용했고, Cloak은 "coming soon"(계획)으로만 적었습니다. 두 출처가 충돌하면 리드 전달값을 따랐습니다 (README 갱신 필요, §7).

> **표현 규칙(사용자 피드백)**: 제목·태그라인에서 "Blink"를 **동사로 쓰지 않습니다**. 제품명 PageBlink는 그대로 씁니다. 기존 "Blink to the source" 문구는 README·[plan 006](006-demo-script.md)에 남아 있으므로 §7에서 갱신 항목으로 둡니다.

## 1. 제출물 한눈에

| 항목 | 값 | 상태 |
|---|---|---|
| 행사 | Build Something Real: The Serverpod Hackathon (제출처: BuilderBase) | ✅ |
| 마감 | 2026-10-14 21:59 UTC = **10/15 06:59 KST** ([research 004](../research/004-hackathon-deadline.md)) | ✅ |
| 필수 | 동작하는 Flutter + Serverpod 앱 · 2분 이내 데모 영상 · 프로젝트 설명 · 코드 저장소 링크 | ✅ (오케스트레이터 전달) |
| 보너스 | Serverpod를 태그한 소셜 포스트 (LinkedIn "Serverpod" · X @ServerpodDev · BlueSky @serverpod.dev) | ✅ (오케스트레이터 전달) |
| 웹 앱 | https://pageblink.serverpod.space | ✅ Serverpod Cloud 배포, Cloud DB의 pgvector 확인 (리드 전달) · HTTP 200 ([devlog 007](../devlog/007-cloud-deploy-and-model-rotation.md)). ⚠️ 이후 재배포 결과는 확인 필요 |
| API | https://pageblink.api.serverpod.space | ✅ HTTP 200 (같은 기록) |
| 저장소 | https://github.com/biyott/pageblink | ✅ **public** (리드 전달, 2026-10-15 약 01:45 KST). ⚠️ 비로그인 상태에서 열리는지 제출 전 확인 |
| 데모 영상 | `<VIDEO_URL>` (자리표시자) | ⚠️ 업로드 후 교체 |

> 아래 텍스트의 `<VIDEO_URL>`은 실제 링크로 **모두 교체**한 뒤 붙여넣으세요 (§7 체크리스트).

## 2. 프로젝트 이름 · 태그라인

```text
PageBlink
```

```text
Ask your notes. Every answer shows its source.
```

대체 후보 (필드 글자 수에 맞춰 선택):

```text
Ask your notes & documents. Tap ⚡ to open the page it came from.
```

## 3. 짧은 설명 (요약 필드용, 약 50단어)

```text
PageBlink is a Keep-style Markdown notes app that also takes PDFs. Ask a question across all your notes and documents, and the answer streams in with numbered citations. Tap a ⚡ citation to open the exact PDF page or note it came from. Built with Flutter and Serverpod 4, live on Serverpod Cloud.
```

## 4. 전체 프로젝트 설명 (Markdown, 약 420단어)

문제 → 기능 → 구현(Serverpod 중심) → 다음 단계(솔직한 한계) 순서입니다.

````markdown
## The problem

Notes live in one app, PDFs in another, and AI answers rarely come with a source you can check in one tap.

## What PageBlink does

PageBlink is a Google Keep–style notes app with Markdown, where you can also upload PDFs. Notes and PDFs sit on one board and are indexed together. Ask a question in plain language and the answer streams in token by token with `[n]` citations. Tap a ⚡ citation and the app opens the source: the exact PDF page with the quoted passage, or the cited note with the quote shown on top. On mobile, a citation bottom sheet shows "Source n of m". You can also create projects, invite teammates by email, and share documents with them. The UI is English by default and switches to Korean when your locale is Korean, with a language picker in Settings.

## How it's built

**Serverpod 4 does the heavy lifting:**
- **ORM + pgvector:** chunks are stored as `Vector(768)` columns with an HNSW cosine index, queried through the Serverpod ORM.
- **Streaming endpoint:** `ask()` returns a `Stream<AnswerEvent>`, carrying tokens, citations, and the answering model on one channel.
- **Auth:** `serverpod_auth_idp` email sign-in with JWT.
- **Access control inside the vector query:** the owner/project-membership filter is part of the same query as the similarity ordering, and client-sent project ids are intersected with real memberships.
- **Private cloud storage:** original PDFs are stored privately and opened through short-lived signed URLs after an ACL check, so citations open the page on any device.
- **Model catalog + rotation:** a model endpoint serves a 7-model catalog (5 free, 2 paid via OpenRouter). The app has a model picker, and if a model fails before streaming starts, the server rotates to the next one.
- **Indexing-failure handling:** reason codes, Re-index and Re-index all, and a keyword-search fallback when embeddings are unavailable.
- **Deployed on Serverpod Cloud**, with the Flutter web app served by the Serverpod server.

**Flutter:** `pdfrx` extracts text per page on the device, so only text and a content hash go to the server. A "Glass Paper" design adapts to phone, tablet, and desktop, with a 3-pane desktop layout and a persistent Ask panel.

All LLM and embedding calls go through the server, so API keys never reach the app.

## What's next

Honest limits: notes are single-user with save-on-back, and there is no realtime sync yet. Citations are not highlighted inside the page body yet. Still planned: Cloak, a device-only offline privacy tier (shown as "coming soon"), Notion-like realtime collaborative editing over Serverpod streams, a direct Gemini provider, and inline citation highlighting.
````

## 5. 기술 스택 (영문, 복사용)

```markdown
- Flutter 3.47.7 (pinned with fvm), Dart
- Serverpod 4.0.4 (server, generated client, Flutter app; all serverpod packages on the same version)
- Serverpod ORM + migrations, Postgres with pgvector (Vector(768), HNSW, cosine distance)
- Streaming endpoint (Stream<AnswerEvent>) for token and citation events
- serverpod_auth_idp (email sign-in, JWT)
- Serverpod private cloud storage with signed URLs for original PDFs
- Serverpod Cloud (deployment, secrets) and the Serverpod web server serving the Flutter web app
- pdfrx (on-device per-page PDF text extraction and viewer), gpt_markdown (note preview)
- i18n: English by default, Korean by locale, with a language picker in Settings
- Embeddings: EmbeddingGemma-300m (768-d) via DeepInfra, optional Gemini embeddings when a key is configured
- LLMs: OpenRouter (7-model catalog: 5 free, 2 paid), automatic rotation before streaming starts
- Built with Claude Code agents
```

## 6. 소셜 포스트 (보너스)

### 6-1. LinkedIn (약 107단어)

```text
I just finished my entry for Build Something Real: The Serverpod Hackathon.

PageBlink is a Keep-style Markdown notes app that also takes PDFs. Ask a question across all your notes and documents, watch the answer stream in with citations, and tap a ⚡ to open the exact PDF page or note it came from.

Built with Flutter and Serverpod 4: ORM with pgvector, a streaming Stream<AnswerEvent> endpoint, email auth, private cloud storage, and access control inside the vector query. It is live on Serverpod Cloud.

Demo (under 2 min): <VIDEO_URL>
Try it: https://pageblink.serverpod.space

Thank you @Serverpod for Serverpod 4 and Serverpod Cloud!

#Serverpod #Flutter #Dart #hackathon #RAG
```

- ⚠️ LinkedIn에서는 `@Serverpod`를 입력한 뒤 **드롭다운에서 Serverpod 회사 페이지를 선택**해야 실제 멘션(태그)이 됩니다. 텍스트만 붙여넣으면 태그가 되지 않습니다.
- `<VIDEO_URL>`을 실제 영상 링크로 교체합니다.

### 6-2. X (≤280자)

```text
PageBlink for the @ServerpodDev hackathon: ask your notes & PDFs, get streamed answers with citations, tap ⚡ to open the exact source. Flutter + Serverpod 4 + pgvector, live on Serverpod Cloud.
Demo: <VIDEO_URL>
pageblink.serverpod.space
#Serverpod
```

### 6-3. Bluesky (≤280자, 핸들만 다름)

```text
PageBlink for the @serverpod.dev hackathon: ask your notes & PDFs, get streamed answers with citations, tap ⚡ to open the exact source. Flutter + Serverpod 4 + pgvector, live on Serverpod Cloud.
Demo: <VIDEO_URL>
pageblink.serverpod.space
#Serverpod
```

- ✅ 글자 수를 셸로 확인했습니다. 템플릿 248자(X) · 249자(Bluesky). `<VIDEO_URL>`을 YouTube 단축 링크(`https://youtu.be/` + 11자)로 바꿔도 265~266자이고, X의 가중치(URL 23자 · ⚡ 2자)로 세면 261~262자입니다.
- ⚠️ 실제 영상 링크가 이보다 길면 다시 세세요. 게시 전에 각 플랫폼의 글자 수 표시를 최종 확인합니다.
- ⚠️ 각 플랫폼에서 핸들이 자동완성 목록에서 실제 계정으로 연결되는지 확인합니다.

## 7. 제출 체크리스트

마감: **10/15 06:59 KST** ✅ ([research 004](../research/004-hackathon-deadline.md)).

### 영상 · 저장소

- [ ] 데모 영상(2분 이내) 업로드, 비로그인 상태에서 재생되는지 확인 (촬영 절차: [plan 006](006-demo-script.md))
- [ ] 영상 링크를 이 문서의 `<VIDEO_URL>`에 모두 반영 (§4 영문 설명에는 없음, §6 포스트 3곳)
- [ ] 저장소 https://github.com/biyott/pageblink 가 **public** 이고 비로그인 상태에서 열리는지 확인 ✅ public (리드 전달)
- [ ] 루트 [README](../../README.md) `Live demo` 표의 **Demo video** 행에 링크 추가 (현재 "link to be added")
- [ ] ⚠️ 루트 README·[plan 006](006-demo-script.md)의 낡은 내용 갱신 (이 문서 작업에서는 수정하지 않음): 저장소 URL(`biyott/serverpod-hack-2026` → `biyott/pageblink`), "Blink to the source" 태그라인, "UI strings are in Korean", "notes feature deploy 결과 확인 필요"
- [ ] ✅ UI 언어: 영어 기본, 로케일이 ko면 한국어, 설정에서 System/English/한국어 선택 (리드 전달). README의 "UI strings are in Korean"은 낡은 문구. 영문 설명은 이 최신 사실을 따름

### 라이브 서비스 사전 점검

- [ ] 두 URL이 제출 시점에 응답하는지 확인 (마지막 기록: HTTP 200)
- [ ] ⚠️ Cloud E2E 한 번: 가입 → 노트 저장 → PDF 업로드(웹 스토리지 CORS 미확인, 영문 텍스트에는 넣지 않음) → 질문 → ⚡ 열기 (README·devlog 007/008에 기록 없음)
- [ ] ⚠️ DeepInfra 잔액 확인: 잔액 0이면 임베딩이 402로 실패해 업로드·노트 인덱싱이 안 됨 (README "Known issue during judging"). [devlog 009](../devlog/009-indexing-failure-handling.md)에 충전 기록이 있으나 재배포 결과는 확인 필요
- [ ] 공개 문서로만 시연 (무료 모델이 프롬프트를 기록할 수 있음, [ADR 014](../adr/014-model-catalog-and-rotation.md))

### BuilderBase 양식

| 필드 | 넣을 내용 | 상태 |
|---|---|---|
| 프로젝트 이름 | §2 `PageBlink` | ✅ |
| 태그라인/요약 | §2 태그라인 또는 §3 짧은 설명 | ⚠️ 실제 필드 이름·글자 수 제한 확인 필요 |
| 상세 설명 | §4 (Markdown 지원 여부 확인 필요, 미지원이면 서식 기호 제거) | ⚠️ 확인 필요 |
| 기술 스택/태그 | §5 | ⚠️ 확인 필요 |
| 데모 영상 링크 | 업로드한 영상 URL | ⚠️ 업로드 후 |
| 저장소 링크 | https://github.com/biyott/pageblink | ✅ public (리드 전달) |
| 라이브 URL | https://pageblink.serverpod.space | ✅ |
| 필수 여부 · 추가 필드 | – | ⚠️ 확인 필요 (양식 화면에서 직접 확인) |

### 소셜 포스트 (보너스)

- [ ] LinkedIn 게시 (Serverpod 회사 페이지 멘션 확인)
- [ ] X 게시 (@ServerpodDev)
- [ ] Bluesky 게시 (@serverpod.dev)
- [ ] ⚠️ 보너스 인정 방식(포스트 링크를 양식에 붙이는지 등)은 확인 필요

### 제출 후

- [ ] [devlog](../devlog/README.md)에 새 번호로 기록 (영상 링크, 제출 시각 KST)

## 8. 영문 주장 ↔ 근거 (사실 확인 표)

영문 텍스트의 주장이 어디서 왔는지 정리한 표입니다. 영문 텍스트에 넣지 않은 ✅/⚠️는 여기서 관리합니다.

| 영문 텍스트의 주장 | 근거 | 상태 |
|---|---|---|
| 노트(마크다운) + PDF를 함께 질문, `[n]` 인용 스트리밍 | README "Implemented now", [ADR 015](../adr/015-product-scope-notes-and-pdfs.md) | ✅ |
| ⚡ 탭 → PDF 해당 페이지(인용 구절 표시) / 노트(상단에 인용 구절) | README, [devlog 008](../devlog/008-notes-feature.md) | ✅ 코드 기준, ⚠️ Cloud E2E 확인 필요 |
| `Vector(768)` + HNSW(cosine) + ORM | README "How we used Serverpod" | ✅ 로컬 검증, Cloud 마이그레이션 적용 로그 ([devlog 007](../devlog/007-cloud-deploy-and-model-rotation.md)) |
| `Stream<AnswerEvent>` 엔드포인트 (토큰·인용·답한 모델) | README | ✅ |
| `serverpod_auth_idp` 이메일 + JWT | README | ✅ |
| 검색 쿼리 안 ACL, 클라이언트 projectId는 실제 멤버십과 교집합 | README, [ADR 010](../adr/010-acl-in-query.md) | ✅ |
| 비공개 스토리지 + 단기 서명 URL(ACL 확인 후) | README, [devlog 008](../devlog/008-notes-feature.md) | ✅ 구현, ⚠️ 웹 업로드 CORS 미확인 |
| 7개 카탈로그(무료 5·유료 2), 스트리밍 전 오류 시 다음 모델로 | README, [ADR 014](../adr/014-model-catalog-and-rotation.md) | ✅ 단위 테스트 기준, ⚠️ 실제 429 상황 확인 필요 |
| Serverpod Cloud 배포, 서버가 Flutter 웹 앱 서빙 | README | ✅ |
| `pdfrx` 페이지별 온디바이스 추출, 텍스트 + 해시만 전송 | README, [ADR 003](../adr/003-pdf-extract-on-client.md) | ✅ |
| "Glass Paper" 디자인, 폰·태블릿·데스크톱 반응형, 3-pane 데스크톱 + 상시 Ask 패널 | 리드 전달 (git 로그 `f177be5`·`af03088`) | ⚠️ README 기능 표에는 없음 |
| 영어 기본 · ko 로케일 자동 한국어 · 설정 언어 선택, 첫 화면은 랜딩 + 로그인 | 리드 전달 (커밋 `7882ac1`, [plan 007](007-landing-sign-in.md)) | ⚠️ README에는 "UI는 한국어"로 남아 있음 (낡은 문구) |
| 모바일 인용 바텀시트 ("Source n of m") | 리드 전달 | ⚠️ README에 없음, 코드 확인 필요 |
| 노트 + PDF 한 보드, 함께 인덱싱 · 질문 | README, [ADR 015](../adr/015-product-scope-notes-and-pdfs.md) | ✅ |
| 인덱싱 실패 처리: 원인 코드, Re-index / Re-index all, 임베딩 불가 시 키워드 검색 폴백 | 리드 전달, [devlog 009](../devlog/009-indexing-failure-handling.md) | ⚠️ README에 없음, Cloud 배포 결과 확인 필요 |
| 앱 내 모델 선택기, 기본 `google/gemma-4-26b-a4b-it:free` | README, [ADR 014](../adr/014-model-catalog-and-rotation.md) | ✅ |
| 선택적 Gemini 임베딩(키가 설정된 경우) | 리드 전달, [devlog 009](../devlog/009-indexing-failure-handling.md) 제목 | ⚠️ 영문 설명 본문에는 넣지 않고 기술 스택에만 표기 |
| 프로젝트 생성 · 이메일 초대 · 팀 공유 | README | ✅ |
| 한계: 단일 사용자 저장 방식, 실시간 동기화 없음, 본문 안 하이라이트 없음, Cloak "coming soon" | README "Known limits", 리드 전달 | ✅ |
| 다음 단계: Cloak(기기 전용·오프라인), 실시간 협업 편집(Serverpod 스트림), 직접 Gemini 공급자, 본문 안 인용 하이라이트 | README "Planned", 리드 전달, [plan 005](005-follow-up-spec.md) | ✅ 계획일 뿐 (구현 아님) |
| LLM·임베딩 호출은 서버 경유, 키는 앱에 없음 | README "Flow of one question", AGENTS.md | ✅ |
| 글자·단어 수 | 셸 `wc`로 측정: 짧은 설명 53단어, 전체 설명 약 424단어(마크다운 기호 제외, 기호 포함 `wc -w`는 436), LinkedIn 107단어 | ✅ |

> 영문 텍스트에는 지연 시간·정확도 같은 수치를 넣지 않았습니다 (측정 기록 없음). 넣은 숫자는 README에 있는 768차원·카탈로그 7개(무료 5·유료 2)와 2분 영상 길이뿐입니다.

## 9. 변경 이력

- `2026-10-15 01:41` 최초 작성 (사실은 README·ADR 003/010/014/015·devlog 007/008·plan 006 기준. BuilderBase 필드 이름은 확인 필요)
- `2026-10-15 01:41` 리드 전달 최신 사실 반영: 저장소 URL(`biyott/pageblink`, public), 태그라인에서 동사 "Blink" 제거, 추가 구현 항목(i18n·랜딩·Glass Paper·인용 바텀시트·인덱싱 실패 처리·모델 선택기) 반영, 영문 텍스트 재작성 및 글자·단어 수 재측정
