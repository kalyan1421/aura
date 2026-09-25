import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';

/// Aura design tokens: a calm cosmic night. Every quadrant accent is tuned to
/// the same lightness/chroma band so no feeling looks "worse" than another.
abstract final class AuraColors {
  // Night sky, deepest → raised.
  static const Color skyDeep = Color(0xFF05060F);
  static const Color sky = Color(0xFF0A0C1D);
  static const Color skyHigh = Color(0xFF10132A);
  static const Color surface = Color(0xFF151935);
  static const Color surfaceHigh = Color(0xFF1D2245);
  static const Color outline = Color(0xFF2C3264);
  static const Color hairline = Color(0x1FFFFFFF);

  /// Boundary of an interactive control in its idle state (unselected chip
  /// borders, the off switch's track outline, input borders): at least 3:1
  /// against [sky], [skyHigh] and [surface] (WCAG 1.4.11). [outline] stays
  /// for decorative hairlines and drag handles.
  static const Color controlOutline = Color(0xFF6268A8);

  // Text (all ≥ 4.5:1 on [sky]).
  static const Color text = Color(0xFFF2F0FF);
  static const Color textSoft = Color(0xFFBDB9E0);
  static const Color textMuted = Color(0xFF9591BD);

  // Light.
  static const Color starlight = Color(0xFFF7E6B5);
  static const Color lavender = Color(0xFFC9BFFF);
  static const Color accent = Color(0xFFBBAAFF);
  static const Color onAccent = Color(0xFF15112E);

  /// Warm lantern tone for "I need help now": visible, never alarming red.
  static const Color lantern = Color(0xFFF6C1A4);
  static const Color onLantern = Color(0xFF2A1510);

  /// Warm danger tone for destructive actions (Delete my account): text and
  /// border on the night sky, ≥ 4.5:1 on [sky] and [surface]. Never used for
  /// feelings, missed days or personal data.
  static const Color danger = Color(0xFFFF8A80);

  // Quadrant accents (bright) and their deep tile grounds.
  static const Color sunrise = Color(0xFFF3BE67);
  static const Color rain = Color(0xFF5ACBBE);
  static const Color moonlight = Color(0xFFAFC3F0);
  static const Color storm = Color(0xFFAE93FA);

  static const Color sunriseDeep = Color(0xFF2E2213);
  static const Color rainDeep = Color(0xFF0E2A2B);
  static const Color moonlightDeep = Color(0xFF161F3A);
  static const Color stormDeep = Color(0xFF221A43);

  static Color quadrant(Quadrant q) => switch (q) {
    Quadrant.sunrise => sunrise,
    Quadrant.rain => rain,
    Quadrant.moonlight => moonlight,
    Quadrant.storm => storm,
  };

  static Color quadrantDeep(Quadrant q) => switch (q) {
    Quadrant.sunrise => sunriseDeep,
    Quadrant.rain => rainDeep,
    Quadrant.moonlight => moonlightDeep,
    Quadrant.storm => stormDeep,
  };
}

abstract final class AuraSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20;
}

abstract final class AuraRadius {
  static const double s = 12;
  static const double m = 18;
  static const double l = 26;
  static const double pill = 999;
}

abstract final class AuraMotion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration calm = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 900);
  static const Curve ease = Curves.easeOutCubic;
}

/// Colour for a hue angle, at the lightness band used for glows.
Color glowColorForHue(
  double hueDeg, {
  double saturation = 0.62,
  double value = 1,
}) => HSVColor.fromAHSV(1, hueDeg % 360, saturation, value).toColor();
