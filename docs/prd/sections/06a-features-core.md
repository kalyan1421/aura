## Feature Specification — Personal Core

Solo features. All work offline unless stated. Every feature here is the same for everyone 13+; for under-18 users the only differences are invisible and are noted per feature.

### Shared definitions

| Term | Definition |
|---|---|
| **Aura day** | Local day with a **04:00 rollover** (accepted default, tune in alpha): a 01:30 Wednesday check-in counts for Tuesday. Students are up past midnight; a midnight cut would split one evening in two. |
| **Active day** | An Aura day with ≥ 1 check-in or ≥ 1 habit. |
| **Day stamp** | Every record stores `created_at` (UTC), `tz_offset` and `aura_day`. All three are set on device and never recomputed. |
| **Starlight** | Progression points that only go up. They are earned only: never sold, spent, gifted or granted by Plus. |

**Clock rules** `[ASSUMPTION]`
- A day skipped only by timezone travel is not missed. A record dated after the server's current date earns no Starlight or streak credit.
- The same rules run twice: a pure Dart engine on device (provisional) and the NestJS ledger service (authoritative, DS-5) after merging devices. One shared set of JSON test vectors runs in both CI suites so they cannot drift. The ledger is keyed by source record id, so re-syncs never double-count.

### F1 Mood Check-in

**P0 · Milestone A.** Riya won't tell anyone how she feels; Arjun quit Daylio because logging felt like a chore. Checking in must be faster than opening the camera and work with no signal.

**Behaviour**
- **Tap 1 = mood** from a fixed 4×4 grid grouped by quadrant (glyph + label; never reorders). **Tap 2 = Save.** Optional: tags (10 defaults + ≤ 10 custom, ≤ 20 chars `[ASSUMPTION]`), note ≤ 500 chars, voice ≤ 60 s.
- **Local-first:** written to encrypted Drift and confirmed before any network call. Starlight, streaks, Nebula wake and capsule triggers all evaluate on device.
- **After saving, in this order:**
  1. the crisis sheet, if the note matched the lexicon (F9)
  2. a mood-trigger capsule, if one fires (F4)
  3. Starlight, then "Join a room of people feeling this" (F5)
- **Unlimited check-ins;** only Starlight is capped. Edit for 24 h, delete anytime; deleting never removes Starlight or glow days.
- **Backfill** up to 7 days `[ASSUMPTION]`: shown in Insights only, earns nothing, no streak effect, fires no capsules.
- **Voice notes are not crisis-scanned in v1.** "I need help now" stays visible.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-CHK-01 | P0 | Mood-only check-in in 2 taps, median < 5 s | Given Home, when the user taps a mood then Save, the entry is saved. Median `duration_ms` < 5,000; p90 < 8,000 `[ASSUMPTION]`. |
| REQ-CHK-02 | P0 | Fully offline | In airplane mode, save confirms < 300 ms, credits Starlight, syncs ≤ 60 s after reconnect. Negative: never a spinner, error or retry. |
| REQ-CHK-03 | P0 | Notes crisis-checked on device | A lexicon hit in any shipped language (English, Telugu, Tenglish; Hindi and Hinglish from beta) shows the support sheet first, and the entry still saves. Negative: a clean note shows no sheet. |
| REQ-CHK-04 | P0 | Room prompt after save | Shown after every live check-in, to every user 13+. Negative: it never appears before the crisis sheet or a firing capsule (order above). |

**Edge cases & states**
- **Double-tap on Save:** one entry (idempotent client id). **App killed before Save:** nothing saved.
- **Storage full:** text saves; voice is dropped with a notice.

**Under-18 users:** identical. Invisible only: excluded from behavioural analytics (aggregate counts only).

**Post-v1 (P2):** custom moods, an intensity slider, on-device voice transcription for crisis scanning, watch check-in, HealthKit / Health Connect.

### F2 Habit-Responsive Avatar (incl. habits)

**P0 · Milestone A.** Finch shows people will care for a character when self-care is hard (research doc), but Arjun doesn't want a pet. In Aura the avatar *is* the user: small self-care makes you glow.

