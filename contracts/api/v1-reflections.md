# Aura API v1 — Reflections (F6)

Companion to `contracts/api/v1.md` and `contracts/api/v1-rooms.md` (same base URL, auth, error shape, sanctions,
pending-deletion guard, DS-10 boundary). Server: `server/aura-api/src/reflections`; schema
`supabase/migrations/20261005000018_reflections.sql`; on-device + server text rules
`contracts/safety/reflection_filter.v1.json` (+ `reflection_filter.vectors.json`, both stacks must pass them).
PRD: `06b-features-social.md` F6 (+ F5 realtime), `06c-features-platform.md` F9 "Reflection pipeline", Strikes,
Minors & grooming; `14-states.md` "Reflection composer"; `19-admin-console.md`; `20-timeline.md` weeks 15–17.

A reflection is a short (≤ 200 characters), moderated post inside a mood room. It is answered **only with gestures**:
no replies, no threads, no editing (REQ-REF-05).

## 0. Conventions

- Everything in `v1-rooms.md` §0 applies: bearer token, `403 rooms_suspended` / `403 account_closed` for sanctioned
  accounts, `403 account_deletion_pending`, `409 profile_required`, `Cache-Control: no-store`, ISO 8601 UTC instants,
  errors `{ "code", "message" }`.
- **Characters** are extended grapheme clusters (what a person sees; Dart `characters`, JS `Intl.Segmenter`) — never
  UTF-16 units (Node's ICU joins Indic conjuncts, so the server never counts more characters than the app does;
  `server/aura-api/src/sync/text-limits.ts`).
- Reflections are **online only**. The app keeps the draft on the phone (never lost) and disables Send while offline;
  a Send that was in flight when the connection dropped is retried with the **same `reflectionId`** (idempotent).
- **DS-10 (tested: `test/e2e/reflections.e2e-spec.ts` "DS-10 contract")**: no response and no realtime payload in this
  document contains an account id, an email, a DOB, an age, an under-18 flag, a report lane or a moderation score —
  about anyone, including the caller. Authors appear only as `{ memberId, pseudonym }` of their room membership.
  Under-18 accounts get byte-for-byte the same responses and copy; stricter thresholds are invisible (REQ-REF-08).
- **Reflection text is never logged**, never sent to analytics, and leaves Aura only to OpenAI omni-moderation
  (REQ-REF-07). At rest it is envelope-encrypted (DS-1): a random per-reflection data key, AES-256-GCM, wrapped with
  the server master key (`src/keys/envelope.ts`), associated data bound to the reflection id. Only NestJS decrypts it.

