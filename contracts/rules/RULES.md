# Aura progression rules (v1) — the single source of truth

Implemented twice: **Dart** (`packages/aura_domain`, used offline by the app) and **TypeScript** (`server/aura-api`, authoritative, DS-5).
Both implementations MUST pass every case in `contracts/rules/vectors/*.json`. Change a rule here + in the vectors first, then both code paths.

## 1. Aura day (`aura_day.json`)
`auraDay(instantUtc, ianaTz) = date( toLocal(instantUtc, ianaTz) − 4h )`. The day rolls over at **04:00 local**.

## 2. Credit eligibility (`eligibility.json`)
An event (check-in or habit completion) earns Starlight and streak credit only if ALL hold:
- `deviceTs ≤ serverNow + 5 min` (not future-dated beyond clock skew)
- `serverNow − deviceTs ≤ 30 days` (not stale)
- `localDay == auraDay(deviceTs, tz)` (not a backfill; backfills up to 7 days are stored but earn nothing)

Ineligible events are still stored; they just award 0 and are not active-day evidence.

## 3. Starlight per aura day (`starlight.json`)
Process a day's eligible events in `deviceTs` order:
- check-in #1 → **10**; check-ins #2 and #3 → **2** each; #4+ → 0
- habit completion → **5**, once per `habitId` per day; repeats → 0
- **daily cap 60**: an award is reduced so the day's total never exceeds 60
- ineligible events → 0 and do not consume a check-in slot

## 4. Stage & constellation (`stage.json`)
Total Starlight (all-time, never decreases) → stage:
`spark` 0 · `ember` 100 · `glow` 400 · `radiance` 1,200 · `constellation` 3,000.
`constellationStars = total ≥ 3000 ? min(12, floor((total − 3000) / 500)) : 0`.

## 5. Traits (`traits.json`)
`ringCount` from lifetime **Breathe** completions, `glowLevel` from lifetime **Sleep on time** completions: thresholds 5 / 20 / 50 → 0–3. Permanent.

## 6. Hue (`hue.json`)
Circular weighted mean of the last 14 aura days' check-in quadrants:
Sunrise **45°**, Rain **175°**, Moonlight **210°**, Storm **275°**.
`x = Σ w·cos θ`, `y = Σ w·sin θ`; `hue = atan2(y, x)` in [0, 360). If there are no check-ins, or `hypot(x, y) < 1e-9`, return `null` (renderer holds the previous hue). Tolerance in vectors: ±0.5°.

## 7. Glow streak & rest days (`streak.json`)
State: `{glowStreak, lifetimeGlowDays, restBank, earnCounter, lastActiveDay}`; new users start `{0, 0, 1, 0, null}` (1 welcome rest day).
Fold over **distinct active aura days in ascending order** (input may be unsorted or contain duplicates):
1. If `lastActiveDay == null` → `glowStreak = 1`.
   Else `gap = days(day − lastActiveDay) − 1`:
   - `gap == 0` → `glowStreak += 1`
   - `1 ≤ gap ≤ restBank` → `restBank −= gap`; `glowStreak += 1` (rest days bridge, add nothing)
   - `gap > restBank` → `glowStreak = 1`; **nothing is spent**
2. `lifetimeGlowDays += 1`
3. Earning: if `restBank < 3` → `earnCounter += 1`; when it reaches 4 → `restBank += 1`, `earnCounter = 0`. While `restBank == 3` the counter is paused (unchanged).
4. `lastActiveDay = day`

## 8. Resting Nebula (`nebula.json`)
`isResting = lastActiveDay != null && days(currentAuraDay − lastActiveDay) ≥ 3`
(last active Monday → resting from Thursday 04:00; not on Wednesday 23:00).

## 9. Time capsules (`capsules.json`, F4)
Pure functions on device (offline unlock, triggers) and server (validation, the unlock push). Every case has a `kind`:

- **`window`** — `isValidUnlockDate(sealedAt, tz, unlockLocalDate)`:
  `sealDate = localDate(sealedAt, tz)` — the **calendar date** in the zone the device was in (no 04:00 shift).
  Valid iff `addDays(sealDate, 7) ≤ unlockLocalDate ≤ addYears(sealDate, 5)`; `addYears` keeps month and day and
  clamps Feb 29 → Feb 28. (The server additionally refuses dates > 5 years + 2 days past its own date — a broken-clock guard.)
- **`unlock_at`** — `unlockAt(localDate, tz)` = the instant the wall clock in `tz` reads **10:00** on `localDate`.
  If 10:00 does not exist that day (DST gap) it is shifted forward by the gap; if it occurs twice, the earlier
  instant. Always evaluated in the user's **current** zone, so a timezone change moves the unlock to 10:00 in the
  new zone. A date capsule is **due** when `now ≥ unlockAt(unlockLocalDate, currentTz)`.
- **`trigger`** — `pickTrigger(capsules, checkIn)` → `{ fire: id | null, hold: id | null }`, evaluated on device
  after a check-in is saved (`checkIn = { moodId, quadrant, deviceTs, live, crisis }`):
  1. `live == false` (a backfill) → `{ fire: null, hold: null }`.
  2. `cooldownUntil = max(c.cooldownUntil)` over **all** capsules, deleted ones included;
     `checkIn.deviceTs < cooldownUntil` → nothing.
  3. Candidates: `unlockType == "mood"`, `deletedAt == null`, `firedAt == null`, `openedAt == null`,
     `armedAt ≤ checkIn.deviceTs`, and (`triggerMoodId == checkIn.moodId` or `triggerQuadrant == checkIn.quadrant`).
  4. Pick the oldest by `armedAt`, then `sealedAt`, then `id` (plain string order).
  5. `crisis` (lexicon hit or "I need help now") → `{ fire: null, hold: pick }`; otherwise `{ fire: pick, hold: null }`.

Related rules (state transitions, not vectors): `armedAt = sealedAt + 24 h`; a re-arm ("Keep for next time") sets
`armedAt` = the re-arm time. A fire at `t` sets that capsule's `cooldownUntil = t + 168 h` (7 × 24 h, absolute —
REQ-CAP-03: fired Mon 09:00 → nothing fires before the next Mon 09:00). When two devices fire the same capsule
offline, the earliest `t` wins and the cooldown starts from it. Instants compare as instants (offsets respected).
