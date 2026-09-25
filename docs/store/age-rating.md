# Age rating: draft questionnaire answers (Apple and Google Play / IARC)

**For:** PRD 20-timeline weeks 43–48, "final age rating". Week 0 also has the "Apple age-rating questionnaire dry-run" item.
**Drafted** 25 Sep 2026 from the code on `fix/design-audit` after `c521ceb`. **Not final.** AK answers the real questionnaires in App Store Connect and Play Console, and the lawyer confirms the `[LEGAL]` items. Store outcomes are computed by Apple and IARC, so nothing here is a guaranteed result.

## 1. What the rating is based on (facts from the build)

| Feature | What a user can see or do | Where |
|---|---|---|
| **Accounts** | Everyone 13 and over gets the full app. Under-13s are blocked by a neutral DOB gate, with a 30-day device lock and no account created. Store age signals are read where available, but only to block under-13s. There are no parental controls and no parental consent (D2). | F8; `features/onboarding/`, `features/auth/age_signals.dart` |
| **User-generated content** | Room **reflections**: ≤ 200 characters, at most 3 per room per day. They are visible to people in the same 24-hour mood room under a fresh pseudonym, and only after on-device lexicon, server rules, OpenAI omni-moderation and (when uncertain) human review. Content from or near under-18 accounts gets stricter thresholds, and the pipeline fails closed. Private notes, voice notes, capsules and photos are **never** visible to anyone else. | F6/F9; `server/aura-api/src/reflections/` |
| **Interaction with strangers** | Mixed-age rooms (≤ 24 people) and Breath Ripples (2–4 seats) with **8 preset gestures** only. Quiet Together shows a count, a shared sound and unnamed gestures. There are **no DMs, replies, threads, profiles, photos, links, handles, voice or video**. Report, mute and block are everywhere, and blocked pairs are never matched. | F5/F7/F16 |
| **Gifts** | Consumable gifts (Warm Tea, Comfort Lantern, Encouragement Bouquet) to a pseudonymous room member, with no message. The recipient never sees the sender. | F12; `server/aura-api/src/billing/gifts.ts` |
| **Crisis content** | "I need help now" on every main screen opens helplines (Tele-MANAS, 988, local emergency) and grounding. The crisis lexicon covers self-harm phrases in 5 languages. Copy follows safe-messaging guidelines and never names a method. | F9 |
| **Health and wellness** | Mood check-ins, a breathing pacer, grounding and sounds. It states "not a medical device or an emergency service" and makes no treatment claims. | F1/F15; `apps/mobile/store/` lint |
| **Purchases** | Aura Plus subscription, sky cosmetics and gifts. No loot boxes and no randomised rewards (gifts are fixed items). | F12 |
| **Ads / web** | No ads, no WebView, no open web browsing. | MASVS PLATFORM-2 |

## 2. Apple App Store: updated age-rating questionnaire (tiers 4+ / 9+ / 13+ / 16+ / 18+)

Apple's current questionnaire (the updated questions were required from 31 Jan 2026) has sections for in-app controls, capabilities, mature themes, medical or wellness, sexuality or nudity, violence and chance-based activities. Apple computes the rating from the answers, and the developer may **raise** it but not lower it.

