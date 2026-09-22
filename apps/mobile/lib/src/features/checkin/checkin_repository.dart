import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';

/// Max note length (F1).
const int maxNoteLength = 500;

/// Max tags per check-in (server cap) and max custom tag length (F1).
const int maxTagsPerCheckIn = 10;
const int maxCustomTagLength = 20;

/// Local-first check-ins: the row and its outbox mutation are written in one
/// transaction, before any network call (REQ-CHK-02).
class CheckInRepository {
  CheckInRepository(this._db, this._outbox, this._time);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;

  /// Saves a check-in with the client id [id]. Saving the same id twice is a
  /// no-op (double-tap on Save → one entry).
  Future<CheckInRow> save({
    required String id,
    required Mood mood,
    List<String> tags = const [],
    String? note,
  }) async {
    final now = _time.now();
    final day = _time.dayOf(now);
    final text = note?.trim();
    final hasNote = text != null && text.isNotEmpty;
    final cleanTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .take(maxTagsPerCheckIn)
        .toList();

    return _db.transaction(() async {
      final inserted = await _db
          .into(_db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              id: id,
              moodId: mood.id,
              quadrant: mood.quadrant.name,
              tags: Value(cleanTags),
              note: Value(
                hasNote
                    ? text.substring(0, text.length.clamp(0, maxNoteLength))
                    : null,
              ),
              localDay: day.toIso(),
              deviceTs: now,
              tzOffsetMinutes: _time.offsetMinutes(now),
              tz: Value(_time.timezone),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted > 0) {
        await _outbox.enqueue(
          entity: Entities.checkIn,
          op: Ops.upsert,
          entityId: id,
          deviceTs: now,
          localDay: day,
          tz: _time.timezone,
          needsNote: hasNote,
          payload: {
            'id': id,
            'moodId': mood.id,
            'tags': cleanTags,
            'noteCt': null, // filled with ciphertext at push time
            'source': 'app',
          },
        );
      }
      return (_db.select(
        _db.checkIns,
      )..where((t) => t.id.equals(id))).getSingle();
    });
  }

  Future<String?> noteOf(String id) async {
    final row = await (_db.select(
      _db.checkIns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.note;
  }

  /// At least one check-in exists on this phone (gates the push soft ask).
  Future<bool> any() async =>
      await (_db.select(_db.checkIns)..limit(1)).getSingleOrNull() != null;

  Stream<List<CheckInRow>> watchAll() => (_db.select(
    _db.checkIns,
  )..orderBy([(t) => OrderingTerm.desc(t.deviceTs)])).watch();
}
