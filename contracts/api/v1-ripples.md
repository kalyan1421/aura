# Aura API v1 — Breath Ripples (F7)

Companion to `contracts/api/v1.md` (same base URL, auth, error shape and pending-deletion guard) and
`contracts/api/v1-rooms.md` (DS-10 rules, report reasons, blocks). Server: `server/aura-api/src/ripples`; schema
`supabase/migrations/20261005000021_breath_ripples.sql`. App: `apps/mobile/lib/src/features/ripples`.
PRD: `06b-features-social.md` "F7 Breath Ripples" (+ shared stranger-surface rules), `06d` F15 (one pacer engine),
`14-states.md` "Breath Ripples lobby and session", `17-accessibility.md` REQ-A11Y-07, `09-technical-constraints.md`
"Realtime protocol budget".

A 3-minute co-breath with 1 to 3 strangers: 10 s settle-in, 16 cycles of inhale 4 s / exhale 6 s, 10 s fade-out.
No score, number, countdown, leaderboard, voice or text. Nothing one player does can hurt the others.

## 0. Conventions

- Every route needs `Authorization: Bearer <Supabase access token>`; `401 unauthorized` without one;
  `403 account_deletion_pending` during a deletion grace period; `409 profile_required` before onboarding.
- Errors: `{ "code": "snake_case", "message": "…" }`. Responses carry `Cache-Control: no-store`.
- Instants are ISO 8601 UTC. Millisecond epochs (`…Ms`) are **server clock**; `serverTime` on every match / session
  response lets the app estimate its clock offset (take the sample with the shortest round trip).
- Online only (PRD 16 Offline). Offline the app shows "Breathing together needs a connection. Breathe solo instead?"
  and makes no call.
- Sanctioned accounts: `/v1/ripples/match` and the session routes answer `403 rooms_suspended` / `403 account_closed`
  exactly like `/v1/rooms*` (the same room-access sanctions cover every stranger surface). Reporting and blocking a
  light keep working for suspended accounts ("help is never locked").
- Community guidelines (REQ-SAFE-04) come before any stranger surface: `409 guidelines_required` + `version`, as
  in rooms §1.1.
- Kill switches (`public.feature_flags`, `GET /v1/config`): `ripples_enabled` off → `POST /v1/ripples/match`
  answers `503 ripples_paused` (sessions already playing finish); `ripples_echoes` off → no echo is recorded or
  seated.

### DS-10: the stranger boundary (tested: `test/e2e/ripples.e2e-spec.ts` "DS-10 contract")
No response here and no realtime payload ever contains an account id (`user_id` / JWT `sub`), an email, a date of
birth, an age or anything that says whether someone is under 18 — about anyone, including the caller. Other
people appear only as a **seat number** (1–4, session-scoped) with a `kind` and, for humans, a pseudonym. Seat
member ids (`ripple_seats.id`) stay on the server (event log, reports).

### Enums
| Name | Values |
|---|---|
| `Entry` | `quick` (Home, one global queue, fresh pseudonym) · `room` ("Breathe together" in a room, room pseudonym) |
| `SeatKind` | `human` · `echo` (a labelled recording of someone who breathed here before) · `guide` (the pacer itself, never presented as a person) |
| `StartRule` | `full` (4 humans) · `early` (8 s with ≥ 2 humans) · `timeout` (20 s, whoever waits) · `invite` (room invite: 4 humans, or 20 s) |

### Shared shapes
```jsonc
// Seat — one light on the ocean.
{ "seat": 2, "kind": "human", "label": "Quiet Comet" }            // humans: their pseudonym
{ "seat": 3, "kind": "echo", "label": null, "trace": [0, -2, 1, null, …] } // echoes: pacer-relative offsets, 50 ms steps
{ "seat": 4, "kind": "guide", "label": null }                     // guides: breathe exactly on the pacer

// Session — everything a phone needs to run the pacer in phase with the others.
{
  "sessionId": "uuid",
  "entry": "quick",
  "roomId": null,                     // the room's id for a room session (the caller is a member)
  "startRule": "early",
  "t0": "2026-10-08T15:30:00.000Z",   // start of the settle-in, server clock
  "t0Ms": 1791466200000,
  "settleMs": 10000, "inhaleMs": 4000, "exhaleMs": 6000, "cycles": 16, "fadeMs": 10000,
  "pacerVersion": 1,
  "endsAt": "…", "endsAtMs": 1791466380000,          // t0 + settle + cycles × (in + out) + fade = t0 + 180 s
  "mySeat": 1,
  "seats": [Seat, …],                 // 1–4, ordered by seat
  "humans": 2, "echoes": 2, "guides": 0, // for the intro line ("2 people and 2 echoes …"); never shown as a score
  "ended": false,
  "realtime": { "topic": "game:<sessionId>" },
  "limits": { "eventsPerSecond": 10, "pulseMinMs": 3000, "gestureMinMs": 5000, "heartbeatMs": 2000,
              "disconnectAfterMs": 3000, "echoAfterMs": 10000, "rejoinWindowMs": 10000 },
  "serverTime": "…", "serverTimeMs": 1791466200123
}
```

