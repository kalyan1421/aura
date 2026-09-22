# Aura PRD — Shared Writer Brief (source of truth for all section writers)

---
## ⚠️ REVISION v1.1 — AK's answers to all open questions (23 Sep 2026). THIS BLOCK OVERRIDES EVERYTHING BELOW IT.

**Ownership & publishing.** **AKVega** (not Asan Innovators) owns Aura, publishes it from AKVega's existing company App Store + Play accounts, and is the data fiduciary / controller. Asan Innovators remains only the *preparer* of this PRD (branding line stays). AK is Grievance Officer. A tech/privacy lawyer is engaged in week 0.

**D2 REVISED — Age policy: 13+, full access, NO parental consent, ONE mixed-age pool.**
- Under-13 still blocked at the DOB gate (30-day device lock stays).
- **Everyone 13+ gets the full app with no feature limits**: rooms, reflections, Breath Ripples, gifts, purchases, share cards. **There is no Local Mode, no parent consent flow, no DigiLocker, no parent persona flow, no 13–17 pool, no age-band partition in matching, no teen-specific Lantern Hour, no teen gift ban.** Delete all of these from specs, stories, states, notifications, data model, console.
- AK chose this knowingly after being told the risk. The PRD must record it as **the top legal/safety risk** (DPDP requires verifiable parental consent for <18 in India, penalty up to ₹200 crore; Texas SB 2420 is in force for US minors; UK Children's Code / GDPR Art. 8 when EU/UK open; Australia's under-16 social media law). Do not re-argue it inside feature specs; just don't specify teen gating.
- **Invisible protections that impose no user-facing limit are still in**: DOB (full date, DS-6) is stored; server knows who is under 18; under-18 users are excluded from behavioural product analytics (aggregate only); auto-moderation applies stricter grooming/PII/sexual-content thresholds to any content involving an under-18 account; a "Minors & grooming" moderation lane; instant ban + evidence preservation + mandatory reporting (POCSO / IT Rules) for sexual content involving minors or grooming.

**D3 unchanged (AK solo)** — art is **hybrid: AK-supplied AI character art (design/avatar/aura_master_v1.png) + every animated layer in code by Claude** (see F2): the avatar, nebula, room themes and Breath Ripples ocean are **procedural** (Flutter CustomPainter + fragment shaders + flutter_animate; SVG icons for gestures). **No Rive animator, no art budget.** Rive becomes optional. Keep the named-inputs contract idea but as a Dart `AuraAvatarState` (stage, hue, isResting, rings, glow…) driving a procedural renderer.

