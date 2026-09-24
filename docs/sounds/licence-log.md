# Sounds licence log (F15)

PRD 06d "Audio source" (AK, 23 Sep 2026): licensed CC0 or royalty-free field recordings for the base stems, procedural layering in code, brown noise synthesized on the device, and **a licence log (source, licence, date) for each stem**. No per-play licences. PRD 20 risk row: CC0/royalty-free stems only; any stem with an unclear licence is replaced by a procedural layer, as brown noise already is.

The manifest is `contracts/sounds/stems.v1.json` (bundled in the app as `apps/mobile/lib/src/features/sanctuary/sounds/stem_manifest_bundled.dart`; `test/sounds_manifest_test.dart` fails if they differ, and fails if a stem id is missing from the table below).

## Rules for a recorded stem

A file stem may only move from `"status": "pending_sourcing"` to `"available"` when all of these are true:

1. **Licence is CC0-1.0, or royalty-free with no attribution, per-play, per-install or revenue terms** that Aura can't meet. CC-BY is acceptable only if AK approves the attribution text (it would go in Settings › About). No CC-NC or CC-ND (Aura Plus is commercial).
2. **The source page and the licence text are archived** (PDF or web-archive link) in the row below, with the date downloaded.
3. **No identifiable voices, music or brands** in the recording (no narration in v1; voices would also be personal data).
4. **Audio spec:** AAC-LC in `.m4a`, 44.1 or 48 kHz, stereo, 96–128 kbps, a seamless loop of 90–150 s (the app picks a random start point), loudness normalised to about −23 LUFS integrated, no fade at either end. About 2 MB per base stem, so the four base recordings stay near the PRD's ≈ 8 MB.
5. **Manifest fields filled:** `bytes` (exact file size), `sha256` (lower-case hex of the exact file uploaded), `licence` (SPDX id or "royalty-free: <vendor>"), `source_url`. The app refuses an available file stem without size, hash and licence, and deletes a download whose size or hash doesn't match.
6. **Uploaded** to the Sounds bucket at the manifest's `file` path; the app downloads from `AURA_SOUNDS_BASE_URL` + `file` (a `--dart-define`).

Bump the file name's version (`rain.v2.m4a`) whenever a stem's audio changes; the app keys its cache on the hash.

## Log

| Stem id | Tier | Kind | Source | Licence | Date | Archived licence / notes |
|---|---|---|---|---|---|---|
| brown_noise | free | procedural | Generated on the device (`procedural_synth.dart`, `brown_noise`) | Aura's own code | 2026-09-24 | No third-party audio. |
| singing_bowl | free | procedural | Generated on the device (`singing_bowl`: struck-bowl partials timed in code) | Aura's own code | 2026-09-24 | No third-party audio. A recorded strike sample may replace it later (log it here first). |
| chimes | free | procedural | Generated on the device (`chimes`: pentatonic tubes timed in code) | Aura's own code | 2026-09-24 | No third-party audio. |
| rain | free | file (pending) | — | — | — | **Pending sourcing.** Until then the app plays the generated `rain` stand-in. |
| ocean | free | file (pending) | — | — | — | **Pending sourcing.** Generated `ocean` stand-in plays meanwhile. |
| wind | free | file (pending) | — | — | — | **Pending sourcing.** Generated `wind` stand-in plays meanwhile. |
| night_insects | free | file (pending) | — | — | — | **Pending sourcing.** Generated `crickets` stand-in plays meanwhile. |
| pink_noise | plus | procedural | Generated on the device (`pink_noise`) | Aura's own code | 2026-09-24 | No third-party audio. |
| deep_bell | plus | procedural | Generated on the device (`deep_bell`) | Aura's own code | 2026-09-24 | No third-party audio. |
| monsoon_roof | plus | file (pending) | — | — | — | **Pending sourcing.** Hidden in the app until available. |
| stream | plus | file (pending) | — | — | — | **Pending sourcing.** Hidden in the app until available. |
| fireplace | plus | file (pending) | — | — | — | **Pending sourcing.** Hidden in the app until available. |
| distant_thunder | plus | file (pending) | — | — | — | **Pending sourcing.** Hidden in the app until available. |

## Candidate sources to check (not yet vetted)

Check each file's own licence, not just the site's default: Freesound (filter "Creative Commons 0"), BBC Sound Effects (RemArc licence is **not** suitable for a commercial app: avoid), Pixabay sounds (Pixabay Content License: royalty-free, check the current terms), or a commissioned field recording (own the rights outright; best for a Hyderabad monsoon roof).
