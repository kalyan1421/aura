# Hinglish and Hindi mood names vs. the 4×4 mood grid

**Status:** measurements and **proposals for native review**. Nothing here has been applied, and
`contracts/moods.json` is unchanged. The names in the catalogue are drafts, and choosing them is a copy decision for
the owner. PRD 18 asks for all 16 names to be tested with at least 10 native speakers before beta, and for a
self-review of their clinical weight against published safe-messaging guidelines. Neither has been done.

The method is the one in `docs/l10n/tenglish-mood-names.md`: how the grid picks its layout, how the label width comes
from the screen width, and the fonts used. To reproduce the numbers:

`cd apps/mobile && AURA_MOOD_WIDTHS=1 flutter test test/flows_mood_name_widths_test.dart`

The report now also covers `hi-Latn` (Roboto on Android, SF Pro on iOS) and `hi` (the bundled Noto Sans Devanagari,
heaviest weight SemiBold). The same test checks two things at 360 dp (Android, and Devanagari):
- every proposal below fits the 4×4;
- the current Hindi and Hinglish sets keep the 4×4.

`test/mood_grid_fit_test.dart` also runs the grid in Hindi and Hinglish on real phones. At 1.0 text, all 16 labels sit
above Save. At 1.5× and 2×, the grid may scroll but never overflows.

## The current names (contracts/moods.json)

| Quadrant | Mood | Hindi | Hinglish | PRD 18 table (hi / Hinglish) |
|---|---|---|---|---|
| Storm | Overwhelmed | बेहाल | Behaal | भारीपन / Bahut bojh |
| Storm | Anxious | बेचैन | Bechain | घबराहट / Ghabrahat |
| Storm | Restless | अशांत | Ashaant | — |
| Storm | Frustrated | झुंझलाहट | Jhunjhlahat | — |
| Rain | Melancholy | उदास | Udaas | — |
| Rain | Drained | थकान | Thakaan | — |
| Rain | Lonely | अकेलापन | Akelapan | अकेलापन / Akelapan |
| Rain | Numb | सुन्न | Sunn | सुन्न / Sunn |
| Moonlight | Calm | शांत | Shaant | — |
| Moonlight | Content | संतुष्ट | Santusht | — |
| Moonlight | Quietly Hopeful | थोड़ी उम्मीद | Thodi ummeed | थोड़ी उम्मीद / Thodi ummeed |
| Moonlight | Grateful | आभारी | Aabhaari | — |
| Sunrise | Joyful | खुश | Khush | — |
| Sunrise | Excited | उत्साहित | Utsaahit | — |
| Sunrise | Proud | गर्व | Garv | गर्व / Proud |
| Sunrise | Energised | जोश में | Josh mein | — |

**Gender.** Every name is either a noun (थकान, अकेलापन, झुंझलाहट, गर्व) or an adjective that doesn't change with gender
(उदास, बेचैन, शांत, खुश, उत्साहित, आभारी), so PRD 18's "no gendered forms" holds. Keep this in mind when reviewing
alternatives. चिढ़चिढ़ा / chidchida ("irritable") and थका हुआ / thaka hua ("tired") both change with gender
(चिढ़चिढ़ी, थकी हुई), so neither can be used.

**Where the catalogue differs from the PRD table.** These are owner decisions:
- **Overwhelmed.** बेहाल / Behaal means "in a bad way, distraught", which may carry more weight than "overwhelmed". The
  PRD's भारीपन ("heaviness") is softer. "Bahut bojh" ("too much weight") is two words, which the grid handles.
- **Anxious.** बेचैन / Bechain means "uneasy, restless", an everyday word. The PRD's घबराहट / Ghabrahat means
  "nervousness, panic" and is closer to "anxious". But it is also a little stronger, and it sits next to अशांत
  (Restless) in the same quadrant.
- **Proud (Hinglish).** The PRD keeps the English word "Proud", as common usage. The catalogue has "Garv".

**Clinical weight.** None of the 16 is a clinical term. The PRD rules out *avsaad* ("depression") for Melancholy, and
none of these uses it. सुन्न / Sunn ("numb") is the everyday word.

## Blocking names per width (1.0 text scale)

"Blocks" means the name alone keeps the grid out of the 4×4 at that width (see the Tenglish doc).

