# Aura API v1 — F14 Notifications (Milestone A subset)

Extends `contracts/api/v1.md` (same auth, error shape, sync envelope; device registration is v1.md "Devices"). PRD:
`docs/prd/sections/12-notifications.md` (catalogue, global rules 1–9, banned copy, REQ-NTF-01/02),
`15-permissions.md` (asked in context, no re-ask for 30 days), `16-offline.md` (settings: one write path, LWW per
field). Capsule push scheduling: `v1-capsules.md` §6.

**Milestone A ships two pushes:** the daily check-in reminder (`daily_reminder`) and "date capsule unlocked"
(`capsule_unlocked`). Everything else in the catalogue comes later; the cap and precedence already account for it.

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

- Settings › Notifications: master switch, daily reminder on/off + time, date capsule unlocked on/off, quiet hours
  (start/end), discreet mode. Picking a reminder time inside quiet hours asks once: send it anyway
  (`reminderInQuietHours: true`) or keep it quiet. Each change is a local write + an outbox patch.
- OS permission off: a calm note with a link to the phone's Settings. The app never re-asks within 30 days of a decline
  (only "Allow" on the explainer fires the OS prompt; a later re-ask needs 30 days and a meaningful moment).
- Foreground: never a system notification for these pushes — an in-app banner (reminder: only if not checked in
  today; capsule: once per capsule id, not if already opened). Tap / launch from a push: `daily_reminder` → check-in;
  `capsule_unlocked` → the capsule (the capsules feature provides the location; Home until then).
- Copy lint (REQ-NTF-01, `pnpm lint` in server/aura-api): the server catalogue and every app ARB key starting with
  `notif_` (in-app banners, lock-screen copy) must pass. Name any new notification string `notif_…`.
