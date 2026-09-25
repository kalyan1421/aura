import 'package:meta/meta.dart';

import '../avatar/aura_stage.dart';
import '../local_day.dart';
import 'capsules.dart' show addYearsClamped;

/// F13 keepsakes and share milestones (contracts/rules/RULES.md §11, vectors
/// `keepsakes.json`). NestJS awards keepsakes (authoritative); the app uses
/// the catalogue for the private box and [sharePrompt] / [capsuleYears] for
/// the one Home share prompt. [earnedKeepsakes] is here so both engines keep
/// passing the same vectors.
enum KeepsakeSource {
  capsuleSeals,
  capsuleOpens,
  glowDays,
  rippleSessions,
  lanternNights,
  sanctuarySeconds,
}

@immutable
final class KeepsakeDef {
  const KeepsakeDef(this.key, this.source, this.threshold);

  final String key;
  final KeepsakeSource source;
  final int threshold;
}

/// The catalogue, in display order. The key is all that is stored (with the
/// day it was earned).
const List<KeepsakeDef> keepsakeCatalogue = [
  KeepsakeDef('capsule_sealed_first', KeepsakeSource.capsuleSeals, 1),
  KeepsakeDef('capsule_opened_first', KeepsakeSource.capsuleOpens, 1),
  KeepsakeDef('glow_days_7', KeepsakeSource.glowDays, 7),
  KeepsakeDef('glow_days_30', KeepsakeSource.glowDays, 30),
  KeepsakeDef('glow_days_100', KeepsakeSource.glowDays, 100),
  KeepsakeDef('glow_days_365', KeepsakeSource.glowDays, 365),
  KeepsakeDef('ripples_first', KeepsakeSource.rippleSessions, 1),
  KeepsakeDef('lantern_hours_1', KeepsakeSource.lanternNights, 1),
  KeepsakeDef('lantern_hours_10', KeepsakeSource.lanternNights, 10),
  KeepsakeDef('lantern_hours_50', KeepsakeSource.lanternNights, 50),
  KeepsakeDef('sanctuary_minutes_60', KeepsakeSource.sanctuarySeconds, 3600),
  KeepsakeDef('sanctuary_minutes_300', KeepsakeSource.sanctuarySeconds, 18000),
  KeepsakeDef('sanctuary_minutes_1000', KeepsakeSource.sanctuarySeconds, 60000),
];

/// Catalogue position of [key], or `null` for a key this build doesn't know
/// (a newer server): such a keepsake is simply not shown.
int? keepsakeIndex(String key) {
  for (var i = 0; i < keepsakeCatalogue.length; i++) {
    if (keepsakeCatalogue[i].key == key) return i;
  }
  return null;
}

/// One dated event of a source: an Aura day and how much it adds.
@immutable
final class KeepsakeEvent {
  const KeepsakeEvent(this.day, this.amount);

  final LocalDay day;
  final int amount;
}

@immutable
final class EarnedKeepsake {
  const EarnedKeepsake(this.key, this.day);

  final String key;
  final LocalDay day;

  @override
  bool operator ==(Object other) =>
      other is EarnedKeepsake && other.key == key && other.day == day;

  @override
  int get hashCode => Object.hash(key, day);

  @override
  String toString() => 'EarnedKeepsake($key, ${day.toIso()})';
}

List<KeepsakeEvent> _normalise(
  KeepsakeSource source,
  List<KeepsakeEvent> events,
) {
  final positive = events.where((e) => e.amount > 0);
  final list = source == KeepsakeSource.glowDays
      // 1 per distinct day, whatever the amount.
      ? {for (final e in positive) e.day}
            .map((d) => KeepsakeEvent(d, 1))
            .toList()
      : positive.toList();
  // Stable sort by day.
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = a.$2.day.compareTo(b.$2.day);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final x in indexed) x.$2];
}

/// RULES.md §11 `earned`: every keepsake the [sources] reach, with the day
/// each was reached, in catalogue order. [lanternCounted] is the Lantern Hour
/// tally counted before `sources[lanternNights]`.
List<EarnedKeepsake> earnedKeepsakes(
  Map<KeepsakeSource, List<KeepsakeEvent>> sources, {
  int lanternCounted = 0,
}) {
  final out = <EarnedKeepsake>[];
  final sorted = <KeepsakeSource, List<KeepsakeEvent>>{};
  for (final def in keepsakeCatalogue) {
    final counted = def.source == KeepsakeSource.lanternNights
        ? (lanternCounted < 0 ? 0 : lanternCounted)
        : 0;
    if (def.threshold <= counted) continue;
    final events = sorted.putIfAbsent(
      def.source,
      () => _normalise(def.source, sources[def.source] ?? const []),
    );
    var total = counted;
    for (final e in events) {
      total += e.amount;
      if (total >= def.threshold) {
        out.add(EarnedKeepsake(def.key, e.day));
        break;
      }
    }
  }
  return out;
}

/// RULES.md §11 `capsule_years`: anniversaries of the first seal's day that
/// are on or before [today] (29 Feb → 28 Feb in a common year).
int capsuleYears(LocalDay? firstSealed, LocalDay today) {
  if (firstSealed == null || firstSealed.isAfter(today)) return 0;
  var years = 0;
  while (!addYearsClamped(firstSealed, years + 1).isAfter(today)) {
    years++;
  }
  return years;
}

/// Lifetime glow-day milestones with a share card (PRD F13 "Glow milestone").
const List<int> glowMilestones = [7, 30, 100, 365];

@immutable
final class SharePromptResult {
  const SharePromptResult(this.prompt, this.offer);

  /// The one milestone to offer now, or `null`.
  final String? prompt;

  /// Every milestone that is new now; all are marked offered together.
  final List<String> offer;
}

/// RULES.md §11 `share_prompt`: one prompt for the highest new milestone;
/// every new milestone is marked offered at once (offered once, several at
/// once → one prompt). Glow milestones are never the prompt while
/// [hideGlow] (Comfort › hide streak number) is on.
SharePromptResult sharePrompt({
  required AuraStage stage,
  required int lifetimeGlowDays,
  required int capsuleYears,
  required Set<String> offered,
  required bool hideGlow,
}) {
  final evolution = [
    for (final s in AuraStage.values)
      if (s.index >= AuraStage.ember.index && s.index <= stage.index)
        'evolution:${s.name}',
  ].where((id) => !offered.contains(id)).toList();
  final glow = [
    for (final n in glowMilestones)
      if (n <= lifetimeGlowDays) 'glow:$n',
  ].where((id) => !offered.contains(id)).toList();
  final anniversaries = [
    for (var y = 1; y <= capsuleYears; y++) 'capsule_anniversary:$y',
  ].where((id) => !offered.contains(id)).toList();
  final prompt = evolution.isNotEmpty
      ? evolution.last
      : (!hideGlow && glow.isNotEmpty)
      ? glow.last
      : anniversaries.isNotEmpty
      ? anniversaries.last
      : null;
  return SharePromptResult(prompt, [...evolution, ...glow, ...anniversaries]);
}
