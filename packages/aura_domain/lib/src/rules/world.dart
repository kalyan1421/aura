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
