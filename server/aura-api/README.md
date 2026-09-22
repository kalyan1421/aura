# aura-api

NestJS 11 modular monolith for Aura — raw `pg` (no ORM), zod, jose, BullMQ. Two entrypoints:

| Entrypoint | Port | What |
|---|---|---|
| `src/main.ts` | **3310** | HTTP API — `contracts/api/v1.md` |
| `src/worker.ts` | **3311** | BullMQ workers + `GET /health` (db, redis, workers, last heartbeat) |

## Run

```bash
cp .env.example .env        # fill AURA_MASTER_KEY (openssl rand -base64 32); local values in supabase/LOCAL.md
pnpm install
pnpm test                   # unit: rules vectors, auth, crypto, validation, sync orchestration (no DB)
pnpm test:e2e               # needs the local Supabase stack (55521/55522) + Redis (6391)
pnpm start:dev              # API on :3310        → curl localhost:3310/health
pnpm start:worker:dev       # worker health :3311 → curl localhost:3311/health
pnpm build && pnpm start    # compiled (dist/main.js, dist/worker.js via pnpm start:worker)
pnpm lint                   # type-check (tsc --noEmit, strict)
```

## Layout (`src/`)

| Module | Notes |
|---|---|
| `config/` | zod-validated env (`AppConfig`); `.env` is merged without overriding real env vars |
| `db/` | `pg` Pool, `withTx`, `Tx.savepoint()`; DATE columns stay `YYYY-MM-DD` strings |
| `auth/` | global guard; Supabase JWT via `jose`: ES256/RS256 against JWKS (by `kid`), HS256 only if `SUPABASE_JWT_SECRET` is set; `@CurrentUser()`, `@Public()` |
| `rules/` | pure TS port of `contracts/rules/RULES.md` (aura day, eligibility, Starlight, stage, traits, hue, streak, nebula) |
| `progression/` | derive the `Snapshot` from ledger + active days; persist `avatar_state` / `streak_state` |
| `profile/` | `POST /v1/profile` (under-13 → 403, nothing stored), `GET /v1/me/snapshot` |
| `sync/` | `POST /v1/sync/push` — the only personal-data write path |
| `keys/` | `GET /v1/keys/data-key` — per-user AES-256-GCM-wrapped data key (DS-1) |
| `devices/` | `PUT` / `DELETE /v1/devices` — FCM token registration (upsert on token, reassigned across accounts; owner-scoped delete). Sending is F14 |
| `catalogue/` | cached moods / preset habits from the DB seed |
| `queues/` | queue registry (`capsule-unlock`, `room-lifecycle`, `moderation`, `notifications` + internal `heartbeat`), skeleton processors, worker host |
| `health/` | `GET /health` → `{status, db, redis}` |

## Sync semantics worth knowing

- One transaction per push, a per-user advisory lock, one savepoint per mutation. Replays of an applied mutation →
  `duplicate`; replays of a rejected one → the same `rejected` + reason.
- Rejection reasons: `invalid_mutation_id`, `unknown_entity`, `unknown_op`, `invalid_payload`, `unknown_mood`,
  `unknown_preset_habit`, `habit_not_found`, `already_logged`, `id_conflict`, `backfill_too_old` (> 7 days),
  `invalid_local_day` (> 2 days ahead of the event's aura day), `conflict` / `invalid_reference` (DB constraint).
- New check-ins / habit logs are always stored; only eligible ones (RULES §2) get a ledger row (amount may be 0) and an
  `active_days` row. Edits never re-time or re-credit. Deletes never touch the ledger or active days.
- Habit credits use `source_id = uuidv5(habitId:localDay)` so un-log + re-log cannot earn twice on the same day.
- `ringCount` / `glowLevel` count distinct credited aura days with `habit_key` `breathe` / `sleep_on_time`.

Never log request bodies, notes, DOB or job payloads.
