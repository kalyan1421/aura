## Localization & i18n

### Languages and staging

Priority: **English → Telugu → Tenglish → Hindi → Hinglish.**

| Language | Locale | Script | UI | Room pool |
|---|---|---|---|---|
| English | `en` | Latin | Alpha | English, alpha |
| Telugu | `te` | Telugu | Alpha | Telugu + Tenglish, alpha |
| Tenglish | `te-Latn` | Romanized Telugu | Alpha | Telugu + Tenglish, alpha |
| Hindi | `hi` | Devanagari | Beta | Hindi + Hinglish, gated |
| Hinglish | `hi-Latn` | Romanized Hindi | Beta | Hindi + Hinglish, gated |

- **Alpha languages are the ones AK can moderate.** **Hindi + Hinglish rooms open** when a Hindi-reading moderator exists or auto-moderation reaches ≥ 95% recall on crisis, PII and sexual/grooming items in ≥ 1,000 native-labelled Hindi/Hinglish reflections `[ASSUMPTION]`; until then those users match into English (F5).
- **One English** (Indian/British spelling, "Energised") for every country; no `en-US` in v1 `[ASSUMPTION]`.
- **Default:** English outside India. In India the onboarding picker pre-selects a supported device language, with a one-tap "Tenglish lo choodandi" / "Hinglish mein dekho" (phones never report romanized locales). System strings for `te-Latn` and `hi-Latn` fall back to English `[ASSUMPTION]`.
- **Availability:** worldwide except EU, UK and Australia until beta. **Store listings in all 5 languages:** Telugu and Hindi as store locales `[STORE: confirm Telugu in App Store Connect]`; Tenglish and Hinglish (no store locale) in India screenshots, ASO keywords and creator assets.

### When to add a language

Next: **Tamil, then Kannada**, then Bengali and Marathi; non-Indian languages follow the same rule. Add one when both hold for 4 consecutive weeks `[ASSUMPTION]`:
1. **Demand:** ≥ 8% of MAU in states or countries where it is the main language (coarse region, never GPS), or ≥ 5% of MAU pick it in a "Want Aura in your language?" prompt.
2. **Safety readiness:** a lexicon in native script **and** romanized form (e.g. Tanglish), and a moderator who reads it or auto-moderation that meets the bar above.

UI may ship first; **the room pool opens only at safety readiness** (until 5,000 DAU, that means the auto-moderation bar).

### String externalization

