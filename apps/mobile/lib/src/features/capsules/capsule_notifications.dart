import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/time/clock.dart';
import 'capsule_repository.dart';

/// The generic, content-free copy of the "ready to open" notice (PRD
/// 12-notifications / 15-permissions: never a title, a date or a mood).
@immutable
class CapsuleNoticeText {
  const CapsuleNoticeText({
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String body;
  final String channelName;
  final String channelDescription;

  @override
  bool operator ==(Object other) =>
      other is CapsuleNoticeText &&
      other.body == body &&
      other.channelName == channelName &&
      other.channelDescription == channelDescription;

  @override
  int get hashCode => Object.hash(body, channelName, channelDescription);
}

/// One local notification. Every date capsule unlocking on [date] shares it
/// (at most one "ready to open" per day, like the server's push).
@immutable
class UnlockNotice {
  const UnlockNotice({
    required this.date,
    required this.at,
    required this.capsuleIds,
  });

  final LocalDay date;

  /// 10:00 on [date] in the current zone.
  final DateTime at;
  final List<String> capsuleIds;

  int get id => capsuleNoticeId(date);

  String get payload => '$capsuleNoticePayloadPrefix:${date.toIso()}';
}

/// Notification payloads of capsule notices start with this (the payload is
/// only readable by the app; it never shows on screen).
const String capsuleNoticePayloadPrefix = 'capsule_unlocked';

/// iOS keeps at most 64 pending local notifications per app, shared with
/// every other feature: capsules use the soonest this many days.
const int maxScheduledCapsuleNotices = 24;

/// A stable notification id per unlock date, far above the small ids other
/// features use.
int capsuleNoticeId(LocalDay date) =>
    0x18000000 +
    DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(1970)).inDays;

/// Which notices should be scheduled: one per unlock date of the pending
/// date capsules (sealed, not opened, not deleted), at 10:00 in [tz] (the
/// **current** zone, so a move re-times them), in the future, soonest
/// [max] first. [skipDates]: days the server's push already announced.
List<UnlockNotice> planUnlockNotices(
  Iterable<CapsuleRow> rows, {
  required String tz,
  required DateTime now,
  int max = maxScheduledCapsuleNotices,
  Set<String> skipDates = const {},
}) {
  final byDate = <LocalDay, List<String>>{};
  for (final r in rows) {
    if (r.deletedAt != null || r.openedAt != null) continue;
    final date = unlockDateOf(r);
    if (date == null || skipDates.contains(date.toIso())) continue;
    (byDate[date] ??= <String>[]).add(r.id);
  }
  final notices = [
    for (final e in byDate.entries)
      UnlockNotice(
        date: e.key,
        at: capsuleUnlockAt(e.key, tz),
        capsuleIds: e.value..sort(),
      ),
  ]..removeWhere((n) => !n.at.isAfter(now.toUtc()));
  notices.sort((a, b) => a.at.compareTo(b.at));
  return notices.take(max).toList();
}

/// The OS side of local notifications (flutter_local_notifications); tests
/// use a fake.
abstract interface class LocalNoticePort {
  /// Schedules (or replaces) notification [id] at the instant [at].
  Future<void> schedule({
    required int id,
    required DateTime at,
    required CapsuleNoticeText text,
    required String payload,
  });

  Future<void> cancel(int id);

  /// Ids of the capsule notices still pending (payload
  /// [capsuleNoticePayloadPrefix]); other features' are never touched.
  Future<List<int>> pendingIds();
}

/// [LocalNoticePort] over flutter_local_notifications. Initialised lazily and
/// **never asks for permission**: the one notification prompt belongs to
/// the push soft ask after the first check-in (PRD 15-permissions). Without
/// permission the OS simply doesn't show the notice; Home's card and the
/// Sanctuary list still say a capsule is ready.
///
/// Android: channel "Capsules", private visibility, inexact scheduling (no
/// exact-alarm permission; ±15 min is fine), rescheduled after a reboot by
/// the plugin's boot receiver (AndroidManifest.xml).
class FlutterLocalNoticePort implements LocalNoticePort {
  FlutterLocalNoticePort([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  static const String channelId = 'capsules';

  Future<bool> _init() => _ready ??= () async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return true;
    } on Object catch (e) {
      debugPrint('capsules: notifications unavailable (${e.runtimeType})');
      _ready = null;
      return false;
    }
  }();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required CapsuleNoticeText text,
    required String payload,
  }) async {
    if (!await _init()) return;
    await _plugin.zonedSchedule(
      id: id,
      // An absolute instant; the scheduler re-times it after a zone change.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          text.channelName,
          channelDescription: text.channelDescription,
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: channelId),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      body: text.body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _init()) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> pendingIds() async {
    if (!await _init()) return const [];
    final pending = await _plugin.pendingNotificationRequests();
    return [
      for (final p in pending)
        if (p.payload?.startsWith(capsuleNoticePayloadPrefix) ?? false) p.id,
    ];
  }
}

/// Keeps this phone's "Something you sealed is ready to open." notices in
/// line with its capsules (PRD F4 date unlock, contracts/api/v1-capsules.md
/// §6): scheduled at sealing (works offline), one per unlock date at 10:00
/// in the **current** zone, re-timed after a timezone change, cancelled when
/// a capsule opens or is deleted (here, or on another phone via the pull).
/// An unlock that passed while the phone was off simply shows as ready on
/// the next launch (Home's card).
///
/// `CapsuleRow.notifyAt` records when this phone's notice fires, so the
/// server's backup push for the same capsule can be skipped
/// ([shouldShowServerPush]).
class CapsuleUnlockScheduler {
  CapsuleUnlockScheduler({
    required this._db,
    required this._kv,
    required this._port,
    this._clock = const Clock(),
  });

