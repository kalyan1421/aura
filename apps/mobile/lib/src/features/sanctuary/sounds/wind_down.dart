import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import 'sound_rng.dart';
import 'stem_manifest.dart';

/// The night wind-down (PRD 06d): about 20 minutes of base stems that thin
/// out to silence. No narration, no voice track (REQ-SAN-13).
///
/// A lineup is a bed plus up to three more base stems. The lineup is picked
/// per Aura day: the same all day, and never the same two days running.
/// Each day's pick is a seeded jump of 1…N−1 places from the day before
/// through the list of every possible lineup, so consecutive days always
/// differ while the sequence still looks shuffled.
const Duration windDownLength = Duration(minutes: 20);

/// Day 0 of the reshuffle walk.
const LocalDay windDownEpoch = LocalDay(2026, 1, 1);

/// How many stems play besides the bed.
const int _others = 3;

/// Every lineup [pool] allows: each bed first, then every ordered choice of
/// up to three of the other stems. Sorted by id first, so the list (and so
/// the order for a day) depends only on which stems are in the pool.
List<List<String>> windDownLineups(List<Stem> pool) {
  final ids = [for (final s in pool) s.id]..sort();
  final beds = [
    for (final s in pool)
      if (s.role == StemRole.bed) s.id,
  ]..sort();
  final k = ids.length - 1 < _others ? ids.length - 1 : _others;
  final out = <List<String>>[];
  for (final bed in beds) {
    final rest = [for (final id in ids) if (id != bed) id];
    void pick(List<String> chosen) {
      if (chosen.length == k) {
        out.add([bed, ...chosen]);
        return;
      }
      for (final id in rest) {
        if (!chosen.contains(id)) pick([...chosen, id]);
      }
    }

    pick(const []);
  }
  return out;
}

int _dayHash(int i) =>
    SoundRng(0x9E3779B9 ^ ((i * 0x85EBCA6B) & 0xFFFFFFFF)).nextUint32();

/// The wind-down lineup for Aura day [day] (bed first).
List<String> windDownOrderFor(LocalDay day, List<Stem> pool) {
  final lineups = windDownLineups(pool);
  if (lineups.isEmpty) return const [];
  final n = lineups.length;
  if (n == 1) return lineups.first;
  final d = day.daysSince(windDownEpoch);
  var idx = _dayHash(d < 0 ? d : 0) % n;
  for (var i = 1; i <= d; i++) {
    idx = (idx + 1 + _dayHash(i) % (n - 1)) % n;
  }
  return lineups[idx];
}

/// One stem's volume over the wind-down: linear between keyframes
/// (seconds, gain).
@immutable
class WindDownTrack {
  const WindDownTrack(this.stemId, this.keys);

  final String stemId;
  final List<(double, double)> keys;

  double gainAt(double seconds) {
    if (seconds <= keys.first.$1) return keys.first.$2;
    for (var i = 1; i < keys.length; i++) {
      final (t1, g1) = keys[i];
      if (seconds <= t1) {
        final (t0, g0) = keys[i - 1];
        return g0 + (g1 - g0) * (seconds - t0) / (t1 - t0);
      }
    }
    return keys.last.$2;
  }
}

/// The shape of each slot of the lineup (seconds, gain). Everything fades
/// in over 4 s (≥ 2 s, no startle); the fourth stem joins at 4 min; then
/// the stems leave one by one and the bed fades to silence at 20 min. At
/// most four ever play together.
const List<List<(double, double)>> _slotShapes = [
  [(0, 0), (4, 0.55), (600, 0.5), (960, 0.42), (1200, 0)],
  [(0, 0), (4, 0.45), (420, 0.45), (540, 0)],
  [(0, 0), (4, 0.35), (660, 0.35), (780, 0)],
  [(0, 0), (240, 0), (270, 0.35), (840, 0.35), (960, 0)],
];

@immutable
class WindDownPlan {
  const WindDownPlan({
    required this.day,
    required this.order,
    required this.tracks,
  });

  final LocalDay day;

  /// The lineup, bed first.
  final List<String> order;
  final List<WindDownTrack> tracks;

  Duration get length => windDownLength;

  /// Each stem's volume (0…1) [elapsed] into the wind-down.
  Map<String, double> gainsAt(Duration elapsed) {
    final s = elapsed.inMilliseconds / 1000;
    return {for (final t in tracks) t.stemId: t.gainAt(s)};
  }

  bool isOver(Duration elapsed) => elapsed >= length;
}

/// Tonight's plan for Aura day [day] from the playable base stems in [pool].
WindDownPlan windDownPlanFor(LocalDay day, List<Stem> pool) {
  final order = windDownOrderFor(day, pool);
  return WindDownPlan(
    day: day,
    order: order,
    tracks: [
      for (var i = 0; i < order.length; i++)
        WindDownTrack(order[i], _slotShapes[i]),
    ],
  );
}
