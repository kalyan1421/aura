import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// F4 step in the check-in post-save order (F1): crisis sheet → **mood-
/// trigger capsule** → Starlight, "A minute for you", room offer.
///
/// Opens a matching mood-trigger capsule if one fires for [mood]. When
/// [crisisShown] is true the capsule is held (F4 crisis collision rule):
/// offer "A note from past you is waiting. Open now, or later?".
///
/// Placeholder until the capsules feature lands; the check-in screen already
/// calls it in the right place.
Future<void> runMoodTriggerCapsuleStep(
  BuildContext context,
  WidgetRef ref, {
  required String checkInId,
  required Mood mood,
  required bool crisisShown,
}) async {}
