# Aura — Store, Regulatory & Platform Fact Check (verified 23 Sep 2026)

Web-verified against primary sources where possible. Confidence in brackets.

## Contradictions with the original research plan
1. **Apple 1.2 names "Chatroulette-style experiences, random or anonymous chat" as removable without notice.** Mood rooms must read as structured, moderated, gesture-first: filtered text, report/block, published contact. Biggest store risk. [High]
2. **₹9 price point not possible on Google Play** (India minimum ₹10). Apple may allow ₹9 (unverified). Use **₹10 floor** on both. [Medium]
3. **Under-18s:** DPDP bans tracking, behavioural monitoring and targeted ads to children; verifiable parental consent required. Rewarded-ads plan conflicts for minors. [High]
4. **Supabase Pro with spend cap is too small** (500 concurrent, 50 Presence msgs/s). Plan spend cap off. [High]
5. **Perspective API shuts down 31 Dec 2026.** Do not use. [High]
6. **Google Play fees change mid-roadmap**: new structure global by 30 Sep 2027. [High]

## Apple
- **1.2 UGC**: must have filtering, reporting + timely response, blocking, published contact info. "Chatroulette-style experiences, random or anonymous chat" → removal risk. 1.2.1(a)/4.7.5: age-restrict by verified or declared age. https://developer.apple.com/app-store/review/guidelines/ [High]
- **Health**: 1.4.1 greater scrutiny for medical apps, remind users to consult a doctor. **5.1.1(ix)**: apps in regulated fields (healthcare) should be submitted by a legal entity, not an individual. **5.1.3**: health data not for ads/data mining; not stored in iCloud. [High]
- **Age ratings** (new tiers 4+/9+/13+/16+/18+, announced 24 Jul 2025; questionnaire deadline 31 Jan 2026): Health/Wellness topics ≥ 9+; frequent medical info 16+; social media features 13+ (16+ Australia). **Declared Age Range API** (iOS 26+) returns <13 / 13–15 / 16–17 / 18+. https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/ [High]
- **3.1.1**: digital goods and gifts must use IAP; gifts refundable only to purchaser. No India exception (external links only on the US storefront; CCI case vs Apple pending). India payment methods include **UPI and UPI Autopay** for subscriptions. https://support.apple.com/en-in/111741 [High]. Lowest India price reportedly ₹9 (= $0.29 global min) — verify in App Store Connect. [Medium-low]

## Google Play
- **Play Billing** required for digital goods. **User Choice Billing in India**: fee −4 pts. Current fees (non-US/UK/EEA): 15% on first $1M, 30% above; subs 15%. Epic settlement (approved 4 Mar 2026): 10% subs, 20/25% other + 5% billing fee — US/UK/EEA from 30 Jun 2026, **global by 30 Sep 2027**. Billing Library **v8 required** for new apps/updates from 31 Aug 2026 (extension to 1 Nov 2026). https://support.google.com/googleplay/android-developer/answer/112622 [High]
- **UPI and UPI Autopay subscriptions** supported since Nov 2022. India minimum price **₹10**. [High / Medium]
- **Health apps declaration form** mandatory for all apps; "not a medical device" disclaimer; no misleading claims; privacy policy in Console and in-app. https://support.google.com/googleplay/android-developer/answer/16679511 [High]
- **UGC policy**: users accept terms before posting; ongoing moderation; in-app reporting; blocking for 1:1 interactions; timely action. https://support.google.com/googleplay/android-developer/answer/9876937 [High]
- **Play Age Signals API**: beta, optional; Texas accounts (after 28 May 2026), Brazil (since 17 Mar 2026); global later in 2026. [High]

## US state app-store age laws (relevant only if US storefront is enabled)
- **Texas SB 2420 in force since 4 Jun 2026** (new TX accounts): developers must use Declared Age Range + PermissionKit Significant Change API; parents consent to downloads, IAPs and significant changes, and can revoke. [High]
- **Utah**: delayed to 6 May 2027 (private action only). **Louisiana**: delayed to 1 Jul 2027; developers may rely on store signals/consent. [High]

