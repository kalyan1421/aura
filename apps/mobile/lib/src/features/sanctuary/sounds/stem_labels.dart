import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'stem_manifest.dart';

/// A stem's localized name from its manifest `title_key`. An unknown key
/// (a newer manifest) falls back to the stem id, so nothing breaks.
String stemTitle(AppLocalizations l, Stem stem) =>
    stemTitleForKey(l, stem.titleKey) ?? stem.id;

String? stemTitleForKey(AppLocalizations l, String key) => switch (key) {
  'sounds_stemRain' => l.sounds_stemRain,
  'sounds_stemOcean' => l.sounds_stemOcean,
  'sounds_stemWind' => l.sounds_stemWind,
  'sounds_stemNightInsects' => l.sounds_stemNightInsects,
  'sounds_stemSingingBowl' => l.sounds_stemSingingBowl,
  'sounds_stemChimes' => l.sounds_stemChimes,
  'sounds_stemBrownNoise' => l.sounds_stemBrownNoise,
  'sounds_stemPinkNoise' => l.sounds_stemPinkNoise,
  'sounds_stemDeepBell' => l.sounds_stemDeepBell,
  'sounds_stemMonsoonRoof' => l.sounds_stemMonsoonRoof,
  'sounds_stemStream' => l.sounds_stemStream,
  'sounds_stemFireplace' => l.sounds_stemFireplace,
  'sounds_stemDistantThunder' => l.sounds_stemDistantThunder,
  _ => null,
};

/// A quiet icon per stem (decorative: the name is always shown and read).
IconData stemIcon(Stem stem) => switch (stem.id) {
  'rain' => Icons.water_drop_outlined,
  'ocean' => Icons.waves_rounded,
  'wind' => Icons.air_rounded,
  'night_insects' => Icons.nights_stay_outlined,
  'singing_bowl' => Icons.radio_button_unchecked_rounded,
  'chimes' => Icons.notifications_none_rounded,
  'brown_noise' || 'pink_noise' => Icons.graphic_eq_rounded,
  'deep_bell' => Icons.notifications_outlined,
  'monsoon_roof' => Icons.roofing_rounded,
  'stream' => Icons.water_rounded,
  'fireplace' => Icons.local_fire_department_outlined,
  'distant_thunder' => Icons.thunderstorm_outlined,
  _ => Icons.music_note_outlined,
};

/// A size for the person, e.g. "8.1 MB" (always shown before a download).
String megabytes(AppLocalizations l, int bytes) {
  final mb = bytes / 1000000;
  final text = mb >= 10 ? mb.round().toString() : mb.toStringAsFixed(1);
  return l.sounds_megabytes(text);
}
