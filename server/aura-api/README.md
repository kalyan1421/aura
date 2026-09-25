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
                            # APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY / APPLE_CLIENT_ID (API + worker): Sign in
                            # with Apple token revocation on account deletion (docs/setup/social-sign-in.md §10)
pnpm install
pnpm test                   # unit: rules vectors, auth, crypto, validation, sync orchestration (no DB)
pnpm test:e2e               # needs the local Supabase stack (55521/55522) + Redis (6391)
pnpm start:dev              # API on :3310        → curl localhost:3310/health
pnpm start:worker:dev       # worker health :3311 → curl localhost:3311/health
pnpm build && pnpm start    # compiled (dist/main.js, dist/worker.js via pnpm start:worker)
pnpm lint                   # type-check (tsc --noEmit, strict) + push copy lint (REQ-NTF-01, `pnpm lint:copy`)
```

## Layout (`src/`)

| Module | Notes |
|---|---|
| `config/` | zod-validated env (`AppConfig`); `.env` is merged without overriding real env vars |
| `db/` | `pg` Pool, `withTx`, `Tx.savepoint()`; DATE columns stay `YYYY-MM-DD` strings |
| `auth/` | global guards: `AuthGuard` (Supabase JWT via `jose`: ES256/RS256 against JWKS (by `kid`), HS256 only if `SUPABASE_JWT_SECRET` is set), then `PendingDeletionGuard` (`403 account_deletion_pending` while a deletion is scheduled; one PK lookup), then `AccountClosedGuard` (`403 account_closed` for an active `account_ban`, except `@AllowAccountClosed()` routes: `/v1/account*`, `GET /v1/safety*`); `@CurrentUser()`, `@Public()`, `@AllowPendingDeletion()`, `@AllowAccountClosed()` |
| `rules/` | pure TS port of `contracts/rules/RULES.md` (aura day, eligibility, Starlight, stage, traits, hue, streak, nebula) |
| `progression/` | derive the `Snapshot` from ledger + active days; persist `avatar_state` / `streak_state` |
| `profile/` | `POST /v1/profile` (under-13 by DOB or `ageSignal` → 403, nothing stored; `ageSignal: "under18"` → server-only `minor_signals`, read by `user_is_minor()`), `GET /v1/me/snapshot` |
| `sync/` | `POST /v1/sync/push` — the only personal-data write path (incl. check-in `voicePath`; grapheme-counted text limits in `text-limits.ts`) |
| `media/` | `POST /v1/media/upload-url` / `download-url` — signed Storage URLs for F1 voice notes under `<user_id>/voice/<check-in id>` (503 `media_unavailable` without a service key) |
| `keys/` | `GET /v1/keys/data-key` — per-user AES-256-GCM-wrapped data key (DS-1) |
| `devices/` | `PUT` / `DELETE /v1/devices` — FCM token registration (upsert on token, reassigned across accounts; owner-scoped delete). Sending: `notifications/` (F14) |
| `account/` | `GET /v1/account` (+ `accountClosed: true` when banned), `POST` / `DELETE /v1/account/deletion` — 7-day grace (F8 REQ-ACC-11), `POST /v1/account/apple-auth` (Sign in with Apple refresh token, sealed; `apple-sign-in.ts`, `apple-tokens.ts`). `account-purge.ts` (worker): personal rows → Apple token revoked → private-media (Storage API) → GoTrue leftovers + `auth.users` (SQL) |
| `catalogue/` | cached moods / preset habits from the DB seed |
| `queues/` | queue registry (`capsule-unlock`, `room-lifecycle`, `notifications` + internal `heartbeat`, `maintenance`; reflections run their own `reflections` queue), worker host. `maintenance` runs job `maintenance` (sync_mutations > 90 days and sync_tombstones > 400 days, daily 03:17 UTC), job `account-purge` (hourly :41 UTC) and job `retention` (`retention.ts`: moderation audit rows > 3 years via `prune_moderation_actions()`; closed reports only once `safety_config.closed_report_retention_days` is set — NULL = keep; daily 03:29 UTC) |
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
- Sign in with Apple (App Review 5.1.1(v)): the stored refresh token (`apple_auth_tokens`) is revoked at Apple when the
  deletion is requested (best effort, ≤ 5 s) and by the purge right after step (1). Apple unreachable / no `APPLE_*` on
  the worker → deferred for up to 72 h after the grace period, then dropped unrevoked (`appleAbandoned`, warned).
- New personal table? Add it to `PERSONAL_TABLES` — the e2e suite compares the list with every public table that has a
  `user_id` column.
- Closed accounts (active `account_ban`): every route but `/v1/account*`, `GET /v1/safety*` and `/health` →
  `403 account_closed` (a pending deletion answers first). They can still see their status and delete themselves.

## Time capsules — F4 (contracts/api/v1-capsules.md)

| Module | Notes |
|---|---|
| `capsules/` | `CapsuleSyncHandler` (sync entity `capsule`: `seal` / `open` / `fire` / `rearm` / `delete`), `CapsulesRepository`, `CapsuleMediaGate` (capsule-media rules), `capsule-rules.ts` (RULES.md §9: unlock window, 10:00-local `unlockAt`, arming, cooldown, `pickTrigger`), `CapsuleUnlockService` (+ `CapsuleUnlockModule`: the unlock push, API + worker) |
| `notifications/` | `NotificationsService.enqueue(userId, type, opaqueId, { dedupeKey })` → queue `notifications`; worker `NotificationDispatcher` → `NotificationDelivery` (F14 rules, see "Notifications — F14" below) → `NOTIFICATION_TRANSPORT` (FCM, or log-only without credentials) |

- **Storage:** `public.capsules` holds ciphertext (`payload_ct`: title, text, media refs, hard-moment flag — never decrypted)
  plus unlock metadata; select-own RLS for the app's pull, no client writes. Deletes are **tombstones** (content and target
  erased) so "delete wins" across devices. `public.capsule_unlock_schedule` is server-only bookkeeping for the push.
- **Sync rules:** content and unlock metadata are immutable after `seal` (identical re-send = no-op, anything else
  `capsule_sealed`); date window 7 days – 5 years from the seal's calendar date (+ a server-clock guard); Free = 3 active
  trigger capsules (`trigger_capsule_limit`, nothing stored), 200 pending date capsules (`date_capsule_limit`); `open` is
  one-way and stores the server time (early opens tolerated); `fire` keeps the earliest device time per cycle and sets
  `cooldown_until = fire + 168 h`; `rearm` starts a new `cycle` (stale ops → `stale_cycle`). Device timestamps are never
  stored ahead of server time for fire/re-arm. Capsule reasons: `invalid_unlock_date`, `trigger_capsule_limit`,
  `date_capsule_limit`, `capsule_sealed`, `capsule_deleted`, `capsule_not_found`, `stale_cycle`, `not_a_trigger_capsule`,
  `capsule_not_armed`, `capsule_not_opened` (+ the generic ones).
- **After commit (best-effort, 5 s, counts-only warnings):** schedule new date capsules' unlock jobs, cancel opened/deleted
  ones, delete deleted capsules' media (`<user_id>/capsules/<id>/…`). A failure never changes the push result.
- **Media:** `POST /v1/media/upload-url` kinds `capsule_voice` (≤ 2 MiB → `…/capsules/<id>/voice`) and `capsule_photo`
  (`index` 0–2, ≤ 4 MiB → `…/photo-<index>`). Before the seal reaches the server: upsert URLs; after: an empty slot may be
  filled once, an occupied one is `409 capsule_sealed`; tombstoned capsules → `409 capsule_deleted` and their downloads 404.
- **Unlock push:** one delayed job per pending date capsule on `capsule-unlock` (opaque id `unlockJobId()`, data
  `{ capsuleId }`) at 10:00 on the unlock date in the **current profile timezone**. The job re-reads the zone (moved west →
  `moveToDelayed`); the worker's repeatable `sweep` (every 10 min, same queue) re-schedules capsules whose profile zone
  changed, schedules never-scheduled ones and handles jobs > 15 min overdue. Sent at most once per user per unlock date
  (hashed dedupe key), never > 24 h late, never for opened/deleted capsules.
- **Account purge:** `capsules` is in `PERSONAL_TABLES` (the schedule cascades; media goes with the `<user_id>/` prefix);
  `purgeAccount` / `purgeDueAccounts` take an optional `UnlockJobCanceller` (the worker passes `CapsuleUnlockService`).
- **Tests:** `test/unit/capsules.*.spec.ts` (rules edge cases, sync handler, media, unlock + notifications),
  `contracts/rules/vectors/capsules.json` (runner in `rules.vectors.spec.ts`), `test/e2e/capsules.e2e-spec.ts`,
  `supabase/tests/09_capsules.test.sql`.

## Notifications — F14, Milestone A (contracts/api/v1-notifications.md)

Daily check-in reminder + date capsule unlocked, under the PRD's global rules.

| File | Notes |
|---|---|
| `policy.ts` | pure rules: quiet hours (default 23:00–08:00, wraps midnight, user-confirmed reminder exception), 2 pushes per Aura day with precedence (`catalogue.ts`), toggles + master switch, pending deletion, staleness, reminder planning (DST-safe) |
| `notification-prefs.ts` | sync entity `notification_prefs` (upsert = patch, per-field LWW on `deviceTs` clamped to server time); re-plans `reminder_next_at` in the profile zone inside the push |
| `delivery.service.ts` | one push: facts → `decide()` → atomic day slot (`sent_day` / `sent_types` on the prefs row) → localized generic copy (`push-copy.ts`, discreet-aware) → transport per install → prune `UNREGISTERED` |
| `reminder.service.ts` | `reminder-sweep` (every min: claim due rows, enqueue once per Aura day) + `reminder-reconcile` (every 10 min: zone changes) on the `notifications` queue |
| `fcm.transport.ts` | FCM HTTP v1 (service-account JWT via `jose`, cached OAuth token); Android `VISIBILITY_PRIVATE` + channel + tag, iOS alert + collapse id; `FCM_SERVICE_ACCOUNT_JSON` / `FCM_SERVICE_ACCOUNT_FILE`, else `LogOnlyNotificationTransport` |
| `copy-lint.ts` | REQ-NTF-01 lint (moods/quadrants/themes + banned words, 5 languages); gate: `pnpm lint:copy` (part of `pnpm lint`) |

- **Tests:** `test/unit/notifications.*.spec.ts` (policy, delivery, prefs + reminder schedule, FCM transport, copy, copy
  lint), `test/e2e/notifications.e2e-spec.ts`, `supabase/tests/12_notifications.test.sql`.

## Mood Rooms — F5 and core safety — F9 (contracts/api/v1-rooms.md)

| Module | Notes |
|---|---|
| `rooms/` | `RoomsService` (`POST /v1/rooms/match`, `GET /v1/rooms[/:id]`, heartbeat, leave, survey, mutes), `GesturesService` (`POST …/gestures`: limits, silent drops, broadcasts), pure rules (`matching.ts` ladder + thin merge, `regions.ts` offset→region + Lantern Hour windows incl. DST, `room-state.ts`, `pseudonyms.ts`, `gesture-limits.ts`), `room-views.ts` + `broadcast.ts` (the only builders of stranger-facing shapes — DS-10), `room-lifecycle.ts` (worker tick) |
| `safety/` | `ReportsService` (`/v1/safety/reports` → lanes, SLA, evidence, under-13 pause), `BlocksService`, `SafetyService` (`GET /v1/safety/me`), `ModerationService` (internal API for the admin console: queue by lane, act, lift, mandatory reports, audit), plain SQL helpers (`safety.queries.ts`, `evidence.ts`, `audit.ts`, `reports.core.ts`) shared with rooms and the worker |

- **Schema:** `supabase/migrations/20261005000010_rooms_safety.sql` — all tables server-only (RLS on, no policies, no
  client grants). Tunables in single-row `matching_config` / `safety_config` (read per request; change without a release).
  Hindi + Hinglish rooms: client-readable flag `feature_flags.rooms_pool_hi` (off).
- **Matching:** one transaction — per-user advisory lock (one room per quadrant) → step 0 → join limit → thin merge
  (demand = joins by *home* partition) → per-partition advisory lock (no duplicate cold-start rooms) → ladder → per-room
  `FOR UPDATE` with the capacity/block re-check → seat. DB trigger `room_members_guard` is the backstop (`AR001` full,
  `AR002` second room for a quadrant, `AR003` joins closed); the service moves on to the next candidate on any of them.
- **Presence:** server-side. `room_members.last_seen_at` is touched by match/detail/heartbeat/gesture; live = within
  `live_window_s` (120 s). Realtime Presence is not used (no presence policy), so nobody can publish a fake presence.
- **Realtime:** private Broadcast topics `room:<room_id>` / `member:<member_id>`, authorised by policy
  `aura_rooms_receive` on `realtime.messages` → `public.realtime_topic_allowed(topic)` (SECURITY DEFINER; current
  membership, room not purged, no pending deletion, no room-access sanction). No INSERT policy: clients can't broadcast.
  The server broadcasts with `select realtime.send(...)` inside the write transaction (delivered only on commit).
- **Limits and drops:** gestures 1 / 2 s (across rooms), 40 / room / h, same gesture → same member ≤ 3 / 10 min.
  Over-limit attempts are stored as `dropped = 'over_limit'` (the limit hits); 3 hits in 24 h → `gesture_shadow_mute`
  (24 h) + an auto spam-lane report + an audit row. Blocks (both ways), mutes, shadow-mutes and hidden recipients drop
  silently too; every drop answers exactly like a delivery.
- **Worker:** `room-lifecycle` queue, job `room-lifecycle-tick` every minute at :00 (`ROOM_LIFECYCLE_CRON`): cached status
  transitions + one `room_state` / `lantern_hour` broadcast each, "here now" sweep, purge at 24 h + 7 d
  (`ensureEvidenceForRoom` first), evidence past `hold_until`. Logs counts only.
- **Safety data:** reports snapshot the item into `evidence_holds` at filing (180 days; subjects' account ids only, never
  the reporter's). `moderation_actions` is append-only (trigger `AR010` + revoked grants) and hash-chained; subjects are an
  HMAC of the account id (key derived from `AURA_MASTER_KEY`). Lanes and `involves_minor` never leave the server.
- **Account purge:** `room_members`, `sanctions`, `strikes` are in `PERSONAL_TABLES` (gestures and mutes cascade);
  `ACCOUNT_REFERENCE_CLEANUP` deletes blocks both ways and nulls the account's links on reports; `LEGAL_HOLD_TABLES`
  (`evidence_holds`) is the only documented exception `[LEGAL]` — the rooms e2e suite scans every public column after a
  purge and fails on any other reference.
- **Tests:** `test/unit/rooms.*.spec.ts`, `test/unit/safety.lanes.spec.ts` (incl. a lock-discipline concurrency test),
  `test/e2e/rooms.e2e-spec.ts` (+ `test/e2e/realtime.ts`, a minimal Phoenix client for private channels; includes the
  DS-10 contract scan of every response and broadcast), `supabase/tests/10_rooms_safety.test.sql`.
