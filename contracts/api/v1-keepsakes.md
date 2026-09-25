# Aura API v1 — Keepsakes and share cards (F13, Milestone C)

PRD 06a "F13 Share cards & Keepsakes"; REQ-SHR-01…06; 21-open-questions CI-8 (AK: **keepsakes are never visible to
strangers**). Rules (catalogue, thresholds, dating, share prompt): `contracts/rules/RULES.md` §11 +
`contracts/rules/vectors/keepsakes.json`. Schema: `supabase/migrations/20261005000026_keepsakes.sql`. Server:
`server/aura-api/src/keepsakes`. App: `apps/mobile/lib/src/features/keepsakes`, `…/features/share`.

Self-contained on purpose: keepsakes and share cards are a scope-cut lever (PRD 20-timeline, levers 2 and 8). Nothing
else in the server imports the keepsakes module, and no other response mentions keepsakes.

## 1. What a keepsake is

An **earned-only seal**: a catalogue key and the Aura day it was earned. Nothing else is stored — no link to rooms,
pseudonyms, capsules or content (PRD "stored as a key and a date only").

| key | earned when |
|---|---|
| `capsule_sealed_first` | the first capsule is sealed |
| `capsule_opened_first` | the first capsule is opened |
| `glow_days_7` · `glow_days_30` · `glow_days_100` · `glow_days_365` | 7 / 30 / 100 / 365 lifetime glow days |
| `ripples_first` | the first Breath Ripples session (a human seat in a session that has ended) |
| `lantern_hours_1` · `lantern_hours_10` · `lantern_hours_50` | the first, 10th and 50th Lantern Hour spent in a room |
| `sanctuary_minutes_60` · `sanctuary_minutes_300` · `sanctuary_minutes_1000` | 60 / 300 / 1,000 Sanctuary minutes |

- **Awarded by NestJS** from records it already holds (capsule metadata, `active_days`, Breath Ripples seats, Lantern
  Hour room memberships, `sanctuary_sessions`), never from anything the app claims. No endpoint grants one.
- **Never sold:** no SKU, Stardust, Plus perk or gift grants one (REQ-SHR-05; `billing/catalogue.ts` has no such item
  and a unit test fails if any non-keepsake server module mentions keepsakes). No Starlight or Stardust comes with one.
- **Never lost:** deleting the source (a capsule, a check-in), a refund, a downgrade or a purged room never removes
  one. The table refuses updates and refuses deletes while the account lives; the account purge (deletion due) and
  the auth-user cascade are the only ways a row goes.
- **Past activity:** the first worker run after F13 ships awards everyone for records that still exist. Rooms are
  purged 7 days after they close, so Lantern Hours count only from what is still recorded (PRD `[ASSUMPTION]`).
- **When:** `GET /v1/keepsakes` awards anything newly reached for the caller before answering (so the app sees a new
  seal right after its sync), and the worker (queue `keepsakes`) awards everyone with recent records every 5 minutes
  and everyone once at start-up and daily. Awarding is idempotent (per-user lock; `on conflict do nothing`; the
  Lantern Hour tally only counts nights after its watermark).

## 2. `GET /v1/keepsakes`

The caller's own keepsakes. Auth: Supabase JWT (like every `/v1` route; `403 account_deletion_pending` and
`403 account_closed` apply). `Cache-Control: no-store`.

```json
200 { "keepsakes": [ { "key": "capsule_sealed_first", "earnedOn": "2026-10-05" },
                     { "key": "glow_days_7", "earnedOn": "2026-10-12" } ] }
```

- Catalogue order (§1). `earnedOn` is the Aura day (`YYYY-MM-DD`, the profile's zone). No other field, ever.
- No profile yet → `200 { "keepsakes": [] }` (nothing to award, nothing written).
- **There is no way to ask about anyone else:** the route takes no path or query parameter that selects a person
  (`GET /v1/keepsakes/<id>` → 404; `?userId=` is ignored). No room, member sheet, reflection, Breath Ripples or Quiet
  Together response carries a keepsake field (REQ-SHR-06; contract tests in `test/unit/keepsakes.spec.ts` and
  `test/e2e/keepsakes.e2e-spec.ts`).
- The same rows are readable by the owner through Supabase select-own (`public.keepsakes`, RLS `own_read`); the app
  uses this route because it also awards. `public.keepsake_tallies` is server-only.

## 3. Share cards (on device only — no endpoint)

Share cards are made and shared on the phone; the server is never told (REQ-SHR-03: no reward for sharing, nothing to
record). Card types: **evolution** (Ember → Constellation), **glow milestone** (7 / 30 / 100 / 365 lifetime days),
**capsule anniversary** ("Sealed a capsule 1 year ago"), **keepsake** (the seal and its line).

- Rendered from the avatar renderer's Still tier into a 1080×1920 PNG (retry at 720×1280 on failure), offline too.
- **Binds only whitelisted fields** (REQ-SHR-02): stage, rings, glow, constellation stars and equipped cosmetics of
  the avatar; the milestone (type + value); the wordmark; the store link. **Never** moods, quadrants, the mood-derived
  hue (cards use the template's fixed palette), tags, notes, capsule text, dates, streak count, pseudonyms, usernames,
  ages or ids.
- Shared through the OS share sheet only (`share_plus`; its "Save image" covers saving — no photo-library
  permission). No social SDKs, no pixels, no analytics events.
- **Link:** the store link carries a random share token (not derived from the user id) for adults; an under-18
  account (or one whose age is unknown on this phone) shares the plain link with no token. The card image is
  identical either way, and sharing is never hidden or limited by age (REQ-SHR-04).
- **Prompt:** offered once per milestone; several at once → one prompt for the highest (RULES.md §11
  `share_prompt`). A new keepsake shows once as a small card on Home.
