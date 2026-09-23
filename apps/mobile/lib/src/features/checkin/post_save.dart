import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capsules/capsule_hooks.dart';

/// The F4 step of the check-in's post-save order (F1, PRD 06d): crisis sheet
/// → **mood-trigger capsule** → saved moment (Starlight, companion response,
/// "A minute for you", room offer). [crisisShown]: the crisis sheet opened
/// for this check-in, so a firing capsule is held (F4 crisis collision).
typedef MoodTriggerCapsuleStep = Future<void> Function(
  BuildContext context,
  WidgetRef ref, {
  required String checkInId,
  required Mood mood,
  required bool crisisShown,
});

/// The capsule step the check-in awaits: [runMoodTriggerCapsuleStep], which
/// the capsules feature fills in its own file. Tests override this to watch
/// the order; nothing else should.
final moodTriggerCapsuleStepProvider = Provider<MoodTriggerCapsuleStep>(
  (ref) => runMoodTriggerCapsuleStep,
);
