## Timeline, Phasing & Delivery Risks

**Frame:** AK builds solo with AI coding tools, starting **Mon 5 Oct 2026**. AK supplied the character art and Claude animates it in code; a lawyer is engaged from week 0. AK is the only moderator until 5,000 DAU. Scope is the full research Phase 1–2 (D1) on Flutter + Supabase + NestJS/BullMQ with own billing validation (D5). Public launch is **Thu 30 Sep 2027** (week 52), which leaves about 3 weeks of buffer.

### Milestones
| Milestone | Target | Audience | Ships |
|---|---|---|---|
| **A: Closed alpha** | **Wk 14 · w/e 10 Jan 2027** | 300–500 invited testers (13+), worldwide except EU/UK/AU | F1 Check-in, F2 Avatar (character art + code layers), F3 Streaks, F4 Capsules, F5 Rooms (gestures, Lantern Hour local time), F9 core safety, F8 accounts + DOB gate; English + Telugu + Tenglish; admin console v0 |
| **B: Open beta** | **Wk 30 · w/e 2 May 2027** | Public beta via TestFlight public link + Play open testing; **EU/UK/AU added if legal clears** | + F6 Reflections (lexicon → OpenAI → human), F7 Breath Ripples, F12 Monetization (NestJS validation, Plus first month free), F10 Insights, F14 Notifications, Hindi + Hinglish UI |
| **C: Public launch** | **Thu 30 Sep 2027** (wk 52) | App Store + Play Store | + F11 Widget, F13 Share cards, Hindi/Hinglish rooms (if moderation ready), ASO in 5 languages, security and compliance hardening |

### Build sequence (AK)
| Weeks | Work | Exit criteria |
|---|---|---|
| **0 (in parallel, not code)** | Lawyer: privacy notice (incl. full DOB, sensitive data, cross-border processors), terms, SPDI consent text, grievance setup, **review of risk register R1–R7**. Apple age-rating questionnaire dry-run. Create app records under AKVega. OpenAI and PostHog org setup | Lawyer engaged; expected age rating known (13+ vs 16+/18+) |
| **1–4** (w/e 1 Nov) | Foundations: Flutter skeleton; design tokens + **procedural render system** (shader pipeline, quality tiers, static fallback); Supabase schema + **RLS test harness**; **NestJS monolith (API + Worker) + Redis/BullMQ on DigitalOcean Mumbai + CI**; auth; DOB gate + under-13 device lock; Drift outbox; PostHog + Sentry; i18n scaffold (en, te, te-Latn) | Sign-up to empty home on both platforms; RLS + API tests in CI |
| **5–6** | F1 Check-in, habits, Starlight ledger (NestJS) + daily caps | < 5 s mood-only check-in, works offline |
| **7–9** | F2 avatar: character base + code layers (`AuraAvatarState` + manifest → renderer, 5 stages, Resting Nebula), F3 streaks + rest days | 60 fps mid-range, tier drop on low-end; rest-day tests incl. timezone change |
| **10** | F4 Capsules: date + mood-trigger, envelope encryption, BullMQ unlock jobs, voice | Capsule sealed offline opens on schedule |
| **11–12** | F5 Rooms: NestJS matcher (`language × quadrant × tz_region`), pseudonyms, gestures, Realtime, local Lantern Hour; F9 core safety (report/block/mute, crisis sheet India/US/generic, lexicon EN/TE/Tenglish) | No `user_id` in any stranger-facing response (contract test) |
| **13** | Admin console v0 (Next.js → NestJS: queues, actions, audit, grievance inbox, 24×7 legal-order paging); Telugu/Tenglish copy review; TestFlight + Play closed testing | A test takedown order pages AK |
| **14** | **Milestone A** | |
| **15–17** | F6 Reflections + moderation pipeline; **minors & grooming lane** + instant-ban/evidence/reporting SOP; evidence holds (180 d); de-identified moderation corpus | Publish p50 < 2 s; fail-closed overnight |
| **18–20** | F7 Breath Ripples: procedural ocean, sessions, echoes (opt-out), haptics, accessible mode | p50 match < 20 s; disconnect never shows failure |
| **21–23** | F12 billing in NestJS: App Store Server Notifications V2, Play RTDN via Pub/Sub, signed-payload verification; Plus (1-month free trial → ₹49 / ₹399), cosmetics, gifts, Stardust | Sandbox: trial → paid, refund, grace, cancel on both stores |
| **24–25** | F10 Insights, F14 notification rules (incl. trial-ending reminder), Hindi + Hinglish UI strings | Native-speaker copy review |
| **26–27** | Compliance: **DPDP readiness for 13 May 2027**; EU/UK/AU gate (Art. 27 representatives, DPIA, Children's Code, AU under-16 assessment) | Lawyer go/no-go per region |
| **28–29** | Beta hardening: realtime load test, Supabase spend cap off, security review of the NestJS/RPC boundary | No P0 bugs open |
| **30** | **Milestone B** | |
| **31–36** | Beta iteration; online-first growth (Reddit, Instagram/YouTube creators, Discord); F11 widget (SwiftUI + Glance) | D30 ≥ 10% (India cohort) tracked |
| **37–42** | F13 share cards; Hindi/Hinglish rooms if moderation is ready; **first moderator hire at 5,000 DAU**; ASO + listings in 5 languages | Held-item backlog under target |
| **43–48** | Launch readiness: final age rating, Data Safety / privacy labels, MASVS L1, re-price for Google's new fees (global by 30 Sep 2027) | Store review dry-run passed |
| **49–51** | Buffer + launch campaign | |
| **52** | **Milestone C: Thu 30 Sep 2027** | |

### Scope-cut levers (pull in this order if a milestone slips by more than 2 weeks)
1. **Gifts → v1.1.** Plus and cosmetics still launch.
2. **F13 share cards and F11 widget → v1.1.**
3. **F10 Insights → basic calendar only.**
4. **Hindi/Hinglish rooms → post-launch** (the UI stays translated).
5. **EU/UK/AU opening → after launch.**
6. Never cut: crisis routing, report/block, the reflection moderation pipeline, the minors & grooming lane, 24×7 legal paging, rest days.

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
| Legal risks R1–R7 (see Technical Constraints) | Medium | High | Lawyer review before alpha; region gates at beta; levers 5 and 6 |
| Store rejection (anonymous-chat clause, age restriction, health claims) | Medium | High | Gesture-first design; review notes; age-rating dry-run in week 0 |
| One character base doesn't represent every user | Medium | Medium | Add masculine and androgynous bases in the same style early (asset + manifest only, no code change) |
| Moderation overload before 5,000 DAU | Medium | High | Fail-closed holds; kill switches per language pool; waitlist throttle in beta |
| Rooms feel empty (liquidity), worse when split across regions and languages | High at alpha | Medium | Region merge rules, local Lantern Hour, mood merging, echoes |
| Bus factor = 1 | Medium | High | Everything in the repo + runbooks; managed services; no bespoke infra beyond NestJS |
