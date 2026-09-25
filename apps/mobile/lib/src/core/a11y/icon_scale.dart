import 'package:flutter/widgets.dart';

/// The most an icon grows with the person's text size (design critique:
/// "icons scale with text"). Past this, words keep growing but icons stay
/// put, so a 200% screen still has room for its content.
const double maxIconScale = 1.5;

/// [base] scaled with the text scale, clamped to 1–[maxIconScale]x, so an
/// icon beside large words is not a tiny speck.
double scaledIconSize(BuildContext context, double base) {
  final factor = MediaQuery.textScalerOf(context).scale(base) / base;
  return base * factor.clamp(1.0, maxIconScale);
}
