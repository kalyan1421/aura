import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../avatar/aura_stage.dart';
import '../catalog.g.dart';
import '../local_day.dart';
import 'aura_day.dart';

// ---------------------------------------------------------------------------
// 2. Credit eligibility (RULES.md section 2)
// ---------------------------------------------------------------------------

/// Allowed device-clock skew into the future.
const Duration maxClockSkew = Duration(minutes: 5);

/// Events older than this when received earn nothing.
const Duration maxEventAge = Duration(days: 30);

/// Whether an event earns Starlight and streak credit.
///
/// Ineligible events are still stored; they award 0 and are not active-day
/// evidence.
bool isEligible({
  required DateTime deviceTs,
  required DateTime serverNow,
  required String timezone,
  required LocalDay localDay,
}) {
  if (deviceTs.isAfter(serverNow.add(maxClockSkew))) return false;
  if (serverNow.difference(deviceTs) > maxEventAge) return false;
  return localDay == auraDay(deviceTs, timezone);
}

// ---------------------------------------------------------------------------
// 3. Starlight per Aura day (RULES.md section 3)
// ---------------------------------------------------------------------------

abstract final class StarlightRules {
  static const int firstCheckIn = 10;
  static const int extraCheckIn = 2;

  /// Check-ins #2 and #3 earn [extraCheckIn]; #4+ earn 0.
  static const int awardedCheckIns = 3;
  static const int habit = 5;
  static const int dailyCap = 60;
}

enum StarlightEventType { checkIn, habit }

/// One event of a single Aura day, for [starlightAwards].
@immutable
final class StarlightEvent {
  const StarlightEvent.checkIn({this.eligible = true})
    : type = StarlightEventType.checkIn,
      habitId = null;

  const StarlightEvent.habit(String this.habitId, {this.eligible = true})
    : type = StarlightEventType.habit;

  final StarlightEventType type;
  final String? habitId;
  final bool eligible;
}

/// Awards for one Aura day's events, in the order given (the caller passes
/// them in `deviceTs` order). Returns one award per event.
List<int> starlightAwards(Iterable<StarlightEvent> events) {
  var total = 0;
  var checkIns = 0;
  final habitsAwarded = <String>{};
  final awards = <int>[];
  for (final e in events) {
    var base = 0;
    if (e.eligible) {
      switch (e.type) {
        case StarlightEventType.checkIn:
          checkIns++;
          if (checkIns == 1) {
            base = StarlightRules.firstCheckIn;
          } else if (checkIns <= StarlightRules.awardedCheckIns) {
            base = StarlightRules.extraCheckIn;
          }
        case StarlightEventType.habit:
          if (habitsAwarded.add(e.habitId!)) base = StarlightRules.habit;
      }
    }
    final award = math.min(base, StarlightRules.dailyCap - total);
    total += award;
    awards.add(award);
  }
  return awards;
}

// ---------------------------------------------------------------------------
// 4. Stage & constellation (RULES.md section 4)
// ---------------------------------------------------------------------------

/// Stage for an all-time Starlight [total].
AuraStage stageFor(int total) {
  var stage = AuraStage.spark;
  for (final s in AuraStage.values) {
    if (total >= s.threshold) stage = s;
  }
  return stage;
}

const int maxConstellationStars = 12;
const int starlightPerConstellationStar = 500;

/// Constellation stars for an all-time Starlight [total] (0–12).
int constellationStarsFor(int total) {
  final base = AuraStage.constellation.threshold;
  if (total < base) return 0;
  return math.min(
    maxConstellationStars,
    (total - base) ~/ starlightPerConstellationStar,
  );
}

// ---------------------------------------------------------------------------
// 5. Traits (RULES.md section 5)
// ---------------------------------------------------------------------------

const List<int> traitThresholds = [5, 20, 50];

/// Trait level 0–3 from lifetime completions (Breathe → rings, Sleep → glow).
int traitLevel(int completions) =>
    traitThresholds.where((t) => completions >= t).length;

// ---------------------------------------------------------------------------
// 6. Hue (RULES.md section 6)
// ---------------------------------------------------------------------------

/// Number of Aura days (ending today) that feed the hue.
const int hueWindowDays = 14;

/// Circular weighted mean of quadrant hue anchors, in [0, 360); `null` if
/// there is no data or the mix cancels out (the renderer holds its hue).
double? hueFor(Map<Quadrant, int> counts) {
  var x = 0.0;
  var y = 0.0;
  counts.forEach((q, w) {
    if (w <= 0) return;
    final theta = q.hueDeg * math.pi / 180;
    x += w * math.cos(theta);
    y += w * math.sin(theta);
  });
  if (math.sqrt(x * x + y * y) < 1e-9) return null;
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg % 360 + 360) % 360;
}

/// Hue from check-ins whose Aura day falls in the last [hueWindowDays] days
/// ending on [today] (inclusive).
double? hueFromCheckIns(
  Iterable<({LocalDay day, Quadrant quadrant})> checkIns,
  LocalDay today,
) {
  final counts = <Quadrant, int>{};
  for (final c in checkIns) {
    final age = today.daysSince(c.day);
    if (age < 0 || age >= hueWindowDays) continue;
    counts.update(c.quadrant, (v) => v + 1, ifAbsent: () => 1);
  }
  return hueFor(counts);
}

// ---------------------------------------------------------------------------
// 8. Resting Nebula (RULES.md section 8)
// ---------------------------------------------------------------------------

/// Idle Aura days after the last active one before the Nebula shows.
const int restingAfterDays = 3;

/// Whether the avatar rests in the Nebula on [currentAuraDay].
bool isResting(LocalDay? lastActiveDay, LocalDay currentAuraDay) =>
    lastActiveDay != null &&
    currentAuraDay.daysSince(lastActiveDay) >= restingAfterDays;