| Section | Question | Draft answer | Why | Confidence |
|---|---|---|---|---|
| In-app controls | Parental Controls | **No** | None exist (D2) | High |
| In-app controls | Age Assurance | **Yes** `[VERIFY definition]` | Declared DOB gate, plus Apple Declared Age Range where eligible (iOS 26.2+, `AppDelegate.swift` `AuraAgeSignalsChannel`), used to block under-13s. If Apple means *verified* age assurance only, answer No. | Medium |
| Capabilities | Unrestricted Web Access | **No** | No browser or WebView. External links go to fixed legal and support pages only. | High |
| Capabilities | User-Generated Content | **Yes** | Room reflections | High |
| Capabilities | Social Media | **Yes** (conservative) | Rooms, gestures and reflections between people. Answering No would understate it, and App Review sees the rooms anyway. | Medium |
| Capabilities | Social Media Disabled for Users Under 13 | **Yes** | Under-13s can't create an account at all | High |
| Capabilities | Messaging and Chat | **No** `[VERIFY with AK]` | No person-to-person messages, replies or threads. Reflections are pre-moderated one-to-room posts, and gestures are presets. This is the most contestable answer. Answering **Yes** is defensible and doesn't raise the computed rating on its own, but it reinforces the Apple 1.2 "anonymous chat" reading we argue against (F9 positioning). **Pick the answer that matches the review notes.** | Medium |
| Capabilities | Advertising | **No** | No ads | High |
| Mature themes | Profanity or Crude Humor | **Infrequent** | Reflections can contain mild language. Moderation targets harassment, hate and sexual content, not all profanity. | Medium |
| Mature themes | Horror/Fear Themes | **None** | | High |
| Mature themes | Alcohol, Tobacco, or Drug Use or References | **None** | Moderated ("illicit" category). Aura's own copy never references them. | Medium |
| Medical or wellness | Medical or Treatment Information | **Infrequent** | Helpline information (Tele-MANAS is a mental-health helpline) in the Safety Center. There is no treatment content. **Frequent** would force 16+. | Medium |
| Medical or wellness | Health or Wellness Topics | **Yes** | Mood check-ins, breathing, grounding | High |
| Sexuality or nudity | Mature or Suggestive Themes | **None** `[VERIFY]` | Crisis support touches self-harm as a topic (no methods, safe-messaging reviewed). If Apple counts that as a mature theme, answer **Infrequent**, which still doesn't reach 16+ (only **Frequent** does). | Medium |
| Sexuality or nudity | Sexual Content or Nudity; Graphic Sexual Content and Nudity | **None** | No images between users. Sexual text is blocked, with zero tolerance for anything involving minors. | High |
| Violence | Cartoon/Fantasy, Realistic, Prolonged Graphic, Guns or Weapons | **None** | | High |
| Chance-based | Gambling; Simulated Gambling; Contests; Loot Boxes | **No / None / None / No** | Gifts and cosmetics are fixed, known items | High |

**Expected computed rating: 13+.** It is driven by Social Media = Yes, Medical or Treatment Information = Infrequent and Profanity = Infrequent. With these answers, nothing reaches the 16+ triggers (Unrestricted Web Access, Frequent medical information, Frequent mature or suggestive themes) or the 18+ triggers. This matches the PRD target ("Target 13+"; F9 "Expected rating 13+").

**What would move it:**
- **16+**: answering Frequent to Medical or Treatment Information, or to Mature/Suggestive Themes. Apple could also push for it in review because of mixed-age stranger rooms (PRD 09 `[STORE]`). The developer can always *raise* the rating voluntarily. That is AK's lever if App Review insists, but it contradicts D2's 13+ audience.
- **Australia:** the PRD expects 16+ there because of the under-16 social media law, which is a legal floor rather than an Apple rating. Keep AU closed until the assessment is done (REQ-ACC-14) `[LEGAL]`.

## 3. Google Play: content rating (IARC) and target audience

**IARC questionnaire:** Play Console → App content → Content rating. It produces ESRB, PEGI, USK, ClassInd, ACB, GRAC and the generic IARC ratings.

| IARC item | Draft answer | Why |
|---|---|---|
| Category | **"Social networking, forums, blogs and user-generated content"** `[VERIFY]` (the alternative is "All other app types") | Rooms and reflections are UGC shared between users. Picking the social/UGC category is the honest choice and adds the "Users Interact" descriptor. |
| Violence, blood, sexuality, nudity | **No** | As in §1 |
| Offensive language | **No** for Aura's own content. Answer UGC-related questions as "users can post text that is moderated" | IARC rates the app's own content, and UGC is disclosed through interactive elements |
| Controlled substances, gambling, simulated gambling | **No** | |
| Crude humour, fear, discrimination | **No** | Hate is moderated and against the guidelines |
| Does the app contain references to suicide or self-harm? | If asked: **Yes, in a supportive or helpline context only** `[VERIFY question wording]` | Crisis support (F9). Answer honestly; it may add a descriptor or raise some regional ratings. |
| Interactive elements | **Users Interact: Yes. Shares Info: No. Shares Location: No. Digital Purchases: Yes. Unrestricted Internet: No.** | Room gestures and reflections; no location; IAP |

