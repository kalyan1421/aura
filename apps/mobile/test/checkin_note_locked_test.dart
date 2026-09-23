import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A pulled check-in whose server-side note this phone can't read yet must
/// not be editable: an edit rewrites `note_ct` on the server and would erase
/// the note (contracts/api/v1.md "Edits").
void main() {
  late AppDatabase db;
  late CheckInRepository repo;
  const ids = Ids();

  setUp(() {
    db = memoryDb();
    repo = CheckInRepository(
      db,
      OutboxRepository(db, ids),
      TimeContext(clock: FixedClock(testNow), timezone: 'Asia/Kolkata'),
    );
  });
  tearDown(() => db.close());

  Future<void> insertPulled({required bool noteLocked}) => db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          id: 'pulled-1',
          moodId: 'calm',
          quadrant: 'moonlight',
          localDay: '2026-10-08',
          deviceTs: testNow.subtract(const Duration(hours: 1)),
          tzOffsetMinutes: 0,
          synced: const Value(true),
          noteLocked: Value(noteLocked),
        ),
      );

  test('a locked note blocks editing, inside the 24 h window too', () async {
    await insertPulled(noteLocked: true);
    final row = await (db.select(db.checkIns)).getSingle();

    expect(canEditCheckIn(row, testNow), isFalse);
    await expectLater(
      repo.edit(id: row.id, mood: moodById('anxious')!, tags: const []),
      throwsA(isA<CheckInNotEditable>()),
    );
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('once the note is readable the same check-in is editable', () async {
    await insertPulled(noteLocked: false);
    final row = await (db.select(db.checkIns)).getSingle();

    expect(canEditCheckIn(row, testNow), isTrue);
  });
}
