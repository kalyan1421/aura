import 'package:aura_domain/aura_domain.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'breath_pacer.dart';
import 'breathe_session_screen.dart';
import '../../core/providers.dart';
import 'calm_route.dart';
import 'sanctuary_session_log.dart';
import 'steps_activity_screen.dart';

/// Every Sanctuary activity (F15 v1). The enum name is a stable id, so a
/// later `/sanctuary/activity/:id` route can use [sanctuaryActivityById] and
/// [SanctuaryActivityInfo.screen].
enum SanctuaryActivity {
  /// Breathe: pick a rhythm and a length first.
  breathe,

  /// One minute of calm breathing (4/6), started at once.
  calmMinute,

  /// One minute of box breathing, started at once.
  boxMinute,

  /// 4-7-8 breathing (4 breaths), started at once.
  fourSevenEight,

  /// Three slow breaths with grounding cues (Storm's minute).
  land,

  /// One quiet minute with the orb (Moonlight's minute).
  stillness,

  /// Hand on heart (Rain's minute).
  heart,

  /// 5-4-3-2-1 senses.
  senses,

  /// Three small things.
  gratitude,

  /// Replay one good moment (Sunrise's minute).
  savour,
}

/// Looks up an activity by its id (the enum name), or `null`.
SanctuaryActivity? sanctuaryActivityById(String id) =>
    SanctuaryActivity.values.asNameMap()[id];

extension SanctuaryActivityInfo on SanctuaryActivity {
  String title(AppLocalizations l) => switch (this) {
    SanctuaryActivity.breathe => l.sanctuary_breatheCard,
    SanctuaryActivity.calmMinute => l.minute_calmTitle,
    SanctuaryActivity.boxMinute => l.minute_boxTitle,
    SanctuaryActivity.fourSevenEight => l.minute_478Title,
    SanctuaryActivity.land => l.minute_landTitle,
    SanctuaryActivity.stillness => l.minute_stillnessTitle,
    SanctuaryActivity.heart => l.heart_title,
    SanctuaryActivity.senses => l.senses_title,
    SanctuaryActivity.gratitude => l.gratitude_title,
    SanctuaryActivity.savour => l.minute_savourTitle,
  };

  String body(AppLocalizations l) => switch (this) {
    SanctuaryActivity.breathe => l.sanctuary_breatheCardBody,
    SanctuaryActivity.calmMinute => l.breathe_calmBody,
    SanctuaryActivity.boxMinute => l.breathe_boxBody,
    SanctuaryActivity.fourSevenEight => l.breathe_478Body,
    SanctuaryActivity.land => l.minute_landBody,
    SanctuaryActivity.stillness => l.minute_stillnessBody,
    SanctuaryActivity.heart => l.heart_card,
    SanctuaryActivity.senses => l.senses_card,
    SanctuaryActivity.gratitude => l.gratitude_card,
    SanctuaryActivity.savour => l.minute_savourBody,
  };

  IconData get icon => switch (this) {
    SanctuaryActivity.breathe ||
    SanctuaryActivity.calmMinute ||
    SanctuaryActivity.boxMinute ||
    SanctuaryActivity.fourSevenEight => Icons.air_rounded,
    SanctuaryActivity.land => Icons.self_improvement_rounded,
    SanctuaryActivity.stillness => Icons.spa_outlined,
    SanctuaryActivity.heart => Icons.volunteer_activism_outlined,
    SanctuaryActivity.senses => Icons.visibility_outlined,
    SanctuaryActivity.gratitude => Icons.auto_awesome_outlined,
    SanctuaryActivity.savour => Icons.local_florist_outlined,
  };

  /// The activity's full-screen page.
  Widget screen() => switch (this) {
    SanctuaryActivity.breathe => const BreatheSessionScreen(),
    SanctuaryActivity.calmMinute => const BreatheSessionScreen(autoStart: true),
    SanctuaryActivity.boxMinute => const BreatheSessionScreen(
      pattern: BreathPattern.box,
      autoStart: true,
    ),
    SanctuaryActivity.fourSevenEight => const BreatheSessionScreen(
      pattern: BreathPattern.fourSevenEight,
      autoStart: true,
    ),
    SanctuaryActivity.land => const BreatheSessionScreen(
      guide: BreathGuide.land,
    ),
    SanctuaryActivity.stillness => const BreatheSessionScreen(
      guide: BreathGuide.stillness,
    ),
    SanctuaryActivity.heart => const BreatheSessionScreen(
      guide: BreathGuide.heart,
    ),
    SanctuaryActivity.senses => const StepsActivityScreen(
      activity: StepsActivity.senses,
    ),
    SanctuaryActivity.gratitude => const StepsActivityScreen(
      activity: StepsActivity.gratitude,
    ),
    SanctuaryActivity.savour => const StepsActivityScreen(
      activity: StepsActivity.savour,
    ),
  };
}

/// Opens [activity] full screen, above the tab bar. Never starts on its own:
/// only a tap calls this. Notes (on this phone only) that Sanctuary was used,
/// for the wind-down reminder's in-app notice.
Future<void> openSanctuaryActivity(
  BuildContext context,
  SanctuaryActivity activity,
) {
  noteSanctuaryOpened(context);
  return pushCalm<void>(context, (_) => activity.screen());
}

/// Marks Sanctuary as opened now (local store only; best-effort).
void noteSanctuaryOpened(BuildContext context) {
  try {
    final c = ProviderScope.containerOf(context, listen: false);
    unawaited(
      markSanctuaryOpened(
        c.read(kvStoreProvider),
        c.read(timeContextProvider).now(),
      ),
    );
  } on Object {
    // No provider scope (a bare widget test): nothing to note.
  }
}

/// The grounding library as listed in the Sanctuary (PRD 06d: the three
/// grounding activities plus the two short ones "A minute for you" uses).
const List<SanctuaryActivity> groundingLibrary = [
  SanctuaryActivity.senses,
  SanctuaryActivity.heart,
  SanctuaryActivity.gratitude,
  SanctuaryActivity.stillness,
  SanctuaryActivity.savour,
];

/// What "Today's minute" rotates through, one per Aura day (REQ-SAN-06). Not
/// based on mood: "A minute for you" does that.
const List<SanctuaryActivity> todaysMinutePool = [
  SanctuaryActivity.calmMinute,
  SanctuaryActivity.senses,
  SanctuaryActivity.heart,
  SanctuaryActivity.boxMinute,
  SanctuaryActivity.gratitude,
  SanctuaryActivity.stillness,
  SanctuaryActivity.fourSevenEight,
  SanctuaryActivity.savour,
];

const LocalDay _minuteEpoch = LocalDay(2026, 1, 1);

/// Today's minute for Aura day [day]: the same all day, the next one
/// tomorrow. Deterministic and offline.
SanctuaryActivity todaysMinuteFor(LocalDay day) =>
    todaysMinutePool[day.daysSince(_minuteEpoch) % todaysMinutePool.length];
