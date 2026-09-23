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

/// A check-in can be edited for a day after it was made; deleting works any
/// time (F1 "Edit for 24 h, delete anytime").
const Duration checkInEditWindow = Duration(hours: 24);

/// How many of the person's own custom tags the picker offers again.
const int maxRecentCustomTags = 10;

/// True while [row] may still be edited at [now]. A row whose server-side
/// note isn't readable on this phone yet is not editable: the edit would
/// overwrite that note.
bool canEditCheckIn(CheckInRow row, DateTime now) =>
    row.deletedAt == null &&
    !row.noteLocked &&
    now.toUtc().difference(row.deviceTs.toUtc()) < checkInEditWindow;

/// [CheckInRepository.edit] on a check-in that is deleted, missing or past
/// [checkInEditWindow].
class CheckInNotEditable implements Exception {
  const CheckInNotEditable();
}

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
    final cleanTags = _cleanTags(tags);

    return _db.transaction(() async {
      final inserted = await _db
          .into(_db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              id: id,
              moodId: mood.id,
              quadrant: mood.quadrant.name,
              tags: Value(cleanTags),
              note: Value(hasNote ? _clampNote(text) : null),
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

  /// Edits mood, tags and note of an existing check-in (within
  /// [checkInEditWindow]). Keeps the id, day and time, and queues an upsert
  /// of the same id: the server treats it as an edit and never re-earns
  /// (contracts/api/v1.md "Edits"). Throws [CheckInNotEditable] otherwise.
  Future<CheckInRow> edit({
    required String id,
    required Mood mood,
    List<String> tags = const [],
    String? note,
  }) {
    final text = note?.trim();
    final hasNote = text != null && text.isNotEmpty;
    final cleanTags = _cleanTags(tags);
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.checkIns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || !canEditCheckIn(row, _time.now())) {
        throw const CheckInNotEditable();
      }
      await (_db.update(_db.checkIns)..where((t) => t.id.equals(id))).write(
        CheckInsCompanion(
          moodId: Value(mood.id),
          quadrant: Value(mood.quadrant.name),
          tags: Value(cleanTags),
          note: Value(hasNote ? _clampNote(text) : null),
          synced: const Value(false),
        ),
      );
      // Stamped like the original, so if the first upsert never reached the
      // server this one is judged as the same event.
      await _outbox.enqueue(
        entity: Entities.checkIn,
        op: Ops.upsert,
        entityId: id,
        deviceTs: row.deviceTs,
        localDay: LocalDay.parse(row.localDay),
        tz: row.tz ?? _time.timezone,
        needsNote: hasNote,
        payload: {
          'id': id,
          'moodId': mood.id,
          'tags': cleanTags,
          'noteCt': null, // filled with ciphertext at push time
          'source': row.source,
        },
      );
      return (_db.select(
        _db.checkIns,
      )..where((t) => t.id.equals(id))).getSingle();
    });
  }

  /// Deletes a check-in (any time) as a tombstone plus a `delete` mutation
  /// (PRD Offline: check-ins are append-only, delete always wins).
  ///
  /// The row stays with `deletedAt` so the local projection keeps its
  /// Starlight and glow days (F1; `ProgressRepository.watchEvents` reads
  /// tombstones). Its note and tags are cleared: only what progression needs
  /// is kept. A still-queued upsert stays queued, so the server credits the
  /// same Starlight before it applies the delete.
  Future<void> delete(String id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.checkIns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final now = _time.now();
    await (_db.update(_db.checkIns)..where((t) => t.id.equals(id))).write(
      CheckInsCompanion(
        deletedAt: Value(now),
        note: const Value(null),
        tags: const Value([]),
      ),
    );
    await _outbox.enqueue(
      entity: Entities.checkIn,
      op: Ops.delete,
      entityId: id,
      deviceTs: now,
      localDay: _time.dayOf(now),
      tz: _time.timezone,
      payload: {'id': id},
    );
  });

  /// Private history: live check-ins, newest Aura day first, newest first
  /// within a day. Tombstones are left out.
  Stream<List<CheckInRow>> watchHistory() =>
      (_db.select(_db.checkIns)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.localDay),
              (t) => OrderingTerm.desc(t.deviceTs),
            ]))
          .watch();

  /// One check-in (tombstones included, so a page can tell "deleted").
  Stream<CheckInRow?> watchEntry(String id) => (_db.select(
    _db.checkIns,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// True while a mutation for [id] still waits in the outbox.
  Stream<bool> watchPending(String id) {
    final count = _db.outbox.seq.count();
    return (_db.selectOnly(_db.outbox)
          ..addColumns([count])
          ..where(_db.outbox.entityId.equals(id)))
        .watchSingle()
        .map((r) => (r.read(count) ?? 0) > 0);
  }

  /// The person's own custom tags (not one of [contextTags]) from their live
  /// check-ins, most recently used first, at most [limit]. Looks at the last
  /// 500 check-ins so it stays quick on a long history.
  Future<List<String>> recentCustomTags({
    int limit = maxRecentCustomTags,
  }) async {
    final rows =
        await (_db.select(_db.checkIns)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.deviceTs)])
              ..limit(500))
            .get();
    final builtIn = contextTags.toSet();
    final out = <String>[];
    final seen = <String>{};
    for (final r in rows) {
      for (final t in r.tags) {
        if (builtIn.contains(t) || !seen.add(t.toLowerCase())) continue;
        out.add(t);
        if (out.length >= limit) return out;
      }
    }
    return out;
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

  static List<String> _cleanTags(List<String> tags) => tags
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .take(maxTagsPerCheckIn)
      .toList();

  static String _clampNote(String text) =>
      text.substring(0, text.length.clamp(0, maxNoteLength));
}
