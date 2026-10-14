# ⚡ PageBlink — Ask your notes & documents. Blink to the source.

> 한국어 요약: Google Keep 스타일의 마크다운 노트 앱에 PDF도 올릴 수 있고, 노트와 PDF 전체에 질문하면 인용과 함께 답이 스트리밍됩니다. 인용(⚡)을 탭하면 PDF는 해당 페이지로, 노트는 노트 편집 화면(인용 구절 표시)으로 점멸합니다. Flutter + Serverpod, Serverpod Cloud에 배포됨.

**PageBlink** is a Google Keep–style notes app with Markdown, where you can also upload PDFs, and then ask questions across **both your notes and your PDFs**. Write a quick note in a simple, mobile-friendly Markdown editor or upload a PDF, ask a question in plain language, and the answer streams in token by token with `[n]` citations to the exact sources it used. Tap a ⚡ citation chip and the app **blinks** you to the source: the cited page of the PDF, or the cited note with the quoted passage shown. Notion-like realtime sync and richer editing are planned for later ([ADR 015](docs/adr/015-product-scope-notes-and-pdfs.md)). Each note or document can live in a different privacy tier: **Cloak** (device-only, planned) → **Cloud** (your private cloud documents) → **Shared Vision** (documents shared with a project team, with access control enforced inside the vector query).

Built for **Build Something Real: The Serverpod Hackathon** with Flutter + Serverpod 4.0.4.

## Live demo

| | |
|---|---|
| Web app | https://pageblink.serverpod.space (Serverpod Cloud) |
| API | https://pageblink.api.serverpod.space |
| Demo video | link to be added (확인 필요) |

✅ Both URLs returned HTTP 200 after the redeploy recorded in [devlog 007](docs/devlog/007-cloud-deploy-and-model-rotation.md). ⚠️ The notes feature ([devlog 008](docs/devlog/008-notes-feature.md)) was being deployed to Serverpod Cloud when this was written; the result is 확인 필요. ⚠️ A full end-to-end run on the cloud deployment (sign-up → upload → ask → citation) is not yet recorded in the devlog. Note: the UI strings are in **Korean**.

> Demo tip: the default answer models are OpenRouter **free** models, which may log prompts ([ADR 014](docs/adr/014-model-catalog-and-rotation.md)). Use public documents for the demo.

## Features

### Implemented now

| Feature | How it works |
|---|---|
| Email sign-in | `serverpod_auth_idp` email provider, JWT tokens |
| Markdown notes (Keep-style) | "노트" tab: grid of note cards + PDF cards, "새 노트" extended FAB and a small PDF FAB. Note editor with title, Markdown body, toolbar (heading / bold / italic / list / checkbox / quote / code), preview toggle (`gpt_markdown`), saves when you go back. Server: `document.saveNote` / `document.get` with ACL ([ADR 015](docs/adr/015-product-scope-notes-and-pdfs.md)) |
| Notes are searchable like PDFs | On every save the server re-chunks and re-embeds the note (a note is "page 1"); a citation to a note opens the note editor with the cited quote shown at the top |
| PDF upload with on-device text extraction | `pdfrx` extracts text **per page** in the Flutter app; only text and a SHA-256 content hash are sent ([ADR 003](docs/adr/003-pdf-extract-on-client.md)) |
| Indexing | Server chunks pages, embeds with **EmbeddingGemma-300m** (768-d, via DeepInfra), stores in Postgres with **pgvector** (HNSW, cosine) through the Serverpod ORM |
| Streaming answers with citations (notes + PDFs) | `Stream<AnswerEvent>` endpoint: top-8 chunks by cosine distance over notes and PDFs together → LLM → tokens + `[n]` markers → `citation` events (each carries `kind`: `note` or `pdf`) |
| ⚡ Blink to the page | Citation chip opens the PDF viewer at the cited page with the quoted passage. The viewer uses the local copy if present, otherwise the server copy via a short-lived signed URL after an ACL check, so citations open on any device or for teammates. If the server copy is unavailable it shows the quote only (see limits below) |
| Projects + invites | Create a project, invite a registered user by email (owner only; the UI invites as editor). Roles owner / editor / viewer |
| Server-side ACL inside the vector query | `WHERE` on owner / project membership is part of the same query as the similarity ordering; client-sent project ids are intersected with real memberships ([ADR 010](docs/adr/010-acl-in-query.md)) |
| In-app model picker + automatic rotation | Backend serves a 7-model catalog (5 free, 2 paid via OpenRouter). On 402/404/408/429/5xx **before any text streams**, the server rotates to the next model; the app shows which model answered ([ADR 014](docs/adr/014-model-catalog-and-rotation.md)) |

