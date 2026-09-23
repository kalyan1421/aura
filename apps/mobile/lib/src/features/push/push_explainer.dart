import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'notification_prefs.dart';
import 'notifications_settings_section.dart';
import 'push_service.dart';

/// Offers notifications right after a check-in is saved (PRD
/// 15-permissions): the warm explainer first, and only "Allow" fires the OS
/// prompt. Shown at most once per account; a no-op when push is off.
///
/// "Allow" also turns the daily check-in reminder on at the evening time
/// shown on the sheet (suggested 20:00, changeable there and in Settings ›
/// Notifications). "Not now" changes nothing.
Future<void> offerPushAfterCheckIn(BuildContext context, WidgetRef ref) async {
  var time = NotificationPrefs.suggestedReminderTime;
  var allowed = false;
  final prefs = ref.read(notificationPrefsRepositoryProvider);
  await ref.read(pushServiceProvider).offerAfterCheckIn(() async {
    if (!context.mounted) return null;
    final current = await prefs.load();
    time = current.reminderTime ?? time;
    if (!context.mounted) return null;
    final answer = await showModalBottomSheet<SoftAskAnswer>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => PushExplainerSheet(
        initialTime: time,
        quietStart: current.quietStart,
        quietEnd: current.quietEnd,
        onTimeChanged: (t) => time = t,
      ),
    );
    allowed = answer == SoftAskAnswer.allow;
    return answer;
  });
  if (!allowed) return;
  final current = await prefs.load();
  await prefs.update({
    PrefFields.reminderEnabled: true,
    PrefFields.reminderTime: time.hm,
    // A time inside quiet hours was confirmed on the sheet.
    if (inQuietHours(time, current.quietStart, current.quietEnd))
      PrefFields.reminderInQuietHours: true,
  });
}

/// "Want a gentle nudge each evening?" with the evening time, Allow and
/// Not now.
class PushExplainerSheet extends StatefulWidget {
  const PushExplainerSheet({
    super.key,
    this.initialTime = NotificationPrefs.suggestedReminderTime,
    this.quietStart = const DayTime(23, 0),
    this.quietEnd = const DayTime(8, 0),
    this.onTimeChanged,
  });

  final DayTime initialTime;
  final DayTime quietStart;
  final DayTime quietEnd;
  final ValueChanged<DayTime>? onTimeChanged;

  @override
  State<PushExplainerSheet> createState() => _PushExplainerSheetState();
}

class _PushExplainerSheetState extends State<PushExplainerSheet> {
  late DayTime _time = widget.initialTime;

  String _format(DayTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: t.hour, minute: t.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  Future<void> _change() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
    );
    if (picked == null || !mounted) return;
    final t = DayTime(picked.hour, picked.minute);
    if (inQuietHours(t, widget.quietStart, widget.quietEnd)) {
      final ok = await showNotificationQuietConfirm(
        context,
        reminder: _format(t),
        start: _format(widget.quietStart),
        end: _format(widget.quietEnd),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _time = t);
    widget.onTimeChanged?.call(t);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.xl,
        AuraSpace.gutter,
        AuraSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.nights_stay_rounded,
              size: 40,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Semantics(
            header: true,
            child: Text(
              l.push_title,
              textAlign: TextAlign.center,
              style: t.headlineSmall,
            ),
          ),
          const SizedBox(height: AuraSpace.s),
          Text(
            l.push_body,
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.m),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.push_timeRow(_format(_time)),
                key: const ValueKey('push-time'),
                style: t.bodyMedium,
              ),
              TextButton(
                key: const ValueKey('push-change-time'),
                onPressed: () => unawaited(_change()),
                child: Text(l.push_changeTime),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.l),
          FilledButton(
            key: const ValueKey('push-allow'),
            onPressed: () => Navigator.pop(context, SoftAskAnswer.allow),
            child: Text(l.push_allow),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('push-not-now'),
            onPressed: () => Navigator.pop(context, SoftAskAnswer.notNow),
            child: Text(l.common_notNow),
          ),
        ],
      ),
    );
  }
}
