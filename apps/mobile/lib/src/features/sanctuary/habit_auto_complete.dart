import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../onboarding/gate_controller.dart';

/// Whether F2 auto-complete may write for this person. The same rule as the
/// support sheet's grounding minute: an onboarded person who isn't behind the
/// under-13 lock. Nothing is written from onboarding (including the first
/// check-in) or the Blocked screen.
bool habitAutoCompleteAllowed(GateState gate) =>
    !gate.isBlocked && gate.onboarded;

/// F2 auto-complete of the preset [presetKey] (Breathe after 60 s of a
/// Sanctuary breathing session, Journal after a note of 50+ characters):
/// ticks off today's habit when [habitAutoCompleteAllowed], the habit is
/// shown on Home and not done yet. Idempotent and never un-marks. Never
/// throws: a failure here must not disturb what the person is doing.
///
/// Returns whether a new completion was written (say so to the person only
/// then).
Future<bool> autoCompleteHabitToday(WidgetRef ref, String presetKey) async {
  try {
    // Everything is read before the first await: the caller may be gone by
    // the time the write finishes.
    final gate = ref.read(gateControllerProvider);
    if (!habitAutoCompleteAllowed(gate)) return false;
    final habits = ref.read(habitRepositoryProvider);
    final sync = ref.read(syncControllerProvider);
    final logged = await habits.completeToday(presetKey);
    if (logged) sync.notifyLocalWrite();
    return logged;
  } on Object catch (e) {
    debugPrint('habits: $presetKey auto-complete skipped (${e.runtimeType})');
    return false;
  }
}
