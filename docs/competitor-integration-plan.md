# Competitor feature integration plan

Status: **proposal for AK's decision (23 Sep 2026).** Nothing here changes the PRD, contracts or code until approved. Approved items then follow the repo rule: PRD sections (`docs/prd/sections/`) and `contracts/` first, then Dart + TS.

Sources: *Aura App – Top 10 Competitors and Unique Features* and *Aura App – Competitor Unique Features & Strategic Integration* (supplied by AK). Competitor descriptions come from those documents and were **not independently verified**. The PRD's own competitive section (`11-competitive.md`) already covers Finch, Daylio, Habitica, Forest, Slowly, Voidpet and Wysa; this plan adds Headspace, Calm, Galaxy, Tandem, Timehop and Amino.

## 1. Bottom line

- The strategy document proposes 20 integrations. Measured against the PRD and the current build:
  - **1 is already built** (Aura Spirit progression is the F2 avatar).
  - **3 are already in the PRD** but not built yet (F10 Insights and F11 widget cover them).
  - **5 are worth adopting** almost as proposed.
  - **7 are worth adapting** into an Aura-safe version.
  - **1 is deferred** to after launch (structured multi-day journeys).
  - **3 should be rejected for v1** because they break locked decisions, each with a safer alternative.
- **The biggest real gap is solo calm.** The PRD has no private calming space: no breathing visualizer with haptics, no grounding library and no ambient soundscapes. The brief listed "extra room themes/soundscapes" as a Plus perk, and `screen-plan.md` names a Sanctuary tab, but no PRD feature specifies it. Finch, Calm and Headspace all win on this, and Aura's own users (exam stress, hostel nights) need it on the days they don't want strangers.
- **The second gap is that the companion never responds to a check-in.** The avatar's hue drifts with the 14-day mood mix, but it doesn't react to the check-in just made, and nothing is offered to help in that moment. Finch's "responsive familiar" and "in-flow grounding" point at this.
- **The stranger ideas that need conversation conflict with locked decisions.** Letters, accountability partners, voice circles and user-created communities break: no DMs or long-form stranger text, one mixed-age 13+ pool (D2), a solo moderator until 5,000 DAU (Q17), and Apple 1.2 on anonymous chat. The plan keeps their intent with gesture-only, additive or self-directed versions.

## 2. Coverage matrix: the 20 proposed integrations

Legend: **In PRD** = where the PRD already specifies it · **Built** = state of the repo today · Verdict: **Done / Keep** (already planned) / **Adopt** / **Adapt** / **Defer** / **Reject (v1)**.