- Flutter `gen-l10n`: `app_en.arb`, `app_te.arb`, `app_te_Latn.arb`, `app_hi.arb`, `app_hi_Latn.arb`. **No hard-coded user-facing strings**; CI lint fails on literals in widget code.
- Feature-namespaced keys (`room_gesture_warm_tea`), each with an `@description` giving screen and emotional tone.
- **ICU plurals and placeholders**, never concatenation (Telugu and Hindi word order differ).
- **No gendered forms.** Aura collects no gender, but Hindi verbs agree with it (*karoge/karogi*) and so do Telugu third-person forms (*ontarivaadu/ontaridi*). Use nouns (*Akelapan*, *Ontaritanam*), impersonal constructions, and the respectful Telugu *meeru*.
- **Brand terms stay in Latin script** everywhere: Aura, Aura Plus, Lantern Hour, Breath Ripples, Starlight, Stardust `[ASSUMPTION]`.
- Server-sent strings (pushes, moderation reasons, trial email) use the same catalogue, rendered in NestJS. Pseudo-localized build before each milestone.
- **Calm copy** (companion lines, "A minute for you", guided prompts, grounding scripts, Tonight's intentions) ships in every alpha language. Each string is native-reviewed and self-reviewed against safe-messaging guidelines like crisis copy, and written in the second person with the respectful Telugu *meeru* and no gendered forms. Line pools are the same size in every language.

### Translating the 16 moods

Everyday words a 20-year-old would use, not clinical ones (no *avsaad* "depression" for Melancholy); a passing feeling, not an identity; nouns over gendered forms. Tenglish and Hinglish may keep the English word where that is common usage. All 16 are tested with ≥ 10 native speakers per language (Telugu in alpha, Hindi before beta) and self-reviewed against published safe-messaging guidelines for clinical weight.

| Mood | Telugu | Tenglish | Hindi | Hinglish |
|---|---|---|---|---|
| Overwhelmed | ఉక్కిరిబిక్కిరి | Ukkiribikkiri | भारीपन | Bahut bojh |
| Anxious | ఆందోళన | Tension | घबराहट | Ghabrahat |
| Lonely | ఒంటరితనం | Ontaritanam | अकेलापन | Akelapan |
| Numb | ఏమీ అనిపించట్లేదు | Emi anipinchatledu | सुन्न | Sunn |
| Quietly Hopeful | కొంచెం ఆశ | Konchem aasha | थोड़ी उम्मीद | Thodi ummeed |
| Proud | గర్వంగా ఉంది (check: *garvam* can read as arrogance) | Proud | गर्व | Proud |

Room theme names stay English in Tenglish and Hinglish and are translated in Telugu and Hindi script. Gestures are localized for warmth: Warm Tea becomes "Oka cup chai" / "Ek cup chai" `[ASSUMPTION]`.

### Room language pools

Three pools: **English · Telugu + Tenglish · Hindi + Hinglish** (one spoken language, both scripts). The pool follows the app language; a change applies to new rooms only. Thin pools merge into English of the same timezone region (F5): gestures and presence render in each viewer's language, reflections are shown as written and never machine-translated.

### Moderation lexicons

One versioned lexicon per language and script (crisis, PII, harassment, sexual/grooming, spam), edited in the admin console and shipped to devices as a signed bundle without an app release. OpenAI omni-moderation is the only server model and is weakest on romanized text, so **the lexicon carries most of the load for Tenglish and Hinglish**; expect a higher held rate there.
- **Transliteration variants:** spelling drift (Tenglish *chachipovali / sachipovali / chanipovalani*; Hinglish *marna / marnaa / mrna*), misspellings (*sucide*), digit swaps (*m4rna*), spacing tricks, code-mixed phrases.
- **Grooming and off-platform asks** in all five: age, photos, number, Insta/Snap/WhatsApp, meeting up (*number ivvu*, *insta id cheppu*, *number do*).
- Match on NFC-normalized, lower-cased text with zero-width joiners stripped; store the original (joiners matter in Telugu and Devanagari). PII detection covers Telugu (౦–౯) and Devanagari (०–९) digits and spelled-out numbers in all five languages.
- Stricter sexual, grooming and PII thresholds when an under-18 account is involved (invisible to users). Crisis terms reviewed each release by a native speaker and against published safe-messaging guidelines.

### Fonts

- Bundle **Noto Sans Telugu** and **Noto Sans Devanagari** (subsets) via `fontFamilyFallback`; OEM fonts on some Android skins render conjuncts badly.
- **Line height ≥ 1.5 for Telugu and Devanagari** so stacked consonants and vowel signs don't clip. Test conjuncts (క్ష, శ్రీ, స్త్ర; क्ष, ज्ञ, श्र) at 200% text scale.
- Budget 30–45% longer Telugu and 20–35% longer Hindi strings `[ASSUMPTION]`; buttons wrap rather than truncate.

### Dates, numbers, money

- `intl` `DateFormat` by locale ("23 Sep 2026" / "23 సెప్టెం 2026" / "23 सितंबर 2026"); romanized locales use English formats; 12-hour time. Lantern Hour shows as 9–11 pm local.
- **Indian grouping** (1,00,000) for users in India, the device region's grouping elsewhere; Western digits in all languages `[ASSUMPTION]`.
- **Prices:** always the store's localized price string from `in_app_purchase` product details, never a hard-coded amount, so INR and store-local prices abroad are correct and tax-inclusive `[STORE]`. Stardust is a count, never shown with a currency symbol.

### Helplines by country

Remote config keyed by country (store region, then SIM, then locale; never GPS), localized, tap-to-call, cached on device: **India** Tele-MANAS **14416** / 1-800-891-4416 · **US 988** · **everywhere else** "If you're in danger right now, please call your local emergency number" (no unverified numbers). Re-verified quarterly and before EU/UK/AU open; a wrong number is a P0 bug.

### RTL

Not needed at launch, but not blocked: `EdgeInsetsDirectional`, `AlignmentDirectional` and direction-aware icons everywhere (lint-enforced), so Urdu can ship later without layout rework.
