import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// What the app saves always fits the server's rules (contracts/api/v1.md):
/// tags ≤ 20 and notes ≤ 500 grapheme clusters, and an edit carries
/// `editedAt` so the server can judge the 24 h window while the mutation
/// keeps the original `deviceTs`.
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

  test('an edit keeps the original deviceTs and adds editedAt = now', () async {
    final id = ids.v7();
    await repo.save(id: id, mood: moodById('calm')!);
    final editAt = testNow.add(const Duration(hours: 5));
    clock.instant = editAt;

    await repo.edit(id: id, mood: moodById('anxious')!);

    final edit = (await outbox()).last;
    expect(edit.deviceTs.toUtc(), testNow);
    final payload = jsonDecode(edit.payload) as Map<String, dynamic>;
    expect(DateTime.parse(payload['editedAt'] as String), editAt);
    // The first save is not an edit.
    final first = jsonDecode((await outbox()).first.payload) as Map;
    expect(first.containsKey('editedAt'), isFalse);
  });

  test('tags are cut to 20 characters without splitting a syllable', () async {
    // 25 Telugu syllables (each several code units).
    final long = List.filled(25, 'క్ష').join();
    final row = await repo.save(
      id: ids.v7(),
      mood: moodById('calm')!,
      tags: [long],
    );
    expect(row.tags.single.characters.length, 20);
    expect(row.tags.single, List.filled(20, 'క్ష').join());
  });

  test('a note is cut at 500 characters between emoji, never inside one',
      () async {
    final note = List.filled(501, '🌙').join();
    final row = await repo.save(
      id: ids.v7(),
      mood: moodById('calm')!,
      note: note,
    );
    expect(row.note!.characters.length, 500);
    expect(row.note!.characters.every((c) => c == '🌙'), isTrue);
  });
}
