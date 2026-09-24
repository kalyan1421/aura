# Aura API v1 — F14 Notifications (Milestone A subset)

Extends `contracts/api/v1.md` (same auth, error shape, sync envelope; device registration is v1.md "Devices"). PRD:
`docs/prd/sections/12-notifications.md` (catalogue, global rules 1–9, banned copy, REQ-NTF-01/02),
`15-permissions.md` (asked in context, no re-ask for 30 days), `16-offline.md` (settings: one write path, LWW per
field). Capsule push scheduling: `v1-capsules.md` §6.

**Milestone A ships three pushes:** the daily check-in reminder (`daily_reminder`), "date capsule unlocked"
(`capsule_unlocked`) and "Tell me when they open" (`rooms_pool_open`, §5). Everything else in the catalogue comes
later; the cap and precedence already account for it.

## 1. Settings: sync entity `notification_prefs`

Written only through `POST /v1/sync/push`; read back with Supabase select-own on `public.notification_prefs`.

```json
{ "id": "<mutation uuidv7>", "entity": "notification_prefs", "op": "upsert",
  "deviceTs": "2026-10-08T20:15:00+05:30", "localDay": "2026-10-08", "tz": "Asia/Kolkata",
  "payload": { "reminderEnabled": true, "reminderTime": "20:00" } }
```

- `op` is `upsert` only (anything else → `unknown_op`). `deviceTs` is **required** (the LWW clock) → else
  `invalid_payload`. `localDay` / `tz` are accepted and ignored. No record id: one row per account.
- `payload` is a **patch**: any non-empty subset of the fields below (unknown keys are ignored, so a newer app can add
  fields). Empty patch, wrong types, or a time that isn't `HH:MM` (24 h, `00:00`–`23:59`) → `invalid_payload`.

| field | type | default | meaning |
|---|---|---|---|
| `enabled` | bool | `true` | master switch (Settings › Notifications) |
| `reminderEnabled` | bool | `false` | daily check-in reminder; off until the person picks it (the post-check-in explainer turns it on at the suggested `20:00` `[ASSUMPTION]`) |
| `reminderTime` | `"HH:MM"` \| null | null | local time in the profile zone |
| `reminderInQuietHours` | bool | `false` | the one-time confirmation: send the reminder even though its time is inside quiet hours (night shifts, rule 1) |
| `capsuleUnlocked` | bool | `true` | "date capsule unlocked" pushes |
| `quietStart` / `quietEnd` | `"HH:MM"` | `23:00` / `08:00` | quiet hours `[start, end)`, may wrap midnight; `start = end` means none |
| `discreet` | bool | `false` | every push reads "Aura · You have a gentle update" (rule 4) |

