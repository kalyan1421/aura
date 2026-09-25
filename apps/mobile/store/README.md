# Aura store listings (ASO, 5 languages)

Fastlane-style metadata for the App Store (`deliver`) and Google Play (`supply`). PRD 20-timeline weeks 37–42: "ASO + listings in 5 languages". Drafted 25 Sep 2026 for Milestone C (public launch, Thu 30 Sep 2027).

**Status:** English is ready for AK's review. Telugu, Hindi, Tenglish and Hinglish are **drafts that need native review** before upload (`status.json`). The lint (`apps/mobile/test/store_listing_lint_test.dart`) runs with `flutter test`.

## Layout

| Path | Store locale | Upload | Status |
|---|---|---|---|
| `ios/en-GB/` | English (U.K.): the India storefront's default English | `deliver` | ready for AK review |
| `ios/en-US/` | English (U.S.). Byte-identical mirror of `en-GB` (lint-checked) | `deliver` | ready for AK review |
| `ios/te/` | Telugu (App Store Connect added it on 31 Mar 2026) | `deliver` | draft, native review |
| `ios/hi/` | Hindi | `deliver` | draft, native review |
| `android/en-US/` | English (United States): Play's default listing | `supply` | ready for AK review |
| `android/en-IN/` | English (India). Byte-identical mirror of `en-US` | `supply` | ready for AK review |
| `android/te-IN/` | Telugu | `supply` | draft, native review |
| `android/hi-IN/` | Hindi | `supply` | draft, native review |
| `extras/te-Latn/` | Tenglish: **no store locale exists** | not uploadable | draft, native review |
| `extras/hi-Latn/` | Hinglish: **no store locale exists** | not uploadable | draft, native review |

Files per locale:
- iOS: `name`, `subtitle`, `promotional_text`, `description`, `keywords`, `release_notes`.
- Play: `title`, `short_description`, `full_description`.
- Extras: `keywords`, `promotional_text`, `screenshot_captions`, `disclaimer`.

**Tenglish and Hinglish.** Neither store has a romanized Telugu or Hindi locale. Both stores list Telugu and Hindi only in native script. Romanized terms are used in three places instead:
1. As search terms in the native-script keyword fields: `ios/te/keywords` carries `tenglish,manasu,bhaavalu`, and `ios/hi/keywords` carries `hinglish,mood diary,mann,bhavnayein`. `ios/en-GB/keywords` carries `telugu,tenglish,hinglish`.
2. In India screenshot captions (`extras/*/screenshot_captions.txt`, one caption per line, 40 characters or fewer).
3. In creator and social copy (`extras/*/promotional_text.txt`).

This matches PRD 18-localization ("Tenglish and Hinglish … in India screenshots, ASO keywords and creator assets").

## Store limits (verified 25 Sep 2026)

| Field | Limit | Source |
|---|---|---|
| App Store name | 30 characters | App Store Connect, "App information" |
| App Store subtitle | 30 characters | same |
| App Store promotional text | 170 characters; can change without a new build | "Platform version information" |
| App Store description | 4,000 characters | same |
| App Store keywords | 100 characters, comma-separated. **Linted as 100 UTF-8 bytes**, because a Telugu or Devanagari character is 3 bytes and the byte reading is the safe one `[VERIFY in ASC]` | same |
| App Store "What's New" | 4,000 characters | same |
| Play title | 30 characters | Play Console, "Main store listing" |
| Play short description | 80 characters | same |
| Play full description | 4,000 characters | same |

**How characters are counted.** Lengths are UTF-16 code units, which is how both consoles count. In Telugu and Devanagari every vowel sign and virama counts as its own character, so a Telugu string is longer than it looks. `listing_rules.json` holds the limits, and the test reads them from there.

**Locales.** App Store Connect has no English (India). India's default is English (U.K.), and Telugu and Hindi were added as metadata locales on 31 Mar 2026. Play has `en-IN`, `te-IN` and `hi-IN`.