**Habits**
- 6 defaults (Hydrate, Sleep on time, Move, Breathe/Meditate, Journal, Go outside) + ≤ 3 custom (≤ 30 chars, crisis-scanned); user picks which show.
- **Binary, self-reported,** per Aura day. No "missed" state, red or cross.
- **Auto-complete** `[ASSUMPTION]`: Breathe after the 60 s exercise or a Breath Ripples session; Journal after a note ≥ 50 chars or sealing a capsule.

**Starlight** (accepted default, tune in alpha)

| Source | Starlight | Limit |
|---|---|---|
| First check-in of the day | 10 | once |
| Each further check-in | 2 | the next 2 only |
| Each habit | 5 | once a day |
| **Daily cap** | **60** | all sources |

Plus does not multiply Starlight.

**Stages** (accepted default): Spark 0 → Ember 100 → Glow 400 → Radiance 1,200 → Constellation 3,000. At ~20 a day, Ember lands on day ~5 (inside week 1, for D7) and Constellation around month 5. After that, every 500 Starlight adds a star to the user's constellation (max 12).

**Traits**
- **Hue** blends the last 14 days of moods (Sunrise gold, Moonlight silver-blue, Rain teal, Storm violet). Every hue must look equally beautiful; Storm is never "sick". No data → hue holds.
- **Starlight rings** (Breathe) and **cosmic glow** (Sleep) unlock at 5 / 20 / 50 lifetime completions, permanently.
- Only hue moves, and only sideways. Cosmetics (F12) never change stage or traits.

**Resting Nebula**
- **Entry** at the 04:00 rollover ending the 2nd consecutive inactive day: soft clouds, slow breathing idle, no sad face, no neglect copy. Rest days don't prevent it; it's a look, not a penalty.
- **Wake:** the next check-in or habit fires `wakeUp` (≤ 4 s, skippable) with one micro-goal, never a list of what was missed.

**Hybrid avatar: character art + code (AK, 23 Sep 2026)**
- **Base character art:** a chibi-style celestial meditator (translucent galaxy body, flowing hair with golden rim light, closed smiling eyes, a 4-point star on brow and heart, gold and blue orbit rings), AI-generated by AK. Master file in `design/avatar/aura_master_v1.png` (transparent PNG). A `manifest.json` records the anchors (brow, heart, centre) and `bakedRings`, so new bases (a clean ring-less version, other body forms) drop in without code changes.
- **Everything alive is code:** fragment-shader aura glow (hue, glowLevel), Resting Nebula clouds, breathing float (±2% scale, ~6 s cycle), brow and heart glints, orbs orbiting the ring paths (one per `ringCount`, a third procedural ring at 3), twinkling sparkles, and the constellation arc. The hue tint on the character is subtle (≤ 25%) so every quadrant stays beautiful. `flutter_animate` handles one-shot moments. No Rive in v1.
- **Stages change presence, not identity:** spark is smaller and dimmer, ember warmer, glow full size, radiance adds a strong halo, and constellation adds the star arc. The character is the same at every stage.
- **Representation** `[ASSUMPTION]`: v1 ships one character. Masculine and androgynous body forms in the same style are the first cosmetic/identity addition (see Post-v1), so users like Arjun and Sai can see themselves.
- **One input:** an immutable (Freezed) `AuraAvatarState`, built from the server snapshot (DS-5) or the offline projection. The renderer is a pure function of state + elapsed time, so the same state always draws the same frame.

| Field | Type | Values |
|---|---|---|
| `stage` | `AuraStage` enum | spark · ember · glow · radiance · constellation |
| `hue` | double | 0–360°, from the 14-day mood mix |
| `isResting` | bool | Resting Nebula |
| `ringCount`, `glowLevel` | int | 0–3 (Breathe / Sleep unlocks) |
| `constellationStars` | int | 0–12 |
| `equippedCosmetics` | `Set<CosmeticId>` | empty = none; visual only |