**Conflicts (16-offline "settings: last-write-wins per field").** The server keeps, per field, the device time of its
last applied write (`field_ts`, clamped to server time so a fast clock can't pin a field). A patch field older than
the stored stamp is ignored; newer (or equal: later received wins) is applied. The result is always `applied` (a fully
stale patch changes nothing). The app should send only the fields the person changed, so two phones editing
different settings offline both win.

Every applied change re-plans the next daily reminder (`reminder_next_at`) in the **profile** timezone, inside the
push transaction.

**Pull** — `GET /rest/v1/notification_prefs?select=*` (select-own; clients never write). Columns the app reads:
`enabled, reminder_enabled, reminder_time ("HH:MM:SS"), reminder_in_quiet_ok, capsule_enabled, quiet_start,
quiet_end, discreet, field_ts` (`{ "<payloadField>": "<ISO>" }`), `updated_at`. Server-managed, informational:
`reminder_next_at`, `reminder_tz`, `sent_day`, `sent_types` (today's push types — type names only). No row = all
defaults. Merge per field: take the server value when its `field_ts` is newer than the local change's stamp.

## 2. Pushes

Payload (FCM `data`), content-free: `{ "type": "daily_reminder" }` or `{ "type": "capsule_unlocked", "id": "<capsule
id>" }`. Never a mood, quadrant, room theme, title, text, date, pseudonym or streak (rule 3).

| type | when | Android channel | copy (en) | te-Latn | collapse key |
|---|---|---|---|---|---|
| `daily_reminder` | the person's time, daily; **skipped** if a live check-in exists for that Aura day | `reminders` | "A quiet minute for you. How's today feeling?" | "Mee kosam oka quiet minute. Ee roju ela anipistondi?" | `daily_reminder` |
| `capsule_unlocked` | 10:00 local on the unlock date (v1-capsules.md §6) while the capsule is sealed; max 1/day | `capsules` | "Something you sealed is ready to open." | "Meeru daachukunnadi ippudu open cheyyochu." | the unlock date's notice id (below) |
| `rooms_pool_open` | once, when a language pool the person asked about opens (§5) | `rooms` ("Rooms & Lantern Hour") | "Hindi and Hinglish rooms are open now." | "Hindi, Hinglish rooms ippudu modalayyaayi." | `rooms_pool_open` |

- Copy is rendered server-side in the profile's `ui_locale` (`en`, `te`, `te-Latn`; `hi` / `hi-Latn` → English until
  beta). Discreet mode: "You have a gentle update" (te-Latn "Meeku oka gentle update undi") for every type. There is no
  title: the OS shows "Aura".
- **Android:** notification message, `channel_id` per type, `visibility: PRIVATE` (a secure lock screen shows the
  system's generic public version — app name, contents hidden), `tag` = the collapse key, `ttl` (reminder 2 h, capsule
  24 h), high priority. **iOS:** alert with the same line, `apns-collapse-id` = the collapse key, `apns-expiration`,
  `thread-id` = the channel. Hidden previews use the system's generic placeholder.
- **Capsule notice id** — shared with the app's offline "ready to open" notice, which is one per unlock date
  (`features/capsules/capsule_notifications.dart` `capsuleNoticeId(LocalDay)`): `0x18000000 + days since 1970-01-01`
  of the unlock date. Its decimal string is the push's `apns-collapse-id` and Android `tag`. iOS: the push and the local
  notice share a request identifier, so one replaces the other. Android: the app's push handler (foreground, and the
  background isolate FlutterFire starts for every message) cancels the local notice with that id, so the person sees
  one. In the foreground the app asks the capsules feature (`shouldShowServerPush`) and shows an in-app banner instead.
  The key reveals nothing the delivery doesn't: the push is sent at 10:00 on that very date.

## 3. Server rules (worker `notifications` queue)

Applied at delivery (`src/notifications/policy.ts`, all unit-tested), in order: profile exists → **no scheduled
deletion** → at least one registered install (signed-out installs have no token) → master switch → type toggle →
not stale (reminder 2 h, capsule 26 h) → type-specific (reminder: no check-in this Aura day; capsule: still sealed) →
each type at most once per Aura day → **quiet hours** (the capsule push waits for their end, + up to 10 min jitter;
the reminder is skipped unless `reminderInQuietHours`) → **cap: 2 pushes per Aura day** across types with precedence
capsule unlocked > daily reminder > gestures > Lantern Hour > wind-down > habit nudge > welcome back (a lower push
yields the last slot when a higher one is still due later that day; dropped items stay in-app).

- The day's slot is taken atomically in SQL (`notification_prefs.sent_day` / `sent_types`); given back when no install
  accepted the push. Temporary FCM failures (429/5xx/network) retry the job (BullMQ backoff); tokens FCM reports as
  `UNREGISTERED` are deleted.
- Daily reminder schedule: `reminder-sweep` every minute claims rows with `reminder_next_at <= now()`, moves them to the
  next day and enqueues one push (deduplicated per user + Aura day; > 2 h late → not sent). `reminder-reconcile`
  every 10 min re-plans after a profile timezone change (the app re-sends `POST /v1/profile` when the device zone
  changes) and repairs missing plans. Offline check-ins the server hasn't seen yet can't suppress that day's reminder
  (accepted: the reminder is gentle and the app ignores it in the foreground when already checked in).
