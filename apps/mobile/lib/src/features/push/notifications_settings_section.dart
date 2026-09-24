import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import 'habit_nudges_section.dart';
import 'notification_prefs.dart';
import 'push_messaging.dart';

/// Settings › Notifications (PRD 12-notifications rule 8, 15-permissions):
/// a master switch, the daily check-in reminder (on/off + time), "a capsule
/// is ready to open", warmth from your room, Lantern Hour (opt-in), the
/// wind-down reminder (opt-in, on/off + time), "after a quiet while", quiet
/// hours, discreet mode and per-habit nudges ([HabitNudgesSection]). Every change is a local
/// write plus a patch in the sync outbox; the server applies the rules.
///
/// - A reminder time inside quiet hours is honoured only after a one-time
///   confirmation (night shifts, rule 1).
/// - Notifications off in the phone's settings → a calm note: "Turn on" (the
///   OS prompt) when asking is allowed — never asked, or the one re-ask 30+
///   days after a decline — otherwise a link to the phone's settings.
class NotificationsSection extends ConsumerStatefulWidget {
  const NotificationsSection({super.key});

  @override
  ConsumerState<NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<NotificationsSection>
    with WidgetsBindingObserver {
  PushPermission? _permission;
  bool _mayAsk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshPermission());
    // Another phone may have changed these; best-effort, silent.
    unawaited(ref.read(notificationPrefsRepositoryProvider).pull());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the phone's settings.
    if (state == AppLifecycleState.resumed) unawaited(_refreshPermission());
  }

  Future<void> _refreshPermission() async {
    final push = ref.read(pushServiceProvider);
    final permission = await push.permission();
    final mayAsk = await push.mayAskAgain();
    if (!mounted) return;
    setState(() {
      _permission = permission;
      _mayAsk = mayAsk;
    });
  }

  Future<void> _update(Map<String, Object?> patch) =>
      ref.read(notificationPrefsRepositoryProvider).update(patch);

  String _time(BuildContext context, DayTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: t.hour, minute: t.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  Future<DayTime?> _pick(DayTime initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    return t == null ? null : DayTime(t.hour, t.minute);
  }

  /// The one-time confirmation for a reminder inside quiet hours.
  Future<bool> _confirmQuiet(
    DayTime reminder,
    DayTime start,
    DayTime end,
  ) async {
    final ok = await showNotificationQuietConfirm(
      context,
      reminder: _time(context, reminder),
      start: _time(context, start),
      end: _time(context, end),
    );
    return ok;
  }

  Future<void> _setReminderEnabled(NotificationPrefs p, bool on) async {
    if (!on) return _update({PrefFields.reminderEnabled: false});
    final time = p.reminderTime ?? NotificationPrefs.suggestedReminderTime;
    return _setReminderTime(p, time, enable: true);
  }

  Future<void> _setReminderTime(
    NotificationPrefs p,
    DayTime time, {
    bool enable = true,
  }) async {
    final inside = inQuietHours(time, p.quietStart, p.quietEnd);
    var confirmed = false;
    if (inside && !(p.reminderInQuietHours && time == p.reminderTime)) {
      confirmed = await _confirmQuiet(time, p.quietStart, p.quietEnd);
      if (!confirmed) return; // pick another time: nothing changes
    }
    await _update({
      PrefFields.reminderTime: time.hm,
      if (enable) PrefFields.reminderEnabled: true,
      if (confirmed) PrefFields.reminderInQuietHours: true,
      // Outside quiet hours the confirmation isn't needed; a later move back
      // inside asks again.
      if (!inside && p.reminderInQuietHours)
        PrefFields.reminderInQuietHours: false,
    });
  }

  Future<void> _setWindDownEnabled(NotificationPrefs p, bool on) async {
    if (!on) return _update({PrefFields.windDownEnabled: false});
    final time = p.windDownTime ?? NotificationPrefs.suggestedWindDownTime;
    return _setWindDownTime(p, time);
  }

  /// The wind-down reminder at [time] (and on): inside quiet hours only after
  /// the same one-time confirmation as the daily reminder (rule 1).
  Future<void> _setWindDownTime(NotificationPrefs p, DayTime time) async {
    final inside = inQuietHours(time, p.quietStart, p.quietEnd);
    var confirmed = false;
    if (inside && !(p.windDownInQuietHours && time == p.windDownTime)) {
      confirmed = await _confirmQuiet(time, p.quietStart, p.quietEnd);
      if (!confirmed) return;
    }
    await _update({
      PrefFields.windDownTime: time.hm,
      PrefFields.windDownEnabled: true,
      if (confirmed) PrefFields.windDownInQuietHours: true,
      if (!inside && p.windDownInQuietHours)
        PrefFields.windDownInQuietHours: false,
    });
  }

  Future<void> _setQuiet(
    NotificationPrefs p, {
    DayTime? start,
    DayTime? end,
  }) async {
    final s = start ?? p.quietStart;
    final e = end ?? p.quietEnd;
    final reminder = p.reminderTime;
    var confirmed = false;
    if (p.reminderEnabled &&
        reminder != null &&
        !p.reminderInQuietHours &&
        inQuietHours(reminder, s, e)) {
      // "Keep it quiet": the quiet hours still change; the reminder then
      // waits until it's outside them (the server skips it inside).
      confirmed = await _confirmQuiet(reminder, s, e);
    }
    final windDown = p.windDownTime;
    var windDownConfirmed = false;
    if (p.windDownEnabled &&
        windDown != null &&
        !p.windDownInQuietHours &&
        inQuietHours(windDown, s, e) &&
        mounted) {
      windDownConfirmed = await _confirmQuiet(windDown, s, e);
    }
    await _update({
      if (start != null) PrefFields.quietStart: start.hm,
      if (end != null) PrefFields.quietEnd: end.hm,
      if (confirmed) PrefFields.reminderInQuietHours: true,
      if (windDownConfirmed) PrefFields.windDownInQuietHours: true,
    });
  }

  Future<void> _turnOn() async {
    final push = ref.read(pushServiceProvider);
    await push.requestFromSettings();
    await _refreshPermission();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p =
        ref.watch(notificationPrefsProvider).value ?? const NotificationPrefs();
    final on = p.enabled;

    Widget toggle({
      required String key,
      required String title,
      required String note,
      required bool value,
      required ValueChanged<bool>? onChanged,
    }) => SwitchListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(note),
    );

    Widget timeRow({
      required String key,
      required String title,
      required DayTime value,
      required VoidCallback? onTap,
    }) => ListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      title: Text(title),
      trailing: Text(_time(context, value), style: t.titleMedium),
      onTap: onTap,
    );

    final permission = _permission;
    final reminderTime =
        p.reminderTime ?? NotificationPrefs.suggestedReminderTime;
    final windDownTime =
        p.windDownTime ?? NotificationPrefs.suggestedWindDownTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AuraSpace.xl,
            bottom: AuraSpace.s,
          ),
          // Its own node: in this Column it would otherwise merge with the
          // rows' plain text below it.
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              l.set_notifications,
              key: const ValueKey('set-section-notifications'),
              style: t.titleSmall,
            ),
          ),
        ),
        if (permission != null && !permission.allowsPush)
          _OffNote(
            mayAsk: _mayAsk,
            onTurnOn: _turnOn,
            onOpenSettings: () =>
                unawaited(ref.read(auraPlatformProvider).openAppSettings()),
          ),
        toggle(
          key: 'set-ntf-master',
          title: l.set_notifMaster,
          note: l.set_notifMasterNote,
          value: on,
          onChanged: (v) => unawaited(_update({PrefFields.enabled: v})),
        ),
        toggle(
          key: 'set-ntf-reminder',
          title: l.set_notifReminder,
          note: p.reminderEnabled
              ? l.set_notifReminderNote(_time(context, reminderTime))
              : l.set_notifReminderOffNote,
          value: p.reminderEnabled,
          onChanged: on ? (v) => unawaited(_setReminderEnabled(p, v)) : null,
        ),
        timeRow(
          key: 'set-ntf-reminder-time',
          title: l.set_notifReminderTime,
          value: reminderTime,
          onTap: on && p.reminderEnabled
              ? () async {
                  final picked = await _pick(reminderTime);
                  if (picked != null) await _setReminderTime(p, picked);
                }
              : null,
        ),
        toggle(
          key: 'set-ntf-capsule',
          title: l.set_notifCapsule,
          note: l.set_notifCapsuleNote,
          value: p.capsuleUnlocked,
          onChanged: on
              ? (v) => unawaited(_update({PrefFields.capsuleUnlocked: v}))
              : null,
        ),
        toggle(
          key: 'set-ntf-gestures',
          title: l.set_notifGestures,
          note: l.set_notifGesturesNote,
          value: p.gestures,
          onChanged: on
              ? (v) => unawaited(_update({PrefFields.gestures: v}))
              : null,
        ),
        toggle(
          key: 'set-ntf-lantern',
          title: l.set_notifLantern,
          note: l.set_notifLanternNote,
          value: p.lanternHour,
          onChanged: on
              ? (v) => unawaited(_update({PrefFields.lanternHour: v}))
              : null,
        ),
        toggle(
          key: 'set-ntf-wind-down',
          title: l.set_notifWindDown,
          note: p.windDownEnabled
              ? l.set_notifWindDownNote(_time(context, windDownTime))
              : l.set_notifWindDownOffNote,
          value: p.windDownEnabled,
          onChanged: on ? (v) => unawaited(_setWindDownEnabled(p, v)) : null,
        ),
        timeRow(
          key: 'set-ntf-wind-down-time',
          title: l.set_notifWindDownTime,
          value: windDownTime,
          onTap: on && p.windDownEnabled
              ? () async {
                  final picked = await _pick(windDownTime);
                  if (picked != null) await _setWindDownTime(p, picked);
                }
              : null,
        ),
        toggle(
          key: 'set-ntf-welcome-back',
          title: l.set_notifWelcomeBack,
          note: l.set_notifWelcomeBackNote,
          value: p.welcomeBack,
          onChanged: on
              ? (v) => unawaited(_update({PrefFields.welcomeBack: v}))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AuraSpace.s),
          child: Text(
            l.set_notifQuietNote(
              _time(context, p.quietStart),
              _time(context, p.quietEnd),
            ),
            key: const ValueKey('set-ntf-quiet-note'),
            style: t.bodyMedium,
          ),
        ),
        timeRow(
          key: 'set-ntf-quiet-start',
          title: l.set_notifQuietFrom,
          value: p.quietStart,
          onTap: on
              ? () async {
                  final picked = await _pick(p.quietStart);
                  if (picked != null) await _setQuiet(p, start: picked);
                }
              : null,
        ),
        timeRow(
          key: 'set-ntf-quiet-end',
          title: l.set_notifQuietUntil,
          value: p.quietEnd,
          onTap: on
              ? () async {
                  final picked = await _pick(p.quietEnd);
                  if (picked != null) await _setQuiet(p, end: picked);
                }
              : null,
        ),
        toggle(
          key: 'set-ntf-discreet',
          title: l.set_notifDiscreet,
          note: l.set_notifDiscreetNote,
          value: p.discreet,
          onChanged: on
              ? (v) => unawaited(_update({PrefFields.discreet: v}))
              : null,
        ),
        HabitNudgesSection(
          prefs: p,
          enabled: on,
          pick: _pick,
          formatTime: (t) => _time(context, t),
          update: _update,
        ),
      ],
    );
  }
}

