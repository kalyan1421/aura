# Aura: Full Project Handbook

> One self-contained reference for the whole Aura project: the product, every feature, screen and flow, the rules,
> the architecture, the data, the API, safety, design, localization, testing, release and open items.
> Written so any agent (or person) can pick up work without reading the rest of the repo first.

| | |
|---|---|
| **Product** | Aura: a pseudonymous, social and gamified mood check-in app for iOS and Android |
| **Owner / publisher** | **AKVega** (company App Store and Play accounts; data fiduciary / controller) |
| **Built by** | Kalyan Kumar Bedugam (**AK**), solo, with AI coding tools. AK is also the only moderator and the Grievance Officer |
| **Repo** | Private GitHub `kalyan1421/aura`, default branch `main`; active work branch `fix/design-audit`; analytics + CI parked on `wip/analytics-ci` |
| **App ids** | `com.akvega.aura` (both platforms) · version `1.0.0 (2)` · iPhone only on iOS |
| **Handbook date** | 27 Sep 2026 (branch `fix/design-audit` at `faca132`) |
| **Spec source of truth** | `docs/PRD.md` v1.3 (assembled from `docs/prd/sections/*.md`; edit sections, never PRD.md) |
| **Rules source of truth** | `contracts/rules/RULES.md` + `contracts/rules/vectors/*.json` (Dart and TypeScript must both pass) |

**How to read this.** Sections 1–5 explain the product and its decisions. Sections 6–8 are the architecture and the
shared rules. Section 9 is every feature. Sections 10–11 are every screen and every flow. Sections 12–27 are the
cross-cutting systems (safety, notifications, sync, data, API, admin, design, a11y, l10n, billing, security, legal,
testing, release). Sections 28–31 are what is out of scope, what is still open, and the rules any agent must follow.
Where the spec (PRD) and the build differ, both are stated.

**Status tags used below:** **Built** = in the code with tests · **Blocked on AK** = code done or not needed, waits
on something only AK can supply · **Parked** = deliberately not active · **Spec** = described in the PRD.

---

## Table of contents

1. Product in one page
2. Current status (27 Sep 2026)
3. Locked decisions
4. Personas and the core journey
5. Glossary
6. Architecture and repository
7. Mood catalogue, tags and habits
8. Progression rules (Starlight, stages, hue, streaks, nebula)
9. Features F1–F16 in detail
10. Navigation and every screen
11. Key user flows (step by step)
12. Safety, moderation and crisis routing
13. Notifications
14. Permissions
15. Offline mode and sync
16. Data model and migrations
17. API surface (NestJS `/v1` and `/admin`)
18. Remote config, flags and kill switches
19. Admin and moderation console
20. Design system
21. Accessibility
22. Localization
23. Monetization (Aura Plus, cosmetics, gifts)
24. Analytics (parked)
25. Security and privacy engineering
26. Legal, compliance, store and public site
27. Testing, tooling and commands
28. Hosting, deploy and release
29. Out of scope (v1)
30. Open items, blocked items and remaining work
31. Rules every agent must follow
32. Where to find things (doc index)

---

## 1. Product in one page

### What Aura is
A calm, pseudonymous app built around one loop:

> **Check in (2 taps) → your avatar glows → you're not alone → come back tomorrow.**

1. **Check in** with how you feel in under 5 seconds from a fixed 4×4 mood grid (F1).
2. **Grow your Aura**, a celestial avatar that *is you*. It evolves as you look after yourself and **never dies or
   regresses**; on hard days it rests in a protective nebula (F2, F3).
3. **Sit with strangers who feel the same** in a 24-hour mood room, matched by mood, language and local evening.
   People send silent preset gestures and short moderated reflections. No profiles, no DMs, no follower counts (F5, F6).
4. **Breathe together**: a 3-minute co-op breathing game with strangers. No score, no fail state (F7).
5. **Write to your future self**: time capsules that open on a date or the next time you feel a certain way (F4).
6. **Settle on your own**: a private Sanctuary with a breathing pacer, grounding exercises and offline soundscapes
   (F15). After every check-in the avatar answers with one warm line and offers an optional minute of calm.
7. **Study, read or rest together** silently in Quiet Together: a count, a shared sound, gestures, nothing else (F16).

### Who it is for
- Everyone **13+**, full access, one shared pool. Under-13s are blocked.
- Core audience: Indian students and young professionals, **Telugu / Tenglish first**, then Hindi / Hinglish.
- Available worldwide; EU, UK and Australia open only at beta after a legal checklist.

### Why
Incumbents are solo trackers (Daylio: broken streaks make people quit) or friends-only (Finch). Nobody offers
low-pressure *stranger* support without chat. Therapy in India is scarce, expensive and stigmatised.

### What Aura is not
**Not therapy, not a diagnostic tool, not an emergency service, not chat.** This line shapes copy, store listings and
moderation. The disclaimer "Aura is not a medical device or an emergency service" appears in onboarding, Settings,
the Safety Center and the store listings.

### Product principles (apply to every decision)
- **Non-punitive by construction.** Nothing you care about is ever taken away. No red, no loss copy, no streak-loss
  pushes, the avatar never gets sick or smaller.
- **Equal dignity for every feeling.** Storm, Rain, Moonlight and Sunrise get the same size, motion, warmth and number
  of options. No feeling is ranked, scored or treated as a problem to fix.
- **Private by default.** Mood, notes, history and insights stay on the phone or encrypted. Nothing on a lock screen
  reveals how someone feels.
- **Stranger connection without chat.** Empathy through gestures, not conversation.
- **Help first.** "I need help now" is on every screen, works offline and signed out, and is never behind a paywall.
- **Calm, not treatment.** Copy says what to do ("breathe with the orb"), never what it achieves ("reduces anxiety").

### North Star and key targets (PRD 02)
- **North Star: Weekly Supported Users (WSU)** = users who check in on ≥ 3 days in a week **and** have ≥ 1 social
  moment (gesture given/received, reflection published, or Breath Ripples session completed).
- Onboarding completion ≥ 70% · mood-only check-in median < 5 s · room conversion ≥ 25% · "felt less alone" ≥ 60% ·
  D1 35% / D7 18% / D30 10% · paid conversion 2% of MAU · rating ≥ 4.5.
- Guardrails: reports < 5 per 1,000 room visits; crisis items < 15 min in Lantern Hour, < 1 h otherwise; all reports
  < 24 h; under-18 reports < 4 h; grooming / minor sexual content 100% instant ban + evidence + report.
- All behavioural targets are measured on **18+ users only**.

### Timeline (PRD 20)
| Milestone | Target | Ships |
|---|---|---|
| Build start | Mon 5 Oct 2026 | (most of weeks 1–9 was built before this) |
| **A: Closed alpha** | w/e 10 Jan 2027 | App shell + Safety Center; F1 (incl. backfill, prompts); F2 + companion response + "A minute for you"; F15 Sanctuary v1; F3; F4; F5 rooms (gestures, Lantern Hour); F9 core safety; F8 accounts + DOB gate + Apple/Google sign-in + age signals; F14 subset; en/te/te-Latn; admin console v0 |
| **B: Open beta** | w/e 2 May 2027 | + F6 reflections, F7 Breath Ripples, F12 monetization, F10 Insights (+ weekly card, month in stars), F14 rest, F15 Sounds, room lanterns + Tonight's intention, Hindi + Hinglish UI |
| **C: Public launch** | Thu 30 Sep 2027 | + F11 widget, F13 share cards + keepsakes, F16 Quiet Together + wind-down, Look back, Hindi/Hinglish rooms (if moderation ready), ASO in 5 languages, hardening |

**Scope-cut levers (in order):** gifts → share cards + widget → Insights to basic calendar → Hindi/Hinglish rooms →
EU/UK/AU → Quiet Together → Look back → keepsakes → extra Plus stems → room lanterns.
**Never cut:** crisis routing, report/block, the reflection moderation pipeline, the minors & grooming lane, 24×7
legal paging, rest days.

---

## 2. Current status (27 Sep 2026)

**The code for Milestones A, B and C is essentially complete.** The audit in `docs/status/pending.md` (104 rows over
every PRD requirement) ends at: **89 done, 1 partial, 0 missing, 9 blocked on AK, 5 out of scope.**

### Recent state of the branch
- **v1.0 launches free.** The `plus_enabled` flag (bundled default **off**, missing row counts as off) hides every
  purchase surface: no paywall, no Plus/gift cards, no Restore, the store plugin is never initialised. Plus-only
  features keep their calm "Part of Aura Plus" line. Store descriptions for v1.0 omit Aura Plus.