## 1. Matching

### 1.1 `POST /v1/ripples/match` — join the queue, or poll it
Body `{ "ticketId": uuid, "entry": "quick" | "room", "roomId"?: uuid }` (`roomId` exactly for `room`). The
**ticket id is client-generated** (UUIDv7) and makes the call idempotent: the first call enqueues, every later call
with the same id polls (and refreshes the ticket; a ticket not polled for 6 s is never grouped). Poll every
`pollAfterMs` (≤ 2 s; shorter just before a start deadline).

- `200 { "status": "waiting", "ticketId", "pollAfterMs", "serverTime", "serverTimeMs", "invite"?: Invite }`
- `200 { "status": "matched", "ticketId", "serverTime", "serverTimeMs", "session": Session }`

**Quick-match: one global queue** — no language pool, region or age split. Grouping runs on every poll in one
transaction over the waiting tickets (`FOR UPDATE SKIP LOCKED`), oldest first, greedily adding compatible tickets:

| Rule | Starts when |
|---|---|
| `full` | 4 humans can sit together |
| `early` | the oldest has waited ≥ 8 s and ≥ 2 humans can sit together |
| `timeout` | the oldest has waited 20 s: whoever waits, plus echo-fill |

**Max wait 20 s**; there is no "no one found" or retry state. **Blocked pairs are never grouped** (a block in either
direction). Empty seats (up to 4) are filled with **echoes** when the library holds ≥ 50 eligible recordings, else
with **guide** lights; with `ripples_echoes` off they stay empty ("Breathing on your own this time").

