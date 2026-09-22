## Feature Specification — Accounts, Safety & Monetization

Covers F8, F9 and F12; other sections enforce these rules.

### F8 Accounts & Age Gate

**Priority:** P0, Milestone A (closed alpha, w/e 10 Jan 2027).

**Purpose.** Start in under a minute with no real name or phone number, keep under-13s out, give everyone 13+ the full app, and pass store account rules first time.

#### Behaviour

**Order.** Welcome → date of birth → (under 13: block) → sign in → first check-in. **Everyone 13+ gets the full app, with no feature limits.** DOB comes first so Aura never receives an under-13's email.

**Sign-in.** Sign in with Apple (Apple 4.8), Google, or email magic link. Email scope only; no name, password or profile.

**Neutral DOB.** Empty day, month and year pickers, no default year, no copy mentioning 13 or 18. **Full date stored** (DS-6); never shown to others or returned by stranger-facing endpoints (DS-10).

**Under-13 block.** Kind screen with help by region (India: Childline 1098, 112; elsewhere: "talk to an adult you trust"). No account, email or device ID is created. A **device lock** (iOS Keychain; Android Block Store `[ASSUMPTION: confirm persistence across reinstall]`) shows the block screen on every launch for **30 days**. No server-side fingerprinting.

**Platform age signals only block under-13s; they never gate 13–17.** Apple **Declared Age Range** (iOS 26+) and **Play Age Signals** (beta; Texas and Brazil now, global later in 2026) are read where available (≤1 s wait). Signal <13 → block, whatever the DOB. Signal under 18 with an adult DOB → under-18 invisible protections only `[ASSUMPTION]`. Otherwise → DOB alone.

**Under-18 flag.** `is_minor` (from DOB) never changes what a user sees or does; it drives only invisible protections (analytics exclusion, stricter moderation, minors lane) and clears at 18.

**Deletion and export.** In-app delete (Apple 5.1.1(v); Play also needs a web link), warning that subscriptions continue. Deactivated at once, restorable by signing in within 7 days `[ASSUMPTION]`, hard-deleted within 30 days incl. storage; Apple token revoked. Purchase/tax records and evidence holds (DS-4) kept only as law requires `[LEGAL]`. Export: JSON + readable HTML within 72 h `[ASSUMPTION]`.

**Publisher.** **AKVega** (existing company store accounts; Apple 5.1.1(ix)) is publisher and data fiduciary / controller.

**Storefronts.** **Worldwide from alpha except the EU, UK and Australia**, which open at Milestone B (w/e 2 May 2027); Norway, Iceland and Liechtenstein stay closed with the EU (GDPR applies) `[ASSUMPTION]`. **Before EU/UK/AU open:** (1) **GDPR Art. 27** EU and UK representatives; (2) **DPIA** for mood data as health data (Art. 9) and under-18 users; (3) written **GDPR Art. 8** position for users below each country's age of consent (13–16); (4) **UK Children's Code** review and Online Safety Act risk assessments; (5) **Australia under-16 social media law** assessment; (6) **EU DSA trader status** `[STORE]`. Items 1–5 `[LEGAL]`. A failed item keeps that region closed or adds a local age floor.

> **Legal risk accepted by AK (23 Sep 2026)**
>
> AK chose 13+, full access, no parental consent and one mixed-age pool after being told these risks. It is the PRD's top legal and safety risk.
>
> | Law / exposure | Requires | Aura v1 |
> |---|---|---|
> | **India DPDP, Rule 10** | Verifiable parental consent for under-18s; no behavioural monitoring of children. Up to **₹200 crore**. Applies **13 May 2027**, during beta. | No parental consent; full DOB means Aura knows who is a minor. |
> | **Texas SB 2420** (in force 4 Jun 2026; US storefront includes Texas) | Store age signal; revocable parental consent for minors' downloads, IAP and significant changes (PermissionKit). Utah 6 May 2027, Louisiana 1 Jul 2027. | Signals only block under-13s; no PermissionKit consent. |
> | **GDPR Art. 8, UK Children's Code, Australia under-16 law** | Parental authorisation below 13–16; under-18 privacy defaults; under-16s off age-restricted social media. | Regions closed until the checklist is done. |
> | **Mixed-age rooms** | Grooming risk; App Review scrutiny (1.2, 1.2.1(a)) `[STORE]`. | Teens and adults share rooms and Breath Ripples. |
>
> **Mitigations that limit no one:** no DMs, replies, profiles, photos, links or handles; fresh pseudonym per room; under-18s out of behavioural analytics; stricter grooming, PII and sexual thresholds on content involving an under-18; a "Minors & grooming" lane; instant ban, 180-day evidence hold and mandatory reporting (F9); no ads.
>
> **Gate:** the lawyer engaged in week 0 reviews this box, F9 and the privacy notice **before alpha submission**. If they advise against launch, AK decides again.

