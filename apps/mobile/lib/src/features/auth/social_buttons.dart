import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';

/// Branded sign-in button. Its colours are Google's, not Aura tokens, and
/// must not be restyled (developers.google.com/identity/branding-guidelines).
///
/// 56 dp tall like the primary "Email me a code" button, pill-shaped like every
/// Aura button (Google allows matching the app's corner radius), full width,
/// and grows with the text size (200%, Telugu) instead of clipping.
const double socialButtonHeight = 56;

/// "Continue with Google", Google's dark theme: fill #131314, 1 px #8E918F
/// stroke inside, label #E3E3E3, the standard colour "G" (never
/// monochrome, never a stand-in icon). Google's spec (G 20, label 14/20 in
/// a 44 pt iOS button; 12/10/12 or 16/12/16 horizontal padding on Android /
/// iOS) is scaled uniformly to Aura's 56 dp, so the G keeps its proportions.
///
/// Label font: Google specifies Google Sans Medium; it isn't bundled (see
/// docs/setup/social-sign-in.md), so the platform font at medium weight is
/// used (Roboto on Android).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const Color fill = Color(0xFF131314);
  static const Color stroke = Color(0xFF8E918F);
  static const Color labelColor = Color(0xFFE3E3E3);

  /// Google's iOS button is 44 pt tall.
  static const double _scale = socialButtonHeight / 44;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final g = _scaled(context, 20 * _scale);
    return _BrandButton(
      fill: fill,
      stroke: stroke,
      foreground: labelColor,
      paddingStart: (ios ? 16 : 12) * _scale,
      paddingEnd: (ios ? 16 : 12) * _scale,
      onPressed: onPressed,
      busy: busy,
      logo: SizedBox.square(
        dimension: g,
        child: const CustomPaint(painter: GoogleGMarkPainter()),
      ),
      gap: (ios ? 12 : 10) * _scale * (g / (20 * _scale)),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: base.copyWith(
          fontSize: 14 * _scale,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: labelColor,
        ),
      ),
    );
  }
}

/// A logo size that follows the text size (up to 200%), so logo and title
/// keep their proportion at every setting.
double _scaled(BuildContext context, double size) {
  final scaled = MediaQuery.textScalerOf(context).scale(size);
  return scaled.clamp(size, size * 2);
}

/// Shared shell: pill, min 56 dp, logo + title centred as one group. While
/// this button's sign-in runs, a small progress ring sits in the end
/// padding; both sides keep room for it, so nothing moves or resizes.
class _BrandButton extends StatelessWidget {
  const _BrandButton({
    required this.fill,
    required this.foreground,
    required this.paddingStart,
    required this.paddingEnd,
    required this.onPressed,
    required this.busy,
    required this.logo,
    required this.gap,
    required this.label,
    this.stroke,
  });

  final Color fill;
  final Color? stroke;
  final Color foreground;
  final double paddingStart;
  final double paddingEnd;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget logo;
  final double gap;
  final Widget label;

  static const double _ring = 16;
  static const double _ringInset = AuraSpace.m;