## India
- **DPDP Rules** notified 13/14 Nov 2025. Consent managers from 13 Nov 2026. **Main obligations from 13 May 2027.** (12-month acceleration proposal not notified.) [High]
- **Children (<18)**: verifiable parental consent (Rule 10) via reliable details already held, details voluntarily provided, or **DigiLocker virtual token**. No tracking, behavioural monitoring or targeted ads directed at children. Penalty up to ₹200 crore. Exemptions cover mental-health establishments / healthcare professionals for care delivery — a wellness app likely does **not** qualify. [High]
- **Health data**: no special category under DPDP. Legacy **SPDI Rules** (mental health = sensitive personal data) apply until 13 May 2027. [Medium-high]
- **IT Rules (amended 20 Feb 2026)**: Grievance Officer required; grievances resolved in **7 days** (was 15); unlawful-content grievances **36 h**; nudity/CSAM **2 h**; court/government takedown orders **3 h**; NCII **2 h**. Significant social media intermediary threshold: 50 lakh registered users. [High]

## Crisis resources
- **Tele-MANAS: 14416 or 1-800-891-4416**, 24×7, 20+ languages. [High]
- **US 988** (call/text/chat). [High]
- findahelpline.com: personal use only (no commercial use). **ThroughLine API**: 1,500+ helplines in 170+ countries; free sandbox US/NZ only; production needs a paid licence. [High]

## Supabase Realtime (Pro, $25/mo)
Spend cap ON: 500 concurrent connections, 500 msgs/s, **50 Presence msgs/s**. Spend cap OFF: 10,000 concurrent, 2,500 msgs/s, 1,000 Presence msgs/s. 5M msgs included then $2.50/M (**a broadcast counts as 1 + number of subscribers**); 500 peak connections included then $10 per 1,000. https://supabase.com/docs/guides/realtime/limits [High]

## Moderation (Hindi / Hinglish)
- **OpenAI omni-moderation**: free; has self-harm intent/instruction categories; 40 languages with big Indic gains; Hinglish not stated. [High / Medium]
- **Perspective API**: sunset, ends 31 Dec 2026, no new signups. [High]
- **Llama Guard 4**: open weights; Hindi official; Hinglish not stated. [High]
- **Azure Content Safety**: Hindi works but not a trained language. [High]
- **No production Hinglish moderation API found.** Sarvam/Bhashini offer LLMs/translation, not moderation. Plan to fine-tune MuRIL / XLM-R on Aura's own labelled data. [Medium]

## Competitors (2025–26)
- **Finch**: bootstrapped, est. $30–40M ARR (~$2.9M/mo). Tree Town = friend-code friends only; no strangers. [Medium]
- **How We Feel**: free nonprofit; friend sharing + comments (Feb 2025). [High]
- **Voidpet Garden**: emotion monsters, a16z, minimal social. [High]
- **Kind Words 2** (Steam, Oct 2024): anonymous kind letters to strangers — closest analogue to Aura's stranger mechanic. [High]
- **Amaha** (India): 6M+ users, 50k+ moderated peer community, therapy. [High]
- **Evolve** (India): LGBTQ+ self-care, ~600k users. [Medium]
- **Level SuperMind** (India): meditation, reportedly rebranded Swa:aha, ~1M users. [Medium-low]
- **MindPeers** (India): therapy + B2B, <₹10 Cr revenue FY25. [Medium]
- **New entrants**: **YourSecret** (Mar 2026, anonymous chat for US college students matched by emotional state — most direct overlap with mood rooms) [Medium]; Manifest ($3.4M, voice-note wellness); Momo ($2.5M, AI habit companion). [Medium]

## Flutter packages
- **home_widget 0.10.0** (Sep 2026, breaking changes): interactive widgets on iOS 17+ (AppIntents) and Android (Glance ActionCallback); SPM support from 0.9.0; **widget UI must be native** (SwiftUI / Kotlin). [High]
- **rive 0.14.11** stable, built on **rive_native** (C++ runtime; requires `RiveNative.init()`); 0.13.20 was the last pure-Dart version. **0.15.0-dev** has breaking data-binding changes and native-only deferred rendering; `package:rive/legacy.dart` bridge; min Flutter 3.32 / Dart 3.8. [High]