- **Moments are events, not state:** `evolve`, `wakeUp` and `celebrate` arrive on a stream with an id and play once per id. Reduce Motion is read from `MediaQuery`, not stored in the state.
- **Quality tiers** `[ASSUMPTION]`, picked at launch and re-checked while running:

| Tier | Used when | What changes |
|---|---|---|
| High | Default | Full particles, 2 shader passes, 60 fps |
| Low | Android with ≤ 3 GB RAM, battery saver on, or frames over budget for 2 s | ≤ ⅓ of the particles, 1 shader pass, 30 fps idle |
| Still | Reduce Motion; home widget and share-card snapshots (a PNG drawn from the same state) | One painted frame; a slow glow only under Reduce Motion |

- **Fallback chain:** shader fails to load → painter-only (same state, no glow); painter throws → bundled PNG of the current stage (exported from the renderer at build time). The avatar is never blank.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-AVA-01 | P0 | Never regresses | Stage and traits survive inactivity, deletions, refunds and downgrades. Negative: deleting every check-in leaves the stage unchanged. |
| REQ-AVA-02 | P0 | Starlight per table | 3 check-ins + 9 habits in a day = 59. Negative: a 4th check-in earns 0, and no day ever exceeds 60. |
| REQ-AVA-03 | P0 | Never sold | No SKU, gift, Plus perk or Stardust path grants Starlight. Checked on every catalogue change. |
| REQ-AVA-04 | P0 | Nebula after 2 idle days | Last active Mon → `isResting` from Thu 04:00; the next habit fires `wakeUp`. Negative: not resting at Wed 23:00. |
| REQ-AVA-05 | P0 | Evolution plays once | Crossing 100 offline plays `evolve` once. Negative: a later sync on a 2nd device doesn't replay it. |
| REQ-AVA-06 | P1 | Renderer honours the `AuraAvatarState` contract | Golden tests draw every stage × resting × tier at a fixed time and match; each field visibly changes the frame. Negative: an out-of-range value (e.g. `ringCount` 5) is clamped, never throws. |
| REQ-AVA-07 | P0 | Never blank; degrades on weak phones | On a 3 GB Android the Low tier is chosen at launch. A forced shader failure shows the painter-only avatar; a forced paint failure shows the stage PNG. Negative: no path shows an empty avatar slot or crashes. |

**Edge cases & states**
- **Performance targets** `[ASSUMPTION]`: High tier ≥ 55 fps on a 4 GB RAM Android; Low tier ≥ 30 fps on 2–3 GB.
- **All habits hidden:** check-ins alone still grow the avatar.

**Under-18 users:** identical, including cosmetic purchases (F12). Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** body forms (masculine and androgynous character bases in the same art style; high priority), habit quantities, HealthKit auto-complete, the avatar in the Shared Universe Album, optional Rive layer on the same state.

### F3 Gentle Streaks & Rest Days

**P0 · Milestone A.** Broken streaks make people quit mood trackers in bad weeks (research doc). Riya will miss exam days; coming back must feel rewarded.

**Behaviour**
- **Glow streak.** Active days in the current run. Rest days bridge the run but add nothing to it.
- **Lifetime glow days.** Distinct active days. The count never decreases.
- **Earning:** every 4 active days → +1 rest day; the counter pauses while the bank is full (3). New users start with **1 welcome rest day** `[ASSUMPTION]`.
- **Applying (automatic, never prompted).** On return after N idle days:
  - **N ≤ bank:** N rest days are spent and the streak continues.
  - **N > bank:** the streak ends, **nothing is spent** and the bank carries over.