**Room invite** (`entry: room`, a current member of a room that isn't a memory): the first tap opens an invite for
20 s ("Quiet Comet wants to breathe together · 2/4" on the room's invite banner, §3.2); taps on the banner join it. It
starts at 4 humans or when the 20 s end, with echo-fill; members with a block between them are seated in parallel
sessions of the same invite (nobody can tell). Seats carry **room pseudonyms**. One new invite per person per 10
minutes: a tap past that joins the room's open invite if there is one, otherwise the global quick queue (the ticket
simply polls; no error). A tap after an invite started opens a new one (same limit).

Re-matching while seated elsewhere silently leaves the older seat (its light dims into an echo). One waiting ticket
per account: a new ticket cancels an older waiting one.

Errors: `400 invalid_request`; `404 not_found` (room entry: not a current member, or the room is a memory);
`409 ticket_conflict` (the ticket id belongs to someone else, or to another entry); `503 ripples_paused`; plus §0.

### 1.2 `DELETE /v1/ripples/match/:ticketId` → `204`
Leave the lobby ("Leave anytime"). Idempotent; unknown ids are a no-op.

### 1.3 `GET /v1/ripples/rooms/:roomId/invite` → `200 { "invite": Invite | null }`
```jsonc
{ "inviteId": "uuid", "fromPseudonym": "Quiet Comet", "humans": 2, "capacity": 4,
  "startsAt": "…", "startsAtMs": 1791466220000, "mine": false }
```
Current room members only (else `404 not_found`). `null` when no invite is open, or when **you blocked** the inviter
(the blocked side sees no change). `humans` counts people who joined (blocked pairs sit apart, but the banner shows
the invite's total).

## 2. Session

Routes below answer `404 not_found` unless the caller holds a human seat of the session (after leaving, only
§2.4–§2.6 still work, for 7 days, so a light can be reported after the session).

### 2.1 `GET /v1/ripples/sessions/:sessionId` → `200 Session`
The server's truth: refetch after (re)subscribing and after every `seat_update` hint. `ended: true` once the session
ended (the app then just finishes locally).

### 2.2 `POST /v1/ripples/sessions/:sessionId/leave` → `204`
Leaving is silent: the light dims into an echo for the others (`seat_update { seat, kind: "echo" }`), nobody ever
sees "left" or "failed". The last human leaving ends the session. No penalty, ever.

### 2.3 `POST /v1/ripples/sessions/:sessionId/complete` → `204`
Body `{ "cycles": 0–60, "trace"?: { "offsets": [int | null, …] } }` — sent once at the end (or on leaving early).
`cycles` = breath cycles this phone completed (the server caps it at the cycles its own clock allows).
`trace.offsets` = this player's inhale/exhale transitions relative to the pacer, in order, in **50 ms steps**
(`-40…40`, `null` = missed), ≤ 2 × cycles entries. **No sync value is ever sent** (REQ-GAME-06): alignment is
computed on the phone only.

**Echo recording** (REQ-GAME-09): one unlinked row in `echo_library.recordings` when the seat completed ≥ 12
cycles by the server clock, the account hasn't opted out (§2.7) and `ripples_echoes` is on: offsets, pacer version,
completion (`hit transitions / (2 × cycles)`), median |offset| and the ISO week — no account, member, device,
session or age data, no timestamp finer than the week. Once per seat; repeats are no-ops.

### 2.4 `POST /v1/ripples/sessions/:sessionId/reports` → `201` new, `200` repeat
Body `{ "seat": 1–4, "reason": 1–9, "note"?: string ≤ 500 }` → `{ "reportId", "showHelplines" }`. Report reasons,
lanes, SLA and the daily limit (`429 report_limit`, never for reason 1) are exactly rooms §2.1. Only human seats
other than your own can be reported (`404 seat_not_found` for echoes, guides, empty seats; `400 invalid_target` for
yourself). The session (seats, pseudonyms, times, event log) is snapshotted into the evidence store (180 days)
with the reported person as the subject. Anyone involved under 18 → Minors & grooming lane, invisibly.

### 2.5 `POST /v1/ripples/sessions/:sessionId/blocks` → `201` new, `200` existing
Body `{ "seat" }` → `{ "blockId" }`. Account-level, both ways, never matched again; listed and undone with
`GET/DELETE /v1/safety/blocks` (rooms §2.2). The blocked person sees no change: the blocker's phone simply stops
showing that light's pulses and gestures.

**Mute** is per session and local only: the app stops that seat's haptics and gestures for you. Nothing is sent.

### 2.6 `POST /v1/ripples/sessions/:sessionId/flood` → `204`
Body `{ "seat" }`. Receiver-side signal (REQ-GAME-05): a seat sent more than 10 events/s. The receivers already
ignore the excess; the server files one automatic spam-lane item per seat (`reports.auto_signal = ripple_flood`)
for a moderator. Never a sanction by itself.

### 2.7 Echo consent
- `GET /v1/ripples/echo-consent` → `{ "enabled": boolean }` (on by default, per the privacy notice).
- `PUT /v1/ripples/echo-consent` `{ "enabled": boolean }` → `{ "enabled" }`. Stored in `user_consents`
  (purpose `echoes`): off withdraws, on grants again. Opt-out stops **future** recordings; past echoes are unlinked,
  so they can't be found or deleted per person [LEGAL].

## 3. Realtime (Supabase Realtime, private channels)

### 3.1 `game:<sessionId>` — Broadcast + Presence, human seat holders only
Authorised by RLS on `realtime.messages` (`public.ripples_topic_allowed`): a human seat that hasn't left, until the
session ends (+ 30 s). Clients **send** breath events (client to client, PRD 09 budget: state changes only):

| Event | Payload | Sender, rate |
|---|---|---|
| `breath_state` | `{ "seat", "phase": "in" \| "out", "t" }` | Player, per press/release (tap in accessible mode) |
| `pulse` | `{ "seat", "t" }` | Player, ≤ 1 per 3 s |
| `gesture` | `{ "seat", "type": "hug" \| "deep_breath" \| "youre_not_alone", "t" }` | Player, ≤ 1 per 5 s |
| `heartbeat` | `{ "seat", "t" }` | Player, every 2 s if idle |
| `session_start` | Session (without `serverTime`) | Server, once (a hint: the match response is authoritative) |
| `seat_update` | `{ "seat", "kind", "at" }` | Server (leave). **Hint only: refetch §2.1** — labels are never taken from the channel |
| `session_end` | `{ "t" }` | Server (t0 + 180 s, or no humans left) |

`t` = event time in server-clock ms. **Hard cap 10 events/s per seat**: the sender throttles, receivers drop the
excess and report it once (§2.6). Presence: each phone tracks `{ "seat" }`. A seat with nothing for 3 s is
*disconnected* (its light follows the pacer); after 10 s (or a leave) it is an *echo* (paler, labelled, driven by
its own recent rhythm); one event brings it back. Echo seats never pulse or gesture.

Receivers never trust server-shaped events from the channel for anything but a refetch: Realtime Broadcast carries
no sender identity, so a forged `seat_update`/`session_end` can at most trigger a harmless refetch, and a phone
always ends at its own `t0 + 180 s`. Labels come only from REST. A forged `breath_state` for another seat can only
move that light (known limitation, documented for review).

**Sync (on the phone only; never shown as a number, never sent):** for each inhale/exhale start *k*,
ref = median of the seats' times, alignment = max(0, 1 − |t − ref| / 1500 ms), 0 if missed; S = mean, EMA α 0.3.
Ripple radius = r_min + S × (r_max − r_min); fish = 3 + round(12 × S). Minimum ripple and 3 fish at S = 0.

### 3.2 `ripples:<roomId>` — Broadcast, current room members
`ripple_invite { "inviteId", "at" }` when an invite opens or someone joins it; `ripple_invite_closed
{ "inviteId", "at" }` when it starts. Ids only: the banner fetches §1.3 (block-filtered).

## 4. Server behaviour the app should know

- **Retention:** sessions, seats, tickets and the event log are purged 7 days after the session ends; reported
  sessions are in the evidence store first. Echoes: 90 days (by ISO week). Invites and tickets: 1 day.
- **Account deletion:** tickets, seats and invites go with the account (`account-purge.ts`); echoes can't (they
  hold nothing that links them to anyone).
- **Room lanterns (F5):** a room session's human `cycles_done` is stored per seat so the room lantern can add light
  (the lantern owns the rule).
- **Codes introduced here:** `ripples_paused` (503), `ticket_conflict` (409), `seat_not_found` (404).
