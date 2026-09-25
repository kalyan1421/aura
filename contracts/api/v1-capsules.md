# Aura API v1 — F4 Personal Time Capsules

Extends `contracts/api/v1.md` (same auth, error shape, sync envelope and media routes). PRD: F4 in
`docs/prd/sections/06a-features-core.md`, conflict rules in `16-offline.md`, DS-1 in `10-data-model.md`, the
"Date capsule unlocked" push in `12-notifications.md`. Shared rules: `contracts/rules/RULES.md` §9 +
`contracts/rules/vectors/capsules.json` (Dart and TS must both pass them).

**One-line model:** capsules are written only through `POST /v1/sync/push` (entity `capsule`), read back with
Supabase select-own on `public.capsules`, and carry **ciphertext only** — title, text, media references and the
hard-moment flag are all inside `payloadCt`. The server stores unlock metadata (type, date or target, armed,
fired, opened) and nothing it could show.

## 1. What is encrypted (DS-1, REQ-CAP-07)

`payloadCt` is produced on the device with the per-user data key (`GET /v1/keys/data-key`), AES-256-GCM, the same
envelope as check-in `noteCt`, **associated data = the capsule id** (lower-case). Base64 or base64url (padding
optional), 1 – 131,072 characters. The server never decrypts, parses or logs it. The plaintext is app-defined;
recommended (versioned) shape:

```json
{ "v": 1, "title": "For my next Overwhelmed day", "text": "You've done this before…", "hardMoment": false,
  "media": [ { "slot": "voice", "durationMs": 83000 }, { "slot": "photo-0", "w": 2048, "h": 1536 } ] }
```

- Limits enforced **on the device** (the server cannot see them): title ≤ 60 characters (visible while sealed —
  the app decrypts locally to show it), text ≤ 2,000 characters (grapheme clusters, like every text limit), voice
  ≤ 2:00 (Plus 10:00 later), ≤ 3 photos, ≤ 2,048 px on the long edge, EXIF/GPS stripped before encryption.
- `hardMoment` = PRD `sealed_in_hard_moment` (a lexicon hit while sealing). It lives only in the ciphertext, so
  only the device knows it; the opening flow reads it after decrypting.
- Media objects are separate ciphertexts (§5). Recommended AD for a media object: `<capsule id>/<slot>`.

## 2. Sync push: entity `capsule`

Same endpoint, envelope, idempotency (mutation `id`), per-mutation savepoints and replay rules as v1.md.
Capsule mutations earn nothing (no Starlight, no active day) and never change the snapshot.

```json
{ "id": "<mutation uuidv7>", "entity": "capsule", "op": "seal",
  "deviceTs": "2026-10-08T18:00:00+05:30", "tz": "Asia/Kolkata",
  "payload": { "id": "<capsule uuidv7>", "payloadCt": "<base64>", "unlockType": "date", "unlockLocalDate": "2027-10-08" } }
```

- `deviceTs` is **required** for every capsule op: the moment of the action on the device clock (seal / fire /
  open / re-arm / delete). Missing → `rejected: invalid_payload`.
