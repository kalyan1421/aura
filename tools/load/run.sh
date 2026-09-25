#!/usr/bin/env bash
# Aura realtime load test — one bounded run against the LOCAL stack (see README.md).
#
#   ./run.sh                       # small, safe default: 30 rooms + 16 ripples users, 2 min (46 sockets)
#   ./run.sh --scale large         # 110 rooms + 40 ripples users (150 sockets) + a 400-user HTTP matching burst
#   ./run.sh --dry-run             # print the plan and the guard verdict; creates nothing
#   ./run.sh --rooms 60 --ripples 24 --burst 200 --duration 150
#
# Steps: guard (local only unless the full --staging opt-in) → wait for other e2e runs → own NestJS API on :3323 with a
# mock moderation provider on :3324 (process-local env overrides only) → provision `load-<runid>-<n>@aura.test` users →
# k6 (aura-load.js) with DB / container samplers → report.md → cleanup.sh (always, unless --keep) → stop what it started.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

SCALE=small
DRY=0
KEEP=0
FORCE=0
OWN_API=1
ROOMS="" RIPPLES="" BURST="" DURATION=""
REFLECTIONS=1
API_PORT="${LOAD_API_PORT:-3323}"
MOCK_PORT="${LOAD_MOCK_PORT:-3324}"
DB_POOL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scale) SCALE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --keep) KEEP=1; shift ;;
    --force) FORCE=1; shift ;;
    --rooms) ROOMS="$2"; shift 2 ;;
    --ripples) RIPPLES="$2"; shift 2 ;;
    --burst) BURST="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --no-reflections) REFLECTIONS=0; shift ;;
    --db-pool) DB_POOL="$2"; shift 2 ;;
    --api-url) export API_URL="$2"; OWN_API=0; shift 2 ;;
    --staging) export AURA_LOAD_STAGING=1; OWN_API=0; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "run.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

case "$SCALE" in
  small) : "${ROOMS:=30}" "${RIPPLES:=16}" "${BURST:=0}" "${DURATION:=120}" ;;
  large) : "${ROOMS:=110}" "${RIPPLES:=40}" "${BURST:=400}" "${DURATION:=150}" ;;
  *) echo "run.sh: --scale small|large" >&2; exit 2 ;;
esac
SOCKETS=$((ROOMS + RIPPLES))
TOTAL=$((ROOMS + RIPPLES + BURST))
(( SOCKETS <= ${RT_MAX_SOCKETS:-150} )) || { echo "run.sh: $SOCKETS sockets > RT_MAX_SOCKETS ${RT_MAX_SOCKETS:-150} (the local Realtime tenant allows 200 connections for everyone)" >&2; exit 2; }
(( TOTAL <= 2000 )) || { echo "run.sh: $TOTAL users is more than this harness should create on a laptop" >&2; exit 2; }
(( DURATION <= 300 )) || { echo "run.sh: keep runs bounded (--duration ≤ 300 s)" >&2; exit 2; }

export SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:55521}"
export API_URL="${API_URL:-http://127.0.0.1:$API_PORT}"
export LOAD_DB_URL="${LOAD_DB_URL:-postgresql://postgres:postgres@127.0.0.1:55522/postgres}"
export LOAD_TZ="${LOAD_TZ:-Asia/Kolkata}"

MODE="$(node "$HERE/lib/guard-cli.mjs")" || exit 3
if [[ "$MODE" == "local" && -z "${SUPABASE_ANON_KEY:-}" ]]; then
  # Local CLI defaults (supabase/LOCAL.md) — read-only `supabase status`.
  eval "$(cd "$REPO" && supabase status -o env 2>/dev/null | grep -E '^(ANON_KEY|SERVICE_ROLE_KEY)=')"
  export SUPABASE_ANON_KEY="${ANON_KEY:-}" SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-}"
fi

RUNID="${RUNID:-r$(date -u +%m%d%H%M)$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')}"
RUN_DIR="$HERE/.runs/$RUNID"
EST_SECONDS=$((DURATION + 60 + (BURST > 0 ? 30 : 0)))
cat <<EOF
Aura load run $RUNID ($MODE)
  targets   supabase $SUPABASE_URL · api $API_URL$([[ $OWN_API == 1 ]] && echo " (own instance, mock moderation :$MOCK_PORT)")
  users     $TOTAL  (load-$RUNID-0@aura.test … load-$RUNID-$((TOTAL - 1))@aura.test)
  scenarios rooms $ROOMS · ripples $RIPPLES · burst $BURST (HTTP only) · $DURATION s · sockets $SOCKETS · tz $LOAD_TZ · reflections $REFLECTIONS
  bounded   ≈ $EST_SECONDS s of load after provisioning; cleanup $([[ $KEEP == 1 ]] && echo "SKIPPED (--keep)" || echo "always")
