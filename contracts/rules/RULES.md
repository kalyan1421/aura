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
State: `{glowStreak, longestGlowStreak, lifetimeGlowDays, restBank, earnCounter, lastActiveDay}`; new users start `{0, 0, 0, 1, 0, null}` (1 welcome rest day).
Fold over **distinct active aura days in ascending order** (input may be unsorted or contain duplicates):
1. If `lastActiveDay == null` → `glowStreak = 1`.
   Else `gap = days(day − lastActiveDay) − 1`:
   - `gap == 0` → `glowStreak += 1`
   - `1 ≤ gap ≤ restBank` → `restBank −= gap`; `glowStreak += 1` (rest days bridge, add nothing)
   - `gap > restBank` → `glowStreak = 1`; **nothing is spent**
2. `lifetimeGlowDays += 1`
3. Earning: if `restBank < 3` → `earnCounter += 1`; when it reaches 4 → `restBank += 1`, `earnCounter = 0`. While `restBank == 3` the counter is paused (unchanged).
4. `longestGlowStreak = max(longestGlowStreak, glowStreak)` (F3 "Longest streak lives only in Insights": never on Home, never in a push or share card; it never decreases)
5. `lastActiveDay = day`

A state read without `longestGlowStreak` (older snapshots) takes `longestGlowStreak = glowStreak`.

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

## 10. Insights — Aura Sky (`insights.json`, F10)
Pure functions over the person's **own local data**, run **on the device only** (PRD F10: "computed on device and
never uploaded"). The TypeScript copy exists so both engines keep passing the vectors; no endpoint uses it.
Every case has a `kind`. Inputs: check-ins `{localDay, quadrant, tags?, deviceTs?, tzOffsetMinutes?}` (live rows
only — deleted entries leave the sky) and habit logs `{habitId, localDay}`. A window is `[from, to]` in Aura days,
inclusive, matched on each row's stamped `localDay` (never recomputed, so a timezone change moves no entry).
`today = auraDay(now, currentTz)` (§1).

- **`part`** — a check-in is **live** iff it has `deviceTs` and `tzOffsetMinutes` and
  `localDay == date(deviceTs + tzOffsetMinutes − 4h)` (the wall clock it was stamped at; a backfill fails this).
  Only live check-ins have a part of the day, from the local hour `h` of `deviceTs + tzOffsetMinutes`:
  `morning` 4 ≤ h < 12 · `afternoon` 12 ≤ h < 17 · `evening` 17 ≤ h < 21 · `night` otherwise (21:00–03:59, so a
  01:30 check-in is the night of the Aura day before).
- **`day_star`** — `dayStar(quadrants, rest)`: no check-ins → `rest` if the day is a rest day, else `empty` (plain
  sky; never grey or crossed out). Otherwise the quadrant(s) with the highest count, in catalogue order
  (storm, rain, moonlight, sunrise): one → `single`, a tie → `split` (all tied quadrants). Check-ins win over `rest`.
- **`rest_days`** — `restDays(activeDays)`: fold §7 from the new-user state over the distinct active days in
  ascending order; whenever a gap is bridged (`1 ≤ gap ≤ restBank`), each day of that gap is a rest day. Returns
  them ascending. (On the device, active days are the live check-in and habit days, deleted ones included.)
- **`week`** — weeks start on `weekStartsOn` (ISO 1 = Monday, the default; 7 = Sunday).
  `weekStart = today − ((isoWeekday(today) − weekStartsOn + 7) mod 7)`. The **weekly card** covers the week just
  ended, `[weekStart − 7, weekStart − 1]`, from the first Aura day of the week (Monday 04:00 local) until the next.
- **`month`** — `monthStart` = the 1st of today's month; **Your month in stars** recaps the previous calendar month
  `[1st of previous month, monthStart − 1]` from the first Aura day of the month (1st, 04:00 local).
- **`gate`** — in the window, `N` check-ins over `D` distinct days: `N < 7` → `need_checkins`; else `D < 5` →
  `need_days`; else `ok`. Returns `{status, checkIns: N, days: D}` (the "4/7" counter).
