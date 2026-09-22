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
