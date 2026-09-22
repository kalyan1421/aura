// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: contracts/moods.json
// Regenerate: cd packages/aura_domain && dart run tool/gen_catalog.dart

import 'mood.dart';

/// The four mood quadrants (energy x pleasantness).
enum Quadrant {
  storm(
    energy: Energy.high,
    pleasant: false,
    theme: 'lighthouse',
    hueDeg: 275.0,
  ),
  rain(
    energy: Energy.low,
    pleasant: false,
    theme: 'rain_sanctuary',
    hueDeg: 175.0,
  ),
  moonlight(
    energy: Energy.low,
    pleasant: true,
    theme: 'midnight_observatory',
    hueDeg: 210.0,
  ),
  sunrise(
    energy: Energy.high,
    pleasant: true,
    theme: 'sunrise_deck',
    hueDeg: 45.0,
  );

  const Quadrant({
    required this.energy,
    required this.pleasant,
    required this.theme,
    required this.hueDeg,
  });

  /// Energy axis of the grid.
  final Energy energy;

  /// Pleasantness axis of the grid.
  final bool pleasant;

  /// Room theme id for this quadrant.
  final String theme;

  /// Hue anchor used by the hue rule (RULES.md section 6).
  final double hueDeg;
}

/// The fixed 16-mood catalogue, in grid order (`sort`).
const List<Mood> moodCatalog = <Mood>[
  Mood(
    id: 'overwhelmed',
    quadrant: Quadrant.storm,
    sort: 0,
    names: <String, String>{
      'en': 'Overwhelmed',
      'te': 'ఉక్కిరిబిక్కిరిగా',
      'te-Latn': 'Ukkiribikkiriga',
      'hi': 'बेहाल',
      'hi-Latn': 'Behaal',
    },
  ),
  Mood(
    id: 'anxious',
    quadrant: Quadrant.storm,
    sort: 1,
    names: <String, String>{
      'en': 'Anxious',
      'te': 'ఆందోళనగా',
      'te-Latn': 'Aandolanaga',
      'hi': 'बेचैन',
      'hi-Latn': 'Bechain',
    },
  ),
  Mood(
    id: 'restless',
    quadrant: Quadrant.storm,
    sort: 2,
    names: <String, String>{
      'en': 'Restless',
      'te': 'అశాంతిగా',
      'te-Latn': 'Ashaanthiga',
      'hi': 'अशांत',
      'hi-Latn': 'Ashaant',
    },
  ),
  Mood(
    id: 'frustrated',
    quadrant: Quadrant.storm,
    sort: 3,
    names: <String, String>{
      'en': 'Frustrated',
      'te': 'విసుగ్గా',
      'te-Latn': 'Visugga',
      'hi': 'झुंझलाहट',
      'hi-Latn': 'Jhunjhlahat',
    },
  ),
  Mood(
    id: 'melancholy',
    quadrant: Quadrant.rain,
    sort: 4,
    names: <String, String>{
      'en': 'Melancholy',
      'te': 'దిగులుగా',
      'te-Latn': 'Digulugaa',
      'hi': 'उदास',
      'hi-Latn': 'Udaas',
    },
  ),
  Mood(
    id: 'drained',
    quadrant: Quadrant.rain,
    sort: 5,
    names: <String, String>{
      'en': 'Drained',
      'te': 'అలసిపోయినట్టు',
      'te-Latn': 'Alasipoyinattu',
      'hi': 'थकान',
      'hi-Latn': 'Thakaan',
    },
  ),
  Mood(
    id: 'lonely',
    quadrant: Quadrant.rain,
    sort: 6,
    names: <String, String>{
      'en': 'Lonely',
      'te': 'ఒంటరిగా',
      'te-Latn': 'Ontariga',
      'hi': 'अकेलापन',
      'hi-Latn': 'Akelapan',
    },
  ),
  Mood(
    id: 'numb',
    quadrant: Quadrant.rain,
    sort: 7,
    names: <String, String>{
      'en': 'Numb',
      'te': 'మొద్దుబారినట్టు',
      'te-Latn': 'Moddubaarinattu',
      'hi': 'सुन्न',
      'hi-Latn': 'Sunn',
    },
  ),
  Mood(
    id: 'calm',
    quadrant: Quadrant.moonlight,
    sort: 8,
    names: <String, String>{
      'en': 'Calm',
      'te': 'ప్రశాంతంగా',
      'te-Latn': 'Prashaanthanga',
      'hi': 'शांत',
      'hi-Latn': 'Shaant',
    },
  ),
  Mood(
    id: 'content',
    quadrant: Quadrant.moonlight,
    sort: 9,
    names: <String, String>{
      'en': 'Content',
      'te': 'తృప్తిగా',
      'te-Latn': 'Trupthiga',
      'hi': 'संतुष्ट',
      'hi-Latn': 'Santusht',
    },
  ),
  Mood(
    id: 'quietly_hopeful',
    quadrant: Quadrant.moonlight,
    sort: 10,
    names: <String, String>{
      'en': 'Quietly Hopeful',
      'te': 'మెల్లగా ఆశగా',
      'te-Latn': 'Mellaga aashaga',
      'hi': 'थोड़ी उम्मीद',
      'hi-Latn': 'Thodi ummeed',
    },
  ),
  Mood(
    id: 'grateful',
    quadrant: Quadrant.moonlight,
    sort: 11,
    names: <String, String>{
      'en': 'Grateful',
      'te': 'కృతజ్ఞతగా',
      'te-Latn': 'Kruthagnathaga',
      'hi': 'आभारी',
      'hi-Latn': 'Aabhaari',
    },
  ),
  Mood(
    id: 'joyful',
    quadrant: Quadrant.sunrise,
    sort: 12,
    names: <String, String>{
      'en': 'Joyful',
      'te': 'ఆనందంగా',
      'te-Latn': 'Aanandanga',
      'hi': 'खुश',
      'hi-Latn': 'Khush',
    },
  ),
  Mood(
    id: 'excited',
    quadrant: Quadrant.sunrise,
    sort: 13,
    names: <String, String>{
      'en': 'Excited',
      'te': 'ఉత్సాహంగా',
      'te-Latn': 'Utsaahanga',
      'hi': 'उत्साहित',
      'hi-Latn': 'Utsaahit',
    },
  ),
  Mood(
    id: 'proud',
    quadrant: Quadrant.sunrise,
    sort: 14,
    names: <String, String>{
      'en': 'Proud',
      'te': 'గర్వంగా',
      'te-Latn': 'Garvanga',
      'hi': 'गर्व',
      'hi-Latn': 'Garv',
    },
  ),
  Mood(
    id: 'energised',
    quadrant: Quadrant.sunrise,
    sort: 15,
    names: <String, String>{
      'en': 'Energised',
      'te': 'హుషారుగా',
      'te-Latn': 'Hushaaruga',
      'hi': 'जोश में',
      'hi-Latn': 'Josh mein',
    },
  ),
];

/// Preset habit keys (`habits.preset_key`).
abstract final class PresetHabitKeys {
  static const String hydrate = 'hydrate';
  static const String sleepOnTime = 'sleep_on_time';
  static const String move = 'move';
  static const String breathe = 'breathe';
  static const String journal = 'journal';
  static const String goOutside = 'go_outside';
}

/// The six preset habits, in display order.
const List<PresetHabit> presetHabits = <PresetHabit>[
  PresetHabit(key: 'hydrate', names: <String, String>{'en': 'Hydrate'}),
  PresetHabit(
    key: 'sleep_on_time',
    names: <String, String>{'en': 'Sleep on time'},
  ),
  PresetHabit(key: 'move', names: <String, String>{'en': 'Move'}),
  PresetHabit(key: 'breathe', names: <String, String>{'en': 'Breathe'}),
  PresetHabit(key: 'journal', names: <String, String>{'en': 'Journal'}),
  PresetHabit(key: 'go_outside', names: <String, String>{'en': 'Go outside'}),
];

/// The 10 default context tags offered after picking a mood.
const List<String> contextTags = <String>[
  'study',
  'work',
  'family',
  'friends',
  'sleep',
  'health',
  'money',
  'love',
  'alone',
  'commute',
];
