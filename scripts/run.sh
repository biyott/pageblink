#!/usr/bin/env bash
# Run PageBlink locally. No secrets in this file (see scripts/neon.env.example).
#
#   scripts/run.sh dev              serverpod start (embedded Postgres)
#   scripts/run.sh neon [args...]   server in staging mode against Neon
#                                   e.g. scripts/run.sh neon --apply-migrations
#   scripts/run.sh app              Flutter web app in Chrome (needs a running server)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
neon_env="${PAGEBLINK_NEON_ENV:-$HOME/.config/pageblink/neon.env}"
mode="${1:-}"
[ $# -gt 0 ] && shift

# LLM / embedding keys come from the environment or config/passwords.yaml.
warn_keys() {
  for k in OPENROUTER_API_KEY DEEPINFRA_API_KEY; do
    [ -n "${!k:-}" ] || echo "warn: $k not set (ok if it is in config/passwords.yaml)" >&2
  done
}

case "$mode" in
  dev)
    warn_keys
    cd "$root/app" && exec serverpod start "$@"
    ;;
  neon)
    [ -f "$neon_env" ] || { echo "missing $neon_env (copy scripts/neon.env.example there)" >&2; exit 1; }
    # shellcheck disable=SC1090
    . "$neon_env"
    : "${SERVERPOD_DATABASE_HOST:?set it in $neon_env}"
    warn_keys
    cd "$root/app/pageblink_server" && exec dart bin/main.dart --mode staging "$@"
    ;;
  app)
    cd "$root/app/pageblink_flutter" && exec flutter run -d chrome "$@"
    ;;
  *)
    sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