#### Requirements

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-ACC-01 | P0 | Apple / Google / magic-link sign-in; no name or phone. | Google requests email scope only. **Neg:** no screen asks for name or phone. |
| REQ-ACC-02 | P0 | Neutral full-date DOB before any auth call. | Continue disabled until day, month and year are set. **Neg:** zero auth requests before DOB. |
| REQ-ACC-03 | P0 | Under-13 block, 30-day device lock. | Given DOB <13, when the app is relaunched or reinstalled (iOS), then the block screen shows, not DOB. **Neg:** nothing identifying reaches the server. |
| REQ-ACC-04 | P0 | Age signals only block under-13s. | Adult DOB + signal <13 → block. No signal → waits ≤1 s. **Neg:** no signal value hides a feature from a 13+ user. |
| REQ-ACC-10 | P0 | Under-18 flag, invisible only. | DOB 24 Sep 2008 → `is_minor` false from 24 Sep 2026. **Neg:** a 13- and a 30-year-old see identical features; flag absent from stranger-facing responses. |
| REQ-ACC-11 | P0 | In-app deletion. | ≤3 taps from Settings; subscription warning; purge ≤30 days. **Neg:** never requires emailing support. |
| REQ-ACC-12 | P1 | Data export. | Contains own check-ins, habits, capsules, purchases. **Neg:** no other users' content or moderation notes. |
| REQ-ACC-13 | P0 | AKVega publisher; no EU/EEA, UK or AU until beta. | Both listings in AKVega's accounts. **Neg:** release checklist blocks those regions until REQ-ACC-14 is done. |
| REQ-ACC-14 | P0 (B) | EU/UK/AU opening checklist. | Items 1–6 each have an owner, date and filed document. **Neg:** a missing item keeps that region closed. |
| REQ-ACC-15 | P0 | Lawyer review before alpha. | Written review filed. **Neg:** no alpha build submitted without it. |

#### Edge cases
- **Adult enters a wrong DOB:** "Entered the wrong date?" → support; younger at once, older only with evidence `[ASSUMPTION]`.
- **"Might be under 13" confirmed:** account and data deleted within 7 days (COPPA for US users) `[LEGAL]`.

#### Minors (13–17)
No user-facing difference. Invisible only: `is_minor`, analytics exclusion, stricter moderation, minors lane, Childline 1098 on the India sheet.

#### Post-v1
Phone OTP `[ASSUMPTION]`; passkeys; a parental-consent flow only if the lawyer or a regulator requires it (PRD v1.0 design).

### F9 Safety, Moderation & Crisis Routing

**Priority:** P0 at Milestone A; reflection pipeline when F6 ships.

**Purpose.** Rooms are Aura's core and its biggest store risk: Apple 1.2 names "random or anonymous chat" as removable, IT Rules 2026 set hour-level takedown clocks, some users arrive in crisis, and 13-year-olds share rooms with adults. F9 makes stranger contact structured, filtered and accountable, with help one tap away.

#### App Review positioning
**Aura is** a private mood journal with optional, time-limited mood rooms where people who feel the same respond with 8 preset gestures and short pre-moderated reflections. **Aura is not** random or anonymous chat, messaging, dating, therapy, a medical device or an emergency service.

Safeguards for review notes (Apple 1.2, 1.2.1(a), 1.4.1; Play UGC):
- **No chat:** no DMs, replies or threads; reflections ≤200 chars, 3/room/day, answered only by gestures.
- **Filtering** before publish; no links, handles, numbers or images.
- **Report, block, mute** everywhere; human review <24 h, crisis <1 h.
- **Young users:** under-13s blocked; stricter thresholds and a dedicated lane for anything involving an under-18; instant ban and reporting for grooming.
- **No identity:** fresh pseudonym per room, no profiles or photos; rooms close at 24 h, purge 7 days later.
- **Guidelines** before first room; **crisis routing** everywhere; **published contact** and Grievance Officer; company publisher.