**Expected outcome (not guaranteed):** around **ESRB Teen / PEGI 12 / IARC 12+**, with the "Users Interact" and "In-App Purchases" descriptors. The suicide/self-harm answer is the most likely reason for a higher regional rating `[VERIFY]` once the questionnaire has been run.

**Target audience and content** (Play Console → App content → Target audience):
- **Age groups: 13–15, 16–17 and 18+.** Do **not** select under-13 groups. Aura is not for children, so the Families policy and "Designed for Families" don't apply.
- "Could the app unintentionally appeal to children?" → **No**. Base the answer on the actual art and copy (celestial avatar, calm tone, no cartoon mascots aimed at kids) `[VERIFY with the store listing assets]`.
- **Because 13–17 is selected,** Play expects appropriate content for teens and no ads to minors (there are none), and it scrutinises UGC and social features. The requirements from Play's UGC policy are all in place: terms and guidelines accepted before posting (REQ-SAFE-04), in-app reporting, blocking, and ongoing moderation.
- **Play Age Signals** are read, but only to block under-13s (F8 REQ-ACC-04). Any Play requirement to act on signals for 13–17 in specific US states (Texas SB 2420, and Utah and Louisiana in 2027) is **not implemented (D2)**. That is legal risk R2 `[LEGAL]`.

## 4. Risks (PRD `[LEGAL]` / `[STORE]` items)

| # | Risk | Where from | Effect on the rating or review |
|---|---|---|---|
| R1 | No verifiable parental consent for Indian under-18s (DPDP Rule 10, from 13 May 2027) | PRD 09 risk register | This isn't a rating input, but Play's teen audience declaration and the privacy policy must be consistent with whatever the lawyer advises |
| R2 | US state app-store laws (Texas in force; Utah 6 May 2027; Louisiana 1 Jul 2027): age signals and parental consent for minors | PRD 09 | Stores may enforce age-range APIs for those states. The fallback is excluding the states or adding Declared Age Range and PermissionKit for them only |
| R4 | Mixed-age stranger rooms | PRD 09 | The main reason App Review might push for 16+ or reject under 1.2.1(a) |
| R5 | Apple 1.2 "random or anonymous chat" and 1.2.1(a) age restriction by declared age | PRD 09, F9 | The "Messaging and Chat" answer and the review notes must tell the same story: gesture-first, no chat, pre-moderated reflections, report and block, and a demo recording |
| R6 | Crisis copy not clinically reviewed | PRD 09 | Affects the self-harm questions (IARC) and Apple's medical and mature-themes answers |
| — | Australia under-16 law | F8/F9 | A 16+ floor in AU, or AU stays closed |

## 5. What AK and the lawyer must confirm

1. **Messaging and Chat (Apple):** Yes or No. Make it consistent with the App Review notes and the listing, which never says "chat".
2. **Age Assurance (Apple):** does a declared DOB plus Declared Age Range count?
3. **Medical or Treatment Information:** Infrequent (helplines), or None? Don't answer Frequent.
4. **IARC category** (social/UGC vs all other) and the wording of the self-harm answer.
5. **Play target audience 13–17** is consistent with the lawyer's DPDP / R1 advice and with the privacy policy `[LEGAL]`.
6. **Accept 13+ vs voluntarily raise to 16+.** A voluntary raise to 16+ would conflict with D2 and exclude the 13–15 JEE/NEET persona (Meera). That decision is AK's, with the lawyer.
7. **Regions:** keep EU, UK and AU closed until REQ-ACC-14 is done. The rating doesn't change that.
8. Run the **dry-run** (PRD week 0 / weeks 43–48) in both consoles with these answers, record the computed ratings here, and attach the demo account, seeded room and 60-second moderation recording to the App Review notes (F9).
