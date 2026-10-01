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

  /// W02 (RULES.md section 13): the Aura day (`YYYY-MM-DD`) the person chose
  /// "treat this as a commitment"; `null` = not a commitment, never decays.
  /// Schema v6.
  TextColumn get committedFrom => text().nullable()();

  /// W02: a person-chosen pause; needs [committedFrom]. Schema v6.
  TextColumn get pausedThrough => text().nullable()();

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

/// F4 time capsules (schema v5): a mirror of `public.capsules`
/// (contracts/api/v1-capsules.md §3) plus this phone's own bookkeeping.
///
/// **Sealed means sealed**, on the phone too: the content (title, text,
/// media descriptors, the hard-moment flag) is kept only as [payloadCt], the
/// ciphertext made with the per-user data key — exactly what the server
/// stores — and is decrypted in memory to show the title or open it. Only
/// while no data key is on this phone yet (e.g. offline before the first key
/// fetch) the payload waits as [payloadClear], inside the encrypted database
/// like a check-in note; the push seals it before anything leaves the phone.
///
/// A deleted capsule stays as a tombstone (content and unlock target
/// erased): its `cooldownUntil` still holds the global trigger cooldown.
@DataClassName('CapsuleRow')
class Capsules extends Table {
  TextColumn get id => text()();

  /// `date` | `mood`.
  TextColumn get unlockType => text()();

  /// Date capsules: opens at 10:00 on this date (`YYYY-MM-DD`) in the
  /// current zone.
  TextColumn get unlockLocalDate => text().nullable()();

  /// Mood capsules: exactly one of these two.
  TextColumn get triggerMoodId => text().nullable()();
  TextColumn get triggerQuadrant => text().nullable()();

  /// DS-1 ciphertext of the payload (AD = the capsule id). `null` on
  /// tombstones and while [payloadClear] waits for the data key.
  TextColumn get payloadCt => text().nullable()();

  /// The payload JSON, only until a data key seals it (never synced).
  TextColumn get payloadClear => text().nullable()();

  /// Device time of sealing, and the zone it was sealed in (the window's
  /// calendar date).
  DateTimeColumn get sealedAt => dateTime()();
  TextColumn get sealTz => text().nullable()();

  /// Mood capsules: may fire from here (seal + 24 h, or the re-arm time).
  DateTimeColumn get armedAt => dateTime().nullable()();

  /// Re-arms so far ("Keep for next time"); sent with open/fire/rearm.
  IntColumn get cycle => integer().withDefault(const Constant(0))();

  /// Fire time in the current cycle (earliest wins across devices).
  DateTimeColumn get firedAt => dateTime().nullable()();

  /// Most recent fire + 168 h. The global cooldown is the max over all rows,
  /// tombstones included.
  DateTimeColumn get cooldownUntil => dateTime().nullable()();

  /// First open in the current cycle: the server's time once pulled, this
  /// phone's until then. One-way.
  DateTimeColumn get openedAt => dateTime().nullable()();
  DateTimeColumn get openedDeviceTs => dateTime().nullable()();

  /// Tombstone.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The server row's `updated_at` (last pull that touched it).
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  /// The seal reached the server (acknowledged, or pulled).
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// The server refused the seal for good (`trigger_capsule_limit`,
  /// `invalid_unlock_date`, `date_capsule_limit`): the capsule lives only
  /// on this phone until the person changes it (e.g. makes it a date
  /// capsule, which re-seals the same id).
  TextColumn get rejected => text().nullable()();

  /// When this phone's local "ready to open" notification fires (date
  /// capsules; `null` when none is scheduled). Lets the push handler skip
  /// the server's backup push for the same capsule.
  DateTimeColumn get notifyAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A capsule's media on this phone and on the server (schema v5): one row
/// per slot (`voice`, `photo-0` … `photo-2`).
///
/// [file] is a file name in the capsule's folder of `CapsuleMediaStore`:
/// `<slot>.enc` is sealed with the data key (AD = `<capsule id>/<slot>`) —
/// exactly the bytes uploaded; a raw file (`<slot>.m4a` / `.jpg`) only
/// exists until a data key is on this phone. [path] is the server object
/// (`<user_id>/capsules/<id>/<slot>`) once uploaded or known to exist.
@DataClassName('CapsuleMediaRow')
class CapsuleMedia extends Table {
  TextColumn get capsuleId => text()();
  TextColumn get slot => text()();
  TextColumn get file => text().nullable()();
  TextColumn get path => text().nullable()();

  /// Failed uploads, and when to try again (uploads keep retrying after the
  /// seal was pushed without them).
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// The upload can never succeed (e.g. too large): stop trying.
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {capsuleId, slot};
}

/// U07 Orbit Loom: the constellations kept in the Reflection sky (schema
/// v7). Cosmetic (RULES.md section 14): the shape as kept (`[[x, y], ...]`
/// and `[[a, b], ...]` JSON) and an optional neutral meaning key. Letting one
/// go sets [deletedAt] and erases the shape, as the server does; the row stays
/// so the delete can be pushed and a later pull cannot bring it back.
@DataClassName('LoomConstellationRow')
class LoomConstellations extends Table {
  TextColumn get id => text()();
  TextColumn get stars => text().nullable()();
  TextColumn get links => text().nullable()();
  TextColumn get meaning => text().nullable()();

  /// The Aura day it was kept (the per-day limit).
  TextColumn get localDay => text()();
  DateTimeColumn get deviceTs => dateTime()();
  TextColumn get tz => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The server holds it (pushed and applied, or pulled).
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
