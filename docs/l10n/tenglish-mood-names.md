# Tenglish and Telugu mood names vs. the 4×4 mood grid

**Status:** measurements plus **spelling proposals for native review**. Nothing here has been applied: `contracts/moods.json` and the mood catalogue are unchanged. Choosing names is a copy decision for the owner.

## Why the grid goes tall

`MoodGrid` (`apps/mobile/lib/src/features/checkin/mood_grid.dart`) gives all 16 labels one shared size. It uses the first layout, in the order grid (4×4) → tall → stacked → list, where the widest single word of every name fits on one line at **11 px or more**. Words never break inside, and it measures the bold weight so that selecting a mood never causes overflow. Names may still wrap between words. **A single long word anywhere pushes the whole grid into the taller layout**, so one name is enough to block the 4×4.

The label width in the 4×4 depends only on the screen width. The check-in list pads the grid by the 20 dp page gutter on both sides:

`label width = (screen − 48) / 4 − 15.5` dp

| Screen width | 360 dp | 375 dp | 390 dp | 412 dp |
|---|---:|---:|---:|---:|
| Label width available in the 4×4 | 62.50 | 66.25 | 70.00 | 75.50 |

## How this was measured

`apps/mobile/test/flows_mood_name_widths_test.dart` runs the grid's own `resolveMoodGridFit` with the real label style (`MoodGrid.labelBaseStyle`, bold, letter-spacing 0), the quadrant-header check, 1.0 text scale and the 11 px floor. It uses real fonts in place of the test font:

- **Android:** Roboto Bold (the system font; the app's iOS type scale falls back to it on Android).
- **iOS:** SF Pro Bold, taken from macOS `SFNS.ttf` at opsz 17 / wght 700. This is an approximation of the iPhone system font, and it only runs on macOS.
- **Telugu script (`te`):** the bundled Noto Sans Telugu. Its heaviest bundled weight is SemiBold.

A name "blocks" a width when the fit for that name alone cannot keep the 4×4 there. "Needs" is the width of its widest word at 11 px.

To reproduce the numbers: `cd apps/mobile && AURA_MOOD_WIDTHS=1 flutter test test/flows_mood_name_widths_test.dart`. The same test checks that every proposal below fits the 4×4 at 360 dp on Android and in Telugu script.

## Blocking names per width (1.0 text scale)

| Width | Tenglish on Android (Roboto) | Tenglish on iOS (SF Pro) | Telugu script (Noto Sans Telugu) |
|---|---|---|---|
| 360 dp | Moddubaarinattu, Prashaanthanga, Kruthagnathaga, Ukkiribikkiriga, Alasipoyinattu, Aandolanaga, Ashaanthiga | Android's 7 plus Aanandanga, Hushaaruga, Utsaahanga | అలసిపోయినట్టు, మొద్దుబారినట్టు, ఉక్కిరిబిక్కిరిగా |
| 375 dp | Moddubaarinattu, Prashaanthanga, Kruthagnathaga, Ukkiribikkiriga, Alasipoyinattu, Aandolanaga | Android's 6 plus Ashaanthiga, Aanandanga, Hushaaruga | అలసిపోయినట్టు, మొద్దుబారినట్టు |
| 390 dp | Moddubaarinattu, Prashaanthanga, Kruthagnathaga, Ukkiribikkiriga, Alasipoyinattu | Android's 5 plus Aandolanaga | అలసిపోయినట్టు |
| 412 dp | Moddubaarinattu, Prashaanthanga, Kruthagnathaga | Android's 3 plus Ukkiribikkiriga, Alasipoyinattu | none: the 4×4 holds, at 11.01 px |

Moddubaarinattu, Prashaanthanga and Kruthagnathaga block at **every** width on both platforms. On Android they would need a 427–450 dp screen, and on iOS 468–492 dp.

> **English blocks too.** "Overwhelmed" needs 67.90 px on Android, so English also goes tall at 360 and 375 dp and keeps the 4×4 only from 390 dp. On iOS it needs 76.45 px, so English never gets the 4×4 at these four widths. At 360 dp on iOS, "Melancholy" (63.25 px) blocks as well. Shortening the Tenglish names brings Tenglish up to English, not past it. A 4×4 at 360 dp in every locale would also need an English change, such as "Swamped" (48.60 / 54.21 px), or a geometry change. Both are owner decisions.

> **Borderline fits.** A name within a fraction of a pixel of the label width can still block. For example, Ashaanthiga needs 62.13 px at 360 dp where 62.50 px is available. In `resolveMoodGridFit`, the first shared size lands a hair over after re-measuring, and the next ×0.97 step drops below the 11 px floor. Ukkiribikkiriga in Telugu script fits at 375 dp with only 0.02 px to spare. Treat anything within about 0.5 px of the limit as fragile.

## Per-name proposals

> **PROPOSALS FOR NATIVE REVIEW. Not applied.** Every candidate is meant to keep the meaning of the current name. The catalogue writes long vowels doubled (Aandolanaga, Ashaanthiga). Some candidates use the single-vowel spellings common in everyday chat typing, and that is a house-style choice too. Code-mixed forms (e.g. "Tension ga") follow the Tenglish register, which already keeps English words.

In the tables below, "fits at" lists the widths among 360/375/390/412 dp where the candidate alone keeps the 4×4.

### Tenglish (`te-Latn`)

#### Numb: "Moddubaarinattu" (మొద్దుబారినట్టు, "as if gone numb")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 84.97 px | 95.51 px |
| Available | 62.50 / 66.25 / 70.00 / 75.50 px | same |
| Blocks at | all four widths (needs ≥ 450 dp) | all four widths (needs ≥ 492 dp) |

| Candidate | Meaning / note | Android: needs → fits at | iOS: needs → fits at |
|---|---|---|---|
| **Moddugaa** (మొద్దుగా) | "dull, numb": the everyday word | 52.48 → all | 58.09 → all |
| **Moddubaari** (మొద్దుబారి) | same verb, "gone numb", drops "-inattu" ("as if") | 59.32 → all | 66.10 → 375+ |
| **Moddu baarinattu** | the current word split at its compound boundary; same meaning | 50.56 → all | 57.49 → all |

#### Calm: "Prashaanthanga" (ప్రశాంతంగా, "calmly, at peace")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 80.72 px | 90.09 px |
| Blocks at | all four widths (needs ≥ 433 dp) | all four widths (needs ≥ 470 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Shaantanga** (శాంతంగా) | "calmly, peacefully": the plainer form of the same root | 58.82 → all | 65.76 → 375+ |
| **Shaantam ga** | same, as noun + "ga" (common in chat) | 50.01 → all | 55.53 → all |
| **Prashantam ga** | keeps "prashaantam", as noun + "ga", single a | 59.85 → all | 66.42 → 390+ |

#### Grateful: "Kruthagnathaga" (కృతజ్ఞతగా, "gratefully")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 79.20 px | 89.51 px |
| Blocks at | all four widths (needs ≥ 427 dp) | all four widths (needs ≥ 468 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Thankful ga** | code-mixed "grateful", natural Tenglish | 43.91 → all | 48.74 → all |
| **Krutagnata** (కృతజ్ఞత) | the noun "gratitude", simpler romanization; the only candidate that isn't an adverb | 54.72 → all | 62.02 → all (0.48 px spare at 360) |
| **Krutagnyata** | same noun, "gny" spelling for జ్ఞ | 60.16 → all | 68.24 → 390+ |

#### Overwhelmed: "Ukkiribikkiriga" (ఉక్కిరిబిక్కిరిగా, "overwhelmed, choked up")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 71.72 px | 80.93 px |
| Blocks at | 360, 375, 390 (fits at 412; needs ≥ 397 dp) | all four widths (needs ≥ 434 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Ukkiri bikkiriga** | the same word, split between its two halves | 42.88 → all | 48.24 → all |
| **Ukkiribikkiri** | same, without "-ga" | 59.54 → all | 67.35 → 390+ |
| **Ukkiri bikkiri** | split, without "-ga" | 30.71 → all | 34.65 → all |

#### Drained: "Alasipoyinattu" (అలసిపోయినట్టు, "as if worn out")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 71.20 px | 80.01 px |
| Blocks at | 360, 375, 390 (fits at 412; needs ≥ 395 dp) | all four widths (needs ≥ 430 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Alasipoyi** (అలసిపోయి) | "worn out", drops "-nattu" ("as if") | 45.56 → all | 50.59 → all |
| **Alasi poyinattu** | the current word, split | 46.42 → all | 52.83 → all |
| **Neerasanga** (నీరసంగా) | "drained, listless": the common spoken word for low energy | 59.30 → all | 66.03 → 375+ |

#### Anxious: "Aandolanaga" (ఆందోళనగా, "anxiously")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 64.93 px | 72.04 px |
| Blocks at | 360 (fits from 375; needs ≥ 370 dp) | 360, 375, 390 (fits at 412; needs ≥ 398 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Andolanaga** | same word, single "a" | 58.77 → all | 65.63 → 375+ |
| **Tension ga** | code-mixed, very common for "anxious" | 39.39 → all | 42.85 → all |
| **Kangaruga** (కంగారుగా) | "flustered, anxious". It can also mean "in a hurry", so check the nuance | 53.56 → all | 59.80 → all |

#### Restless: "Ashaanthiga" (అశాంతిగా, "restless, unsettled")

| | Android | iOS |
|---|---:|---:|
| Needs at 11 px | 62.13 px (a borderline miss, see above) | 69.18 px |
| Blocks at | 360 (fits from 375) | 360, 375 (fits from 390; needs ≥ 387 dp) |

| Candidate | Meaning / note | Android | iOS |
|---|---|---|---|
| **Ashantiga** | same word, single "a", "t" for త | 50.08 → all | 55.74 → all |
| **Ashaantiga** | keeps the long "aa", drops the "h" | 55.98 → all | 62.23 → 375+ (a borderline miss at 360) |
| **Kuduruga ledu** (కుదురుగా లేదు) | "can't settle": an everyday phrase for restless | 47.71 → all | 53.66 → all |

#### iOS only: Joyful "Aanandanga", Energised "Hushaaruga", Excited "Utsaahanga"

These fit on Android at every width. On iOS, SF Pro is about 11% wider:

| Current | iOS needs | iOS blocks at | Candidate (meaning kept) | iOS: needs → fits at |
|---|---:|---|---|---|
| Aanandanga (ఆనందంగా, "joyfully") | 68.88 px | 360, 375 | **Aanandam ga** (noun + "ga") | 58.65 → all |
| | | | **Anandanga** (single a) | 62.47 → 375+ (a borderline miss at 360) |
| Hushaaruga (హుషారుగా, "lively, energised") | 66.94 px | 360, 375 | **Husharuga** (single a) | 60.45 → all |
| Utsaahanga (ఉత్సాహంగా, "excited, enthusiastic") | 65.97 px | 360 | **Utsahanga** (single a) | 59.48 → all |

### Telugu script (`te`, Noto Sans Telugu, same on both platforms)

#### Drained: అలసిపోయినట్టు ("as if worn out")

Needs **73.19 px**. Blocks at 360, 375 and 390, fits at 412 (needs ≥ 403 dp).

| Candidate | Meaning / note | Needs → fits at |
|---|---|---|
| **అలసిపోయి** | "worn out", drops -నట్టు ("as if") | 52.23 → all |
| **అలసటగా** | "tiredly" | 45.54 → all |
| **నీరసంగా** | "drained, listless": the common spoken word | 39.73 → all |

#### Numb: మొద్దుబారినట్టు ("as if gone numb")

Needs **68.08 px**. Blocks at 360 and 375, fits from 390 (needs ≥ 382 dp).

| Candidate | Meaning / note | Needs → fits at |
|---|---|---|
| **మొద్దుబారి** | "gone numb", drops -నట్టు | 47.11 → all |
| **మొద్దుగా** | "dull, numb" | 38.56 → all |
| **స్తబ్దంగా** | "inert, frozen still". A little more formal, so check the nuance | 33.37 → all |

#### Overwhelmed: ఉక్కిరిబిక్కిరిగా ("overwhelmed, choked up")

Needs **66.23 px**. Blocks at 360. At 375 it fits with 0.02 px to spare, which is fragile.

| Candidate | Meaning / note | Needs → fits at |
|---|---|---|
| **ఉక్కిరిబిక్కిరి** | same word without -గా | 55.61 → all |
| **సతమతంగా** | "in turmoil, struggling to cope": a close synonym | 55.34 → all |

The Telugu-script version reads better than the romanized one because Telugu script is compact. Only these three names block, and the 4×4 already holds at 412 dp.
