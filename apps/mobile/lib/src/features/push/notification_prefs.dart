import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/db/database.dart';
import '../../core/db/kv_store.dart';
import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';

/// A wall-clock time of day, `HH:MM` (24 h).
@immutable
class DayTime implements Comparable<DayTime> {
  const DayTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  String get hm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// `HH:MM` or Postgres `HH:MM:SS`; anything else → null.
  static DayTime? tryParse(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(:\d\d)?$').firstMatch(v);
    if (m == null) return null;
    return DayTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  int compareTo(DayTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => minutes;

  @override
  String toString() => hm;
}

/// Quiet hours are `[start, end)` and may wrap midnight (23:00–08:00);
/// `start == end` means none (PRD 12-notifications rule 1, as the server).
bool inQuietHours(DayTime t, DayTime start, DayTime end) {
  if (start == end) return false;
  return start.minutes < end.minutes
      ? t.minutes >= start.minutes && t.minutes < end.minutes
      : t.minutes >= start.minutes || t.minutes < end.minutes;
}

/// Payload field names of the sync entity `notification_prefs`
/// (contracts/api/v1-notifications.md §1).
abstract final class PrefFields {
  static const String enabled = 'enabled';
  static const String reminderEnabled = 'reminderEnabled';
  static const String reminderTime = 'reminderTime';
  static const String reminderInQuietHours = 'reminderInQuietHours';
  static const String capsuleUnlocked = 'capsuleUnlocked';
  static const String quietStart = 'quietStart';
  static const String quietEnd = 'quietEnd';
  static const String discreet = 'discreet';

  static const List<String> all = [
    enabled,
    reminderEnabled,
    reminderTime,
    reminderInQuietHours,
    capsuleUnlocked,
    quietStart,
    quietEnd,
    discreet,
  ];

  /// Server column of each field (the select-own pull).
  static const Map<String, String> columns = {
    enabled: 'enabled',
    reminderEnabled: 'reminder_enabled',
    reminderTime: 'reminder_time',
    reminderInQuietHours: 'reminder_in_quiet_ok',
    capsuleUnlocked: 'capsule_enabled',
    quietStart: 'quiet_start',
    quietEnd: 'quiet_end',
    discreet: 'discreet',
  };
}

/// Settings › Notifications. Defaults are the PRD's: everything on except
/// the daily reminder (it starts when the person picks it, suggested
/// 20:00), quiet hours 23:00–08:00, discreet mode off.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.reminderEnabled = false,
    this.reminderTime,
    this.reminderInQuietHours = false,
    this.capsuleUnlocked = true,
    this.quietStart = const DayTime(23, 0),
    this.quietEnd = const DayTime(8, 0),
    this.discreet = false,
  });

  /// PRD catalogue: "suggested 8 pm" `[ASSUMPTION]`.
  static const DayTime suggestedReminderTime = DayTime(20, 0);

  final bool enabled;
  final bool reminderEnabled;
  final DayTime? reminderTime;
  final bool reminderInQuietHours;
  final bool capsuleUnlocked;
  final DayTime quietStart;
  final DayTime quietEnd;
  final bool discreet;

  /// The reminder time falls inside quiet hours.
  bool get reminderInsideQuietHours {
    final t = reminderTime;
    return t != null && inQuietHours(t, quietStart, quietEnd);
  }

  Map<String, Object?> toJson() => {
    PrefFields.enabled: enabled,
    PrefFields.reminderEnabled: reminderEnabled,
    PrefFields.reminderTime: reminderTime?.hm,
    PrefFields.reminderInQuietHours: reminderInQuietHours,
    PrefFields.capsuleUnlocked: capsuleUnlocked,
    PrefFields.quietStart: quietStart.hm,
    PrefFields.quietEnd: quietEnd.hm,
    PrefFields.discreet: discreet,
  };

  /// Applies a patch (payload field → value); unknown or malformed values
  /// are ignored.
  NotificationPrefs apply(Map<String, Object?> patch) {
    bool b(String k, bool fallback) =>
        patch.containsKey(k) && patch[k] is bool ? patch[k]! as bool : fallback;
    DayTime t(String k, DayTime fallback) => patch.containsKey(k)
        ? DayTime.tryParse(patch[k]) ?? fallback
        : fallback;
    return NotificationPrefs(
      enabled: b(PrefFields.enabled, enabled),
      reminderEnabled: b(PrefFields.reminderEnabled, reminderEnabled),
      reminderTime: patch.containsKey(PrefFields.reminderTime)
          ? DayTime.tryParse(patch[PrefFields.reminderTime])
          : reminderTime,
      reminderInQuietHours: b(
        PrefFields.reminderInQuietHours,
        reminderInQuietHours,
      ),
      capsuleUnlocked: b(PrefFields.capsuleUnlocked, capsuleUnlocked),
      quietStart: t(PrefFields.quietStart, quietStart),
      quietEnd: t(PrefFields.quietEnd, quietEnd),
      discreet: b(PrefFields.discreet, discreet),
    );
  }

  static NotificationPrefs fromJson(Map<String, dynamic>? json) => json == null
      ? const NotificationPrefs()
      : const NotificationPrefs().apply(json);

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// The account's server row (`public.notification_prefs`, select-own).
abstract interface class NotificationPrefsRemote {
  /// The row, or null when there is none (all defaults) or no session.
  Future<Map<String, dynamic>?> fetch();
}

