import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../checkin/quadrant_glyph.dart' show quadrantName;
import 'widget_store.dart';

/// How many further widget check-ins today the widget can show an award
/// for; after that it shows the award for the last one (0 once capped).
const int widgetAwardLookahead = 4;

/// Everything the app tells the widget, before it is turned into copy.
/// Nothing here is a note, tag, voice, reflection, capsule content or DOB:
/// only what the PRD lets the widget show (F11 "Shows").
@immutable
class WidgetDisplayInput {
  const WidgetDisplayInput({
    required this.ready,
    required this.owner,
    required this.today,
    required this.timezone,
    this.checkedInToday = false,
    this.lastMood,
    this.showLastMood = false,
    this.discreet = false,
    this.streakDays,
    this.capsuleWaiting = false,
    this.triggerMoodIds = const {},
    this.awardsToday = const [],
    this.awardsFreshDay = const [],
    this.hasAvatar = false,
  });

  /// Onboarded and not under the under-13 lock. Otherwise the widget shows
  /// only "Open Aura to continue", input off (F11 edge case).
  final bool ready;

  /// Opaque token for the signed-in person on this phone; the widget stamps
  /// it on each check-in so another account never imports it.
  final String owner;
  final LocalDay today;
  final String timezone;
  final bool checkedInToday;

  /// The newest live check-in's mood; sent only with [showLastMood].
  final Mood? lastMood;

  /// "Show my last mood" (off by default).
  final bool showLastMood;

  /// Discreet widget: plain star, no "Aura", no mood words (off by default).
  final bool discreet;

  /// Glow streak to show; `null` when Settings hides it (F3 hideStreak).
  final int? streakDays;

  /// A capsule is ready to open (it opens in the app only).
  final bool capsuleWaiting;

  /// Moods (ids) a widget check-in would fire a mood-trigger capsule for
  /// right now; the widget then says "Something from past you is waiting".
  final Set<String> triggerMoodIds;

  /// Provisional Starlight for the next widget check-ins on [today], and on
  /// a new Aura day the app hasn't seen yet (computed by the shared rules,
  /// RULES.md §3, so the widget never re-implements them).
  final List<int> awardsToday;
  final List<int> awardsFreshDay;

  /// An avatar PNG is published with this state.
  final bool hasAvatar;
}

/// The widget's awards for the next [widgetAwardLookahead] check-ins, given
/// the progression [events] already on this phone (RULES.md §3: 10 for the
/// first, 2 for the next 2, daily cap 60 across check-ins and habits).
({List<int> today, List<int> freshDay}) widgetAwards(
  List<ProgressEvent> events,
  LocalDay today,
  String timezone,
) {
  final todays = events.where((e) => e.localDay == today).toList()
    ..sort((a, b) {
      final c = a.deviceTs.compareTo(b.deviceTs);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final starlight = [
    for (final e in todays)
      e.kind == ProgressKind.checkIn
          ? StarlightEvent.checkIn(eligible: _live(e, timezone))
          : StarlightEvent.habit(e.habitId!, eligible: _live(e, timezone)),
  ];
  final next = List.filled(
    widgetAwardLookahead,
    const StarlightEvent.checkIn(),
  );
  final all = starlightAwards([...starlight, ...next]);
  return (
    today: all.sublist(starlight.length),
    freshDay: starlightAwards(next),
  );
}

bool _live(ProgressEvent e, String timezone) {
  try {
    return auraDay(e.deviceTs, e.timezone ?? timezone) == e.localDay;
  } catch (_) {
    return true;
  }
}

/// `aura.widget.display` for [input], in the app's language [l] /
/// [localeTag]. All copy is rendered here, so the widget never formats text
/// and follows the app's language (Tenglish and Hinglish included).
Map<String, Object?> buildWidgetDisplay(
  WidgetDisplayInput input,
  AppLocalizations l,
  String localeTag,
) {
  final strings = <String, String>{
    'prompt': l.widget_prompt,
    'checkIn': l.widget_checkIn,
    'openApp': input.discreet ? l.widget_openAppDiscreet : l.widget_openApp,
  };
  final base = <String, Object?>{
    'v': widgetStoreVersion,
    'ready': input.ready,
    'discreet': input.discreet,
    'tz': input.timezone,
  };
  if (!input.ready) return {...base, 's': strings};

  strings.addAll({
    'doneToday': l.widget_doneToday,
    'saved': l.widget_saved,
    'needHelp': l.widget_needHelp,
    'back': l.widget_back,
  });
  final awards = {...input.awardsToday, ...input.awardsFreshDay}..remove(0);
  final display = <String, Object?>{
    ...base,
    'owner': input.owner,
    'auraDay': input.today.toIso(),
    'checkedInToday': input.checkedInToday,
    'awardsToday': input.awardsToday,
    'awardsFresh': input.awardsFreshDay,
    'savedAward': {for (final a in awards) '$a': l.widget_savedStarlight(a)},
    'avatar': input.hasAvatar && !input.discreet,
    's': strings,
  };
  if (input.discreet) return display;

  strings['capsuleWaiting'] = l.widget_capsuleWaiting;
  final streak = input.streakDays;
  if (streak != null && streak > 0) {
    display['streak'] = l.home_glowStreak(streak);
  }
  display['capsuleWaiting'] = input.capsuleWaiting;
  display['triggerMoods'] = input.triggerMoodIds.toList()..sort();
  final last = input.lastMood;
  if (input.showLastMood && last != null) {
    display['lastMood'] = {
      'id': last.id,
      'quadrant': last.quadrant.name,
      'text': l.widget_lastMood(last.nameFor(localeTag)),
    };
  }
  display['quadrants'] = [
    for (final q in Quadrant.values)
      {
        'id': q.name,
        'label': quadrantName(l, q),
        'moods': [
          for (final m in moodCatalog.where((m) => m.quadrant == q))
            {'id': m.id, 'label': m.nameFor(localeTag)},
        ],
      },
  ];
  return display;
}

String encodeWidgetDisplay(Map<String, Object?> display) => jsonEncode(display);