- **`patterns`** — `findPatterns(checkIns, habitLogs, from, to, includeHabits)`; empty unless the gate is `ok`.
  - **Contrast** (tag, habit and time patterns). A population of check-ins is split by a context X into `in` and
    `out`. X passes with quadrant Q iff: `in` spans **≥ 3 distinct days**; `n_out ≥ 3`; `k_in ≥ 3` (in-check-ins
    with Q); and the lift `k_in/n_in − k_out/n_out ≥ 1/4`, compared exactly in integers:
    `4·(k_in·n_out − k_out·n_in) ≥ n_in·n_out`. Per context only the **best** quadrant is kept (largest lift, then
    larger `k_in`, then catalogue order). Only "more often" is ever expressed; there is no "less often" pattern.
  - `tag_quadrant` — needs `N ≥ 14`; one context per distinct tag string: `in` = check-ins carrying the tag.
  - `habit_quadrant` — only when `includeHabits` (Plus); needs `N ≥ 14`; one context per habit with logs in the
    window: `in` = check-ins on a day that habit was logged.
  - `time_of_day` — population = the window's **live** check-ins; one context per part of the day.
  - `quadrant_mix` — over all window check-ins: the top quadrant must be unique, hold **≥ 40 %**
    (`5·top ≥ 2·N`) and lead the second by **≥ 2**.
  - **Order:** contrast patterns by lift descending (exact: `numA·denB` vs `numB·denA`), then `k_in` descending,
    then kind (`tag_quadrant`, `habit_quadrant`, `time_of_day`), then key ascending (plain string order; the key
    is the tag, the habit id or the part name). `quadrant_mix` (at most one, `key: null`) comes last.
- **`weekly`** — the first pattern of the week-just-ended window (above), or `null`. Free: `includeHabits = false`.
- **`month_recap`** — for the previous month: `{month: "YYYY-MM", from, to, checkIns, daysCheckedIn,
  quadrantCounts}`. (Lifetime glow days come from §7, not from here.)
- **`care`** — window `[today − 13, today]`: `N ≥ 7` and ≥ 80 % Storm or Rain (`5·(storm + rain) ≥ 4·N`).

Copy is descriptive only ("more often"), never causal, never a number, percentage, score, label or diagnosis
(REQ-INS-03); every quadrant uses the same template.

### 10.1 Look back (`look_back.json`, F10 · Milestone C)
The sky from the same week 1 month, 6 months and 1 year ago, **pull-only** inside Insights (never pushed, never on
Home, the widget, a notification or a share card; REQ-INS-08). Free: Look back is on the never-paywalled list (PRD
F12). On device only, like §10; the TypeScript copy exists only to keep the engines in step. Every case has a `kind`:

- **`add_months`** — `addMonthsClamped(day, n)`: move the year/month by `n` calendar months (negative = back) and keep
  the day of the month, clamped to the target month's length: 31 Mar − 1 → 28 Feb (29 Feb in a leap year);
  31 Oct − 1 → 30 Sep; 31 Aug − 6 → 28 Feb; 29 Feb − 12 → 28 Feb; 29 Feb − 48 → 29 Feb.
- **`windows`** — `today = auraDay(now, currentTz)` (§1: 04:00 rollover, so 03:59 still belongs to the day before).
  For `m` in `[1, 6, 12]`: `anchor = addMonthsClamped(today, −m)`, `from = weekStart(anchor)` (§10 `week`,
  `weekStartsOn` default ISO 1 = Monday), `to = from + 6`. Returns `{today, windows: [{months, anchor, from, to}]}`.
  Entries are matched on their **stamped** `localDay` (never recomputed), so a timezone change only moves `today`.
- **`gate`** — `lookBackGate({now, checkIns, helpAt, hidden})`, evaluated on the device, in this order:
  1. `hidden` (Settings › Look back off) → `{status: "off", until: null}`.
  2. `helpAt` = the last time a crisis sheet or the Safety Center opened **on this phone** (device-only, never sent
     to the server, DS-7). `now < helpAt + 24 h` → `after_help`.
  3. Any Storm or Rain check-in made at `t` (`deviceTs`; deleted ones and backfills count, since it is the moment
     that matters) with `now < t + 3 h` → `after_heavy`.
  4. Otherwise `{status: "open", until: null}`.
  `until` = the latest end among the gates in force (so the UI knows when to look again). Instants compare as
  instants (offsets respected); a time in the future (clock skew) keeps Look back hidden. Exactly 3 h / 24 h → open.
  While not `open`, Look back is absent from Insights (no card, no message about why).
- **`sky`** — `lookBackSky(from, to, entries, restDays)`. An entry `{id, localDay, quadrant, deviceTs, deleted?,
  lexiconCrisis?, helpOpened?, noteUnreadable?}` **shows** iff none of the flags is set:
  `lexiconCrisis` — the crisis lexicon matches its note, **re-run on the device when it is displayed**;
  `helpOpened` — the device-only flag kept when help was opened from that check-in; `noteUnreadable` — it has a
  note this phone can't decrypt, so the lexicon couldn't check it; `deleted` — deleted entries leave Look back.
  For each day `from..to`: its showing entries in `deviceTs` order (then `id`), and its star = §10 `day_star` over
  their quadrants with `rest = day ∈ restDays` (a day whose only entries were left out is plain sky, never a hint of
  them). `visible` = at least one entry shows; a week that isn't visible is left out of the screen.