Attach a demo account, a seeded room and a 60-second recording of a report actioned. Listing copy says "mood rooms" and "silent support", never "chat", "anonymous" or "talk to strangers". Expected rating 13+ (16+ in Australia); revisit if 16+ elsewhere `[STORE]`.

#### Behaviour

**Community guidelines** accepted before first room (Play UGC), versioned, re-shown on material change: be kind; no hate (incl. caste, religion, gender, sexuality); no sexual content; no contact details, meeting up, or asking anyone's age, school, city or photos; no selling; no encouraging self-harm (talking about how you feel is fine).

**Report reasons:** Unkind · Hate · Sexual · Asking for contact or to meet · **Targeting a young person** (minors lane) · Spam · Encourages self-harm · Threat · **I'm worried about this person** (crisis lane, not a violation) · **Might be under 13** (minors lane) · Other. Item hides for the reporter; outcome goes to their inbox.

**Mute** hides a pseudonym for that room. **Block** also keeps both accounts out of the same room or game for good (server-side). The blocked person isn't told.

**"I need help now"** on Home, room headers, Breath Ripples pause, note and capsule editors, Settings and the under-13 screen. Opens from bundled data: no login, network, paywall or spinner.

**Crisis detection.** **L0** help button. **L1 on-device lexicon** on notes, reflections and capsule text in **English, Telugu, Tenglish, Hindi and Hinglish**, incl. romanised forms ("marna chahti", "chachipovalani undi"): high-confidence phrase → full sheet; idiom ("mar gaye yaar", "navvi navvi chachipoya") → soft "Help is here" card; entries still save. **L2 OpenAI omni-moderation** on reflections; no LLM classifier. **L3 human** crisis lane. Private text is never sent for classification (DS-1); flagged reflections never publish; nobody is auto-contacted; crisis events aggregate only (DS-7).

**Safe messaging.** AK self-reviews crisis copy and lexicon against published safe-messaging guidelines (WHO, AFSP, Samaritans). **No clinical advisor**: a recorded duty-of-care risk, re-reviewed before EU/UK/AU open.

**Support sheet** (dismissible; region from device settings, never IP/GPS): **India** Tele-MANAS **14416 / 1-800-891-4416** and 112, plus Childline 1098 for under-18s `[ASSUMPTION: confirm operational]`; **US** 988; **elsewhere** "Call your local emergency number". No findahelpline.com data, no ThroughLine. Offline **60-second grounding**. **Disclaimer:** "Aura is not a medical device or an emergency service" (Play health policy, Apple 1.4.1).

**Reflection pipeline** (F6 owns author UX)
1. **On-device:** lexicon + PII/link regex (spaced or spelled digits, emails, URLs, @handles, UPI IDs, "insta/snap"). PII blocks sending.
2. **Server rules** (NestJS worker): re-run stage 1, rate limits, sanctions, and **grooming rules** in all five languages (asking age, school, city or photos; moving to other apps; secrecy; meeting up), since omni-moderation has no grooming category.
3. **OpenAI omni-moderation** (free): self-harm, sexual incl. minors, harassment, hate, violence, illicit.
4. **Human queue** (AK) for anything uncertain.

