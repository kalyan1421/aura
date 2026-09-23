import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import 'prompts.dart' show promptSeed;

/// The companion response's warm lines (PRD 06d, REQ-CMP-01…04): a pool of
/// the same size for every quadrant, plus a small neutral pool used after a
/// crisis sheet. Lines are identified by stable keys (`storm3`,
/// `neutral2`) so "no repeat within the last 5" survives a language change.
abstract final class CompanionLines {
  /// Lines per quadrant (REQ-CMP-03: equal pools, ≥ 8 per language at A).
  static const int perQuadrant = 8;

  /// Lines in the neutral pool (the same for every quadrant).
  static const int neutral = 4;

  /// A line isn't shown again until this many others have been.
  static const int noRepeatWithin = 5;

  /// The keys of [quadrant]'s pool, or of the neutral pool when `null`.
  static List<String> keys(Quadrant? quadrant) => [
    for (var i = 1; i <= (quadrant == null ? neutral : perQuadrant); i++)
      '${quadrant?.name ?? 'neutral'}$i',
  ];

  /// The line for [key] in the current language.
  static String text(AppLocalizations l, String key) => switch (key) {
    'storm1' => l.companion_storm1,
    'storm2' => l.companion_storm2,
    'storm3' => l.companion_storm3,
    'storm4' => l.companion_storm4,
    'storm5' => l.companion_storm5,
    'storm6' => l.companion_storm6,
    'storm7' => l.companion_storm7,
    'storm8' => l.companion_storm8,
    'rain1' => l.companion_rain1,
    'rain2' => l.companion_rain2,
    'rain3' => l.companion_rain3,
    'rain4' => l.companion_rain4,
    'rain5' => l.companion_rain5,
    'rain6' => l.companion_rain6,
    'rain7' => l.companion_rain7,
    'rain8' => l.companion_rain8,
    'moonlight1' => l.companion_moonlight1,
    'moonlight2' => l.companion_moonlight2,
    'moonlight3' => l.companion_moonlight3,
    'moonlight4' => l.companion_moonlight4,
    'moonlight5' => l.companion_moonlight5,
    'moonlight6' => l.companion_moonlight6,
    'moonlight7' => l.companion_moonlight7,
    'moonlight8' => l.companion_moonlight8,
    'sunrise1' => l.companion_sunrise1,
    'sunrise2' => l.companion_sunrise2,
    'sunrise3' => l.companion_sunrise3,
    'sunrise4' => l.companion_sunrise4,
    'sunrise5' => l.companion_sunrise5,
    'sunrise6' => l.companion_sunrise6,
    'sunrise7' => l.companion_sunrise7,
    'sunrise8' => l.companion_sunrise8,
    'neutral2' => l.companion_neutral2,
    'neutral3' => l.companion_neutral3,
    'neutral4' => l.companion_neutral4,
    _ => l.companion_neutral1,
  };
}

/// Picks the line for one check-in: from [quadrant]'s pool, or the neutral
/// pool after a crisis sheet ([afterCrisis]). Deterministic for a check-in
/// id ([seed]) and never one of the [recent] keys (the last
/// [CompanionLines.noRepeatWithin] shown), as long as the pool has another.
/// Pure.
String pickCompanionLine({
  required Quadrant quadrant,
  required bool afterCrisis,
  required int seed,
  List<String> recent = const [],
}) {
  final pool = CompanionLines.keys(afterCrisis ? null : quadrant);
  final window = recent.take(CompanionLines.noRepeatWithin).toSet();
  var fresh = [
    for (final k in pool)
      if (!window.contains(k)) k,
  ];
  // A pool no larger than the window (the neutral one): only never repeat
  // the line shown last.
  if (fresh.isEmpty) {
    fresh = [
      for (final k in pool)
        if (recent.isEmpty || k != recent.first) k,
    ];
  }
  return fresh[seed % fresh.length];
}

/// Remembers the last lines shown on this phone ([KvStore]; line keys only,
/// never a mood), so the same words don't come back check-in after
/// check-in.
class CompanionMemory {
  CompanionMemory(this._kv);

  final KvStore _kv;

  static const String _key = 'companion.recent_lines';

  /// Picks the line for [checkInId] and records it. A storage failure
  /// still returns a line (it just isn't remembered).
  Future<String> pickFor({
    required String checkInId,
    required Quadrant quadrant,
    required bool afterCrisis,
  }) async {
    var recent = const <String>[];
    try {
      final raw = await _kv.get(_key);
      if (raw != null) {
        recent = (jsonDecode(raw) as List<dynamic>).cast<String>();
      }
    } on Object {
      recent = const [];
    }
    final key = pickCompanionLine(
      quadrant: quadrant,
      afterCrisis: afterCrisis,
      seed: promptSeed(checkInId),
      recent: recent,
    );
    try {
      final next = [
        key,
        ...recent.where((k) => k != key),
      ].take(CompanionLines.noRepeatWithin).toList();
      await _kv.set(_key, jsonEncode(next));
    } on Object {
      // Not remembered; the line still shows.
    }
    return key;
  }
}
