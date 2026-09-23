## Timeline, Phasing & Delivery Risks

**Frame:** AK builds solo with AI coding tools, starting **Mon 5 Oct 2026**. AK supplied the character art and Claude animates it in code; a lawyer is engaged from week 0. AK is the only moderator until 5,000 DAU. Scope is the full research Phase 1–2 (D1) on Flutter + Supabase + NestJS/BullMQ with own billing validation (D5). Public launch is **Thu 30 Sep 2027** (week 52), which leaves about 3 weeks of buffer.

**Status on 23 Sep 2026.** Built before the 5 Oct start:
- foundations, except PostHog + Sentry;
- F1, except backfill; habits and the Starlight ledger; F2; F3;
- from later weeks: voice notes, History and account deletion.

AK approved the competitor-integration waves (`docs/competitor-integration-plan.md`), which add about 11.5 weeks: Wave 1 ≈ 3.5 with A, Wave 2 ≈ 4.5 with B, Wave 3 ≈ 3.5 with C. That lead plus the ~3-week buffer pays for them, which leaves little slack, so the scope-cut levers below are the contingency. Later rows can start early because weeks 1–9 are largely done. Wave items sit next to the work they depend on.

### Milestones
| Milestone | Target | Audience | Ships |
|---|---|---|---|
| **A: Closed alpha** | **Wk 14 · w/e 10 Jan 2027** | 300–500 invited testers (13+), worldwide except EU/UK/AU | **App shell** (Home · Sanctuary · [Check-in] · Rooms · Insights) + **Safety Center route**; F1 Check-in incl. 7-day backfill and guided prompts; F2 Avatar (character art + code layers) incl. Journal auto-complete and the **companion response**; **"A minute for you"**; **F15 Sanctuary v1** (Breathe, grounding, Today's minute); F3 Streaks; F4 Capsules; F5 Rooms (gestures, Lantern Hour local time); F9 core safety; F8 accounts + DOB gate, native Apple/Google sign-in, platform age signals; F14 subset (daily reminder, date-capsule push); English + Telugu + Tenglish; admin console v0 |
| **B: Open beta** | **Wk 30 · w/e 2 May 2027** | Public beta via TestFlight public link + Play open testing; **EU/UK/AU added if legal clears** | + F6 Reflections (lexicon → OpenAI → human), F7 Breath Ripples (on the F15 pacer engine), F12 Monetization (NestJS validation, Plus first month free; sky themes + soundscape pairing), F10 Insights (+ weekly insight card, "Your month in stars"), F14 Notifications (+ wind-down reminder), **F15 Sounds**, F5 room lanterns + Tonight's intention, Hindi + Hinglish UI |
| **C: Public launch** | **Thu 30 Sep 2027** (wk 52) | App Store + Play Store | + F11 Widget, F13 Share cards + keepsakes, **F16 Quiet Together** + Lantern Hour wind-down, F10 Look back, Hindi/Hinglish rooms (if moderation ready), ASO in 5 languages, security and compliance hardening |

### Build sequence (AK)
| Weeks | Work | Exit criteria |
|---|---|---|
| **0 (in parallel, not code)** | Lawyer: privacy notice (incl. full DOB, sensitive data, cross-border processors), terms, SPDI consent text, grievance setup, **review of risk register R1–R7**. Apple age-rating questionnaire dry-run. Create app records under AKVega. OpenAI and PostHog org setup | Lawyer engaged; expected age rating known (13+ vs 16+/18+) |
| **1–4** (w/e 1 Nov) | Foundations: Flutter skeleton; design tokens + **procedural render system** (shader pipeline, quality tiers, static fallback); Supabase schema + **RLS test harness**; **NestJS monolith (API + Worker) + Redis/BullMQ on DigitalOcean Mumbai + CI**; auth; DOB gate + under-13 device lock; Drift outbox; PostHog + Sentry; i18n scaffold (en, te, te-Latn). **Built before 5 Oct except PostHog + Sentry.** Added: app shell (5 positions) + Safety Center route; native Sign in with Apple / Google Sign-In (ID token → Supabase); platform age signals | Sign-up to empty home on both platforms; RLS + API tests in CI; shell and native sign-in on both platforms |
| **5–6** | F1 Check-in, habits, Starlight ledger (NestJS) + daily caps. **Built** (incl. voice notes, History, 24 h edit). Added: 7-day backfill, Journal auto-complete, guided prompts, companion response, "A minute for you" | < 5 s mood-only check-in, works offline; saved-moment order tests pass (REQ-CMP-06) |
| **7–9** | F2 avatar: character base + code layers (`AuraAvatarState` + manifest → renderer, 5 stages, Resting Nebula), F3 streaks + rest days. **Built.** Added: **F15 Sanctuary v1**: pacer engine (reused by F7), Breathe (3 patterns, haptics), grounding library, Today's minute | 60 fps mid-range, tier drop on low-end; rest-day tests incl. timezone change; Breathe works offline, with Reduce Motion and with haptics off |
| **10** | F4 Capsules: date + mood-trigger, envelope encryption, BullMQ unlock jobs, voice, composer prompts; F14 subset: daily reminder + date-capsule push | Capsule sealed offline opens on schedule |
| **11–12** | F5 Rooms: NestJS matcher (`language × quadrant × tz_region`), pseudonyms, gestures, Realtime, local Lantern Hour; F9 core safety (report/block/mute, crisis sheet India/US/generic, lexicon EN/TE/Tenglish) | No `user_id` in any stranger-facing response (contract test) |
| **13** | Admin console v0 (Next.js → NestJS: queues, actions, audit, grievance inbox, 24×7 legal-order paging); Telugu/Tenglish copy review; TestFlight + Play closed testing | A test takedown order pages AK |
| **14** | **Milestone A** | |
| **15–17** | F6 Reflections + moderation pipeline; **minors & grooming lane** + instant-ban/evidence/reporting SOP; evidence holds (180 d); de-identified moderation corpus; F5 room lanterns + Tonight's intention. In parallel (not code): Sounds stem sourcing + licence log | Publish p50 < 2 s; fail-closed overnight; lantern never dims (REQ-ROOM-13) |
| **18–20** | F7 Breath Ripples on the F15 pacer engine: procedural ocean, sessions, echoes (opt-out), haptics, accessible mode | p50 match < 20 s; disconnect never shows failure |
| **21–23** | F12 billing in NestJS: App Store Server Notifications V2, Play RTDN via Pub/Sub, signed-payload verification; Plus (1-month free trial → ₹49 / ₹399), cosmetics incl. sky themes + soundscape pairing, gifts, Stardust | Sandbox: trial → paid, refund, grace, cancel on both stores |
| **24–25** | F10 Insights + weekly insight card + "Your month in stars"; F14 notification rules (incl. trial-ending and wind-down reminders); Hindi + Hinglish UI strings | Native-speaker copy review |
| **26–27** | Compliance: **DPDP readiness for 13 May 2027**; EU/UK/AU gate (Art. 27 representatives, DPIA, Children's Code, AU under-16 assessment). Code, alongside the lawyer-led work: **F15 Sounds** (stem mixer, timer, background audio, night wind-down) | Lawyer go/no-go per region; Sounds offline after one download |
| **28–29** | Beta hardening: realtime load test, Supabase spend cap off, security review of the NestJS/RPC boundary; background-audio store-review check (Apple 2.5.4, Play foreground-service declaration) | No P0 bugs open |
| **30** | **Milestone B** | |
| **31–36** | Beta iteration; online-first growth (Reddit, Instagram/YouTube creators, Discord); F11 widget (SwiftUI + Glance); F10 Look back | D30 ≥ 10% (India cohort) tracked |
| **37–42** | F13 share cards + keepsakes; **F16 Quiet Together** + Lantern Hour wind-down; Hindi/Hinglish rooms if moderation is ready; **first moderator hire at 5,000 DAU**; ASO + listings in 5 languages | Held-item backlog under target; no member list in any Quiet Together payload (REQ-QUIET-01) |
| **43–48** | Launch readiness: final age rating, Data Safety / privacy labels, MASVS L1, re-price for Google's new fees (global by 30 Sep 2027) | Store review dry-run passed |
| **49–51** | Buffer + launch campaign | |
| **52** | **Milestone C: Thu 30 Sep 2027** | |

### Scope-cut levers (pull in this order if a milestone slips by more than 2 weeks)
1. **Gifts → v1.1.** Plus and cosmetics still launch.
2. **F13 share cards and F11 widget → v1.1.** Keepsake cards go with them.
3. **F10 Insights → basic calendar only.** This also removes the weekly insight card and the deeper month in stars.
4. **Hindi/Hinglish rooms → post-launch** (the UI stays translated).
5. **EU/UK/AU opening → after launch.**
6. **F16 Quiet Together** (with the Lantern Hour wind-down) **→ v1.1.**
7. **Look back → v1.1.**
8. **Keepsakes → v1.1.**
9. **Extra Sounds stems (Plus) → v1.1.** The free base set stays.
10. **Room lanterns → v1.1.**

**Never cut** (unchanged): crisis routing, report/block, the reflection moderation pipeline, the minors & grooming lane, 24×7 legal paging, rest days.

**Kept, though not on the never-cut list:** Sanctuary v1 and the companion response. They are cheap and central to the calm promise (competitor plan §5). Levers 6–10 were added by AK on 23 Sep 2026, after the existing levers.

### Timing considerations
- **DPDP main obligations start 13 May 2027**, two weeks into open beta. Compliance work is scheduled for weeks 26–27, and R1 (no parental consent) stays open as an accepted risk.
- **Indian academic calendar:** beta opens in May after most exams; **freshers' season (Jul–Aug 2027) falls inside the beta**, which makes it the natural growth push ahead of the 30 Sep launch.
- **Google's new Play fee structure** reaches all countries by 30 Sep 2027, the launch date, so re-price in weeks 43–48.
- **Single moderator:** growth is throttled by AK's review capacity. Hitting 5,000 DAU triggers a hire; before then, fail-closed holds protect the rooms.

### Delivery risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Solo capacity with NestJS + own billing + worldwide scope | High | High | Scope-cut levers; weekly exit criteria; ~3 weeks of buffer; AI tooling for tests, migrations, copy |
| Own billing validation edge cases (refunds, grace, trial → paid, cross-platform) | Medium | High | Replayable `store_notifications` log; sandbox matrix in weeks 21–23; monitor mismatches weekly |
| Legal risks R1–R7 (see Technical Constraints) | Medium | High | Lawyer review before alpha; region gates at beta; lever 5 and the never-cut list |
| Store rejection (anonymous-chat clause, age restriction, health claims) | Medium | High | Gesture-first design; review notes; age-rating dry-run in week 0 |
| One character base doesn't represent every user | Medium | Medium | Add masculine and androgynous bases in the same style early (asset + manifest only, no code change) |
| Moderation overload before 5,000 DAU | Medium | High | Fail-closed holds; kill switches per language pool; waitlist throttle in beta |
| Rooms feel empty (liquidity), worse when split across regions and languages | High at alpha | Medium | Region merge rules, local Lantern Hour, mood merging, echoes |
| Bus factor = 1 | Medium | High | Everything in the repo + runbooks; managed services; no bespoke infra beyond NestJS |
| Competitor waves (≈ +11.5 weeks) use up the weeks 1–9 lead and the buffer | High | Medium | Levers 6–10 cut the new items first, after the existing levers; weekly exit criteria |
| Background audio questioned in store review | Low `[ASSUMPTION]` | Medium | Audio only while the user plays it; review notes; Play foreground-service declaration with video; Sounds behind a flag |
| A stem's licence turns out unclear | Low | Medium | CC0 / royalty-free only, licence log per stem; replace with a procedural layer (as brown noise already is) |
