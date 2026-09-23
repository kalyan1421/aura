#!/usr/bin/env bash
# Prints KEY=VALUE lines: the environment server/aura-api's e2e suite and the image smoke test read, derived from
# the running local Supabase stack (`supabase status -o env`). The keys are the CLI's fixed local demo keys
# (supabase/LOCAL.md), not secrets; AURA_MASTER_KEY is a throwaway random key unless one is already set.
#
#   .github/scripts/e2e-env.sh >> "$GITHUB_ENV"                     # CI
#   set -a; eval "$(.github/scripts/e2e-env.sh)"; set +a            # locally (bash/zsh)
#
# REDIS_URL defaults to the dev/CI port 6391 (infra/docker-compose.yml); the SMTP port is Mailpit's `smtp_port`
# from supabase/config.toml.
set -euo pipefail
cd "$(dirname "$0")/../.."

eval "$(supabase status -o env)"
smtp_port="$(sed -n 's/^smtp_port *= *\([0-9][0-9]*\).*/\1/p' supabase/config.toml)"

cat <<EOF
DATABASE_URL=$DB_URL
SUPABASE_URL=$API_URL
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY
MAILPIT_URL=$MAILPIT_URL
E2E_SMTP_URL=smtp://127.0.0.1:${smtp_port:-55525}
REDIS_URL=${REDIS_URL:-redis://127.0.0.1:6391}
AURA_MASTER_KEY=${AURA_MASTER_KEY:-$(openssl rand -base64 32)}
EOF
