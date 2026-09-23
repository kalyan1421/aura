import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'capsule_opening.dart';
import 'capsule_providers.dart';

/// F4 step in the check-in post-save order (F1): crisis sheet → **mood-
/// trigger capsule** → Starlight, "A minute for you", room offer.
///
/// Evaluates RULES.md §9 `trigger` on this phone for the saved check-in
/// [checkInId] (a live one: backfills fire nothing): the oldest armed
/// capsule (sealed ≥ 24 h ago or re-armed) waiting for [mood] or its
/// quadrant, unless the global 7-day cooldown is running. In-app only,
/// never a push (PRD 12-notifications).
///
/// * A match fires at once (the cooldown starts) and the card asks "You
///   left a note for a moment like this. Open now or later?". "Later" keeps
///   it, fired and unopened, in Future you.
/// * When [crisisShown] (the support sheet opened for this check-in) the
///   match is **held** (F4 crisis collision rule): the card says "A note from
///   past you is waiting. Open now, or later?"; "Now" counts as the fire,
///   "Later" leaves it armed with no cooldown.
///
/// Resolves when the person is done (the next post-save step waits). Never
/// throws: a failure here must not disturb the check-in.
Future<void> runMoodTriggerCapsuleStep(
  BuildContext context,
  WidgetRef ref, {
  required String checkInId,
  required Mood mood,
  required bool crisisShown,
}) async {
  try {
    // Read before any await: the caller may be gone by the end.
    final repo = ref.read(capsuleRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final pick = await repo.pickFor(
      checkInId: checkInId,
      mood: mood,
      crisis: crisisShown,
    );
    if (pick.isNone || !context.mounted) return;

    final fired = pick.fire;
    if (fired != null) {
      // Fired as the card appears: the cooldown starts now.
      if (!await repo.fire(fired)) return;
      sync.notifyLocalWrite();
      if (!context.mounted) return;
      final now = await showCapsuleTriggerCard(context, held: false);
      if (now && context.mounted) await openCapsule(context, fired);
      return;
    }

    final held = pick.hold!;
    final now = await showCapsuleTriggerCard(context, held: true);
    // "Later": nothing is recorded — it stays armed, no cooldown.
    if (!now || !context.mounted) return;
    // "Now" counts as the fire.
    if (!await repo.fire(held)) return;
    sync.notifyLocalWrite();
    if (context.mounted) await openCapsule(context, held);
  } on Object catch (e) {
    debugPrint('capsules: trigger step skipped (${e.runtimeType})');
  }
}
