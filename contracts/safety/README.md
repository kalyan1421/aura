# Safety contracts

> **NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.** The seed lexicon was written by the dev team. Telugu and Tenglish need a native speaker; every entry needs the safe-messaging self-review (WHO / AFSP / Samaritans checklist, PRD open question A9, REQ-SAFE-15). Open points are listed in the JSON's `review.open`.

| File | What |
|---|---|
| `crisis_lexicon.v1.json` | The on-device crisis lexicon (PRD F9 "L1"), versioned. Source of truth for the app and, later, the NestJS worker. |
| `crisis_lexicon.vectors.json` | Text → verdict cases every matcher must pass (Dart now, TypeScript later). |

## Crisis lexicon (F9 L1)

Runs on the phone over notes, custom habit names and (later) reflections and capsule text. **Private text never leaves the device for classification** (DS-1), and nothing matched is logged or sent to analytics.

### Entries

```json
{ "id": "te-Latn.want_to_die", "language": "te-Latn", "kind": "crisis",
  "phrase": "chachipovalani", "stem": true, "variants": ["sachipovali", "chanipovali"] }
```

- `id`: `<language>.<snake_case>`, unique. Never reuse an id for a different meaning.
- `language`: `en`, `te`, `te-Latn`, `hi`, `hi-Latn`. Hindi and Hinglish are declared but empty until beta.
- `kind`:
  - `crisis`: high-confidence words for wanting to die or to harm oneself. The app saves the entry, then opens the full support sheet (`showSupportSheet(context, crisis: true)`).
  - `soft`: idioms that borrow those words ("dying of boredom", "navvi navvi chachipoya"). Never the crisis sheet; a caller may show a gentle "Help is here" card. Inside one clause, a soft match also explains away a crisis match it overlaps, so "I want to die of boredom" is soft. Only benign idioms belong here: nothing about shame, being a burden or being tired of life.
- `phrase` + `variants`: every spelling that counts (transliteration drift, common misspellings, contractions with or without the apostrophe).
- `stem` (optional, default `false`): the last word may carry suffixes. Telugu is agglutinative, so romanized stems need it (`chachipovalani` matches `chachipovalanipistundi`). Telugu script always matches as a substring and needs no flag.

### Matching (every implementation must do exactly this)

1. **Normalize** the text and every form:
   1. strip invisible format characters: zero-width space / non-joiner / joiner (U+200B–U+200D), word joiner and invisible operators (U+2060–U+2064), BOM (U+FEFF), soft hyphen (U+00AD), Mongolian vowel separator (U+180E), bidi marks and embeddings (U+200E, U+200F, U+202A–U+202E, U+2066–U+2069);
   2. canonical decomposition, canonical ordering and canonical composition (NFC) for Latin, Devanagari and Telugu;
   3. drop combining diacritics U+0300–U+036F (so `díe` → `die`) and lower-case;
   4. delete apostrophes (`'` `’` `‘` `ʼ` `` ` `` `´`), so `can't` → `cant`;
   5. collapse whitespace runs to one space (a run containing a line break becomes one line break) and trim.
2. **Latin-script forms** (only `a–z`, digits and spaces after normalizing) match on **word boundaries**:
   - words are runs of `a–z0–9`; any other character separates them;
   - inside a word that mixes letters and digits, digits read as letters: `0→o 1→i 3→e 4→a 5→s 7→t` (`k1ll` → `kill`);
   - a form matches a run of consecutive words; with `stem`, its last word may be a prefix;
   - a multi-word form also matches its words written together as one word (`wanttodie`, `killmyself`).
3. **Other scripts** (Telugu, later Devanagari) match as a **substring** of the normalized text, with line breaks read as spaces.
4. **Verdict**: `crisis` if a crisis match is not overlapped by a soft match; otherwise `soft` if any soft match; otherwise `none`.
   - Crisis matches may run across punctuation and line breaks; soft matches may not cross a clause break (`. ! ? ; : । ॥` or a line break).
   - Negation is not parsed: "I don't want to kill myself" is `crisis`. A gentle sheet is the better mistake.

### Changing the lexicon

1. Edit `crisis_lexicon.v1.json` (bump `version` for any change that ships; keep ids stable) and add cases to `crisis_lexicon.vectors.json`.
2. Regenerate the app's bundled copy: `cd apps/mobile && python3 tool/gen_lexicon.py` (writes `lib/src/features/support/crisis_lexicon_data.dart`; `--check` fails when it is stale).
3. `flutter test test/lexicon_*` must pass (the tests read this directory: generated copy in sync, every vector).
4. Removing a crisis term needs the owner's sign-off (PRD 19, admin console rules) and a note in the review log.

Later (PRD 18 "Moderation lexicons"): the same data ships as a signed bundle from the admin console without an app release; this file stays the reviewed baseline.