**Known limits (honest):**
- Notes are single-user editing with save-on-back. There is no realtime sync or collaborative editing, no images, no labels/colors/pin/archive, no version history, and checkboxes cannot be toggled in the preview. Those are planned ([plan 005](docs/plan/005-follow-up-spec.md)).
- ⚠️ The notes UI and the sign-up password rule change (12–50 chars, lowercase + number, uppercase or special; client-side only) are not covered by automated tests or a recorded end-to-end run (확인 필요).
- Original PDFs are stored server-side in private cloud storage (`document.pdfUploadDescription` / `confirmPdfUpload` / `pdfUrl`, commit 4140d4f). The viewer falls back to the server copy through a short-lived signed URL after an ACL check, so citations open on any device and for teammates. ⚠️ CORS for the web upload is still unverified (확인 필요); if the server copy is unavailable (for example a failed upload), the viewer shows the cited quote instead of the page. Citation highlight inside the page body is not implemented yet.
- **Known issue during judging:** embeddings need a funded DeepInfra account (402 when balance is 0), so uploads and note indexing fail until the balance is topped up.
- OpenRouter free quota is per account (50/day, 1,000/day after buying ≥ $10 credits; 20/min), so rotation helps with congestion, not with the daily cap.
- The Cloak tier appears in the tier picker as "coming soon" (disabled).

### Planned

Notion-like realtime sync and collaborative editing (Serverpod streams), a richer note editor (checklist toggling in preview, images, labels/colors/pin/archive), note version history, Cloak device-only tier with offline Evidence mode (EmbeddingGemma on device + sqlite-vec/FTS5), citation highlight inside the page body, device↔cloud sync (Recall), direct Gemini provider, member/role management UI, background indexing with Future Calls, Korean hybrid search, and more. Full spec with acceptance criteria: [docs/plan/005-follow-up-spec.md](docs/plan/005-follow-up-spec.md).

## Architecture

```mermaid
flowchart LR
  subgraph App["Flutter app (web demo)"]
    UI[Ask · Notes & PDFs · Projects]
    ED[Note editor<br/>Markdown + preview]
    PDF[pdfrx<br/>per-page text + viewer]
  end

  subgraph SP["Serverpod 4 (Serverpod Cloud)"]
    EP["Endpoints<br/>document · ask · project · model"]
    AUTH[serverpod_auth_idp<br/>email + JWT]
    DB[(Postgres + pgvector<br/>Vector 768 · HNSW cosine)]
    EP --> DB
    EP --- AUTH
  end

  EMB[DeepInfra<br/>EmbeddingGemma-300m]
  LLM[OpenRouter<br/>free + paid models, rotation]

  UI --> ED
  UI --> PDF
  UI -- "generated client<br/>saveNote / get / upload / list / delete" --> EP
  UI -- "ask(): Stream of AnswerEvent" --> EP
  EP -- "embed chunks / query" --> EMB
  EP -- "prompt with numbered sources" --> LLM
```

Notes and PDFs share one pipeline: a saved note is indexed as a single page (`kind: 'note'`), an uploaded PDF as one chunk set per page (`kind: 'pdf'`); both end up as `DocChunk` rows in the same vector index.

Flow of one question: embed the query → ACL-filtered pgvector search (top 8) → numbered sources into the prompt → stream tokens → emit a `citation` event on the first `[n]` of each source → the app renders `[n]` as ⚡ chips (PDF citation → viewer at the page; note citation → note editor). All LLM and embedding calls go through the Serverpod server; API keys never reach the app.

## How we used Serverpod

| Serverpod feature | Where in PageBlink | Status |
|---|---|---|
| ORM + migrations | `Document` (with `kind` + `body`), `DocChunk`, `Project`, `ProjectMember` models (`*.spy.yaml`), generated migrations | ✅ in use |
| `Vector(768)` + HNSW index (cosine) + `distanceCosine` ordering | `DocChunk.embedding`; search in [`ask_endpoint.dart`](app/pageblink_server/lib/src/rag_endpoints/ask_endpoint.dart) | ✅ in use, verified on local DB and applied by the Cloud migration |
| Streaming endpoint (`Stream<AnswerEvent>`) | `AskEndpoint.ask`: tokens, citations, answering model, errors on one channel | ✅ in use |
| `serverpod_auth_idp` (email) | Sign-in; endpoints use `requireLogin` and the authenticated user id for ACL | ✅ in use |
| Generated protocol + client | `pageblink_client` is generated; the app calls `client.ask.ask(...)`, `client.document.saveNote(...)`, `client.document.upload(...)` | ✅ in use |
| Serverpod Cloud deploy + passwords | Live at `pageblink.serverpod.space`; API keys set as Cloud passwords | ✅ in use |
| Web server serves the Flutter web app | `FlutterRoute` in [`server.dart`](app/pageblink_server/lib/server.dart) | ✅ in use |
| Cloud storage / file upload | Original PDFs go to private cloud storage via upload descriptions; `pdfUrl` returns a short-lived signed URL after an ACL check; deleting a document removes the stored file too | ✅ in use (web upload CORS unverified) |
| Future Calls | Background indexing | ⏳ planned (needs Growth plan; project is on Starter) |