- **During a gap:** "Resting · your glow is safe" if the bank covers it, otherwise nothing. No countdowns.
- **Streak end:** "Your glow carries on" shows once, with the unchanged avatar, lifetime glow days and the new streak. No red, no old number, no "lost". Longest streak lives only in Insights.
- **Never** streak-loss pushes; never rest days via money, Stardust, Plus or ads. Optional "Hide streak number" setting `[ASSUMPTION]`.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-STK-01 | P0 | 1 rest day per 4 active days, bank max 3 | Bank 2 + counter 3, active today → bank 3. Negative: at bank 3, 4 more active days leave it at 3. |
| REQ-STK-02 | P0 | Auto-applied | Bank 2; active Mon, idle Tue–Wed, active Thu → streak continues, bank 0, Tue–Wed shown as rest days. |
| REQ-STK-03 | P0 | Oversized gap spends nothing | Bank 2, 3-day gap → streak ends, bank stays 2, end screen shows once. |
| REQ-STK-04 | P0 | No paywall, ads or loss pushes | Negative: the catalogue and Plus entitlements have no rest-day item. The build fails on any streak-loss template (F14). |
| REQ-STK-05 | P0 | Day rules | A 03:59 check-in counts for the previous day. A gap caused only by travel is not missed. |

**Edge cases & states**
- A habit-only day counts as active. Backfill never fills a gap. Across devices, active days are the union.

**Under-18 users:** identical. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** planned rest days (e.g. exam week), and a weekly-rhythm mode where 3 active days make a "glow week".

### F4 Personal Time Capsules

**P0 · Milestone A.** A capsule turns a good moment into help for a bad one: Riya seals "you've done this before" for her next Overwhelmed day; Arjun seals a one-year note in his first Bengaluru week.

**Behaviour**
- **Contents:** title (≤ 60 chars, visible while sealed) plus text ≤ 2,000 chars, voice ≤ 2 min (Plus 10 min) and/or ≤ 3 photos (2,048 px, EXIF/GPS stripped `[ASSUMPTION]`).
- **Sealing:** a lexicon hit shows the support sheet; the capsule still seals, flagged `sealed_in_hard_moment`.
- **Date unlock:** 1 week–5 years ahead, at 10:00 local `[ASSUMPTION]`. Local notification scheduled at sealing (works offline); deduplicated server push as backup.
- **Mood-trigger unlock:** target is one mood or a quadrant. Arms 24 h after sealing `[ASSUMPTION]`, fires on the next matching check-in. After any trigger capsule opens, none fires for 7 days (global cooldown); oldest match first.
- **Limits:** Free = 3 active trigger capsules, unlimited date capsules (fair-use cap 200 `[ASSUMPTION]`). Plus = unlimited triggers, 10-min voice. Downgrade deletes or locks nothing; it only blocks new triggers while ≥ 3 are active.
- **Sealed means sealed:** no early open, no edit. Delete is allowed and never shows content.
- **Opening:** skippable ~4 s ceremony (static under Reduce Motion). Hard-moment capsules first show "You wrote this during a hard moment. Open when you're ready" with a help button. "Keep for next time" re-arms a trigger capsule.
- **Encryption:** content encrypted on device; server stores ciphertext plus unlock metadata only (type, date, target, armed). Keys per Data & Privacy.

**Crisis collision rule.** If a capsule would fire on a crisis-flagged check-in (lexicon hit, or "I need help now" after saving), it is **held**. The support sheet shows first, then a card offers "A note from past you is waiting. Open now, or later?"
- **Now** counts as the fire and starts the cooldown.
- **Later** keeps the capsule armed for the next unflagged match, with no cooldown.

Why: help is time-critical and must never wait behind anything. Capsule content is unreviewed and may come from a hard moment, so it shouldn't be the first thing someone in acute distress sees.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-CAP-01 | P0 | Date capsule, 1 week–5 years | Negative: the picker blocks < 7 days and > 5 years. Opens at 10:00 local, offline too. |
| REQ-CAP-02 | P0 | Trigger arms at 24 h | Sealed Mon 18:00 for Overwhelmed → a Mon 22:00 Overwhelmed check-in doesn't fire it; one on Tue 19:00 does. |
| REQ-CAP-03 | P0 | 7-day global cooldown | Opened Mon 09:00 → no trigger capsule fires before the next Mon 09:00. |
| REQ-CAP-04 | P0 | Free: 3 active; Plus: unlimited | A 4th trigger capsule on Free shows the Plus explainer and "make it a date capsule". Negative: date capsules never hit the limit. |
| REQ-CAP-05 | P0 | Voice length by tier | Recording stops at 2:00 on Free and 10:00 on Plus. Old 10-min recordings still play after a downgrade. |
| REQ-CAP-06 | P0 | Crisis hold | A flagged match shows the support sheet; the capsule stays sealed. "Later" starts no cooldown. |
| REQ-CAP-07 | P0 | Encrypted on device | The DB row and Storage object hold only ciphertext. Negative: Kabir's moderator tools can't display capsule content. |

