import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';

/// The avatar's response to a live check-in (PRD 06d, REQ-CMP-01/02): a
/// gentle lift, a shimmer and a soft glow tinted with the check-in's
/// quadrant, all within [total] (≤ 2 s). Duration, curves and brightness are
/// the same for every quadrant (the quadrant tokens share one lightness
/// band); only the tint changes. Under Reduce Motion nothing moves at all.
class CompanionReaction extends StatelessWidget {
  const CompanionReaction({
    super.key,
    required this.quadrant,
    required this.child,
  });

  final Quadrant quadrant;

  /// The avatar.
  final Widget child;

  /// The whole reaction: lift and settle, shimmer, glow in and out.
  static const Duration total = Duration(milliseconds: 1400);

  /// Opacity of the tint in the shimmer and the glow (equal for all).
  static const double tintAlpha = 0.5;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return child;
    final tint = AuraColors.quadrant(quadrant);
    return Stack(
      alignment: Alignment.center,
      children: [
        // A soft glow behind the avatar: in, then gone.
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Animate(
                key: const ValueKey('companion-glow'),
                effects: [
                  const FadeEffect(
                    begin: 0,
                    end: 1,
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  ),
                  const FadeEffect(
                    delay: Duration(milliseconds: 600),
                    begin: 1,
                    end: 0,
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                  ),
                ],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        tint.withValues(alpha: tintAlpha * 0.6),
                        tint.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Animate(
          key: const ValueKey('companion-reaction'),
          effects: [
            // Lift…
            const MoveEffect(
              begin: Offset.zero,
              end: Offset(0, -8),
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            ),
            // …and settle.
            const MoveEffect(
              delay: Duration(milliseconds: 500),
              begin: Offset.zero,
              end: Offset(0, 8),
              duration: Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
            ),
            ShimmerEffect(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 1300),
              color: tint.withValues(alpha: tintAlpha),
            ),
          ],
          child: child,
        ),
      ],
    );
  }
}

/// The one warm line under the avatar: announced once to screen readers
/// (live region). It follows the shimmer in, or crossfades in within 300 ms
/// under Reduce Motion (REQ-CMP-02).
class CompanionLine extends StatelessWidget {
  const CompanionLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final line = Text(
      text,
      key: const ValueKey('companion-line'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: reduce
          ? line.animate().fadeIn(duration: reducedMotionFade)
          : line.animate().fadeIn(
              delay: const Duration(milliseconds: 500),
              duration: const Duration(milliseconds: 400),
            ),
    );
  }
}