- App icons ("Equal Orbit"), store screenshots (App Store 6.9", Play phone) and store listings exist.
- iOS is iPhone-only with the export-compliance key; release scripts for iOS (TestFlight upload) and Android (AAB).
- Production build config points at the live API, Supabase project and Google client ids.
- App Review sign-in: `POST /v1/auth/review-sign-in` with a fixed code for one configured review account.
- Backend runs on **Render Free (Singapore)**: one web service runs API + worker together, Render Key Value as Redis.
- Legal / support pages are live on Firebase Hosting: `https://aura-akvega.web.app` (privacy, terms, support +
  Grievance Officer, delete-account, child-safety).
- Uncommitted in the working tree: edits to the Android `full_description.txt` (en-IN, en-US).

### Last verification recorded (`docs/status/pending.md`)
| Suite | Result |
|---|---|
| `packages/aura_domain` `dart test` | 353 passed |
| `apps/mobile` `flutter analyze` / `flutter test` | no issues / 2,352 passed (5 skipped) |
| `apps/mobile` builds | `flutter build ios --simulator --debug` and `flutter build apk --debug` built |
| `server/aura-api` `pnpm test` / `pnpm lint` / `pnpm test:e2e` | 1,500 passed / clean / 322 passed (19 suites) |
| `supabase test db` (pgTAP) | every file passes (00–35) |
| `apps/admin` typecheck / lint / test / build | clean / clean / 41 passed / built |

### What is blocked on AK (no code left, or code done and waiting)
- **Lawyer:** SPDI consent notice, privacy notice (incl. moderation corpus and export), risk register R1–R7, POCSO /
  IT Rules SOP, EU/UK/AU go/no-go, GAC appeal wording. `trust_screen.dart` has a `TODO(legal)`.
- **CA:** GST / TDS on store sales.
- **Store consoles:** app records under AKVega, storefront availability, age-rating questionnaire, INR price points
  and free-month offer, TestFlight / Play testing, sandbox matrix, background-audio review notes and Play
  foreground-service video, final Data Safety / privacy labels.
- **Native + safe-messaging review:** crisis lexicon (incl. the Hindi / Hinglish candidates) and 200-phrase recall
  sets per language; companion lines, prompts, grounding copy; all te / te-Latn / hi / hi-Latn copy.
- **Assets:** licensed CC0 / royalty-free base sound stems (procedural stand-ins play today), store screenshots review,
  App Review "report actioned" recording, VoiceOver / TalkBack passes, PEAT flash check.
- **Credentials / infra:** production env hardening (`NODE_ENV`, `TRUST_PROXY`, Supabase settings, Firebase key
  restrictions), secrets custody, paging webhooks, SMTP, Apple DeviceCheck key and Play Integrity project (device-ban
  attestation), Android upload key + Play App Signing, a domain for Universal / App Links, external pen test.
- **Real-device spike:** does Android Block Store survive a reinstall (under-13 lock).
- **Decision:** whether sandbox-granted Plus expires at public launch.
- **People:** first moderator hire plan; screen-reader beta testers.

### Remaining code work (known, planned)
1. **Master-key rotation** (large, 2–3 days): split `AURA_HMAC_KEY` from `AURA_MASTER_KEY`, key ids on every wrapped
   blob, a re-wrap CLI, a runbook.
2. **Sandbox entitlements expiry** once AK decides.
3. **Admin console** `__Host-` cookie prefix and prefetch CSP.
4. **`NODE_ENV` required at boot** (one-line schema change, left to AK).
5. **Aggregate crisis counters** (`POST /v1/crisis-events`, no user id) if wanted before the rest of analytics.

---

## 3. Locked decisions

Do not relitigate these. They are AK's calls, recorded in the PRD Decision Record.

### Product decisions
| # | Decision |
|---|---|
| D1 | v1 = research Phase 1–2 in full, incl. reflections and one co-op game |
| D2 | **13+ with full access, no parental consent, one mixed-age pool.** Under-13 blocked with a 30-day device lock. Under-18s get only invisible protections (analytics exclusion, stricter moderation, minors lane). Legal risk explained and accepted by AK |
| D3 | AK builds solo; avatar = AK's AI-generated character art + code-animated layers; no animator, no Rive in v1 |
| D4 | Worldwide from alpha except EU/UK/Australia until beta; AKVega publishes |
| D5 | Flutter + Supabase + NestJS modular monolith + Redis/BullMQ; own receipt validation (no RevenueCat); PostHog Cloud; min iOS 16 / Android 7 |
| D6 | Competitor integrations: Sanctuary, companion response, "A minute for you", guided prompts (A); Sounds, weekly card, room lanterns, Tonight's intention (B); Quiet Together, Look back, keepsakes (C) |

### Data-shape decisions (DS-1…DS-10)
| # | Decision |
|---|---|
| DS-1 | **Envelope encryption** for notes, voice, capsules, media: per-user data key wrapped by a server master key held outside the DB. Crisis detection on private text runs on the device only |
| DS-2 | **Fresh pseudonym per room.** Blocks and strikes follow `user_id` server-side |
| DS-3 | **Mood-at-join chip** on each silhouette; no history, no live updates |
| DS-4 | Room content: **24 h room + 7-day read-only memory**, then hard delete; reported/removed items kept **180 days** in evidence holds |
| DS-5 | **Server ledger decides** Starlight, stage, streaks; the client is optimistic |
| DS-6 | **Full date of birth stored**; `is_minor` computed |
| DS-7 | Crisis events **aggregate only** (no user id); next-day gentle check scheduled on the device |
| DS-8 | No teen Local Mode (N/A under D2) |
| DS-9 | Purchase validation in NestJS (App Store Server API + Notifications V2; Play Developer API + RTDN) |
| DS-10 | **All stranger-facing reads and writes** go through NestJS or reviewed Postgres RPCs returning pseudonyms only. Clients never see another user's account id, age or DOB |

### Competitor-integration decisions (CI-1…CI-14, 23 Sep 2026)
F15 Sanctuary added; base soundscapes free, Plus adds more; CC0 recordings + procedural layering, no binaural or health
claims; avatar responds to every check-in; "A minute for you" for all four quadrants; guided prompts; weekly insight
card + month in stars (B) + Look back (C); keepsakes (C) never visible to strangers; room lanterns + Tonight's
intention (B); Quiet Together (C) as F16; navigation `Home · Sanctuary · [Check-in] · Rooms · Insights`; Safety
Center is a full route `/safety`; reflections stay in v1; intensity and body signal are post-v1.

### Build-time decisions (BD-1…BD-7, 24 Sep 2026)
| # | Decision |
|---|---|
| BD-1 | A crisis report unacknowledged for 5 minutes pages the Owner **at any hour**, repeating every 5 min, no content in the page |
| BD-2 | The automatic ban at the 4th strike is a **social account ban only**; device bans stay an Owner decision |
| BD-3 | Weekly insight card available from Monday 04:00 and stays all week, describing the week that just ended |
| BD-4 | "Your month in stars" is skipped for a month with no check-ins |
| BD-5 | An intention hold can't be undone; leaving doesn't lower the count; one Breath Ripples cycle = 0.25 gesture of lantern light; only Lantern Hour rooms take light; intention hidden in memory view |
| BD-6 | Paywall exclusion "after a Storm or Rain check-in" = **within 3 hours**; "unprompted" = the inline explainer at a limit screen, at most once a day |
| BD-7 | Reflections written offline are **kept as a draft, not queued**; Send is disabled offline |

### Other locked technical choices
- Store billing only (Apple IAP / Play Billing Library 8 via `in_app_purchase`). **No RevenueCat, no Razorpay, no UPI
  direct checkout** for digital goods.
- Art is procedural code (CustomPainter + fragment shaders + `flutter_animate`) on top of one AI-generated character
  PNG. No Rive.
- Locales: `en`, `te`, `te-Latn` (Tenglish), `hi`, `hi-Latn` (Hinglish). Alpha ships en / te / te-Latn.
- IDs are client-generated **UUIDv7**. `local_day` is the **Aura day** (04:00 rollover in the user's IANA zone).
- Only one external moderation classifier: **OpenAI omni-moderation**. No LLM classifier, no Perspective API.
- Helplines are static: India Tele-MANAS, US 988, everywhere else "call your local emergency number". No ThroughLine,
  no findahelpline.com data.

---

## 4. Personas and the core journey

| Persona | Snapshot | Primary features | Biggest risk |
|---|---|---|---|
| **Riya, 20 (primary)** | Engineering student in a Hyderabad hostel, Telugu/Tenglish, mid-range Android, patchy Wi-Fi. Feels a lot, tells no one | F1, F5, F2, F3, F9, F4 | First room feels empty or unsafe; Aura becomes one more diary |
| **Arjun, 26** | First-job engineer in Bengaluru, lives alone, burning out, iPhone, pays for small things | F7, F10, F12, F3, F11 | Feels judged after a gap; Plus feels thin |
| **Meera, 16** | NEET aspirant in Kota, lives in a PG, no privacy | F5, F9, F7 | An adult stranger tries to move her off Aura or sexualise a reflection |
| **Sai, 19** | Telugu-first diploma student, budget Android, storage full, types Tenglish | F1, F5, F6, F2, F12 | Tenglish reflections held too often; app lags |
| **AK / Kabir** | The only moderator until 5,000 DAU (Kabir is the planned hire) | F9, F6 | A crisis or grooming item waits past SLA overnight |

**Tie-break rule:** when a v1 trade-off is unclear, decide in Riya's favour unless it weakens safety for Meera.

**The three moments that decide retention:**
1. **First gesture received (Day 0).** If the first room gives nothing back, Aura is filed as another mood tracker.
2. **The return after the first missed stretch.** Resting Nebula, silent rest days and "Your glow carries on" must
   beat the guilt that ends most tracking habits.
3. **The first mood-trigger capsule opening.** Her own words arriving on the kind of day she wrote them for.

---

## 5. Glossary

| Term | Meaning |
|---|---|
| **Aura day** | The local day with a **04:00 rollover** in the user's IANA time zone. A 01:30 Wednesday check-in counts for Tuesday |
| **Active day** | An Aura day with ≥ 1 check-in or ≥ 1 habit |
| **Quadrant** | One of four mood groups on energy × pleasantness: **Storm** (high energy, unpleasant), **Rain** (low, unpleasant), **Moonlight** (low, pleasant), **Sunrise** (high, pleasant) |
| **Starlight** | Progression points. Only go up; earned only; never sold, spent, gifted or granted by Plus |
| **Stage** | Avatar presence: Spark → Ember → Glow → Radiance → Constellation |
| **Resting Nebula** | The avatar's calm resting look after 2 inactive days. A look, never a penalty |
| **Glow streak** | Active days in the current run. **Lifetime glow days** = distinct active days, never decreases |
| **Rest day** | Banked day that bridges a gap automatically (earn 1 per 4 active days, bank max 3, 1 welcome rest day) |
| **Capsule** | A sealed message to your future self, opened on a date or by a mood trigger |
| **Mood room** | A 24-hour, ≤ 24-member pseudonymous room for one quadrant, language pool and time-zone region |
| **Lantern Hour** | 21:00–23:00 on the region clock, when rooms are busiest |
| **Gesture** | One of 8 presets: Warm Tea, Light a Candle, Hug, Me Too, Soft Rain, Stargaze, Deep Breath, You're Not Alone |
| **Reflection** | A ≤ 200-character moderated post in a room, answered only by gestures (F6) |
| **Pseudonym** | A generated name like "Quiet Comet", fresh per room |
| **Echo** | A labelled, unlinked recording of a past human's breathing that fills an empty Breath Ripples seat |
| **Guide light** | A pacer-driven seat used while the echo library is too small; never presented as a person |
| **Sanctuary** | The private calm tab: Breathe, grounding, Today's minute, Sounds, capsules entry ("Future you") |
| **Companion response** | The avatar's ≤ 2 s quadrant-tinted shimmer and one warm line after each live check-in |
| **"A minute for you"** | One optional calm activity card after Save, one per quadrant |
| **Stardust** | Cosmetics currency a gift recipient receives (10/30/50). Never sold directly, cashed, transferred or expired |
| **Aura Plus** | Subscription (₹49/month or ₹399/year, first month free). "More of", never "better calm". **Off for v1.0** |
| **Keepsake** | An earned-only private seal (first capsule sealed, 7 glow days, etc.) |
| **Language pool** | Room pool by app language: English · Telugu + Tenglish · Hindi + Hinglish |
| **tz_region** | Room time-zone region by device UTC offset: `americas`, `europe_africa`, `south_asia`, `east_asia_pacific` |
| **Lane** | Moderation queue priority: L0 Crisis · L1 Minors & grooming · L2 Harassment · L3 Spam / other |
| **Outbox** | The on-device queue of personal mutations, drained to `POST /v1/sync/push` |
| **Tombstone** | A server-side delete marker that always wins in sync |
| **DS-10 boundary** | The single choke point through which all stranger-facing data flows (NestJS / RPC, pseudonyms only) |

---

## 6. Architecture and repository

### Stack
| Layer | Choice |
|---|---|
| Mobile app | **Flutter** (pubspec: Flutter ≥ 3.44, Dart SDK ^3.13), Impeller. **Riverpod** (`flutter_riverpod` ^3.4 + generator; CLAUDE.md still says "Riverpod 2") · **GoRouter** 18 · **Freezed** · **Drift** (SQLite, encrypted) · Dio · `supabase_flutter` |
| Shared domain | `packages/aura_domain`: pure Dart mood catalogue and progression rules (Starlight, streaks, nebula, stage, hue), `AuraAvatarState` |
| Backend | **NestJS 11 modular monolith**, TypeScript 5.9, Node ≥ 22, **raw `pg` (no ORM)**, Zod, `jose`, **BullMQ 5 + ioredis**, pnpm, Jest |
| Data platform | **Supabase** (Postgres + RLS, Auth, Realtime Broadcast/Presence, Storage private bucket), project in ap-south-1 Mumbai |
| Admin console | Next.js app `apps/admin` → NestJS `/admin` endpoints only; hosted on Vercel (`aura-admin.vercel.app`) |
| Public site | Static pages `apps/site` → Firebase Hosting `aura-akvega.web.app` |
| Push | FCM (APNs via FCM), sent from the NestJS worker; payloads carry no mood or content |
| Moderation | On-device lexicon → server rules + grooming list → OpenAI omni-moderation → human queue |
| Audio | `just_audio` + `audio_session` + `audio_service` (background playback), procedural synth for brown noise and fallbacks; `record` + `audioplayers` for voice notes |
| Widgets | Native: SwiftUI + App Intents (iOS `AuraWidget`, `AuraWidgetCore`), Kotlin Jetpack Glance (Android) |
| Min OS | iOS 16 / Android 7.0 (API 24) |

### Repository layout
| Path | What |
|---|---|
| `apps/mobile` | Flutter app `com.akvega.aura`, feature-first under `lib/src/features/`, shared plumbing under `lib/src/core/` |
| `apps/admin` | Next.js moderation console |
| `apps/site` | Public legal/support site (`site.json` → `python3 apps/site/build.py` → `apps/site/public`) |
| `packages/aura_domain` | Pure Dart domain rules |
| `server/aura-api` | NestJS API (`src/main.ts`) + worker (`src/worker.ts`) |
| `supabase/` | Supabase CLI project: migrations (schema source of truth), RLS, pgTAP tests, seed |
| `contracts/` | Cross-stack contracts: `rules/` (RULES.md + vectors), `moods.json`, `api/v1*.md`, `safety/` (lexicon, helplines, filter), `sounds/stems.v1.json` |
| `infra/docker-compose.yml` | Local Redis |
| `design/` | Avatar master art (`design/avatar/aura_master_v1.png` + manifest) and brand |
| `docs/` | PRD, screen plan, design system, design critique + 138 screen captures, status, setup guides, security, store, l10n, research |
| `tools/` | `audit/deps.sh`, `load/` (realtime load test), `release/` (iOS + Android scripts), `video/` (Remotion feature-tour videos) |
| `render.yaml` | Render blueprint for API + worker + Key Value |
| `firebase.json` | Firebase Hosting for the public site (strict CSP, no scripts) |

### Mobile app structure (`apps/mobile/lib/src/`)
**core/**: `a11y` (haptics, icon scale, motion) · `db` (Drift connection, tables, KV store) · `entitlements` (Plus,
billing API) · `env` (dart-defines) · `ids` (UUIDv7) · `l10n` (locale controller, speech locale) · `net` (Aura API
client, models) · `perf` (device profile → avatar tier) · `prefs` (comfort prefs) · `remote_config` (flags, signed
bundles, helplines, lexicon, device ban, install id, app version) · `router` (routes, redirects, deep links) ·
`security` (note cipher, secure store, session storage) · `sync` (outbox, sync service, pull service, capsule + media
sync) · `theme` (tokens, app theme) · `time` (clock, device tz) · `widgets` (cosmic background, help app bar, notices,
legal links, edge-fade scroller).

**features/** (one folder each): `account` (delete, export, deletion pending) · `auth` (sign-in, social, age signals,
account closed, sign-out) · `avatar` (painter, manifest, moments, debug lab) · `capsules` · `checkin` · `companion`
(lines, response, minute for you, prompts) · `habits` · `history` (list, detail, backfill) · `home` · `insights` (sky,
calendar, cards, look back, month in stars) · `keepsakes` · `onboarding` (welcome, trust, DOB, language, blocked,
gate) · `plus` (paywall, gifts, sky themes, store gateway) · `profile` · `progress` · `push` (prefs, inbox,
explainer, messaging) · `quiet` · `reflections` · `ripples` · `rooms` (home, join, room, lantern, wind-down, report,
member sheet) · `safety` (Safety Center, helpline list) · `sanctuary` (breathe, grounding, sounds) · `settings` ·
`share` · `shell` (app shell) · `support` (support sheet, crisis lexicon, grievance form, helplines) · `update`
(forced update) · `voice` · `widget` (bridge, background, ingest, prefs).

### Backend modules (`server/aura-api/src/`)
`account` (deletion, purge, export, Apple tokens, private media) · `admin` (console endpoints, audit, config,
deletion cases, grievances, legal orders, paging, pseudonyms, region pause, staff, rate limit) · `auth` (JWT
verifier, guards: auth, account-closed, pending-deletion; review sign-in) · `billing` (Apple, Google, catalogue,
entitlements, gifts, store sync, trial reminder, webhooks) · `capsules` (rules, sync, unlock scheduling, media gate) ·
`catalogue` · `common` (errors, log scrub, zod, uuid) · `config` · `db` (pg pool, advisory locks) · `devices` (FCM
tokens, device bans, install id) · `health` · `intentions` (Tonight's intention list + lint) · `keepsakes` (award,
rules, sweep) · `keys` (envelope encryption, data-key endpoint) · `media` (signed upload/download URLs, orphan sweep) ·
`notifications` (catalogue, copy lint, policy, delivery, FCM transport, reminders, welcome back, gestures push,
trial ending, pool waitlist) · `profile` (age, signup throttle) · `progression` (snapshot) · `queues` (BullMQ
registry, maintenance, retention, worker host) · `quiet` (placement, lifecycle, gestures, soundscapes, safety) ·
`reflections` (pipeline decide, moderation provider, cipher, corpus, reports, queue) · `remote-config` (flags, kill
switch decorator, signed lexicon + helplines bundles, app version, CLI) · `ripples` (matcher, echoes, lifecycle,
safety) · `rooms` (matching, pseudonyms + blocklist, gestures + limits, lanterns, lifecycle, regions, wind-down) ·
`rules` (TS port of the rules contract) · `safety` (reports, blocks, guidelines, evidence, moderation service) ·
`sanctuary` · `sync` (push, pull cursors, tombstones) · `user-mail` (trial-ending email).

**BullMQ queues:** `capsule-unlock`, `room-lifecycle` (tick every minute: state transitions, Lantern Hour broadcast,
"here now" sweep, purge at 24 h + 7 d with evidence copied first), `notifications`, `reflections`, `billing`,
`keepsakes`, `quiet`, `ripples`, plus internal `heartbeat` (60 s) and `maintenance` (daily 03:17 UTC sync-mutation
purge; hourly :41 account purge; daily 03:29 retention; orphan media sweep after 30 days).

### Runtime topology
```
 Flutter app ──(Supabase Auth: email OTP / magic link / Apple / Google ID token)──▶ Supabase Auth
     │  reads own rows (PostgREST, RLS select-own) ───────────────────────────────▶ Supabase Postgres
     │  realtime (private Broadcast channels, Presence in rooms/game) ────────────▶ Supabase Realtime
     │  encrypted voice/photo via signed URLs ────────────────────────────────────▶ Supabase Storage (private-media)
     │  ALL personal writes + ALL stranger-facing reads/writes ───────────────────▶ NestJS API (/v1)
     │                                                                              │  service role + pg
     │                                                                              ├──▶ Postgres
     │                                                                              ├──▶ Redis / BullMQ ──▶ Worker
     │                                                                              ├──▶ OpenAI omni-moderation
     │                                                                              ├──▶ App Store / Play APIs
     │                                                                              └──▶ FCM
 Admin console (Next.js) ──(SSO + TOTP, sealed cookies)──▶ NestJS /admin (aura_admin role, audited)
 App Store Server Notifications V2 / Play RTDN (Pub/Sub) ──▶ NestJS webhooks
```

### The two write/read rules (most important architectural invariant)
1. **The app never writes personal tables directly.** RLS on personal tables allows *select own rows* only. All
   personal mutations (check-ins, habit logs and definitions, Sanctuary session records, capsule seal/open/fire/
   rearm/delete, settings, notification prefs, tombstones) go through **`POST /v1/sync/push`**, which upserts rows and
   appends `starlight_ledger` entries in one transaction. The server ledger is authoritative (DS-5).
2. **Stranger-facing data only flows through NestJS / reviewed RPCs** that return pseudonyms and random `member_id`s
   (DS-10). No response to another client ever contains an account id, age, DOB or under-18 flag. Contract tests
   scan payloads for this (`rooms.e2e-spec.ts`, `ripples.e2e-spec.ts`, `quiet.e2e-spec.ts` "DS-10 contract").

### Realtime channels (Supabase private Broadcast)
| Channel | Content | Presence |
|---|---|---|
| `room:{room_id}` | IDs only: `gesture_sent`, `reflection_published`, `reflection_removed`, `room_state` (incl. lantern level and intention hold count, room totals only), `wind_down`. Text is fetched through NestJS | `{member_id, pseudonym, silhouette_id, mood}` (≤ 24) |
| `game:{session_id}` | Breath Ripples: `session_start`, `breath_state`, `pulse`, `gesture`, `heartbeat`, `seat_update`, `session_end` | human seat holders |
| `ripples:{room_id}` | Breathe-together invites in a room | none |
| `quiet:{session_id}` | server → client: `t0`, soundscape seed, gesture types (never the sender), live count every 30 s | **none** (no member list ever) |

**Event-light rule:** clients send state changes (inhale/exhale transitions, pulses, gestures) with timestamps and
interpolate locally. 10 events/s is a burst ceiling, not a send rate. Rooms broadcast IDs only.

### Local ports (chosen to avoid other local projects)
Supabase API **55521** · DB **55522** · Studio **55523** · Inbucket **55524** · Analytics **55527** · Pooler
**55529** · Shadow **55520** · Redis **6391** · NestJS API **3310** · Worker health **3311** · Admin **3320**.

### Build configuration (dart-defines, `--dart-define-from-file`)
`AURA_API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` / publishable key, social sign-in toggles and Google web/iOS
client ids, `AURA_APPLE_SIGNIN`, `AURA_BETA_LOCALES` (shows hi / hi-Latn), debug tools (never in release),
`AURA_PRIVACY_URL`, `AURA_TERMS_URL`, `AURA_SUPPORT_EMAIL`, `AURA_GRIEVANCE_NAME`, `AURA_GRIEVANCE_EMAIL`,
`AURA_APP_STORE_ID`. Public values live in `apps/mobile/config/public.json`, production in `config/prod.json`. The
auth redirect is `aura://auth-callback`.

---

## 7. Mood catalogue, tags and habits

Source: `contracts/moods.json` (Telugu/Hindi names are drafts pending native review). The UI must never fork these.

### Quadrants
| Quadrant | Energy | Pleasant | Room theme | Hue | Glyph | UI colour (fg / ground) |
|---|---|---|---|---|---|---|
| **Storm** | high | no | Lighthouse | 275° violet | lighthouse | `#AE93FA` / `#221A43` |
| **Rain** | low | no | Rain Sanctuary | 175° teal | raindrop | `#5ACBBE` / `#0E2A2B` |
| **Moonlight** | low | yes | Midnight Observatory | 210° silver-blue | moon | `#AFC3F0` / `#161F3A` |
| **Sunrise** | high | yes | Sunrise Deck | 45° gold | sun | `#F3BE67` / `#2E2213` |

### The 16 moods (fixed 4×4 grid, never reorders)
| Storm | Rain | Moonlight | Sunrise |
|---|---|---|---|
| Overwhelmed | Melancholy | Calm | Joyful |
| Anxious | Drained | Content | Excited |
| Restless | Lonely | Quietly Hopeful | Proud |
| Frustrated | Numb | Grateful | Energised |

Each mood has names in `en`, `te`, `te-Latn`, `hi`, `hi-Latn`. Screen readers read name + group, e.g. "Anxious, Storm
group, high energy, unpleasant". Quadrants are never encoded by colour alone (name + glyph + fixed position).

### Context tags (10 defaults, + ≤ 10 custom, ≤ 20 chars)
study · work · family · friends · sleep · health · money · love · alone · commute

### Preset habits (6 defaults, + ≤ 3 custom, ≤ 30 chars, crisis-scanned)
Hydrate · Sleep on time · Move · Breathe · Journal · Go outside. Binary, self-reported, per Aura day. The user picks
which show. No "missed" state, red or cross.

---

## 8. Progression rules

Normative text: `contracts/rules/RULES.md`. Vectors in `contracts/rules/vectors/*.json` run in **both** the Dart
(`packages/aura_domain`) and TypeScript (`server/aura-api/src/rules`) test suites, so they cannot drift. Every rule
change starts in the contract (spec + vectors), then Dart, then TS.

| § | Rule | Vector file |
|---|---|---|
| 1 | **Aura day**: local day with 04:00 rollover in the IANA zone. A 03:59 check-in counts for the previous day | `aura_day.json` |
| 2 | **Credit eligibility**: no Starlight/streak credit for records > 10 min in the future, > 30 days old on receipt, or an impossible burst; a `local_day` credited once; backfills earn nothing | `eligibility.json` |
| 3 | **Starlight per Aura day**: first check-in 10; each of the next 2 check-ins 2; each habit 5 once a day; **daily cap 60**. Plus never multiplies. (3 check-ins + 9 habits = 59) | `starlight.json` |
| 4 | **Stage**: Spark 0 → Ember 100 → Glow 400 → Radiance 1,200 → Constellation 3,000; then +1 constellation star per 500 Starlight (max 12). **Never regresses** | `stage.json` |
| 5 | **Traits**: Starlight rings (Breathe) and cosmic glow (Sleep) unlock at 5 / 20 / 50 lifetime completions, permanently | `traits.json` |
| 6 | **Hue**: blends the last 14 days of moods (Sunrise gold, Moonlight silver-blue, Rain teal, Storm violet). No data → hue holds. Only hue moves, sideways | `hue.json` |
| 7 | **Glow streak and rest days**: +1 rest day per 4 active days, bank max 3 (counter pauses when full), 1 welcome rest day. Gap N ≤ bank → N spent, streak continues; N > bank → streak ends, **nothing spent**. Longest streak kept (shown only in Insights, hidden with "Hide streak number") | `streak.json` |
| 8 | **Resting Nebula**: entered at the 04:00 rollover ending the 2nd consecutive inactive day; next check-in or habit fires `wakeUp` | `nebula.json` |
| 9 | **Capsules**: date 1 week–5 years, 10:00 local; mood trigger arms 24 h after sealing; 7-day global cooldown after any trigger opens; oldest match first; crisis hold | `capsules.json` |
| 10 | **Insights thresholds** (patterns need ≥ 7 check-ins over ≥ 5 days; tag/habit patterns need the item on ≥ 3 days and ≥ 14 check-ins; care card at ≥ 80% Storm/Rain of ≥ 7 check-ins in 14 days); 10.1 Look back gates | `insights.json`, `look_back.json` |
| 11 | **Keepsakes and share milestones** | `keepsakes.json` |
| 12 | **Minimum app version** (forced update) | `app_version.json` |

**Clock and anti-farming rules.** A day skipped only by time-zone travel is not missed. Every mutation may carry the
`tz` the device used; backfill and eligibility are judged in that zone. If the server total is below the local
projection, the displayed stage stays; new Starlight fills the gap first.

### The avatar (`AuraAvatarState`, immutable)
| Field | Values |
|---|---|
| `stage` | spark · ember · glow · radiance · constellation |
| `hue` | 0–360° from the 14-day mood mix |
| `isResting` | Resting Nebula |
| `ringCount`, `glowLevel` | 0–3 |
| `constellationStars` | 0–12 |
| `equippedCosmetics` | visual only |

- **Art**: one AI-generated chibi celestial meditator (galaxy body, golden rim light, star on brow and heart, orbit
  rings) in `design/avatar/`; `manifest.json` records anchors and baked rings so new bases drop in without code.
- **Everything alive is code**: fragment-shader glow, nebula clouds, breathing float (±2%, ~6 s), glints, orbiting
  orbs, sparkles, constellation arc. Hue tint ≤ 25% so every quadrant stays beautiful.
- **Moments are events, not state**: `evolve`, `wakeUp`, `celebrate`, companion response; each plays once per id.
- **Quality tiers**: High (default, full particles, 2 shader passes, 60 fps) · Low (Android ≤ 3 GB RAM
  i.e. `totalMem ≤ 3.3×10⁹`, battery saver / Low Power Mode, or frames over budget for 2 s: ≤ ⅓ particles, 1 pass,
  30 fps idle) · Still (Reduce Motion, widget and share-card PNGs).
- **Fallback chain**: shader fails → painter-only; painter throws → bundled stage PNG. Never blank.

---
## 9. Features F1–F16 in detail

Every feature is the same for everyone 13+. For under-18 users the only differences are invisible (analytics
exclusion, stricter moderation thresholds, the Minors & grooming lane, Childline 1098 on the India sheet).
All features below are **Built** unless marked otherwise.

### Feature map
| ID | Feature | Pri · Milestone | App folder | Server module |
|---|---|---|---|---|
| F1 | Mood check-in | P0 · A | `checkin`, `voice`, `history` | `sync` |
| F2 | Habit-responsive avatar + habits + companion response | P0 · A | `avatar`, `habits`, `companion`, `progress` | `progression`, `rules` |
| F3 | Gentle streaks and rest days | P0 · A | `progress`, `home` | `rules`, `progression` |
| F4 | Personal time capsules | P0 · A | `capsules` | `capsules`, `media`, `keys` |
| F5 | Mood rooms (+ lanterns, Tonight's intention at B; wind-down at C) | P0 · A | `rooms` | `rooms`, `intentions`, `safety` |
| F6 | Reflections | P0 · B | `reflections` | `reflections` |
| F7 | Breath Ripples | P0 · B | `ripples` | `ripples` |
| F8 | Accounts and age gate | P0 · A | `onboarding`, `auth`, `account` | `profile`, `auth`, `account` |
| F9 | Safety, moderation, crisis routing | P0 · A | `safety`, `support`, `rooms/report_sheet` | `safety`, `reflections`, `admin`, `remote-config` |
| F10 | Insights ("Aura Sky") + weekly card + month in stars + Look back | P1 · B (Look back C) | `insights`, `history` | none (on device) |
| F11 | Home-screen widget | P1 · C | `widget` + native iOS/Android | `sync` |
| F12 | Monetization (Plus, cosmetics, gifts) | P1 · B | `plus`, `core/entitlements` | `billing` |
| F13 | Share cards and keepsakes | P1 · C | `share`, `keepsakes` | `keepsakes` |
| F14 | Notifications | P0/P1 · A/B | `push` | `notifications` |
| F15 | Sanctuary (Breathe, grounding, Today's minute; Sounds at B) | P0 · A / P1 · B | `sanctuary`, `sanctuary/sounds` | `sanctuary`, `sync` |
| F16 | Quiet Together + Lantern Hour wind-down | P1 · C | `quiet`, `rooms/wind_down_*` | `quiet`, `rooms/wind-down` |

### F1 Mood check-in
- **Tap 1 = mood** from the fixed 4×4 grid (glyph + label, grouped by quadrant). **Tap 2 = Save.** Median < 5 s.
- Optional details: tags (10 defaults + ≤ 10 custom), private note ≤ 500 chars, voice note ≤ 60 s.
- **Guided prompts** rotate as hint text in the empty note field ("What's one small thing that helped today?"),
  "Another" rotates, typing hides. Never saved, never counted, switch off in Settings. No prompt asks "why" or about
  self-harm.
- **Local-first**: written to encrypted Drift and confirmed before any network call (< 300 ms offline); Starlight,
  streaks, nebula wake and capsule triggers evaluate on the device; outbox syncs ≤ 60 s after reconnect.
- **Notes are crisis-checked on the device** (lexicon in the shipped languages). Voice notes are not scanned in v1.
- **Unlimited check-ins**; only Starlight is capped. Edit within 24 h, delete anytime; deleting never removes
  Starlight or glow days.
- **Backfill** up to 7 days back, from History: earns nothing, no streak effect, fires no capsule, auto-completes
  nothing, gets no companion response, minute card or room offer ("Added to your sky"). 8 days back →
  `backfill_too_old`.
- Edge cases: double-tap Save = one entry (idempotent id); app killed before Save = nothing saved; storage full →
  text saves, voice dropped with a notice.
- **Saved-moment order (REQ-CMP-06, tested for every combination):**
  1. the crisis sheet, if the note matched the lexicon;
  2. a mood-trigger capsule, if one fires (held on a crisis-flagged check-in);
  3. Starlight and the companion response;
  4. "A minute for you" (not after a crisis sheet) and "Join a room of people feeling this".
- Requirements: REQ-CHK-01..06.

### F2 Avatar, habits and the companion response
- **Habits** auto-complete: **Breathe** after ≥ 60 s of Sanctuary Breathe, the support sheet's 60 s grounding or a
  Breath Ripples session (≥ 6 cycles); **Journal** after a note ≥ 50 chars or sealing a capsule. Hidden habits are
  never auto-completed; backfills auto-complete nothing.
- **Companion response** after each saved **live** check-in (not backfill, not widget): a ≤ 2 s shimmer tinted with
  the check-in's quadrant, then one warm line from a localized pool.
  - Equal warmth: same duration, brightness and line length for all quadrants; ≥ 8 lines per quadrant per language;
    no repeat within the last 5.
  - Voice: second person, plain words. Never advice ("you should", "try to"), diagnosis, cheerleading ("cheer up"),
    digging questions ("why?") or promises ("it will be fine"). A copy lint enforces banned words.
  - Draft lines: Storm "That's a lot at once. Your light is still here." · Rain "Heavy evenings happen. You showed up
    for yourself anyway." · Moonlight "A quiet glow tonight. Stay as long as you like." · Sunrise "Bright one. Keep a
    little of this for later."
  - After a crisis sheet: a neutral line from a small pool, the same for every quadrant.
  - If the check-in also wakes the avatar or crosses a stage, that moment replaces the shimmer and its line is the
    only one. Plays once per check-in id; edits and syncs never replay it.
- **"A minute for you"**: one optional card after Save, same size and position for every quadrant.

| Quadrant | Offer | Activity |
|---|---|---|
| Storm | 30-second grounding ("Land") | Three slow breaths with the orb (Calm 4/6); "Keep going" opens Breathe |
| Rain | Gentle comfort ("Heart") | Hand-on-heart |
| Moonlight | Stillness | One quiet minute with the orb |
| Sunrise | Savour | Replay one good moment from today |

  Never starts on its own; one tap dismisses; earns nothing itself; base content only (never a paywall); offline.
- Requirements: REQ-AVA-01..07, REQ-CMP-01..07.

### F3 Gentle streaks and rest days
- Glow streak + lifetime glow days + rest-day bank (rules §7). Applying rest days is automatic, never prompted.
- During a gap: "Resting · your glow is safe" if the bank covers it, otherwise nothing. No countdowns.
- Streak end: "Your glow carries on" shows once, with the unchanged avatar, lifetime glow days and the new streak.
  No red, no old number, no "lost".
- **Never** streak-loss pushes; never rest days via money, Stardust, Plus or ads. "Hide streak number" in Comfort.
- Longest streak lives only in Insights (hidden too with "Hide streak number").
- Requirements: REQ-STK-01..05.

### F4 Personal time capsules
- **Contents**: title ≤ 60 chars (visible while sealed) + text ≤ 2,000 chars, voice ≤ 2 min (Plus 10 min) and/or ≤ 3
  photos (2,048 px, EXIF/GPS stripped). Guided prompt in the empty composer ("What do you want future you to remember
  about today?"), never saved.
- **Sealing**: a lexicon hit shows the support sheet; the capsule still seals, flagged `sealed_in_hard_moment`.
- **Date unlock**: 1 week to 5 years ahead, at 10:00 local; local notification scheduled at sealing + deduplicated
  server push backup.
- **Mood-trigger unlock**: target a mood or a quadrant; arms 24 h after sealing; fires on the next matching check-in;
  7-day global cooldown after any trigger opens; oldest match first.
- **Limits**: Free = 3 active trigger capsules, date capsules unlimited (fair-use 200). Plus = unlimited triggers and
  10-min voice. A downgrade deletes or locks nothing; it only blocks new triggers while ≥ 3 are active.
- **Sealed means sealed**: no early open, no edit; delete is allowed and never shows content.
- **Opening**: skippable ~4 s ceremony (static under Reduce Motion). Hard-moment capsules first show "You wrote this
  during a hard moment. Open when you're ready" with help. "Keep for next time" re-arms a trigger capsule.
- **Crisis collision**: a capsule that would fire on a crisis-flagged check-in is **held**; the support sheet shows
  first, then "A note from past you is waiting. Open now, or later?" Now = counts as the fire (cooldown starts);
  Later = stays armed, no cooldown.
- **Encryption**: content encrypted on the device (AES-256-GCM with the per-user data key from `GET /v1/keys/data-key`);
  the server stores ciphertext + unlock metadata only; moderators can never see capsule content.
- Sync entity `capsule` with actions `seal`, `open`, `fire`, `rearm`, `delete` (contract `v1-capsules.md`).
- Account deletion removes all capsules; the confirmation states how many sealed ones will be lost.
- Requirements: REQ-CAP-01..08.

### F5 Mood rooms
- **Entry**: every saved live check-in offers "Join a room of people feeling this". Active rooms sit in the Rooms tab
  and a Home "Your rooms" strip. No browsing of other rooms.
- **One active room per user per quadrant**; you return to it with the same pseudonym.
- **Size and life**: ≤ 24 members; 24 h from creation; no new members after 20 h; then read-only **memory** for 7 days;
  then purged. Reported items move to the evidence store (180 days).
- **Shows**: theme, silhouettes with mood-at-join chips, "5 here now", "18 people have been here today", gestures,
  reflections. Counts are real members, never echoes or staff.
- **Gestures (8 presets)**: Warm Tea · Light a Candle · Hug · Me Too · Soft Rain · Stargaze · Deep Breath · You're Not
  Alone. Aimed at a member, a reflection or the room. The recipient sees "Quiet Comet sent you Warm Tea"; others see
  an unnamed animation.
- **Lantern Hour 21:00–23:00** on the region clock: shared lantern event; matching concentrates people.
- **Leaving** frees the quadrant slot; no rejoining. Exit micro-survey "Did you feel less alone?" after ≥ 30 s, max
  once a day.
- **State machine**: `forming` (first member) → `open` (2nd member) ⇄ `lantern_hour` (21:00/23:00 region clock) →
  `closing` (age 20 h, no new members) → `memory` (24 h, read-only; report/block still work) → `purged` (24 h + 7 d).
- **Matching** (`POST /v1/rooms/match`, partition `language_pool × quadrant × tz_region`, tunable `matching_config`):
  0. return to the user's active room for this quadrant;
  1. exact mood match with ≥ 1 live (off at alpha);
  2. quadrant room with most live members;
  3. adjacent merge on the same pleasantness side (Storm↔Rain, Moonlight↔Sunrise), ≥ 3 live. **Never pleasant with
     unpleasant**;
  4. async: partition room with most 24 h activity, else a new room ("N people have been here today").
  New room spawns when nothing is joinable, or outside Lantern Hour when the best candidate has ≥ 12 live. Thin
  partition (< 12 joins in 24 h) merges into the busiest region; still thin → non-English pools merge into English.
- **Time-zone regions** (device UTC offset at join): `americas` ≤ −2:30 (America/Chicago clock) · `europe_africa`
  −2:00 to +3:00 (Europe/Berlin) · `south_asia` +3:30 to +6:30 incl. Gulf (Asia/Kolkata) · `east_asia_pacific` ≥ +7:00
  (Asia/Tokyo).
- **Language pools**: English · Telugu + Tenglish · Hindi + Hinglish (flag `rooms_pool_hi` off → those users join
  English, and can join a waitlist "Tell me when they open").
- **Guidelines before the first room** (server-recorded per version; match refuses with `409 guidelines_required`).
- **Limits**: 3 new room joins per quadrant per 24 h (re-entry free); gestures 1 per 2 s, 40 per room per hour, same
  gesture to same member ≤ 3 per 10 min. Over-limit drops silently; 3 limit hits in 24 h shadow-mute that account's
  gestures for 24 h.
- **Room lanterns (B)**: one shared 5-level lantern per open room during Lantern Hour. Human gestures within limits
  and room Breath Ripples cycles (0.25 each) add light, scaled to live members. **Additive only**, never dims or
  resets; at 23:00 the memory shows "Tonight's lantern". No individual counts, not even your own share.
- **Tonight's intention (B)**: one preset intention per room per Lantern Hour from a localized list ("Sleep before
  midnight", "Be gentle with myself tonight", "Phone down for 10 minutes"). One tap to hold; room sees "12 holding
  this tonight". No free text, no pairing, no named holders, no follow-up.
- **Wind down together (C)**: see F16.
- "May be under 13" reports from 2 distinct members pause that account's rooms and games pending review.
- **Never fake presence**: no bots, seeded members or inflated counts.
- Requirements: REQ-ROOM-01, 03–14.

### F6 Reflections
- **Composer**: ≤ 200 chars, emoji allowed. Max **3 per user per room per rolling 24 h** ("2 of 3 left today") and
  10 per account per day.
- **Not allowed**: links, @handles, emails, phone numbers (incl. +91, spacing, spelled-out digits in any script, Telugu
  ౦–౯ and Devanagari ०–९ digits), UPI IDs, contact-swap phrases ("insta id", "telegram pe aao", "number ivvu").
- **Published**: newest first, no ranking, no editing, author can delete, purged with the room.
- **Held**: only the author sees "Waiting for a quick check" (overnight "This may take until morning"); expires
  unpublished if the room becomes a memory first.
- **Rejected**: gentle copy by category; text returns to the composer. Only harassment, hate, sexual and spam are
  strikes.
- **Crisis-diverted**: never published; the support sheet opens at once; item enters the crisis lane; no strike.
- **Fail closed**: omni-moderation error or > 5 s → held; nothing released by timeout. **Offline: Send disabled,
  draft kept** (BD-7).
- **State machine**: drafted → on-device check (rejected / crisis_diverted / clean) → server moderation → published
  / held_for_review / rejected / crisis_diverted; held → published / rejected / expired; published → removed (report
  upheld) / deleted (author).
- **Pipeline** (server p95 ≤ 2 s): (1) on-device PII/link regex + crisis + contact-swap lexicon; (2) server repeats
  (1) + rate limits + sanctions + grooming phrase list (age, school, city, photos, other apps, secrecy, meeting up) in
  all five languages; (3) **OpenAI omni-moderation** (self-harm → crisis; sexual/minors or grooming → rejected to
  Minors & grooming; high → rejected; medium → held; else published); (4) human queue.
- **Stricter thresholds** when the author or any room member is under 18, and for Telugu, Tenglish and Hinglish.
- **Overnight (00:30–07:30 IST)**: clean text auto-publishes, holds wait; a sexual/minors or grooming hit shadow-mutes
  the author until review.
- Near-duplicates in > 2 rooms within 24 h held as spam. Auto-hide after 3 distinct reports, or 1 sexual/contact
  report when author or reporter is under 18.
- **Kill switch** per language pool (`reflections_composer` + `pausedPools`): "Reflections are resting for a bit.
  Gestures still work." Also triggered at > 50 held.
- Text is sealed at rest (DS-1 envelope) and decrypted only by NestJS for review, never logged.
- Requirements: REQ-REF-01..08, REQ-SAFE-07, 13, 14.

### F7 Breath Ripples
- **Session**: 2–4 seats; 10 s settle-in, **16 cycles** of inhale 4 s / exhale 6 s, 10 s fade-out (3 min).
- **Input**: hold to inhale, release to exhale; "tap to switch" mode; haptic pacer; reduce-motion; accessible mode
  (auto-on with a screen reader: rising/falling haptic + tone).
- **Visuals**: night ocean, one light per seat; better group sync → wider ripples, more fish. **Minimum ripple and 3
  fish always.** No score, number, countdown, leaderboard, voice or text.
- **Contact**: one-tap haptic pulse and 3 gestures (Hug, Deep Breath, You're Not Alone).
- **Leaving is silent**: your light dims into an echo; others never see "left" or "failed".
- **End**: "Breathe again", "Back to room", "Done", optional "How do you feel now?". ≥ 6 cycles logs Breathe.
- **Entry**: "Breathe together" in a room (room pseudonym, invite shows to live members for 20 s) or quick-match from
  Home (fresh pseudonym).
- **Matching**: one global queue (no language or age split), blocked pairs excluded; clients poll
  `POST /v1/ripples/match` every 2 s; 4 humans → start; at 8 s with ≥ 2 humans → start with echo fill; at 20 s → start
  with whoever waits plus echoes. **Max wait 20 s**, no "no one found" screen.
- **Sync** is computed on the client only (group median reference, EMA smoothing) and never sent.
- **Echoes**: recorded at session end from each human with ≥ 12 cycles who hasn't opted out ("Let my breathing become
  an echo", on by default): pacer-relative offsets, pacer version, completion %, ISO week. No account, member, device
  or age data; separate `echo_library`; 90-day retention. Clearly labelled ("2 people and 2 echoes of people who
  breathed here before"). Guide lights while < 50 eligible echoes.
- Latency budget: p95 RTT ≤ 400 ms, tolerates 1.5 s one-way; hard cap 10 events/s/player (excess flagged).
- No gift, purchase or upsell anywhere in the game or lobby.
- Requirements: REQ-GAME-01, 03–09.

### F8 Accounts and age gate
- **Order**: Welcome → Privacy & boundaries → date of birth → (under 13: block) → language → sign in → first check-in.
  DOB comes first so Aura never receives an under-13's email.
- **Sign-in** (email scope only, no name, password, phone or profile): native **Sign in with Apple** (iOS, no full-name
  scope), native **Google Sign-In** (ID token into Supabase `signInWithIdToken` with nonce), **email 6-digit code or
  magic link** (same email carries both). Provider name/picture claims are stripped (migration
  `…011_strip_oauth_profile`).
- **Neutral DOB**: empty day/month/year pickers, no default year, no copy mentioning 13 or 18. Full date stored,
  locked after onboarding (`409 birth_date_locked`); age check uses the user's own local date.
- **Under-13 block**: kind screen with region help (India: Childline 1098, 112; elsewhere "talk to an adult you
  trust"); no account, email or device id created; **30-day device lock** (iOS Keychain; Android Block Store mirror,
  device-only). No server fingerprinting.
- **Platform age signals** (Apple Declared Age Range iOS 26+, Play Age Signals) are read with ≤ 1 s wait and only ever
  block under-13s; an under-18 signal with an adult DOB turns on invisible protections only.
- **`is_minor`** (from DOB) never changes what anyone sees or does; clears at 18.
- **Deletion**: in-app, ≤ 3 taps from Settings; warns that store subscriptions continue; deactivated at once;
  restorable by signing in within 7 days ("Keep my account?"); hard-deleted after (hourly purge job) incl. storage;
  Apple token revoked. Also a web page `aura-akvega.web.app/delete-account/`.
- **Data export** (REQ-ACC-12): made **on the phone** (HTML + JSON + check-in CSV) and handed to the share sheet;
  `GET /v1/account/export` adds server-held records (profile incl. DOB, purchases, subscriptions, Plus, Stardust,
  cosmetics, gifts without counterparts, keepsakes, Sanctuary records, consents, guidelines, notification settings,
  own reflections). Voice/photos listed, not attached; sealed capsules stay sealed; the screen warns the files are not
  encrypted. Works in the grace period and on a closed account.
- **Account closed** (ban): a calm full-screen "This account is closed" page (no reason), Grievance Officer and
  support contacts, in-app review form, delete, sign out, and "I need help now". Nothing is lost on the phone until
  sign-out or delete.
- **Publisher**: AKVega. Storefronts worldwide except EU/UK/AU until the legal checklist is done.
- Requirements: REQ-ACC-01..04, 10..15.

### F9 Safety, moderation and crisis routing
Covered in full in section 12. Key points: "I need help now" everywhere opens the **Safety Center** route; the
**support sheet** is for contextual interception; on-device crisis lexicon in five languages; OpenAI omni-moderation
for reflections; four moderation lanes with SLAs; strikes; zero tolerance and mandatory reporting for minors'
sexual content and grooming; Grievance Officer with an in-app ticket form. Requirements: REQ-SAFE-01..16.

### F10 Insights ("Aura Sky")
- **Sky calendar**: each day is a star in its most frequent quadrant's colour and icon (split star for mixed days,
  faint ring for rest days). Inactive days are plain dark sky, never grey or crossed out. Month and year views; tap a
  day for a day sheet with its entries.
- **Patterns** (quadrant mix, time of day, tag × quadrant, habit × quadrant) computed **on the device and never
  uploaded**. Under 7 check-ins: calendar only + "Patterns appear after 7 check-ins (4/7)". Weak patterns are hidden,
  not caveated.
- **Copy**: descriptive only ("more often", never "because"); no scores, labels or diagnoses (copy lint).
- **Care card**: ≥ 80% of ≥ 7 check-ins in 14 days are Storm/Rain → "It's been a heavy couple of weeks" with the
  support sheet and a room. Never pushed.
- **Weekly insight card** (B): from Monday 04:00, all week, one passing pattern in words only, no numbers. No pattern →
  no card.
- **Your month in stars** (B): on the first Aura day of the month, a recap of last month (skipped if no check-ins).
  Free: days checked in, lifetime glow days, quadrant mix as a sky. Plus: deeper review.
- **Look back** (C): pull-only view of the same week 1 month, 6 months and 1 year ago. Hidden for 3 h after a Storm or
  Rain check-in and 24 h after a crisis sheet (device-only check); crisis-flagged entries never shown (lexicon re-run
  on display); notes and voice open only on a further tap; never pushed, never on Home, widget or notifications;
  shown only while its safety gate allows (`lookBackAvailableProvider`).
- **Lifetime** block incl. longest glow streak (hidden with "Hide streak number").
- **Free vs Plus**: free = full calendar, 30-day patterns, lifetime stats, weekly card, basic month, Look back, CSV
  export. Plus = any range, habit × mood, deeper monthly review. Calendar and history are never gated.
- History (the full check-in list with 24 h edit and delete) lives inside the Insights tab at `/insights/history`.
- Requirements: REQ-INS-01..08.

### F11 Home-screen widget
- **iOS** (WidgetKit + App Intents): medium on iOS 17+ is interactive (tap a quadrant, then one of its 4 moods →
  "Saved · +10 Starlight") without opening the app; small shows the avatar and deep-links `aura://checkin`. Below iOS
  17 both deep-link.
- **Android** (Jetpack Glance): 4×2 does the same two taps via `ActionCallback`; 2×2 deep-links.
- **Data path**: widget writes a mood-only record (client id + day stamp) to a shared store (App Group / app-private
  storage); the app imports it into Drift on next launch or background refresh, then syncs exactly once. Widget
  Starlight is provisional until import.
- **Shows**: a still PNG of the avatar, "How are you feeling?", today done or not, "Need help" on larger sizes.
  Capsules never open here.
- **Privacy**: lock screen / StandBy / Always-On never show mood names, colours or history. "Show my last mood" off by
  default. **Discreet widget** (plain star, no wordmark, no mood words), off by default.
- Signed out → "Open Aura to continue", input disabled. Refresh after each check-in, at 04:00 and on nebula change.
- Requirements: REQ-WID-01..04.

### F12 Monetization
Covered in section 23. **Switched off for v1.0** by `plus_enabled`. Requirements: REQ-PAY-01..11.

### F13 Share cards and keepsakes
- **Card types**: Evolution (Ember → Constellation), Glow milestone (7 / 30 / 100 / 365 lifetime days), Capsule
  anniversary, Keepsake.
- **Rendered on the device**: `RepaintBoundary` → 1080×1920 PNG (720×1280 on low memory), Still-tier avatar, < 1 s,
  offline. Shared only through the OS share sheet (`share_plus`); no photo-library permission, no social SDKs.
- **Shows only** avatar (stage, rings, glow, cosmetics), milestone line, wordmark, store link. **Never** moods,
  quadrants, tags, notes, capsule text, dates, streak count, pseudonyms or ids. Uses a fixed template palette, not the
  mood hue. Share links carry a random token not derived from the user id; under-18 shares use a plain link, no token.
- **Prompt** offered once per milestone; several at once → one prompt for the highest. No reward for sharing.
- **Keepsakes** (earned-only seals, awarded by NestJS from existing records): `capsule_sealed_first`,
  `capsule_opened_first`, `glow_days_7/30/100/365`, `ripples_first`, `lantern_hours_1/10/50`,
  `sanctuary_minutes_60/300/1000`. Private box (from Insights, Home and Settings › Account) shows only seals earned,
  with the day. No locked slots, progress bars or "next seal" hints. A new seal shows once as a small card on Home.
  Never sold, never lost, never visible to strangers.
- Requirements: REQ-SHR-01..06.

### F14 Notifications
Covered in section 13.

### F15 Sanctuary
- **Layout**: the avatar as a calm orb, "Today's minute", Breathe, Grounding, Sounds, and the capsules entry ("Future
  you"). "I need help now" in the header.
- **Offline and content-free**: a finished activity writes one content-free `sanctuary_session` record (activity,
  variant, duration, Aura day) via sync push. Nothing typed, said or picked inside an activity is stored.
- **Activities** (enum ids): `breathe` (choose rhythm and length), `calmMinute`, `boxMinute`, `fourSevenEight`, `land`
  (Storm's minute), `stillness` (Moonlight), `heart` (Rain), `senses` (5-4-3-2-1), `gratitude`, `savour` (Sunrise).
- **Breathe**: avatar-orb pacer; patterns **Calm 4/6** (default), **Box 4-4-4-4**, **4-7-8** (4 cycles ≈ 76 s, "Stop any
  time if you feel light-headed"); length 1 / 3 / 5 min; haptics per phase (obey Comfort + system); Reduce Motion = orb
  still, words + haptics; no score or counts; end screen "That was a few minutes for you" + Again / Done. ≥ 60 s
  (pauses excluded) completes Breathe once per Aura day.
- **One pacer engine** (pattern + start time → phase at any moment) drives Breathe, "A minute for you", the wind-down
  cues and Breath Ripples.
- **Grounding library**: 5-4-3-2-1, hand-on-heart, gratitude, stillness, savour. Prompts only, no text fields,
  self-paced "Next".
- **Today's minute**: one suggestion per Aura day, the same all day, one tap to start, no "missed" state.
- **Sounds (B)**: base stems **free**: rain, ocean, wind, night insects, singing bowl, chimes, brown noise; up to 4
  layers with per-stem volume; favourite mixes saved on the device; timer 15 / 30 / 60 min or off (30 s fade out);
  **night wind-down** (~20 min procedural sequence thinning to silence, reshuffled each Aura day, no narration).
  Silent until tapped (fade-in ≥ 2 s). Background playback with lock-screen controls reading only "Aura · Sounds".
  Headphones disconnect or a call pauses (never moves to the speaker). Base stems download once (~8 MB, size shown
  first); brown noise is synthesized; "Remove downloaded sounds" on the Sounds screen. No microphone. Plus stems show the
  explainer on tap (only "Part of Aura Plus" within 3 h of a Storm/Rain check-in or in a crisis flow).
- **Status**: recorded base stems are `pending_sourcing` (licence log `docs/sounds/licence-log.md`); procedural
  stand-ins (`fallback_generator`) play today, so Sounds work offline on a fresh install.
- Requirements: REQ-SAN-01..13.

### F16 Quiet Together and the Lantern Hour wind-down
- **Modes**: Study, Read, Rest. Entry from the Rooms tab.
- **60-min blocks** on the hour of the region clock; join or leave at any minute; you roll into the next block.
- **Counts only**: "12 here" and nothing else. No silhouettes, pseudonyms, moods, join/leave messages. Honest count of
  1: "Just you right now. Others drop in through the hour."
- **Gestures only**, to the whole session, shown as unnamed animations ("someone lit a candle"). No text input
  anywhere. Limits 1 per 10 s, 20 per session hour; flooding shadow-mutes gestures 24 h.
- **Shared soundscape played locally** from each phone's cache, lined up to the server `t0` (±1 s between phones).
  Silent until "Play the shared sound"; base stems only; no user audio, no streaming, no microphone.
- **Optional 25/5 focus rhythm** (Study, off by default): focus :00–:25, break :25–:30, focus :30–:55, break
  :55–:00; soft chime + haptic + visual; next change shown as a clock time ("Break at 9:25"), never a countdown.
- **Leaving costs nothing**; nothing is earned for staying.
- **Online only** ("Quiet Together needs a connection. Sanctuary works offline."). No push invites.
- Partition `mode × tz_region`, ≤ 50 per session, blocked pairs never placed together; no per-member Presence.
- Report: session menu "Report a problem here" (routes like a room report). "Hide gestures" for yourself.
- **Lantern Hour wind-down**: at 22:30 on the region clock, open rooms offer "Wind down together": one ambient track
  of base stems from a common `t0`, the pacer (Calm 4/6) and preset text cues ("Let the day get quieter"), ~20 min;
  room sees only "N winding down". Kill switches per region.
- Requirements: REQ-QUIET-01..07.

---

## 10. Navigation and every screen

### App shell (after onboarding)
`Home · Sanctuary · [Check-in] · Rooms · Insights`
- Four peer tabs (`StatefulShellRoute.indexedStack`, one navigation stack and scroll position per tab) plus a
  visually distinct **central Check-in action** that opens the full-screen check-in above the shell. It pulses for a
  new user.
- Settings opens from the top bar (right side on every tab); it is not a sixth tab.
- **"I need help now"** sits in the top bar of every primary screen, within the first 3 focus stops. It opens
  `/safety` in every state (signed out, onboarding, under-13 screen, forced update). Above 130% text it becomes a
  heart-only round button with the label in its tooltip.
- Check-in, Safety Center, Settings, History detail, rooms and Plus routes sit above the shell.
- Transitions: soft fade with a slight rise (380 ms); under Reduce Motion a plain crossfade ≤ 300 ms.

### Route table (`apps/mobile/lib/src/core/router/routes.dart`)
| Route | Screen | Notes |
|---|---|---|
| `/` | (gate) | resolves through `gateRedirect` |
| `/welcome` | Welcome | first launch |
| `/onboarding/trust` | Privacy & boundaries | |
| `/onboarding/dob` | Date of birth | |
| `/blocked` | Not eligible (under-13) | 30-day device lock |
| `/onboarding/language` | Language | |
| `/onboarding/sign-in` | Sign in | email code / magic link, Apple, Google |
| `/home` | Home (tab 1) | |
| `/sanctuary` | Sanctuary (tab 2) | activities open as pushed screens |
| `/checkin` | Check-in (central action) | `first: true` during onboarding |
| `/rooms` | Rooms home (tab 3) | |
| `/rooms/join` | Room join / matching | quadrant + mood passed as route `extra`, never in the URL |
| `/rooms/:id` | Mood room | |
| `/insights` | Insights / Aura Sky (tab 4) | |
| `/insights/history` | History list | `/history` redirects here |
| `/insights/month` | Your month in stars | |
| `/history/:id` | Check-in detail | 24 h edit, delete, voice playback |
| keepsakes route | Keepsakes box | from Insights, Home card, Settings › Account |
| `/safety` | Safety Center | opens in every state |
| `/settings` | Settings | |
| `/settings/delete-account` | Delete account | |
| `/settings/export` | Download a copy of my data | |
| plus route (`?from=<surface>`) | Aura Plus paywall | redirects Home while `plus_enabled` is off |
| plus skies route | Sky themes | redirects Home while `plus_enabled` is off |
| `/sign-in` | Standalone sign-in | from Settings when signed out |
| `/update-required` | Please update Aura | every route redirects here below the minimum version, except `/safety` |
| `/debug/avatar` | Avatar lab | debug builds only |

**Redirect order**: Safety Center always opens → under-13 lock wins → forced update → onboarding steps in order →
after onboarding, onboarding routes bounce to Home.

**Deep links** (`aura://`): `aura://checkin`, `aura://safety`, `aura://sanctuary`, `aura://rooms`
(notifications, widgets, shortcuts). Check-in and Safety open above the current screen; a tab link never replaces a
screen that may hold unsaved input. `aura://auth-callback` belongs to Supabase (magic link). Universal / App Links
wait on a domain.

### Screen inventory
Screen captures (138, iPhone 15 size, English + Telugu + Hindi + 200% text) are in `docs/design/screens/` with an
`INDEX.md`; regenerate with `cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture`.

#### Onboarding (010–018)
| Screen | Purpose and content | Key states |
|---|---|---|
| **Welcome** | Calm promise, cosmic hero, "Begin", global help | fresh / returning, large text, offline |
| **Privacy & boundaries** (trust) | Private by default, no diagnosis, not an emergency service, no DMs or open chat; policy links; SPDI consent text pending the lawyer | offline cached copy |
| **Date of birth** | Neutral day / month / year pickers (year picker with type-to-search), Continue disabled until all set | incomplete, boundary birthday, leap year, large text |
| **Blocked** (under-13) | Kind eligibility result, youth/emergency help by region, "Entered the wrong date?" route, no account capture | offline, region fallback |
| **Language** | Endonym list with script preview; beta labels for hi / hi-Latn (hidden unless `AURA_BETA_LOCALES`); in India pre-selects device language with a one-tap Tenglish/Hinglish option | immediate preview |
| **Sign in** | Apple + Google first, then "or", then email field with "Email me a code" under it; 6-digit code entry; magic link also works | code sent, wrong code, retry, provider unavailable, offline |
| **First check-in** | The check-in screen inside onboarding, with the notification rationale after save | |

#### Home (020–029)
- **Top bar**: "Aura" wordmark (dropped before the help pill would wrap), sync status icon, Settings, "I need help now".
- **"Keep my account?"** card first when a deletion is scheduled.
- **Crisis follow-up** card (in-app only, 12–72 h after a support sheet).
- **One "moment" slot** above the avatar, priority: capsule ready › new keepsake › milestone share prompt.
- **Avatar hero** (fitted so stats, glow card and habit rows sit above the nav bar on common phones), status line
  (new user, resting, welcome back, evolving).
- Today's progress / stats, today's check-in history line, glow streak card (rest days sheet on tap; hidden number
  with Comfort), **habits** section (chips; editor sheet to show/hide/add custom).
- **"Your rooms"** strip (rooms to return to).
- **Breathe together** quick-match card (Breath Ripples) under the fold.
- Quiet Plus / gift notices (trial ending, billing issue, gift received), hidden while Plus is off.
- Sheets: habits editor, rest days, sync status.
- States: fresh day, checked in, new user empty, scrolled end, 200% text, te / hi.

#### Check-in (030–043)
- **Mood grid**: 4 quadrants × 4 moods, equal tiles, glyph + label, stable order, sticky Save.
- **Details** (open below after a pick; auto-scroll brings "What's it about?" into view): tag chips (+ custom), note
  with rotating guided prompt, voice note (record up to 60 s, playback, record again, remove; mic rationale first
  time; "Voice is off" if denied).
- **Saved moment** (in-route state): crisis sheet → capsule card → Starlight + companion shimmer and line → "A minute
  for you" card + room offer ("Rooms open when you're back online" offline). Offline/saved-locally status.
- **Backfill** mode (from History "Add a past day"): mood grid for a chosen day within 7 days, then "Added to your
  sky".
- States: empty, selected, saving, saved offline, recoverable failure (selection and text preserved), support
  collision, max tags / note length, mic denied, storage full.

#### History and check-in detail (041–043)
- **History** (`/insights/history`): chronological private check-ins with discreet previews; "Add a past day".
- **Check-in detail** (`/history/:id`): mood, tags, note, voice playback, sync status; **Edit** within 24 h; **Delete**
  anytime (confirmation). States: editable / read-only, unsynced, delete pending, missing.

#### Sanctuary (050–063)
- **Hub**: avatar orb, Today's minute card, Breathe, Grounding list, Sounds entry, "Future you" (capsules).
- **Breathe setup**: rhythm chips (Calm 4/6, Box, 4-7-8) + length chips (1 / 3 / 5 min) → **Breathe running** (orb,
  phase words, pause, exit) → end ("That was a few minutes for you", Again / Done).
- **Grounding steps** (e.g. 5-4-3-2-1): full-width "Next", Back, no timer.
- **Sounds**: idle screen with the night wind-down card, stem mixer (up to 4 layers, per-stem volume), timer sheet,
  playing state, Plus stem locked note, wind-down active, download size notice, "Remove downloaded sounds".
- States: first visit, sound off, reduced motion, offline, paused, headphones disconnected, storage full.

#### Capsules (070–076)
- **Capsules list** (sealed capsules: title, unlock type, date or trigger; sealed ones never show content).
- **Capsule detail** (sealed: title + unlock info + delete; opened: content).
- **Composer**: title, text with guided prompt, voice (2 / 10 min), up to 3 photos (system picker, EXIF stripped),
  unlock choice: **date** (picker 1 week–5 years) or **mood trigger** (mood or quadrant). Limit screen at the 4th
  trigger (Plus explainer + "make it a date capsule"; plain note while Plus is off).
- **Opening ceremony** (~4 s, skippable, static under Reduce Motion) → opened view; hard-moment gate; "Keep for next
  time".
- **Capsule ready** card on Home.

#### Rooms (080–098)
- **Rooms home**: your active rooms, how rooms work, next Lantern Hour, **Quiet Together** card (modes), paused state
  ("Rooms are resting for a bit"), Hindi pool choice / waitlist.
- **Join**: community guidelines (first time and on a new version) → matching.
- **Mood room**: header (theme, "N here now · M today", help, room menu), Lantern Hour banner + **room lantern** +
  **Tonight's intention** card, member silhouettes with mood chips, reflections list, pinned **gesture tray**
  ("Send warmth" button above 130% text), reflection composer (≤ 200, "2 of 3 left today", held/rejected states),
  exit survey on leave.
- **Member sheet** (tap a silhouette): gestures grid, mute, block, report, gift (Plus on).
- **Report sheet**: 9 reasons (one tap, optional note). Reason 1 shows helplines.
- **Gift sheet** (Plus on): Warm Tea / Comfort Lantern / Encouragement Bouquet.
- **Memory** view (read-only, "Tonight's lantern", report/block still work).
- **Wind down together** card → wind-down session (track, pacer, text cues, gestures, "N winding down").
- States: offline, empty, joining, live, reconnecting, closing, memory, reported / blocked.

#### Breath Ripples and Quiet Together (100–108)
- **Ripples lobby** ("Looking…", ≤ 20 s) → **session** (settle, ocean with lights, pulse and 3 gestures, help
  top-right, tap a light to report/block/mute) → **end** (Breathe again / Back to room / Done / "How do you feel now?").
- **Quiet session**: mode, count, block time, shared sound button, optional 25/5 rhythm with "Break at 9:25", gestures,
  hide gestures, report, reconnecting state.

#### Insights (110–122)
- **Aura Sky top**: weekly insight card, month-in-stars card, care card when relevant.
- **Sky calendar** (month / year) → **day sheet**.
- **Patterns** (free vs Plus depth), **Lifetime** (incl. longest streak), **Look back** entry, **Keepsakes** entry.
- **Month in stars** (free and Plus versions, Plus-locked section).
- **Look back** (1 month / 6 months / 1 year weeks).

#### Keepsakes and share (125–129)
Keepsakes box (earned seals only) · share previews: evolution, glow milestone, capsule anniversary, keepsake.

#### Plus (130–134; hidden while `plus_enabled` is off)
Paywall ("1 month free, then ₹49/month", trial end date, cancel steps, Restore, Terms; no countdowns) · Sky themes
(free / Plus / cosmetic, soundscape pairing, Stardust redemption).

#### Settings (140–148)
In order: **Language** (with the "New rooms will match you with …" pool notice) · **Comfort** (Reduce motion,
Haptics, Hide streak number; guided prompts switch) · **Account** (sign in / signed in as, keepsakes,
sign out with unsynced warning, "Download a copy of my data", "Delete my account") · **Notifications** (master
switch, per-type toggles, reminder time, quiet hours, discreet mode, habit nudges, wind-down, Lantern Hour) ·
**Widget** (show my last mood, discreet widget) · **Help & Safety** (disclaimer, moderation-corpus opt-out, Grievance
Officer contact, "Write to the Grievance Officer" form, contact support) · **Aura Plus** (hidden while off) · **About**
(version, legal links, avatar lab in debug).
- **Delete account**: what is deleted, sealed capsule count, 7-day grace, store subscriptions warning, online only →
  confirm dialog.
- **Data export** screen (warning that files are not encrypted).

#### Safety and system (150–155)
- **Safety Center** (`/safety`): immediate help, verified region helplines (tap to call), offline 60-second grounding,
  boundary copy and disclaimer. Focus lands on the helpline list.
- **Support sheet** ("I need help now" variant and crisis variant).
- **Update required** (forced update; Safety Center still reachable).
- **Device banned** (with the in-app review form).
- **Account closed** (see F8), **Grievance form** (category, email pre-filled, description, content location; shows
  ticket id, resolve-by date and the Grievance Appellate Committee route).

#### Sheets, dialogs and transient surfaces
DOB picker sheet · check-in details · saved moment · support sheet · notification rationale (before the OS prompt) ·
mic rationale · companion evolution / wake-up moment · ambient controls (Sounds mixer, timer) · gesture tray · room
info / member / report / block sheets · gift sheet · sign-out confirmation · delete / export confirmations · habits
editor · rest days · sync status · crisis follow-up card · capsule-ready card. Every sheet is scrollable,
keyboard-safe, dismissible without a gesture-only interaction, and returns focus to its invoker.

### Cross-screen state contract
| Area | Required states and language rule |
|---|---|
| App shell | startup, offline, reconnecting, sync pending, signed in / out; never block private local use on the network |
| Onboarding | resume exact step; policy-link failure; never collect an account identifier before eligibility |
| Check-in | preserve selection and text on failure; idempotent double-save; save before support; help never disables Save |
| Companion | new, active, resting, welcome back, evolved; never sick, dying, disappointed or reset |
| Sanctuary | silent until chosen; audio interrupted; headphones disconnected (pause); reduced motion; paused; completion acknowledged, not scored |
| Rooms | offline, empty, joining, live, reconnecting, closed; the only stranger text is F6 reflections; Quiet Together shows counts only |
| Insights | threshold-gated patterns, insufficient data, care card; observations descriptive, never causal |
| Settings / data | permission denied, export queued / failed / ready, pending sync; explain consequences before action |
| Safety | offline and region fallback are first-class; helplines never depend on IP / GPS; visible exit back to the prior task |

---

## 11. Key user flows

### 11.1 First run (onboarding)
1. Welcome → "Begin".
2. Privacy & boundaries → continue.
3. Date of birth (no default year). Under 13 → **Blocked** screen, 30-day device lock (Keychain / Block Store), no
   account, nothing sent. Platform age signal < 13 also blocks. Otherwise continue.
4. Language (en / te / te-Latn; hi / hi-Latn in beta builds). UI switches immediately; room pool follows.
5. Sign in: Apple (iOS) / Google (native ID token) / email → 6-digit code or magic link. `POST /v1/profile` stores
   DOB, locale, IANA time zone, country. Name/photo claims stripped.
6. First check-in (full check-in flow, no paywall anywhere in the first 24 h).
7. After save: notification rationale ("Want a gentle nudge each evening? One a day at most, and never about
   streaks.") with a time picker. "Not now" never fires the OS prompt (iOS provisional auth only), re-ask after 30 days.
8. Home.

### 11.2 Daily check-in and the saved moment
1. Tap the central Check-in (or widget / `aura://checkin` / reminder).
2. Tap a mood. Optionally add tags, note (guided prompt), voice.
3. Save → written to Drift + outbox in one transaction (< 300 ms), Starlight projected locally.
4. On-device lexicon on the note: hit → **support sheet first** (check-in already saved; nobody is notified).
5. Mood-trigger capsule check (armed, cooldown clear): fires → capsule card ("Open now / later"); on a crisis-flagged
   check-in it is held behind the sheet.
6. Starlight + companion shimmer + one line (or the evolve / wake-up moment instead).
7. "A minute for you" card (skipped after a crisis sheet) + "Join a room of people feeling this".
8. Outbox drains to `POST /v1/sync/push` (2 s after the write, on reconnect, foreground, background task); response
   returns per-item results and the authoritative avatar/streak snapshot, which the app adopts.

### 11.3 Joining a mood room
1. Room offer after a live check-in (or "Your rooms" strip / Rooms tab). Offline → "Rooms open when you're back online".
2. First time or new version: community guidelines → accept (`POST /v1/safety/guidelines/accept`).
3. `POST /v1/rooms/match` with quadrant and mood → ladder steps 0–4 → seat + fresh pseudonym + `member_id`.
4. Subscribe to `room:{id}` (Presence + Broadcast IDs); fetch detail and reflections through NestJS.
5. Send gestures (rate-limited), hold Tonight's intention, add lantern light in Lantern Hour, write reflections (B).
6. Heartbeat keeps "here now"; leave → frees the slot, exit survey after ≥ 30 s (once a day).
7. Room closes at 20 h, becomes memory at 24 h, purged at 24 h + 7 d.
Error codes the app handles: `profile_required`, `rooms_suspended`, `account_closed`, `guidelines_required`,
`language_pool_unavailable` (offer English / waitlist), `rooms_paused` (503).

### 11.4 Sending a reflection
1. Type ≤ 200 chars. Offline → Send disabled, draft kept.
2. On-device check: PII / link / handle → gentle rejection, nothing leaves the phone; crisis hit → support sheet,
   crisis-diverted, nothing published.
3. `POST /v1/rooms/:roomId/reflections` → server rules → OpenAI omni-moderation → published (broadcast
   `reflection_published`) / held ("Waiting for a quick check") / rejected (reason code to inbox) / crisis-diverted.
4. Others react only with gestures. Report / mute / block from the card's ⋯ menu.

### 11.5 Breath Ripples
1. "Breathe together" (room invite, 20 s to join) or Home quick-match.
2. Poll `POST /v1/ripples/match` every 2 s → start rules (4 humans / 8 s with ≥ 2 / 20 s max) with echo or guide fill.
3. Join `game:{session}`; server sends `session_start {t0, …}`; pacer runs locally from `t0`.
4. Hold/release sends `breath_state`; pulses and 3 gestures; sync computed locally.
5. Disconnect > 3 s → light follows pacer; > 10 s → dims into an echo (silently). Rejoin within 10 s restores.
6. End → complete (`/complete`), echo recorded if ≥ 12 cycles and not opted out; ≥ 6 cycles logs Breathe.

### 11.6 Capsule seal and open
1. Sanctuary › Future you › New capsule (or composer).
2. Write title + text (+ voice / photos) → choose date or mood trigger → Seal. Lexicon hit → support sheet, capsule
   still seals flagged.
3. Encrypted on the device with the data key; media uploaded to a signed URL (`POST /v1/media/upload-url`); sync entity
   `capsule` action `seal`.
4. Date capsule: local notification at 10:00 local + server push backup (BullMQ `capsule-unlock`) → "Something you
   sealed is ready to open." → ceremony → open (`open` action records real time).
5. Trigger capsule: armed after 24 h → matching live check-in → card (in-app only) → Open now (cooldown 7 days) or
   Later / "Keep for next time" (`rearm`).

### 11.7 Crisis and help
- **"I need help now"** anywhere → Safety Center (bundled data, no login, network, paywall or spinner; opens < 500 ms in
  airplane mode). Region from device settings, never IP/GPS: India Tele-MANAS 14416 / 1-800-891-4416 and 112 (+
  Childline 1098 for under-18s); US 988; elsewhere "call your local emergency number". 60-second grounding offline.
- **Contextual interception** (lexicon hit in a note, capsule, reflection; report reason 1) → support sheet over the
  current task, dismissible.
- Soft idioms ("mar gaye yaar") → soft "Help is here" card instead of the full sheet.
- Next open 12–72 h later: an in-app crisis follow-up card (never a push). Look back hidden for 24 h on that device.
- Nobody is contacted automatically, at any age.

### 11.8 Sign-out, deletion, closed account
- Sign out: warning if the outbox is not empty ("sign out anyway / stay"); wipes the phone (DB, keys, media).
- Delete: Settings › Account › Delete my account → explains scope + 7-day grace + subscriptions → `POST
  /v1/account/deletion` → wipe + sign out. Signing in during grace → "Keep my account?" (`DELETE
  /v1/account/deletion`) or "Let it go". After grace: hourly purge incl. storage, Apple token revoked.
- Closed account (ban): `accountClosed: true` or `403 account_closed` → closed page; export, delete, grievance
  review, help remain available.

### 11.9 Forced update
The server's minimum version (`app_version.json` rule, `GET /v1/config`) above this build → every route redirects to
`/update-required` except `/safety`. Lowering the minimum returns the app to the root gate.

### 11.10 Grievance / appeal
Settings › Help & Safety › "Write to the Grievance Officer" (or "Ask for a review in the app" on closed-account and
banned-device screens, category `moderation_appeal`) → `POST /v1/grievances` (`channel: in_app`) → ticket id,
resolve-by date, GAC appeal route. Failures keep every word typed. Nothing typed is stored on the phone.

### 11.11 Purchase (when Plus is switched on)
Limit screen or Settings → paywall → store sheet (`in_app_purchase`) → `POST /v1/billing/purchases` (NestJS verifies
with Apple / Google) → entitlement updated (webhooks keep it current) → Plus on within 5 s. Gifts: `POST
/v1/billing/gifts` pre-check **before** the store sheet (no block either way, sender unsanctioned, ≤ 5/day), then
purchase, then delivery ("Someone here sent you a Comfort Lantern"). Pending (UPI mandate / Ask to Buy): "You won't
be charged until it's approved". Failed: "No charge. Nothing was sent."

---
## 12. Safety, moderation and crisis routing

### App Review positioning
**Aura is** a private mood journal with optional, time-limited mood rooms where people who feel the same respond with
8 preset gestures and short pre-moderated reflections. **Aura is not** random or anonymous chat, messaging, dating,
therapy, a medical device or an emergency service. Listing copy says "mood rooms" and "silent support", never "chat",
"anonymous" or "talk to strangers". Expected rating 13+ (16+ in Australia).

### Stranger-surface rules (apply everywhere strangers meet)
- One mixed-age pool; no partition, queue or fallback uses age.
- DS-10 boundary: pseudonyms and random `member_id`s only; no account id, age, DOB or under-18 flag in any payload.
- Silhouettes show stage, mood hue and at most one standard cosmetic (never fingerprints).
- **Never present:** DMs, text replies, profiles, follower counts, public gesture tallies, photos, links, paid
  priority entry.

| Surface | "I need help now" | Report / Block / Mute | Gift |
|---|---|---|---|
| Room header | lifebuoy, every state incl. memory | room menu "Report a problem here" | — |
| Member sheet | — | all three | yes (Plus on) |
| Reflection card / composer | text link under the composer | all three from ⋯ | yes, from the gesture tray |
| Breath Ripples | top-right, whole session | tap a light | never |
| Quiet Together | whole session | session menu; no per-person block (nobody is shown); "Hide gestures" | never |

### Report reasons (wire values never change meaning)
1 in danger or self-harm (crisis lane; reporter sees helplines) · 2 harassment · 3 sexual content or advances · 4
hate · 5 contact or personal info · 6 spam or selling · 7 may be under 13 (minors lane) · 9 targeting a young person
(minors lane, whatever the ages on record) · 8 other (shown last). The item hides for the reporter at once; the
outcome goes to their in-app inbox.
- **Block** is account-level: content hidden both ways, the pair never matched again. The blocked person sees no
  change (gestures look sent but drop; a gift fails before any charge).
- **Mute** is per membership, for you only.

### Community guidelines (accepted before the first room, versioned)
Be kind; no hate (incl. caste, religion, gender, sexuality); no sexual content; no contact details, meeting up, or
asking anyone's age, school, city or photos; no selling; no encouraging self-harm (talking about how you feel is fine).

### Crisis detection layers
- **L0** the help button everywhere.
- **L1 on-device lexicon** on notes, reflections, capsule text and custom habits in English, Telugu, Tenglish (Hindi
  and Hinglish candidates drafted, not active), incl. romanised forms and transliteration drift; high-confidence
  phrase → full sheet; idiom → soft "Help is here" card; entries still save. Matching on NFC-normalized, lower-cased
  text with zero-width joiners stripped. Shipped as a **signed, versioned bundle** (`contracts/safety/
  crisis_lexicon.v1.json`, remote updates via `GET /v1/lexicon/crisis`).
- **L2 OpenAI omni-moderation** on reflections only. Private text (notes, capsules) is never sent anywhere.
- **L3 human** crisis lane.
- Crisis events are aggregate only (DS-7). Nobody is auto-contacted.

### Helplines (bundled, signed, refreshed on sync; never IP/GPS)
India: **Tele-MANAS 14416 / 1-800-891-4416**, **112**, Childline **1098** for under-18s · US: **988** · everywhere else:
"If you're in danger right now, please call your local emergency number". Country from store region, then SIM, then
locale. A wrong number is a P0 bug. Source `contracts/safety/helplines.v1.json`.

### Moderation lanes and SLAs
| Lane | Contents | SLA |
|---|---|---|
| **L0 Crisis** | self-harm-flagged reflections (auto-held, never published); "in danger" reports | < 15 min in India's Lantern Hour, < 1 h otherwise (staffed 8 am–11 pm IST) |
| **L1 Minors & grooming** | anything involving an under-18 account (by stored DOB), suspected under-13, grooming signals from anyone | sexual content or grooming involving a minor < 2 h, pages 24×7; other L1 < 4 h |
| **L2 Harassment** | hate, adult sexual content, threats, bullying, doxxing | < 24 h |
| **L3 Spam / other** | promotion, gesture flooding, appeals | < 24 h |

**Legal clocks (IT Rules 2021 as amended 20 Feb 2026):** grievance acknowledge 24 h / resolve 7 days; unlawful
content 36 h; nudity / CSAM / NCII 2 h; court / government order 3 h; removed-content records 180 days.

**24×7 paging** (console PWA Web Push within 60 s → voice call at 5 min → repeat every 5 min until acknowledged;
payload has no content): legal orders, 2 h grievances, L1 sexual/grooming, crisis items unacknowledged 5 min (BD-1).
Weekly test page. Before absences AK turns on **hold-all** (every new reflection waits) / reduced mode.

### Strikes and sanctions
1 = warning + removal · 2 = 24 h reflection mute · 3 = 7-day room suspension · 4 = permanent social ban (account only,
BD-2). Strikes expire after 90 clean days. Immediate ban for sexual content involving or aimed at minors, grooming,
credible threats, doxxing. **Self-harm expression is never a strike.** One appeal per action, resolved in 7 days.
Shadow-mute is available for trolls. Owner-only device bans (install id + Apple DeviceCheck / Play Integrity once keys
exist).

### Minors & grooming SOP
1. Instant ban of account and device in one action.
2. Evidence preserved 180 days in `evidence_holds` (overrides the purge).
3. Mandatory report (POCSO police / Special Juvenile Police Unit, National Cybercrime Reporting Portal; NCMEC for US).
   The ticket cannot close without a `report_ref` or an Owner-recorded legal reason.
4. No tipping off: the banned user sees only "This account was closed for breaking Aura's rules". Nobody contacts the
   minor's family.
5. Suspected under-13: account closed, data deleted (evidence excepted), device locked 30 days.

### Crisis escalation workflow
The moderator confirms the item is held, the sheet was shown and the next-day in-app check is queued; removes anything
harmful to others; records the outcome. **Never** counsels, contacts off-platform, identifies or locates the user,
promises follow-up, or contacts family. A credible threat to someone else or a lawful order goes to the Owner.

### De-identified moderation corpus (REQ-SAFE-16)
Final decisions become `text + language + label + ISO week` rows with no link to anyone, sealed under DS-1. Settings
opt-out (on by default per the privacy notice), `GET/PUT /v1/safety/corpus-consent`. Never included: under-18
authors, opted-out authors, crisis text, Minors & grooming items, contact details / links / personal questions,
held items until a human decides.

---

## 13. Notifications (F14)

Notifications offer a quiet minute; they never pull people back through guilt or pressure. **Nothing on a lock screen
may reveal how someone feels.**

### Catalogue
| Notification | Trigger | Channel | Cap |
|---|---|---|---|
| Daily check-in reminder | user-chosen time (suggested 8 pm); skipped if already checked in | push + widget glow | 1/day |
| Habit nudge (opt-in) | time per habit | push | 1/day, bundled |
| Date capsule unlocked | unlock date, 10:00 local | push + widget badge | 1/day |
| Mood-trigger capsule | next matching check-in | **in-app only** | 7-day cooldown |
| Gestures received | gestures sent to you | push (batched) + in-app | 1 push per room per day |
| Lantern Hour (opt-in) | region's 21:00 | push | 1/day; skipped if already in a room |
| Wind-down reminder (opt-in) | user time (suggested 10:30 pm) → Sanctuary wind-down | push | 1/day |
| Breath Ripples invite | "Breathe together" in your room | **in-room banner only** | 1 per session |
| Welcome back | 7 days inactive, again at 21 | push | 2 per absence, then silence |
| Aura Plus trial ending | 48 h before the free month ends | push + in-app + email | once per account, exempt from cap |
| Billing issue | store notification | **in-app banner only** | no push |
| Moderation outcome | held / rejected / strike | **in-app inbox only** | per event |
| Crisis follow-up | support sheet 12–72 h ago | **in-app card on next open only** | once per event |
| Rooms pool open | Hindi/Hinglish pool opens (waitlist) | push | once |

English examples: "A quiet minute for you. How's today feeling?" · "Something you sealed is ready to open." · "3 people
in your room sent you warmth." · "Lantern Hour is on. Others are here tonight." · "No catch-up needed. Aura is here
whenever you want a quiet minute."

### Global rules
1. **Quiet hours 11 pm–8 am** local by default, editable; a reminder deliberately scheduled inside them is honoured
   after a one-time confirmation (night-shift).
2. **Max 2 pushes per day**, all types. Precedence: capsule unlocked > daily reminder > gestures > Lantern Hour >
   wind-down > habit nudge > welcome back. Dropped items stay as in-app cards.
3. **Payloads carry no mood or content**: type + opaque id + generic copy. Never a mood, quadrant, room theme name
   ("Rain Sanctuary" reveals the quadrant), capsule or reflection text, pseudonym or habit history. Android
   `VISIBILITY_PRIVATE`; iOS hidden-preview placeholder.
4. **Discreet mode** ("Aura · You have a gentle update" for every push), off by default.
5. Permission asked in context after the first check-in, never at install; after a decline, no re-ask for 30 days;
   iOS provisional authorization only after "Not now".
6. **Smart timing**: reminder ignored 5 days in a row → every other day; 14 ignored → stop (welcome-back takes over);
   any check-in restores it.
7. Per-type toggles + master switch in Settings. Copy follows the app language, rendered server-side from the shared
   key catalogue.
8. Lock-screen media controls read only "Aura · Sounds".
9. Android channels: Reminders, Capsules, Rooms & Lantern Hour, Account, Sounds playback.

### Banned copy (a copy-lint test fails the build in all 5 languages)
Guilt ("You haven't checked in for 3 days"), loss or decay ("Your Aura is fading"), streak threats, "We miss you",
mood on lock screen ("Still feeling anxious?"), social pressure or urgency ("Quiet Comet is waiting", "Only 2 hours
left!"), billing pressure ("Last chance!"). Banned words include miss, lose, streak, broken, fading, last chance,
hurry, and any mood, quadrant or room theme name.

### Trial-ending reminder rules (CCPA dark-patterns guidelines + store rules)
Facts only (end date, store's localized price, period); one tap opens the store's own subscription page; not sent if
auto-renew is already off (instead "Plus stays on until {date}. You won't be charged.").

---

## 14. Permissions

**Nothing at launch. Soft ask first. No permission gates a core flow. Re-ask at most once after ≥ 30 days. Same for
everyone.**

| Permission | When | If denied |
|---|---|---|
| Notifications | after the first check-in, with a time picker | Home reminder card; capsule badge on next open |
| Microphone | first tap on the mic (check-in, capsule composer) | "Voice is off" + Settings link; typing works |
| Photos | never a permission: system picker (PHPicker / Android Photo Picker) | n/a |
| Haptics | never (install-time on Android) | visual pulse / phase words |
| Background audio | capability, not a prompt; only while Sounds or a shared sound plays | n/a |
| Exact alarms | **not requested** (inexact scheduling, WorkManager) | n/a |
| Location | **not requested** (time zone from device settings) | n/a |
| App Tracking Transparency | **not requested**; `AD_ID` removed with `tools:node="remove"`; privacy manifest declares no tracking | n/a |

No microphone for Breath Ripples, Sanctuary or Quiet Together. EXIF and location stripped from photos. No in-app camera.

---

## 15. Offline mode and sync

**Rule: your own things work offline; anything involving other people or money needs a connection.**

| Works offline | Online only |
|---|---|
| Check-in incl. voice, widget check-in, habits, avatar and streak (provisional), capsule create/seal, date unlock, trigger firing, Insights, Look back, keepsakes box (cached), Sanctuary + companion + minute, Sounds after one download, Safety Center + support sheet, cached Plus features | Rooms, gestures, reflections, Breath Ripples, Quiet Together, wind-down, purchases, restore, gifts, sign-in, data export (server part), deletion, server push |

### Local store
- **Drift** on an encrypted SQLite (SQLCipher); DB key generated on first launch, kept in Keychain / Keystore
  (`…AfterFirstUnlockThisDeviceOnly`).
- Voice and photo files in the app's private directory, encrypted at rest with the per-user data key.
- DB and media **excluded from iCloud / Android Auto Backup**; the server is the restore path.
- Supabase session in secure storage (not SharedPreferences).

### Write and read paths
| What | Goes to |
|---|---|
| All outbox mutations (check-ins, habit logs + definitions, Sanctuary sessions, capsule actions, settings, notification prefs, room pool waitlist, tombstones) | **`POST /v1/sync/push`** (verifies the Supabase JWT; one transaction incl. ledger) |
| Voice and photo files (already encrypted) | Supabase Storage via short-lived signed URLs from NestJS |
| Purchases, restores, gifts | NestJS (never queued) |
| Sign-in and refresh | Supabase Auth |
| Pull of own data and the avatar / streak snapshot | Supabase PostgREST select-own + `GET /v1/me/snapshot` |

### Sync model
- **Outbox**: every mutation writes the domain row and an outbox row in one Drift transaction.
- **Idempotent ids**: UUIDv7 primary keys; NestJS upserts on id; ledger entries keyed by source record id.
- **Push**: oldest-first in batches of 50 on reconnect, foreground, 2 s after a write, and via WorkManager /
  BGTaskScheduler. Per-item results + the new snapshot come back.
- **Pull**: per-entity **delta since a server cursor** (`updated_at ≥ cursor − 5 min`, so boundary rows are re-read),
  after each push and on foreground. **Server tombstones** always win and drop that item's unsent mutations; a phone's
  own unsent change wins until sent. Tombstones kept 400 days; a phone idle longer re-reads everything.
- **Retry**: exponential back-off to 1 h; after 10 failures or on a 4xx validation rejection, the item moves to a
  dead-letter table (logged without content).
- **Timestamps**: `device_ts` + UTC offset, `local_day`, a monotonic stamp; the server adds `server_ts`.

### Conflict rules
| Entity | Rule |
|---|---|
| Check-ins | append-only; delete tombstone always wins |
| Habit logs | one row per habit per `local_day`; last-write-wins on `device_ts`, tie → `server_ts` |
| Habit definitions, settings | last-write-wins per field; tombstone wins |
| Avatar, streak, rest days | derived by NestJS from the ledger; client adopts the snapshot |
| Capsules | content immutable once sealed; unlock one-way; tombstone wins; trigger fires at most once (earliest `device_ts` wins) |
| Entitlements, Stardust | NestJS only |

Sign-out with a non-empty outbox shows a warning (unsynced items are lost on uninstall).

---

## 16. Data model and migrations

Postgres on Supabase (Mumbai). **RLS on every table.** Personal tables: select-own only, no client insert/update/delete.
NestJS uses the service role; the admin console uses a dedicated **`aura_admin`** role with no grants on private
tables. Client ids are UUIDv7.

### Tables by area (actual names from the migrations)
| Area | Tables (key points) |
|---|---|
| Identity and consent | `profiles` (`user_id`, full `birth_date`, generated `is_minor`, `ui_locale`, `language_pool`, `timezone`, `tz_region`, `country`, `deleted_at`; DOB locked; min-age backstop) · `user_consents` (per purpose: core processing, analytics, echoes, corpus) · `user_data_keys` (wrapped per-user data key + key id) · `apple_auth_tokens` · `account_deletions` · `minor_signals` · `guidelines_acceptances`. No server table for under-13 blocks (device lock only) |
| Personal | `moods`, `preset_habits` (catalogues) · `check_ins` (`id`, `mood_id`, `quadrant`, `tags[]`, `note_ct` envelope ciphertext, `voice_path`, `local_day`, `device_ts`, `server_ts`, `source` app/widget) · `habits`, `habit_logs` (unique habit + day) · `starlight_ledger` (append-only, NestJS only, daily caps) · `active_days` · `avatar_state`, `streak_state` (derived; incl. longest streak) · `capsules` + `capsule_unlock_schedule` · `sanctuary_sessions` (content-free) · `keepsakes` + `keepsake_tallies` · `sky_preferences` |
| Sync | `sync_mutations` (idempotency, purged daily) · `sync_tombstones` (400 days) |
| Rooms | `rooms` (quadrant, mood ids, language pool, tz region, theme, capacity 24, lifecycle timestamps, status, lantern level, Lantern Hour time, intention key, holds) · `room_members` (`member_id`, `pseudonym`, `mood_at_join`, joined / left / last seen; `user_id` never returned) · `room_gestures` · `room_mutes` · `room_survey_counts` (aggregate) · `room_pool_waitlist` · `room_intention_presets`, `room_intention_texts` · `matching_config` · `pseudonym_blocklist` · `blocks` |
| Reflections | `reflections` (sealed body, status pending / published / held / rejected / crisis_diverted / removed, mod scores, `involves_minor`, decided by / at) · `reflection_config` · `moderation_corpus` (de-identified) |
| Breath Ripples | `ripple_tickets` (queue) · `ripple_sessions` · `ripple_seats` (human / echo / guide) · `ripple_invites` · `ripple_session_log` (7 days) · `ripple_config` · `echo_library.recordings` (separate schema, no link to people) |
| Quiet Together | `quiet_sessions` · `quiet_members` (counts only to clients) · `quiet_gestures` · `quiet_config` |
| Trust & safety | `reports` (lane, SLA timestamps) · `strikes`, `sanctions` · `moderation_actions` (**append-only, hash-chained audit**; UPDATE/DELETE blocked for every role) + `moderation_audit_anchor` · `evidence_holds` (180 days, overrides the purge) · `safety_config` · `crisis_events` (aggregate, no user id; no writer yet) · `device_installs`, `device_bans` |
| Admin | `admin_staff` · `admin_grievances` · `admin_legal_orders` · `admin_mandatory_checklists` · `admin_deletion_cases` · `admin_pages`, `admin_page_deliveries` |
| Money | `billing_accounts` · `subscriptions` (store, product, original transaction / purchase token, state trial / active / grace / billing_retry / expired / refunded, trial end, expiry) · `purchases` · `entitlements` (NestJS-owned) · `store_notifications` (append-only, replayable) · `gifts` (≤ 5/day) · `stardust_ledger` · `user_cosmetics` · `trial_ending_emails` |
| Notifications and ops | `device_tokens` · `notification_prefs` · `notification_schedule` · `notification_activity` (smart timing) · `gesture_push_log` · `feature_flags` (+ `payload`, `updated_at` trigger) · `signed_bundle_versions`, `signed_bundle_current` (lexicon, helplines) |

### Migrations (`supabase/migrations`, each with a pgTAP test in `supabase/tests`)
| # | Migration | # | Migration |
|---|---|---|---|
| 01 | foundations | 19 | milestone_a_gaps |
| 02 | storage_private_media | 20 | billing |
| 03 | client_privilege_hardening | 21 | breath_ripples |
| 04 | catalogue | 22 | room_lanterns |
| 05 | review_fixes | 23 | sanctuary_sessions_notifications |
| 06 | min_age_local_date | 24 | security_review |
| 07 | account_deletion | 25 | gaps_b |
| 08 | voice_path_and_text_limits | 26 | keepsakes |
| 09 | capsules | 27 | quiet_together |
| 10 | rooms_safety | 28 | perf |
| 11 | strip_oauth_profile | 29 | console_followups |
| 12 | notifications | 30 | longest_streak |
| 13 | admin | 31 | moderation_corpus |
| 14 | account_followups | 32 | sync_tombstones |
| 15 | safety_reason_guidelines | 33 | reminder_smart_timing |
| 16 | admin_completion | 34 | pseudonym_blocklist |
| 17 | flags_lexicon_devices | 35 | plus_enabled |
| 18 | reflections | | |
File names are `20261005000NNN_<name>.sql`. pgTAP files include `00_schema_contract`, `01_rls_read_own`,
`02_client_writes_denied`, then one per migration.

---

## 17. API surface (NestJS `server/aura-api`)

Contracts live in `contracts/api/`: `v1.md` (foundations), `v1-rooms.md`, `v1-reflections.md`, `v1-ripples.md`,
`v1-quiet.md`, `v1-capsules.md`, `v1-billing.md`, `v1-notifications.md`, `v1-keepsakes.md`. All authenticated routes
verify the Supabase JWT. Errors are `{ "code", "message" }`. Guards: auth, account-closed (`403 account_closed`),
pending-deletion (`403 account_deletion_pending`), device ban, kill switch (`503 <feature>_paused`).

### Public (no JWT)
`GET /health` · `GET /v1/config` (flags, kill switches, min app version; ETag) · `GET /v1/lexicon/crisis` (signed) ·
helplines bundle · `GET /v1/intentions` · `POST /v1/grievances` · `GET /v1/grievances/officer` ·
`POST /v1/auth/review-sign-in` (review account only, 5 tries/hour) · `POST /v1/billing/webhooks/apple` ·
`POST /v1/billing/webhooks/google`.

### Profile, sync, keys, media, devices, account
- `POST /v1/profile` (DOB, locale, tz, country; DOB locked after onboarding) · `GET /v1/me/snapshot`
- `POST /v1/sync/push` (the only personal write path; entities incl. `check_in`, habit, habit log, `sanctuary_session`,
  `capsule`, settings, `notification_prefs`, `room_pool_waitlist`, tombstones; per-mutation `tz`)
- `GET /v1/keys/data-key` (per-user data key, DS-1)
- `POST /v1/media/upload-url` · `POST /v1/media/download-url` (own prefix only, 5-minute URLs)
- `PUT /v1/devices` · `DELETE /v1/devices` (FCM token)
- `GET /v1/account` · `POST /v1/account/deletion` · `DELETE /v1/account/deletion` · `POST /v1/account/apple-auth` ·
  `GET /v1/account/export`

### Rooms and safety
`POST /v1/rooms/match` · `GET /v1/rooms` · `GET /v1/rooms/:roomId` · `POST /v1/rooms/:roomId/heartbeat` ·
`POST /v1/rooms/:roomId/gestures` · `POST /v1/rooms/:roomId/leave` · `POST /v1/rooms/:roomId/survey` ·
`POST|DELETE /v1/rooms/:roomId/mutes[/:memberId]` · `POST /v1/rooms/:roomId/intention/hold` ·
`GET|POST|DELETE /v1/rooms/:roomId/wind-down` · `POST|GET /v1/safety/reports` · `POST|GET|DELETE /v1/safety/blocks` ·
`GET /v1/safety/me` · `POST /v1/safety/guidelines/accept` · `GET|PUT /v1/safety/corpus-consent`

### Reflections
`GET /v1/rooms/:roomId/reflections` (+ composer state) · `GET /v1/rooms/:roomId/reflections/:id` ·
`POST /v1/rooms/:roomId/reflections` · `DELETE /v1/rooms/:roomId/reflections/:id`

### Breath Ripples
`POST /v1/ripples/match` (join or poll) · `DELETE /v1/ripples/match/:ticketId` · `GET /v1/ripples/rooms/:roomId/invite` ·
`GET /v1/ripples/sessions/:id` · `POST …/leave` · `POST …/complete` · `POST …/reports` · `POST …/blocks` ·
`POST …/flood` · `GET|PUT /v1/ripples/echo-consent`

### Quiet Together
`POST /v1/quiet/join` · `POST /v1/quiet/sessions/:id/heartbeat` · `POST …/leave` · `POST …/gestures` · `POST …/reports`

### Billing (purchase routes answer `503 plus_disabled` while Plus is off)
`GET /v1/billing/entitlement` · `POST /v1/billing/purchases` · `POST /v1/billing/restore` · `PUT /v1/billing/sky` ·
`POST /v1/billing/stardust/redeem` · `POST /v1/billing/gifts` (pre-check) · `DELETE /v1/billing/gifts/:giftId` ·
`GET /v1/billing/gifts/received` · `POST /v1/billing/gifts/received/seen`

### Keepsakes
`GET /v1/keepsakes` (awards anything newly reached, then answers)

### Admin (`/admin/*`, AdminGuard, role-checked, every action audited)
Session / login / MFA · `GET /admin/queue`, `GET /admin/work`, `GET /admin/stats` · `GET /admin/reports/:id`,
`POST /admin/reports/:id/actions` · `GET /admin/sanctions`, `POST /admin/sanctions/:id/lift` · reflections review
(`GET /admin/reflections`, `GET /admin/reflections/:id`, `POST …/decision`, pool pause/resume) · `GET /admin/config`,
`POST /admin/config/flags/:key`, region pause/resume · lexicon versions (list, create, test, publish, rollback,
baseline) · helplines versions · intentions (presets, words) · pseudonym blocklist · device bans · grievances ·
legal orders · deletion cases · evidence (`POST /admin/evidence/:holdId/export`) · mandatory reports (checklist,
record) · paging (`GET /admin/pages`, ack, test, status) · audit (`GET /admin/audit`, exports, verify chain) · staff.

---

## 18. Remote config, flags and kill switches

`GET /v1/config` (public, ETag) returns flags from `public.feature_flags`. **A flag on the phone only hides UI; every
kill switch is enforced on its route** (`@KillSwitch`). A missing row counts as **on** for a kill switch and **off**
for everything else (except `plus_enabled`, where missing = off). Flips go through `POST /admin/config/flags/:key`
(Owner, reason code, audited) and reach clients within 5 minutes.

| Flag | Default | Effect when off |
|---|---|---|
| `rooms_enabled` | on | no new joins, "Rooms are resting for a bit" (`503 rooms_paused`) |
| `rooms_pool_hi` | **off** | Hindi + Hinglish rooms closed; offer English + waitlist (`409 language_pool_unavailable`) |
| `reflections_composer` (+ `pausedPools`) | on | no new reflections in that pool (`503 reflections_paused`) |
| `ripples_enabled`, echoes | on | Breath Ripples / echo recording off |
| `gifts_enabled` | on | no new gifts (`503 gifts_paused`) |
| `plus_enabled` | **off** (v1.0 free) | no purchase surface anywhere (`503 plus_disabled`) |
| room lanterns, `room_intention_enabled` | on | feature hidden |
| `quiet_enabled` (+ `pausedRegions`), wind-down per region | on | join refused in that region |
| sign-ups, reduced mode, hold-all | configurable | throttling / hold every new reflection |

Also delivered: minimum app version per platform (forced update), signed lexicon and helpline bundles (Ed25519-style
signature with key id; the app verifies before use and falls back to the bundled copy), device-ban status.

---

## 19. Admin and moderation console (`apps/admin`)

- **Next.js** server-rendered app; holds **no database credentials**; talks only to NestJS `/admin` endpoints; each
  action runs one transaction under the `aura_admin` role and writes the audit row.
- **Sign-in**: Google SSO for listed accounts + enforced **TOTP** MFA; staff accounts separate from app accounts;
  sealed, purpose-bound cookies; `Origin: null` → 403; strict CSP.
- **Roles**: **Owner** (AK: everything incl. device bans, config, flags, lexicons, staff, deletion, grievances, legal
  orders, mandatory reports) · **Moderator** (queues, approve/reject, shadow-mute, strike, suspend ≤ 7 days, escalate;
  no device bans, config, email/DOB or export) · **Read-only analyst** (aggregates only).
- **Never shows**: check-ins, notes, voice, habits, Insights, capsules, DOB, email or phone. Enforced by DB grants
  (tested), not just the UI. Shows an "Under 18" flag, never the DOB.
- **Item view**: the item, omni-moderation scores and matched lexicon terms, room context (quadrant, pool, region,
  room age, other reflections), reporter count and reasons, the author's pseudonym, hashed internal id, account age,
  strike history.
- **Screens** (`apps/admin/src/app/(console)/`): `now` (what needs attention) · `queue` · `reports` · `reflections` ·
  `sanctions` · `devices` · `grievances` · `legal-orders` · `mandatory` (mandatory reports) · `deletion-cases` ·
  `config` (flags, region pauses) · `lexicons` · `helplines` · `intentions` · `pseudonyms` · `paging` · `audit` ·
  `staff` · `stats`; plus `login`, `mfa`, `evidence/[holdId]`.
- Setup guide: `docs/setup/admin-console.md`.

---

## 20. Design system

Runtime source of truth: `apps/mobile/lib/src/core/theme/aura_tokens.dart` + `app_theme.dart`. Doc:
`docs/design-system.md`. **Dark-only Material 3 theme.** Never duplicate hex values in feature code.

### Colours
| Token | Value | Use |
|---|---|---|
| `skyDeep` | `#05060F` | lower background |
| `sky` | `#0A0C1D` | scaffold |
| `skyHigh` | `#10132A` | inputs, low containers, off-switch track |
| `surface` | `#151935` | cards |
| `surfaceHigh` | `#1D2245` | disabled controls |
| `outline` | `#2C3264` | decorative boundaries |
| `controlOutline` | `#6268A8` | idle control boundaries (≥ 3:1) |
| `hairline` | 12% white | separators |
| `text` / `textSoft` / `textMuted` | `#F2F0FF` / `#BDB9E0` / `#9591BD` | text levels |
| `starlight` | `#F7E6B5` | companion / progress light |
| `lavender` | `#C9BFFF` | focus, links |
| `accent` / `onAccent` | `#BBAAFF` / `#15112E` | primary action, selected chips |
| `lantern` / `onLantern` | `#F6C1A4` / `#2A1510` | **"I need help now", helplines only** |
| `danger` | `#FF8A80` | destructive actions only, never feelings |

Quadrant colours: see section 7. `lantern` is a warm beacon, never a "bad feeling" colour.

### Type, spacing, shape, motion
- System font for Latin; bundled **Noto Sans Telugu** and **Noto Sans Devanagari** via `fontFamilyFallback`. Line
  height **1.55** for Telugu / Devanagari, **1.4** otherwise.
- Spacing `xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32`, page gutter 20 dp.
- Radius `s 12 · m 18 · l 26 · pill 999`. Hierarchy from surface, type and space, not shadows.
- Motion `quick 180 ms · calm 420 ms · slow 900 ms`, `Curves.easeOutCubic`; reduced motion = crossfades ≤ 300 ms.

### Component contracts
Filled button (56 dp, pill, accent) · outlined button (52 dp) · switch (on accent; off skyHigh + controlOutline) ·
icon buttons ≥ 48×48 · chips (one selected style everywhere: accent fill + onAccent + leading check) · inputs (skyHigh,
18 dp radius, lavender focus border, input preserved on error) · quadrant/mood tile (equal geometry) · cards (surface +
hairline) · top sheet (26 dp radius, handle, scrollable, no drag-only dismiss) · **global help entry** (lantern,
explicit label, first 3 focus stops, never wraps; heart-only above 130% text) · **`helpAppBar`** (back, one-line title
shrinking to 18 pt then ellipsis, help + actions right; tab roots put Settings on the right) · **`GestureTray`** (one
component for all gesture surfaces, compact row or full grid) · destructive button (danger outline + icon + explicit
words) · navigation (4 tabs + distinct central Check-in; active state by icon + label + container) · toasts ≥ 5 s.

### Visual assets
- Avatar master art `design/avatar/aura_master_v1.png` + `manifest.json`; fragment shaders in the app.
- `CosmicBackground` is the one reusable sky. Personal **sky themes** (night free; aurora, monsoon dusk with Plus;
  first light, lantern festival, deep ocean, meteor shower as cosmetics) recolour only the user's own Home,
  Sanctuary and Insights.
- App icon "Equal Orbit" (iOS set, Android adaptive + monochrome).
- Design critique of every screen: `docs/design/design-critique.md` (findings and their fix status).

---

## 21. Accessibility

Target **WCAG 2.1 AA** on every screen. Almost everything is P0 because Aura is used on hard days.

| ID | Requirement |
|---|---|
| A11Y-01 | Text scales to 200% without clipping in en, te, hi |
| A11Y-02 | Tap targets ≥ 44×44 pt / 48×48 dp, ≥ 8 dp apart (guideline matchers in widget tests) |
| A11Y-03 | Contrast 4.5:1 body, 3:1 large text / icons / control boundaries; no text directly on a starfield or glow without a scrim |
| A11Y-04 | Every control labelled in the current language; moods read name + group |
| A11Y-05 | Avatar is one semantics node described from `AuraAvatarState` ("Your Aura, Glow stage, resting in a soft nebula, violet hue"); particles hidden |
| A11Y-06 | Gestures and presence announced ("Warm Tea sent to Quiet Comet", "7 people here now, 31 today") |
| A11Y-07 | Breath Ripples accessible mode (haptic + tone, tap-to-switch, ±1.5 s tolerance) |
| A11Y-08 | Reduce Motion from OS and the in-app toggle |
| A11Y-09 | No flashing > 3 per second (PEAT check on recordings) |
| A11Y-10 | Quadrants never colour-only (name + icon + fixed position; greyscale still understandable) |
| A11Y-11 | Help within the first 3 focus stops; Safety Center focus lands on helplines; Switch Access / keyboard can check in |
| A11Y-12 | No time pressure; drafts kept; informational toasts ≥ 5 s |
| A11Y-13 | Semantics tagged with the app language (`te` → Telugu voice, `hi` → Hindi voice, romanized → English voice) |
| A11Y-14 | Script-aware line height; goldens at 100/150/200% in te and hi with real Noto fonts |
| A11Y-15 | Pacers work without sight, sound or motion (two of text, haptics, tone) |
| A11Y-16 | Reduce Motion for calm and companion moments |
| A11Y-17 | Sound always has a non-audio equivalent; never autoplays; fades in ≥ 2 s |

Manual passes each milestone (VoiceOver, TalkBack, Accessibility Scanner, Xcode Inspector) in English and Telugu are
AK's; ≥ 3 screen-reader beta testers planned.

---

## 22. Localization

| Language | Locale | Script | UI | Room pool |
|---|---|---|---|---|
| English | `en` | Latin | alpha | English |
| Telugu | `te` | Telugu | alpha | Telugu + Tenglish |
| Tenglish | `te-Latn` | romanized Telugu | alpha | Telugu + Tenglish |
| Hindi | `hi` | Devanagari | beta (hidden behind `AURA_BETA_LOCALES`) | Hindi + Hinglish, gated by `rooms_pool_hi` |
| Hinglish | `hi-Latn` | romanized Hindi | beta | Hindi + Hinglish, gated |

- Flutter `gen-l10n` ARB files `apps/mobile/lib/l10n/app_{en,te,te_Latn,hi,hi_Latn}.arb` (~1,400 keys in English).
  **No hard-coded user-facing strings** (a test enforces it). Feature-namespaced keys with `@description`. ICU
  plurals and placeholders, never concatenation.
- **No gendered forms** (Hindi verbs and Telugu third person agree with gender; use nouns and impersonal forms and the
  respectful Telugu *meeru*).
- **Brand terms stay in Latin script**: Aura, Aura Plus, Lantern Hour, Breath Ripples, Starlight, Stardust.
- One English (Indian/British spelling, "Energised"). Romanized system strings fall back to English.
- Hindi / Hinglish rooms open only when a Hindi-reading moderator exists or auto-moderation reaches ≥ 95% recall on
  ≥ 1,000 native-labelled items.
- Server-sent strings (pushes, moderation reasons, trial email) use the same key catalogue, rendered in NestJS.
- Budget 30–45% longer Telugu and 20–35% longer Hindi; buttons wrap, never truncate. A pseudo-localization test run
  (~40% longer, accented) checks key screens for overflow (`tool/gen_pseudo_l10n.py`).
- RTL-ready (directional insets/alignment, lint test) though no RTL language ships.
- Dates via `intl` by locale; 12-hour time; Indian grouping in India; prices always the store's localized string.
- New language rule: ≥ 8% of MAU in its region or ≥ 5% asking, **and** a lexicon in native + romanized script and
  moderation readiness. Next: Tamil, then Kannada.
- All non-English copy (moods, companion lines, prompts, grounding scripts, intentions, crisis copy) awaits native
  review. Review notes: `docs/l10n/`.

---

## 23. Monetization (F12, switched off for v1.0)

- **Billing**: Apple IAP (StoreKit 2) and Google Play Billing (**PBL 8**, bundled by `in_app_purchase_android` 0.5.3)
  via `in_app_purchase`. **No RevenueCat, no Razorpay / UPI direct checkout** (a static-scan test enforces it).
- **Validation in NestJS**: App Store Server API + Notifications V2; Play Developer API + RTDN via authenticated
  Pub/Sub push; acknowledge within 3 days; purchases carry an HMAC-derived `appAccountToken` /
  `obfuscatedAccountId`; notifications logged, idempotent, reconciled daily. **Never granted from a client receipt
  alone.**

| Product | Id | Price (India, GST incl.) |
|---|---|---|
| Aura Plus monthly | `aura_plus_monthly` | ₹49/month, first month free (Google offer `first-month-free`) |
| Aura Plus annual | `aura_plus_annual` | ₹399/year, first month free |
| Sky themes (cosmetic) | `sky_first_light`, `sky_lantern_festival`, `sky_deep_ocean`, `sky_meteor_shower` | ₹10 / ₹29 / ₹49 / ₹99 (or 10/30/50/100 Stardust) |
| Gifts (consumable) | `gift_warm_tea`, `gift_comfort_lantern`, `gift_encouragement_bouquet` | ₹10 / ₹29 / ₹49 → recipient gets 10 / 30 / 50 Stardust |
Abroad: store-local tiers (e.g. $4.99 / $39.99). ₹10 floor. The app always shows the store's price string.

- **Plus is "more of", never "better calm"**: unlimited mood-trigger capsules, 10-min voice capsules, deeper Insights
  (any range, habit × mood, deeper month in stars), extra Sounds stems and Plus sky themes.
- **Never paywalled**: check-in, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Sanctuary
  (Breathe, grounding, Today's minute, base Sounds, night wind-down), companion response, "A minute for you", Quiet
  Together, wind-down, Look back, keepsakes.
- **Paywall never appears**: within 24 h of onboarding; in a crisis flow or the rest of that day; on nebula wake-up;
  within 3 h of a Storm or Rain check-in. Shows only on limit screens and in Settings, at most once a day unprompted,
  always with a free path; shows "1 month free, then ₹49/month", trial end date, cancel steps, Restore, Terms; no
  countdowns.
- **Gifts**: checked before the store sheet (no block either way, sender unsanctioned, ≤ 5/day, reserved 7 days for
  pending approval); no message; recipient sees "Someone here sent you a Comfort Lantern"; 3+ gifts in 7 days from one
  adult to the same under-18 account flag the minors lane. Refunded gift: recipient keeps the Stardust; 2 refunded
  gifts in 90 days pause gifting.
- **States**: pending, failed ("No charge. Nothing was sent."), trial, grace, lapse (nothing made is lost; sealed Plus
  capsules still open), Restore, cross-platform entitlement.
- **Unit economics**: ₹49 → ex-GST ₹41.53 → less 15% store fee ≈ ₹35.30. Annual ≈ ₹287 net. At 2–5% conversion,
  Plus earns ≈ ₹0.70–1.75 per MAU per month. Google's new fees land globally by 30 Sep 2027 (re-price before launch).

---

## 24. Analytics (parked)

PostHog Cloud (behavioural events, consent toggle "Help improve Aura", `acq_source_answered`) and Sentry are **parked
on the `wip/analytics-ci` branch** along with CI workflows. `pubspec.yaml` still lists `posthog_flutter` and
`sentry_flutter` (off unless `AURA_POSTHOG_KEY` / `AURA_SENTRY_DSN` are passed), but the analytics code is not on this
branch. When unparked, the rules are: under-18 accounts excluded from behavioural analytics (aggregate counts only),
no ad SDKs, no IDFA/GAID, never mood notes, reflection text, capsule content or DOB in any event or log. The
`crisis_events` table exists with no writer.

---

## 25. Security and privacy engineering

- **Envelope encryption (DS-1)**: per-user data key (`user_data_keys`, with key id) wrapped by `AURA_MASTER_KEY`
  (held outside the DB, in the host's secrets; **losing it makes every note, voice note and capsule unreadable**).
  Notes, voice, capsule payloads and media are encrypted on the device with AES-256-GCM; reflections and corpus rows
  are sealed server-side. The admin console has no decrypt path to private content.
- **Keys on device** in Keychain `…AfterFirstUnlockThisDeviceOnly` / Android Keystore; DB and media excluded from
  backups; App Group container excluded too.
- **Network**: no cleartext (Android `usesCleartextTraffic=false`, iOS ATS default); release builds refuse non-https
  base URLs; verified TLS to managed Postgres (`DATABASE_CA_CERT`).
- **Log scrubbing**: automated guards (Dart analyzer, TS compiler API) fail on logging private fields; server
  `log-scrub.ts`. Never log or send mood notes, reflection text, capsule content or DOB.
- **Forced update** (MASVS F-6) via `minAppVersion` in `GET /v1/config`.
- **Dependency audit**: `tools/audit/deps.sh` (`pnpm audit --prod`, Dart advisories).
- **Privacy manifests** for the app and the widget; no tracking domains.
- **RLS tests** for every table; client write denial tests; admin grant tests.
- **Audit log** append-only and hash-chained, exported nightly, verified via `GET /admin/audit/verify`, kept 3 years.
- **Rate limits** in Redis with HMAC'd identifiers (install ids, addresses).
- Reviews: `docs/security/masvs-l1.md` (OWASP MASVS L1 checklist), `docs/security/milestone-b-review.md` (NestJS/RPC
  boundary review and residuals §5.x: master-key rotation, sandbox entitlements, cookie prefix, `NODE_ENV`, edge rate
  limits, external pen test, secrets custody).

---

## 26. Legal, compliance, store and public site

### Regulatory map (summary; lawyer review pending)
India **DPDP Act + Rules** (main obligations 13 May 2027, during beta; parental consent for under-18s **not
implemented**, accepted risk R1) · **SPDI Rules** (explicit consent for mental-health data until then) · **IT Rules
2021 as amended 20 Feb 2026** (Grievance Officer, clocks above) · **POCSO** (mandatory reporting) · **CCPA dark
patterns** (no traps in trial / paywall) · US **COPPA** (under-13 blocked) · **Texas SB 2420** in force (not
implemented, risk R2) · GDPR / UK Children's Code / Australia under-16 law before those regions open at beta (Art. 27
representatives, DPIA, Art. 8 position, risk assessments, DSA trader status).

### Accepted legal risk register (AK, 23 Sep 2026)
R1 no parental consent (DPDP) · R2 US state app-store laws · R3 EU/UK/AU minors rules · R4 mixed-age stranger rooms ·
R5 App Review (age restriction + anonymous chat clause) · R6 crisis copy not clinically reviewed · R7 one moderator.

### Store compliance map (handled where)
Apple 1.2 UGC (filtering, reports, blocks, contact) → F6/F9/console · 1.2 anonymous chat → gesture-first design +
review notes · 1.4.1 / Play health → disclaimers + Health apps declaration · 5.1.1(v) → in-app deletion · 5.1.1(ix) →
AKVega company accounts · 5.1.3 → no ads, DB not in iCloud · 2.5.4 / Play foreground service → Sounds audio only when
the user plays it · 3.1.1 → IAP only · Play UGC → guidelines before posting · Data Safety / privacy labels →
`docs/store/`.

### Store assets (`apps/mobile/store/`)
Listings for Android `en-IN`, `en-US`, `hi-IN`, `te-IN` and iOS `en-GB`, `en-US`, `hi`, `te`; Tenglish / Hinglish extras
for ASO; screenshots (App Store 6.9" 1320×2868, Play phone 1080×1920, Plus off); Play graphics; `listing_rules.json`
+ a lint test. Store docs: `docs/store/age-rating.md`, `app-privacy-labels.md`, `play-data-safety.md`,
`export-compliance.md`, `pricing.md`, `app-review-notes.txt`. Review sign-in: `docs/setup/app-review.md`.

### Public site (`apps/site`, Firebase Hosting `aura-akvega`)
`https://aura-akvega.web.app`: `/` · `/privacy/` · `/terms/` · `/support/` (with Grievance Officer) · `/delete-account/`
· `/child-safety/`. Edit `apps/site/site.json`, run `python3 apps/site/build.py`, deploy with
`firebase deploy --only hosting`. Strict headers: HSTS, no scripts, `frame-ancestors 'none'`.
Published contact: Grievance Officer **Kalyan Kumar Bedugam**, `akprojects1431@gmail.com` (used because no AKVega
domain mailbox exists yet).

---

## 27. Testing, tooling and commands

### Commands
```bash
# Local backend services (from repo root)
supabase start
supabase db reset
supabase test db
docker compose -f infra/docker-compose.yml up -d

# API + worker
cd server/aura-api && pnpm install && pnpm test && pnpm start:dev
pnpm start:worker:dev
pnpm test:e2e
pnpm lint

# Dart domain
dart pub get
cd packages/aura_domain && dart test

# Mobile
cd apps/mobile && flutter run
dart run build_runner build -d
flutter analyze && flutter test

# Admin console
cd apps/admin && pnpm typecheck && pnpm lint && pnpm test && pnpm build

# PRD
python3 docs/prd/assemble.py
```

### What the tests cover
- **Rules vectors** (`contracts/rules/vectors`) in both Dart and TypeScript.
- **Mobile** (~158 test files, 2,352 tests): screens, saved-moment order, sync (outbox, delta pull, tombstones),
  companion lines and copy lints, insights copy lint, no hard-coded strings, RTL readiness, pseudo-localization
  overflow, accessibility guidelines and contrast, avatar painter goldens (every stage × resting × tier), script
  goldens (te / hi at 100/150/200%), billing static scan, store listing lint, device profile, age gate, data export,
  grievance form. Design captures (`--tags capture`).
- **Server** (1,500 unit + 322 e2e): matching ladder, gesture limits, lanterns, pseudonyms + blocklist, reflections
  decide + corpus + e2e pipeline, ripples, quiet (payload scans for DS-10 / REQ-QUIET-01), billing (catalogue
  invariants, trial push, webhooks), notifications (policy, copy lint, smart timing), admin actions, helplines,
  lexicon candidates, account export, media sweep.
- **Database** (pgTAP 00–35): schema contract, RLS read-own, client writes denied, one file per migration.
- **Admin** (41): sealed cookies, origin checks, etc.
- **Load**: `tools/load/` realtime load test (results in `docs/perf/realtime-load-test.md`).
- CI is **parked** (`wip/analytics-ci`); lints run as tests locally.

---

## 28. Hosting, deploy and release

| Piece | Where (actual, Sep 2026) | PRD plan |
|---|---|---|
| Postgres, Auth, Realtime, Storage | Supabase project in ap-south-1 (Mumbai) | same |
| API + worker | **Render Free web service in Singapore**, one process running both (`scripts/start-all.mjs`), auto-deploy from `main`; kept awake by an uptime ping on `/health` | DigitalOcean Mumbai droplets |
| Redis | Render Key Value (free, no persistence, `noeviction`) | managed Redis |
| Admin console | Vercel (`aura-admin.vercel.app`) | beside NestJS in Mumbai |
| Public site | Firebase Hosting `aura-akvega.web.app` | website |
| Mail | SMTP via Resend, from `no-reply@akvega.com` | — |

**For launch** (render.yaml note): split into a `starter` web service (`node dist/main.js`) + a `starter` worker
(`node dist/worker.js`) + `starter` Key Value with persistence.

Secrets (entered in the host dashboard, never committed): `DATABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_ANON_KEY`, `AURA_MASTER_KEY` (back up offline), `LEXICON_SIGNING_KEY`, `OPENAI_API_KEY`, `SMTP_URL`, store
credentials, `REVIEW_ACCOUNT_EMAIL` / `REVIEW_ACCOUNT_CODE`, `APP_MIN_VERSION_IOS/ANDROID`.

**Mobile release**: `tools/release/ios.sh` (build, sign with an App Store Connect API key, upload to TestFlight;
`ExportOptions.plist`) and `tools/release/android.sh` (signed App Bundle; needs `android/key.properties`, see
`docs/setup/android-release-signing.md`). Social sign-in setup: `docs/setup/social-sign-in.md`. Lexicon and flags:
`docs/setup/lexicon-and-flags.md`.

**Marketing video**: `tools/video` (Remotion project: 16:9 feature tour and 9:16 reel).

---

## 29. Out of scope (v1)

- Therapy, diagnosis, clinical scoring (PHQ-9/GAD-7), AI "therapist" chat.
- DMs, friend lists, followers, public profiles (only "Bring a friend" private rooms post-v1).
- Text replies, threads, voice chat, video; images or audio shared with strangers.
- Parental consent flows, teen-only pools, parent dashboards (D2).
- Shared Universe Album, community capsules, Zen Stone Stacking, Melody Weaving.
- Rewarded ads; direct UPI/Razorpay; Google User Choice Billing; RevenueCat.
- LLM moderation classifier, clinical advisor, ThroughLine licence.
- Rive or commissioned illustration; wearables / HealthKit / Health Connect; a web app (only the admin console is web).
- Languages beyond the five; campus partnerships and B2B.
- Rejected competitor features: stranger letters, stranger accountability partners, voice/audio circles, user-created
  circles and creator skins, coaching marketplace, social-media memory import, HP/gold economy, nostalgia streaks,
  celebrity sleep stories, meditation videos, binaural beats or health claims. **Deferred**: multi-day Pathways,
  narrated wind-down.
- Post-v1 ideas on record: custom moods, intensity slider, on-device voice transcription for crisis scanning, body
  forms for the avatar (masculine, androgynous; high priority), planned rest days, annual Year in Stars, curated
  life-context room themes, Control Center control, Live Activity, passkeys, phone OTP.

---

## 30. Open items, blocked items and remaining work

See section 2 for the full "blocked on AK" list and the five remaining code items. Also:
- `trust_screen.dart` `TODO(legal)`: SPDI consent text from the lawyer.
- `delivery.service.ts` `TODO(analytics)`: `notification_sent` event (parked).
- Universal / App Links (MASVS F-5) need a domain.
- Device-ban attestation needs Apple DeviceCheck and Play Integrity keys.
- 8 recorded sound stems pending licensed sourcing.
- Real legal / grievance values and native review of all new copy.
- Interpretations made where the PRD was open (keep them unless AK changes them): longest streak hides with "Hide
  streak number"; corpus exclusions broader than the PRD; data export made on the phone (not emailed); grievance form
  pre-fills the email; delta-pull cursor and tombstone rules; smart timing counts any check-in; Low tier threshold
  `totalMem ≤ 3.3×10⁹` or power saving; speech locales; one Latin pseudonym list for all pools + live blocklist; Block
  Store device-only; pseudo-localization as a test run; date-capsule push always 10:00 local.
- Still open in the screen plan: whether a completed check-in returns to the originating tab (recommended yes).

---

## 31. Rules every agent must follow

1. **Read the contract first.** Product behaviour: `docs/prd/sections/`. Rules: `contracts/rules/RULES.md` + vectors.
   API: `contracts/api/*.md`. Moods: `contracts/moods.json`. Do not invent fields, endpoints or rules.
2. **Rule changes start in `contracts/rules`** (spec + vectors), then Dart (`packages/aura_domain`), then TypeScript
   (`server/aura-api/src/rules`). Both suites must pass the same vectors.
3. **Schema changes are new Supabase migrations** with a matching pgTAP test; RLS on every table; personal tables are
   select-own only.
4. **The app never writes personal tables directly**: everything personal goes through `POST /v1/sync/push`.
5. **DS-10**: no stranger-facing payload may contain an account id, age, DOB or under-18 flag. Add a payload-scan test
   for any new stranger surface.
6. **Never log or send** mood notes, reflection text, capsule content or DOB to analytics or logs.
7. **Help first**: "I need help now" on every new screen (first 3 focus stops), working offline and signed out; the
   crisis sheet comes before anything else.
8. **Non-punitive and equal dignity**: no loss copy, no red for feelings, no scores, no countdowns, equal treatment of
   every quadrant. Run the copy lints.
9. **No hard-coded strings**: add ARB keys for all five locales (English final, others marked for native review);
   no gendered forms; brand terms in Latin script.
10. **Use the design tokens and shared components** (`AuraColors`, `AuraSpace`, `AuraRadius`, `AuraMotion`,
    `helpAppBar`, `GestureTray`, `CosmicBackground`). No per-screen token copies.
11. **Accessibility**: 200% text, 48 dp targets, labels, Reduce Motion variants, no colour-only meaning.
12. **Feature-first folders, repository pattern, immutable Freezed models, Riverpod providers, no cross-app imports,
    shared logic in `packages/`** (AK's Asan conventions).
13. **Kill switches are enforced on the route**, not just hidden in the UI.
14. **Never paywall** anything on the never-paywalled list, and respect the paywall exclusions.
15. **Never edit `docs/PRD.md` directly**; edit a section and run `python3 docs/prd/assemble.py`.
16. **Work style AK asked for**: run build agents **one at a time**, not in parallel; verify and integrate each before
    starting the next. Commit only when asked; branch off `main` for new work.
17. **Match the surrounding code**: comment density, naming and idiom.

---

## 32. Where to find things (doc index)

| Topic | File |
|---|---|
| Repo guide | `CLAUDE.md` |
| Full PRD (assembled) | `docs/PRD.md` |
| PRD sections | `docs/prd/sections/00-header` … `22-out-of-scope` (features in `06a` core, `06b` social, `06c` platform, `06d` calm) |
| Status audit of every requirement | `docs/status/pending.md` |
| Screen plan and navigation decisions | `docs/screen-plan.md` |
| Design system | `docs/design-system.md` |
| Design critique + 138 screen captures | `docs/design/design-critique.md`, `docs/design/screens/INDEX.md` |
| Competitor integration plan | `docs/competitor-integration-plan.md` |
| Market research, fact-check | `docs/research/` |
| Progression rules | `contracts/rules/RULES.md`, `contracts/rules/vectors/` |
| API contracts | `contracts/api/v1*.md` |
| Safety data (lexicon, helplines, reflection filter) | `contracts/safety/` |
| Sound stems manifest | `contracts/sounds/stems.v1.json`, `docs/sounds/licence-log.md` |
| Security | `docs/security/masvs-l1.md`, `docs/security/milestone-b-review.md` |
| Store and privacy declarations | `docs/store/`, `apps/mobile/store/` |
| Setup guides | `docs/setup/` (admin console, Android signing, App Review, lexicon and flags, social sign-in) |
| Localization notes | `docs/l10n/` (helplines and emails, Hindi review, Hinglish / Tenglish mood names) |
| Realtime load test | `docs/perf/realtime-load-test.md` |
| Backend deploy | `render.yaml`, `server/aura-api/README.md` |
| Public site | `apps/site/`, `firebase.json` |
