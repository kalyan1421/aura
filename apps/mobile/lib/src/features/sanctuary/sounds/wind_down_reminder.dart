import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/aura_tokens.dart';
import '../../push/notification_prefs.dart';
import '../../push/notifications_settings_section.dart'
    show showNotificationQuietConfirm;

/// The opt-in wind-down reminder, set from the night wind-down card (PRD 12
/// catalogue "Wind-down reminder (opt-in, from B)"; REQ-NTF-04: "off until
/// the user picks a time"). The same setting as Settings › Notifications:
/// "Remind me at 10:30 PM" asks for a time first (suggested 22:30), a time
/// inside quiet hours asks the one-time confirmation (rule 1); when on, the
/// time shows with "Turn off". Hidden while all notifications are off.
class WindDownReminderRow extends ConsumerWidget {
  const WindDownReminderRow({super.key});

  String _time(BuildContext context, DayTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: t.hour, minute: t.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  Future<void> _turnOn(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefs p,
  ) async {
    final initial = p.windDownTime ?? NotificationPrefs.suggestedWindDownTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (picked == null || !context.mounted) return;
    final time = DayTime(picked.hour, picked.minute);
    final inside = inQuietHours(time, p.quietStart, p.quietEnd);
    var confirmed = false;
    if (inside) {
      confirmed = await showNotificationQuietConfirm(
        context,
        reminder: _time(context, time),
        start: _time(context, p.quietStart),
        end: _time(context, p.quietEnd),
      );
      if (!confirmed) return;
    }
    await ref.read(notificationPrefsRepositoryProvider).update({
      PrefFields.windDownTime: time.hm,
      PrefFields.windDownEnabled: true,
      if (confirmed) PrefFields.windDownInQuietHours: true,
      if (!inside && p.windDownInQuietHours)
        PrefFields.windDownInQuietHours: false,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = ref.watch(notificationPrefsProvider).value;
    if (p == null || !p.enabled) return const SizedBox.shrink();
    final time = p.windDownTime;
    if (p.windDownEnabled && time != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AuraSpace.s),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.sounds_windDownReminderOn(_time(context, time)),
                key: const ValueKey('sounds-wind-down-reminder-on'),
                style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
              ),
            ),
            TextButton(
              key: const ValueKey('sounds-wind-down-reminder-off'),
              onPressed: () => unawaited(
                ref.read(notificationPrefsRepositoryProvider).update({
                  PrefFields.windDownEnabled: false,
                }),
              ),
              child: Text(l.sounds_windDownReminderOff),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s),
      child: TextButton.icon(
        key: const ValueKey('sounds-wind-down-remind'),
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: () => unawaited(_turnOn(context, ref, p)),
        label: Text(
          l.sounds_windDownRemind(
            _time(context, time ?? NotificationPrefs.suggestedWindDownTime),
          ),
        ),
      ),
    );
  }
}