  final AppDatabase _db;
  final KvStore _kv;
  final LocalNoticePort _port;
  final Clock _clock;

  /// What was scheduled last: `{text, notices: {id: atIso}}`.
  static const String planKey = 'capsules.notices';

  /// Unlock dates the server's push already announced (`[YYYY-MM-DD]`).
  static const String serverNotifiedKey = 'capsules.server_notified';

  Future<void> _tail = Future<void>.value();

  /// Runs [body] after the previous call (reconciles never interleave).
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Brings the OS schedule in line with the capsules table for zone [tz].
  /// Idempotent and cheap when nothing changed.
  Future<void> reconcile({
    required String tz,
    required CapsuleNoticeText text,
  }) => _serial(() async {
    final now = _clock.now();
    final rows = await _db.select(_db.capsules).get();
    final skip = await _serverNotified(now);
    final plan = planUnlockNotices(rows, tz: tz, now: now, skipDates: skip);
    final planned = {for (final n in plan) n.id: n};
    final last = await _kv.getJson(planKey);
    final lastNotices = (last?['notices'] as Map<String, dynamic>?) ?? const {};
    final sameText = last?['text'] == text.body;
    final pending = (await _port.pendingIds()).toSet();

    for (final id in pending) {
      if (!planned.containsKey(id)) await _port.cancel(id);
    }
    for (final n in plan) {
      final unchanged =
          sameText &&
          pending.contains(n.id) &&
          lastNotices['${n.id}'] == n.at.toIso8601String();
      if (unchanged) continue;
      await _port.schedule(id: n.id, at: n.at, text: text, payload: n.payload);
    }
    await _kv.setJson(planKey, {
      'text': text.body,
      'notices': {for (final n in plan) '${n.id}': n.at.toIso8601String()},
    });

    // When each pending date capsule's notice fires (or fired). A notice
    // whose time passed keeps its value: it was shown (or would have been).
    final atByCapsule = {
      for (final n in plan)
        for (final id in n.capsuleIds) id: n.at,
    };
    await _db.transaction(() async {
      for (final r in rows) {
        if (r.deletedAt != null || r.openedAt != null) continue;
        final date = unlockDateOf(r);
        if (date == null) continue;
        // Passed: keeps what it had (shown then, or never scheduled). A day
        // the server's push announced keeps its mark too.
        if (!capsuleUnlockAt(date, tz).isAfter(now)) continue;
        if (skip.contains(date.toIso())) continue;
        final want = atByCapsule[r.id];
        final had = r.notifyAt;
        if (want == null ? had == null : had?.isAtSameMomentAs(want) == true) {
          continue;
        }
        await (_db.update(_db.capsules)..where((t) => t.id.equals(r.id))).write(
          CapsulesCompanion(notifyAt: Value(want)),
        );
      }
    });
  });

  /// For the push handler (features/push): whether the server's backup
  /// "capsule_unlocked" push for [capsuleId] should be shown on this phone.
  ///
  /// False when the capsule is opened or deleted here, or this phone's own
  /// notice for it already fired (`notifyAt` has passed). When the server's
  /// push comes first (e.g. the profile zone is ahead of the phone's), it is
  /// shown and this phone's notice for that day is cancelled for good, so
  /// the person hears about it once.
  Future<bool> shouldShowServerPush(String capsuleId) => _serial(() async {
    final now = _clock.now();
    final r = await (_db.select(
      _db.capsules,
    )..where((t) => t.id.equals(capsuleId.toLowerCase()))).getSingleOrNull();
    if (r == null) return true; // not pulled here yet: the server knows
    if (r.deletedAt != null || r.openedAt != null) return false;
    final notified = r.notifyAt;
    if (notified != null && !notified.isAfter(now)) return false;
    final date = unlockDateOf(r);
    if (date != null) {
      await _port.cancel(capsuleNoticeId(date));
      final days = await _serverNotified(now);
      await _kv.set(serverNotifiedKey, _encodeDays({...days, date.toIso()}));
      await (_db.update(_db.capsules)..where(
            (t) =>
                t.unlockLocalDate.equals(date.toIso()) & t.deletedAt.isNull(),
          ))
          .write(CapsulesCompanion(notifyAt: Value(now)));
    }
    return true;
  });

  /// Sign-out / account deletion: every capsule notice goes.
  Future<void> cancelAll() => _serial(() async {
    for (final id in await _port.pendingIds()) {
      await _port.cancel(id);
    }
    await _kv.set(planKey, null);
    await _kv.set(serverNotifiedKey, null);
  });

  /// Server-announced days, pruned to the last two days.
  Future<Set<String>> _serverNotified(DateTime now) async {
    final raw = await _kv.get(serverNotifiedKey);
    if (raw == null || raw.isEmpty) return const {};
    final cutoff = LocalDay.fromDateTime(now.toUtc()).addDays(-2);
    return {
      for (final d in raw.split(','))
        if (LocalDay.tryParse(d)?.isBefore(cutoff) == false) d,
    };
  }

  static String _encodeDays(Set<String> days) =>
      (days.toList()..sort()).join(',');
}