EOF
if [[ $DRY == 1 ]]; then
  RUNID="$RUNID" node "$HERE/provision.mjs" --runid "$RUNID" --count "$TOTAL" --dry-run
  echo "dry run: nothing was created."
  exit 0
fi
command -v k6 >/dev/null || { echo "run.sh: k6 not found (brew install k6)" >&2; exit 2; }
[[ -n "${SUPABASE_ANON_KEY:-}" && -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || { echo "run.sh: SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY missing" >&2; exit 2; }

# Courtesy: other agents share this stack. Don't start while an e2e suite is running (their rooms/queues would see ours).
# The local Realtime tenant is shared too (200 connections, 100 messages/s for everyone), and the Breath Ripples quick
# queue is one global queue: a load run next to an e2e run makes both flaky. Wait up to 10 min, then give up.
E2E_PATTERN='jest.*(e2e|jest-e2e)'
if [[ $FORCE == 0 && "$MODE" == "local" ]]; then
  for i in $(seq 1 120); do
    pgrep -f "$E2E_PATTERN" >/dev/null 2>&1 || break
    (( i % 6 == 1 )) && echo "run.sh: an e2e suite is running on this stack — waiting (--force to skip) …"
    (( i == 120 )) && { echo "run.sh: e2e still running after 10 min; not starting (re-run later or --force)" >&2; exit 4; }
    sleep 5
  done
fi

mkdir -p "$RUN_DIR"; chmod 700 "$RUN_DIR"
PIDS=()
cleanup_all() {
  local code=$?
  for p in "${PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  if [[ $KEEP == 0 && -f "$RUN_DIR/started_at" ]]; then
    "$HERE/cleanup.sh" "$RUNID" --since "$(cat "$RUN_DIR/started_at")" 2>&1 | tee "$RUN_DIR/cleanup.log" || code=1
    if [[ "$MODE" == "local" ]]; then
      echo "echo_library.recordings after: $(psql "$LOAD_DB_URL" -X -At -c 'select count(*) from echo_library.recordings')" | tee -a "$RUN_DIR/cleanup.log"
    fi
  fi
  echo "run.sh: done ($RUN_DIR)"
  exit $code
}
trap cleanup_all EXIT INT TERM

# ---- own API instance + mock moderation (env overrides for this process only)
if [[ $OWN_API == 1 ]]; then
  MOCK_KEY="load-mock-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
  node "$HERE/mock-moderation.mjs" --port "$MOCK_PORT" --key "$MOCK_KEY" >"$RUN_DIR/mock.log" 2>&1 & PIDS+=($!)
  (
    cd "$REPO/server/aura-api"
    exec env PORT="$API_PORT" OPENAI_API_KEY="$MOCK_KEY" OPENAI_MODERATION_URL="http://127.0.0.1:$MOCK_PORT/v1/moderations" \
      ${DB_POOL:+DB_POOL_MAX=$DB_POOL} node_modules/.bin/ts-node-transpile-only src/main.ts
  ) >"$RUN_DIR/api.log" 2>&1 & PIDS+=($!)
  API_PID=$!
  for i in $(seq 1 60); do
    curl -fsS "$API_URL/health" >/dev/null 2>&1 && break
    kill -0 "$API_PID" 2>/dev/null || { echo "run.sh: API failed to start (see $RUN_DIR/api.log)" >&2; exit 1; }
    sleep 1
  done
  curl -fsS "$API_URL/health" >/dev/null || { echo "run.sh: API not healthy after 60 s" >&2; exit 1; }
  echo "api: own instance on :$API_PORT (pid $API_PID), mock moderation on :$MOCK_PORT"
fi

date -u +%Y-%m-%dT%H:%M:%SZ >"$RUN_DIR/started_at"
if [[ "$MODE" == "local" ]]; then
  echo "echo_library.recordings before: $(psql "$LOAD_DB_URL" -X -At -c 'select count(*) from echo_library.recordings')" | tee "$RUN_DIR/echoes.log"
fi

# ---- provision
RUNID="$RUNID" node "$HERE/provision.mjs" --runid "$RUNID" --count "$TOTAL" --out "$RUN_DIR" --concurrency "${PROVISION_CONCURRENCY:-16}"

# ---- samplers (local only): DB activity / lock waits every 1 s, container CPU every ~3 s, pg_stat_statements snapshot
if [[ "$MODE" == "local" ]]; then
  PGSS="select queryid, calls, round(total_exec_time::numeric,2), rows, regexp_replace(left(query, 240), '[\\n\\r\\t,]+', ' ', 'g') from extensions.pg_stat_statements where dbid = (select oid from pg_database where datname = current_database())"
  psql "$LOAD_DB_URL" -X -At -F, -c "$PGSS" >"$RUN_DIR/pgss_before.csv" 2>/dev/null || true
  (
    while true; do
      psql "$LOAD_DB_URL" -X -At -F, -c "select to_char(clock_timestamp(),'HH24:MI:SS'), count(*), count(*) filter (where state='active'), count(*) filter (where wait_event_type='Lock'), count(*) filter (where wait_event='advisory'), count(*) filter (where wait_event_type='Lock' and wait_event in ('transactionid','tuple')), count(*) filter (where wait_event_type='LWLock'), count(*) filter (where state='idle in transaction') from pg_stat_activity where datname = current_database() and pid <> pg_backend_pid()" 2>/dev/null
      sleep 1
    done
  ) >"$RUN_DIR/db_activity.csv" & PIDS+=($!)
  (
    while true; do
      docker stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}}' 2>/dev/null | grep -E '^(supabase_(db|realtime|kong|auth|rest)_aura|aura_redis),' | sed "s/^/$(date +%H:%M:%S),/"
      [[ -n "${API_PID:-}" ]] && echo "$(date +%H:%M:%S),aura_api_3323,$(ps -o %cpu= -p "$API_PID" 2>/dev/null | tr -d ' ')%,-"
      sleep 2
    done
  ) >"$RUN_DIR/containers.csv" & PIDS+=($!)
