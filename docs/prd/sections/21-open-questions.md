## Decision Record & Remaining Actions

All open questions were put to AK and answered on **23 Sep 2026**. "Rec." means AK took the recommended option. "Changed" means AK chose differently from the recommendation, and the PRD follows AK's choice.

### Answers
| # | Question | AK's answer | |
|---|---|---|---|
| D4 | Storefront availability | **Worldwide from alpha; EU, UK and Australia open at beta** | Changed |
| D5 | Stack | **Flutter + Supabase + NestJS + Redis/BullMQ from day one** | Changed |
| Q3 | Developer accounts | **AKVega's existing company App Store + Play accounts**; AKVega owns and publishes Aura and is the data fiduciary | n/a |
| — | Teens outside India | Superseded by D2 (all ages 13+ worldwide) | n/a |
| Q13 | Min OS | iOS 16 + Android 7 | Rec. |
| DS-1 | Private content protection | Envelope encryption | Rec. |
| DS-2/3 | Identity in rooms | Fresh pseudonym per room + mood-at-join chip | Rec. |
| DS-4 | Room retention | 24 h + 7-day memory; legal holds excepted | Rec. |
| DS-5 | Progress authority | Server ledger | Rec. |
| DS-6 | Age storage | **Full date of birth** | Changed |
| DS-7 | Crisis records | Aggregate only | Rec. |
| DS-8 | Teen Local Mode data | Upload after consent, now **N/A** (no Local Mode) | Rec., moot |
| DS-9 | Purchase tracking | **Own validation in NestJS** (no RevenueCat) | Changed |
| DS-10 | Stranger-facing reads | NestJS / RPC layer | Rec. |
| Q4 | Legal setup | AK is Grievance Officer; lawyer engaged week 0 | Rec. |
| **D2** | **Age policy** | **13+ with full access, no parental consent** (Q5 and Q22 withdrawn) | **Changed; risk accepted** |
| — | Teen matching | **Everyone in one mixed pool** | Changed; risk accepted |
| Q21 | Parent access requests | Minimise + disclose (only relevant if a parent invokes DPDP rights) | Rec. |
| Q6 | AI moderation | **OpenAI omni-moderation only** (no LLM classifier) | Changed |
| Q7 | Evidence retention | 180 days | Rec. |
| Q24 | Training corpus | Keep de-identified labelled reflections with notice + opt-out | Rec. |
| Q23 | CSAM / grooming | Instant ban + preserve + mandatory report | Rec. |
| Q8 | Crisis-flow review | **Self-review against published safe-messaging guidelines** | Changed |
| Q9 | Art | **Hybrid:** AK supplied the character art (AI-generated celestial meditator); Claude builds every animated layer in code (no animator) | Changed |
| Q17 | Moderators | **AK alone until 5,000 DAU** | Changed |
| Q18 | First users | **Online-first, no campus partners** | Changed |
| Q19 | Plus pricing | **First month free, then ₹49/month or ₹399/year** | Changed (trial length) |
| Q12 | Public launch | **End of September 2027** (30 Sep 2027) | Changed |
| Q11 | GST | AKVega is registered; CA confirms store-billed treatment | Rec. |
| Q20 | Google User Choice Billing | Revisit after launch | Rec. |
| Q14 | Analytics | PostHog Cloud | Rec. |
| Q15 | Languages | **English → Telugu → Tenglish → Hindi → Hinglish** | Changed |
| — | Helplines worldwide | **India + US + generic local-emergency fallback** | Changed |
| — | Lantern Hour | 9–11 pm local time, rooms grouped by timezone region | Rec. |
| — | Language rollout | Staged: alpha en/te/te-Latn; beta + hi/hi-Latn UI; Hindi rooms when moderation is ready | Rec. |
| — | Remaining defaults | Accept all (4 am day, Starlight economy, gift values, limits, echoes opt-out); tune in alpha | Rec. |

### Competitor integration and screen plan (23 Sep 2026, PRD v1.2)
On the same day AK approved `docs/competitor-integration-plan.md`, accepting every recommendation, and settled the open questions in `docs/screen-plan.md`.

