// A copy of contracts/sounds/stems.v1.json, bundled so Sounds work offline
// from the first launch. test/sounds_manifest_test.dart fails when the two
// differ: after editing the contract, paste it here unchanged.

/// The stem manifest shipped with the app (`contracts/sounds/stems.v1.json`).
const String bundledStemManifestJson = r'''
{
  "_note": "F15 Sounds stem manifest (PRD 06d 'Sounds'). The app bundles a copy (apps/mobile/lib/src/features/sanctuary/sounds/stem_manifest_bundled.dart; a test keeps them equal). Every file stem needs a row in docs/sounds/licence-log.md before its status becomes 'available'. File stems with status 'pending_sourcing' are hidden in the app unless they name a fallback_generator, which plays until the recording is downloaded.",
  "version": 1,
  "max_layers": 4,
  "stems": [
    {
      "id": "rain",
      "title_key": "sounds_stemRain",
      "tier": "free",
      "role": "bed",
      "kind": "file",
      "file": "base/rain.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing",
      "fallback_generator": "rain"
    },
    {
      "id": "ocean",
      "title_key": "sounds_stemOcean",
      "tier": "free",
      "role": "bed",
      "kind": "file",
      "file": "base/ocean.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing",
      "fallback_generator": "ocean"
    },
    {
      "id": "wind",
      "title_key": "sounds_stemWind",
      "tier": "free",
      "role": "bed",
      "kind": "file",
      "file": "base/wind.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing",
      "fallback_generator": "wind"
    },
    {
      "id": "night_insects",
      "title_key": "sounds_stemNightInsects",
      "tier": "free",
      "role": "bed",
      "kind": "file",
      "file": "base/night_insects.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing",
      "fallback_generator": "crickets"
    },
    {
      "id": "singing_bowl",
      "title_key": "sounds_stemSingingBowl",
      "tier": "free",
      "role": "accent",
      "kind": "procedural",
      "generator": "singing_bowl",
      "licence": "generated-in-code",
      "status": "available"
    },
    {
      "id": "chimes",
      "title_key": "sounds_stemChimes",
      "tier": "free",
      "role": "accent",
      "kind": "procedural",
      "generator": "chimes",
      "licence": "generated-in-code",
      "status": "available"
    },
    {
      "id": "brown_noise",
      "title_key": "sounds_stemBrownNoise",
      "tier": "free",
      "role": "bed",
      "kind": "procedural",
      "generator": "brown_noise",
      "licence": "generated-in-code",
      "status": "available"
    },
    {
      "id": "pink_noise",
      "title_key": "sounds_stemPinkNoise",
      "tier": "plus",
      "role": "bed",
      "kind": "procedural",
      "generator": "pink_noise",
      "licence": "generated-in-code",
      "status": "available"
    },
    {
      "id": "deep_bell",
      "title_key": "sounds_stemDeepBell",
      "tier": "plus",
      "role": "accent",
      "kind": "procedural",
      "generator": "deep_bell",
      "licence": "generated-in-code",
      "status": "available"
    },
    {
      "id": "monsoon_roof",
      "title_key": "sounds_stemMonsoonRoof",
      "tier": "plus",
      "role": "bed",
      "kind": "file",
      "file": "plus/monsoon_roof.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing"
    },
    {
      "id": "stream",
      "title_key": "sounds_stemStream",
      "tier": "plus",
      "role": "bed",
      "kind": "file",
      "file": "plus/stream.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing"
    },
    {
      "id": "fireplace",
      "title_key": "sounds_stemFireplace",
      "tier": "plus",
      "role": "bed",
      "kind": "file",
      "file": "plus/fireplace.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing"
    },
    {
      "id": "distant_thunder",
      "title_key": "sounds_stemDistantThunder",
      "tier": "plus",
      "role": "accent",
      "kind": "file",
      "file": "plus/distant_thunder.v1.m4a",
      "bytes": null,
      "bytes_estimate": 2000000,
      "sha256": null,
      "licence": null,
      "source_url": null,
      "status": "pending_sourcing"
    }
  ]
}
''';
