import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/push/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Settings › Notifications on this phone (F14): local-first, each change a
/// PATCH in the sync outbox (`notification_prefs` upsert), and per-field
/// last-write-wins when adopting the server's row.

class _Remote implements NotificationPrefsRemote {
  Map<String, dynamic>? row;
  Object? error;
  @override
  Future<Map<String, dynamic>?> fetch() async {
    final e = error;
    if (e != null) throw e;
    return row;
  }
}

void main() {
  late AppDatabase db;
  late KvStore kv;
  late OutboxRepository outbox;
  late _Remote remote;
  late int nudges;
  late NotificationPrefsRepository repo;

  setUp(() {
    db = memoryDb();
    kv = KvStore(db);
    outbox = OutboxRepository(db, const Ids());
    remote = _Remote();
    nudges = 0;
    repo = NotificationPrefsRepository(
      db: db,
      kv: kv,
      outbox: outbox,
      time: testTime,
      notifySync: () => nudges++,
      remote: remote,
    );
  });

  tearDown(() => db.close());

  Future<List<OutboxRow>> rows() => db.select(db.outbox).get();

  test('defaults are the PRD ones: all on except the reminder; quiet '
      '23:00–08:00; discreet off', () async {
    final p = await repo.load();
    expect(p, const NotificationPrefs());
    expect(p.enabled, isTrue);
    expect(p.reminderEnabled, isFalse);
    expect(p.reminderTime, isNull);
    expect(p.capsuleUnlocked, isTrue);
    expect(p.quietStart, const DayTime(23, 0));
    expect(p.quietEnd, const DayTime(8, 0));
    expect(p.discreet, isFalse);
    expect(NotificationPrefs.suggestedReminderTime, const DayTime(20, 0));
  });

  test('a change is a local write + one outbox PATCH of just that change, '
      'then a sync nudge', () async {
    await repo.update({'reminderEnabled': true, 'reminderTime': '20:00'});
    await repo.update({'discreet': true});

    final p = await repo.load();
    expect(p.reminderEnabled, isTrue);
    expect(p.reminderTime, const DayTime(20, 0));
    expect(p.discreet, isTrue);

    final out = await rows();
    expect(out, hasLength(2));
    expect(out.map((r) => (r.entity, r.op, r.entityId)).toSet(), {
      ('notification_prefs', 'upsert', 'notification_prefs'),
    });
    expect(jsonDecode(out[0].payload), {
      'reminderEnabled': true,
      'reminderTime': '20:00',
    });
    expect(jsonDecode(out[1].payload), {'discreet': true});
    expect(out[0].deviceTs, testNow);
    expect(out[0].tz, 'Asia/Kolkata');
    expect(nudges, 2);
  });

  test('unknown fields never travel', () async {
    await repo.update({'discreet': true, 'mood': 'anxious'});
    expect(jsonDecode((await rows()).single.payload), {'discreet': true});
    await repo.update({'mood': 'anxious'});
    expect(await rows(), hasLength(1)); // nothing to send
  });

  test('watch emits the new settings', () async {
    final seen = <NotificationPrefs>[];
    final sub = repo.watch().listen(seen.add);
    await pumpEventQueue();
    await repo.update({'capsuleUnlocked': false});
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.last.capsuleUnlocked, isFalse);
  });

  test('pull adopts server fields stamped later than this phone\'s, and '
      'keeps newer local ones', () async {
    await repo.update({'discreet': true}); // stamped testNow
    final later = testNow.add(const Duration(minutes: 5)).toIso8601String();
    final earlier = testNow
        .subtract(const Duration(minutes: 5))
        .toIso8601String();
    remote.row = {
      'enabled': true,
      'reminder_enabled': true,
      'reminder_time': '07:30:00',
      'reminder_in_quiet_ok': false,
      'capsule_enabled': false,
      'quiet_start': '22:00:00',
      'quiet_end': '08:00:00',
      'discreet': false,
      'field_ts': {
        'reminderEnabled': later,
        'reminderTime': later,
        'capsuleUnlocked': later,
        'discreet': earlier, // older than this phone's change
        // quietStart has no stamp: never adopted (a server default)
      },
    };
    await repo.pull();
    final p = await repo.load();
    expect(p.reminderEnabled, isTrue);
    expect(p.reminderTime, const DayTime(7, 30));
    expect(p.capsuleUnlocked, isFalse);
    expect(p.discreet, isTrue);
    expect(p.quietStart, const DayTime(23, 0));
    expect(await rows(), hasLength(1)); // a pull never queues anything
  });

  test(
    'pull is best-effort: no row, no stamps, or an error change nothing',
    () async {
      await repo.pull();
      remote.row = {'enabled': false};
      await repo.pull();
      remote.error = Exception('offline');
      await repo.pull();
      expect(await repo.load(), const NotificationPrefs());
    },
  );

  test('quiet hours wrap midnight; start = end means none', () {
    const start = DayTime(23, 0);
    const end = DayTime(8, 0);
    expect(inQuietHours(const DayTime(22, 59), start, end), isFalse);
    expect(inQuietHours(const DayTime(23, 0), start, end), isTrue);
    expect(inQuietHours(const DayTime(3, 0), start, end), isTrue);
    expect(inQuietHours(const DayTime(8, 0), start, end), isFalse);
    expect(
      inQuietHours(const DayTime(10, 0), const DayTime(8, 0), end),
      isFalse,
    );
    expect(
      inQuietHours(
        const DayTime(10, 0),
        const DayTime(8, 0),
        const DayTime(16, 0),
      ),
      isTrue,
    );
    expect(DayTime.tryParse('07:30:00'), const DayTime(7, 30));
    expect(DayTime.tryParse('24:00'), isNull);
    expect(DayTime.tryParse('7:30'), isNull);
    expect(const DayTime(9, 5).hm, '09:05');
  });

  test('reminderInsideQuietHours', () {
    expect(
      const NotificationPrefs(reminderTime: DayTime(23, 30))
          .reminderInsideQuietHours,
      isTrue,
    );
    expect(
      const NotificationPrefs(reminderTime: DayTime(20, 0))
          .reminderInsideQuietHours,
      isFalse,
    );
  });
}
