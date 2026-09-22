import 'package:freezed_annotation/freezed_annotation.dart';

import 'aura_stage.dart';

part 'aura_avatar_state.freezed.dart';

/// Cosmetic ids (F12). Visual only; never change stage or traits.
typedef CosmeticId = String;

/// The single input of the avatar renderer (PRD F2). The renderer is a pure
/// function of this state + elapsed time.
///
/// Out-of-range values are clamped, never thrown: `ringCount`/`glowLevel`
/// to 0–3, `constellationStars` to 0–12, and `hue` wrapped into [0, 360)
/// (non-finite hues fall back to [defaultHue]).
@freezed
class AuraAvatarState with _$AuraAvatarState {
  AuraAvatarState({
    this.stage = AuraStage.spark,
    double hue = defaultHue,
    this.isResting = false,
    int ringCount = 0,
    int glowLevel = 0,
    int constellationStars = 0,
    Set<CosmeticId> equippedCosmetics = const {},
  }) : hue = normalizeHue(hue),
       ringCount = ringCount.clamp(0, maxTraitLevel),
       glowLevel = glowLevel.clamp(0, maxTraitLevel),
       constellationStars = constellationStars.clamp(0, maxStars),
       equippedCosmetics = Set.unmodifiable(equippedCosmetics);

  /// Neutral starting hue (a soft silver-lavender) used before any mood data.
  static const double defaultHue = 250;
  static const int maxTraitLevel = 3;
  static const int maxStars = 12;

  final AuraStage stage;

  /// 0–360°, from the 14-day mood mix.
  final double hue;

  /// Resting Nebula look (a look, not a penalty).
  final bool isResting;

  /// Starlight rings (Breathe unlocks), 0–3.
  final int ringCount;

  /// Cosmic glow (Sleep on time unlocks), 0–3.
  final int glowLevel;

  /// Constellation stars, 0–12.
  final int constellationStars;

  final Set<CosmeticId> equippedCosmetics;

  /// Wraps any finite hue into [0, 360).
  static double normalizeHue(double hue) {
    if (!hue.isFinite) return defaultHue;
    final h = hue % 360;
    return h < 0 ? h + 360 : h;
  }
}