- Smart timing (rule 7) is P1 — not built. The capsule push "at reminder time" option is a follow-up (10:00 now).
- Analytics (`notification_sent`, 18+ only) is a TODO hook in `NotificationDelivery`; nothing is sent today.

**Configuration (worker):** `FCM_SERVICE_ACCOUNT_JSON` (the service-account JSON, or base64 of it) or
`FCM_SERVICE_ACCOUNT_FILE` / `GOOGLE_APPLICATION_CREDENTIALS` (a path); optional `FCM_PROJECT_ID`. Unset or unusable →
log-only transport (logs the type only), the worker keeps running.

## 4. App behaviour (apps/mobile `features/push`, Settings › Notifications)

- Settings › Notifications (after Account): master switch, daily reminder on/off + time, date capsule unlocked on/off,
  quiet hours (start/end), discreet mode. Picking a reminder time inside quiet hours asks once: send it anyway
  (`reminderInQuietHours: true`) or keep it quiet. Each change is a local write + an outbox patch.
- The post-first-check-in explainer shows the evening time (suggested 20:00, changeable) and a "Keep them discreet"
  choice (rule 4). "Allow" → the OS prompt and `{reminderEnabled: true, reminderTime}`; the discreet choice is saved
  whatever the answer (after "Not now" iOS still delivers capsule notices quietly).
- OS permission off: a calm note with a link to the phone's Settings. The app never re-asks within 30 days of a decline
  (only "Allow" on the explainer fires the OS prompt; a later re-ask needs 30 days and a meaningful moment).
- Foreground: never a system notification for these pushes — an in-app banner (reminder: only if not checked in
  today; capsule: once per capsule id, not if already opened). Tap / launch from a push: `daily_reminder` → check-in;
  `capsule_unlocked` → the capsule (the capsules feature provides the location; Home until then).
- Copy lint (REQ-NTF-01, `pnpm lint` in server/aura-api): the server catalogue and every app ARB key starting with
  `notif_` (in-app banners, lock-screen copy) must pass. Name any new notification string `notif_…`.

## 5. "Tell me when they open": sync entity `room_pool_waitlist` → push `rooms_pool_open`

PRD 06b F5 (Hindi + Hinglish rooms stay off until moderation is ready) and 14-states ("Join English room" / "Tell me
when they open"). Migration 20261005000019; `src/notifications/pool-waitlist.ts`.

```json
{ "id": "<mutation uuidv7>", "entity": "room_pool_waitlist", "op": "upsert",
  "deviceTs": "2026-10-08T20:15:00+05:30", "localDay": "2026-10-08", "tz": "Asia/Kolkata", "payload": { "pool": "hi" } }
```

- `op` `upsert` (a repeat keeps the first request) or `delete` (withdraw). `pool`: `hi` only (the pools that open
  later) → else `invalid_payload`. Stored in `public.room_pool_waitlist` — server-only (no select-own), purged with the
  account.
- **Worker** `pool-open-sweep` (every minute, `notifications` queue): while the pool's flag is on (`hi` →
  `feature_flags.rooms_pool_hi`), each waiting row is claimed (oldest first, `SKIP LOCKED`), **deleted**, and one
  `rooms_pool_open` push enqueued in the same transaction (Redis refusing → the batch rolls back and waits for the next
  sweep; BullMQ drops a duplicate after a commit failure). **Once:** the opt-in is used up; flipping the flag off and on
  again sends nothing more, and someone who taps again while it's off is told at the next opening. No push for an
  account with a scheduled deletion, a missing profile, or an active `account_ban` / `social_ban` / `rooms_pause`.
- **Delivery** follows §3: master switch (no type toggle of its own — the tap is the opt-in), a registered install
  (i.e. OS permission given), quiet hours (deferred to their end), once per Aura day, and the 2/day cap — when capped
  it **waits for the next Aura day** instead of being dropped; given up after 72 h. Re-checks the flag: a pool closed
  again meanwhile sends nothing. Android channel `rooms` ("Rooms & Lantern Hour", muteable in phone Settings), TTL 24 h,
  payload `{ "type": "rooms_pool_open" }` (no id).
