# Aura realtime load harness (`tools/load`)

Milestone B hardening (PRD `20-timeline` weeks 28–29, "Beta hardening: realtime load test"). It drives synthetic
users through the same calls the app makes — room matching, joins, gestures, heartbeats, private Realtime room
topics, Breath Ripples quick-match with polling, reflections — and reports match time, per-route API latency,
realtime fan-out delay and error rates. Results of the runs so far: `docs/perf/realtime-load-test.md`.

**Local stack by default. Staging only with an explicit opt-in. Never production** (the guard refuses it and there is
no override).

## Requirements

- The local stack: `supabase start` (API 55521, DB 55522) and Redis (`docker compose -f infra/docker-compose.yml up -d`).
- `k6` (`brew install k6`), Node ≥ 22, `psql`, and `server/aura-api` dependencies installed (`pnpm install`).
- Nothing to install here: the Node helpers have no dependencies (`package.json` only holds scripts).

## Run it

```bash
cd tools/load
./run.sh --dry-run          # the plan and the guard verdict; creates nothing
./run.sh                    # small, safe default: 30 room users + 16 Breath Ripples users, 2 min (46 sockets)
./run.sh --scale large      # 110 room users + 40 ripples users (150 sockets) + a 400-user HTTP matching burst
./run.sh --rooms 0 --ripples 0 --burst 1000 --duration 60              # HTTP-only matching burst
K6_EXTRA_ENV="-e BURST_WINDOW_S=3" ./run.sh --rooms 0 --ripples 0 --burst 1000 --duration 60   # a sharper burst
```

Each run, end to end (bounded to a few minutes; `--duration` ≤ 300 s, ≤ 150 sockets, ≤ 2,000 users):

1. **Guard** (`lib/guard.js`): every target must be loopback unless the full staging opt-in is set.
2. Waits while an e2e suite runs on the same stack (the Breath Ripples queue and the local Realtime tenant are
   shared); stops the load early if one starts (`--force` skips this).
3. Starts its **own NestJS API on :3323** plus a **mock moderation provider on :3324** (`mock-moderation.mjs`:
   every text is clean after 250 ± 150 ms, like the real call). The overrides are env vars of that one process;
   no shared config, flag, `matching_config` row or rate-limit key is touched. `--api-url` uses an existing API.
4. **Provisions** `load-<runid>-<n>@aura.test` users (`provision.mjs`): Auth admin create → password grant → profile
   (adult, `en`, `Asia/Kolkata`) → guidelines accepted → echo opt-out.
5. **k6** (`aura-load.js`) runs three scenarios:
   - `rooms`: match within `ROOM_BURST_S`, one socket with `room:<id>` + `member:<id>`, detail and reflections
     refetch, a heartbeat every 45 s, gestures within the server limits, one reflection per `REFLECT_EVERY` users,
     then leave;
   - `ripples`: quick-match ticket (UUIDv7), poll until `matched`, `game:<sessionId>` Broadcast + Presence with
     `breath_state` / heartbeat / pulse, leave after `PLAY_S`, re-queue until the end;
   - `burst`: HTTP only (match → detail → heartbeat → leave) spread over `BURST_WINDOW_S`, for scale beyond the
     socket cap.
   Samplers record `pg_stat_activity` every second, container CPU, and `pg_stat_statements` before/after.
6. `report.mjs` writes `.runs/<runid>/report.md` (the tables quoted in `docs/perf`).
7. **Cleanup always runs** (also on Ctrl-C or failure, unless `--keep`), then everything the run started is stopped.

Knobs (k6 env through `K6_EXTRA_ENV="-e NAME=value …"`): `ROOM_BURST_S`, `BURST_START_S`, `BURST_WINDOW_S`,
`HEARTBEAT_S`, `GESTURE_MIN_S`/`GESTURE_MAX_S`/`GESTURE_CAP`, `REFLECT_EVERY`, `PLAY_S`, `QUADRANTS`, `RT_MAX_SOCKETS`.
`--db-pool N` sets `DB_POOL_MAX` for the harness's own API only. `--no-reflections` skips reflections.

Artifacts land in `.runs/<runid>/` (git-ignored, mode 700; `users.json` holds short-lived tokens of accounts that
cleanup deletes — never commit or share it).

## Cleanup

`cleanup.sh <runid>` (called by `run.sh`) runs `cleanup.sql` in one transaction and deletes **only** what that run
created:

- the run's `auth.users` rows (`^load-<runid>-[0-9]+@aura\.test$`) — cascades remove profiles, consents, room
  memberships, gestures, mutes, reflections, ripple seats/tickets, sanctions, strikes;
- rooms and Breath Ripples sessions that only the run's users sat in, ripple invites they made;
- reports / evidence holds about or by them (auto items such as held reflections), which would otherwise stay as
  unlinked queue rows (their user FKs are `SET NULL`);
- `realtime.messages` rows on the run's room / member / game topics.

It then verifies nothing of the run is left and prints the count of `load-*@aura.test` accounts on the local DB (0).
Rooms or sessions shared with a real user are kept (only the run's memberships go). Global rows, aggregate counters
and the append-only moderation audit chain are never touched. Leftovers from an interrupted run:

```bash
./cleanup.sh <runid>          # one run
./cleanup.sh --all-local      # every load-* run on the LOCAL DB only
```

## Staging (later — never production)

Staging needs every one of these, or the guard refuses before anything is created:

```bash
export AURA_LOAD_STAGING=1
export API_URL=https://api.staging.example.com            # host must carry a non-production marker
export AURA_LOAD_STAGING_ACK=api.staging.example.com      # the exact API host, typed again
export SUPABASE_URL=https://<staging-ref>.supabase.co
export AURA_LOAD_STAGING_SUPABASE_HOST=<staging-ref>.supabase.co
export AURA_LOAD_PROD_HOSTS=api.aura.app,<prod-ref>.supabase.co   # AK: list production hosts here once they exist
export SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=…    # staging keys, from the secret store — never committed
export LOAD_DB_URL=postgresql://…staging…                 # for cleanup.sh only
./run.sh --staging --dry-run && ./run.sh --staging
```

Before a staging run: tell whoever else uses staging, check the Supabase project's Realtime quotas (connections and
messages per second) and turn the spend cap decision into an explicit yes, run the small scale first, and point the
staging API at a moderation key meant for tests. With `--staging` the harness does not start its own API and there is
no mock moderation: reflections hit the staging moderation provider (use `--no-reflections` if that is not wanted).
Anything that looks like production (`prod`, `production`, `live`, `www`, or a host in `AURA_LOAD_PROD_HOSTS`) is
refused even with every opt-in set.

## Tests

`npm test` (or `node --test test/*.test.mjs`) checks the guard: loopback passes, staging needs the whole opt-in,
production-looking hosts are always refused, URLs with credentials parse, run ids and emails are strict.
