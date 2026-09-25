# Realtime load test — Milestone B hardening (weeks 28–29)

**Date:** 25 Sep 2026 · **Stack:** local (Supabase CLI stack in Docker on one laptop, Realtime tenant `realtime-dev`,
Redis 6391, a dedicated NestJS API on :3323 with a mock moderation provider) · **Harness:** `tools/load`
(k6 + zero-dependency Node helpers; see its README) · **Branch:** `fix/design-audit` (migrations through 000028).

## Summary

| Check | Target | Result |
|---|---|---|
| Breath Ripples quick-match, ticket → matched | p50 < 20 s (weeks 18–20 exit) | **p50 2.0 s**, p95 2.0–4.1 s (bounded by the 2 s poll interval) |
| Rooms `POST /v1/rooms/match` | p95 < 800 ms (v1-rooms §1.1) | **p95 23 ms** at 150 sockets + 400-user burst; **p95 47 ms** for 1,000 matches in 3 s |
| API latency, all routes | p95 < 300 ms (09-technical-constraints) | p95 17–40 ms; only `POST …/reflections` is slower (p50 263–362 ms, of which ~250 ms is the simulated moderation call) |
| Realtime fan-out (server accept → every member) | Breath Ripples ≤ 1.5 s one-way (F7) | gestures p95 21–29 ms; Breath Ripples client → client p95 8–14 ms |
| HTTP errors | — | 0.00 % (small), 0.44 % (large: 16 × `404 member_not_found`, a harness race, see below) |
| Realtime errors | — | none at 46 sockets; **90 × "Too many messages per second"** at 150 sockets (local tenant cap, see Bottleneck 1) |
| Cleanup | nothing synthetic left | every run verified: 0 `load-*@aura.test` accounts, 0 memberless rooms / humanless sessions since start |

**Verdict:** the API, Postgres and the matching paths have large headroom for the beta (20k users, 09-technical
constraints). The first limit a realtime-heavy evening will hit is the **Realtime messages-per-second quota**, not
the servers. One real performance bug was found and fixed: missing foreign-key indexes made room purges and account
deletions scan `reports` once per member and per gesture (migration `20261005000028_perf.sql`).

## Method

Every virtual user is a real account created for the run (`load-<runid>-<n>@aura.test`, adult, `en`,
`Asia/Kolkata`) that goes through the app's own onboarding calls (profile, guidelines, echo opt-out) and then behaves
like the app (details in `tools/load/README.md`):

- **rooms**: `POST /v1/rooms/match` inside a 10 s burst, one websocket with the private Broadcast topics
  `room:<id>` + `member:<id>` (RLS-checked joins), detail + reflections refetch, heartbeat every 45 s, gestures to the
  room or a member within the server limits, one reflection for every third user (published through the full
  filter + moderation pipeline against a mock provider: clean after 250 ± 150 ms), then `leave`.
- **ripples**: quick-match ticket (UUIDv7) and polling until `matched`, then `game:<sessionId>` (Broadcast +
  Presence) with `breath_state` transitions, idle heartbeats and pulses for 45 s, leave, re-queue.
- **burst**: HTTP only (match → detail → heartbeat → leave), for scale past the local socket cap.

Measured client-side (k6 on the same machine, loopback): match time, per-route latency and status, socket connect and
channel join time, fan-out delay from the server's `at` / sender's `t` to receipt at every other subscriber, and the
sender's own `gesture_sent` round trip (skew-free end to end). Samplers recorded `pg_stat_activity` every second,
container CPU every ~2 s and a `pg_stat_statements` delta.

Isolation: the harness ran its own API on :3323 (env overrides for that process only), changed no global row (flags,
`matching_config`, rate-limit keys), and ran when no other test suite was using the stack. Each run cleaned up only
its own rows and verified it.

## Runs

| Run | Load | Duration |
|---|---|---|
| `r092506447f28` small | 30 room users + 16 Breath Ripples users (46 sockets) | 120 s |
| `r092506467aa5` large | 110 room users + 40 ripples users (150 sockets) + 400-user HTTP burst (550 users) | 150 s |
| `r0925065078f0` burst | 1,000 users, `POST /v1/rooms/match` spread over 10 s (≈ 100 matches/s) | 60 s |
| `r092506516a77` sharp burst | 1,000 users over 3 s (≈ 330 matches/s) | 60 s |