| # | Question | AK's answer | |
|---|---|---|---|
| CI-1 | Add a private calm feature? | **Yes: F15 Sanctuary.** Milestone A: Breathe (avatar-orb pacer; calm 4/6, box, 4-7-8; haptics obey Comfort; Reduce Motion = text + haptics; no score; ≥ 60 s logs Breathe; the same engine later drives F7), grounding library (5-4-3-2-1, hand-on-heart, gratitude; nothing stored), Today's minute. Milestone B: **Sounds** (stem mixer, timer, background playback, offline, silent until chosen, nightly reshuffled wind-down, no narration) | Rec. |
| CI-2 | Soundscape pricing | **Base soundscapes free** (never paywalled); **Plus adds extra stems and themes** ("more of") | Rec. |
| CI-3 | Audio source | **A mix:** licensed CC0 / royalty-free field recordings for base stems plus procedural layering. No binaural or health claims. Background audio (iOS `UIBackgroundModes: audio`, Android media playback service); no microphone | Rec. |
| CI-4 | Should the avatar respond to each check-in? | **Yes (A):** ≤ 2 s quadrant-tinted shimmer (still under Reduce Motion) + one warm localized line; equal warmth for every quadrant; never advice or diagnosis | Rec. |
| CI-5 | "A minute for you": which quadrants? | **All four (A)**, equal dignity: Storm → 30 s grounding, Rain → gentle comfort, Moonlight → stillness, Sunrise → savour. Optional, after Save; never replaces the crisis sheet; not shown after it. F1 order: crisis sheet → capsule (held on crisis) → Starlight + companion response → minute + room offer | Rec. |
| CI-6 | Guided prompts | **Yes (A):** optional rotating prompt in the F1 note and F4 composer; localized; skippable | Rec. |
| CI-7 | F10 additions | **Weekly insight card** (descriptive only; REQ-INS-03 still applies) and **"Your month in stars"** (basic free, deeper Plus) at B. **Look back** at C: pull-only, notes/voice on tap, never right after a Storm/Rain check-in or within a day of a crisis sheet, crisis-flagged entries excluded, never pushed | Rec. |
| CI-8 | Keepsakes; visible to strangers? | **Keepsakes at C** (F13): earned-only seals, private box + share cards; never sold, never lost, **never visible to strangers** | Rec. |
| CI-9 | F5 additions | **Room lanterns** (anonymous, room-scoped, additive-only; no individual counts; nothing fails) and **Tonight's intention** (room-level, gestures only, no pairing) at B | Rec. |
| CI-10 | Quiet Together at Milestone C? | **Yes, as F16:** time-boxed drop-in co-presence (study / read / rest), counts and gestures only, shared soundscape played locally from a common start (no user audio), optional 25/5 rhythm, leaving costs nothing; plus the **Lantern Hour wind-down** | Rec. |
| CI-11 | Confirm the rejections | **Confirmed** (see Out of Scope): stranger letters, stranger accountability partners, voice/audio circles, user-created circles and creator skins, coaching marketplace, social-media memory import, HP/gold economy, nostalgia streaks, celebrity sleep stories, meditation videos. **Pathways deferred** to after launch | Rec. |
| CI-12 | Screen-plan questions | **Shell:** Home · Sanctuary · [Check-in] · Rooms · Insights ("Rooms" is the F5 space, the screen plan's "Universe"; Insights shows History until F10). **Safety Center:** full route `/safety` opened by "I need help now"; the sheet is for contextual/crisis interception. **Age:** stays 13+ (D2 unchanged). **Reflections:** stay in v1 as F6 at Milestone B; the screen plan's "no public UGC" note is superseded. **Intensity and body signal:** post-v1 | Rec. |
| CI-13 | What else joins Milestone A? | App shell + Safety Center route, F15 Sanctuary v1, companion response, "A minute for you", guided prompts, native Sign in with Apple (iOS) and Google Sign-In (ID token into Supabase), platform age signals as specified, F1 7-day backfill, Journal auto-complete, F14 subset (daily reminder, date-capsule push) | Rec. |
| CI-14 | If a milestone slips | Cut after the existing levers: Quiet Together → Look back → Keepsakes → extra Sounds stems → room lanterns. Never-cut list unchanged | Rec. |

### Still waiting on someone else (not decisions: actions)
| # | Action | Owner | By |
|---|---|---|---|
| A1 | Review legal risk register **R1–R7** (no parental consent, US state laws, EU/UK/AU, mixed-age rooms, App Review, crisis copy, single moderator) and advise mitigations that fit D2 | Lawyer | Before alpha (wk 12) |
| A2 | Privacy notice covering full DOB, sensitive (mental-health) data, OpenAI as a cross-border processor, echoes and moderation corpus with opt-outs | Lawyer | Wk 10 |
| A3 | Mandatory-reporting SOP (POCSO / IT Rules) for sexual content involving minors and grooming; 180-day evidence store | Lawyer | Wk 15 |
| A4 | EU/UK/AU go/no-go (Art. 27 representatives, DPIA, Children's Code, AU under-16 law) | Lawyer | Wk 27 |
| A5 | Who remits GST on store-billed sales, and any TDS | CA | Wk 21 |
| A6 | Apple age-rating questionnaire dry-run: does unrestricted stranger interaction + UGC come out 13+ or higher? | AK | Wk 0–1 |
| A7 | Confirm Apple INR price points (₹10 / ₹29 / ₹49 / ₹99 / ₹399) and the 1-month free-trial introductory offer on both stores | AK (console) | Wk 21 |
| A8 | Android Block Store persistence across reinstall (for the under-13 device lock) | AK (eng spike) | Wk 3 |
| A9 | Crisis lexicon and support-sheet copy self-review against WHO and similar safe-messaging guidance, in all 5 languages | AK | Wk 12 |
| A10 | Plan the first moderator hire (Telugu + Hindi reading) so it can happen within 2 weeks of reaching 5,000 DAU | AK | By beta |
| A11 | Safe-messaging self-review of the companion lines, "A minute for you" copy, guided prompts and grounding scripts in en / te / te-Latn (with A9) | AK | Wk 12 |
| A12 | Source the base Sounds stems (CC0 / royalty-free) with a licence log; confirm the background-audio review position (Apple 2.5.4, Play foreground-service declaration) | AK | Wk 25 |
