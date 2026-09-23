import 'package:flutter/material.dart';

import '../../core/a11y/motion.dart';
import '../../core/theme/aura_tokens.dart';

/// A full-screen page with the app's calm transition (a soft fade with a
/// slight rise, as the router's pages have). Under Reduce Motion a plain
/// crossfade of at most 300 ms (REQ-A11Y-08), decided when it is pushed.
///
/// For screens pushed on top of whatever is showing (a Sanctuary activity,
/// a past check-in) rather than routed by URL.
Route<T> calmRoute<T>(BuildContext context, WidgetBuilder builder) {
  final reduce = reduceMotionOf(context);
  return PageRouteBuilder<T>(
    transitionDuration: reduce
        ? reducedMotionFade
        : const Duration(milliseconds: 380),
    reverseTransitionDuration: reduce
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AuraMotion.ease);
      if (reduceMotionOf(context)) {
        return FadeTransition(opacity: curved, child: child);
      }
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Pushes [builder]'s screen full screen, above any tab bar (the root
/// navigator), with [calmRoute].
Future<T?> pushCalm<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(calmRoute<T>(context, builder));