### Enums
| Name | Values |
|---|---|
| `ReflectionStatus` (what the **author** may see) | `pending` (still checking) · `published` · `held` (waiting for a human) · `rejected` (not posted; text returns to the composer) · `removed` (taken down after a report was upheld) · `crisis_diverted` (never published; the support sheet opens — only ever in the `POST` answer and the author's `reflection_status` event, never listed) |
| `RejectReason` | `contact_details` (phone numbers incl. spaced / spelled-out digits, emails, UPI ids, @handles, contact-swap phrases) · `link` · `personal_questions` (asking someone's age, school, city, photos, to meet or to keep secrets) · `hurtful` (harassment, hate, threats) · `sexual` · `other` |
| `ReviewHint` | `soon` ("Waiting for a quick check") · `overnight` ("This may take until morning": the reviewer's night, 00:30–07:30 IST by default) |
| `ComposerState` | `open` · `limit_reached` (3 in this room in 24 h, or 10 in 24 h across rooms) · `paused` (kill switch / reduced mode: "Reflections are resting for a bit. Gestures still work.") · `read_only` (the room is a memory) |

Statuses that exist only on the server: `deleted` (author deleted or withdrew it), `expired` (still held or pending
when the room became a memory — never published).

### Shapes
```ts
type Reflection = {
  reflectionId: string;              // UUID (client-generated UUIDv7)
  status: 'published' | 'pending' | 'held' | 'rejected' | 'removed';   // anything but 'published' only on your own
  author: { memberId: string; pseudonym: string };   // the room membership — never an account id
  isMine: boolean;
  text: string;                      // as written (never translated)
  createdAt: string;
  publishedAt: string | null;
  gestureCount: number | null;       // delivered gestures on it — YOUR published reflections only; null otherwise
  rejectReason: RejectReason | null; // your own rejected / removed ones only
  review: ReviewHint | null;         // your own pending / held ones only
};
type Composer = {
  state: ComposerState;
  maxChars: number;                  // 200
  perRoom: number;                   // 3
  remainingInRoom: number;           // "2 of 3 left today" (rolling 24 h)
  remainingToday: number;            // of 10 across rooms (rolling 24 h)
  slow: boolean;                     // the automatic check is degraded: "Reflections are slower right now"
};
type SendOutcome = {
  reflectionId: string;
  status: 'published' | 'pending' | 'held' | 'rejected' | 'crisis_diverted';
  rejectReason: RejectReason | null; // when rejected
  review: ReviewHint | null;         // when pending or held
  showSupport: boolean;              // true only for crisis_diverted: open the F9 support sheet at once
  reflection: Reflection | null;     // the stored item (null for rejected-by-rules and crisis_diverted)
  composer: Composer;
};
```

## 1. Routes

### 1.1 `GET /v1/rooms/:roomId/reflections` → `200 { "reflections": Reflection[], "composer": Composer }`
Members only (current or memory; not left): else `404 not_found`. Newest first (by `createdAt`; no ranking), ≤ 200.
Contains every **published** reflection you may see, plus **your own** `pending`, `held`, `rejected` and `removed`
ones. Never in it: other people's non-published items; anything by someone you blocked or who blocked you (both
ways, REQ-SAFE-06); reflections of members you muted (per membership, for you only); reflections you reported (they
hide for you at once); reflections hidden by the report threshold (§3); reflections of hidden accounts (suspended,
paused, closed, pending deletion). Memories stay readable until the room is purged; the composer is `read_only`.

### 1.2 `GET /v1/rooms/:roomId/reflections/:reflectionId` → `200 Reflection`
Same visibility as 1.1; anything you may not see → `404 reflection_not_found` (never says why).

### 1.3 `POST /v1/rooms/:roomId/reflections` — send
```json
{ "reflectionId": "0192f0c4-8b5e-7c1a-9d3e-2f4a6b8c0d1e", "text": "first Diwali alone in this city" }
```
- `reflectionId`: a UUID the app generates once per draft (UUIDv7). Replaying the same id by the same member answers
  the current outcome (`200`); the id already used by someone else, or in another room → `409 reflection_id_conflict`.
- `text`: trimmed; 1–200 characters; emoji allowed. Longer, empty, or not a string → `400 invalid_request`.
- **No replies:** a body carrying `parentId` or `parent_id` (any value, even `null`) → `400 replies_not_supported`.
  There is **no edit endpoint** (REQ-REF-05). Unknown keys → `400 invalid_request`.

Answer: `201 SendOutcome` when an item was stored, `200 SendOutcome` for a replay or a rejection by the text rules
(nothing is stored for those). The server waits up to ~1.8 s for the automatic check; if it takes longer the answer
is `status: "pending"` and the final outcome arrives as the author's `reflection_status` event (§2) and in 1.1.

| Error | When |
|---|---|
| `400 invalid_request` | bad body, bad id, empty, > 200 characters |
| `400 replies_not_supported` | `parentId` / `parent_id` present (P2 hook: text replies are post-v1) |
| `404 not_found` | not a current member of the room, room gone |
| `409 room_read_only` | the room is a memory |
| `409 reflection_id_conflict` | the id belongs to another member or room |
| `429 reflection_room_limit` | 3 reflections by you in this room in the last 24 h ("That's 3 reflections for today. Gestures are always open.") |
| `429 reflection_daily_limit` | 10 reflections by you across rooms in the last 24 h |
| `503 reflections_paused` | kill switch: `reflections_composer` off, your room's language pool paused (flag payload `pausedPools`), or `reduced_mode` on. The app shows "Reflections are resting for a bit. Gestures still work." |

Limits count every reflection you sent in the window **except** rejected and crisis-diverted ones (rejections don't
use up the 3/day, 14-states [ASSUMPTION]); a deleted one still counts.

### 1.4 `DELETE /v1/rooms/:roomId/reflections/:reflectionId` → `204`
Author only (anyone else, or unknown → `404 reflection_not_found`). Published → gone for everyone
(`reflection_removed`); pending / held → withdrawn ("Author can withdraw"). Idempotent. Works in memories. No edit:
to change a reflection, delete it and send a new one.

### 1.5 Gestures on a reflection — `POST /v1/rooms/:roomId/gestures` (v1-rooms.md §1.5, extended)
```json
{ "type": "hug", "target": "reflection", "toReflectionId": "<reflectionId>" }
```
- Same limits, silent drops and `202 { gestureId, at }` answer as every gesture. `toReflectionId` is required for
  `target: "reflection"` and refused for the others (`400 invalid_request`).
- The reflection must be published and visible to you (§1.1) → else `404 reflection_not_found`; your own →
  `400 invalid_target`.
- The recipient is the reflection's author: dropped silently if a block exists either way, the author muted you,
  or the author is hidden. The room sees the usual anonymous `gesture_sent` (with `target: "reflection"` and
  `reflectionId`); the author's member topic gets `gesture_received` with `reflectionId`. **Only the author sees a
  count** (`gestureCount` on their own published reflections).

### 1.6 Reporting a reflection — `POST /v1/safety/reports` (v1-rooms.md §2.1, extended)
```json
{ "target": { "kind": "reflection", "roomId": "<roomId>", "reflectionId": "<reflectionId>" }, "reason": 5, "note": "optional" }
```
- Same reasons, answer (`201 { reportId, showHelplines }`, `200` for a repeat), limits and lanes as every report.
  The reflection must be published and visible to you, or already reported by you → else `404 not_found`; your own
  → `400 invalid_target`. `GET /v1/safety/reports` lists it with `targetKind: "reflection"`.
- It **hides for you at once** (drops out of 1.1). The author is never told who reported.
- **Auto-hide (REQ-REF-06)**: reports from **3 distinct members** (repeats by one member count once; reason 1 "in
  danger" never counts toward hiding), or **1** report for sexual content (3), contact / personal info (5) or
  targeting a young person (9) when the author or that reporter is under 18, hide the reflection for everyone within
  the same request (`reflection_removed`); it waits in the queue for a human (approve restores it).
- The reflection is copied into the evidence store (180 days, encrypted) with its room context.

## 2. Realtime (Supabase Realtime, private Broadcast — v1-rooms.md §3)

IDs only: text is always fetched through §1.1 / §1.2, so blocked pairs never see each other's words.

| Topic | Event | Payload | When |
|---|---|---|---|
| room | `reflection_published` | `{ reflectionId, at }` | a reflection became visible (published, approved by a moderator, restored) |
| room | `reflection_removed` | `{ reflectionId, at }` | deleted by its author, removed by a moderator, auto-hidden by reports |
| room | `gesture_sent` | `{ gestureId, type, target, reflectionId?, at }` | as before; `reflectionId` only for `target: "reflection"` |
| member | `reflection_status` | `{ reflectionId, status, at }` | **your own** reflection changed: `published` · `held` · `rejected` · `removed` · `crisis_diverted` (open the support sheet) |
| member | `gesture_received` | `{ gestureId, type, fromMemberId, fromPseudonym, reflectionId?, at }` | as before; `reflectionId` when the gesture was on your reflection |

On any of these, refetch 1.1 (or 1.2 for one item). A blocked member still receives the id-only room events; the
refetch simply doesn't include the item.

## 3. Moderation pipeline (server; PRD F6 "Moderation pipeline", F9 "Reflection pipeline")

The app runs step 1 first (**nothing leaves the phone** for contact details or links; a crisis-lexicon hit opens the
support sheet at once and the reflection is still sent, so it reaches the crisis lane). The server repeats
everything, in this order — the first rule that decides wins:

1. **Crisis lexicon** (the live signed version, else the bundled baseline; EN, TE, Tenglish, HI, Hinglish) →
   `crisis_diverted`: stored encrypted, never published, crisis lane (L0) item, **never a strike**, `showSupport`.
   Crisis text containing a phone number: crisis wins.
2. **Grooming phrases** (`reflection_filter.v1.json`, all five languages) → `rejected` (`personal_questions`), Minors &
   grooming lane (L1), the author's reflections and gestures are shadow-muted until review [ASSUMPTION, F6].
3. **Contact details / links** (`reflection_filter.v1.json`) → `rejected` (`contact_details` / `link`); nothing is
   stored (REQ-REF-02 negative: the same text sent straight to the API is rejected).
4. **OpenAI omni-moderation** (the only classifier, REQ-REF-07; text only; timeout 5 s):
   - self-harm (any self-harm category) ≥ threshold → `crisis_diverted` (as 1);
   - `sexual/minors` ≥ threshold → `rejected` (`sexual`), Minors & grooming lane, shadow-mute (as 2);
   - any category ≥ its **reject** threshold → `rejected` (`hurtful` / `sexual` / `other`), stored, a lane item so a
     human can confirm a strike (only harassment, hate, sexual and spam can become strikes; F9);
   - error, timeout, or `OPENAI_API_KEY` unset → **`held`** (fail closed; never released by a timeout).
5. **Forced holds**: `hold_all` flag on; the author has an active strike or shadow-mute; the same text by the author
   in more than 2 rooms in 24 h (spam) → `held`.
6. Any category ≥ its **hold** threshold → `held`. **Stricter thresholds** (sexual, harassment; and the stricter
   digit rule for contact details) when the author or any current member of the room is under 18, and in the Telugu
   + Tenglish and Hindi + Hinglish pools (REQ-REF-08, invisible). **Overnight** (00:30–07:30 IST [ASSUMPTION]) only
   text rated clean with high confidence publishes; everything else waits for the morning.
7. Otherwise → `published` (broadcast `reflection_published`).

Held items wait for a human (or expire unpublished when the room becomes a memory). **Nothing publishes without a
server or moderator decision** (REQ-REF-03). A pending item older than 60 s (process restart) is held by the worker.
Thresholds live in `public.reflection_config` (tunable without a release). The composer's **kill switch** trips
automatically for a language pool with more than 50 held items [ASSUMPTION]; AK resumes it in the console.

## 4. Admin console (NestJS `/admin/reflections*`, AdminGuard; Owner + Moderator unless noted; every action audited)

Held, crisis-diverted, rejected-for-review and reported reflections are **also** normal items in the report queue
(`/admin/queue`, `targetKind: "reflection"`; automatic items have `source: "auto"` and `autoSignal` ∈
`reflection_hold` · `reflection_crisis` · `reflection_minor_safety` · `reflection_violation`). The reflection routes
show the text and apply the reflection decisions:

- `GET /admin/reflections?status=held|pending|published|rejected|crisis_diverted|removed|all&limit=` (limit 1–500, default 200;
  `held` also lists published items hidden by reports) →
  `{ items: ReviewItem[], pools: PoolState[] }` (oldest first for held / pending, else newest first).
- `GET /admin/reflections/:reflectionId` → `ReviewView`: the text (decrypted by NestJS, never logged), status,
  hold / reject reason, omni-moderation scores, matched rule ids (never the matched words), stricter-threshold and
  overnight flags, room context (quadrant, pool, region, age, the room's other published reflections), the author as
  pseudonym + hashed id + account age + "Under 18" flag + strike history (never the DOB, email or account id), every
  report on it (lane, reason, source, status) and its audit trail. Opening it counts toward the 2-hour queue session
  unless a linked report is urgent (crisis or paging).
- `GET /admin/reflections/by-report/:reportId` → `{ reflectionId }` (from the report page).
- `POST /admin/reflections/:reflectionId/decision`
  ```json
  { "decision": "approve" | "remove" | "escalate", "reasonCode": "no_violation", "strike": false,
    "rejectReason": "hurtful", "lane": "minors_grooming" }
  ```
  - `approve`: held / pending / rejected / crisis-diverted ("release as a false positive") / removed / auto-hidden →
    published (`reflection_published`, author's `reflection_status`); its open reports close as reviewed, no action,
    and an automatic shadow-mute from them is lifted. Refused for a room that is already a memory
    (`409 room_read_only`) and for deleted / expired items (`409 not_reviewable`).
  - `remove`: held / pending → `rejected` (author sees `rejectReason`, default `other`); published → `removed`
    (`reflection_removed`); crisis-diverted stays unpublished ("keep unpublished"). Open reports close as actioned.
    `strike: true` first adds a strike through the ladder (`ModerationService.act`) on the item's open report — refused
    with `409 crisis_never_strikes` for crisis items.
  - `escalate`: moves the item's open report to a higher lane (`lane`: `minors_grooming` or `crisis`), recomputes its
    SLA and pages the Owner when the new lane pages (PRD 19 "Escalate").
  - `reasonCode`: `[a-z0-9_]{1,40}`, required; goes to the audit log.
- `POST /admin/reflections/pools/:pool/pause` / `.../resume` (Owner; `pool` ∈ `en` · `te` · `hi`, body
  `{ reasonCode }`) → `204`: the per-pool kill switch (`reflections_composer.payload.pausedPools`).

```ts
type AdminStatus = 'pending' | 'published' | 'held' | 'rejected' | 'crisis_diverted' | 'removed' | 'deleted' | 'expired';
type ReviewItem = {
  reflectionId: string; status: AdminStatus;
  hidden: boolean;                   // published but hidden by the report threshold (waits for a human)
  holdReason: HoldReason | null; rejectReason: RejectReason | null;
  text: string | null;               // decrypted by NestJS; null once scrubbed (deleted / expired)
  charCount: number; languagePool: 'en' | 'te' | 'hi';
  strict: boolean;                   // stricter thresholds applied (under-18 involved or te / hi pool)
  overnight: boolean;                // decided inside the overnight window
  involvesMinor: boolean;            // the console's "Under 18" flag — never a DOB
  createdAt: string; decidedAt: string | null; decidedBy: string | null;
  room: { roomId: string; quadrant: string; tzRegion: string; state: string } | null;   // null once purged
  report: { reportId: string; lane: Lane; reasonKey: string; source: 'user' | 'auto'; autoSignal: string | null;
            slaDueAt: string; pages: boolean; overdue: boolean } | null;              // the most urgent OPEN report
};
type ReviewView = ReviewItem & {
  scores: Record<string, number> | null;   // omni-moderation category scores (null: never classified)
  ruleHits: string[];                      // rule ids (e.g. "phone_digits", "en.ask_age", "crisis_lexicon")
  stage: 'rules' | 'provider' | 'human' | 'author' | 'system' | null;
  publishedAt: string | null; removedAt: string | null; hiddenAt: string | null;
  gestureCount: number;
  supportShown: boolean;                   // US-42: a crisis diversion opened the support sheet for the author
  author: { pseudonym: string; hash: string | null; accountAgeDays: number | null; under18: boolean;
            activeStrikes: number; strikes: Array<{ strikeId: string; reasonCode: string; createdAt: string; expiresAt: string; active: boolean }>;
            sanctions: Array<{ sanctionId: string; kind: string; reasonCode: string; source: string; startsAt: string; endsAt: string | null; active: boolean }>;
            otherReports: Array<{ reportId: string; lane: Lane; reasonKey: string; status: string; createdAt: string }> };  // US-42 recent flags
  roomContext: { roomId: string; quadrant: string; languagePool: string; tzRegion: string; ageHours: number; state: string;
                 memoryAt: string; purgeAt: string;
                 others: Array<{ reflectionId: string; pseudonym: string; text: string | null; publishedAt: string }> } | null;
  reports: Array<{ reportId: string; lane: Lane; reasonKey: string; source: 'user' | 'auto'; autoSignal: string | null;
                   status: 'open' | 'actioned' | 'dismissed'; createdAt: string; slaDueAt: string; pages: boolean }>;
  audit: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null }>;
  allowedDecisions: Array<'approve' | 'remove' | 'escalate'>;   // for this staff member and this item
  canStrike: boolean;                                           // an open, non-crisis report exists
};
type PoolState = { pool: 'en' | 'te' | 'hi'; paused: boolean; held: number };
type DecisionResult = { reflectionId: string; previousStatus: AdminStatus; status: AdminStatus; hidden: boolean;
  reportsResolved: number; sanctionsLifted: number;
  strike: { activeStrikes: number | null; autoBan: boolean } | null;
  escalated: { reportId: string; lane: Lane; pages: boolean } | null };
```
`HoldReason` ∈ `uncertain` · `strict_threshold` · `overnight` · `provider_unavailable` · `timeout` · `hold_all` ·
`active_strike` · `sanction` · `near_duplicate` · `reported` (hidden by reports). Errors: `400 invalid_request`,
`403 forbidden_role` (audited), `404 not_found`, `409 not_reviewable` · `room_read_only` · `crisis_never_strikes` ·
`no_open_report` (escalate / strike without an open report) · `invalid_lane` (escalating sideways or down).

## 5. Codes introduced here
`replies_not_supported`, `reflection_id_conflict`, `reflection_not_found`, `reflection_room_limit`,
`reflection_daily_limit`, `reflections_paused` (plus `invalid_request`, `invalid_target`, `not_found`,
`room_read_only`, `rooms_suspended`, `account_closed` from v1 / v1-rooms). Admin: `not_reviewable`,
`crisis_never_strikes`, `invalid_lane`, `no_open_report`.

## 6. Flags (GET /v1/config, v1.md "Remote config")
| Key | Default | Off / set means | Enforced by the server |
|---|---|---|---|
| `reflections_composer` | on, `payload: { "pausedPools": [] }` | off: no new reflections anywhere; a pool in `pausedPools`: none in that language pool | `POST …/reflections` → `503 reflections_paused` |
| `reduced_mode` | off | on: reflections paused (as above) while AK is unreachable (PRD 19); gestures, check-ins, crisis support keep working | same |
| `hold_all` | off | on: every new reflection is held for a human within 60 s of the flip (REQ-SAFE-10); gestures unaffected | the pipeline (step 5) |

The app hides the composer when `reflections_composer` is off, `reduced_mode` is on or its pool is paused, but the
`composer.state` from §1.1 is the answer that counts.
