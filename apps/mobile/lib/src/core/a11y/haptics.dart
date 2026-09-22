import 'package:flutter/services.dart';

/// Restrained haptics that honour Settings → Comfort → Haptics. Haptics are
/// an enhancement only, never the sole confirmation (design-system.md).
///
/// [enabled] is kept in step with `ComfortPrefs.haptics` by `AuraApp`, so
/// plain widgets without a `ref` can use it.
abstract final class AuraHaptics {
  static bool enabled = true;

  /// Selecting a mood, toggling a habit or chip.
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// A completed action (e.g. a check-in saved).
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }
}
