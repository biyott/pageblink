# Run locally

[← Back to the project README](../../README.md)

**Last updated (KST):** 2026-10-15 14:54

Requirements: Flutter **3.47.7** (via [fvm](https://fvm.app)), Serverpod CLI 4.0.4. No Docker needed; `serverpod start` uses an embedded Postgres (pgvector available, checked in [devlog 002](../devlog/002-env-setup-and-g1.md)).

```bash
fvm use 3.47.7
dart install serverpod_cli
```

**Create `passwords.yaml` first (required)** — `app/pageblink_server/config/passwords.yaml` is git-ignored, so a fresh clone does not have it. Without it, `serverpod start` exits immediately, even with the embedded database (✅ reproduced):

```text
Missing password for "database". Please check your config/passwords.yaml file or the SERVERPOD_PASSWORD_database environment variable.
```

A file with this structure started the server successfully (✅); replace each `<random string>` with your own random value:

```yaml
shared:
  jwtRefreshTokenHashPepper: '<random string>'
  jwtHmacSha512PrivateKey: '<random string>'
  emailSecretHashPepper: '<random string>'
development:
  database: '<random string>'
  serviceSecret: '<random string>'
```

Example generator (✅ values made this way started the server): `openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-48`

Only a missing `database` was individually confirmed to stop startup (✅). The other four keys are required by the server code, which uses `JwtConfigFromPasswords()`; each was not tested one by one (⚠️).

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
