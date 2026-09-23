## Technical Constraints

Store-policy and regulatory facts below were verified on 23 Sep 2026 (sources in `docs/research/fact-check-2026-09-23.md`). Where they contradict the original research docs, **this section wins**.

### What the verification changed
| Research doc said | Reality | Change in this PRD |
|---|---|---|
| Sell cosmetics/gifts via direct UPI / Razorpay | Digital goods must use **Apple IAP / Play Billing** (Apple 3.1.1 has no India exception). Both stores already accept **UPI and UPI Autopay**. | Store billing, validated by AKVega's own NestJS service; Razorpay not used in v1 |
| ₹9 sachet price | Google Play India minimum is **₹10** | ₹10 floor everywhere |
| Rewarded ads to recover streaks | Contradicts the non-punitive design; ads to minors are restricted in India (DPDP) | No ads in v1; P2 adults only, never tied to streaks |
| Stranger rooms are the differentiator | Apple 1.2 names **"random or anonymous chat"** as removable without notice | Rooms are gesture-first, structured and filtered, with report/block/contact (see F9 "App Review positioning") |
| Perspective-style moderation APIs | **Perspective API shuts down 31 Dec 2026**; no production Hinglish/Tenglish moderation API exists | On-device lexicon → OpenAI omni-moderation → human (AK). Train an in-house model later on de-identified labelled data |
| Supabase Realtime "just works" | Pro with spend cap: **500 concurrent connections, 50 Presence msgs/s** | Spend cap off from beta; event-light protocol (below) |
| Unit economics at list price | Store fees (15%) and 18% GST are ignored | Net-revenue math in F12 |