150 sockets is the harness's ceiling on this stack: the local Realtime tenant allows 200 connections and 100
events/s for everyone (`_realtime.tenants`: `max_concurrent_users 200`, `max_events_per_second 100`).

### Match time

| Run | Rooms match p50 / p95 / max (ms) | Ripples ticket → matched p50 / p95 (ms) |
|---|---|---|
| small | 27 / 53 / 64 (n 30) | 2,033 / 4,061 (n 32; 2–3 polls) |
| large | 12 / 23 / 69 (n 510) | 2,018 / 2,037 (n 120; every session started full, 4 humans) |
| burst 10 s | 9 / 18 / 50 (n 1,000) | — |
| sharp burst 3 s | 19 / 47 / 101 (n 1,000) | — |

Breath Ripples matching is decided on the server within milliseconds; the ~2 s is the client's `pollAfterMs` poll
interval. Room matching placed 90 % of users into an existing room (step 2), created ~8 % (cold start) and merged a
few (step 3), as the v1-rooms ladder intends.

### API latency per route (large run, client-observed)

| Route | n | p50 ms | p95 ms | p99 ms | statuses |
|---|---|---|---|---|---|
| POST /v1/rooms/match | 510 | 12 | 22 | 30 | 200×510 |
| GET /v1/rooms/:id | 510 | 4 | 9 | 12 | 200×510 |
| POST /v1/rooms/:id/heartbeat | 748 | 7 | 20 | 24 | 200×748 |
| POST /v1/rooms/:id/gestures | 720 | 12 | 27 | 32 | 202×704, 404×16 |
| GET /v1/rooms/:id/reflections | 147 | 4 | 10 | 13 | 200×147 |
| POST /v1/rooms/:id/reflections | 37 | 263 | 424 | 435 | 201×37 |
| POST /v1/rooms/:id/leave | 510 | 7 | 15 | 21 | 200×510 |
| POST /v1/ripples/match | 211 | 10 | 25 | 34 | 200×211 |
| GET /v1/ripples/sessions/:id | 120 | 4 | 8 | 8 | 200×120 |
| POST /v1/ripples/sessions/:id/leave | 120 | 8 | 18 | 19 | 204×120 |
| **all** | 3,633 | 8 | 23 | 136 | 0.44 % failed |

The 16 × `404 member_not_found` are member-targeted gestures sent to someone who had just left the room — the
harness picks a target from its last room snapshot, as a phone could; the server answers correctly. Small run: 495
requests, 0 errors, p95 40 ms overall.

### Realtime

| Metric (ms) | small p50 / p95 | large p50 / p95 |
|---|---|---|
| socket connect (through Kong) | 3 / 4 | 2 / 4 |
| private channel join (RLS topic check) | 4 / 7 | 3 / 6 |
| gesture POST → sender sees its own `gesture_sent` | 22 / 40 | 14 / 29 |
| gesture `at` → every member on `room:<id>` | 14 / 29 | 10 / 21 |
| gesture `at` → recipient on `member:<id>` | 19 / 31 | 12 / 23 |
| `member_joined` fan-out | 22 / 41 | 14 / 27 |
| `reflection_published` fan-out | 5 / 15 | 4 / 13 |
| Breath Ripples client → client | 3 / 14 | 1 / 8 |
| own gesture broadcast seen within 10 s | 100 % | **75.6 %** |
| messages received | 4,422 (33.8/s) | 11,482 (70.9/s) |

### Server resources

| | small | large | burst 10 s | sharp burst |
|---|---|---|---|---|
| Postgres connections (max) | 24 | 24 | 24 | 24 |
| active backends (max) / lock waits (max) | 2 / 0 | 2 / 0 | 3 / 1 | 7 / 3 |
| API process CPU p95 (% of one core) | 11 | 22 | 47 | 102 |
| Postgres CPU p95 | 7 | 21 | 66 | 134 |

Hottest statements (large run, 2.3 s of statement time in total): `realtime.send` (0.10 ms × 2,242), the heartbeat
`update room_members … for update` (0.11 ms × 1,962), Realtime's own `realtime.messages` insert/select for private
channel authorization (0.9 / 0.5 ms × 240–340), the room match candidate query (0.18 ms × 1,020). In the sharp
burst, **82 % of statement time was waiting in `pg_advisory_xact_lock`** — the per-partition matching lock
(`aura:room-partition:<pool>:<quadrant>:<region>`, `rooms.repository.ts`), 3 per match, 2.5 ms mean.