fi

# ---- load (yields to e2e: if a suite starts mid-run, k6 is interrupted — it still writes its summary)
set +e
k6 run --quiet \
  -e RUN_DIR="$RUN_DIR" -e RUNID="$RUNID" -e SUPABASE_URL="$SUPABASE_URL" -e API_URL="$API_URL" \
  -e SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" -e LOAD_TZ="$LOAD_TZ" \
  -e AURA_LOAD_STAGING="${AURA_LOAD_STAGING:-}" -e AURA_LOAD_STAGING_ACK="${AURA_LOAD_STAGING_ACK:-}" \
  -e AURA_LOAD_STAGING_SUPABASE_HOST="${AURA_LOAD_STAGING_SUPABASE_HOST:-}" -e AURA_LOAD_PROD_HOSTS="${AURA_LOAD_PROD_HOSTS:-}" \
  -e ROOMS_VUS="$ROOMS" -e RIPPLES_VUS="$RIPPLES" -e BURST_VUS="$BURST" -e DURATION_S="$DURATION" \
  -e REFLECTIONS="$REFLECTIONS" -e RT_MAX_SOCKETS="${RT_MAX_SOCKETS:-150}" \
  ${K6_EXTRA_ENV:-} \
  --out "csv=$RUN_DIR/samples.csv.gz" \
  "$HERE/aura-load.js" > >(tee "$RUN_DIR/k6.log") 2>&1 &
K6_PID=$!
if [[ $FORCE == 0 && "$MODE" == "local" ]]; then
  (
    while kill -0 "$K6_PID" 2>/dev/null; do
      if pgrep -f "$E2E_PATTERN" >/dev/null 2>&1; then
        echo "run.sh: an e2e suite started — stopping the load early to stay out of its way" | tee -a "$RUN_DIR/k6.log"
        kill -INT "$K6_PID" 2>/dev/null; break
      fi
      sleep 2
    done
  ) & PIDS+=($!)
fi
wait "$K6_PID"
K6_CODE=$?
set -e
echo "k6 exit code: $K6_CODE (99 = a threshold/target was missed; the run itself completed)"

if [[ "$MODE" == "local" ]]; then
  psql "$LOAD_DB_URL" -X -At -F, -c "$PGSS" >"$RUN_DIR/pgss_after.csv" 2>/dev/null || true
fi
node "$HERE/report.mjs" "$RUN_DIR" || echo "run.sh: report failed (raw data is in $RUN_DIR)"
