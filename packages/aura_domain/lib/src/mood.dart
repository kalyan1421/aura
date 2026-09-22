import 'package:meta/meta.dart';

import 'catalog.g.dart';

export 'catalog.g.dart';

/// Energy axis of the mood grid.
enum Energy { high, low }

/// Locale tags Aura ships (`profiles.ui_locale`).
abstract final class AuraLocales {
  static const String en = 'en';
  static const String te = 'te';
  static const String teLatn = 'te-Latn';
  static const String hi = 'hi';
  static const String hiLatn = 'hi-Latn';

  static const List<String> all = [en, te, teLatn, hi, hiLatn];

  /// Room language pool for a UI locale (contracts/api/v1.md).
  static String languagePool(String uiLocale) => switch (uiLocale) {
    te || teLatn => 'te',
    hi || hiLatn => 'hi',
    _ => 'en',
  };
}

/// One of the 16 fixed moods.
@immutable
final class Mood {
  const Mood({
    required this.id,
    required this.quadrant,
    required this.sort,
    required this.names,
  });

  final String id;
  final Quadrant quadrant;
  final int sort;

  /// Localised names keyed by locale tag (`en`, `te`, `te-Latn`, ...).
  final Map<String, String> names;

  /// Name in [localeTag], falling back to English (never a raw key).
  String nameFor(String localeTag) =>
      names[localeTag] ?? names[AuraLocales.en] ?? id;

  @override
  bool operator ==(Object other) => other is Mood && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Mood($id)';
}

/// A preset habit from the catalogue.
@immutable
final class PresetHabit {
  const PresetHabit({required this.key, required this.names});

  final String key;
  final Map<String, String> names;

  String nameFor(String localeTag) =>
      names[localeTag] ?? names[AuraLocales.en] ?? key;

  @override
  bool operator ==(Object other) => other is PresetHabit && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

final Map<String, Mood> _byId = {for (final m in moodCatalog) m.id: m};

/// Looks up a mood by id; `null` for unknown ids.
Mood? moodById(String id) => _byId[id];

/// The four moods of [quadrant], in grid order.
List<Mood> moodsIn(Quadrant quadrant) =>
    moodCatalog.where((m) => m.quadrant == quadrant).toList(growable: false);

/// Parses a quadrant name (`storm`, `rain`, `moonlight`, `sunrise`).
Quadrant? quadrantByName(String name) {
  for (final q in Quadrant.values) {
    if (q.name == name) return q;
  }
  return null;
}
