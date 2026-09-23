import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores a `List<String>` as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Own check-ins. The note is plaintext here because the whole database is
/// encrypted at rest; it is encrypted again with the per-user data key before
/// it leaves the device (DS-1).
@DataClassName('CheckInRow')
class CheckIns extends Table {
  TextColumn get id => text()();
  TextColumn get moodId => text()();
  TextColumn get quadrant => text()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get note => text().nullable()();

  /// Aura day (`YYYY-MM-DD`, 04:00 rollover), set on device, never recomputed.
  TextColumn get localDay => text()();
  DateTimeColumn get deviceTs => dateTime()();
  IntColumn get tzOffsetMinutes => integer()();

  /// IANA zone the day was stamped in (schema v2). `null` for rows pulled
  /// from the server.
  TextColumn get tz => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('app'))();

  /// Tombstone; deleting keeps Starlight and glow days.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// True once the server acknowledged it (or it came from a pull).
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// The server holds an encrypted note this phone can't read yet (pulled
  /// before the data key arrived, or undecryptable). An edit rewrites the
  /// server's note, so editing waits until the note is readable here
  /// (schema v3).
  BoolColumn get noteLocked => boolean().withDefault(const Constant(false))();

  // ---- voice note (F1, schema v4) ------------------------------------------

  /// This phone's copy of the voice note: a file name inside the app's
  /// private, backup-excluded voice directory (`VoiceStore`). `<rec>.enc` is
  /// sealed with the per-user data key (DS-1); `<rec>.m4a` is raw and only
  /// exists until a data key is on this phone. `null` when there is no local
  /// copy (none, or pulled from the server: played by downloading).
  TextColumn get voiceFile => text().nullable()();

  /// Recorded length in milliseconds, for display (`null` when unknown, e.g.
  /// a pulled voice note that hasn't been played here).
  IntColumn get voiceMs => integer().nullable()();

  /// The server object holding the current recording
  /// (`<user_id>/voice/<id>`, the upload's `path` verbatim): set once the
  /// upload succeeded, or by a pull. `null` while the current local
  /// recording is not uploaded yet (or there is no voice note).
  TextColumn get voicePath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // preset | custom
  TextColumn get presetKey => text().nullable()();
  TextColumn get name => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get localDay => text()();
  DateTimeColumn get deviceTs => dateTime()();

  /// IANA zone the day was stamped in (schema v2).
  TextColumn get tz => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pending mutations for `POST /v1/sync/push`, drained oldest-first.
/// The payload never holds note plaintext: `needsNote` rows get their
/// `noteCt` filled in (encrypted) right before sending; `needsMedia` rows get
/// their `voicePath` after the upload.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get mutationId => text().unique()();
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get deviceTs => dateTime()();
  TextColumn get localDay => text()();

  /// IANA zone `localDay` was stamped in, sent as `tz` (schema v2).
  TextColumn get tz => text().nullable()();
  TextColumn get payload => text()();
  BoolColumn get needsNote => boolean().withDefault(const Constant(false))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// A `check_in` upsert that goes out only after its voice note is uploaded
  /// (schema v4, like [needsNote]): `voicePath` is filled in right before
  /// sending. Cleared when the outbox gives up on the upload — the check-in
  /// then goes without it (never blocked by media).
  BoolColumn get needsMedia => boolean().withDefault(const Constant(false))();

  /// Failed upload attempts of this row's voice note (schema v4).
  IntColumn get mediaAttempts => integer().withDefault(const Constant(0))();
}

/// Mutations the server rejected (4xx) or that failed 10 times. Kept so they
/// stop blocking the queue; logged without content.
@DataClassName('DeadLetterRow')
class DeadLetters extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get mutationId => text()();
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  TextColumn get reason => text()();
  DateTimeColumn get failedAt => dateTime()();

  // v2: enough to re-queue a mutation after a repair (e.g. a habit merge).
  DateTimeColumn get deviceTs => dateTime().nullable()();
  TextColumn get localDay => text().nullable()();
  TextColumn get tz => text().nullable()();
}

/// Small app settings and caches (locale, onboarding stage, snapshot JSON…).
@DataClassName('KeyValueRow')
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
