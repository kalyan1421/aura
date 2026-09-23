#!/usr/bin/env bash
# Smoke test for the admin console image (apps/admin/Dockerfile): starts it with throwaway configuration (no backend
# needed), then checks that /login renders (200) with next.config.ts's security headers, that / redirects to
# sign-in, that Docker's HEALTHCHECK reports healthy, and that the process exits on SIGTERM.
#
#   .github/scripts/smoke-admin-image.sh aura-admin:ci
#   SMOKE_ADMIN_PORT=3421 .github/scripts/smoke-admin-image.sh aura-admin:local     # when 3320 is taken
set -euo pipefail
image="${1:?usage: $0 <image>}"
port="${SMOKE_ADMIN_PORT:-3320}"
c=aura-smoke-admin

cleanup() {
  echo "--- $c logs (tail)"
  docker logs --tail 20 "$c" 2>&1 || true
  docker rm -f "$c" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker rm -f "$c" >/dev/null 2>&1 || true

# Unreachable backend on purpose: /login must render without calling it.
docker run -d --name "$c" -p "127.0.0.1:$port:3320" \
  -e ADMIN_COOKIE_SECRET="$(openssl rand -base64 48)" \
  -e SUPABASE_ANON_KEY=smoke-test-anon-key \
  -e SUPABASE_URL=http://127.0.0.1:9 \
  -e AURA_API_URL=http://127.0.0.1:9 \
  "$image" >/dev/null

code=000
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/login" || true)"
  [ "$code" = 200 ] && break
  sleep 2
done
echo "/login → $code"
[ "$code" = 200 ] || { echo "::error::/login answered $code"; exit 1; }

headers="$(curl -sI --max-time 3 "http://127.0.0.1:$port/login")"
for h in 'x-frame-options: deny' 'x-robots-tag: noindex, nofollow' 'content-security-policy:'; do
  grep -qi "^$h" <<<"$headers" || { echo "::error::missing header: $h"; exit 1; }
done
[ -z "$(grep -i '^x-powered-by' <<<"$headers" || true)" ] || { echo "::error::x-powered-by is exposed"; exit 1; }
echo "security headers present"

root="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 3 "http://127.0.0.1:$port/")"
echo "/ → $root"
[[ "$root" == 307*"/login"* ]] || { echo "::error::/ should redirect to /login"; exit 1; }

status=starting
for _ in $(seq 1 45); do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$c")"
  [ "$status" = healthy ] && break
  sleep 2
done
echo "HEALTHCHECK $status"
[ "$status" = healthy ] || { echo "::error::HEALTHCHECK is $status"; exit 1; }

[ "$(docker exec "$c" id -u)" != 0 ] || { echo "::error::runs as root"; exit 1; }

docker stop -t 10 "$c" >/dev/null
exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$c")"
echo "stopped, exit code $exit_code"
[ "$exit_code" != 137 ] || { echo "::error::ignored SIGTERM and was killed"; exit 1; }
echo "Console image smoke test passed."