## Bottlenecks and recommendations

1. **Realtime messages per second (first limit to hit).** At 150 sockets the local tenant's 100 events/s cap
   dropped messages ("Too many messages per second" × 90) and a quarter of the senders did not see their own gesture
   broadcast within 10 s. Room fan-out multiplies: each gesture is one `gesture_sent` to every member, so a full room
   of 20 with a gesture every ~20 s per person is ~20 delivered messages/s per room. On Supabase Pro the connection
   budget is 500 (09-technical-constraints) and messages/s are a separate plan quota.
   *Recommend:* before beta, confirm the production project's messages-per-second and connection quotas and set the
   alert at 50 % of both (09 already asks this for Presence); coalesce room `gesture_sent` broadcasts per room into
   one message every 1–2 s (a list of gesture ids), which cuts room fan-out by the gesture rate; keep heartbeats on
   HTTP (they already are) and keep Presence out of rooms. Re-run this harness against staging with the real quota.
2. **Matching lock at high burst rates.** Matches into one partition serialise on an advisory lock (by design: no
   duplicate cold-start rooms). At ~330 matches/s into the same `en` / IST partitions the lock wait is visible
   (p95 47 ms) but far inside the 800 ms target. The ceiling per partition is roughly the lock hold time
   (≈ 2–3 ms of transaction round trips) → a few hundred matches/s. *Recommend:* nothing for beta; if launch-day
   bursts approach that, shorten the locked section (read candidates before taking the lock, lock only the
   create/merge step) or partition further (e.g. by seed mood).
3. **One API process.** At the sharp burst the single Node process reached one full core (p95 102 %). *Recommend:*
   run ≥ 2 API instances behind the load balancer from beta (the API is stateless; BullMQ/Redis already coordinate
   the worker), and raise `DB_POOL_MAX` per instance only with the Postgres connection budget in mind (24
   connections were enough here).
4. **Fixed — FK indexes on delete paths (migration `20261005000028_perf.sql`).** `EXPLAIN ANALYZE` of a room purge
   with 200k rows in `reports` (rolled back): 60.6 ms for a room with 1 member and 5 gestures, 59 ms of it in three
   `reports` foreign-key checks (≈ 8 ms per member and per gesture, a sequential scan each); **1.4 ms** after the
   migration. A 20-member room with 200 gestures would have cost ≈ 2 s of the purge worker, growing with `reports`,
   and account deletion hits the same checks. The migration indexes every `ON DELETE CASCADE / SET NULL` referencing
   column that had none (reports, sanctions, strikes, gifts, room mutes, Breath Ripples tickets / seats / invites /
   sessions, gesture push log, blocks, device tokens, three small admin / billing links); pgTAP
   `supabase/tests/28_perf.test.sql` fails if a new cascading FK arrives without one.
5. **Contention seen once, while other suites shared the database.** An earlier 1,000-user burst on 24 Sep, run while
   e2e suites were deleting their users on the same Postgres, showed match p95 1.5 s with advisory-lock waits and DB
   CPU at 100 %; the same burst on a quiet stack was p95 18 ms. Load tests need the stack to themselves (the harness
   now waits for, and yields to, e2e runs); on staging, schedule them.
6. **Reflections** are the slowest write (p50 263 ms) because moderation runs inline before publishing; that is the
   intended design (fail-closed) and the time is the provider call. Watch the real provider's latency on staging.

## Not covered here

- Real network latency (Mumbai region, 3G-class phones) — loopback only; re-run on staging from a remote client.
- The production Realtime quotas (the local tenant is fixed at 200 connections / 100 events/s).
- Quiet Together (F16) sessions and the Lantern Hour wind-down (added after this harness was written).
- Push delivery (the worker's gesture batching) — not exercised.

## Reproduce

```bash
cd tools/load
./run.sh --scale small
./run.sh --scale large
./run.sh --rooms 0 --ripples 0 --burst 1000 --duration 60
K6_EXTRA_ENV="-e BURST_WINDOW_S=3" ./run.sh --rooms 0 --ripples 0 --burst 1000 --duration 60
```

Reports: `tools/load/.runs/<runid>/report.md` (git-ignored). Cleanup runs automatically; `./cleanup.sh --all-local`
removes leftovers of an interrupted run.