- `tz`: the IANA zone the device was in (used for the seal's calendar date); absent → profile timezone; unknown
  → `invalid_tz`. `localDay` is optional and ignored for capsules.
- Ops for `capsule`: `seal`, `open`, `fire`, `rearm`, `delete`. Any other op (e.g. `upsert`) → `unknown_op`
  (and the capsule ops are `unknown_op` for other entities).
- A record's mutations must go out in order (seal → fire → open → rearm …), like every outbox record.

### 2.1 `seal` — create (content is immutable from here on)

| `unlockType` | payload |
|---|---|
| `date` | `{ id, payloadCt, unlockType: "date", unlockLocalDate: "YYYY-MM-DD" }` |
| `mood` (one mood) | `{ id, payloadCt, unlockType: "mood", triggerMoodId: "overwhelmed" }` |
| `mood` (a quadrant) | `{ id, payloadCt, unlockType: "mood", triggerQuadrant: "storm" }` |

Fields that don't belong to the type must be absent or `null`; a mood capsule has **exactly one** of
`triggerMoodId` / `triggerQuadrant`.

Rules, in order:
1. Shape → `invalid_payload`; `triggerMoodId` not in the mood catalogue → `unknown_mood`.
2. The id exists: another user's → `id_conflict`; a tombstone → `capsule_deleted`; same `payloadCt`, type, date and
   target → **no-op, `applied`** (a re-send); anything different → **`capsule_sealed`** (content and unlock
   metadata never change after sealing).
3. New capsule only:
   - `date`: RULES.md §9.1 window — `unlockLocalDate` from **7 days to 5 years** after the seal's calendar date
     (`localDate(deviceTs, tz)`, no 04:00 shift) → else `invalid_unlock_date`. Server-only guard against broken
     clocks: also ≤ 5 years + 2 days after the server's own date in that zone.
   - `mood`: at most **3 active trigger capsules** on Free (active = not deleted and not opened in its current cycle;
     an active Aura Plus entitlement makes it unlimited, F12) → the 4th → **`trigger_capsule_limit`, nothing stored**. The app
     keeps it locally and shows the Plus explainer / "make it a date capsule": re-seal the **same capsule id** as
     `date` under a new mutation id (uploaded media stay valid). Date capsules never hit this limit.
   - `date`: fair-use cap **200 pending** date capsules (not deleted, not opened) → `date_capsule_limit`.
4. Stored: `sealed_at = deviceTs`; mood capsules `armed_at = deviceTs + 24 h` (RULES.md §9.3), `cycle = 0`.
   A date capsule gets its unlock push scheduled (§6).

### 2.2 `open` — one-way, records the real unlock time

`{ id, cycle }` (`cycle` defaults to 0; send the capsule's current `cycle`).
- Unknown id (for this user) → `capsule_not_found`; tombstone → `capsule_deleted`; `cycle` ≠ current →
  `stale_cycle`.
- Already opened in this cycle → no-op, `applied` (**the first open wins**; nothing is ever "un-opened").
- Stores `opened_at = server time` (the real unlock time — authoritative) and `opened_device_ts = deviceTs` (the
  device's claim). **Date capsules are never refused for being early**: opening early by moving the clock only
  spoils the user's own surprise; the server just records the real time.
- Trigger capsule not fired yet in this cycle: the open **implies the fire** (§2.3) — it must be armed
  (`deviceTs ≥ armed_at`, else `capsule_not_armed`).
- A date capsule's pending unlock push is cancelled.

### 2.3 `fire` — a trigger capsule matched (at most once per cycle, earliest wins)

`{ id, cycle }`. Sent when the app fires a trigger capsule (RULES.md §9.5): on a live, non-crisis matching
check-in, or when the user taps **"Now"** on the crisis-hold card ("Now counts as the fire"). "Later" on the hold
card sends nothing (the capsule stays armed, no cooldown). "Later" on a normal card sends nothing extra either: the
capsule has fired (cooldown running) and waits, unopened, in the capsule list.
- Unknown → `capsule_not_found`; tombstone → `capsule_deleted`; stale `cycle` → `stale_cycle`; a date capsule →
  `not_a_trigger_capsule`; `deviceTs < armed_at` → `capsule_not_armed`.
- Not fired in this cycle → `fired_at = min(deviceTs, server now)`, `cooldown_until = fired_at + 168 h`.
- Already fired in this cycle (another device fired it offline too) → the **earliest `deviceTs` wins**: if this one
  is earlier, `fired_at` and `cooldown_until` move to it; otherwise no-op. Always `applied`.
- The server records fires; it does **not** enforce the 7-day cooldown (offline devices may legitimately diverge).
  The app enforces it with `globalCooldownUntil = max(cooldown_until)` over all own rows, tombstones included.

### 2.4 `rearm` — "Keep for next time" (trigger capsules only)

`{ id, cycle }` where `cycle` is the cycle that was just opened.
- Unknown / tombstone / stale / date capsule → as above; not opened in this cycle → `capsule_not_opened`;
  already 3 other active trigger capsules → `trigger_capsule_limit` (nothing changes; it stays opened).
- Effect: `cycle += 1`, `armed_at = min(deviceTs, server now)` (no second 24 h wait — the running cooldown still
  holds it), `fired_at`, `opened_at`, `opened_device_ts` cleared. `cooldown_until` is kept. The ciphertext never
  changes.

### 2.5 `delete` — tombstone, always wins

`{ id }`. Allowed at any time, never shows content.
- Unknown id or another user's → silent no-op, `applied` (like check-ins). Already a tombstone → no-op.
- Otherwise the row becomes a **tombstone**: `deleted_at = now()`; `payload_ct`, `unlock_local_date`,
  `trigger_mood_id`, `trigger_quadrant` are erased (timestamps and `cooldown_until` stay — a deleted capsule's fire
  still holds the cooldown). Every later op on it → `capsule_deleted` (incl. a re-sent `seal`).
- After the push commits, its media objects (`<user_id>/capsules/<id>/…`) are deleted (best-effort; leftovers go
  with the account purge) and a pending unlock push is cancelled.

### 2.6 Rejection reasons (capsules)

| reason | when |
|---|---|
| `invalid_payload` | shape/type errors, missing `deviceTs`, both/neither trigger target, `payloadCt` not base64 or > 131,072 chars, `cycle` not an integer ≥ 0 |
| `invalid_tz` | `tz` is not an IANA zone |
| `unknown_op` | an op the entity doesn't support |
| `unknown_mood` | `triggerMoodId` not in the catalogue |
| `invalid_unlock_date` | date outside 7 days – 5 years of the seal's calendar date (or > 5 y + 2 d past the server's today) |
| `trigger_capsule_limit` | seal or re-arm of a 4th active trigger capsule (Free); nothing stored/changed |
| `date_capsule_limit` | a 201st pending date capsule |
| `capsule_sealed` | a `seal` for an existing capsule with different content or unlock metadata |
| `capsule_deleted` | any op except `delete` on a tombstone |
| `capsule_not_found` | `open` / `fire` / `rearm` on an id the server doesn't have for this user |
| `id_conflict` | `seal` with an id owned by another user |
| `stale_cycle` | `open` / `fire` / `rearm` whose `cycle` isn't the current one (another device re-armed it) — pull and adopt the row |
| `not_a_trigger_capsule` | `fire` / `rearm` on a date capsule |
| `capsule_not_armed` | `fire` (or the implied fire of an `open`) with `deviceTs` before `armed_at` |
| `capsule_not_opened` | `rearm` before the current cycle was opened |

Replays follow v1.md (applied → `duplicate`, rejected → the same reason). Rejections are final for that
mutation id: the outbox moves them to the dead-letter table and the next pull brings the server's truth.

## 3. Pull: `public.capsules` (Supabase select-own)

`GET /rest/v1/capsules?select=*&updated_at=gte.<cursor − 5 min>&order=updated_at.asc,id.asc` with the user's
JWT. RLS returns only the caller's rows; clients cannot insert, update or delete (every write is the sync push).
The cursor is the largest `updated_at` seen; pull with a 5-minute overlap (a transaction's `updated_at` is its
start time) and upsert locally by `id` — re-applying a row is harmless. Don't overwrite a capsule that still has
unsent outbox mutations; adopt the server row once they are drained.

| column | type | meaning |
|---|---|---|
| `id` | uuid | capsule id (client UUIDv7) |
| `user_id` | uuid | always the caller |
| `unlock_type` | `date` \| `mood` | |
| `unlock_local_date` | date | date capsules: unlocks at **10:00 local, in the user's current zone**, on this date |
| `trigger_mood_id` | text \| null | mood capsules: the target mood … |
| `trigger_quadrant` | text \| null | … or the target quadrant (`storm`/`rain`/`moonlight`/`sunrise`) |
| `payload_ct` | text \| null | the ciphertext (`null` only on tombstones) |
| `sealed_at` | timestamptz | device time of sealing |
| `armed_at` | timestamptz \| null | mood: may fire from this instant (seal + 24 h, or the re-arm time) |
| `cycle` | int | number of re-arms; send it with `open` / `fire` / `rearm` |
| `fired_at` | timestamptz \| null | mood: fire time in the current cycle (earliest wins) |
| `cooldown_until` | timestamptz \| null | mood: most recent fire + 168 h. **Global cooldown = max over all rows, incl. tombstones** |
| `opened_at` | timestamptz \| null | server time of the first open in the current cycle (the real unlock time) |
| `opened_device_ts` | timestamptz \| null | the device's claimed open time |
| `deleted_at` | timestamptz \| null | tombstone: remove the capsule, its media and its local notification |
| `server_ts` | timestamptz | when the seal reached the server |
| `updated_at` | timestamptz | changes with every applied op — the pull cursor |

States: **sealed** (`opened_at` null; a mood capsule is *arming* until `armed_at`, then *armed*; *fired* once
`fired_at` is set), **opened**, **deleted** (`deleted_at` set). A date capsule is **due** when
`now ≥ unlockAt(unlock_local_date, currentTz)` (RULES.md §9.2).

Account deletion confirmation ("how many sealed ones will be lost"): count rows with `deleted_at is null and
opened_at is null` (local DB, or `select=id&deleted_at=is.null&opened_at=is.null` with `Prefer: count=exact`).

## 4. Shared rules (summary — the normative text is RULES.md §9, vectors in `capsules.json`)

- **Window:** `addDays(sealDate, 7) ≤ unlockLocalDate ≤ addYears(sealDate, 5)`, `sealDate = localDate(sealedAt,
  tz)` (calendar date, no 04:00 shift); `addYears` keeps month/day, Feb 29 → Feb 28.
- **Unlock instant:** the instant the wall clock in the user's **current** zone reads **10:00** on
  `unlockLocalDate` (DST gap → shifted forward by the gap, repeated hour → the earlier). Timezone change → 10:00 in
  the new zone. Unlock passes while the phone is off → opens on next launch.
- **Arming:** `armedAt = sealedAt + 24 h`; after a re-arm, `armedAt` = the re-arm time.
- **Cooldown:** a fire at `t` → `cooldownUntil = t + 168 h`; nothing fires while `checkIn.deviceTs <
  max(cooldownUntil)` over all capsules.
- **Trigger selection** on a saved check-in: only live check-ins (not backfills) — candidates are mood capsules not
  deleted, not fired and not opened in their cycle, `armedAt ≤ checkIn.deviceTs`, matching the mood
  (`triggerMoodId`) or its quadrant (`triggerQuadrant`); pick the oldest by (`armedAt`, `sealedAt`, `id`).
  Crisis-flagged check-in (lexicon hit or "I need help now") → **hold** instead of fire (support sheet first, then
  "A note from past you is waiting. Open now, or later?"; Now = `fire` + `open`; Later = nothing, no cooldown).

## 5. Media: capsule voice and photos (`private-media` bucket)

Same routes, auth, `Cache-Control: no-store`, `503 media_unavailable` and signed-URL behaviour as voice notes
(v1.md "Media: voice notes"). New kinds:

`POST /v1/media/upload-url`
```json
{ "kind": "capsule_voice", "recordId": "<capsule id>", "bytes": 912345 }
{ "kind": "capsule_photo", "recordId": "<capsule id>", "index": 0, "bytes": 1482113 }
```
→ `200 { "path": "<user_id>/capsules/<capsule id>/voice" | "<user_id>/capsules/<capsule id>/photo-<index>", "uploadUrl", "expiresAt" }`

| kind | slots | max `bytes` (ciphertext) |
|---|---|---|
| `voice` (check-in, unchanged) | 1 per check-in | 1,048,576 |
| `capsule_voice` | 1 per capsule (`voice`) | 2,097,152 (2:00 of AAC ≤ 64 kbps + GCM; Plus 10:00 later) |
| `capsule_photo` | 3 per capsule (`index` 0–2 → `photo-0`…`photo-2`) | 4,194,304 (≤ 2,048 px, EXIF/GPS stripped on device) |

- `index` is required (integer 0–2) for `capsule_photo` and must be absent/`null` for the other kinds →
  else `400 invalid_request`. Too big → `400 media_too_large`. The server only sees ciphertext sizes.
- **Sealed means sealed:** before the capsule reaches the server, upload URLs are upserts (retries overwrite).
  Once it is sealed on the server, an **empty** slot still gets an upload URL (a seal pushed while its upload
  lagged), but a slot that already holds an object → **`409 capsule_sealed`** (treat as "already uploaded"). A
  deleted capsule → `409 capsule_deleted`. (Use each URL for one upload; the check happens when the URL is issued.)
- Order (like voice notes): encrypt → upload each slot → push `seal`. If an upload keeps failing, push the seal
  anyway and keep retrying the upload afterwards (allowed while the slot is empty).
- `POST /v1/media/download-url { "path": "<user_id>/capsules/<id>/photo-0" }` works like voice (own prefix only,
  5 min). A tombstoned capsule's paths → `404 not_found`. Download media lazily when the capsule is opened
  (PRD: "Capsule media downloads when opened").
- Deleting a capsule deletes its objects after the push commits (best-effort). Uploads for a capsule that is never
  stored (no capsule row of that id at all) are removed by the daily maintenance sweep once 30 days old, like voice
  (`src/media/orphan-sweep.ts`).

## 6. Push: "Date capsule unlocked" (PRD Notifications)

- The **local notification** scheduled by the app at sealing (10:00 local on the unlock date, rescheduled when the
  device zone changes) is primary and works offline. The server push is the deduplicated **backup**.
- Server: one BullMQ delayed job per pending date capsule (queue `capsule-unlock`, deterministic but opaque job id
  `unlock-<hash of the capsule id>`, data `{ capsuleId }` only) at `unlockAt(unlock_local_date, profile timezone)`;
  the server-only table `capsule_unlock_schedule` records when/in which zone it was scheduled and whether it was
  sent. The zone is re-read when the job runs (a zone to the west → re-delayed to the new 10:00) and a worker sweep
  every 10 minutes re-schedules capsules whose profile timezone changed (a zone to the east → earlier; so a change
  takes effect within ~10 min of `POST /v1/profile`), schedules any capsule whose job was never created (e.g. Redis
  was down at seal time), and sends overdue ones (> 15 min late) whose job was lost.
- Sent only if the capsule is still sealed (not opened, not deleted) and no more than **24 h late**; opening or
  deleting cancels it. **At most 1 per user per unlock date** (several capsules due the same day → one push).
- Payload is content-free: `{ "type": "capsule_unlocked", "id": "<capsule id>" }` + generic copy ("Something you
  sealed is ready to open." / "Meeru daachukunnadi ippudu open cheyyochu."). Never a title, mood, date or text.
- Server interface: `NotificationsService.enqueue(userId, 'capsule_unlocked', capsuleId, { dedupeKey })` →
  queue `notifications`. Until F14 lands the worker's transport is **log-only** (logs the type, never ids); F14
  adds FCM delivery, the 2/day cap with precedence (capsule unlocked first), quiet hours, discreet mode and the
  per-type toggle. The app should suppress a `capsule_unlocked` push for a capsule it has already opened or already
  notified locally (dedupe by `id`).

## 7. Account deletion

`public.capsules` is a personal table: the purge deletes every row (tombstones too), every object under
`<user_id>/` (capsule media live under `<user_id>/capsules/`) and pending unlock jobs. Nothing is kept.

## 8. App checklist (apps/mobile)

- Drift mirror of §3 columns; seal/open/fire/rearm/delete write the local row + an outbox row in one transaction.
- Seal offline; media uploads before the `seal` mutation; local notification at `unlockAt` (current zone).
- Trigger evaluation on device after the crisis sheet and before the room prompt (F1 post-save order) with RULES.md
  §9 — `fire` when the card appears; crisis → hold card; widget check-in → the card waits for the next app open.
- Handle `trigger_capsule_limit` (keep locally, Plus explainer / convert to date), `stale_cycle` / `capsule_deleted`
  (re-pull), `409 capsule_sealed` on upload (done).
- Tombstones from pull → delete the local capsule, its media files and its local notification.
- Never log or send capsule content, titles, dates or targets to analytics (CLAUDE.md).