- **App:** the pool screen's "Tell me when they open" keeps the tap on the phone and queues the mutation; a foreground
  push shows "Hindi and Hinglish rooms are open now." with "See rooms"; a tap opens Rooms.

## 6. Milestone B (F14 "the rest" + the opt-in wind-down reminder): settings

Migration 20261005000023; `src/notifications/{schedules,welcome-back,gestures-push,kind-facts,prefs-milestone-b}.ts`.
PRD 12 catalogue rows shipped here: habit nudge, gestures received, Lantern Hour, wind-down reminder (REQ-NTF-04),
welcome back. (The trial-ending reminder and the billing-issue banner belong to F12 Billing; the Breath Ripples invite
is an in-room banner of F7; mood-trigger capsule, moderation outcome and crisis follow-up are in-app only — §10.)

New `notification_prefs` patch fields (same entity, same per-field LWW as §1):

| field | type | default | column | meaning |
|---|---|---|---|---|
| `gestures` | bool | `true` | `gestures_enabled` | "Gestures received" pushes |
| `lanternHour` | bool | `false` | `lantern_opt_in` | Lantern Hour (opt-in) |
| `windDownEnabled` | bool | `false` | `wind_down_enabled` | wind-down reminder (opt-in; the app turns it on with a time, suggested `22:30` `[ASSUMPTION]`) |
| `windDownTime` | `"HH:MM"` \| null | null | `wind_down_time` | local time in the profile zone |
| `windDownInQuietHours` | bool | `false` | `wind_down_in_quiet_ok` | rule 1's one-time confirmation for a wind-down time inside quiet hours |
| `welcomeBack` | bool | `true` | `welcome_back_enabled` | "Welcome back" pushes |
| `habitNudges` | `{ "<habit uuid>": "HH:MM" }` | `{}` | `habit_nudges` | habit nudges (opt-in per habit; ≤ 16; ids only, never a name). **One LWW field: send the whole map.** |

Every applied change re-plans the user-timed kinds (§7) inside the push transaction. The pull adds these columns.

## 7. User-timed pushes: `wind_down_reminder`, `lantern_hour`, `habit_nudge`

`public.notification_schedule` (server-only): one row per user and kind with the next instant, planned in the profile
zone. Worker `schedule-sweep` (every minute) claims due rows, moves each to its next instant and enqueues one push
(dedupe per user + kind + Aura day; habit nudges per time); more than 2 h late (Lantern Hour: 30 min), or planned in a
zone the profile no longer has → moved on without a push. `schedule-reconcile` (every 10 min) plans missing rows,
re-plans after a profile zone change, deletes unwanted rows.

| type | when | skipped when | quiet hours | stale after | channel | copy (en / te-Latn) |
|---|---|---|---|---|---|---|
| `wind_down_reminder` | the chosen time | a `sanctuary_sessions` record finished since 18:00 of that Aura day `[ASSUMPTION]` ("Sanctuary already opened that evening": the server only knows finished activities; the app also keeps the in-app notice quiet when Sanctuary was opened on the phone) | skipped, unless `windDownInQuietHours` | 2 h | `reminders` | "A few quiet minutes before sleep, whenever you want them." / "Padukune mundu konchem quiet time? Aura ikkade undi." |
| `lantern_hour` | Lantern Hour start on the person's **region clock** (`matching_config.lantern_start`, 21:00; e.g. 19:30 in Dubai) | already joined a room this Aura day; `rooms_enabled` off; an active ban / social ban / rooms pause | skipped | 1 h | `rooms` | "Lantern Hour is on. Others are here tonight." / "Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru." |
| `habit_nudge` | each nudged habit's time; **one push a day**, bundling the habits due then | every due habit is logged for the Aura day (or inactive/deleted) | skipped | 2 h | `reminders` | exactly one preset habit due → its own line ("Small one: a glass of water?" for hydrate, …); otherwise "A small habit or two, whenever you're ready." A custom habit's name never appears. |

