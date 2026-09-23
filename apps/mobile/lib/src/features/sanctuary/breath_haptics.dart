import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/a11y/haptics.dart';
import 'breath_pacer.dart';

/// The haptic rhythm of a breathing session, so the breath can be followed
/// with eyes closed. Haptics are an enhancement only: the phase is always
/// shown and announced too (design-system.md).
abstract interface class BreathHaptics {
  /// [phase] just began.
  void phaseStarted(BreathPhase phase);
}

/// PRD 06d: one soft pattern per phase — rising as the inhale begins
/// (a tick, then a tap), falling as the exhale begins (a tap, then a tick),
/// nothing on a hold. Through [AuraHaptics], so Settings › Comfort ›
/// Haptics (and the system setting) turns it off like every other haptic.
class AuraBreathHaptics implements BreathHaptics {
  const AuraBreathHaptics();

  /// The gap between the two pulses of a pattern.
  static const Duration gap = Duration(milliseconds: 120);

  @override
  void phaseStarted(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        AuraHaptics.selection();
        Timer(gap, AuraHaptics.light);
      case BreathPhase.exhale:
        AuraHaptics.light();
        Timer(gap, AuraHaptics.selection);
      case BreathPhase.holdIn || BreathPhase.holdOut:
        break;
    }
  }
}

/// Where breathing sessions send their haptic cues (tests record them).
final breathHapticsProvider = Provider<BreathHaptics>(
  (ref) => const AuraBreathHaptics(),
);