Tapping a day lists its entries (mood, glyph, time); a note or voice note opens **only on a further tap** of that
entry, and the lexicon is re-run on the note right then.

## 11. Keepsakes and share milestones (`keepsakes.json`, F13 · Milestone C)
Keepsakes are **earned-only seals** (PRD F13 "Keepsakes"). NestJS awards them from records it already holds
(authoritative, like `avatar_state`); the app only shows them. Share milestones are evaluated on the device (the one
Home share prompt). Contract: `contracts/api/v1-keepsakes.md`. Every case has a `kind`; the file's `catalogue` is the
list below, in display order.

| key | source | amount per event | threshold |
|---|---|---|---|
| `capsule_sealed_first` | `capsuleSeals`: capsules sealed (tombstones too) | 1 | 1 |
| `capsule_opened_first` | `capsuleOpens`: capsules opened | 1 | 1 |
| `glow_days_7` · `_30` · `_100` · `_365` | `glowDays`: lifetime glow days = distinct active days (§7) | 1 per distinct day | 7 · 30 · 100 · 365 |
| `ripples_first` | `rippleSessions`: a human seat in a Breath Ripples session that has ended | 1 | 1 |
| `lantern_hours_1` · `_10` · `_50` | `lanternNights`: Lantern Hour nights spent in a room (below) | 1 | 1 · 10 · 50 |
| `sanctuary_minutes_60` · `_300` · `_1000` | `sanctuarySeconds`: Sanctuary session records (`duration_s`) | seconds | 3,600 · 18,000 · 60,000 s |

- **`earned`** — `earnedKeepsakes(sources)`: each source is an unsorted list of events `{day, amount}` (Aura days).
  Events with `amount ≤ 0` are ignored; a glow day counts **1 per distinct day** whatever its amount. `lanternCounted`
  (default 0) is the Lantern Hour tally already counted before these events (the rooms it came from may be purged).
  For every threshold `T` of a source with `T > counted` (`counted` = `lanternCounted` for `lanternNights`, else 0):
  stable-sort the events by day, run a total from `counted`, and the keepsake's **day** is the day of the first event
  at which the total reaches `≥ T`. Unreached thresholds give nothing. Result: `[{key, day}]` in catalogue order.
  (Vector shorthand: `glowDaysRange: {from, count}` = `count` consecutive days from `from`, amount 1.)
- **`capsule_years`** — `capsuleYears(firstSealed, today)`: the number of anniversaries of the first seal's day that
  are `≤ today` (anniversary `y` = `addYears(firstSealed, y)`, §9: Feb 29 → Feb 28). `null` or a future first seal → 0.
- **`share_prompt`** — `sharePrompt({stage, lifetimeGlowDays, capsuleYears, offered, hideGlow})` → `{prompt, offer}`.
  Milestone ids, in candidate order: `evolution:<stage>` for every stage from `ember` up to `stage` (§4 order);
  `glow:<n>` for `n ∈ [7, 30, 100, 365]`, `n ≤ lifetimeGlowDays`; `capsule_anniversary:<y>` for `y ∈ 1..capsuleYears`.
  `offer` = the candidates not in `offered`, in candidate order — **all** of them are marked offered together, so each
  milestone is offered once and several at once make one prompt. `prompt` = the highest of `offer`: the latest
  evolution, else the largest glow (never when `hideGlow`, Comfort › hide streak number), else the latest capsule
  anniversary; `null` when none.

Server days (not vectors): a seal / open = `auraDay(sealed_at / opened_at, profile tz)`; a glow day = its
`active_days.local_day`; a Breath Ripples session = `auraDay(ended_at)`; a Lantern Hour night = `auraDay(lantern_hour_at)`;
a Sanctuary record = its `local_day`. **Lantern Hour nights:** distinct `rooms.lantern_hour_at` of rooms whose Lantern
Hour window (`lantern_hour_at + (lantern_end − lantern_start)`) has ended and in which the person was a member during
it (`joined_at < window end` and `coalesce(left_at, last_seen_at) ≥ lantern_hour_at`). Rooms are purged 7 days after
they close, so NestJS keeps a per-person tally (`keepsake_tallies.lantern_nights`, `lantern_through` = the latest
night counted): only nights after `lantern_through` are new, so nothing is counted twice and nothing counts before
it was recorded (PRD: "Lantern Hour seals count only from when they are recorded").

