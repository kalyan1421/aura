# Aura API v1 — Quiet Together and the Lantern Hour wind-down (F16)

Companion to `contracts/api/v1.md` (same base URL, auth, error shape and pending-deletion guard) and
`contracts/api/v1-rooms.md` (DS-10 rules, report reasons, blocks). Server: `server/aura-api/src/quiet` (sessions) and
`server/aura-api/src/rooms/wind-down*.ts` (the wind-down); schema `supabase/migrations/20261005000027_quiet_together.sql`.
App: `apps/mobile/lib/src/features/quiet` and `apps/mobile/lib/src/features/rooms/wind_down*.dart`.
PRD: `06b-features-social.md` "F16 Quiet Together" + "Lantern Hour wind-down (Milestone C)" (REQ-QUIET-01…07),
`06d` F15 (one pacer engine, base stems), `14-states.md` "Quiet Together (F16)", `09-technical-constraints.md`
(no per-member Presence), `15-permissions.md` (background audio, no microphone), `17-accessibility.md`
REQ-A11Y-11/12/15/16.

A drop-in session where people study, read or rest "together": **a count, a shared sound and gestures, nothing else**.
No member list, no pseudonyms, no silhouettes, no mood, no text, no user audio. Leaving costs nothing.

## 0. Conventions

- Every route needs `Authorization: Bearer <Supabase access token>`; `401 unauthorized` without one;
  `403 account_deletion_pending` during a deletion grace period; `409 profile_required` before onboarding.
- Errors: `{ "code": "snake_case", "message": "…" }`. Responses carry `Cache-Control: no-store`.
- Instants are ISO 8601 UTC. Millisecond epochs (`…Ms`) are **server clock**; `serverTimeMs` on every session
  response lets the phone estimate its clock offset (take the sample with the shortest round trip). The shared
  sound, the focus rhythm and the wind-down pacer all run from `t0Ms` on that corrected clock.
- Online only (PRD 16 Offline). Offline the app shows "Quiet Together needs a connection. Sanctuary works offline."
  and makes no call. The shared sound itself plays from the phone's own cache.
- Sanctioned accounts: `/v1/quiet/join` and the heartbeat answer `403 rooms_suspended` / `403 account_closed` exactly
  like `/v1/rooms*` (the same room-access sanctions cover every stranger surface). Reporting keeps working for
  suspended accounts ("help is never locked").
- Community guidelines (REQ-SAFE-04) come before any stranger surface: `409 guidelines_required` + `version`, as in
  rooms §1.1.
