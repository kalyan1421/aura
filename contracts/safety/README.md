# Safety contracts

> **NEEDS NATIVE + SAFE-MESSAGING REVIEW (A9) before alpha.** The seed lexicon was written by the dev team. Telugu and Tenglish need a native speaker; every entry needs the safe-messaging self-review (WHO / AFSP / Samaritans checklist, PRD open question A9, REQ-SAFE-15). Open points are listed in the JSON's `review.open`.

| File | What |
|---|---|
| `crisis_lexicon.v1.json` | The on-device crisis lexicon (PRD F9 "L1"), versioned. The reviewed baseline every app build bundles, and what NestJS checks new versions against. |
| `crisis_lexicon.vectors.json` | Text → verdict cases every matcher must pass: the app's Dart matcher and NestJS's TypeScript one (`server/aura-api/src/remote-config/lexicon/`), and every signed version before it is published. |
| `fixtures/crisis_lexicon.v1.dev-signed.json` | The baseline as a signed bundle, signed by the server tooling with the public **development** key. Both stacks' tests verify it (a cross-implementation check of the envelope). |

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

Two ways, for two purposes:

**A. The bundled baseline (needs an app release).**
1. Edit `crisis_lexicon.v1.json` (bump `version` for any change that ships; keep ids stable) and add cases to `crisis_lexicon.vectors.json`.
2. Regenerate the copies: `cd apps/mobile && python3 tool/gen_lexicon.py` — writes the app's `lib/src/features/support/crisis_lexicon_data.dart` **and** the server's `server/aura-api/src/remote-config/lexicon/lexicon-contract.data.ts` (same Unicode tables, the baseline, the vectors); `--check` fails when either is stale.
3. `flutter test test/lexicon_*` and `pnpm test` (server) must pass (both read this directory: generated copies in sync, every vector). Re-sign the fixture: `cd server/aura-api && pnpm lexicon sign ../../contracts/safety/crisis_lexicon.v1.json --dev --seq 1 --out ../../contracts/safety/fixtures/crisis_lexicon.v1.dev-signed.json`.
4. Removing a crisis term needs the owner's sign-off (PRD 19, admin console rules) and a note in the review log.

**B. A signed version (no app release; PRD 19 REQ-ADM-12 "signed and reversible").** Through the admin console (NestJS `/admin/lexicons/crisis*`, Owner; contracts/api/v1.md "Crisis lexicon versions"):
1. **Upload** a version in this schema with its own test cases. NestJS refuses it unless it follows the rules above, **every case in `crisis_lexicon.vectors.json` plus its own cases pass**, and en / te / te-Latn each keep a crisis entry. Stored versions never change.
2. **Test on samples** (verdicts only; nothing kept).
3. **Publish**: NestJS signs `{kind, seq, issuedAt, version, content, vectors}` with Ed25519 (`LEXICON_SIGNING_KEY`, server-only). **Roll back** = publish an older stored version: a new signature with a higher `seq`. Dropping crisis forms that phones use now needs an explicit `allowCrisisRemovals` (Owner). Every step is in the hash-chained audit log.
4. Phones download it on start / resume / sync, verify the signature with the public key they embed, refuse an older `seq` (replay), re-run the bundle's vectors with **their own** matcher, and only then use it — else they keep the last verified version, else the bundled v1.

Signed envelope (`aura.signed-bundle.v1`): `{ format, keyId, payload: base64(canonical JSON bytes), signature: base64(Ed25519("aura.signed-bundle.v1\n" ‖ payload bytes)) }`; `keyId` = hex of the first 8 bytes of SHA-256 of the raw 32-byte public key. The development key (`keyId ba9afcf9c1f7ab25`, public key `c8HcqQhqAfZ/Q0f+tf7I7n7meei0mzldCIbFYLYSfko=`) is derived from a published string: it is **not a secret**, production APIs refuse it and release builds don't trust it. Key management: docs/setup/lexicon-and-flags.md.
