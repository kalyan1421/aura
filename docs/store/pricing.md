# Pricing and Google Play's new fees (re-price before 30 Sep 2027)

**For:** PRD 20-timeline weeks 43–48, "re-price for Google's new fees (global by 30 Sep 2027)". F12 unit-economics note.
**Drafted** 25 Sep 2026. Fee facts come from Google's own pages, checked on that date (sources in §5). Where the pages I could read were ambiguous, the item is marked `[VERIFY]`. **Recheck the Play Console "Service fees" page before deciding.**

## 1. Current catalogue (India, GST-inclusive, as users pay)

Source: `server/aura-api/src/billing/catalogue.ts` (product ids are the same in both stores; the app always shows the store's localized price string) and PRD F12.

| Product id | What | Type | India price |
|---|---|---|---|
| `aura_plus_monthly` | Aura Plus, monthly. Google offer `first-month-free`; Apple introductory offer | Auto-renewing subscription | **₹49 / month** |
| `aura_plus_annual` | Aura Plus, yearly, same free first month | Auto-renewing subscription | **₹399 / year** |
| `gift_warm_tea` | Gift: Warm Tea. Recipient gets 10 Stardust | Consumable | ₹10 |
| `gift_comfort_lantern` | Gift: Comfort Lantern. 30 Stardust | Consumable | ₹29 |
| `gift_encouragement_bouquet` | Gift: Encouragement Bouquet. 50 Stardust | Consumable | ₹49 |
| `sky_first_light` | Sky theme First Light (or 10 Stardust) | Non-consumable | ₹10 |
| `sky_lantern_festival` | Sky theme Lantern Festival (or 30 Stardust) | Non-consumable | ₹29 |
| `sky_deep_ocean` | Sky theme Deep Ocean (or 50 Stardust) | Non-consumable | ₹49 |
| `sky_meteor_shower` | Sky theme Meteor Shower (or 100 Stardust) | Non-consumable | ₹99 |

The free skies (`night`) and the Plus skies (`aurora`, `monsoon_dusk`) have no product. Abroad the PRD uses store-local tiers, for example $4.99 / $39.99 for Plus `[STORE]`. The ₹10 floor is Play India's minimum (REQ-PAY-03, which the catalogue test guards).

## 2. What changes on Google Play

Google announced a new Play fee structure in 2026, rolling out by region. This is from Google's Play Console Help ("Understanding Google Play's lower service fees", "Service fees") and the Android Developers Blog:

| | Before (India today) | New structure |
|---|---|---|
| **When** | — | US, UK, EEA: 30 Jun 2026. Australia (and Japan): 30 Sep 2026. South Korea: 31 Dec 2026. **Rest of world, including India: by 30 Sep 2027**, which is Aura's launch day. |
| **Auto-renewing subscriptions** (Aura Plus) | 15% | **10% service fee + the Google Play billing fee** |
| **One-time products** (gifts, skies) | 15% on the first $1M of yearly earnings (with the 15% programme), 30% above | Depends on **new vs existing installs**: roughly **20% (new installs) / 25% (existing installs) + the billing fee**, lower (15% / 20%) for developers in the Apps Experience / Games Level Up programmes. Google also keeps a low first-$1M tier. `[VERIFY]` The pages I read summarised the $1M tier differently: one reading is a flat 10% on all transaction types up to $1M, another has tiered rates. Read the exact table in Play Console. |
| **Billing fee** (Play Billing used) | — (inside the 15%) | **5% in US/UK/EEA.** The amount for India and the rest of the world was **not published** on the pages checked `[VERIFY]`. It doesn't apply to alternative billing or external links. |
| **"Existing install"** | — | An install made before the region's rollout date. In India, **every beta install from May 2027 would be an "existing install"** and would pay the higher one-time rate for the life of that install `[VERIFY the definition for RoW]`. |

**Apple doesn't change.** It is 15% under the Small Business Program, which AK should join (PRD F12 `[STORE]`), and 15% on subscriptions after the first year.

## 3. What it does to Aura's net per sale (Play, India)

Method from PRD F12: net = price ÷ 1.18 (18% GST, per the PRD `[ASSUMPTION: CA confirms]`) × (1 − store fee). Rounded to the nearest paisa.

| Product | Price | Ex-GST | Today (15%) | New: 10% | New: 15% (e.g. 10% + 5% billing, or programme rate) | New: 25% (20% + 5%) | New: 30% (25% + 5%, existing installs) |
|---|---|---|---|---|---|---|---|
| Plus monthly | ₹49 | ₹41.53 | **₹35.30** | ₹37.37 | ₹35.30 | — | — |
| Plus annual | ₹399 | ₹338.14 | **₹287.42** | ₹304.32 | ₹287.42 | — | — |
| Gift / sky | ₹10 | ₹8.47 | **₹7.20** | ₹7.63 | ₹7.20 | ₹6.36 | ₹5.93 |
| Gift / sky | ₹29 | ₹24.58 | **₹20.89** | ₹22.12 | ₹20.89 | ₹18.43 | ₹17.20 |
| Gift / sky | ₹49 | ₹41.53 | **₹35.30** | ₹37.37 | ₹35.30 | ₹31.14 | ₹29.07 |
| Sky | ₹99 | ₹83.90 | **₹71.31** | ₹75.51 | ₹71.31 | ₹62.92 | ₹58.73 |

**Reading it:**
- **Plus (most of the revenue) is unchanged or slightly better.** Subscriptions go to 10% plus a billing fee. If the Indian billing fee is 5% or less, the total is at most today's 15%. **No reason to re-price Plus.**
- **Gifts and skies are the exposure.** For installs past the first-$1M tier (if the flat 10% doesn't apply to Aura), or for existing installs, the fee rises from 15% to about 25–30%, which cuts net by 12–18%. At Aura's scale, total revenue stays far below $1M a year for a long time, so **the first-$1M tier decides almost everything** `[VERIFY]`.
- The PRD's warning ("cosmetics and gifts could cost 25–30%") still holds as the worst case.

## 4. Decisions for AK (weeks 43–48, before 30 Sep 2027)

1. **Confirm the Indian numbers** in Play Console once Google publishes them (usually some weeks before the regional date): the billing fee for India, the first-$1M treatment of one-time products, and whether "existing install" is set by India's rollout date. Update §3 with the real rates.
2. **Enrol** in whichever programme lowers the one-time rate: Apps Experience (Aura is not a game), and the 15% / first-$1M tier if it still needs opting in. Read the eligibility and obligations first.
3. **Plus:** keep ₹49 / ₹399 on both stores. Price parity across stores keeps "Plus follows your account" simple (F12). Recommended.
4. **Gifts and skies:** choose one of these.
   - (a) **Keep ₹10 / ₹29 / ₹49 / ₹99** and accept about ₹1 less per ₹10 sale. Recommended if the $1M tier applies. Gifts are lever 1 in the scope cuts anyway.
   - (b) Raise the **Play-only** gift floor to ₹19. That breaks price parity and the "₹10–₹99 price points" story (PRD 01).
   - (c) Move the low tiers to Stardust only. That changes F12 (Stardust is never sold directly), so it's not recommended.
5. **Alternative billing / external links:** these avoid the billing fee, but PRD 22 puts them out of scope for v1 (Q20; Apple 3.1.1 has no India exception). Revisit after launch together with Google User Choice Billing.
6. **Existing installs from the beta:** if they carry a higher one-time rate for good, consider timing a re-install nudge. That is **not recommended**: it adds friction for a few rupees. Accept the cost.
7. **CA review:** GST treatment of store-billed sales and payouts (PRD F12 `[ASSUMPTION]`), and whether Google's billing fee is itself GST-able.
8. **Apple:** join the Small Business Program (15%). Check Apple's India price grid for ₹10, ₹29, ₹49, ₹99, ₹399 `[STORE]`.
9. **Update:** `server/aura-api/src/billing/catalogue.ts` holds the INR tiers only as documentation and a guard. A price change happens in the two consoles, and then in that file's `inr` fields and this note. The app needs no change, because it shows store price strings.

## 5. Sources (checked 25 Sep 2026)

- Google Play Console Help, "Understanding Google Play's lower service fees": https://support.google.com/googleplay/android-developer/answer/16954621
- Google Play Console Help, "Service fees": https://support.google.com/googleplay/android-developer/answer/112622
- Android Developers Blog, "Expanded billing choice and lower fees on Google Play" (Jun 2026): https://android-developers.googleblog.com/2026/06/play-expanded-billing.html
- Android Developers Blog, "A new era for choice and openness" (Mar 2026): https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html