**Edge cases & states**
- Unlock passes while the phone is off → opens on next launch. After a timezone change → 10:00 in the current zone.
- Account deletion removes all capsules; the confirmation states how many sealed ones will be lost.

**Under-18 users:** identical. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** community capsules, capsules to a friend, location triggers, "open early" with friction.

### F10 Insights ("Aura Sky")

**P1 · Milestone B.** Arjun liked Daylio's Year in Pixels but found it clinical. Aura Sky shows history as a night sky, with plain-language patterns that never diagnose.

**Behaviour**
- **Sky calendar:** each day is a star in its most frequent quadrant's colour (split star for mixed days, faint ring for rest days). Inactive days are plain dark sky, never grey or crossed out. Month and year views; tap a day for its entries.
- **Patterns.** Quadrant mix, time of day, tag × quadrant, habit × quadrant. **Computed on device and never uploaded.**
- **Thresholds** `[ASSUMPTION]`: under 7 check-ins, calendar only plus "Patterns appear after 7 check-ins (4/7)". Any pattern needs ≥ 7 check-ins over ≥ 5 days; tag/habit patterns also need the item on ≥ 3 days and ≥ 14 check-ins. Weak patterns are hidden, not caveated.
- **Copy** `[LEGAL]`. Descriptive only: "more often", never "because". No scores, labels or diagnoses.
- **Care card** `[ASSUMPTION]`: if ≥ 80% of ≥ 7 check-ins in 14 days are Storm/Rain, show "It's been a heavy couple of weeks" with the support sheet and a room. Never pushed.
- **Free:** full calendar, 30-day patterns, lifetime stats. **Plus:** any range, habit × mood, monthly review. CSV export is free `[LEGAL]`.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-INS-01 | P1 | Threshold gating | 6 check-ins → no patterns, shows "6/7". Negative: 7 check-ins over 4 days still show none. |
| REQ-INS-02 | P1 | On-device only | A network capture shows no mood, tag or note data leaving the device. |
| REQ-INS-03 | P1 | Copy rules | A template linter fails the build on banned words ("because", "disorder", "depressed"…). |
| REQ-INS-04 | P1 | Care card | 8 of 9 recent check-ins in Storm or Rain → the card shows. Negative: no push is sent. |
| REQ-INS-05 | P1 | Plus gates depth only | Negative: the calendar and history are never gated, whatever the tier. |

**Edge cases & states**
- Deleted entries leave the sky; lifetime counts stay. Empty state: a quiet sky and a "Check in" button.
- Year view renders < 500 ms with 2 years of data `[ASSUMPTION]`.

**Under-18 users:** identical. Patterns stay on the phone for everyone, so no server-side profiling exists to switch off. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** a Year-in-Stars recap, a therapist PDF export, sleep and step correlations.

### F11 Home-screen widget

**P1 · Milestone C.** The fastest check-in doesn't open the app: Arjun between meetings or Riya in a lecture logs a mood in two taps.