Publish only if 1–3 are clear; violation → gentle rejection; self-harm → crisis lane; uncertain → hold. **`involves_minor`** (under-18 author or room member) lowers sexual, harassment and PII thresholds; any grooming hit → minors lane. **Telugu, Tenglish and Hinglish run stricter** (omni-moderation doesn't claim Hinglish): expect more holds, tuned weekly in alpha `[ASSUMPTION]`. **Fail closed:** provider error or >5 s → hold. **p50 < 2 s**, p95 < 5 s. OpenAI gets text only; zero retention requested `[ASSUMPTION]`; cross-border processing disclosed `[LEGAL]`. **No Perspective API** (sunsets 31 Dec 2026).

**Training corpus.** Decisions feed a **de-identified** corpus (text, language, label; no user, room or pseudonym link), kept past the purge to train an in-house model (MuRIL / XLM-R). Privacy-notice disclosure plus Settings **opt-out**. Under-18 authors excluded `[ASSUMPTION]`; whether it is still personal data `[LEGAL]`.

**Strikes** (expire after 90 clean days `[ASSUMPTION]`): warning → **24 h shadow-mute** → **7-day room suspension** → **permanent social ban**. Threats or doxxing → instant ban. Crisis flags never count; help is never locked; one appeal per action, resolved in 7 days.

**Minors & grooming: zero tolerance.** Sexual content involving a minor, or confirmed grooming → **instant permanent ban** (stays during appeal), **evidence kept 180 days** in `evidence_holds` (overrides the purge), and **mandatory reporting**: POCSO (police or Special Juvenile Police Unit), IT Rules, NCMEC where US law applies `[LEGAL]`. During review, the account's reflections hold and it leaves its rooms.

**SLAs** (last four rows: IT Rules 2026)

| Item | Target |
|---|---|
| Crisis-flagged items | <15 min in Lantern Hour, <1 h otherwise |
| All reports | <24 h |
| Grievance acknowledge / resolve | 24 h / 7 days |
| Unlawful content | 36 h |
| Nudity, CSAM, NCII | 2 h |
| Court / government order | 3 h |

**AK is the only moderator until 5,000 DAU**, then hires.
- **24×7 paging** (push, then a call after 5 min): court or government orders (3 h), nudity / CSAM / NCII grievances (2 h), sexual content involving minors, crisis items unassigned 5 min.
- **Overnight, the rest waits:** held reflections stay unpublished (fail closed); ordinary reports wait for morning, inside 24 h.
- **Gaps:** hire earlier if overnight pages exceed 3 a week for a month `[ASSUMPTION]`. Nobody covers when AK is unreachable, so 2 h / 3 h clocks can be missed `[LEGAL]`; before planned absences AK turns on **hold-all** (every new reflection waits; gestures unaffected).

**Grievance Officer: AK.** Name, email, address and timelines in Settings → Help & Safety and on the website; ticketed form, auto-acknowledged.

**Mood data as health data.** No ad SDKs or data mining (Apple 5.1.3). Local DB and media excluded from iCloud and Android Auto Backup. Explicit consent under SPDI Rules until 13 May 2027 `[LEGAL]`; GDPR Art. 9 once EU/UK open. Play Health apps declaration filed.

#### Requirements

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-SAFE-01 | P0 | Help button on every listed surface. | Opens <500 ms in airplane mode or signed out. **Neg:** never behind paywall or login. |
| REQ-SAFE-02 | P0 | Region-aware support sheet. | IN → 14416, 1-800-891-4416, 112; US → 988; other → generic. **Neg:** no findahelpline.com data shipped. |
| REQ-SAFE-03 | P0 | On-device EN/TE/Tenglish/HI/Hinglish lexicon. | ≥90% recall on a 200-phrase set per language `[ASSUMPTION]`. **Neg:** no private text sent for classification. |
| REQ-SAFE-04 | P0 | Guidelines before first room. | Unaccepted current version → guidelines first. **Neg:** Back doesn't enter the room. |
| REQ-SAFE-05 | P0 | Report with reasons everywhere. | Item hides for reporter; lands in the right lane; outcome in inbox. |
| REQ-SAFE-06 | P0 | Mute and block. | Blocked pair never co-matched across 100 simulated matches. **Neg:** blocked user gets no signal. |
| REQ-SAFE-07 | P0 | Four-stage pipeline, fail closed. | p50 <2 s; provider timeout → held. **Neg:** "9 8 7 6 5 4 3 2 1 0", "insta: x" or "which school are you in?" never published. |
| REQ-SAFE-08 | P0 | Strikes, instant bans, appeals. | Every action has a reason code in the append-only log. **Neg:** crisis flag never creates a strike. |
| REQ-SAFE-10 | P0 | SLA timers, paging, hold-all. | Test government-order email pages AK within 5 min at 3 am; hold-all holds every new reflection within 60 s. |
| REQ-SAFE-11 | P0 | Grievance Officer published. | Visible in-app and on the website; ticket ID within 1 min. |
| REQ-SAFE-12 | P0 | Health-data handling and disclaimers. | No ad SDK in dependency audit; DB not in iCloud backup; disclaimer in onboarding, Settings, sheet, listings. |
| REQ-SAFE-13 | P0 | Stricter thresholds when an under-18 is involved. | Same borderline sexual text publishes in an all-adult room, holds in a room with an under-18. **Neg:** no user sees an age indicator. |
| REQ-SAFE-14 | P0 | Zero tolerance: minors' sexual content, grooming. | Confirmed → instant ban; `evidence_holds` row +180 days with report reference. **Neg:** evidence survives the purge job. |
| REQ-SAFE-15 | P0 | Safe-messaging self-review. | Every crisis string checked against the guideline checklist before alpha and on change. **Neg:** no string names a method. |
| REQ-SAFE-16 | P1 | De-identified corpus, notice, opt-out. | Rows carry no user, room or pseudonym ID. **Neg:** opted-out user's new items never enter it. |

#### Edge cases
- **Crisis text containing a phone number:** crisis wins.
- **Brigading:** items hide for everyone after 3 distinct reporters; new or sanctioned reporters weigh less. "Sexual" or "Targeting a young person" on content involving an under-18: 1 report hides `[ASSUMPTION]`.
- **Pipeline outage:** reflections hold, rooms say "Reflections are slower right now", gestures keep working.

#### Minors (13–17)
No user-facing difference except Childline 1098 on the India sheet. Invisible: stricter thresholds, one-report hide, minors lane above harassment and spam, analytics exclusion. No automatic parent alert `[LEGAL]`.

#### Post-v1
In-house classifier; Tamil and Bengali lexicons; licensed global helpline data; trusted-contact alert (P2); paid moderators from 5,000 DAU.

### F12 Monetization

**Priority:** P1, ships at Milestone B (open beta). Paywall exclusions are P0 once it ships.

**Purpose.** Earn small, fair revenue without selling anything that helps someone feel better. Everything sold is cosmetic or "more of" a free feature.

#### Behaviour

**Billing.** Apple IAP and Google Play Billing via Flutter **`in_app_purchase`**: StoreKit 2; **Play Billing Library v8** (required since 31 Aug 2026, extension to 1 Nov 2026) `[STORE: confirm the plugin bundles PBL 8]`. **No RevenueCat. No Razorpay or UPI direct checkout** (Apple 3.1.1, no India exception).

**Validation in NestJS** (DS-9). Apple: App Store Server API + **App Store Server Notifications V2**. Google: Play Developer API + **Real-time Developer Notifications** via Cloud Pub/Sub; acknowledge within 3 days (else auto-refunded). Purchases carry a `user_id`-derived token (`appAccountToken` / `obfuscatedAccountId`). **NestJS owns `entitlements`**; never granted from a client receipt alone. Notifications are logged, idempotent and reconciled daily.

**Catalogue** (India prices include GST, as the user pays)

| Product | Type | Price |
|---|---|---|
| Aura Plus monthly | Auto-renewing, UPI Autopay; **first month free** (introductory offer) | ₹49/month |
| Aura Plus annual | Same group; first month free | ₹399/year |
| Cosmetics | Non-consumable, restorable, also buyable with Stardust | ₹10 / ₹29 / ₹49 / ₹99 |
| Gifts | Consumable: Warm Tea / Comfort Lantern / Encouragement Bouquet | ₹10 / ₹29 / ₹49 |

**Abroad:** store-local tiers, e.g. **$4.99 / $39.99** `[STORE]`. Free-month eligibility is per store account (a second free month via another store is accepted leakage). **₹10 floor** (Play India minimum); verify Apple's India grid; join Apple's Small Business Program `[STORE]`. Gifts give the recipient 10 / 30 / 50 **Stardust** (never sold directly, cashed, transferred or expired).

**Everyone 13+** can buy everything; no age-based rules. Store controls (Ask to Buy, Family Link) apply as each store sets them.

**Gifts.** Checked **before** the store sheet: no block either way, sender unsanctioned, ≤5 per day. No message. Recipient sees "Someone here sent you a Comfort Lantern." Invisible: 3+ gifts in 7 days from one adult to under-18 recipients → minors-lane review `[ASSUMPTION]`.

**Refunds.** Apple refunds gifts only to the purchaser. Detected via App Store `REFUND` notifications and Play's Voided Purchases API (daily). Cosmetic refunded → removed. **Gift refunded → recipient keeps the Stardust**; never told; Aura absorbs ≤₹49. **Abuse:** 2 refunded gifts in 90 days pauses gifting 90 days; a 3rd disables it `[ASSUMPTION]`.

**Paywall never appears:** within 24 h of onboarding; in a crisis flow or the rest of that day; on Nebula wake-up; straight after a Storm or Rain check-in; as a gate on check-in, habits, rest days, rooms, Breath Ripples, date capsules or crisis support. Only on limit screens (4th mood-trigger capsule, long voice, Plus theme, deeper Insights) and Settings, max 1 unprompted per day, always with a free path. Shows "1 month free, then ₹49/month", trial end date, cancel steps, Restore and Terms (Apple 3.1.2); no countdowns.

**States.** **Pending** (UPI mandate, Ask to Buy): "You won't be charged until it's approved"; nothing granted until confirmed; pending gifts deliver into the room memory. **Failed:** "No charge. Nothing was sent." **Trial:** Plus on until the store converts or lapses it. **Grace periods** on `[STORE]`. **Lapse:** nothing made is lost; sealed Plus capsules still open. **Restore** in Settings; Plus follows the account across platforms. Family Sharing off `[ASSUMPTION]`.

**Tax.** AKVega is GST-registered; its **CA confirms** GST on store-billed sales, payout treatment and any TDS before monetization ships `[ASSUMPTION]`.

#### Unit-economics correction
Research-doc figures (₹480/yr ARPPU, ₹32–52 blended monthly ARPU) are gross; they ignore GST, store fees and the free month.

| ₹49 Aura Plus, one paid month | ₹ |
|---|---|
| User pays (GST-inclusive) | 49.00 |
| Ex-18% GST | 41.53 |
| Less 15% store fee | **≈ 35.30** |

Annual ₹399 nets ≈ ₹287 (≈ ₹24/month). The free month earns nothing; some trials won't convert. At 2–5% paid conversion, Plus earns ≈ **₹0.70–1.75 per MAU per month**, not ₹32–52. A ₹10 gift nets ≈ ₹7.20. **Google's new fees land globally by 30 Sep 2027**, launch day (10% subs; 20/25% other + 5% billing fee): cosmetics and gifts could cost 25–30% `[STORE]`; re-price before then.

#### Requirements

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-PAY-01 | P1 | Store billing via `in_app_purchase`, PBL v8. | **Neg:** static scan finds no RevenueCat or Razorpay SDK, UPI intent or external purchase link. |
| REQ-PAY-02 | P1 | Aura Plus monthly/annual, first month free. | New user sees "1 month free, then ₹49/month"; Plus on within 5 s of confirmation, both platforms. **Neg:** a store account that used the offer sees full price. |
| REQ-PAY-03 | P1 | Cosmetics ₹10–₹99. | **Neg:** no product below ₹10. |
| REQ-PAY-04 | P1 | Gifts for all 13+, pre-checked, no message. | Blocked recipient → gift icon hidden; 6th gift in a day refused pre-sheet. **Neg:** recipient never sees the sender's pseudonym. |
| REQ-PAY-05 | P1 | Refund handling. | Refunded gift: recipient balance unchanged, sender refund count +1. |
| REQ-PAY-06 | P0 | Paywall exclusions. | UI tests: no paywall on install day, after a crisis sheet, on Nebula wake-up, or on any never-sold feature. |
| REQ-PAY-07 | P1 | Pending purchases. | Pending UPI mandate → no entitlement; on approval, granted even if app was killed. |
| REQ-PAY-08 | P1 | Grace, lapse, restore. | Lapsed user's sealed Plus capsule still opens; Restore recovers Plus on a new device. |
| REQ-PAY-10 | P1 | NestJS validation and entitlements. | Sandbox notifications update `entitlements` within 60 s; duplicates grant nothing; reconciliation repairs a dropped notification. **Neg:** a forged or client-only receipt grants nothing. |

#### Edge cases
- **Bought on iOS, now on Android:** Plus stays on; "Manage" points to the App Store.

#### Minors (13–17)
Same as adults. Invisible: the gift-pattern review.

#### Post-v1
Google User Choice Billing (India, −4 pts), revisited after launch; Family Sharing; rewarded ads for adults only (P2).
