#!/usr/bin/env bash
# Smoke test for the aura-api image (server/aura-api/Dockerfile): starts it twice, as the API (default command) and
# as the worker (node dist/worker.js), against the stack described by the current environment — DATABASE_URL,
# REDIS_URL, SUPABASE_URL, AURA_MASTER_KEY, SUPABASE_SERVICE_ROLE_KEY (e.g. from .github/scripts/e2e-env.sh) —
# then checks that both /health endpoints answer 200, that Docker's HEALTHCHECK reports healthy, and that both
# processes exit on SIGTERM instead of being killed.
#
#   .github/scripts/smoke-api-image.sh aura-api:ci
#   SMOKE_API_PORT=3410 SMOKE_WORKER_PORT=3411 .github/scripts/smoke-api-image.sh aura-api:local   # dev ports busy
set -euo pipefail
image="${1:?usage: $0 <image>}"
api_port="${SMOKE_API_PORT:-3310}"
worker_port="${SMOKE_WORKER_PORT:-3311}"
: "${DATABASE_URL:?}" "${REDIS_URL:?}" "${SUPABASE_URL:?}" "${AURA_MASTER_KEY:?}"
containers=(aura-smoke-api aura-smoke-worker)

# Linux (CI): share the host network, so the 127.0.0.1 URLs work unchanged. Docker Desktop: publish the port and
# reach the host's services through host.docker.internal.
on_linux() { [ "$(uname -s)" = Linux ]; }
rewrite() {
  if on_linux; then printf '%s' "$1"; else
    printf '%s' "$1" | sed -E 's#//([^@/]*@)?(127\.0\.0\.1|localhost)([:/]|$)#//\1host.docker.internal\3#'
  fi
}

run() { # name, port to publish, command...
  local name=$1 port=$2
  shift 2
  local net=(--network host)
  on_linux || net=(--add-host host.docker.internal:host-gateway -p "127.0.0.1:$port:$port")
  docker run -d --name "$name" "${net[@]}" \
    -e PORT="$api_port" -e WORKER_HEALTH_PORT="$worker_port" \
    -e DATABASE_URL="$(rewrite "$DATABASE_URL")" -e REDIS_URL="$(rewrite "$REDIS_URL")" \
    -e SUPABASE_URL="$(rewrite "$SUPABASE_URL")" -e AURA_MASTER_KEY \
    -e SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}" \
    "$image" "$@" >/dev/null
}

cleanup() {
  for c in "${containers[@]}"; do
    echo "--- $c logs (tail)"
    docker logs --tail 20 "$c" 2>&1 || true
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT
docker rm -f "${containers[@]}" >/dev/null 2>&1 || true

run aura-smoke-api "$api_port"
run aura-smoke-worker "$worker_port" node dist/worker.js

wait_http() { # url
  local body
  for _ in $(seq 1 60); do
    if body="$(curl -fsS --max-time 3 "$1" 2>/dev/null)"; then
      echo "$1 → $body"
      return 0
    fi
    sleep 2
  done
  echo "::error::$1 did not answer 200 within 120 s"
  return 1
}
wait_http "http://127.0.0.1:$api_port/health"
wait_http "http://127.0.0.1:$worker_port/health"

for c in "${containers[@]}"; do
  status=starting
  for _ in $(seq 1 45); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$c")"
    [ "$status" = healthy ] && break
    sleep 2
  done
  echo "$c: HEALTHCHECK $status"
  [ "$status" = healthy ] || { echo "::error::$c HEALTHCHECK is $status"; exit 1; }
done

# SIGTERM must end each process (graceful shutdown) before Docker's 10 s timeout turns into SIGKILL (exit 137).
for c in "${containers[@]}"; do
  start=$(date +%s)
  docker stop -t 10 "$c" >/dev/null
  code="$(docker inspect -f '{{.State.ExitCode}}' "$c")"
  echo "$c: stopped in $(( $(date +%s) - start )) s, exit code $code"
  [ "$code" != 137 ] || { echo "::error::$c ignored SIGTERM and was killed"; exit 1; }
done
echo "Image smoke test passed."