**D4 REVISED — Worldwide from alpha, except EU, UK and Australia, which open at beta** (after GDPR Art. 27 representative, DPIA, UK Children's Code review, Australia under-16 law assessment). India remains the primary market for GTM and pricing.

**D5 REVISED — Stack:** Flutter + Supabase (Postgres/RLS, Auth, Realtime, Storage) **+ NestJS modular monolith (API + Worker) + Redis/BullMQ from day one** (AK's standard Asan stack; deploy DigitalOcean Mumbai). **No RevenueCat: purchases validated in NestJS** (App Store Server API + App Store Server Notifications V2; Google Play Developer API + Real-time Developer Notifications via Pub/Sub; Play Billing Library v8 on device via `in_app_purchase`). All stranger-facing reads go through NestJS endpoints / Postgres RPCs that return pseudonyms only (DS-10).

**Data decisions:** DS-1 envelope encryption ✔ · DS-2/3 fresh pseudonym per room + mood-at-join chip ✔ · DS-4 24 h room + 7-day memory, legal holds 180 days ✔ · DS-5 server ledger ✔ · **DS-6 full date of birth stored** (changed) · DS-7 crisis events aggregate only ✔ · **DS-8 N/A** (no Local Mode) · **DS-9 own validation in NestJS** (changed) · DS-10 NestJS/RPC layer ✔.

**Moderation:** on-device lexicon → **OpenAI omni-moderation only** (no Claude/LLM classifier) → human queue. Expect a higher held rate, especially Telugu/Tenglish/Hinglish. De-identified labelled reflections kept (with notice + opt-out) to train an in-house model later. Evidence store 180 days. **AK is the only moderator until 5,000 DAU**, then hire. Crisis copy/lexicon **self-reviewed against published safe-messaging guidelines** (WHO, AFSP/Samaritans-style) — no clinical advisor.

**Crisis helplines:** India Tele-MANAS 14416 / 1-800-891-4416, US 988, and a **generic "call your local emergency number"** fallback everywhere else (no ThroughLine licence).

**Lantern Hour:** **9–11 pm in the user's local time**; room matching adds a **timezone-region** key so people in a room share an evening.

**Languages (priority):** English → **Telugu** → **Tenglish** (romanized Telugu, locale `te-Latn`) → Hindi → Hinglish (`hi-Latn`). **Staged:** alpha = English + Telugu + Tenglish (UI + rooms; AK can moderate these); beta = + Hindi + Hinglish UI; Hindi/Hinglish rooms open when a Hindi-reading moderator or reliable auto-moderation exists. Room language pools: English · Telugu+Tenglish · Hindi+Hinglish.

**Monetization:** Aura Plus **first month free**, then **₹49/month or ₹399/year** (store-local prices abroad, e.g. $4.99 / $39.99). Cosmetics ₹10–₹99, gifts ₹10/₹29/₹49 — available to everyone 13+. GST via AKVega's CA. Google User Choice Billing revisited after launch.

**GTM:** **online-first, no campus partners** (Reddit, Instagram/YouTube creators, Discord, ASO). "Campus beta" becomes **open beta**.

**Timeline:** start Mon 5 Oct 2026 · **A closed alpha ≈ wk 14 (w/e 10 Jan 2027)** · **B open beta ≈ wk 30 (w/e 2 May 2027)**, EU/UK/AU open here · **C public launch Thu 30 Sep 2027**. Analytics: PostHog Cloud. Min OS iOS 16 / Android 7.

**Defaults accepted (tune in alpha):** 4 am day boundary; Starlight economy (10 first check-in, 2 each for 2 more, 5/habit, 60/day cap; stages 100/400/1,200/3,000); gifts → 10/30/50 Stardust, max 5/day; rate limits; no paywall within 24 h of onboarding or right after a Storm/Rain check-in; echoes covered by privacy notice with opt-out.
---

Read this fully before writing. Every section must be consistent with it. If you need a decision that isn't here, make the smallest reasonable call and tag it `[ASSUMPTION]` so it can be reviewed.

## Product in one line
**Aura** is a calm, pseudonymous iOS + Android app where you check in with how you feel in two taps, grow a celestial avatar through gentle self-care, and feel less alone by sharing silent support with strangers who feel the same right now.

Owner: Asan Innovators (own product) · Prepared by Kalyan Kumar Bedugam (AK) · PRD v1.0 · 23 Sep 2026.

## Locked decisions (made by AK on 23 Sep 2026 — build on them, do not relitigate)
- **D1 Scope of v1 = research Phase 1–2 in full**: mood check-in, habit-responsive avatar, gentle streaks with rest days, personal time capsules, mood rooms with strangers (gestures **and** short moderated text reflections), **one** real-time co-op mini-game, crisis routing, India monetization. Shared Universe Album, community capsules and extra mini-games are post-v1.
- **D2 Age floor = 13+**. Under-13 blocked. 13–17 need verifiable parental consent (India DPDP Act treats <18 as a child). Minors never share rooms or games with adults, see no ads, get no behavioural tracking/profiling, and cannot send gifts.
- **D3 Team = AK solo** (with AI coding tools). External help only for illustration/Rive animation and a legal review.
- **D4 Market = India-first** (closed alpha → India campus beta → India public launch), global after. `[ASSUMPTION — from research, not explicitly confirmed]`
- **D5 Stack = Flutter + Supabase** (see Tech section). Digital goods are sold through **Apple IAP / Google Play Billing**, not Razorpay (store rule for digital goods).

## Personas (use these names consistently)
1. **Riya, 20** — 2nd-year engineering student, Hyderabad hostel. Exam stress, homesick, won't talk to family ("log kya kahenge"). Uses Instagram but never posts how she feels. Primary persona.
2. **Arjun, 26** — first-job software engineer in Bengaluru, lives alone, remote-hybrid. Burnout, loneliness after moving cities. Has tried Headspace/Daylio, churned. Will pay small amounts.
3. **Meera, 16** — Class 11 NEET aspirant in Kota. High pressure, little privacy. Joins only with parental consent. Minor-safety persona.
4. **Sunita, 44** — Meera's parent. Must approve consent, wants reassurance the app is safe, does NOT get to read Meera's entries.
5. **Kabir, 29** — Aura moderator/ops (initially AK himself). Reviews reports, flagged reflections, crisis escalations.

## Feature catalogue and requirement ID prefixes
| ID | Feature | Priority in v1 | Req prefix |
|---|---|---|---|
| F1 | Mood Check-in (2-tap) | P0 | REQ-CHK |
| F2 | Habit-Responsive Avatar ("your Aura") + habits | P0 | REQ-AVA |
| F3 | Gentle Streaks & Rest Days | P0 | REQ-STK |
| F4 | Personal Time Capsules | P0 | REQ-CAP |
| F5 | Mood Rooms (stranger matching, gestures) | P0 | REQ-ROOM |
| F6 | Reflections (short moderated text in rooms) | P0 | REQ-REF |
| F7 | Co-op mini-game: **Breath Ripples** | P0 | REQ-GAME |
| F8 | Accounts, Age Gate & Parental Consent | P0 | REQ-ACC |
| F9 | Safety, Moderation & Crisis Routing | P0 | REQ-SAFE |
| F10 | Insights ("Aura Sky" mood calendar, patterns) | P1 | REQ-INS |
| F11 | Home-screen widget (quick check-in) | P1 | REQ-WID |
| F12 | Monetization (Aura Plus, cosmetics, gifts) | P1 (ships in v1 India beta) | REQ-PAY |
| F13 | Share cards (avatar evolution, capsule anniversary) | P1 | REQ-SHR |
| F14 | Notifications | P0 (basic) / P1 (smart timing) | REQ-NTF |
| — | Shared Universe Album, community capsules, Zen Stone Stacking & Melody Weaving games, "Bring a friend" private rooms, rewarded ads (adults only), trusted-contact alert | P2 (post-v1) | — |

User stories: `US-01…`. Analytics events: `snake_case` `object_action` (e.g. `checkin_completed`).

## Core mechanics (canonical definitions — use exactly)

**Mood taxonomy (fixed catalogue in v1, 16 moods, 4 quadrants on energy × pleasantness):**
| Quadrant (room theme) | Moods |
|---|---|
| **Storm** — high energy, unpleasant → room theme *The Lighthouse* | Overwhelmed, Anxious, Restless, Frustrated |
| **Rain** — low energy, unpleasant → *The Rain Sanctuary* | Melancholy, Drained, Lonely, Numb |
| **Moonlight** — low energy, pleasant → *The Midnight Observatory* | Calm, Content, Quietly Hopeful, Grateful |
| **Sunrise** — high energy, pleasant → *The Sunrise Deck* | Joyful, Excited, Proud, Energised |

**F1 Check-in:** tap 1 = mood; tap 2 = "Save" or optional context tags (Study, Work, Family, Friends, Sleep, Health, Money, Love, Alone, Commute + custom). Optional note (≤500 chars) or voice note (≤60 s). Target: median < 5 s for mood-only. Every check-in: adds Starlight, may fire a mood-triggered capsule, offers "Join a room of people feeling this".

**F2 Avatar:** a celestial being that IS the user (not a pet). Habits (Hydrate, Sleep on time, Move, Breathe/Meditate, Journal, Go outside, + up to 3 custom) and check-ins earn **Starlight** (progression energy — earned only, never sold). Starlight advances evolution stages (Spark → Ember → Glow → Radiance → Constellation) and unlocks visual traits (aura hue shaped by the user's recent mood mix, starlight rings from Breathe habit, deeper cosmic glow from sleep habit). **The avatar never starves, sickens, dies, or loses stages.** After 2 consecutive days with no check-in or habit it enters **Resting Nebula** (wrapped in soft clouds) and wakes with a welcome-back animation on the next check-in.

**F3 Gentle streaks:** two numbers. **Glow streak** = consecutive active days (a day counts if ≥1 check-in or habit). **Lifetime glow days** = never decreases. **Rest days**: earn 1 per 4 active days, bank max 3, auto-applied to missed days so the glow streak continues. If the streak ends: "Your glow carries on" screen, no red, no loss copy, lifetime count shown. No streak-loss push notifications ever. Rest days are **never** paywalled and **never** bought with ads.

**F4 Time capsules (private only in v1):** seal text (≤2,000 chars), voice (≤2 min free, ≤10 min Plus), up to 3 photos. Unlock rule = **date** (1 week to 5 years) or **mood-trigger** ("open this the next time I feel Overwhelmed" — any mood or quadrant; fires on the next matching check-in, then 7-day cooldown). Free: 3 active mood-trigger capsules, unlimited date capsules. Unlock = push + opening ceremony animation. Capsule content is encrypted (see data decisions).

**F5 Mood rooms:** after a check-in the user may join a room for their quadrant. Room = up to **24 members**, lives **24 h** from creation, then closes to a read-only "memory" for its members for 7 days, then content is purged. Matching keys: quadrant (primary), specific mood (secondary), language pool (English / Hindi+Hinglish), **age band (13–17 vs 18+, never mixed)**. Each member gets a **fresh pseudonym per room** (adjective + celestial noun, e.g. "Quiet Comet") and a small avatar silhouette — no profiles, no follower counts, no DMs, no photos from strangers. Interactions: **8 preset gestures** — Warm Tea, Light a Candle, Hug, Me Too, Soft Rain, Stargaze, Deep Breath, You're Not Alone. **Lantern Hour** 9–11 pm IST daily: rooms show a shared ambient event to concentrate live presence. Cold start: if a pool has too few people, merge adjacent moods, then show the room anyway with "N people have been here today" (async presence is fine; rooms don't need people online at the same moment).

**F6 Reflections:** short text posts inside a room, **≤200 chars**, max 3 per user per room per day. Pipeline: on-device PII + crisis lexicon check → server auto-moderation (≤2 s target) → publish / hold for human review / reject with gentle explanation. No links, no handles, no phone numbers, no images. Others respond **only with gestures** (no text replies in v1 — prevents DM-like threads). Self-harm-flagged reflections are not published; author sees the support sheet; item goes to the priority moderation queue.

**F7 Breath Ripples (the one v1 co-op game):** 2–4 players, ~3 minutes. A breath pacer guides inhale 4 s / exhale 6 s. Players hold to inhale, release to exhale; the closer the group is in sync, the wider the ocean ripples spread and the more bioluminescent fish gather. **No fail state, no score, no leaderboard, no voice or text.** Players can send a one-tap haptic pulse and 3 gestures. Leaving is silent: your light gently dims into an echo. Entry: "Breathe together" invite visible inside a room, or quick-match within the same age band. **If no human joins within 20 s, fill seats with "echoes"** = anonymised recordings of real past breath sessions, clearly labelled as echoes. Network: Supabase Realtime Broadcast channel per session, ≤10 events/s per player, Presence for join/leave.

**F8 Accounts:** pseudonymous. Sign in with Apple, Google, or email magic link (phone OTP optional `[ASSUMPTION]`). No real name collected. Neutral DOB entry at onboarding (no pre-filled year). <13 → kindly blocked. 13–17 → **Local Mode** (solo features work fully on-device, nothing leaves the phone, no analytics) until a parent completes verifiable consent; then account syncs and rooms/game unlock in the 13–17 pool. Parent can revoke consent and request deletion; parent **cannot** read the teen's check-ins, notes, capsules or reflections.

**F9 Safety & crisis:** "I need help now" is always one tap away (home + rooms + game). Crisis signals (on-device lexicon EN/HI/Hinglish on notes, reflections, capsule text; server classifier on reflections) → full-screen support sheet: locale helplines (India **Tele-MANAS 14416**, US 988, others by country), a 60-second grounding exercise, and "Aura is not a medical or emergency service" disclaimer. Report / block / mute on every stranger surface. Strike system + shadow-mute. Moderation queue with priority lanes (crisis > minors > harassment > spam). Grievance Officer contact published in-app (Indian IT Rules).

**F12 Monetization (India first; all digital goods via store billing):**
- **Aura Plus** — ₹49/month `[price tier to verify]` (global later: $4.99/mo or $39.99/yr). Gets: extra room themes/soundscapes, unlimited mood-trigger capsules, 10-min voice capsules, monthly cosmetic drop, deeper Insights.
- **Cosmetics (sachet)** — ₹10–₹99 one-time avatar auras, rings, trails, room ambience.
- **Gifts (adults 18+ only)** — Warm Tea ₹10, Comfort Lantern ₹29, Encouragement Bouquet ₹49, sent to a pseudonym inside a room. Recipient gets the animation + a small fixed amount of **Stardust** (soft currency, earned or gifted, spent only on cosmetics, never cashable, never transferable).
- **Never paywalled:** check-in, habits, avatar evolution, rest days, crisis support, rooms, the co-op game, date capsules.
- Rewarded ads: **not in v1**. P2, adults only, never tied to streaks.

## Tech stack (proposed; solo-friendly)
Flutter (stable, Impeller) · Riverpod 2 + riverpod_generator · GoRouter (deep links) · Freezed · Drift (SQLite offline store, encrypted) · Rive (avatar + game visuals, state machines) · Supabase in **ap-south-1 Mumbai**: Postgres + RLS, Auth, Realtime (Broadcast + Presence), Storage, Edge Functions, pg_cron, Supabase Queues · Billing via **RevenueCat** over StoreKit 2 / Play Billing `[ASSUMPTION]` · Push via FCM (+APNs) · Analytics: PostHog (self-host or EU cloud) `[ASSUMPTION]` with minors fully suppressed · Crash: Sentry or Crashlytics · Moderation: server classifier + custom EN/HI/Hinglish lexicon (vendor TBD). AK's usual NestJS + Redis/BullMQ worker is **deferred** until Edge Functions stop being enough (likely moderation pipeline at scale).

## Targets (use these numbers; success / stretch)
- Onboarding completion ≥ 70% · first check-in during onboarding ≥ 90% of completers
- D1 35% / 45% · D7 18% / 25% · D30 10% / 15% · DAU/MAU 25% / 30%
- ≥ 25% of check-ins lead to a room visit · ≥ 1.5 gestures sent per room visit · Breath Ripples match (human or echo) p50 < 20 s
- "Did you feel less alone?" micro-survey after room visit: ≥ 60% yes
- Paid conversion (India, 60 days after monetization launch): 2% / 5% of MAU (research doc claims 6.5–10.5% — treat as unproven)
- Safety: reports < 5 per 1,000 room visits; crisis-flagged items actioned < 15 min during Lantern Hour, < 1 h otherwise; all reports actioned < 24 h
- North Star: **Weekly Supported Users** = users who check in on ≥ 3 days in a week AND have ≥ 1 social moment (gesture given/received, reflection, or Breath Ripples session).
- Research doc targets a K-factor > 1.1; for a pseudonymous wellness app a realistic target is **K 0.15–0.3**; growth comes from campus partnerships, creators, share cards and ASO.

## Timeline frame (AK solo, start Mon 5 Oct 2026)
- **Milestone A — Closed alpha, 18+ only** (≈ wk 12, late Dec 2026): F1–F5, F9 core, F8 without minors. ~300–500 invited users (research said 2,500; solo ops can't moderate that yet).
- **Milestone B — India campus beta** (≈ wk 24, mid-Mar 2027): + F6 reflections, F7 Breath Ripples, F8 parental consent (13–17 pool opens), F12 monetization, F10, F14.
- **Milestone C — India public launch** (≈ wk 32, mid-May 2027): + F11 widget, F13 share cards, store polish, ASO.
- Global launch after C (not dated).

## Writing rules (all sections)
- Markdown. Start your file with `## <Section Title>` (no number — AK will number at assembly). Use `###` / `####` below it.
- Scannable: bold the key phrase of important bullets, use tables where they help. No marketing fluff, no filler intros, no "In today's world". Avoid em-dash overuse; use plain words.
- Requirements: ID + one-line behaviour + acceptance criteria (Given/When/Then or checklist incl. at least one negative case). Mark priority P0/P1/P2.
- Currency INR, excl. GST. Dates absolute.
- Minors: whenever a behaviour differs for 13–17, say so explicitly.
- Do not invent market statistics. If you cite a research-doc number, say "(research doc)".
- Tag unknowns `[ASSUMPTION]`, legal-dependent items `[LEGAL]`, store-policy-dependent items `[STORE]`.
- Keep to the length budget you're given. Write only your assigned file(s). Do not edit other files.