class SupabasePrefsRemote implements NotificationPrefsRemote {
  SupabasePrefsRemote(this._client);

  final sb.SupabaseClient Function() _client;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    final sb.SupabaseClient client;
    try {
      client = _client();
    } on Object {
      return null; // Supabase didn't start (offline build, tests)
    }
    if (client.auth.currentSession == null) return null;
    return client
        .from('notification_prefs')
        .select('${PrefFields.columns.values.join(',')},field_ts')
        .maybeSingle();
  }
}

/// Settings › Notifications on this phone: local-first (the encrypted
/// key-value store, wiped with the account at sign-out), each change a
/// patch in the outbox for `POST /v1/sync/push` (PRD 16-offline: settings
/// use the one write path; last-write-wins per field). [pull] adopts newer
/// values from another phone or a reinstall.
class NotificationPrefsRepository {
  NotificationPrefsRepository({
    required this._db,
    required this._kv,
    required this._outbox,
    required this._time,
    this._notifySync,
    this._remote,
  });

  final AppDatabase _db;
  final KvStore _kv;
  final OutboxRepository _outbox;
  final TimeContext Function() _time;
  final void Function()? _notifySync;
  final NotificationPrefsRemote? _remote;

  /// `{values: {field: value}, fieldTs: {field: ISO}}`.
  static const String kvKey = 'notifications.prefs';
  static const String entity = 'notification_prefs';

  Stream<NotificationPrefs> watch() =>
      _kv.watchJson(kvKey).map((j) => _decode(j).prefs);

  Future<NotificationPrefs> load() async =>
      _decode(await _kv.getJson(kvKey)).prefs;

  /// Writes [patch] locally and queues it for the server, in one
  /// transaction; then nudges sync. Only the changed fields travel, so two
  /// phones editing different settings offline both win.
  Future<NotificationPrefs> update(Map<String, Object?> patch) async {
    final clean = {
      for (final e in patch.entries)
        if (PrefFields.all.contains(e.key)) e.key: e.value,
    };
    if (clean.isEmpty) return load();
    final t = _time();
    final now = t.now().toUtc();
    late NotificationPrefs next;
    await _db.transaction(() async {
      final cur = _decode(await _kv.getJson(kvKey));
      next = cur.prefs.apply(clean);
      await _kv.setJson(kvKey, {
        'values': next.toJson(),
        'fieldTs': {
          ...cur.fieldTs,
          for (final k in clean.keys) k: now.toIso8601String(),
        },
      });
      await _outbox.enqueue(
        entity: entity,
        op: Ops.upsert,
        entityId: entity,
        deviceTs: now,
        localDay: t.today(),
        payload: clean,
        tz: t.timezone,
      );
    });
    _notifySync?.call();
    return next;
  }

  /// Adopts the server's value of each field whose stamp is newer than this
  /// phone's (another phone's change, or a reinstall). Best-effort: offline,
  /// signed out or unconfigured → nothing changes.
  Future<void> pull() async {
    final remote = _remote;
    if (remote == null) return;
    Map<String, dynamic>? row;
    try {
      row = await remote.fetch();
    } catch (e) {
      debugPrint('notifications: pull ${e.runtimeType}');
      return;
    }
    if (row == null) return;
    final serverTs = row['field_ts'];
    if (serverTs is! Map) return;
    await _db.transaction(() async {
      final cur = _decode(await _kv.getJson(kvKey));
      final adopt = <String, Object?>{};
      final ts = {...cur.fieldTs};
      for (final f in PrefFields.all) {
        final s = DateTime.tryParse('${serverTs[f] ?? ''}');
        if (s == null) continue;
        final mine = DateTime.tryParse(cur.fieldTs[f] ?? '');
        if (mine != null && !s.isAfter(mine)) continue;
        adopt[f] = row![PrefFields.columns[f]];
        ts[f] = s.toUtc().toIso8601String();
      }
      if (adopt.isEmpty) return;
      await _kv.setJson(kvKey, {
        'values': cur.prefs.apply(adopt).toJson(),
        'fieldTs': ts,
      });
    });
  }

  static ({NotificationPrefs prefs, Map<String, String> fieldTs}) _decode(
    Map<String, dynamic>? j,
  ) {
    final values = j?['values'];
    final ts = j?['fieldTs'];
    return (
      prefs: NotificationPrefs.fromJson(
        values is Map<String, dynamic> ? values : null,
      ),
      fieldTs: {
        if (ts is Map)
          for (final e in ts.entries)
            if (e.value is String) '${e.key}': e.value as String,
      },
    );
  }
}

final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>(
      (ref) => NotificationPrefsRepository(
        db: ref.watch(appDatabaseProvider),
        kv: ref.watch(kvStoreProvider),
        outbox: ref.watch(outboxRepositoryProvider),
        time: () => ref.read(timeContextProvider),
        notifySync: () => ref.read(syncControllerProvider).notifyLocalWrite(),
        remote: Env.hasSupabase
            ? SupabasePrefsRemote(() => sb.Supabase.instance.client)
            : null,
      ),
    );

/// This phone's notification settings, live.
final notificationPrefsProvider = StreamProvider<NotificationPrefs>(
  (ref) => ref.watch(notificationPrefsRepositoryProvider).watch(),
);