Stored once per (person, key) with the day computed the first time (`on conflict do nothing`); **never revoked**:
deleting a capsule or check-in, a refund, a downgrade or a purged room never removes one, and no purchase, gift,
Stardust or Plus perk grants one (REQ-SHR-05). Nothing (Starlight, Stardust) comes with a keepsake, and nothing comes
with sharing (REQ-SHR-03).

## 12. Minimum app version (`app_version.json`, MASVS F-6)

`GET /v1/config` `minAppVersion` (per platform) against the installed version. Format
`MAJOR[.MINOR[.PATCH]][+BUILD]` (1–5 digits per part, build 1–9 digits, surrounding spaces trimmed); anything else
parses to nothing. Compare numerically part by part, missing parts are 0; the build number breaks a tie **only when
both sides have one**. An update is required only when both versions parse and the installed one is lower
(fail open: an unreadable version on either side never blocks the app). Dart: `packages/aura_domain`
`app_version.dart`; TS: `server/aura-api/src/remote-config/app-version.ts`.

## 13. World objects: growth and opt-in decay (`world.json`, presentation-only)

Rules for how a habit appears in the personal 3D world (see `docs/releases/NEXT_RELEASE_PLAN.md`, "Revision 29 Sep"). They run
**on the device only** and read the person's own habit logs; the TypeScript copy exists so both engines keep passing the vectors,
and no endpoint uses it. **They never touch the ledger:** nothing here awards Starlight, changes a stage, glow streak, rest bank,
keepsake or share milestone, and nothing here is pushed or shared. A world object is a *view* of habit logs. Every case has a `kind`.

- **`stage`** — `growthStage(distinctLoggedDays)`: the number of distinct Aura days on which the habit has a live (not deleted)
  log, matched on each log's stamped `localDay`. `seed` 0 · `sprout` 1 · `young` 4 · `grown` 10 · `flourishing` 25 · `ancient` 60.
  Growth is **permanent progress**: it depends only on the count, so a missed day can never lower it. (Deleting a log lowers the
  count, exactly as the log itself is gone; that is a correction, not a penalty.)
- **`eligible`** — `decayEligible({optedIn, ageYears})` = `optedIn && ageYears ≥ 18`. Decay is **off by default, chosen by the
  person, and never available under 18** (owner default, PRD D2; revisit only with a product and safety decision). A person who is
  not eligible sees every object `thriving`, whatever they have logged.