- **Kill switches, per region** (`public.feature_flags`, `GET /v1/config`; PRD 19 "from C Quiet Together and the
  Lantern Hour wind-down, per region"):
  - `quiet_enabled` — off, or the caller's region listed in `payload.pausedRegions` → `POST /v1/quiet/join` answers
    `503 quiet_paused`; sessions already running finish their block (the heartbeat at the block's end answers
    `503 quiet_paused` instead of moving you on).
  - `lantern_wind_down_enabled` — off, or the room's region in `payload.pausedRegions` → no wind-down is offered
    (`windDown: null`) and joining answers `503 wind_down_paused`.
  A missing flag counts as on. The app hides entries while a flag is off; the server decides.

### DS-10 / REQ-QUIET-01: counts only (tested on every payload: `test/e2e/quiet.e2e-spec.ts` "REQ-QUIET-01 payload scan")
No response and no realtime payload here ever contains a **member list** (even a pseudonymous one), a pseudonym, a
`member_id`, an account id (`user_id` / JWT `sub`), an email, a date of birth, an age, anything that says whether
someone is under 18, a mood or a silhouette — about anyone, including the caller. Other people exist only as a
**number** ("12 here", "3 winding down"). `quiet_members.member_id` stays on the server (rate limits, reports).
Gesture broadcasts never carry the sender.

### Enums
| Name | Values |
|---|---|
| `QuietMode` | `study` · `read` · `rest` |
| `GestureType` | the 8 F5 presets: `warm_tea` · `light_a_candle` · `hug` · `me_too` · `soft_rain` · `stargaze` · `deep_breath` · `youre_not_alone` |
| `WindDownState` | `soon` (Lantern Hour, before the wind-down's start) · `open` (it is running; joinable) |

### Shared shapes
```jsonc
// QuietSession — everything a phone needs; no people in it.
{
  "sessionId": "uuid",
  "mode": "study",
  "t0": "2027-03-10T13:30:00.000Z",   // block start: on the hour of the timezone region's clock (19:00 IST here)
  "t0Ms": 1804685400000,              // the shared start for the sound and the focus rhythm
  "endsAt": "…", "endsAtMs": 1804689000000, // t0 + 60 min; the next block follows (see §1.2)
  "count": 12,                        // live people in this session, including you ("12 here"); ≥ 1
  "soundscape": {                     // base Sounds stems only (never a Plus stem, never a paywall)
    "seed": 184467,
    "stems": [ { "id": "brown_noise", "gain": 0.55 }, { "id": "rain", "gain": 0.3 } ]
  },
  "rhythm": { "focusMin": 25, "breakMin": 5 },   // study only (else null); OFF on the phone until the person turns it on
  "gestures": { "minIntervalMs": 10000, "perHour": 20 },
  "heartbeatMs": 30000,
  "realtime": { "topic": "quiet:<sessionId>" },
  "serverTime": "…", "serverTimeMs": 1804687800123
}
```

**Shared sound (REQ-QUIET-03).** Each phone plays the stems from its own cache, positioned at
`position = (serverNowMs − t0Ms) mod loopLength` for every stem, so two phones that joined 10 minutes apart hear
the same moment (target ±1 s). Nothing plays until the person taps "Play the shared sound"; volume is per person.
There is no audio upload, no streaming between users and no microphone anywhere. A stem whose recording is not on
the phone yet shows "The shared sound needs a one-time download." (the session works silently meanwhile).

**Focus rhythm (REQ-QUIET-05).** Off by default (a phone-side choice; nothing is sent). When on it follows the block:
focus `:00–:25`, break `:25–:30`, focus `:30–:55`, break `:55–:00` (from `t0`, `focusMin`/`breakMin`), so everyone's
breaks line up. The next change is shown as a clock time ("Break at 9:25"), never as a countdown.

## 1. Sessions

### 1.1 `POST /v1/quiet/join` → `200 { "session": QuietSession }`
Body `{ "mode": QuietMode, "timezone"?: IANA }` (strict: unknown fields → `400 invalid_request`). `timezone`
(else the profile's) picks the timezone region (the F5 regions, by UTC offset now).

- **Drop-in, time-boxed.** Sessions are 60-min blocks on the hour of the region's clock; joining at :40 joins the
  current block (REQ-QUIET-01: the response carries the count, so it shows within 1 s).
- **Placement:** partition `mode × region`, up to 50 people per session. A region with fewer than 3 live people in
  this mode's block merges into the busiest region (ties → `south_asia`, as in F5). Inside the partition the fullest
  session with room is used; more sessions open as needed. **A blocked pair (either direction) is never placed in
  the same session.** Not split by language.
- Idempotent: already in a live session of this mode and block → the same session. Joining another mode (or a new
  block) silently leaves the older membership.
- Errors: `400 invalid_request`; `503 quiet_paused`; plus §0.

### 1.2 `POST /v1/quiet/sessions/:sessionId/heartbeat` → `200 { "session": QuietSession }`
Every `heartbeatMs` (30 s) while the screen is open: keeps you in the count (a person counts while seen in the last
90 s). **When the block has ended** the server places you in the next block of the same mode (same rules as §1.1)
and answers with that session: a different `sessionId` means "switch channel, re-align the sound". The 14-states
line is "The next session starts at 10:00." — no countdown. `404 not_found` when you are no longer in that session
(you left, joined elsewhere, or went quiet for 10 min): the phone simply joins again, silently. `503 quiet_paused`
at a block's end while the kill switch is off for your region.

### 1.3 `POST /v1/quiet/sessions/:sessionId/leave` → `204`
**Leaving costs nothing (REQ-QUIET-04):** no "left early", nothing withered, nothing earned for staying. Others see
only the count change. No Starlight, streak, keepsake or stored record depends on time in a session. Idempotent;
unknown ids are a no-op.

### 1.4 `POST /v1/quiet/sessions/:sessionId/gestures` → `202 { "gestureId", "at" }`
Body `{ "type": GestureType }` — **strict: any other field (text, a member, a target) → `400 invalid_request`**
(REQ-QUIET-02: gestures go to the whole session, never to a person, and there is no text anywhere). Everyone live
sees an unnamed animation ("Someone lit a candle"), rendered in each viewer's language.
- Limits `[ASSUMPTION]`: 1 per 10 s (per account), 20 per session hour. Over a limit → dropped silently (the sender
  still sees `202`). 3 limit hits in 24 h → the account's gestures are shadow-muted for 24 h and a spam-lane item is
  queued for a moderator (the F5 rule; `auto_signal = gesture_flood`). Shadow-muted gestures answer like delivered.
- Errors: `404 not_found` (not a current member); `409 block_over` (the block ended: heartbeat first).

### 1.5 `POST /v1/quiet/sessions/:sessionId/reports` → `201` new, `200` repeat
"Report a problem here" (the session menu). Body `{ "reason": 1–9, "note"?: string ≤ 500 }` →
`{ "reportId", "showHelplines" }`. Reasons, lanes, SLA and the daily limit (`429 report_limit`, never for reason 1)
are exactly rooms §2.1. Nobody is shown, so there is **no per-person block or mute**; "Hide gestures" is a phone-side
setting for yourself. The session's recent gesture log (the last hour: member ids, types, times) is snapshotted into
the evidence store (180 days) with the accounts that sent gestures as its subjects. Works for 7 days after you left.
Anyone involved under 18 → Minors & grooming lane, invisibly.

## 2. Lantern Hour wind-down (rooms; REQ-QUIET-07)

At **22:30 on the region clock** `[ASSUMPTION]` (inside Lantern Hour), open rooms offer "Wind down together" for
**20 minutes** `[ASSUMPTION]`. Members who opt in hear one ambient track of base stems played locally from the
common server `t0`, while the F15 pacer shows breathing cues (Calm 4 / 6) and a few preset text cues. No user voice,
no narration; silent until the member taps; gestures keep working (room gestures, rooms §1.5); leaving costs
nothing. **The room sees only "N winding down".**

```jsonc
// WindDown
{
  "state": "open",                    // or "soon" (Lantern Hour, before startsAt)
  "startsAt": "…", "startsAtMs": 1804699800000,  // t0: the pacer, the text cues and the sound run from here
  "endsAt": "…", "endsAtMs": 1804701000000,      // t0 + 20 min
  "count": 3,                         // members winding down and live now (never who)
  "joined": false,                    // you (only ever about the caller)
  "pacer": { "pattern": "calm", "inhaleMs": 4000, "exhaleMs": 6000 },
  "soundscape": { "stems": ["rain", "wind", "chimes"] },  // base stems, bed first; the phone applies the F15
                                                         // night wind-down envelope (thins out to silence at 20 min)
  "cues": [ { "atS": 0, "key": "arrive" }, { "atS": 120, "key": "day_quieter" }, … ]  // preset keys, localized on the phone
}
```

### 2.1 `GET /v1/rooms/:roomId/wind-down` → `200 { "windDown": WindDown | null, "serverTime", "serverTimeMs" }`
Current members of a room that isn't a memory (else `404 not_found`). `null` outside the room's Lantern Hour,
after the wind-down ended, or while the kill switch is off for the room's region.

### 2.2 `POST /v1/rooms/:roomId/wind-down` → `200 { "windDown", "serverTime", "serverTimeMs" }`
Opt in (idempotent). Counts as being here (liveness). Errors: `404 not_found`; `409 wind_down_closed` (not
open now); `503 wind_down_paused`.

### 2.3 `DELETE /v1/rooms/:roomId/wind-down` → `204`
Opt out (idempotent). Leaving the room also ends it. No copy about stopping early, ever.

### 2.4 Realtime: `wind_down` on `room:<roomId>`
`{ "state": "soon" | "open" | "ended", "count", "at" }` when it starts, ends or the count changes (joins, leaves,
and the lifecycle tick for people going quiet). A room total: no member id, pseudonym or per-member value.

Text cue keys (the phone skips a key it doesn't know): `arrive`, `day_quieter`, `shoulders`, `nothing_to_do`,
`slower`, `rest_well`.

## 3. Realtime `quiet:<sessionId>` — Broadcast, current members only, server → client

Authorised by RLS on `realtime.messages` (`public.quiet_topic_allowed`): a current (not left) member of the session,
until the block ends (+ 2 min). **Clients never write** (no client-to-client events, no Presence: PRD 09 "no
per-member Presence").

| Event | Payload | When |
|---|---|---|
| `count` | `{ "count", "at" }` | every 30 s while anyone is live (the worker tick) |
| `gesture` | `{ "gestureId", "type", "at" }` | a delivered gesture; never the sender. The sender's own phone already animated it (dedupe by `gestureId`) |

Delivery is best-effort; the heartbeat is authoritative. When the channel drops the app shows "Reconnecting…" and
the shared sound keeps playing locally.

## 4. Server behaviour the app should know

- **Retention:** memberships and the gesture log are purged with their session 7 days after the block ends
  `[ASSUMPTION]`; a reported session is in the evidence store first. Nothing else is stored.
- **Account deletion:** `quiet_members` (and through it the gesture log) goes with the account (`account-purge.ts`).
- **Analytics:** none from the app (no analytics SDK in v1). Counts shown to users come from the server counter.
- **Codes introduced here:** `quiet_paused` (503), `wind_down_paused` (503), `wind_down_closed` (409),
  `block_over` (409).