**Behaviour**
- **iOS (WidgetKit + App Intents):** medium on iOS 17+ is interactive: tap a quadrant, then one of its 4 moods → "Saved · +10 Starlight". Small shows the avatar and deep-links to `aura://checkin`. Below iOS 17 both sizes deep-link.
- **Android (Jetpack Glance):** 4×2 does the same two taps via `ActionCallback` without launching the app; 2×2 deep-links.
- **Data path:** the widget writes a mood-only record (client id + day stamp) to a shared store (iOS App Group; Android app-private storage). The app imports it into Drift on next launch or background refresh, then syncs. Widget Starlight is provisional until import.
- **Shows** the avatar (a still PNG of the current `AuraAvatarState`, written by the app), "How are you feeling?", today done or not; larger sizes add "Need help" (F9). Capsules never open here: a match shows "Something from past you is waiting".
- **Privacy defaults (everyone):** lock screen, StandBy and Always-On never show mood names, colours or history; lock-screen accessories show only a star deep link. "Show my last mood" is **off** by default (`privacySensitive` on iOS). **Discreet widget** `[ASSUMPTION]`: plain star, no "Aura" wordmark, no mood words; available to all users, **off by default**.
- **Refresh** after each check-in, at 04:00 and on Nebula change.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-WID-01 | P1 | Check in without opening the app (iOS 17+, Android) | A quadrant tap then a mood tap saves the check-in, and the app never comes to the foreground. |
| REQ-WID-02 | P1 | Offline | A save in airplane mode succeeds, then imports and syncs exactly once. |
| REQ-WID-03 | P1 | No mood history on lock screen | Fresh install: lock-screen and StandBy renders show no mood labels or colours. Negative: "Show my last mood" on still shows none there. |
| REQ-WID-04 | P1 | Discreet mode; iOS < 17 fallback | In Discreet mode, no rendered text contains "Aura" or a mood word. On iOS < 17, a tap opens the check-in sheet directly. |

**Edge cases & states**
- Signed out → "Open Aura to continue", input disabled. The shared store is versioned so the importer accepts older records after updates.

**Under-18 users:** identical, same defaults. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** an iOS 18 Control Center control, watch complications, a Lantern Hour Live Activity.

### F13 Share cards

**P1 · Milestone C.** With no public profiles, cards are a key growth channel (K target 0.15–0.3). Riya can post an avatar milestone to her story without revealing how she feels.

**Behaviour**
- **Card types:** Evolution (Ember → Constellation), Glow milestone (7 / 30 / 100 / 365 lifetime days `[ASSUMPTION]`), Capsule anniversary ("Sealed a capsule 1 year ago").
- **Rendered on device:** `RepaintBoundary` → 1080×1920 PNG, using the Still tier of the avatar renderer. No server rendering or upload.
- **Shows** avatar (stage, rings, glow, cosmetics), milestone line, wordmark, store link. **Never** moods, quadrants, tags, notes, capsule text, dates, streak count, pseudonyms, usernames or IDs.
- **Hue:** cards use the template's fixed palette, not the mood-derived hue, since that mapping is visible in-app and could be decoded into moods.
- **Sharing:** OS share sheet (`share_plus`) or "Save to Photos" (add-only permission) only; no social SDKs, no pixels. Links carry a random share token `[ASSUMPTION]` not derived from the user id.
- **Prompt.** Offered once per milestone. No reward for sharing `[STORE]`.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-SHR-01 | P1 | 1080×1920 PNG made on device | Renders in < 1 s, offline too. |
| REQ-SHR-02 | P1 | No mood or identity data | Templates bind only whitelisted fields (stage, traits, cosmetics, milestone). Golden-image test for each type. Negative: injecting a mood field or a pseudonym fails the build. |
| REQ-SHR-03 | P1 | No reward for sharing | Starlight and Stardust ledgers hold no entry tied to a share. |
| REQ-SHR-04 | P1 | Under-18 shares are untracked | An under-18 account's share uses a plain store link with no token and sends no analytics event; the card looks identical. Negative: the share action is never hidden or limited by age. |

**Edge cases & states**
- Low memory → retry at 720×1280. Several milestones at once → one prompt, for the highest.

**Under-18 users:** same cards and share flow. Invisible only: no share token and no analytics (REQ-SHR-04).

**Post-v1 (P2):** square and MP4 formats, a yearly "Aura Wrapped" card, a "Bring a friend" invite card.