## What the lint enforces (`listing_rules.json`)

- **Limits** as above. Keywords must also have no spaces around commas and no duplicate terms.
- **Banned words.** The lint checks Latin script as whole words, and Telugu and Devanagari as substrings. Three groups are banned:
  - Health and treatment claims (therapy, cure, heal, treat, anxiety, depression, sleep, relief, mental health, clinical, doctor and similar). Sources: PRD 06d "calm, not treatment", REQ-SAN-12, Apple 1.4.1, the Play health policy, and the Mental Healthcare Act / ASCI.
  - App Review positioning words: chat, anonymous, stranger(s), dating (F9 "App Review positioning").
  - Out-of-scope promises: AI, meditation, binaural or frequency claims (PRD 22).
- **Disclaimer.** Every description and full description must contain the locale's "Aura is not a medical device or an emergency service" line (F9, REQ-SAFE-12). That line is the only place the word "medical" may appear.
- **Name and title.** No ranking, price or promotion words (free, best, #1, new…). The brand stays in Latin script.
- **Cross-store mentions.** App Store copy never names Android or Google Play, and Play copy never names Apple, iPhone or the App Store.
- **Clean text.** No placeholders (TODO, `{{`) and no emoji.
- **Mirrors.** The mirrored English locales must stay identical.
- **Coverage.** Every locale folder needs a `status.json` entry, and all 5 languages must be covered.

## Copy rules the lint can't check (reviewers: read these)

- **Say what it is, never what it achieves.** Write "breathe with the orb", not "feel calmer". The copy says "quiet company", "gestures" and "mood rooms", never "talk to", "connect with strangers" or "support group".
- **Don't promise anything out of scope.** That covers DMs, friends or followers, AI, therapy, guided meditation, sleep stories, and Hindi/Hinglish *rooms*. The Hindi/Hinglish UI is translated, but the rooms open only when moderation is ready (PRD 18). The listings promise the **app** in Hindi, never Hindi rooms.
- **Use gender-neutral forms.** Telugu uses the respectful *meeru*. Hindi uses *aap* forms, with nouns rather than gendered verbs where possible.
- **Brand terms stay in Latin:** Aura, Aura Plus, Lantern Hour, Breath Ripples, Starlight, Stardust. Quiet Together is "साथ में शांति" in Hindi, matching the app's ARB.
- **Screenshots** show avatars, gestures and the Sanctuary, never a text feed (PRD 05 user journey).

## Before the first upload (AK)

1. **App name availability.** "Aura: Daily Mood Check-in" (and the te/hi names) must be free on both stores, since App Store names are unique. If it's taken, change `name.txt`/`title.txt` in every locale and re-run the lint.
2. **Hindi.** The Hindi and Hinglish UI is gated by `AURA_BETA_LOCALES` (`lib/src/core/env/env.dart`) until the hi/hi-Latn crisis lexicon is reviewed. **Don't publish `ios/hi` or `android/hi-IN`**, and don't keep "हिन्दी and Hinglish" in the language line, unless the release build turns Hindi on.
3. **Terms of Use link (Apple 3.1.2).** Auto-renewing subscriptions need a Terms of Use (EULA) link in the App Store metadata. Put the lawyer-approved terms URL in App Store Connect's License Agreement field, or add a "Terms of Use: <url>" line to every `ios/*/description.txt`. Add the privacy policy URL in both consoles.
4. **Native review.** A native Telugu reviewer and a native Hindi reviewer each read all their files, including the extras, checking tone, gender-neutral forms and safe messaging. Then flip `status.json` to `approved`.
5. **Upload.** `fastlane deliver --metadata_path store/ios --skip_binary_upload --skip_screenshots` and `fastlane supply --metadata_path store/android --skip_upload_apk --skip_upload_aab`. There is no Fastfile in the repo yet. The folder layout and file names are fastlane's defaults (`deliver` metadata keys, `supply` listing keys). `extras/` sits outside both paths on purpose.
