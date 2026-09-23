import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import '../../core/providers.dart';

/// Where a guided prompt is shown.
enum PromptSurface {
  /// The check-in note (and a past check-in's note).
  checkInNote,

  /// The F4 capsule composer ("Future you").
  capsule,
}

/// Guided prompts (competitor plan #12, PRD REQ-CHK-05): an optional,
/// rotating writing prompt shown only as an empty field's hint text. It is
/// never saved, synced or counted toward a length limit, and typing hides
/// it. Every quadrant has a pool of the same size and warmth; no prompt asks
/// "why" or for detail about self-harm.
///
/// The pool for [surface] and [quadrant] (the mood picked, or for a mood
/// capsule the feeling it waits for). Check-in notes: the quadrant's 3
/// prompts, or 3 general ones before a mood is picked. Capsules: the
/// quadrant's own prompt plus the 3 general capsule prompts, or just those 3.
List<String> promptPool(
  AppLocalizations l,
  PromptSurface surface, {
  Quadrant? quadrant,
}) => switch ((surface, quadrant)) {
  (PromptSurface.checkInNote, null) => [
    l.prompt_note1,
    l.prompt_note2,
    l.prompt_note3,
  ],
  (PromptSurface.checkInNote, Quadrant.storm) => [
    l.prompt_storm1,
    l.prompt_storm2,
    l.prompt_storm3,
  ],
  (PromptSurface.checkInNote, Quadrant.rain) => [
    l.prompt_rain1,
    l.prompt_rain2,
    l.prompt_rain3,
  ],
  (PromptSurface.checkInNote, Quadrant.moonlight) => [
    l.prompt_moonlight1,
    l.prompt_moonlight2,
    l.prompt_moonlight3,
  ],
  (PromptSurface.checkInNote, Quadrant.sunrise) => [
    l.prompt_sunrise1,
    l.prompt_sunrise2,
    l.prompt_sunrise3,
  ],
  (PromptSurface.capsule, final q) => [
    if (q != null) _capsuleFor(l, q),
    l.prompt_capsule1,
    l.prompt_capsule2,
    l.prompt_capsule3,
  ],
};

String _capsuleFor(AppLocalizations l, Quadrant q) => switch (q) {
  Quadrant.storm => l.prompt_capsuleStorm,
  Quadrant.rain => l.prompt_capsuleRain,
  Quadrant.moonlight => l.prompt_capsuleMoonlight,
  Quadrant.sunrise => l.prompt_capsuleSunrise,
};

/// One prompt for [surface] / [quadrant]: [seed] picks where to start in the
/// pool (so each draft gets its own, and a rebuild never changes it) and
/// [turn] rotates from there ("Another prompt" adds 1). Pure: the same
/// arguments always give the same prompt, in the current language.
///
/// ```dart
/// // In the capsule composer (F4):
/// final hint = promptFor(
///   AppLocalizations.of(context),
///   surface: PromptSurface.capsule,
///   quadrant: targetQuadrant, // null for a date capsule
///   seed: promptSeed(draftId),
///   turn: anotherTaps,
/// );
/// ```
String promptFor(
  AppLocalizations l, {
  required PromptSurface surface,
  Quadrant? quadrant,
  required int seed,
  int turn = 0,
}) {
  final pool = promptPool(l, surface, quadrant: quadrant);
  return pool[(seed + turn) % pool.length];
}

/// A stable, non-negative seed for a client id (FNV-1a), so a check-in or a
/// capsule draft keeps its prompt across rebuilds and app restarts.
int promptSeed(String id) {
  var h = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// This phone's switch for guided prompts ([KvStore], "true" = off). A
/// preference of the phone, not of the account: nothing about it is synced,
/// and it survives sign-out ([KvKeys.deviceScoped]).
const String guidedPromptsOffKey = KvKeys.guidedPromptsOff;

/// Whether guided prompts show (on unless switched off in Settings).
final guidedPromptsEnabledProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watch(guidedPromptsOffKey)
      .map((v) => v != 'true'),
);

/// Settings › "Writing prompts": turns guided prompts on or off.
Future<void> setGuidedPromptsEnabled(WidgetRef ref, {required bool enabled}) =>
    ref.read(kvStoreProvider).set(guidedPromptsOffKey, enabled ? null : 'true');