/// "Notifications are off for Aura on this phone" with one calm action.
class _OffNote extends StatelessWidget {
  const _OffNote({
    required this.mayAsk,
    required this.onTurnOn,
    required this.onOpenSettings,
  });

  final bool mayAsk;
  final VoidCallback onTurnOn;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s),
      child: InlineNotice(
        l.set_notifOffNote,
        key: const ValueKey('set-ntf-off-note'),
        icon: Icons.notifications_off_outlined,
        action: mayAsk
            ? TextButton(
                key: const ValueKey('set-ntf-turn-on'),
                onPressed: onTurnOn,
                child: Text(l.set_notifTurnOn),
              )
            : TextButton(
                key: const ValueKey('set-ntf-open-settings'),
                onPressed: onOpenSettings,
                child: Text(l.set_notifOpenSettings),
              ),
      ),
    );
  }
}

/// "This time is inside your quiet hours" — send the reminder anyway?
/// True = the person confirmed (the one-time confirmation of rule 1).
Future<bool> showNotificationQuietConfirm(
  BuildContext context, {
  required String reminder,
  required String start,
  required String end,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('set-ntf-quiet-confirm'),
      title: Semantics(header: true, child: Text(l.set_notifQuietConfirmTitle)),
      content: Text(l.set_notifQuietConfirmBody(start, end, reminder)),
      actions: [
        TextButton(
          key: const ValueKey('set-ntf-quiet-no'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.set_notifQuietConfirmNo),
        ),
        TextButton(
          key: const ValueKey('set-ntf-quiet-yes'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.set_notifQuietConfirmYes),
        ),
      ],
    ),
  );
  return ok ?? false;
}