### Platform & stack (D5)
| Layer | Choice | Constraint / note |
|---|---|---|
| App | **Flutter stable ≥ 3.32**, Dart ≥ 3.8, Impeller | Feature-first folders; shared logic in `packages/core` |
| State / routing / models | Riverpod 2 (+ generator), GoRouter with Universal/App Links, Freezed, Dio + interceptors | Standard Asan Flutter conventions |
| Local store | **Drift** (SQLite), encrypted | Outbox sync with client UUIDs. **DB file excluded from iCloud backup** (Apple 5.1.3 treats health data conservatively) |
| Art & animation | **Hybrid:** AI-generated character art from AK (`design/avatar/`, transparent PNG → WebP) as the base, with every living effect in code: fragment shaders (`FragmentProgram`) + `CustomPainter` + `flutter_animate`; SVG icon set for gestures | No animator or Rive in v1. Avatar driven by a Dart `AuraAvatarState` + asset `manifest.json` (anchors, baked rings), see F2. **Quality tiers**: fewer particles and shader passes on low-RAM Android; fallback chain shader → painter → plain base image |
| Widget | `home_widget` 0.10 | **Widget UI must be written natively** (SwiftUI + AppIntents on iOS 17+, Kotlin Glance on Android). iOS 16 gets a tap-to-open widget |
| Audio (F15, F16; from B) | Background playback plugin with a media session `[ASSUMPTION: e.g. just_audio + audio_service]`; brown noise synthesized on device | Background audio only while the user plays it (iOS `UIBackgroundModes: audio`; Android `mediaPlayback` foreground service). Base stems (≈ 8 MB) download on first use, so they don't add to the install size. No microphone |
| Min OS | **iOS 16 / Android 7.0 (API 24)** | Target SDK per the current Play requirement `[STORE]` |
| Data platform | **Supabase Pro, ap-south-1 (Mumbai)**: Postgres + RLS, Auth, Realtime (Broadcast; Presence ≤ 24/room), Storage (private buckets, signed URLs) | **Spend cap off before beta** |
| Application backend | **NestJS modular monolith** (API service + Worker service) + **Redis / BullMQ**, on **DigitalOcean Mumbai** | Owns ledger-affecting writes, room matching, moderation jobs, purchase validation, admin endpoints, notifications, scheduled jobs (capsule unlocks, room lifecycle). Uses Supabase via the service role; **all stranger-facing reads go through NestJS or reviewed Postgres RPCs that return pseudonyms only** (DS-10) |
| Billing | `in_app_purchase` (StoreKit 2 / **Play Billing Library v8**) → **NestJS validation**: App Store Server API + **App Store Server Notifications V2**; Google Play Developer API + **Real-time Developer Notifications** (Cloud Pub/Sub) | No RevenueCat (DS-9). NestJS owns the `entitlements` table, refunds, grace periods, trial → paid, upgrades/downgrades. Budget ~2 weeks for this |
| Push | FCM (APNs via FCM), sent from the NestJS worker | Payloads carry **no mood or content** (shared phones) |
| Analytics / crash | **PostHog Cloud**, Sentry | Under-18 users excluded from behavioural analytics; no ad SDKs, no IDFA, no ATT prompt |
| Moderation | On-device lexicon (EN / TE / Tenglish / HI / Hinglish) → **OpenAI omni-moderation** (free) → human queue | No LLM classifier (AK's decision). Expect more held items in Telugu/Tenglish/Hinglish. Cross-border processing disclosed `[LEGAL]` |
| Crisis directory | Static: **India** Tele-MANAS 14416 / 1-800-891-4416, **US** 988, **everywhere else** a generic "call your local emergency number" | No ThroughLine licence (AK's decision); findahelpline.com data is personal-use only and not embedded |
| Admin console | Small internal Next.js app → NestJS admin endpoints | SSO + 2FA; no decrypt path to private content |

### Realtime protocol budget (why "event-light" matters)
A Supabase broadcast is billed as **1 + number of subscribers**. For a 4-player, 3-minute Breath Ripples session:

| Protocol | Broadcasts per session | Billed messages per session | At 1,000 sessions/day |
|---|---|---|---|
| Naive stream (10 events/s per player) | ~7,200 | ~36,000 | ~1.1 B/month → **≈ $2,700/month** |
| **Phase transitions + pulses only** (≈ 46 events per player) | ~184 | ~920 | ~28 M/month → **≈ $57/month** |

**Rule:** clients send *state changes* (inhale/exhale transitions, pulses, gestures) with timestamps and interpolate locally. **10 events/s is a burst ceiling, not a send rate** (F7 specifies < 1 event/s in normal play). Rooms broadcast **IDs only** and fetch text through the NestJS/RPC layer. Room Presence (≤ 24 members per channel) is fine at beta scale with the spend cap off (1,000 Presence msgs/s). **Alert at 50% of the Presence limit**, and have a fallback ready: a server-computed "N here now" counter pushed every 30 s. Users outside India connect to Mumbai; Breath Ripples tolerates up to 1.5 s one-way delay (F7). **Quiet Together (F16) uses no per-member Presence:** the server broadcasts a count every 30 s plus unnamed gesture events, and each phone plays the shared sound locally from `t0`, so no audio crosses the network.

### Store policy compliance map
| Rule | Requirement | Where handled |
|---|---|---|
| Apple 1.2 (UGC) | Filtering, reporting with timely response, blocking, published contact | F6, F9, Admin console |
| Apple 1.2 (anonymous/random chat) | Must not read as random chat | F5/F6 design (gestures, no DMs, ≤ 200-char filtered text); F9 review notes |
| Apple 1.2.1(a) / 4.7.5 | Age restriction "based on verified or declared age" for relevant content | DOB gate blocks under-13. **13–17 are not separated (D2)**, so App Review may push back `[STORE]` |
| Apple 1.4.1 / Play health policy | No medical claims; "not a medical device / not an emergency service" disclaimers; Play **Health apps declaration form** | F9, store listing, onboarding |
| Apple 5.1.1(v) | In-app account deletion | F8 |
| Apple 5.1.1(ix) | Health-adjacent apps submitted by a **legal entity** | **AKVega company accounts** ✔ |
| Apple 5.1.3 | Health data not used for ads or data mining; not stored in iCloud | No ads; analytics minimised; Drift DB excluded from backup |
| Apple 2.5.4 / Play foreground-service policy | Background audio only for audible content the user started; Play needs the `mediaPlayback` type declared in Console `[STORE]` | F15 Sounds; review notes; check in weeks 28–29 |
| Apple age rating | New tiers (4+/9+/13+/16+/18+); social features imply ≥ 13+ | Target **13+**. With unrestricted stranger interaction and UGC, the questionnaire may return **16+ or 18+** `[STORE]`, so check in week 1 |
| Apple 3.1.1 / Play Billing | Digital goods via IAP; gifts refundable only to the buyer; Play Billing Library v8 | F12 |
| Play UGC | Users accept terms before posting; in-app reporting; blocking | F8 onboarding, F9 |
| Play Data Safety / privacy policy | Accurate declarations; policy linked in Console and in-app | Pre-launch checklist |
| US state app-store laws | Texas SB 2420 **in force since 4 Jun 2026** (Declared Age Range + PermissionKit + parental consent for minors); Utah 6 May 2027; Louisiana 1 Jul 2027 | **Not implemented (D2)**. The US storefront includes these states: see the risk register |

### Regulatory constraints
| Law | What applies to Aura | When |
|---|---|---|
| **India: DPDP Act 2023 + Rules 2025** | Itemised notice and consent; purpose limitation; rights to access, correct, erase and nominate, plus grievance; breach notification `[LEGAL]`; security safeguards; processor contracts (Supabase, DigitalOcean, OpenAI, PostHog, Google, Apple). **Children (< 18): verifiable parental consent, and no tracking, behavioural monitoring or targeted ads. Not implemented for consent (D2).** Penalty up to ₹200 crore | Main obligations from **13 May 2027**, during open beta |
| **India: SPDI Rules 2011** | Mental-health data is sensitive personal data: explicit (electronic) consent, privacy policy, documented security practices | Governs alpha and beta until 13 May 2027 |
| **India: IT Rules 2021 (amended 20 Feb 2026)** | Terms published; **Grievance Officer (AK)**; acknowledge in 24 h, resolve in **7 days**; unlawful content **36 h**; nudity/CSAM **2 h**; court/government orders **3 h**; removed-content records **180 days** | From alpha |
| **India: POCSO Act** | Mandatory reporting of sexual offences against children that come to Aura's knowledge | Instant-ban SOP (F9) `[LEGAL]` |
| **India: CCPA Dark Patterns Guidelines 2023** | No false urgency, confirm-shaming, subscription traps (incl. trial → paid) | Paywall, trial reminder, notification copy |
| **US: COPPA** | Applies to under-13s | Under-13 blocked at the DOB gate with a 30-day device lock |
| **EU: GDPR** (from beta) | Art. 27 EU representative, DPIA for health data, Art. 9 explicit consent, **Art. 8 parental authorisation below the member-state age (13–16)** | Before EU opens at beta |
| **UK: UK GDPR + Children's Code** (from beta) | UK representative; high-privacy defaults for under-18s | Before UK opens at beta |
| **Australia: under-16 social media minimum age law** (from beta) | If Aura counts as an age-restricted social media platform, under-16s must be kept off | Assess before AU opens; may force a 16+ floor in Australia `[LEGAL]` |
| Mental Healthcare Act 2017 / ASCI | Don't present Aura as mental-health *care*; no therapeutic claims in ads | Copy, store listing |

### Legal risk register: accepted by AK on 23 Sep 2026
AK chose **13+ with full access, no parental consent and one mixed-age pool (D2)** after the risks below were explained. They're recorded here so the lawyer engaged in week 0 reviews them **before alpha**.

| # | Risk | Exposure | Mitigations in the product (none limits users) |
|---|---|---|---|
| R1 | No verifiable parental consent for Indian under-18s (DPDP Rule 10) | Penalty up to ₹200 crore; applies from 13 May 2027 | Data minimisation; under-18s excluded from behavioural analytics; no ads; lawyer review |
| R2 | Texas SB 2420 (in force), Utah/Louisiana (2027) for US minors | State enforcement and private action | Lawyer to advise, e.g. excluding affected US states or adding Declared Age Range + PermissionKit for those states only `[LEGAL]` |
| R3 | GDPR Art. 8 / UK Children's Code / Australia under-16 law when EU/UK/AU open at beta | Regulator action; store removal in those countries | Opening is gated on a legal assessment; country-specific age floors possible `[LEGAL]` |
| R4 | Mixed-age stranger rooms: adults meeting teens at emotional moments | Grooming risk; reputational and legal harm | No DMs, no text replies, no photos, fresh pseudonym per room, stricter auto-moderation on under-18-involved content, "Minors & grooming" lane, instant ban + evidence + mandatory report |
| R5 | App Review: age restriction by declared age (1.2.1(a)) plus the "anonymous chat" clause | Rejection or removal | Gesture-first design; review notes; demo of moderation |
| R6 | Crisis copy not clinically reviewed; generic helplines outside India/US | Duty-of-care gap | Self-review against published safe-messaging guidelines; always-visible help; review again before EU/UK/AU |
| R7 | One moderator (AK) until 5,000 DAU | Missed SLAs overnight | Fail-closed holds, instant crisis diversion, 24×7 paging for 2 h / 3 h legal items, hire at 5,000 DAU |

### Non-functional requirements
| Area | Requirement |
|---|---|
| Performance | Cold start < 2.5 s on a mid-range Android (4 GB RAM class); mood-only check-in saved locally < 300 ms; avatar and Breath Ripples at 60 fps on mid-range devices (quality tier drops below that); API p95 < 300 ms from India; reflection auto-moderation p50 < 2 s |
| Size | Initial download < 60 MB `[ASSUMPTION]` (procedural art keeps assets small; Sounds stems download on demand) |
| Reliability | Backend availability ≥ 99.5% monthly; offline-first personal core; no data loss on app kill (outbox) |
| Security | RLS on every table with tests in CI; stranger reads only via NestJS/reviewed RPCs; envelope encryption for private content (DS-1); private storage with short-lived signed URLs; 2FA + SSO on admin; OWASP MASVS L1 checklist before launch |
| Privacy | Full DOB stored (DS-6) and covered in the privacy notice; aggregate-only crisis events; no ad SDKs; SDK inventory matches Data Safety / privacy labels |
| Battery / data | No background location; sockets only while a room or game is open; works on 3G-class connections for the personal core |
| Observability | Sentry; NestJS structured logs; BullMQ queue metrics; alerts to AK's phone for crisis items, legal orders, 2 h grievances and SLA breaches |
| Cost envelope | Estimated **US$300–450/month at 20k beta users** `[ASSUMPTION]`: Supabase Pro + compute, realtime overage, DigitalOcean (NestJS API + worker droplets, managed Redis), PostHog/Sentry free or low tiers, OpenAI moderation free |
