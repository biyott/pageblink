# Features and limits

[← Back to the project README](../../README.md)

**Last updated (KST):** 2026-10-15 08:58

## Implemented features

Each note or document can live in a different privacy tier: **Cloak** (device-only, planned) → **Cloud** (your private cloud documents) → **Shared Vision** (documents shared with a project team, with access control enforced inside the vector query).

| Feature | How it works |
|---|---|
| Landing + sign-in first page | The first screen is a landing page with the sign-in card; email sign-in uses `serverpod_auth_idp` (email provider, JWT tokens) ([plan 007](../plan/007-landing-sign-in.md)) |
| Keep-style Markdown notes + PDFs on one board | Grid of note cards and PDF cards. Note editor with title, Markdown body, toolbar (heading / bold / italic / list / checkbox / quote / code), preview toggle (`gpt_markdown`), saves when you go back. Server: `document.saveNote` / `document.get` with ACL ([ADR 015](../adr/015-product-scope-notes-and-pdfs.md)) |
| Notes and PDFs are both indexed and askable | On every save the server re-chunks and re-embeds the note (a note is "page 1"); PDFs are indexed per page. One question searches both together |
| PDF upload with on-device text extraction | `pdfrx` extracts text **per page** in the Flutter app; only text and a SHA-256 content hash are sent ([ADR 003](../adr/003-pdf-extract-on-client.md)) |
| Indexing | Server chunks pages, embeds with **EmbeddingGemma-300m** (768-d, via DeepInfra; optional Gemini embeddings when a key is configured), stores in Postgres with **pgvector** (HNSW, cosine) through the Serverpod ORM |
| Streaming answers with ⚡ citations + SOURCES chips | `Stream<AnswerEvent>` endpoint: top-8 chunks by cosine distance over notes and PDFs together → LLM → tokens + `[n]` markers → `citation` events (each carries `kind`: `note` or `pdf`). The app renders `[n]` as ⚡ chips and lists the sources as SOURCES chips under the answer |
| ⚡ Blink to the source | Every answer shows its source: tapping a ⚡ citation opens the exact PDF page with the quoted passage, or the cited note with the quote shown. On mobile, a citation bottom sheet shows the source ("Source n of m") |
| Original PDFs in Serverpod cloud storage | PDFs are stored in private cloud storage. The viewer uses the local copy if present, otherwise the server copy via a short-lived signed URL after an ACL check, so a citation opens the page on any device and for teammates. |
| Projects + invites with ACL inside the vector query | Create a project, invite a registered user by email (owner only; the UI invites as editor). Roles owner / editor / viewer. The `WHERE` on owner / project membership is part of the same query as the similarity ordering; client-sent project ids are intersected with real memberships ([ADR 010](../adr/010-acl-in-query.md)) |
| Model picker + automatic rotation | Backend serves a 7-model catalog (5 free, 2 paid via OpenRouter). On 402/404/408/429/5xx **before any text streams**, the server rotates to the next model; the app shows which model answered ([ADR 014](../adr/014-model-catalog-and-rotation.md)) |
| Indexing-failure handling | Failures carry reason codes; per-document **Re-index** and **Re-index all**; when query embedding is unavailable, `ask` falls back to keyword search and says so in the answer ([devlog 009](../devlog/009-indexing-failure-handling.md)) |
| AB "Glass Paper" responsive design | Warm gradient, glass shell, pastel note cards. Phone: bottom navigation; tablet: navigation rail; desktop: 3-pane layout with a persistent Ask panel |
| i18n (EN / KO) | English by default; Korean automatically when the browser/device locale is `ko`; Settings language picker (System / English / 한국어) |

## Known limits

- **Embeddings need a funded DeepInfra account.** If the balance runs out (HTTP 402), new uploads and note saves fail to index and Ask falls back to keyword search over the chunks that are already indexed, and tells you so ([devlog 009](../devlog/009-indexing-failure-handling.md)). The per-document **Re-index** button recovers failed documents once the balance is topped up. The keyword fallback is implemented, but it has no recorded end-to-end run on the cloud deployment.
- **OpenRouter free quota is per account** (50/day, 1,000/day after buying ≥ $10 credits; 20/min), so model rotation helps with congestion, not with the daily cap.
- **Default answer models are OpenRouter free models, which may log prompts** ([ADR 014](../adr/014-model-catalog-and-rotation.md)). Use public documents for the demo.
- **Verification status.** Both live URLs returned HTTP 200 after the redeploy recorded in [devlog 007](../devlog/007-cloud-deploy-and-model-rotation.md). The latest deploy (notes, landing page, Glass Paper design, i18n, indexing-failure handling) has no recorded end-to-end run on the cloud deployment yet (sign-up → note/PDF upload → ask → citation). The notes UI and the sign-up password rule (12–50 chars, lowercase + number, uppercase or special; client-side only) are not covered by automated tests.
- **Original PDFs and web upload.** PDFs are stored server-side in private cloud storage (`document.pdfUploadDescription` / `confirmPdfUpload` / `pdfUrl`). CORS for the web upload is not verified yet. If the server copy is unavailable (for example a failed upload), the viewer shows the cited quote instead of the page. Citation highlight inside the page body is not implemented yet.
- **Notes are single-user editing with save-on-back.** There is no realtime sync or collaborative editing, no images, no labels/colors/pin/archive, no version history, and checkboxes cannot be toggled in the preview. These are planned ([plan 005](../plan/005-follow-up-spec.md), [ADR 015](../adr/015-product-scope-notes-and-pdfs.md)).
- **The Cloak tier** (device-only, offline) appears in the tier picker as "coming soon" (disabled); it is not implemented.
- **No mobile store builds.** The demo is the Flutter web app on Serverpod Cloud.

## Planned

Cloak device-only offline tier, Notion-like realtime sync and collaborative editing (Serverpod streams), a richer note editor (checklist toggling in preview, images, labels/colors/pin/archive), note version history, Cloak offline Evidence mode (EmbeddingGemma on device + sqlite-vec/FTS5), citation highlight inside the page body, device↔cloud sync (Recall), direct Gemini provider (LLM answers; Gemini embeddings are optional today), mobile store builds, member/role management UI, background indexing with Future Calls, Korean hybrid search, and more. Full spec with acceptance criteria: [docs/plan/005-follow-up-spec.md](../plan/005-follow-up-spec.md).
