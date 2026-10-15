# Run locally

[← Back to the project README](../../README.md)

**Last updated (KST):** 2026-10-15 08:58

Requirements: Flutter **3.47.7** (via [fvm](https://fvm.app)), Serverpod CLI 4.0.4. No Docker needed; `serverpod start` uses an embedded Postgres (pgvector available, checked in [devlog 002](../devlog/002-env-setup-and-g1.md)).

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