  /// Horizontal room kept on both sides so the ring never covers the title.
  static const double _reserve = _ringInset + _ring + AuraSpace.xs;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final shape = StadiumBorder(
      side: stroke == null
          ? BorderSide.none
          : BorderSide(
              color: stroke!,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        // Another sign-in is running: dimmed, colours unchanged.
        opacity: enabled || busy ? 1 : 0.5,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: socialButtonHeight),
          child: Material(
            color: fill,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: shape,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      math.max(paddingStart, _reserve),
                      AuraSpace.s,
                      math.max(paddingEnd, _reserve),
                      AuraSpace.s,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ExcludeSemantics(child: logo),
                        SizedBox(width: gap),
                        Flexible(child: label),
                      ],
                    ),
                  ),
                  if (busy)
                    PositionedDirectional(
                      end: _ringInset,
                      child: SizedBox.square(
                        dimension: _ring,
                        child: CircularProgressIndicator(
                          key: const ValueKey('social-busy'),
                          strokeWidth: 2,
                          color: foreground,
                          semanticsLabel: AppLocalizations.of(context)
                              .signin_busy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "or" between the email field and the social buttons.
class SignInOrDivider extends StatelessWidget {
  const SignInOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        const Expanded(child: Divider(color: AuraColors.outline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.m),
          child: Text(
            AppLocalizations.of(context).signin_or,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
        ),
        const Expanded(child: Divider(color: AuraColors.outline, height: 1)),
      ],
    );
  }
}

/// Google's standard colour "G", drawn as vector from Google's pre-approved
/// sign-in asset (signin-assets.zip, "Theme=Dark, Show text=No"): the G
/// shape masks a softly blurred conic sweep (red → blue → teal → green →
/// yellow → orange) with blurred blue / red / pink highlights. Coordinates
/// are the asset's, in a 20 × 20 box. Don't restyle or recolour.
class GoogleGMarkPainter extends CustomPainter {
  const GoogleGMarkPainter();

  // Conic sweep stops (asset: `conic-gradient(from 90deg, …)` under a −45°
  // transform), as fractions of a turn.
  static const List<Color> _sweepColors = [
    Color(0xFFFF4641),
    Color(0xFFFF4641),
    Color(0xFF3186FF),
    Color(0xFF3186FF),
    Color(0xFF00A5B7),
    Color(0xFF0EBC5F),
    Color(0xFF0EBC5F),
    Color(0xFF6CC400),
    Color(0xFFFFCC00),
    Color(0xFFFFD314),
    Color(0xFFFFCC00),
    Color(0xFFFF6A2B),
    Color(0xFFFD4641),
    Color(0xFFFF4641),
    Color(0xFFFF4641),
  ];
  static const List<double> _sweepStops = [
    0,
    4.14555 / 360,
    39.154 / 360,
    72.0044 / 360,
    96.7463 / 360,
    120.897 / 360,
    154.722 / 360,
    179.136 / 360,
    203.588 / 360,
    226.915 / 360,
    251.688 / 360,
    273.129 / 360,
    289.305 / 360,
    359.593 / 360,
    1,
  ];

  /// Highlights: (cx, cy, rx, ry, rotation°, colour), drawn in order.
  static const List<(double, double, double, double, double, Color)>
  _highlights = [
    (10.0496, 10.2413, 5.39634, 2.83537, 24.4473, Color(0xFF3186FF)),
    (23.3538, 8.2155, 7.43918, 3.09357, 0, Color(0xFF3186FF)),
    (15.2744, 6.2195, 7.40854, 2.37805, 0, Color(0xFFFF4641)),
    (19.5427, 2.9268, 7.40854, 2.37805, 0, Color(0xFFFF5B8B)),
    (14.4817, 9.878, 8.5061, 3.10976, 0, Color(0xFF3186FF)),
    (15.1842, 4.0197, 4.53882, 2.37805, -28.6599, Color(0xFFFF4641)),
  ];

  /// The G outline, scaled by [k] (asset units → logical px).
  static Path _gPath(double k) {
    void c(Path path, List<double> v) => path.cubicTo(
      v[0] * k,
      v[1] * k,
      v[2] * k,
      v[3] * k,
      v[4] * k,
      v[5] * k,
    );
    final path = Path()
      ..moveTo(19.3987 * k, 8.1814 * k)
      ..lineTo(9.9849 * k, 8.1814 * k)
      ..lineTo(9.9849 * k, 12.0445 * k)
      ..lineTo(15.3598 * k, 12.0445 * k);
    c(path, [15.1286, 13.294, 14.4294, 14.3596, 13.3676, 15.0712]);
    c(path, [12.4746, 15.6716, 11.3266, 16.0211, 9.9849, 16.0211]);
    c(path, [7.3864, 16.0211, 5.1823, 14.2666, 4.3947, 11.9004]);
    c(path, [4.1952, 11.2989, 4.0853, 10.6599, 4.0853, 9.9983]);
    c(path, [4.0853, 9.3367, 4.1952, 8.6966, 4.3947, 8.0962]);
    c(path, [5.1823, 5.7311, 7.3864, 3.9755, 9.9849, 3.9755]);
    c(path, [11.4524, 3.9755, 12.767, 4.4816, 13.8039, 5.4713]);
    path.lineTo(16.6653 * k, 2.6057 * k);
    c(path, [14.936, 0.9908, 12.6786, 0, 9.9849, 0]);
    c(path, [6.0832, 0, 2.705, 2.2414, 1.0618, 5.5076]);
    c(path, [0.383, 6.8592, 0, 8.3834, 0, 9.9994]);
    c(path, [0, 11.6155, 0.383, 13.1396, 1.0618, 14.4913]);
    c(path, [2.705, 17.7597, 6.0832, 20, 9.9849, 20]);
    c(path, [12.6797, 20, 14.9485, 19.1137, 16.6018, 17.5861]);
    c(path, [18.4887, 15.8452, 19.5732, 13.2702, 19.5732, 10.2275]);
    c(path, [19.5732, 9.5182, 19.5131, 8.835, 19.3987, 8.1825]);
    path
      ..lineTo(19.3987 * k, 8.1814 * k)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width, size.height) / 20;
    canvas.save();
    canvas.translate((size.width - 20 * k) / 2, (size.height - 20 * k) / 2);
    canvas.clipPath(_gPath(k));

    // 1. The conic sweep, blurred (asset: feGaussianBlur stdDeviation 1).
    final centre = Offset(9.6819 * k, 9.7927 * k);
    final sweep = const SweepGradient(
      colors: _sweepColors,
      stops: _sweepStops,
      transform: GradientRotation(-math.pi / 4),
    ).createShader(Rect.fromCircle(center: centre, radius: 14 * k));
    canvas.saveLayer(
      Rect.fromLTWH(-3 * k, -3 * k, 26 * k, 26 * k),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: k, sigmaY: k),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(10.12826 * k, 9.79264 * k),
        width: 25.73808 * k,
        height: 25.77192 * k,
      ),
      Paint()..shader = sweep,
    );
    canvas.restore();

    // 2. The highlights, each blurred the same way.
    for (final (cx, cy, rx, ry, degrees, color) in _highlights) {
      canvas.save();
      canvas.translate(cx * k, cy * k);
      if (degrees != 0) canvas.rotate(degrees * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 2 * rx * k,
          height: 2 * ry * k,
        ),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, k),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GoogleGMarkPainter oldDelegate) => false;
}
