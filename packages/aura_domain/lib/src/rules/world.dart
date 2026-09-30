import '../local_day.dart';
import 'progression.dart' show isResting;

/// How grown a habit's world object is (RULES.md section 13). Permanent:
/// it depends only on the count of distinct logged days.
enum GrowthStage {
  seed,
  sprout,
  young,
  grown,
  flourishing,
  ancient;

  static GrowthStage fromName(String name) =>
      values.firstWhere((s) => s.name == name);
}

/// Distinct logged days at which each stage starts (after [GrowthStage.seed]).
const List<int> growthStageThresholds = [1, 4, 10, 25, 60];

/// The stage for [distinctLoggedDays] (negative counts clamp to seed).
GrowthStage growthStage(int distinctLoggedDays) {
  var stage = GrowthStage.seed;
  for (var i = 0; i < growthStageThresholds.length; i++) {
    if (distinctLoggedDays >= growthStageThresholds[i]) {
      stage = GrowthStage.values[i + 1];
    }
  }
  return stage;
}

/// How rested a committed habit's object looks. Reversible in one log;
/// never below [dormant] and never affects the ledger.
enum Vitality {
  thriving,
  dimmed,
  wilting,
  dormant;

  static Vitality fromName(String name) =>
      values.firstWhere((v) => v.name == name);
}

/// Youngest age at which opt-in decay is available (owner default).
const int minDecayAgeYears = 18;

/// Decay is chosen by the person and never available under 18.
bool decayEligible({required bool optedIn, required int ageYears}) =>
    optedIn && ageYears >= minDecayAgeYears;

/// Vitality of one habit object (RULES.md section 13). Whole Aura days missed
/// since the latest of the commitment day, the last log and a chosen pause;
/// today (still open) never counts. A `null` [committedFrom] means the habit
/// is not a commitment, so it never decays.
Vitality habitVitality({
  required bool decayActive,
  required LocalDay? committedFrom,
  required LocalDay? lastLogDay,
  required LocalDay? pausedThrough,
  required LocalDay today,
}) {
  if (!decayActive || committedFrom == null) return Vitality.thriving;
  var anchor = committedFrom;
  for (final d in [lastLogDay, pausedThrough]) {
    if (d != null && d.isAfter(anchor)) anchor = d;
  }
  final gap = today.daysSince(anchor) - 1;
  if (gap >= 7) return Vitality.dormant;
  if (gap >= 4) return Vitality.wilting;
  if (gap >= 2) return Vitality.dimmed;
  return Vitality.thriving;
}

/// The one-time "Your world is here" card in the personal universe (W04,
/// RULES.md section 13). True when the person is resting ([isResting]: three
/// or more Aura days without activity) and the card has not already been shown
/// for this absence ([shownFor] is the `lastActiveDay` it was shown for).
bool showWelcomeBack({
  required LocalDay? lastActiveDay,
  required LocalDay today,
  required LocalDay? shownFor,
}) => isResting(lastActiveDay, today) && shownFor != lastActiveDay;

/// The sky over the personal universe (W06, RULES.md section 13).
enum SkyPhase {
  dawn,
  day,
  dusk,
  night;

  static SkyPhase fromName(String name) =>
      values.firstWhere((p) => p.name == name);
}

/// The sky for a wall-clock hour on the phone (any integer, normalised mod
/// 24). Decoration only: no location, no permission, never mood or health.
SkyPhase skyPhase(int localHour) {
  final h = ((localHour % 24) + 24) % 24;
  if (h >= 5 && h < 7) return SkyPhase.dawn;
  if (h >= 7 && h < 17) return SkyPhase.day;
  if (h >= 17 && h < 19) return SkyPhase.dusk;
  return SkyPhase.night;
}

/// How many stepping stones the island has to light.
const int pathStoneCount = 16;

/// Stones that glow after [steps] today: one per thousand, up to
/// [pathStoneCount]. Warmth only: null, negative or zero steps is a plain
/// path, never a dim one. The number itself is never shown or kept.
int litStones(int? steps) {
  if (steps == null || steps <= 0) return 0;
  final stones = steps ~/ 1000;
  return stones > pathStoneCount ? pathStoneCount : stones;
}

/// How a world object looked the last time the person saw it (T04).
class WorldLook {
  const WorldLook(this.stage, this.vitality);
  final GrowthStage stage;
  final Vitality vitality;

  @override
  bool operator ==(Object other) =>
      other is WorldLook && other.stage == stage && other.vitality == vitality;

  @override
  int get hashCode => Object.hash(stage, vitality);
}

/// A world object that deserves a one-time moment.
enum WorldChangeKind {
  /// New to the grove.
  sprout,

  /// Reached a higher growth stage.
  grow,

  /// Was resting and is thriving again.
  wake;

  static WorldChangeKind fromName(String name) =>
      values.firstWhere((k) => k.name == name);
}

typedef WorldChange = ({String key, WorldChangeKind kind});

/// What changed since the person last saw the world (RULES.md section 13
/// `changes`). A `null` [seen] is the baseline: the first look is never a
/// moment. At most one change per key, in [current] order; a lower stage or a
/// plant starting to rest is never a change. Presentation only.
List<WorldChange> worldChanges({
  required Map<String, WorldLook>? seen,
  required List<({String key, WorldLook look})> current,
}) {
  if (seen == null) return const [];
  return [
    for (final c in current)
      if (_changeOf(seen[c.key], c.look) case final kind?)
        (key: c.key, kind: kind),
  ];
}

WorldChangeKind? _changeOf(WorldLook? before, WorldLook now) {
  if (before == null) return WorldChangeKind.sprout;
  if (now.stage.index > before.stage.index) return WorldChangeKind.grow;
  if (before.vitality != Vitality.thriving &&
      now.vitality == Vitality.thriving) {
    return WorldChangeKind.wake;
  }
  return null;
}
