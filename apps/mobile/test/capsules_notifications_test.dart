import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/capsules/capsule_notifications.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capsules_fakes.dart';
import 'helpers.dart';

/// PRD F4 date unlock: a local notice scheduled at sealing for 10:00 local
/// on the unlock date (works offline), generic copy only, re-timed to 10:00
/// in the new zone after a timezone change, cancelled when the capsule opens
/// or is deleted; de-duplicated against the server's backup push.
void main() {
  late Directory root;
  late AppDatabase db;
  late FixedClock clock;
  late FakeNoticePort port;
  late CapsuleUnlockScheduler scheduler;
  late CapsuleRepository repo;
  late String tz;

  const text = CapsuleNoticeText(
    body: 'Something you sealed is ready to open.',
    channelName: 'Capsules',
    channelDescription: 'When something you sealed is ready to open.',
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-capsule-notices');
    db = memoryDb();
    clock = FixedClock(testNow); // 15:30 IST, 8 Oct 2026
    tz = 'Asia/Kolkata';
    port = FakeNoticePort();
    scheduler = CapsuleUnlockScheduler(
      db: db,
      kv: KvStore(db),
      port: port,
      clock: clock,
    );
    repo = CapsuleRepository(
      db,
      OutboxRepository(db, const Ids()),
      TimeContext(clock: clock, timezone: tz),
      store: tempCapsuleStore(root),
      cipher: () async => testCipher(),
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> sealFor(String id, String date) => repo.seal(
    id: id,
    content: const CapsuleContent(title: 'Private title', text: 'secret'),
    unlock: DateUnlock(LocalDay.parse(date)),
  );

  Future<void> reconcile() => scheduler.reconcile(tz: tz, text: text);

  test('scheduled at sealing for 10:00 local on the date, generic copy', () async {
    await sealFor('a', '2027-10-08');
    await reconcile();
    final id = capsuleNoticeId(LocalDay.parse('2027-10-08'));
    expect(port.scheduled, {id: DateTime.utc(2027, 10, 8, 4, 30)}); // 10:00 IST
    expect(port.payloads[id], 'capsule_unlocked:2027-10-08');
    // Never the title, the date or the content on the lock screen.
    expect(port.bodies.single, text.body);
    expect(port.bodies.single, isNot(contains('Private')));
    final row = (await repo.row('a'))!;
    expect(row.notifyAt, DateTime.utc(2027, 10, 8, 4, 30));
  });

  test('capsules on the same day share one notice; unchanged → no churn', () async {
    await sealFor('a', '2027-10-08');
    await sealFor('b', '2027-10-08');
    await sealFor('c', '2027-12-01');
    await reconcile();
    expect(port.scheduled, hasLength(2));
    final calls = port.scheduleCalls;
    await reconcile();
    expect(port.scheduleCalls, calls, reason: 'nothing changed');
  });

  test('after a timezone change: 10:00 in the new zone', () async {
    await sealFor('a', '2027-10-08');
    await reconcile();
    tz = 'America/Los_Angeles';
    await reconcile();
    final id = capsuleNoticeId(LocalDay.parse('2027-10-08'));
    expect(port.scheduled[id], DateTime.utc(2027, 10, 8, 17)); // 10:00 PDT
    expect((await repo.row('a'))!.notifyAt, DateTime.utc(2027, 10, 8, 17));
  });

  test('opening or deleting cancels it', () async {
    await sealFor('a', '2026-10-15');
    await sealFor('b', '2026-11-01');
    await reconcile();
    expect(port.scheduled, hasLength(2));
    clock.instant = DateTime.utc(2026, 10, 15, 5); // after 10:00 IST
    await repo.open('a');
    await repo.delete('b');
    await reconcile();
    expect(port.scheduled, isEmpty);
  });

  test('an unlock that already passed is not scheduled (shows on launch)', () async {
    await sealFor('a', '2026-10-15');
    clock.instant = DateTime.utc(2026, 10, 16);
    await reconcile();
    expect(port.scheduled, isEmpty);
    expect(isCapsuleDue((await repo.row('a'))!, tz, clock.now()), isTrue);
  });

  test('only the soonest days are scheduled (iOS keeps 64 in total)', () async {
    var day = LocalDay.parse('2026-10-20');
    for (var i = 0; i < maxScheduledCapsuleNotices + 5; i++) {
      await sealFor('c$i', day.toIso());
      day = day.addDays(1);
    }
    await reconcile();
    expect(port.scheduled, hasLength(maxScheduledCapsuleNotices));
    expect(
      port.scheduled.containsKey(capsuleNoticeId(LocalDay.parse('2026-10-20'))),
      isTrue,
    );
    final far = (await repo.row('c${maxScheduledCapsuleNotices + 4}'))!;
    expect(far.notifyAt, isNull, reason: 'the server push covers it');
  });

  group("the server's backup push (dedupe by capsule id)", () {
    test('skipped once this phone notified (or the capsule is open/gone)', () async {
      await sealFor('a', '2026-10-15');
      await reconcile();
      clock.instant = DateTime.utc(2026, 10, 15, 4, 31); // local notice fired
      expect(await scheduler.shouldShowServerPush('a'), isFalse);
      await repo.open('a');
      expect(await scheduler.shouldShowServerPush('a'), isFalse);
      await repo.delete('a');
      expect(await scheduler.shouldShowServerPush('a'), isFalse);
    });

    test('shown when it comes first; the local notice for that day is cancelled', () async {
      await sealFor('a', '2026-10-15');
      await sealFor('b', '2026-10-15');
      await reconcile();
      clock.instant = DateTime.utc(2026, 10, 15, 4); // 09:30 IST, before ours
      expect(await scheduler.shouldShowServerPush('a'), isTrue);
      expect(port.scheduled, isEmpty);
      // Not re-scheduled later, and the same day's other capsule is covered.
      await reconcile();
      expect(port.scheduled, isEmpty);
      expect(await scheduler.shouldShowServerPush('b'), isFalse);
    });

    test('an unknown capsule (not pulled yet) shows it', () async {
      expect(await scheduler.shouldShowServerPush('unknown'), isTrue);
    });
  });

  test('sign-out cancels every capsule notice', () async {
    await sealFor('a', '2027-10-08');
    await sealFor('b', '2027-11-08');
    await reconcile();
    await scheduler.cancelAll();
    expect(port.scheduled, isEmpty);
  });

  test('a wiped table cancels what was scheduled', () async {
    await sealFor('a', '2027-10-08');
    await reconcile();
    await db.wipeUserData(keepKeys: const {});
    await reconcile();
    expect(port.scheduled, isEmpty);
  });
}
