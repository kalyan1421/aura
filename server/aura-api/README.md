# aura-api

NestJS 11 modular monolith for Aura — raw `pg` (no ORM), zod, jose, BullMQ. Two entrypoints:

| Entrypoint | Port | What |
|---|---|---|
| `src/main.ts` | **3310** | HTTP API — `contracts/api/v1.md` |
| `src/worker.ts` | **3311** | BullMQ workers + `GET /health` (db, redis, workers, last heartbeat) |

## Run

```bash
cp .env.example .env        # fill AURA_MASTER_KEY (openssl rand -base64 32); local values in supabase/LOCAL.md
                            # SUPABASE_SERVICE_ROLE_KEY: the API (signed voice-note URLs, voice cleanup on sync) and the
                            # worker (account purge) reach the private-media bucket via the Storage API with it
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
| `auth/` | global guards: `AuthGuard` (Supabase JWT via `jose`: ES256/RS256 against JWKS (by `kid`), HS256 only if `SUPABASE_JWT_SECRET` is set), then `PendingDeletionGuard` (`403 account_deletion_pending` while a deletion is scheduled; one PK lookup); `@CurrentUser()`, `@Public()`, `@AllowPendingDeletion()` |
| `rules/` | pure TS port of `contracts/rules/RULES.md` (aura day, eligibility, Starlight, stage, traits, hue, streak, nebula) |
| `progression/` | derive the `Snapshot` from ledger + active days; persist `avatar_state` / `streak_state` |
| `profile/` | `POST /v1/profile` (under-13 → 403, nothing stored), `GET /v1/me/snapshot` |
| `sync/` | `POST /v1/sync/push` — the only personal-data write path (incl. check-in `voicePath`; grapheme-counted text limits in `text-limits.ts`) |
| `media/` | `POST /v1/media/upload-url` / `download-url` — signed Storage URLs for F1 voice notes under `<user_id>/voice/<check-in id>` (503 `media_unavailable` without a service key) |
| `keys/` | `GET /v1/keys/data-key` — per-user AES-256-GCM-wrapped data key (DS-1) |
| `devices/` | `PUT` / `DELETE /v1/devices` — FCM token registration (upsert on token, reassigned across accounts; owner-scoped delete). Sending is F14 |
| `account/` | `GET /v1/account`, `POST` / `DELETE /v1/account/deletion` — 7-day grace (F8 REQ-ACC-11). `account-purge.ts` (worker): personal rows → private-media (Storage API) → GoTrue leftovers + `auth.users` (SQL) |
| `catalogue/` | cached moods / preset habits from the DB seed |
| `queues/` | queue registry (`capsule-unlock`, `room-lifecycle`, `moderation`, `notifications` + internal `heartbeat`, `maintenance`), skeleton processors, worker host. `maintenance` runs job `maintenance` (sync_mutations > 90 days, daily 03:17 UTC) and job `account-purge` (hourly :41 UTC) |
| `health/` | `GET /health` → `{status, db, redis}` |

## Sync semantics worth knowing

- One transaction per push, a per-user advisory lock, one savepoint per mutation. Replays of an applied mutation →
  `duplicate`; replays of a rejected one → the same `rejected` + reason.
- Rejection reasons: `invalid_mutation_id`, `unknown_entity`, `unknown_op`, `invalid_payload`, `invalid_tz`, `unknown_mood`,
  `unknown_preset_habit`, `duplicate_preset_habit`, `too_many_custom_habits`, `habit_not_found`, `already_logged`,
  `id_conflict`, `backfill_too_old` (> 7 days), `invalid_local_day` (> 2 days ahead of the event's aura day),
  `tag_too_long` (> 20 characters), `habit_name_too_long` (> 30 characters), `edit_window_closed`,
  `invalid_voice_path`, `conflict` / `invalid_reference` (DB constraint).
- Text limits count grapheme clusters (`Intl.Segmenter`, = the app's Dart `characters`), never UTF-16 units, plus a
  16-units-per-character safety cap (`src/sync/text-limits.ts`).
- Check-in edits (upsert of an existing id) are judged by `payload.editedAt` (fallback: the mutation's `deviceTs`, which
  the app keeps equal to the original check-in time): within 24 h of the stored `device_ts` and ≤ 5 min ahead of server
  time, else `edit_window_closed`. Inserts ignore `editedAt`; deletes are allowed any time.
- New check-ins / habit logs are always stored; only eligible ones (RULES §2) get a ledger row (amount may be 0) and an
  `active_days` row. Edits never re-time or re-credit. Deletes never touch the ledger or active days.
- Habit credits use `source_id = uuidv5(habitId:localDay)` so un-log + re-log cannot earn twice on the same day.
- `ringCount` / `glowLevel` count distinct credited aura days with `habit_key` `breathe` / `sleep_on_time`.

Never log request bodies, notes, DOB or job payloads.

## Voice notes (contracts/api/v1.md "Media: voice notes")

- `POST /v1/media/upload-url` signs a Storage **upsert** URL for `<user_id>/voice/<recordId>` (client-encrypted bytes,
  ≤ 1 MiB declared; `expiresAt` = 10 min, capped by Storage's own 2 h token); `POST /v1/media/download-url` signs a
  5-minute GET for paths under the caller's own prefix only — anything else is `404 not_found`.
- Sync stores `voicePath` (must be exactly `<user_id>/voice/<check-in id>`, DB CHECK `check_ins_voice_path_shape` as
  backstop). An edit to `null` or `op: delete` removes the object **after the push commits**, best-effort (warnings carry
  counts only; never fails the push). Without `SUPABASE_SERVICE_ROLE_KEY` the media routes answer 503 and cleanup is skipped.
- The Storage client is `src/account/private-media.ts` (`PrivateMediaStore`, provided globally by `QueuesModule`).

## Account deletion (contracts/api/v1.md "Account deletion")

- `POST /v1/account/deletion` schedules the purge 7 × 24 h after the **first** request (repeats return the same date)
  and deletes the account's FCM tokens; `DELETE` cancels until the date passes, then `409 account_deletion_in_progress`.
- While scheduled, every route except `/v1/account*` and `/health` → `403 account_deletion_pending`.
- Purge (`src/account/account-purge.ts`, worker job `account-purge`): per account, (1) one transaction deletes every
  `PERSONAL_TABLES` row, (2) the user's `private-media` objects go through the **Storage API** (`SUPABASE_SERVICE_ROLE_KEY`;
  direct `storage.objects` deletes are blocked by `storage.protect_delete()` and would orphan blobs), (3) one transaction
  scrubs GoTrue audit/flow/refresh rows keyed by the user and deletes `auth.users` **via SQL** (the Admin API delete would
  log a new audit entry with the email). Idempotent; the schedule row is the retry marker and vanishes with the auth user.
  Without a service key, accounts with media are deferred (warning) — rows are gone, media + auth user wait.
- New personal table? Add it to `PERSONAL_TABLES` — the e2e suite compares the list with every public table that has a
  `user_id` column.
