import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Edit within 24 h, delete any time, and deleting never lowers Starlight or
/// glow days (PRD F1; contracts/api/v1.md "Edits"; 16-offline tombstones).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late CheckInRepository repo;
  const ids = Ids();

  setUp(() {
    db = memoryDb();
    clock = FixedClock(testNow);
    repo = CheckInRepository(
      db,
      OutboxRepository(db, ids),
      TimeContext(clock: clock, timezone: 'Asia/Kolkata'),
    );
  });
  tearDown(() => db.close());

  Future<List<OutboxRow>> outbox() =>
      (db.select(db.outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  test('edit keeps the id, day and time and queues an upsert of the same id '
      '(the server treats it as an edit)', () async {
    final id = ids.v7();
    await repo.save(id: id, mood: moodById('calm')!, tags: ['family']);
    clock.instant = testNow.add(const Duration(hours: 5));

    final row = await repo.edit(
      id: id,
      mood: moodById('anxious')!,
      tags: ['work', 'exams'],
      note: 'A long day',
    );

    expect(await db.select(db.checkIns).get(), hasLength(1));
    expect(row.id, id);
    expect(row.moodId, 'anxious');
    expect(row.quadrant, 'storm');
    expect(row.tags, ['work', 'exams']);
    expect(row.note, 'A long day');
    expect(row.localDay, '2026-10-08'); // unchanged
    expect(row.deviceTs.toUtc(), testNow); // unchanged
    expect(row.synced, isFalse);

    final m = await outbox();
    expect(m, hasLength(2));
    expect(m.last.entity, Entities.checkIn);
    expect(m.last.op, Ops.upsert);
    expect(m.last.entityId, id);
    expect(m.last.deviceTs.toUtc(), testNow); // stamped like the original
    expect(m.last.localDay, '2026-10-08');
    expect(m.last.needsNote, isTrue);
    final payload = jsonDecode(m.last.payload) as Map<String, dynamic>;
    expect(payload['id'], id);
    expect(payload['moodId'], 'anxious');
    expect(payload['tags'], ['work', 'exams']);
    expect(payload.containsKey('note'), isFalse); // never plaintext
  });

  test('clearing the note in an edit sends no ciphertext', () async {
    final id = ids.v7();
    await repo.save(id: id, mood: moodById('calm')!, note: 'hello');
    await repo.edit(id: id, mood: moodById('calm')!, note: '  ');
    final row = await (db.select(
      db.checkIns,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.note, isNull);
    expect((await outbox()).last.needsNote, isFalse);
  });

  test('edits are refused after 24 hours and for deleted check-ins', () async {
    final id = ids.v7();
    await repo.save(id: id, mood: moodById('calm')!);
    final row = await (db.select(db.checkIns)).getSingle();
    expect(canEditCheckIn(row, testNow.add(const Duration(hours: 23))), true);
    expect(canEditCheckIn(row, testNow.add(const Duration(hours: 24))), false);

    clock.instant = testNow.add(const Duration(hours: 25));
    await expectLater(
      repo.edit(id: id, mood: moodById('proud')!),
      throwsA(isA<CheckInNotEditable>()),
    );

    clock.instant = testNow.add(const Duration(hours: 1));
    await repo.delete(id);
    await expectLater(
      repo.edit(id: id, mood: moodById('proud')!),
      throwsA(isA<CheckInNotEditable>()),
    );
    expect((await outbox()).where((m) => m.op == Ops.upsert), hasLength(1));
  });

  test(
    'delete is a tombstone plus a delete mutation; the note is cleared',
    () async {
      final id = ids.v7();
      await repo.save(
        id: id,
        mood: moodById('lonely')!,
        note: 'x',
        tags: ['a'],
      );
      clock.instant = testNow.add(const Duration(days: 3));
      await repo.delete(id);
      await repo.delete(id); // idempotent: one mutation

      final row = await (db.select(db.checkIns)).getSingle();
      expect(row.deletedAt?.toUtc(), testNow.add(const Duration(days: 3)));
      expect(row.note, isNull);
      expect(row.tags, isEmpty);
      expect(row.quadrant, 'rain'); // kept: progression needs it

      final m = await outbox();
      expect(m, hasLength(2)); // the original upsert stays queued
      expect(m.first.op, Ops.upsert);
      expect(m.last.entity, Entities.checkIn);
      expect(m.last.op, Ops.delete);
      expect(m.last.entityId, id);
      expect(jsonDecode(m.last.payload), {'id': id});

      expect(await repo.watchHistory().first, isEmpty);
    },
  );

  test(
    'deleting never lowers the local Starlight or glow-day projection',
    () async {
      final progress = ProgressRepository(db, KvStore(db));
      Future<ProgressProjection> project() async => projectProgress(
        events: await progress.watchEvents().first,
        now: clock.now(),
        timezone: 'Asia/Kolkata',
      );

      // Two days of check-ins.
      clock.instant = testNow.subtract(const Duration(days: 1));
      final a = ids.v7();
      await repo.save(id: a, mood: moodById('joyful')!);
      clock.instant = testNow;
      final b = ids.v7();
      final c = ids.v7();
      await repo.save(id: b, mood: moodById('calm')!);
      await repo.save(id: c, mood: moodById('numb')!);

      final before = await project();
      expect(before.totalStarlight, 22); // 10 + (10 + 2)
      await repo.delete(a);
      await repo.delete(c);
      final after = await project();

      expect(after.totalStarlight, before.totalStarlight);
      expect(after.todayStarlight, before.todayStarlight);
      expect(after.streak.lifetimeGlowDays, before.streak.lifetimeGlowDays);
      expect(after.streak.glowStreak, before.streak.glowStreak);
      expect(after.stage, before.stage);
    },
  );

  test('recent custom tags: own tags only, newest first, no deleted ones, '
      'at most 10', () async {
    Future<String> at(int minutes, List<String> tags) async {
      clock.instant = testNow.add(Duration(minutes: minutes));
      final id = ids.v7();
      await repo.save(id: id, mood: moodById('calm')!, tags: tags);
      return id;
    }

    await at(0, ['family', 'exams', 'cricket']);
    final gone = await at(1, ['secret']);
    await at(2, ['Exams', 'study', 'gym']);
    for (var i = 0; i < 10; i++) {
      await at(10 + i, ['t$i']);
    }
    await repo.delete(gone);

    final tags = await repo.recentCustomTags();
    expect(tags, hasLength(maxRecentCustomTags));
    expect(tags.first, 't9');
    expect(tags, isNot(contains('secret')));
    expect(tags, isNot(contains('study'))); // a built-in context tag

    final few = await repo.recentCustomTags(limit: 20);
    expect(few.sublist(10), ['Exams', 'gym', 'cricket']); // case-folded once
  });
}
