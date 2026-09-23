import 'dart:math' as math;

import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/checkin/mood_grid.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 contrast of composited check-in colours (REQ-A11Y-03; design
/// system "Recheck contrast when tint washes, opacity … are introduced").
void main() {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [fg] at [alpha] over an opaque [bg].
  Color over(Color fg, double alpha, Color bg) => Color.from(
    alpha: 1,
    red: fg.r * alpha + bg.r * (1 - alpha),
    green: fg.g * alpha + bg.g * (1 - alpha),
    blue: fg.b * alpha + bg.b * (1 - alpha),
  );

  test('onAccent text on the tinted Save button is ≥ 4.5:1 in every '
      'quadrant', () {
    for (final q in Quadrant.values) {
      final ratio = contrast(AuraColors.onAccent, checkInSaveColor(q));
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$q: $ratio');
    }
  });

  test('a dimmed (unselected) tile label is ≥ 4.5:1 over its tile ground, '
      'even on the brightest part of the card', () {
    const o = moodTileDimmedOpacity;
    for (final q in Quadrant.values) {
      for (final active in [false, true]) {
        final card = quadrantCardGlow(q, active: active);
        // The whole tile fades: its white wash and its label.
        final ground = over(
          const Color(0xFFFFFFFF),
          moodTileWashAlpha * o,
          card,
        );
        final label = over(AuraColors.text, o, card);
        final ratio = contrast(label, ground);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$q active=$active: $ratio',
        );
      }
    }
  });

  test('a selected tile label is ≥ 4.5:1 over its tinted ground', () {
    for (final q in Quadrant.values) {
      final card = quadrantCardGlow(q, active: true);
      final ground = over(AuraColors.quadrant(q), 0.22, card);
      final ratio = contrast(AuraColors.text, ground);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$q: $ratio');
    }
  });
}
