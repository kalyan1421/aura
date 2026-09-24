import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../checkin/quadrant_glyph.dart' show habitLabel;
import '../habits/habit_providers.dart';
import '../habits/habit_repository.dart';
import 'notification_prefs.dart';

/// Settings › Notifications › Habit nudges (PRD 12 catalogue "Habit nudge
/// (opt-in) · Time set per habit · 1/day, due habits bundled"): each habit
/// on Home with its nudge time, or "Off". Tapping a habit without a nudge
/// picks a time; one with a nudge offers "Change time" / "Turn off".
///
/// The whole `{habitId: time}` map travels as one setting (the server keeps
/// ids and times only, never a name). A preset never used yet gets its habit
/// row first (a nudge refers to a habit by id). A time inside quiet hours is
/// kept but says it won't be sent (nudges have no quiet-hours override).
class HabitNudgesSection extends ConsumerWidget {
  const HabitNudgesSection({
    super.key,
    required this.prefs,
    required this.enabled,
    required this.pick,
    required this.formatTime,
    required this.update,
  });

  final NotificationPrefs prefs;

  /// The master switch is on.
  final bool enabled;
  final Future<DayTime?> Function(DayTime initial) pick;
  final String Function(DayTime) formatTime;
  final Future<void> Function(Map<String, Object?> patch) update;

  Future<void> _save(Map<String, DayTime> nudges) => update({
    PrefFields.habitNudges: {for (final e in nudges.entries) e.key: e.value.hm},
  });

  Future<void> _tap(BuildContext context, WidgetRef ref, HabitToday h) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(habitRepositoryProvider);
    final current = h.habitId == null ? null : prefs.habitNudges[h.habitId];
    if (current != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          key: const ValueKey('set-ntf-habit-dialog'),
          children: [
            SimpleDialogOption(
              key: const ValueKey('set-ntf-habit-change'),
              onPressed: () => Navigator.pop(context, 'change'),
              child: Text(l.set_notifHabitChange),
            ),
            SimpleDialogOption(
              key: const ValueKey('set-ntf-habit-off'),
              onPressed: () => Navigator.pop(context, 'off'),
              child: Text(l.set_notifHabitTurnOff),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'off') {
        await _save({...prefs.habitNudges}..remove(h.habitId));
        return;
      }
    }
    final picked = await pick(
      current ?? NotificationPrefs.suggestedHabitNudgeTime,
    );
    if (picked == null) return;
    final id = h.habitId ?? await repo.ensurePresetId(h.preset!.key);
    await _save({...prefs.habitNudges, id: picked});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final habits = ref.watch(habitsTodayProvider).value ?? const <HabitToday>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AuraSpace.l),
          child: Semantics(
            header: true,
            container: true,
            child: Text(
              l.set_notifHabits,
              key: const ValueKey('set-ntf-habits'),
              style: t.titleSmall,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: AuraSpace.xs,
            bottom: AuraSpace.s,
          ),
          child: Text(
            habits.isEmpty ? l.set_notifHabitsNone : l.set_notifHabitsNote,
            style: t.bodyMedium,
          ),
        ),
        for (final h in habits)
          Builder(
            builder: (context) {
              final time = h.habitId == null
                  ? null
                  : prefs.habitNudges[h.habitId];
              final quiet =
                  time != null &&
                  inQuietHours(time, prefs.quietStart, prefs.quietEnd);
              return ListTile(
                key: ValueKey('set-ntf-habit-${h.key}'),
                contentPadding: EdgeInsets.zero,
                enabled: enabled,
                title: Text(h.isCustom ? h.name! : habitLabel(l, h.key)),
                subtitle: quiet ? Text(l.set_notifHabitQuiet) : null,
                trailing: Text(
                  time == null ? l.set_notifHabitOff : formatTime(time),
                  style: t.titleMedium,
                ),
                onTap: enabled ? () => unawaited(_tap(context, ref, h)) : null,
              );
            },
          ),
      ],
    );
  }
}
