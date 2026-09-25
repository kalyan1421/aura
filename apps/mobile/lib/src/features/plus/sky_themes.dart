import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/plus.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../sanctuary/sounds/saved_mixes.dart';

/// Personal sky themes (F12 cosmetics; contracts/api/v1-billing.md §1). They
/// only recolour the person's OWN Home, Sanctuary and Insights backgrounds —
/// never anything a stranger sees. Procedural (a gradient + washes, drawn by
/// [CosmicBackground]); contrast with text is kept by staying dark.
enum SkyTier { free, plus, cosmetic }

@immutable
class SkyTheme {
  const SkyTheme({
    required this.id,
    required this.tier,
    required this.palette,
    required this.soundscape,
    this.stardust,
  });

  final String id;
  final SkyTier tier;
  final SkyPalette palette;

  /// The suggested soundscape preset ([soundscapes]).
  final String soundscape;

  /// Stardust price (cosmetics only).
  final int? stardust;

  String get productId => 'sky_$id';

  String name(AppLocalizations l) => switch (id) {
    'aurora' => l.plus_skyAurora,
    'monsoon_dusk' => l.plus_skyMonsoonDusk,
    'first_light' => l.plus_skyFirstLight,
    'lantern_festival' => l.plus_skyLanternFestival,
    'deep_ocean' => l.plus_skyDeepOcean,
    'meteor_shower' => l.plus_skyMeteorShower,
    _ => l.plus_skyNight,
  };
}

/// Same list and tiers as the server catalogue (server/aura-api/src/billing/
/// catalogue.ts; test/plus_catalogue_test.dart keeps them in step).
const List<SkyTheme> skyThemes = [
  SkyTheme(
    id: 'night',
    tier: SkyTier.free,
    palette: SkyPalette.night,
    soundscape: 'night_air',
  ),
  SkyTheme(
    id: 'aurora',
    tier: SkyTier.plus,
    soundscape: 'high_wind',
    palette: SkyPalette(
      top: Color(0xFF071A24),
      middle: Color(0xFF0B2A33),
      bottom: Color(0xFF050F18),
      wash: Color(0xFF3FD6A8),
      accent: Color(0xFF6B8CFF),
    ),
  ),
  SkyTheme(
    id: 'monsoon_dusk',
    tier: SkyTier.plus,
    soundscape: 'monsoon',
    palette: SkyPalette(
      top: Color(0xFF151B2E),
      middle: Color(0xFF1C2438),
      bottom: Color(0xFF0B0F1A),
      wash: Color(0xFF7D8FB8),
      accent: Color(0xFF4D6C8F),
    ),
  ),
  SkyTheme(
    id: 'first_light',
    tier: SkyTier.cosmetic,
    stardust: 10,
    soundscape: 'bells',
    palette: SkyPalette(
      top: Color(0xFF1A1633),
      middle: Color(0xFF2A1F3D),
      bottom: Color(0xFF120E22),
      wash: Color(0xFFE8A87C),
      accent: Color(0xFFB57EDC),
    ),
  ),
  SkyTheme(
    id: 'lantern_festival',
    tier: SkyTier.cosmetic,
    stardust: 30,
    soundscape: 'night_air',
    palette: SkyPalette(
      top: Color(0xFF140F24),
      middle: Color(0xFF1E1530),
      bottom: Color(0xFF0C0916),
      wash: Color(0xFFF2B35B),
      accent: Color(0xFFE07A5F),
    ),
  ),
  SkyTheme(
    id: 'deep_ocean',
    tier: SkyTier.cosmetic,
    stardust: 50,
    soundscape: 'shore',
    palette: SkyPalette(
      top: Color(0xFF041425),
      middle: Color(0xFF062038),
      bottom: Color(0xFF020A14),
      wash: Color(0xFF2A9DB5),
      accent: Color(0xFF1F5FA8),
    ),
  ),
  SkyTheme(
    id: 'meteor_shower',
    tier: SkyTier.cosmetic,
    stardust: 100,
    soundscape: 'high_wind',
    palette: SkyPalette(
      top: Color(0xFF0B0B1F),
      middle: Color(0xFF14143A),
      bottom: Color(0xFF06061A),
      wash: Color(0xFFC9B8FF),
      accent: Color(0xFF8FD3FF),
    ),
  ),
];

SkyTheme skyById(String id) =>
    skyThemes.firstWhere((s) => s.id == id, orElse: () => skyThemes.first);

/// Soundscape presets a sky can pair with: base stems only, so pairing never
/// needs Plus (base Sounds are never paywalled).
const Map<String, List<String>> soundscapes = {
  'night_air': ['night_insects', 'wind'],
  'high_wind': ['wind', 'chimes'],
  'monsoon': ['rain', 'brown_noise'],
  'bells': ['singing_bowl', 'chimes'],
  'shore': ['ocean', 'wind'],
};

String soundscapeName(AppLocalizations l, String? id) => switch (id) {
  'night_air' => l.plus_soundscapeNightAir,
  'high_wind' => l.plus_soundscapeHighWind,
  'monsoon' => l.plus_soundscapeMonsoon,
  'bells' => l.plus_soundscapeBells,
  'shore' => l.plus_soundscapeShore,
  _ => l.plus_soundscapeNone,
};

/// The soundscape as a mix the Sounds player can play (equal, gentle levels).
SavedMix? soundscapeMix(String? id) {
  final stems = soundscapes[id];
  if (stems == null) return null;
  return SavedMix([for (final s in stems) (s, 0.6)]);
}

/// The person's equipped sky palette (the server's answer; a sky that isn't
/// available any more — Plus ended, a refund — falls back to the night sky).
final personalSkyProvider = Provider<SkyPalette>((ref) {
  final e = ref.watch(entitlementProvider);
  if (!e.availableSkies.contains(e.sky)) return SkyPalette.night;
  return skyById(e.sky).palette;
});

/// [CosmicBackground] in the person's own sky. Only for their own spaces:
/// Home, Sanctuary and Insights.
class PersonalSkyBackground extends ConsumerWidget {
  const PersonalSkyBackground({super.key, required this.child, this.tint});

  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CosmicBackground(
    palette: ref.watch(personalSkyProvider),
    tint: tint,
    child: child,
  );
}

/// A small preview swatch of a sky (the sky screen).
class SkyPreview extends StatelessWidget {
  const SkyPreview({
    super.key,
    required this.palette,
    this.size = 56,
    this.height,
  });

  final SkyPalette palette;

  /// Width (and height, unless [height] is given).
  final double size;
  final double? height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: height ?? size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.m),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.middle, palette.bottom],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuraRadius.m),
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.6),
            colors: [
              palette.wash.withValues(alpha: 0.45),
              palette.wash.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );
}
