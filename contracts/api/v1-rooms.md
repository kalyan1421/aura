# Aura API v1 — Mood Rooms (F5) and core safety (F9)

Companion to `contracts/api/v1.md` (same base URL, auth, error shape and pending-deletion guard). Server:
`server/aura-api/src/rooms` and `src/safety`; schema `supabase/migrations/20261005000010_rooms_safety.sql` (+
`20261005000015_safety_reason_guidelines.sql`: report reason 9, community guidelines acceptance; +
`20261005000022_room_lanterns.sql`: room lanterns and Tonight's intention, Milestone B).
PRD: `06b-features-social.md` (F5, shared stranger-surface rules), `06c-features-platform.md` (F9),
`14-states.md` (Room states), `19-admin-console.md` (lanes, strikes, evidence).

## 0. Conventions

- Every route needs `Authorization: Bearer <Supabase access token>`; `401 unauthorized` without one.
- `403 account_deletion_pending` while a deletion is scheduled (global guard, v1.md). `409 profile_required`
  before onboarding.
- Errors: `{ "code": "snake_case", "message": "…" }`. Responses carry `Cache-Control: no-store`.
- Instants are ISO 8601 UTC (`2026-10-08T15:30:00.000Z`); server time is authoritative for everything shared.
- Ids are random UUIDs minted by the server: `roomId`, `memberId` (one per membership: a fresh one in every
  room), `gestureId`, `reportId`, `blockId`, `noticeId`. None is derived from, or linkable to, an account.
- Rooms are **online only** (PRD Offline Mode). The app never queues room calls; offline it shows
  "Rooms need a connection" and makes no call (REQ-ROOM-01).
- Sanctioned accounts: **every `/v1/rooms*` route** answers `403 rooms_suspended` while the account's room access is
  suspended or paused (`GET /v1/safety/me` says until when) and `403 account_closed` once the account is closed.
  `/v1/safety*` keeps working for suspended accounts ("help is never locked"); for a closed account the `POST`s
  answer `403 account_closed` while the `GET`s still work (so the app can show the closed state).
- Hidden people: a member whose account is suspended/paused/closed or pending deletion is left out of everyone
  else's `members` and "here now", and their seat can't receive gestures; the member you blocked is left out of
  *your* `members` (the blocked side sees no change).

### DS-10: the stranger boundary (tested, `test/e2e/rooms.e2e-spec.ts` "DS-10 contract")
No response in this document and no realtime payload ever contains an account id (`user_id` / JWT `sub`), an
email, a date of birth, an age, or anything that says whether someone is under 18 — about anyone, **including the
caller**. Other people appear only as `{ memberId, pseudonym, silhouette, moodChip }`. Under-18 accounts get
exactly the same responses, copy and limits as adults; their extra protections (stricter moderation, the Minors
& grooming lane) are invisible and live only on the server. Report lanes and moderation reason codes are never
returned — not even to the person a sanction is about (§2.3, no tipping off).

### Enums
| Name | Values |
|---|---|
| `Quadrant` | `storm` · `rain` · `moonlight` · `sunrise` |
| `Theme` (by the room's quadrant) | `lighthouse` (storm) · `rain_sanctuary` (rain) · `midnight_observatory` (moonlight) · `sunrise_deck` (sunrise) |
| `RoomState` | `forming` · `open` · `lantern_hour` · `closing` · `memory` (a purged room is simply `404`) |
| `Stage` | `spark` · `ember` · `glow` · `radiance` · `constellation` |
| `GestureType` (the 8 presets) | `warm_tea` · `light_a_candle` · `hug` · `me_too` · `soft_rain` · `stargaze` · `deep_breath` · `youre_not_alone` |
| `GestureTarget` | `member` · `room` · `reflection` (F6: `toReflectionId`, contracts/api/v1-reflections.md §1.5) |
| `ReportReason` (int) | `1` in danger or self-harm · `2` harassment · `3` sexual content or advances · `4` hate · `5` contact or personal info · `6` spam or selling · `7` may be under 13 · `8` other · `9` targeting a young person. Codes never change meaning; new ones are appended (apps list 9 before 8 "other") |

### Shared shapes
```ts
type LanternHour = {
  timezone: string;   // the room's region clock: America/Chicago | Europe/Berlin | Asia/Kolkata | Asia/Tokyo
  active: boolean;    // true between startsAt (inclusive) and endsAt (exclusive)
  startsAt: string;   // the current window if active, else the next one (21:00 on the region clock)
  endsAt: string;     // 23:00 on the region clock
};
type RoomInfo = {
  roomId: string; quadrant: Quadrant; theme: Theme; state: RoomState;
  readOnly: boolean;       // state === 'memory'
  createdAt: string;
  joinsCloseAt: string;    // createdAt + 20 h: no new members after this ("closing")
  memoryAt: string;        // createdAt + 24 h: read-only memory ("This room has become a memory")
  purgeAt: string;         // memoryAt + 7 d: everything is deleted
  lanternHour: LanternHour;
  lantern: RoomLantern | null;       // Milestone B (§1.9): null before the room's first Lantern Hour / kill switch off
  intention: RoomIntention | null;   // Milestone B (§1.9): null until tonight's intention is set / kill switch off
};
// Room totals only (REQ-ROOM-13/14): never who added light or held, not even your own share.
type RoomLantern = {
  level: number;           // 0–5: how brightly tonight's lantern glows. Only ever rises (never dims, never resets)
  maxLevel: number;        // 5
  active: boolean;         // taking light now (state === 'lantern_hour'); false afterwards: "Tonight's lantern"
};
type RoomIntention = {
  key: string;             // preset key, the app localises it (e.g. "sleep_before_midnight"); unknown key → hide the card
  holds: number;           // "12 holding this tonight" — the room total; only ever rises
  open: boolean;           // holding is possible now (state === 'lantern_hour'); afterwards read-only
};
type Counts = {
  hereNow: number;         // current members seen in the last 2 min (heartbeat), real members only
  today: number;           // everyone who has been a member of this room (it lives 24 h) — "18 people have been here today"
};
type Silhouette = {        // snapshot taken when the member joined; never updates, never a fingerprint
  stage: Stage;
  hue: number | null;      // avatar hue rounded to 30° buckets (0, 30, … 330); null = no hue yet
  cosmetic: string | null; // at most one standard cosmetic; always null until F12 ships
};
type Member = {
  memberId: string; pseudonym: string;   // e.g. "Quiet Comet" — fresh per room, unique within the room
  silhouette: Silhouette;
  moodChip: string;        // mood id at join (catalogue id, e.g. "anxious"); the app localises it
  live: boolean;           // seen in the last 2 min
  muted: boolean;          // you muted this member (you still see the silhouette)
  isMe: boolean;
};
type ReceivedGesture = { gestureId: string; type: GestureType; fromMemberId: string; fromPseudonym: string; at: string };
type SentGesture     = { gestureId: string; type: GestureType; target: GestureTarget; toMemberId: string | null; at: string };
type RoomGesture     = { gestureId: string; type: GestureType; target: GestureTarget; at: string }; // anonymous
type RoomSummary = {
  room: RoomInfo;
  me: { memberId: string; pseudonym: string; moodChip: string; joinedAt: string };
  counts: Counts;
};
type RoomDetail = {
  room: RoomInfo;
  me: { memberId: string; pseudonym: string; moodChip: string; silhouette: Silhouette; joinedAt: string;
        surveyEligible: boolean;     // show "Did you feel less alone?" on exit when true (see §1.7)
        holdingIntention: boolean }; // you hold tonight's intention (§1.9) — yours only, never anyone else's
  counts: Counts;
  members: Member[];       // current members incl. you (isMe), oldest first; members you blocked are left out
  gestures: {
    received: ReceivedGesture[];  // sent to you, newest first (≤ 100); hides muted/blocked senders and gestures you reported
    sent: SentGesture[];          // yours, newest first (≤ 100) — including silently dropped ones (they always "look sent")
    recent: RoomGesture[];        // the room's anonymous feed, newest first (≤ 50) — "others see an unnamed animation"
  };
  realtime: { roomTopic: string; memberTopic: string };  // "room:<roomId>", "member:<memberId>" (§3)
};
```

## 1. Rooms

### 1.1 `POST /v1/rooms/match` — join (or return to) a room for this check-in
```json
{ "quadrant": "storm", "moodId": "anxious", "timezone": "America/Chicago", "allowPoolFallback": false }
```
- `moodId`: a catalogue mood **in** `quadrant` (the saved check-in's mood) → else `400 invalid_request`.
- `timezone` (optional): the device's current IANA zone; its UTC offset *now* picks the timezone region.
  Default: the profile timezone. Unknown zone → `400 invalid_request`.
- `allowPoolFallback` (optional, default false): see `409 language_pool_unavailable`.

`200`:
```json
{ "...RoomDetail": "…", "match": { "step": 2, "reentry": false, "created": false, "merged": false } }
```
i.e. every `RoomDetail` field plus `match` (for analytics `room_joined`: `members_bucket`, `cold_start_merged`):
`step` 0–4 = the ladder step that placed you (§4.2); `reentry` = step 0 (same room, same pseudonym, same
memberId); `created` = a new room was spawned for you; `merged` = placed outside your own partition (another
region, pool or the adjacent quadrant).

| Error | When |
|---|---|
| `400 invalid_request` | bad body, unknown mood, mood not in `quadrant`, unknown timezone |
| `403 rooms_suspended` | the account's room access is suspended or paused (see `GET /v1/safety/me`) |
| `403 account_closed` | the account was closed for breaking the rules ("This account was closed for breaking Aura's rules.") |
| `409 guidelines_required` | the community guidelines in force aren't accepted yet (REQ-SAFE-04). Body: `{ "code": "guidelines_required", "message": "…", "version": 1 }` — the app shows the guidelines, calls `POST /v1/safety/guidelines/accept` (§2.4) and retries the match. Checked after `profile_required` / `rooms_suspended` / `account_closed` and before `language_pool_unavailable`; nothing is seated. If `version` is newer than the copy the app carries, the app asks for an update instead |
| `409 language_pool_unavailable` | Hindi + Hinglish rooms aren't open yet (`feature_flags.rooms_pool_hi` off) and `allowPoolFallback` was not true → the app offers "Join English room" (retry with `allowPoolFallback: true`) / "Tell me when they open" / close (14-states) |
| `503 rooms_paused` | the `rooms_enabled` kill switch is off (v1.md "Remote config"); nothing is seated. The app says "Rooms are resting for a bit" and hides join offers; rooms already joined keep working |
| `403 device_banned` | this install is banned (v1.md, device bans); the app shows "This device can't use Aura" |
| `429 room_join_limit` | 3 **new** rooms joined for this quadrant in the last 24 h. Returning to your room (step 0) is always free |

Only this route is gated by the guidelines: rooms you already joined keep working after the required version
changes, and you are asked again at your next match.

Rules: one active room per quadrant — while you hold a room for this quadrant (joined for it, or a room of this
quadrant, not left, younger than 24 h) you always get it back (step 0). Leaving frees the slot; you can never
rejoin a room you left. Never matched into a room with anyone you blocked or who blocked you. p95 target 800 ms.

### 1.2 `GET /v1/rooms` — the "Your rooms" strip
`200 { "rooms": RoomSummary[] }` — rooms you are in (not left, not purged), newest first: active ones
(`forming`/`open`/`lantern_hour`/`closing`) **and** memories (`memory`, 7 days, read-only).

### 1.3 `GET /v1/rooms/:roomId` → `200 RoomDetail`
Members only (not left). Anyone else, an unknown or purged room, or a room you left → `404 not_found` (never says
which). Opening the room also counts as being here (liveness). Memories stay readable until `purgeAt`.

### 1.4 `POST /v1/rooms/:roomId/heartbeat` → `200 { "room": RoomInfo, "counts": Counts }`
Liveness ("here now"): call every **45 s** while the room screen is in the foreground (live = seen ≤ 2 min ago),
and once when it comes back to the foreground. The response carries fresh counts and state, so it doubles as a
poll. A heartbeat in a memory room changes nothing. Supabase Realtime **Presence is not used** (clients can't track
presence on these channels; see §3).

### 1.5 `POST /v1/rooms/:roomId/gestures`
```json
{ "type": "warm_tea", "target": "member", "toMemberId": "<memberId>" }
{ "type": "me_too", "target": "room" }
```
→ `202 { "gestureId": "uuid", "at": "ISO" }` — the same answer whether the gesture was delivered or **silently
dropped**: over a limit, you are shadow-muted, a block exists between you and the recipient (either way), the
recipient muted you, or the recipient is hidden (suspended / deactivated). Dropped gestures are never delivered and
never broadcast; they still show in your own `sent` list (they "look sent") — except further over-limit attempts by
an account already shadow-muted for flooding, which are not stored at all. Sending also counts as being here.

| Error | When |
|---|---|
| `400 invalid_request` | unknown `type`/`target`, `toMemberId` missing for `member` or present otherwise, `toReflectionId` missing for `reflection` or present otherwise (v1-reflections.md §1.5) |
| `400 invalid_target` | `toMemberId` is you |
| `404 not_found` | not a current member of the room / room gone |
| `404 member_not_found` | `toMemberId` is not a current member of this room (left, or never was) |
| `409 room_read_only` | the room is a memory |

Limits (per account, server-side; the app should also disable the tray for 2 s after a send): **1 gesture per
2 s** (across rooms) · **40 per room per hour** · **the same gesture to the same member ≤ 3 per 10 min**. Over a limit
→ dropped silently. 3 limit hits in 24 h → the account's gestures are shadow-muted for 24 h (still "sent", never
delivered) and a spam-lane item is queued for a moderator (strike signal).

Delivery (§3): the room gets an anonymous `gesture_sent`; for `member` gestures the recipient also gets
`gesture_received` (with the sender's pseudonym) on their member topic. Only the recipient ever learns who sent a
gesture to whom; nobody sees tallies.

### 1.6 `POST /v1/rooms/:roomId/leave` → `200 { "surveyEligible": boolean }`
Leaves for good (frees the quadrant slot, no rejoining, the room disappears from `GET /v1/rooms`). Idempotent: a
repeat returns `200` again. Allowed in every state, including a memory ("remove from my rooms"). Non-member → `404`.

### 1.7 `POST /v1/rooms/:roomId/survey` → `204`
```json
{ "answer": "yes" }          // "yes" | "no" | "skip" — "Did you feel less alone?"
```
Aggregate only: the server adds 1 to a daily counter per (pool, quadrant, region, answer); nothing links the
answer to you. `surveyEligible` (in `RoomDetail.me` and the leave response) is true when you have been in the room
≥ 30 s and haven't answered a survey in the last 24 h; the app shows the survey only then. Also works right after
leaving. A not-eligible answer is ignored (still `204`). Non-member → `404`.

### 1.8 Mutes (per membership, for you only)
- `POST /v1/rooms/:roomId/mutes` `{ "memberId": "<memberId>" }` → `204` (idempotent).
- `DELETE /v1/rooms/:roomId/mutes/:memberId` → `204` (idempotent).
- The member stays in `members` with `muted: true` (the app dims/hides their gestures and pulses); their gestures
  to you are dropped (they see them as sent). Works in memories. `400 invalid_target` (yourself),
  `404 not_found` (not your room), `404 member_not_found` (not a member of this room).

### 1.9 Room lanterns and Tonight's intention (Milestone B, P1 — REQ-ROOM-13 / REQ-ROOM-14)
PRD 06b "Room lanterns and Tonight's intention". Both are **room totals** in `RoomInfo` (`lantern`, `intention`) and in
the `room_state` broadcast (§3) — never per member, never who, not even your own share.

**Room lantern** — one per room, 5 levels `[ASSUMPTION]`, lit only while the room is in Lantern Hour (`state:
lantern_hour`: open rooms, 21:00–23:00 on the region clock; forming and closing rooms keep what they have).
- **Adds light:** every **delivered** gesture from a member (§1.5; a gesture = 1 unit), and breath cycles finished by
  **human** seats in Breath Ripples sessions started from the room (0.25 unit per cycle `[ASSUMPTION]`). **Adds
  nothing:** over-limit or shadow-muted gestures, gestures dropped for a block (either way), a mute or a hidden
  recipient, echoes and guide lights, anything outside Lantern Hour. The gesture answer (`202`) is identical either way.
- **Scaled to the room:** a level needs `max(3, ceil(1.5 × members live when the light arrives))` units
  (`matching_config.lantern_min_units_per_level` / `lantern_units_per_member`, tunable) — a room of 3 can light it too.
- **Additive only:** stored as a running total that only rises (a DB trigger refuses anything lower). Leaving,
  blocking, removals (a removed reflection and its gestures included), people going quiet and the end of the hour
  never lower it. At 23:00 it keeps its level (`active: false`); the memory shows it as "Tonight's lantern" — no
  failed / missed / almost copy (14-states).
- **Fully lit** (`level === maxLevel`): each app that sees the level reach 5 **live** (a `room_state` while in the
  room) plays one short shared moment (lanterns rise; under Reduce Motion a still image and a line of text). Loading a
  room that is already lit doesn't replay it.

**Tonight's intention** — at the start of Lantern Hour each room gets one preset (a key, rotated nightly from the
room's language-pool list `room_intention_presets`; the app localises the key). Set once per room and night.

`POST /v1/rooms/:roomId/intention/hold` (no body) → `200 { "intention": RoomIntention, "holding": true }`
- One tap; **idempotent** (holding again answers `200` with the same total). There is no un-hold: it can't be taken
  back, and the total never falls — leaving the room doesn't lower it either (a falling count would name a leaver).
- Creates no habit, reminder or record beyond the room's total (plus your own `me.holdingIntention`), purged with the
  room. No free text, no pairing, no named holders, no follow-up question or push the next day.
- The room gets `room_state` with the new total. Holding also counts as being here.

| Error | When |
|---|---|
| `404 not_found` | not a current member of the room / room gone (same as §1.3) |
| `409 intention_closed` | the room isn't in Lantern Hour (before 21:00, after 23:00, forming, closing, memory), or no preset is enabled for its pool |
| `503 intention_paused` | the `room_intention_enabled` kill switch is off |

**Kill switches** (feature flags, v1.md "Remote config"): `room_lanterns_enabled` off → no light is added and
`lantern` is `null` everywhere (the stored level is kept for when it comes back); `room_intention_enabled` off →
`intention` is `null` and holding answers `503 intention_paused`. `rooms_enabled` (the rooms kill switch) only stops
new joins: rooms already joined keep their lantern and intention.

**For F7 Breath Ripples (server):** `addBreathCyclesToRoomLantern(tx, roomId, humanCycles, now?)` in
`server/aura-api/src/rooms/lanterns.ts` — call once when a session started from a room ends, inside the transaction
that records it, with the cycles finished by human seats only. A no-op outside that room's Lantern Hour.

## 2. Safety

### 2.1 `POST /v1/safety/reports`
```json
{ "target": { "kind": "member",  "roomId": "<roomId>", "memberId": "<memberId>" },   "reason": 2, "note": "optional" }
{ "target": { "kind": "gesture", "roomId": "<roomId>", "gestureId": "<gestureId>" }, "reason": 6 }
{ "target": { "kind": "room",    "roomId": "<roomId>" },                             "reason": 8 }
```
→ `201 { "reportId": "uuid", "showHelplines": boolean }` (`200` with the existing `reportId` when you already have
an open report on the same target for the same reason — repeats count once).
- `showHelplines` is true for reason `1` only: open the support sheet at once ("reporter sees helplines").
- `note`: optional, ≤ 500 characters (grapheme clusters), shown to moderators only.
- You must hold (or have held) a membership in that room, and the room must not be purged (memories work) →
  else `404 not_found`; the target must belong to the room → else `404 not_found`. Reporting yourself →
  `400 invalid_target`.
- The item hides for you at once: a reported member is muted for you in that room (not for reason 1); a reported
  gesture drops out of your lists.
- Limits: reason 1 unlimited; reasons 2–9 at most 20 per 24 h → `429 report_limit`.
- Server-side routing (never visible): crisis lane (reason 1); Minors & grooming lane (reasons 7 and 9 whatever the
  ages on record, or anyone involved is under 18 by stored DOB or a platform age signal); harassment (2, 3, 4, 5);
  spam/other (6, 8). "Involved" = the reporter and the reported person; for a room report, everyone in the room; for
  reason 9 ("targeting a young person" — a bystander's sense of it is the signal), everyone who has been in the room,
  including people who left. Sexual content (3), contact / personal info (5) and targeting a young person (9) with a
  minor involved get the 2 h clock and the 24×7 page (§5); other Minors & grooming items 4 h. The response is the same
  for every reason and age (DS-10). The reported item is copied to the evidence store (180 days). Two "may be under
  13" reports from different people pause that account's rooms pending review.

`GET /v1/safety/reports` → `200 { "reports": [{ "reportId", "reason", "targetKind", "status": "received" | "reviewed",
"outcome": "action_taken" | "no_action" | null, "createdAt", "reviewedAt": "ISO" | null }] }` — your own reports,
newest first (≤ 100): the in-app outcome inbox. Never says what happened to the other person beyond `outcome`.

### 2.2 Blocks (account-level, both ways)
- `POST /v1/safety/blocks` `{ "roomId": "<roomId>", "memberId": "<memberId>" }` → `201 { "blockId": "uuid" }`
  (`200` with the same `blockId` if you already block that person). The member is resolved to their account on
  the server. `400 invalid_target` (yourself); `404 not_found` / `404 member_not_found` as for mutes (memories work).
- `GET /v1/safety/blocks` → `200 { "blocks": [{ "blockId", "quadrant": Quadrant | null, "createdAt" }] }`, newest
  first — no pseudonym or other identity is kept; `quadrant` is the quadrant of the room you blocked from, for a
  label like "Someone from The Rain Sanctuary" (it outlives the room; null only if unknown). The app may keep its own
  local label (e.g. the pseudonym it showed) if it wants one.
- `DELETE /v1/safety/blocks/:blockId` → `204` (idempotent; unknown ids too).
- Effects: never matched into the same room again; the person disappears from your `members` in every room;
  gestures between you are dropped both ways. **The blocked person sees no change** and is never told.

### 2.3 `GET /v1/safety/me` → your own standing
```json
{ "rooms": "available", "until": null,
  "notices": [{ "noticeId": "uuid", "kind": "warning", "createdAt": "ISO", "until": null }],
  "guidelines": { "version": 1, "accepted": true, "acceptedVersion": 1, "acceptedAt": "ISO" } }
```
`rooms`: `available` · `suspended` (`until` = end, or null = paused pending review) · `closed` (account closed).
`notices` (≤ 50, newest first, last 180 days): `warning` · `suspension` (room suspension, pause pending review, social
ban) · `account_closed`, with when and until when — **never why**: no reason code, lane, report or moderator detail
for any kind (19 admin console, Minors & grooming SOP step 4 "no tipping off"; e.g. a ban for grooming reads exactly
like any other closure). The app shows the calm generic line and how to ask for a review: the Grievance Officer
(bundled in the app; also `GET /v1/grievances/officer`) and `POST /v1/grievances` with category `moderation_appeal`.
Shadow-mutes are never shown anywhere (no notice, `rooms` stays `available`).
`guidelines` (REQ-SAFE-04): `version` = the version rooms require now; `accepted` = you accepted it or a newer one;
`acceptedVersion` / `acceptedAt` = your newest acceptance (null if none). Works for suspended and closed accounts.

### 2.4 `POST /v1/safety/guidelines/accept` — community guidelines before the first room (REQ-SAFE-04)
```json
{ "version": 1 }
```
→ `200 { "version": 1, "accepted": true, "acceptedVersion": 1, "acceptedAt": "ISO" }` (the §2.3 `guidelines` shape).
- `version`: the version of the guidelines text the app just showed (integer 1–1000) → else `400 invalid_request`.
  The required version, or a newer one (an app release can carry new copy before the server asks for it), is
  recorded; an older one opens nothing → `409 guidelines_required` with `{ "version": <required> }` (an out-of-date
  app asks for an update).
- Idempotent: repeating keeps the first `acceptedAt`. Needs a profile (`409 profile_required`). Suspended accounts
  can accept; a closed one gets `403 account_closed`.
- Versioning: `safety_config.guidelines_version` (default 1). On a material change AK ships the new copy in an app
  release, then raises the version: everyone is asked again at their next `POST /v1/rooms/match`.
- Stored server-only in `guidelines_acceptances` (account, version, time; purged with the profile). The app keeps a
  local flag only as a cache to skip the sheet; the server's answer wins.

## 3. Realtime (Supabase Realtime, private Broadcast channels)

- **Topics:** `room:<roomId>` (every current member) and `member:<memberId>` (only the owner of that membership).
  Join both when a room opens: `supabase.channel('room:<id>', private: true)`,
  `supabase.channel('member:<memberId>', private: true)`; the Supabase client sends the user's access token
  (`realtime.setAuth`, automatic in supabase_flutter).
- **Authorization:** RLS on `realtime.messages` — policy `aura_rooms_receive` (SELECT, `extension = 'broadcast'`,
  role `authenticated`) calls `public.realtime_topic_allowed(topic)`: the caller holds a current (not left)
  membership of a not-yet-purged room matching the topic, has no pending account deletion and no room
  suspension/pause/closure. Checked when joining (and when the token is refreshed); anyone else gets
  `Unauthorized`. Unsubscribe after leaving.
- **Clients cannot send:** there is no INSERT policy, so a client broadcast is never accepted (Realtime refuses or
  silently drops it; nobody receives it) and Presence is not available. Everything shown to strangers is written
  through NestJS (limits, blocks, mutes, sanctions applied) and broadcast by the server.
- **How the server broadcasts:** `realtime.send(payload, event, topic, private => true)` in Postgres, **inside the
  same transaction** as the write — delivered only if it commits. Realtime adds an `id` (message id) to every
  payload; ignore it. Delivery is best-effort: treat events as hints and refetch `GET /v1/rooms/:roomId` after
  (re)subscribing or on `room_state`.
- **Payloads:** ids, pseudonyms and preset keys only — never text, account ids, ages or DOBs (DS-10).

| Topic | Event | Payload | When |
|---|---|---|---|
| room | `member_joined` | `{ member: { memberId, pseudonym, silhouette, moodChip }, counts, at }` | a new member joins (not on step-0 returns) |
| room | `member_left` | `{ memberId, counts, at }` | a member leaves, or is removed from view (room access suspended/paused/closed) |
| room | `presence` | `{ counts, at }` | "here now" changed (a member became live, or the ≤ 60 s sweep saw someone go quiet) |
| room | `gesture_sent` | `{ gestureId, type, target, at }` — anonymous | every delivered gesture (the recipient dedupes with its `gesture_received` by `gestureId`) |
| room | `room_state` | `{ state, readOnly, joinsCloseAt, memoryAt, purgeAt, lantern, intention, at }` — `lantern` / `intention` are the §1.9 room totals (or null); **no member id or per-member value, ever** | forming→open, open↔lantern_hour, →closing, →memory; **and** when the lantern's level rises or the intention's hold count changes (§1.9). Refetch the detail only when `state` / `readOnly` changed; otherwise apply `lantern` / `intention` as they are (never lower a level you already show) |
| room | `lantern_hour` | `{ lanternHour, at }` | the region clock hits 21:00 (active) or 23:00 (ended); end the lantern locally at `lanternHour.endsAt` even if this arrives late |
| member | `gesture_received` | `{ gestureId, type, fromMemberId, fromPseudonym, at }` | a gesture to you was delivered ("Quiet Comet sent you Warm Tea") |

## 4. Server behaviour the app should know

### 4.1 Lifecycle (derived from timestamps on the server clock; the worker broadcasts transitions within a minute)
`forming` (1st member) → `open` (2nd member ever joined) ⇄ `lantern_hour` (21:00–23:00 on the room's region clock,
open rooms only) → `closing` at 20 h (no new members; gestures still work; "becomes a memory at …") → `memory` at
24 h (read-only: gestures `409 room_read_only`; report, block, mute, leave and survey still work) → purged at
24 h + 7 d (room, memberships, pseudonyms, gestures and mutes hard-deleted; reported items were already copied to
the evidence store) → `404`.

### 4.2 Matching (`matching_config`, tunable without a release)
- Partition = `language_pool × quadrant × timezone_region`. Pool from the app language (profile): `en`;
  `te` (Telugu + Tenglish); `hi` (Hindi + Hinglish, off until moderation is ready → English with consent).
- Region from the UTC offset now: `americas` ≤ −2:30 (America/Chicago) · `europe_africa` −2:00…+3:00
  (Europe/Berlin) · `south_asia` +3:30…+6:30 incl. the Gulf (Asia/Kolkata) · `east_asia_pacific` ≥ +7:00
  (Asia/Tokyo). A room keeps its region's Lantern Hour for life.
- Thin-partition merge: fewer than 12 joins in 24 h from people whose home partition this is → the same pool and
  quadrant in the busiest region (ties → `south_asia`); still thin → non-English pools use English.
- Ladder: **0** return to your room · **1** exact mood (joinable room seeded with your mood, ≥ 1 live — *off at
  alpha*) · **2** the joinable partition room with the most live members · **3** when the partition had < 3 live
  over 15 min: the adjacent quadrant on the same side (storm↔rain, moonlight↔sunrise — never pleasant with
  unpleasant) with ≥ 3 live · **4** nothing live: the partition room with the most people today, else a new room.
- Joinable = younger than 20 h, fewer than 24 current members, no block with you, not a room you left.
  Outside Lantern Hour a room with ≥ 12 live members counts as full enough (a new room spawns instead); in
  Lantern Hour rooms fill to 24 first. Concurrent joins can never make a 25th member (row locks + DB trigger).
- Counts are real members only: no bots, echoes, staff or inflated numbers.

### 4.3 Accounts, deletion and retention
- While an account's deletion is pending (7-day grace) it is deactivated in rooms: hidden from other members, out
  of "here now", refused on Realtime (and every route answers `403 account_deletion_pending`, v1.md). "Keep my
  account" restores it.
- The account purge removes its memberships (with pseudonyms, heartbeats, survey marks, gestures and mutes both
  ways), blocks both ways, sanctions, strikes and guidelines acceptances (with the profile); reports it filed stay in
  their moderation lane without the link to it. The only rows that may still reference a purged account are
  **evidence holds about it** (reported content where it is the subject), kept until `hold_until` = capture +
  180 days `[LEGAL]` (`LEGAL_HOLD_TABLES`, `server/aura-api/src/account/account-purge.ts`). The moderation audit
  log keeps only an HMAC of the account id.
- Survey answers are aggregate counters (no account, member or room id).

### 4.4 Codes introduced here
`invalid_target`, `member_not_found`, `room_read_only`, `language_pool_unavailable`, `room_join_limit`,
`report_limit`, `rooms_suspended`, `account_closed`, `guidelines_required`, `intention_closed`, `intention_paused`
(plus v1.md's `invalid_request`,
`not_found`, `profile_required`, `account_deletion_pending`, `unauthorized`).

## 5. For the admin console (next stage): internal `ModerationService` (`server/aura-api/src/safety/moderation.service.ts`)
The console's NestJS admin layer (SSO + 2FA, roles) wraps these methods; nothing here is exposed over HTTP yet.
- `listQueue({ lane?, limit? })` → open items, lane first (`crisis` > `minors_grooming` > `harassment` > `spam`), then
  oldest: `{ reportId, lane, priority, reason, reasonKey, source (user | auto), autoSignal, targetKind, createdAt,
  slaDueAt, overdue, pages, involvesMinor ("Under 18" flag — never a DOB), reporterCount, note, room { roomId,
  quadrant, languagePool, tzRegion, ageHours }, subject { hash (HMAC of the account id), pseudonym, accountAgeDays,
  activeStrikes, activeSanctions }, evidenceHoldId }`. SLA: crisis 15 min in India's Lantern Hour else 1 h (pages in
  Lantern Hour); minors & grooming 2 h and pages 24×7 for sexual / contact-info / targeting-a-young-person reports
  involving a minor, else 4 h; others 24 h. `reasonKey` of reason 9 is `targeting_minor`.
- `act({ reportId, action, actor, reasonCode?, hours? })`, `action` ∈ `dismiss` · `warn` · `strike` (ladder: warning
  → 24 h shadow-mute → 7-day room suspension → permanent social ban; 90-day strikes; a crisis report can never
  strike → `ModerationError('crisis_never_strikes')`) · `shadow_mute` (1–720 h, default 7 days) · `suspend` (24 h or
  7 days) · `pause` (pending review; the report stays open) · `ban` (account closed; in the Minors & grooming lane
  the evidence hold becomes ≥ 180 days from the ban with a mandatory-report task). One transaction each, with an
  audit row; `reasonCode` (`[a-z0-9_]`, ≤ 40) defaults to the report's reason key.
- `liftSanction(sanctionId, actor, reasonCode)`, `pendingMandatoryReports()`, `recordMandatoryReport(holdId, actor,
  { reportedTo, reportRef } | { legalReason })`, `auditLog({ limit?, beforeId? })`, `verifyAuditChain()`.
- Automatic actions are audited as `system`: `auto_gesture_shadow_mute` (3 gesture-limit hits in 24 h → 24 h
  gesture shadow-mute + a spam-lane item), `auto_rooms_pause` (2 distinct "may be under 13" reports).
- `moderation_actions` is append-only (UPDATE/DELETE/TRUNCATE fail for every role, trigger + revoked grants) and
  hash-chained (`prev_hash` → `row_hash`).

## 6. Not in this slice (hooks only)
Reflections are specified in `contracts/api/v1-reflections.md` (F6: gesture `target: reflection`, report `target.kind: reflection`, `reflection_published` / `reflection_removed` / `reflection_status` events). Breath Ripples (F7:
`game:<sessionId>` topics), gifts (F12: fail before charge on a block), gesture pushes (F14: "3 people in your room
sent you warmth", batched, 1 per room per day), bring-a-friend rooms (`rooms.kind`), the admin console HTTP layer
(the internal `ModerationService` exists: queue by lane, act, audit log).
Milestone B: room lanterns and Tonight's intention — §1.9 (room totals in `RoomInfo` and `room_state`). Milestone C: Quiet Together (F16) reports use a new `target.kind` (`session`); the report body
shape stays the same.
