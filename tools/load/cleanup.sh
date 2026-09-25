#!/usr/bin/env bash
# Deletes everything one load run created (users `load-<runid>-<n>@aura.test` and what they own) and verifies it.
#   ./cleanup.sh <runid> [--since <ISO>]          # local DB (postgresql://postgres:postgres@127.0.0.1:55522/postgres)
#   LOAD_DB_URL=… AURA_LOAD_STAGING=1 AURA_LOAD_STAGING_ACK=<api host> API_URL=… ./cleanup.sh <runid>   # staging
#   ./cleanup.sh --all-local                      # every leftover load-* run on the LOCAL DB only
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export LOAD_DB_URL="${LOAD_DB_URL:-postgresql://postgres:postgres@127.0.0.1:55522/postgres}"

RUNIDS=()
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --all-local) ALL_LOCAL=1; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) RUNIDS+=("$1"); shift ;;
  esac
done

# Same guard as the load itself: the DB must be local unless the staging opt-in is complete; production never.
MODE="$(node "$HERE/lib/guard-cli.mjs")" || exit 3

if [[ "${ALL_LOCAL:-}" == "1" ]]; then
  [[ "$MODE" == "local" ]] || { echo "cleanup: --all-local only works against the local DB" >&2; exit 3; }
  while IFS= read -r r; do [[ -n "$r" ]] && RUNIDS+=("$r"); done < <(
    psql "$LOAD_DB_URL" -X -At -c "select distinct substring(email from '^load-([a-z0-9]+)-[0-9]+@aura\.test$') from auth.users where email ~ '^load-[a-z0-9]+-[0-9]+@aura\.test$'")
fi
[[ ${#RUNIDS[@]} -gt 0 ]] || { echo "cleanup: nothing to do (no run id given / found)"; exit 0; }

for RUNID in "${RUNIDS[@]}"; do
  [[ "$RUNID" =~ ^[a-z0-9]{4,24}$ ]] || { echo "cleanup: bad run id '$RUNID'" >&2; exit 2; }
  S="${SINCE:-}"
  if [[ -z "$S" && -f "$HERE/.runs/$RUNID/started_at" ]]; then S="$(cat "$HERE/.runs/$RUNID/started_at")"; fi
  S="${S:-1970-01-01T00:00:00Z}"
  echo "cleanup: run $RUNID ($MODE DB, since $S)"
  psql "$LOAD_DB_URL" -X -q -v ON_ERROR_STOP=1 -v runid="$RUNID" -v since="$S" -P pager=off -f "$HERE/cleanup.sql"
done

# Global safety net for local runs: no synthetic account of any run may remain.
if [[ "$MODE" == "local" ]]; then
  LEFT="$(psql "$LOAD_DB_URL" -X -At -c "select count(*) from auth.users where email like 'load-%@aura.test'")"
  echo "cleanup: load-*@aura.test accounts left on the local DB (all runs): $LEFT"
  if [[ "${ALL_LOCAL:-}" == "1" && "$LEFT" != "0" ]]; then exit 1; fi
fi