Payload `{ "type": "<type>" }` (no id). Wind-down and Lantern Hour are opt-in and off until chosen (REQ-NTF-04).

## 8. `welcome_back`

"7 days inactive; again at day 21 · 2 per absence, then silence". **Inactive = the account wrote nothing**: no sync
push and no profile / device / room call. Triggers on `sync_mutations` and `device_installs` keep
`public.notification_activity.last_active_at` and reset the absence's count; Aura keeps no other "last seen".
`welcome-back-sweep` (every 15 min) sends the 1st push once the absence reaches 7 days and the 2nd at 21 days (≥ 7 days
after the 1st), in the early evening 18:00–21:00 local `[ASSUMPTION]`; absences over 60 days are left alone. The claim
is recorded before the enqueue (never twice). Delivery skips it if the person wrote anything after it was requested;
quiet hours → deferred; lowest precedence, capped → next day. Channel `reminders`, payload `{ "type": "welcome_back" }`,
copy "No catch-up needed. Aura is here whenever you want a quiet minute." / "Catch-up emi avasaram ledu. Meeku eppudu
kaavalante appudu Aura ikkade untundi."

## 9. `gestures_received`

`gestures-sweep` (every 5 min) reads gestures sent TO a member (never room-wide ones, never dropped ones) in the last
6 h. A (recipient, room) pair is ready once one of today's gestures is ≥ 10 min old (a burst travels as one push); a row
in `public.gesture_push_log` (recipient, room, Aura day) is written with the enqueue in one transaction → **at most one
push per room per day**. Payload `{ "type": "gestures_received", "id": "<room id>" }` (opaque; the app opens the room).
Delivery counts the distinct senders itself: 1 → "Someone in your room sent you warmth." / "Mee room lo okaru meeku
warmth pampaaru."; n → "{n} people in your room sent you warmth." / "Mee room lo {n} mandi meeku warmth pampaaru.".
Never a pseudonym, gesture type, theme or mood. Skipped for a ban / social ban / rooms pause; inside quiet hours dropped
(the room shows the gestures); stale after 6 h; channel `rooms`. The per-type daily log makes it one room's push a day
in practice.

**Precedence (all of §7–§9):** each counts toward the 2/day cap; a lower kind yields the last slot to a higher one still
expected later that Aura day (a due capsule, a planned daily reminder without a check-in yet, a planned Lantern Hour /
wind-down / habit nudge). **Copy lint:** every template also passes the "calm, not treatment" claim list (`binaural`,
`heal*`, `cure`, `treat*`, `therapy`, `clinically`, `better sleep`, `fall asleep`, `insomnia`, …; reason
`health_claim`) — REQ-NTF-04 "no copy promises better sleep".

## 10. App (apps/mobile)

- Settings › Notifications adds: gestures, Lantern Hour, wind-down (on/off + time, with the same one-time quiet-hours
  confirmation), welcome back, and **Habit nudges** (per habit: a time or off). Sanctuary › Sounds' night wind-down card
  offers "Remind me at …" for the wind-down reminder (same setting).
- Android channels unchanged: `reminders` (daily, wind-down, habit nudges, welcome back), `capsules`, `rooms` ("Rooms &
  Lantern Hour": pool open, Lantern Hour, gestures).
- Tap: `wind_down_reminder` → Sanctuary › Sounds (nothing plays until a tap, REQ-SAN-09); `lantern_hour` → Rooms;
  `gestures_received` → that room (Rooms when it's gone); `habit_nudge` / `welcome_back` → Home. Foreground: a calm in-app
  notice (`notif_*` strings, copy-linted); the wind-down one not when Sanctuary was opened on this phone that evening.
- **Crisis follow-up** (PRD 12: "Support sheet shown 12–72 h ago · in-app card on next open only · once per event"):
  entirely on the phone — the time the support sheet was shown is kept in the local encrypted store (never synced,
  never logged); the next app open 12–72 h later shows one dismissible card on Home with "I need help now" and the
  locale helplines. No push, ever.