## Run locally

Requirements: Flutter **3.47.7** (via [fvm](https://fvm.app)), Serverpod CLI 4.0.4. No Docker needed; `serverpod start` uses an embedded Postgres (pgvector available, checked in [devlog 002](docs/devlog/002-env-setup-and-g1.md)).

```bash
fvm use 3.47.7
dart install serverpod_cli
```

**API keys** — either environment variables (keys only) or `app/pageblink_server/config/passwords.yaml` (git-ignored; on Serverpod Cloud use `serverpod cloud password set <name> <value>`):

| Setting | Env var fallback | Notes |
|---|---|---|
| `openrouterApiKey` | `OPENROUTER_API_KEY` | LLM via OpenRouter |
| `deepinfraApiKey` | `DEEPINFRA_API_KEY` | Embeddings |
| `anthropicApiKey` | `ANTHROPIC_API_KEY` | Only used if no OpenRouter key (direct Claude) |
| `llmModel` | – | Default model (default: `google/gemma-4-26b-a4b-it:free`) |
| `llmRotation` | – | `free` (default) · `all` (also paid models) · `off` |

```bash
export OPENROUTER_API_KEY=...    # or put the keys in config/passwords.yaml
export DEEPINFRA_API_KEY=...
cd app && serverpod start        # generates code, starts the server and the web app
```

In development, email verification codes for sign-up are printed in the server console; on Serverpod Cloud they are sent through the Cloud email service.

Tests:

```bash
cd app/pageblink_server && dart test
```

13 tests passed at commit `0af55e0`; 11 of them are unit tests (`dart test test/unit`, no database needed). The 2 integration tests (pgvector smoke test, greeting) use the embedded local database.

## Judging criteria map

The criteria below come from participant-reported material, not the official rules ([plan 001 §2](docs/plan/001-hackathon-topic-report.md), marked unverified there).

| Criterion (weight) | Where to look |
|---|---|
| Works (30%) | Live demo above (cloud E2E 확인 필요); ask → streamed answer → ⚡ → page. Server tests: `app/pageblink_server/test/` |
| Serverpod stack usage (25%) | [How we used Serverpod](#how-we-used-serverpod) · [`app/pageblink_server/lib/src/`](app/pageblink_server/lib/src/) (`rag_endpoints/`, `models/`) · [devlog 003](docs/devlog/003-server-rag-pipeline.md) |
| Completeness & technical creativity (25%) | Citation-aware streaming protocol (`AnswerEvent`), ACL inside the vector query ([ADR 010](docs/adr/010-acl-in-query.md)), pre-text model rotation ([`rotating_llm_provider.dart`](app/pageblink_server/lib/src/providers/rotating_llm_provider.dart)), per-document privacy tiers ([ADR 009](docs/adr/009-device-tier-privacy-and-sync.md)) |
| Usefulness (20%) | Personal and team Q&A over notes and PDFs with verifiable citations; roadmap in [plan 005](docs/plan/005-follow-up-spec.md) and market gaps in [research 003](docs/research/003-competitors-and-gaps.md) |

## Built with Claude Code

This project was planned, researched, and built with [Claude Code](https://claude.com/claude-code) agents. The decision trail is in the repo: 16 research notes with sources, 15 ADRs, and a timestamped devlog (all times KST) — see below.

---

## 문서

문서는 종류별 폴더로 나뉩니다 → [📂 문서 레지스트리](docs/README.md)

| 폴더 | 내용 |
|---|---|
| 📐 [docs/plan](docs/plan/README.md) | 기획·설계: [주제 선정](docs/plan/001-hackathon-topic-report.md) · [RAG 비서 기획·아키텍처](docs/plan/002-rag-assistant-plan.md) · [기술 스택 & 준비](docs/plan/003-tech-stack-and-prep.md) · [이름 후보 & 기능 용어집](docs/plan/004-naming-and-feature-vocabulary.md) · [후속 기능 명세](docs/plan/005-follow-up-spec.md) |
| 🔎 [docs/research](docs/research/README.md) | 서브에이전트 조사 결과 16건 (출처 포함) |
| ⚖️ [docs/adr](docs/adr/README.md) | 결정 기록 15건 |
| 🧪 [docs/devlog](docs/devlog/README.md) | 개발 과정 기록 8건 (수행 일시 포함) |

## 개요

| 항목 | 내용 |
| ---- | ---- |
| 행사 | Build Something Real: The Serverpod Hackathon |
| 마감 | 2026-10-14 21:59 UTC (= 10/14 23:59 CEST · **10/15 06:59 KST**) |
| 팀 | 웹 + Flutter 개발자 (1인 또는 소규모 팀) |
| 스택 | Serverpod (Dart 백엔드) + Flutter |

## 참고 링크

- 행사 페이지: https://builderbase.com/event/build-something-real-the-serverpod-hackathon
- Serverpod 문서: https://docs.serverpod.dev/overview