| Width | Hinglish on Android (Roboto) | Hinglish on iOS (SF Pro) | Hindi (Noto Sans Devanagari) |
|---|---|---|---|
| 360 dp | none: 4×4 at 11.81 px | **Jhunjhlahat** | none: 4×4 at 13.50 px |
| 375 dp | none | none: 4×4 at 11.18 px | none |
| 390 dp | none | none | none |
| 412 dp | none | none | none |

Hindi and Hinglish are far more compact than Tenglish, and than English, which blocks at 360 and 375 dp on Android
("Overwhelmed"). Devanagari is the most compact script in the app: the longest Hindi name, अकेलापन, needs 41.92 px,
and every name fits at the grid's largest size (13.5 px) at every width.

### Needs at 11 px (widest word)

| Name | Android (Roboto) | iOS (SF Pro) | | Name | Devanagari |
|---|---:|---:|---|---|---:|
| Jhunjhlahat | 58.21 | **65.18** | | अकेलापन | 41.92 |
| Akelapan | 46.18 | 51.16 | | झुंझलाहट | 40.22 |
| Santusht | 44.22 | 49.89 | | उत्साहित | 36.23 |
| Aabhaari | 44.37 | 49.49 | | आभारी | 31.26 |
| Thodi ummeed | 43.29 | 47.79 | | अशांत | 26.73 |
| Thakaan | 42.69 | 46.97 | | थकान | 26.00 |
| Utsaahit | 41.20 | 46.70 | | थोड़ी उम्मीद | 25.82 |
| Ashaant | 40.88 | 45.49 | | बेहाल | 23.65 |
| Bechain | 39.83 | 44.19 | | उदास | 23.29 |
| Shaant | 34.59 | 38.79 | | संतुष्ट | 21.16 |
| Behaal | 33.83 | 37.40 | | बेचैन | 20.51 |
| Khush | 31.10 | 34.84 | | जोश में | 19.57 |
| Udaas | 30.89 | 34.60 | | शांत | 17.72 |
| Sunn | 25.24 | 28.12 | | खुश | 17.41 |
| Josh mein | 24.55 | 26.92 | | सुन्न | 14.51 |
| Garv | 23.06 | 26.10 | | गर्व | 13.01 |

Available label width in the 4×4: 62.50 / 66.25 / 70.00 / 75.50 px at 360 / 375 / 390 / 412 dp.

## Proposals (FOR NATIVE REVIEW — not applied)

### Frustrated: "Jhunjhlahat" (झुंझलाहट, "irritation, exasperation"). Blocks only on iOS at 360 dp

It needs 65.18 px on iOS, where 62.50 px is available at 360 dp; it fits from 375 dp. On Android it fits everywhere.
This is the same situation as English "Overwhelmed" on Android (67.90 px), so fixing it only brings Hinglish in line
with English at that width.

| Candidate | Meaning / note | Android: needs → fits at | iOS: needs → fits at |
|---|---|---|---|
| **Chidh** (चिढ़) | "irritation, annoyance": a noun, so no gender; the everyday word | 28.62 → all | 32.38 → all |
| **Khij** (खीज) | "vexation": also a noun, a little more literary | 18.91 → all | 21.07 → all |
| **Frustrated** | code-mixed: very common in Hinglish chat ("bahut frustrated hoon") | 51.04 → all | 58.43 → all |
| Jhunjhlahat (keep) | the current word; fine from 375 dp on iOS | 58.21 → all | 65.18 → 375+ |

In Hindi script, झुंझलाहट fits everywhere (40.22 px). चिढ़ (16.94 px) and खीज (20.94 px) are shorter options if the
Hinglish name changes and the two scripts should match.

### PRD 18 table alternatives (if the owner prefers them)

| Mood | Candidate | Android | iOS | Devanagari |
|---|---|---:|---:|---:|
| Overwhelmed | Bahut bojh / भारीपन | 28.94 → all | 32.50 → all | 32.26 → all |
| Anxious | Ghabrahat / घबराहट | 51.26 → all | 58.11 → all | 33.17 → all |
| Proud | Proud (Hinglish) | 29.49 → all | 32.94 → all | — |

All of them keep the 4×4 at every width. Choosing between these and the catalogue names is about meaning, not layout.
