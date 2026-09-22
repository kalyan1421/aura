import 'package:flutter/widgets.dart';

/// True when motion should be reduced: the OS setting (iOS Reduce Motion,
/// Android "Remove animations") or the in-app Comfort toggle, which `AuraApp`
/// merges into `MediaQuery.disableAnimations` (REQ-A11Y-08).
///
/// Under reduced motion: no scale/shimmer/pulse/parallax/particle drift;
/// necessary transitions become crossfades of at most 300 ms
/// (design-system.md "Motion and feedback"). `flutter_animate` effects do not
/// check this themselves — guard them with this function.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Longest crossfade allowed under reduced motion.
const Duration reducedMotionFade = Duration(milliseconds: 300);