- **`vitality`** — `habitVitality({decayActive, committedFrom, lastLogDay, pausedThrough, today})`. The per-habit **commitment**
  ("Treat this as a commitment") *is* the opt-in: there is no separate global setting to sync. `decayActive` is
  `decayEligible(optedIn: the person has at least one commitment, ageYears)`; it stores nothing and only adds the age gate.
  The columns are `habits.committed_from` / `habits.paused_through` (W02, migration `…36_habit_commitments`; server refuses a
  minor's commitment: `contracts/api/v1.md`). If `decayActive` is false or `committedFrom` is null → `thriving`. Otherwise `anchor` = the latest of `committedFrom`, `lastLogDay` and `pausedThrough` (nulls ignored), and
  `gap = max(0, days(today − anchor) − 1)`: whole Aura days missed, so *today* (still open) and the day after a log never count.
  `thriving` gap 0–1 · `dimmed` 2–3 · `wilting` 4–6 · `dormant` ≥ 7. Nothing is lower than `dormant`: an object never disappears,
  never loses its growth stage and is never deleted. **One log today restores `thriving` at once** (gap 0). `pausedThrough` is a
  person-chosen pause (holiday, illness): while `today ≤ pausedThrough` the anchor is at least today, so nothing decays.
  Rest days (§7) do **not** bridge vitality: the stakes are the person's own choice, unlike the automatic Resting Nebula, which
  this rule never reads or changes. Copy for `dimmed`/`wilting`/`dormant` is descriptive and warm ("resting", "waiting for you"),
  never "dead", "lost" or a number of missed days.
- **`welcome`** — `showWelcomeBack({lastActiveDay, today, shownFor})` (W04): the one-time "Your world is here" card in the personal
  universe. True iff the person is resting (§8: `lastActiveDay != null` and `days(today − lastActiveDay) ≥ 3`) **and**
  `shownFor != lastActiveDay`. `shownFor` is the `lastActiveDay` the card was last shown for (device-only, never pushed), so it
  appears **once per absence**: coming back and being active moves `lastActiveDay`, so a later absence shows it again, and merely
  leaving and re-opening the universe never repeats it. A new person (`lastActiveDay == null`) never sees it. Copy is warm and
  never mentions days away, streaks, loss or what was missed; it works with Comfort › hide streak number because it shows no number.
- **`sky`** — `skyPhase(localHour)` (W06): the personal universe's sky follows the phone's own wall clock, so it needs no location
  and no permission. `localHour` is 0–23 in the device zone (any integer is normalised mod 24). `dawn` 5 ≤ h < 7 · `day` 7 ≤ h < 17 ·
  `dusk` 17 ≤ h < 19 · `night` otherwise. Latitude and season are not modelled (a real sunrise needs a location, which Aura does not
  ask for). The sky is decoration only: it never changes with mood, habits or health data.
- **`stones`** — `litStones(steps)` (W06, opt-in and read-only): how many of the island's `16` path stones glow after today's steps
  (`0` for `null`, negative or not-a-number; otherwise `min(16, floor(steps / 1000))`). **Warmth only:** no steps is a plain path, never
  a dim or "missed" one; there is no goal or recommended amount; the number of steps is never shown, stored, logged, uploaded or
  shared, and nothing here touches the ledger. Steps come from the platform health store only after the person turns it on.
- **`changes`** — `worldChanges({seen, current})` (T04): which world objects deserve a one-time moment (the companion's
  celebration and a plant's grow or wake animation) since the person last saw the world. `seen` maps an opaque object key to the
  `{stage, vitality}` last shown, or is `null` when nothing was ever shown; `current` is the ordered list of `{key, stage, vitality}`
  now. A `null` `seen` is the **baseline**: no changes (the first look is never a moment). Otherwise, in `current` order, at most one
  change per key: a key absent from `seen` → `sprout` (new to the grove); a higher stage → `grow`; a `seen` vitality other than
  `thriving` that is now `thriving` → `wake`; `grow` wins over `wake`. **Nothing else is a change:** a lower stage (a deleted log), a
  plant starting to rest or resting more deeply, and a key that left the grove are never animated or announced; the world never
  dramatises rest or a correction. Keys are the app's own (a preset's catalogue key or a custom habit's id) and `seen` lives on the
  device only (never pushed, wiped with the account's local data). **Replay is cosmetic:** losing `seen` only means the next look is
  a new baseline; a moment awards nothing, changes nothing and is never tied to how the person feels.


## 14. Orbit Loom constellations (`constellations.json`, U07)

A constellation is a small shape the person makes in Orbit Loom and keeps in the Reflection sky: a few stars, the lines
between them, and optionally one neutral meaning. **It is cosmetic:** keeping one never awards or removes Starlight,
glow days, streaks, rest days, keepsakes or share milestones, and there is no correct pattern, score, timer or
"better" shape. How it looks never depends on mood or any check-in. Sync entity `loom_constellation`, table `loom_constellations` (`contracts/api/v1.md`).

- **Shape.** `stars` is a list of `[x, y]` points in the unit sky (`0 ≤ x, y ≤ 1`, `x` left→right, `y` top→bottom; the
  app rounds to 3 decimals). `links` is a list of `[a, b]` star indices (an unordered pair: `[a, b]` and `[b, a]` are the
  same line). `meaning` is `null` or one of `noticed` ("Something I noticed"), `carrying` ("Something I'm carrying"),
  `ahead` ("Something ahead"), `thankful` ("Something I'm thankful for"), `just_because` ("Just because"). All
  meanings are equal: none is suggested, ranked or rewarded, and none is required. No free text in v1.
- **`problem`** — `constellationProblem({stars, links, meaning})`: `null` when valid, else the **first** problem in this
  order: fewer than `3` stars → `too_few_stars`; more than `7` → `too_many_stars`; a coordinate that is not a finite
  number in `[0, 1]` → `star_outside_sky`; two stars closer than `0.05` (straight-line distance, with a `1e-9` tolerance so a gap of exactly `0.05` is fine
  in floating point) → `stars_too_close`;
  more than `12` links → `too_many_links`; a link that is not two different whole-number indices of existing stars →
  `bad_link`; the same unordered pair twice → `duplicate_link`; a meaning outside the list → `unknown_meaning`. Zero
  links is valid (a scatter of stars is a constellation too).
- **Keeping.** At most `5` constellations are kept per Aura day (the server's `too_many_constellations`); a deleted one
  frees its place. Keeping is idempotent on the constellation id; the person can let one go (a soft delete, like
  other tombstones). Nothing else ever changes one after it is kept.