| # | From | Proposed integration | In PRD | Built | Verdict | Aura version | When |
|---|---|---|---|---|---|---|---|
| 1 | Habitica | Aura Spirit progression (radiance and hue from rituals, no penalties) | F2 stages, hue, rings (Breathe), glow (Sleep); F3 no fail state | ✅ Avatar renderer, stages, traits, Resting Nebula, moments | **Done** | Sanctuary sessions also feed the Breathe habit (rule already exists for the 60 s exercise) | — |
| 2 | Habitica | Communal wellness quests | Only "invert the damage" (Breath Ripples); friend lists out of scope; bring-a-friend rooms P2 | ❌ | **Adapt** | **Room lanterns**: an anonymous, room-scoped, additive-only goal. Gestures and breaths in Lantern Hour light a shared lantern. No individual counts, nothing can fail, no friend graph | B (with F5) |
| 3 | Daylio | Frictionless check-in widget (tint + tags on home screen) | F11 (P1, Milestone C), mood only | ❌ | **Keep F11** | Tags stay in-app: widget and lock-screen privacy (REQ-WID-03). A deep-link small widget could come earlier (cheap) | C (deep-link variant B) |
| 4 | Daylio | Holistic wellness correlator | F10 patterns (tag × quadrant, habit × quadrant), on device, threshold-gated | ❌ (history list only) | **Adopt inside F10** | **Weekly insight card**: one supported pattern a week, descriptive words only ("more often"). The doc's "calmness score increases by 28%" breaks REQ-INS-03 (no scores, no causal claims) | B |
| 5 | Finch | Responsive Aura familiar | Partial: hue follows 14-day mix; evolve/wake moments; "borrow a one-line prompt on welcome-back/evolution" | Partial | **Adopt** | **Companion response**: after each save the avatar reacts (≤ 2 s quadrant-tinted shimmer; still under Reduce Motion) with one warm line from a localized pool. Equal warmth for all quadrants; never advice or diagnosis | A |
| 6 | Finch | In-flow grounding moments | ❌ (support sheet only on a lexicon hit or the help button) | Partial (60 s grounding exists in the support sheet) | **Adapt** | **"A minute for you"** card in the saved moment, offered for **every** quadrant (equal dignity): Storm → 30 s grounding; Rain → gentle comfort (soft sound, hand-on-heart); Moonlight → stillness; Sunrise → savour/gratitude. Optional, after Save, never replaces the crisis sheet, not shown if the sheet just opened | A |
| 7 | Slowly | Slow reflection letters between strangers | Explicitly "do not copy: long-form text between strangers"; DMs/threads out of scope | ❌ | **Reject (v1)** | Letters to **future self** are F4 capsules (A). After 3 months of reflection safety data: a one-way **"note for the next person"** (≤ 200 chars, F6 pipeline, delivered to a random later member of the same quadrant, gesture-only reply) | F4: A · note: post-launch |
| 8 | Slowly | Milestone seals and keepsake box | "Collectible items earned, not bought" (borrow list); F12 cosmetics; constellation stars | ❌ | **Adapt** | **Keepsakes**: earned-only seals (first capsule sealed/opened, 7/30/100/365 glow days, first Breath Ripples, Lantern Hours, Sanctuary minutes) in a private box and on F13 share cards. Never sold, never lost, **never shown to strangers** (silhouettes aren't fingerprints) | C |
| 9 | Timehop | "A year ago today" emotional retrospective | ❌ (F10 P2 "Year-in-Stars recap") | ❌ | **Adapt (safety-gated)** | **Look back** in Insights, pull-only. Shows the sky from the same week 1 month / 6 months / 1 year ago. Notes and voice only on tap; never right after a Storm/Rain check-in or within a day of a crisis sheet; crisis-flagged entries excluded; never pushed | C |
| 10 | Timehop | Monthly / annual growth replays | F10 Plus "monthly review"; P2 Year-in-Stars; F13 milestone cards | ❌ | **Adopt** | **Your month in stars**: basic monthly recap free, deeper Plus (as F10 says). Annual recap post-launch. Shareable only through F13's whitelist (no moods on cards) | B (monthly) · v1.1 (annual) |
| 11 | Tandem | Wellness accountability partners (strangers) | Friend lists, DMs out of scope | ❌ | **Reject (v1)** | **Tonight's intention**: a room-level shared intention in Lantern Hour (e.g. "sleep on time"), gestures only, no pairing. Friend accountability only with P2 bring-a-friend rooms | Intention: B · friends: post-launch |
| 12 | Tandem | Compassionate feedback prompts | Gestures cover encouragement for others (F5); private writing has no prompts | Partial | **Adopt** | **Guided prompts**: an optional rotating prompt in the check-in note and capsule composer ("What's one small thing that helped today?"). Localized, skippable, same warmth for every quadrant | A |
| 13 | Galaxy | Silent co-presence and ambient spaces | F5 rooms (gesture co-presence); screen-plan "quiet gathering" (planned) | ❌ | **Adapt** | **Quiet Together**: time-boxed drop-in sessions (study, read, rest). Counts only ("12 here"), gestures only. A shared soundscape is **played locally from a common start time** (no user audio). Optional 25/5 focus rhythm; leaving costs nothing (Forest inverted). Fits exam-season students | C |
| 14 | Galaxy | Mood-tuned sound circles | ❌ (voice chat out of scope) | ❌ | **Adapt** | **Lantern Hour wind-down**: a synchronized ambient track plus on-screen breathing and text cues for everyone in the room. No user voice, ever | C (with #13) |
| 15 | Headspace | Structured multi-day journeys | ❌ (PRD flags "content depth" as a weakness) | ❌ | **Defer** | **Pathways**: 5–7-day micro-series built only from existing pieces (a daily prompt, one Sanctuary activity, an optional capsule). Text-first, non-clinical, safe-messaging reviewed. Start with "Exam week" and "New in the city" | Post-launch (pilot in C if capacity) |
| 16 | Headspace | Generative sleepcasts | ❌ | ❌ | **Adapt (partial)** | **Wind-down soundscape** whose stems re-order each night (procedural, no narration), with a sleep timer. Narrated stories later: voice talent in 3–5 languages is a content budget Aura doesn't have | B (procedural) · post-launch (narration) |
| 17 | Calm | Haptic breath visualizer | F7 haptic pacer (social, B); 60 s grounding (4/6 circle, no haptics) | Partial | **Adopt** | **Sanctuary › Breathe**: avatar-orb pacer; calm 4/6, box 4-4-4-4 and 4-7-8 patterns; haptic rhythm (obeys Comfort › Haptics); Reduce Motion → text + haptics; no score. Logs Breathe. **The same pacer engine later powers Breath Ripples** (de-risks F7) | A |
| 18 | Calm | Layered ambient sound mixer | ❌ in PRD (brief had soundscapes as a Plus perk); screen-plan "ambient controls sheet" (planned) | ❌ | **Adopt** | **Sanctuary › Sounds**: 6–8 loopable stems (rain, ocean, wind, night insects, singing bowl, chimes, brown noise), per-stem volume, timer, background playback, offline, **silent until chosen**. Base set free (F12: never sell what helps someone feel better); Plus adds extra stems ("more of"). No binaural or health claims | B |
| 19 | Amino | Niche circles (user-created) | Out of scope (UGC communities); liquidity risk (F5) | ❌ | **Reject (v1)** | Post-launch, once liquidity allows: **curated life-context room themes** ("Exam season", "New in the city", "Night shift") defined by Aura, with the same gesture-only rules | Post-launch |
| 20 | Amino | Aesthetic customization of circles | F12 cosmetics, "Plus theme", room ambience (brief) | ❌ | **Adapt** | **Personal only**: sky themes and a soundscape pairing for *your* space, in the F12 catalogue. No creator-skinned stranger spaces | B (with F12) |

**Totals:**
- 1 done.
- 3 already in the PRD: #3, and #4 and #10 inside F10.
- Adopt: #5, #12, #17, #18.
- Adapt: #2, #6, #8, #9, #13, #14, #16, #20.
- 1 deferred: #15.
- 3 rejected with safe alternatives: #7, #11, #19.

## 3. Other competitor features: rejected outright (v1)

| Feature | Competitor | Why not | Revisit |
|---|---|---|---|
| HP damage, party damage on missed tasks | Habitica | Aura is non-punitive by construction (F3, `11-competitive.md`) | Never |
| Gold/XP economy beyond Starlight | Habitica | Starlight only goes up and is never sold (REQ-AVA-03); Stardust exists only for gifts | Never |
| Nostalgia streaks | Timehop | Streak pressure; no streak pushes (F3/F14) | Never |
| Import from Facebook/Instagram/Google Photos | Timehop | Identity-linked data, new permissions, privacy promise | Never |
| Professional tutor/coach marketplace | Tandem | Clinical/therapy territory (`22-out-of-scope.md`) | With a clinical partner |
| In-line corrections, real-time chat, DMs, screening rooms | Tandem, Amino | No chat or DMs (locked; Apple 1.2) | Text replies after 3 months of safety data (PRD) |
| Anonymous voice chat, listening parties with user audio | Galaxy | Audio from strangers is out of scope (moderation, CSAM risk) | Never in v1 |
| Celebrity-narrated sleep stories | Calm | Licensing and cost | — |
| Guided meditation videos | Headspace | Content cost; video out of scope | Post-launch |
| Customizable mood icons | Daylio | Already PRD P2 ("custom moods") | P2 |

## 4. What the build is still missing against the PRD

The existing backlog, independent of the competitor docs:

| PRD item | Milestone | Status today |
|---|---|---|
| F1 Check-in | A | ✅ 2-tap, tags + custom tags, note, voice (≤ 60 s), crisis lexicon, history with 24 h edit and delete. ❌ 7-day backfill (Insights only) |
| F2 Avatar + habits | A | ✅ Stages, traits, nebula, moments, habits editor with custom habits, Breathe auto-complete from the 60 s exercise. ❌ Journal auto-complete (note ≥ 50 chars or capsule) |
| F3 Streaks, rest days | A | ✅ Including hide-streak. ❌ Longest streak (lives in Insights) |
| F4 Time capsules | A | ❌ Not started |
| F5 Mood rooms, gestures, Lantern Hour | A | ❌ Not started |
| F8 Accounts | A | ✅ DOB gate, under-13 lock, email sign-in, sign-out wipe, deletion with 7-day grace. ❌ Apple/Google sign-in, platform age signals |
| F9 Safety | A | ✅ Support sheet, helplines (IN/US/generic), grounding, grievance contact. ❌ Signed lexicon bundle (EN/TE/Tenglish), report/block/mute (needs F5), moderation queues, remote helpline refresh |
| F14 Notifications | A/B | ✅ Device registration and permission explainer. ❌ Sending: daily reminder, capsule push, quiet hours, caps |
| Admin console v0 | A | ❌ Not started |
| PostHog + Sentry | Foundations | ❌ Not wired |
| App shell (5 positions) and Safety Center route | Screen plan, phase 0 | ❌ Not started |
| F6 Reflections, F7 Breath Ripples, F10 Insights, F12 Monetization | B | ❌ Not started (F10: history list only) |
| F11 Widget, F13 Share cards | C | ❌ Not started |

## 5. Plan: three waves on top of the existing milestones

Most of timeline weeks 1–9 is already built before the 5 Oct start (foundations minus analytics, F1, habits and the Starlight ledger, F2, F3), plus voice notes, history and account deletion from later weeks. That lead plus the 3-week buffer is what the waves below spend. **New items rank below the PRD's "never cut" list and below F4, F5 and F9.**

### Wave 1: with Milestone A (closed alpha, w/e 10 Jan 2027), ≈ 3.5 weeks

| Item | From | Effort | Depends on |
|---|---|---|---|
| Companion response after each check-in (#5) | Finch | 1 wk (shared with the next row) | F1 saved moment |
| "A minute for you" (#6): one suggestion per quadrant in the saved moment | Finch | shared with above | Sanctuary Breathe/grounding |
| **Sanctuary v1**: Breathe visualizer with haptics and patterns (#17), grounding library (5-4-3-2-1, hand-on-heart, gratitude), "Today's minute" card | Calm, Finch, Headspace | 2 wk | App shell (Sanctuary tab) |
| Guided prompts in note and capsule composers (#12) | Tandem | 0.5 wk | F4 composer |

### Wave 2: with Milestone B (open beta, w/e 2 May 2027), ≈ 4.5 weeks

| Item | From | Effort | Depends on |
|---|---|---|---|
| **Sanctuary v2 › Sounds**: stem mixer, timer, background audio, nightly re-ordered wind-down (#18, #16) | Calm, Headspace | 2 wk + asset sourcing | Audio licensing decision (D3) |
| Weekly insight card and "Your month in stars" (#4, #10) | Daylio, Timehop | 1 wk on top of F10 | F10 |
| Room lanterns and "Tonight's intention" in Lantern Hour (#2, #11) | Habitica, Tandem | 1 wk | F5 |
| Personal sky themes and soundscape pairing in the catalogue (#20) | Amino | 0.5 wk | F12, Sounds |

### Wave 3: with Milestone C (public launch, 30 Sep 2027), ≈ 3.5 weeks

| Item | From | Effort | Depends on |
|---|---|---|---|
| **Quiet Together** co-presence sessions and Lantern Hour wind-down (#13, #14) | Galaxy, Forest | 2 wk | F5 realtime, Sounds |
| Keepsakes (earned seals) on share cards (#8) | Slowly, Timehop | 1 wk | F13 |
| Look back (1 month, 6 months, 1 year) in Insights (#9) | Timehop | 0.5 wk | F10 |

### After launch (v1.1+)
Pathways (#15), narrated wind-down, bring-a-friend rooms with shared intentions (#11 and #2 for friends), curated life-context room themes (#19), the one-way "note for the next person" (#7, after 3 months of F6 safety data), custom moods (Daylio), annual recap (#10).

### If a milestone slips
Cut in this order: Quiet Together → Look back → Keepsakes → extra Sounds stems → room lanterns. **Keep Sanctuary v1 and the companion response**; they're cheap and central to the calm-companion promise. The PRD's existing levers still apply first: gifts, then share cards and widget, then Insights reduced to the calendar.

## 6. Decisions needed from AK

1. **Add a Sanctuary feature (F15) to the PRD?** It would cover breathing, grounding and sounds, and turn the screen plan's Sanctuary tab into a spec. *Recommended.*
2. **Soundscape pricing:** a free base set with Plus adding extra stems? *Recommended* (F12: never sell what helps someone feel better).
3. **Audio source:** CC0/royalty-free field recordings, procedural synthesis, or a mix. *Recommended:* licensed CC0 recordings for the base stems plus procedural layering (fits "art is code"; no per-play licence risk). Also needs background-audio capability (iOS `UIBackgroundModes: audio`, Android media playback service) and a store-review check.
4. **"A minute for you" for all four quadrants** (equal dignity, not only for "hard" moods)? *Recommended.*
5. **Quiet Together** (stranger co-presence with shared sound) for Milestone C? It adds realtime load, no moderation load.
6. **Confirm the rejections:** stranger letters, accountability partners, voice/audio circles, user-created circles and skins, coaching marketplace, social-media memory import.
7. **Keepsakes are never visible to strangers?** *Recommended* (anti-fingerprinting).

## 7. PRD and contract changes once approved

- **New `06d` section:** F15 Sanctuary (Breathe, grounding library, Sounds, Today's minute) and the F2 companion response.
- **`06a`:**
  - F1: post-save order gains "A minute for you" after Starlight and alongside the room offer.
  - F1/F4: guided prompts.
  - F10: weekly card, monthly recap, Look back.
  - F13: keepsakes.
- **`06b`:** F5 room lanterns and Tonight's intention; Quiet Together (a new F16 or an F5 mode) and the Lantern Hour wind-down.
- **`06c` F12:** soundscape and theme catalogue lines; base soundscapes on the never-paywalled list.
- **`11-competitive`:** add Headspace, Calm, Galaxy, Tandem, Timehop and Amino to the table and the borrow/don't-copy list.
- **`12-notifications`:** an opt-in wind-down reminder (inside the 2/day cap; no mood on the lock screen).
- **`13-analytics`:** Sanctuary and Quiet Together events (18+ only, aggregate for under-18s, as now).
- **`15-permissions`:** background audio; no microphone for Sanctuary.
- **`17-accessibility`:** audio and haptics alternatives, Reduce Motion for the pacer, captions for any narrated content.
- **`20-timeline`:** the three waves.
- **`22-out-of-scope`:** the rejected items with reasons.
- **`contracts/rules`:** Sanctuary session → Breathe habit auto-complete (spec + vectors), shared by Dart and TS.
