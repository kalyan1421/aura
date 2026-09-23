import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../core/db/database.dart';
import '../../core/security/note_cipher.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';
import '../voice/voice_store.dart';

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

/// A past check-in (F1 backfill) can be added for up to this many Aura days
/// back. The server refuses older ones (`backfill_too_old`).
const int maxBackfillDays = 7;

/// Whether a check-in for [day] can be added on [today] as a backfill:
/// 1–[maxBackfillDays] Aura days back (today itself is a live check-in).
bool isBackfillDay(LocalDay day, LocalDay today) {
  final back = today.daysSince(day);
  return back >= 1 && back <= maxBackfillDays;
}

/// [CheckInRepository.save] with a `backfillDay` outside [isBackfillDay]
/// (e.g. the 04:00 rollover moved it to 8 days back). Nothing is saved.
class BackfillOutOfRange implements Exception {
  const BackfillOutOfRange();
}

/// True while [row] may still be edited at [now]. A row whose server-side
/// note isn't readable on this phone yet is not editable: the edit would
/// overwrite that note.
bool canEditCheckIn(CheckInRow row, DateTime now) =>
    row.deletedAt == null &&
    !row.noteLocked &&
    now.toUtc().difference(row.deviceTs.toUtc()) < checkInEditWindow;

/// File names of every voice note check-ins on this phone reference (the
/// voice store deletes anything else at start: orphans).
Future<Set<String>> referencedVoiceFiles(AppDatabase db) async {
  final rows =
      await (db.selectOnly(db.checkIns)
            ..addColumns([db.checkIns.voiceFile])
            ..where(db.checkIns.voiceFile.isNotNull()))
          .get();
  return {for (final r in rows) r.read(db.checkIns.voiceFile)!};
}

/// [CheckInRepository.edit] on a check-in that is deleted, missing or past
/// [checkInEditWindow].
class CheckInNotEditable implements Exception {
  const CheckInNotEditable();
}

/// Local-first check-ins: the row and its outbox mutation are written in one
/// transaction, before any network call (REQ-CHK-02).
///
/// Voice notes (F1): a recording is moved from the drafts directory into
/// [VoiceStore] (a rename), then sealed with the per-user data key as soon
/// as one is on the phone ([sealVoice]). Its upsert waits in the outbox
/// until the upload succeeded (`needsMedia`). Saving never waits on voice:
/// when the file can't be kept (storage full, write failed) the check-in
/// saves without it and `onVoiceDropped` tells the screen (PRD F1 "Storage
/// full: text saves; voice is dropped with a notice").
class CheckInRepository {
  CheckInRepository(
    this._db,
    this._outbox,
    this._time, {
    this._voice,
    this._cipher,
  });

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;
  final VoiceStore? _voice;

  /// The signed-in person's data key if it is already on this phone (no
  /// network). `null` → a recording stays raw until sync fetches the key.
  final Future<NoteCipher?> Function()? _cipher;

  /// Saves a check-in with the client id [id]. Saving the same id twice is a
  /// no-op (double-tap on Save → one entry).
  ///
  /// [voice] is a finished draft recording (≤ 60 s). It is moved into the
  /// voice store; if that fails the check-in still saves, without voice, and
  /// [onVoiceDropped] runs.
  ///
  /// [backfillDay]: a past Aura day, for a check-in added later from History
  /// (F1 backfill). It is stored with that `local_day` but stamped now
  /// (`device_ts`, `tz`), so by RULES.md §2 it is not a live event: it earns
  /// no Starlight and is no active-day evidence (no streak effect), locally
  /// and on the server, which stores it as a backfill. Throws
  /// [BackfillOutOfRange] (nothing saved) unless it is 1–[maxBackfillDays]
  /// days back.
  Future<CheckInRow> save({
    required String id,
    required Mood mood,
    List<String> tags = const [],
    String? note,
    VoiceClip? voice,
    void Function()? onVoiceDropped,
    LocalDay? backfillDay,
  }) async {
    final now = _time.now();
    final today = _time.dayOf(now);
    if (backfillDay != null && !isBackfillDay(backfillDay, today)) {
      throw const BackfillOutOfRange();
    }
    final day = backfillDay ?? today;
    final text = note?.trim();
    final hasNote = text != null && text.isNotEmpty;
    final cleanTags = _cleanTags(tags);
    final stored = await _adopt(voice, onVoiceDropped);
    var keptVoice = false;

    final CheckInRow saved;
    try {
      saved = await _db.transaction(() async {
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
                voiceFile: Value(stored),
                voiceMs: Value(
                  stored == null ? null : _voiceMs(voice!.duration),
                ),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (inserted > 0) {
          keptVoice = stored != null;
          await _outbox.enqueue(
            entity: Entities.checkIn,
            op: Ops.upsert,
            entityId: id,
            deviceTs: now,
            localDay: day,
            tz: _time.timezone,
            needsNote: hasNote,
            // `voicePath` is added once the recording is uploaded; without
            // a voice note it is simply absent (a new check-in has none).
            needsMedia: stored != null,
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
    } catch (_) {
      // The row wasn't written: the draft keeps its recording for a retry.
      if (stored != null) await _voice?.unadopt(stored, voice!.path);
      rethrow;
    }
    if (stored != null) {
      if (keptVoice) {
        unawaited(_sealQuietly(id));
      } else {
        await _voice?.delete(stored); // the id was already saved (double tap)
      }
    }
    return saved;
  }

  /// Edits mood, tags, note and voice of an existing check-in (within
  /// [checkInEditWindow]). Keeps the id, day and time, and queues an upsert
  /// of the same id: the server treats it as an edit and never re-earns
  /// (contracts/api/v1.md "Edits"). Throws [CheckInNotEditable] otherwise.
  ///
  /// Voice: [voice] replaces the voice note with a new recording (uploaded
  /// to the same server object, then `voicePath` is sent), [removeVoice]
  /// removes it (`voicePath: null`; the server deletes the object). Neither
  /// keeps it: `voicePath` is left out of the payload, which keeps the
  /// server's value — unless this phone's recording never got uploaded, then
  /// this edit tries again to attach it.
  Future<CheckInRow> edit({
    required String id,
    required Mood mood,
    List<String> tags = const [],
    String? note,
    VoiceClip? voice,
    bool removeVoice = false,
    void Function()? onVoiceDropped,
  }) async {
    final text = note?.trim();
    final hasNote = text != null && text.isNotEmpty;
    final cleanTags = _cleanTags(tags);
    final existing = await (_db.select(
      _db.checkIns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null || !canEditCheckIn(existing, _time.now())) {
      throw const CheckInNotEditable();
    }
    final stored = await _adopt(voice, onVoiceDropped);
    String? oldFile;

    final CheckInRow edited;
    try {
      edited = await _db.transaction(() async {
        final row = await (_db.select(
          _db.checkIns,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null || !canEditCheckIn(row, _time.now())) {
          throw const CheckInNotEditable();
        }
        final replace = stored != null;
        final remove =
            !replace &&
            removeVoice &&
            (row.voiceFile != null || row.voicePath != null);
        if (replace || remove) oldFile = row.voiceFile;
        await (_db.update(_db.checkIns)..where((t) => t.id.equals(id))).write(
          CheckInsCompanion(
            moodId: Value(mood.id),
            quadrant: Value(mood.quadrant.name),
            tags: Value(cleanTags),
            note: Value(hasNote ? _clampNote(text) : null),
            synced: const Value(false),
            voiceFile: replace || remove ? Value(stored) : const Value.absent(),
            voiceMs: replace
                ? Value(_voiceMs(voice!.duration))
                : remove
                ? const Value(null)
                : const Value.absent(),
            voicePath: replace || remove
                ? const Value(null)
                : const Value.absent(),
          ),
        );
        // A recording on this phone that the server doesn't have yet (new,
        // or an earlier upload that gave up) goes with this edit.
        final needsMedia =
            replace ||
            (!remove && row.voiceFile != null && row.voicePath == null);
        // Stamped like the original, so if the first upsert never reached
        // the server this one is judged as the same event. `editedAt` is
        // when the edit happened: the server judges the 24 h edit window by
        // it.
        await _outbox.enqueue(
          entity: Entities.checkIn,
          op: Ops.upsert,
          entityId: id,
          deviceTs: row.deviceTs,
          localDay: LocalDay.parse(row.localDay),
          tz: row.tz ?? _time.timezone,
          needsNote: hasNote,
          needsMedia: needsMedia,
          payload: {
            'id': id,
            'moodId': mood.id,
            'tags': cleanTags,
            'noteCt': null, // filled with ciphertext at push time
            'source': row.source,
            // Only a removal sends `voicePath` now (null); an upload fills
            // it in at push time; otherwise it is left out (kept).
            if (remove) 'voicePath': null,
            'editedAt': _time.now().toUtc().toIso8601String(),
          },
        );
        return (_db.select(
          _db.checkIns,
        )..where((t) => t.id.equals(id))).getSingle();
      });
    } catch (_) {
      if (stored != null) await _voice?.unadopt(stored, voice!.path);
      rethrow;
    }
    await _voice?.delete(oldFile);
    if (stored != null) unawaited(_sealQuietly(id));
    return edited;
  }

  /// Deletes a check-in (any time) as a tombstone plus a `delete` mutation
  /// (PRD Offline: check-ins are append-only, delete always wins).
  ///
  /// The row stays with `deletedAt` so the local projection keeps its
  /// Starlight and glow days (F1; `ProgressRepository.watchEvents` reads
  /// tombstones). Its note, tags and voice note are cleared (the local file
  /// is deleted; the server deletes its object on the `delete`): only what
  /// progression needs is kept. A still-queued upsert stays queued, so the
  /// server credits the same Starlight before it applies the delete.
  Future<void> delete(String id) async {
    String? file;
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.checkIns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.deletedAt != null) return;
      file = row.voiceFile;
      final now = _time.now();
      await (_db.update(_db.checkIns)..where((t) => t.id.equals(id))).write(
        CheckInsCompanion(
          deletedAt: Value(now),
          note: const Value(null),
          tags: const Value([]),
          voiceFile: const Value(null),
          voiceMs: const Value(null),
          voicePath: const Value(null),
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
    await _voice?.delete(file);
  }

  // ---- voice ---------------------------------------------------------------

  /// Seals the check-in's raw recording with the data key ([cipher], or the
  /// one already on this phone) and points the row at the sealed file. A
  /// no-op when it is sealed already, gone, or no key is available yet.
  /// Throws [VoiceStoreException] when the sealed file can't be written.
  Future<void> sealVoice(String id, {NoteCipher? cipher}) async {
    final store = _voice;
    if (store == null) return;
    await store.guard('seal:$id', () async {
      final row = await (_db.select(
        _db.checkIns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final name = row?.voiceFile;
      if (name == null || VoiceStore.isSealed(name)) return;
      final key = cipher ?? await _cipher?.call();
      if (key == null) return;
      final sealed = await store.seal(name, recordId: id, cipher: key);
      if (sealed == null) return;
      // Only if the row still points at this recording (an edit may have
      // replaced or removed it meanwhile).
      final moved =
          await (_db.update(_db.checkIns)
                ..where((t) => t.id.equals(id) & t.voiceFile.equals(name)))
              .write(CheckInsCompanion(voiceFile: Value(sealed)));
      if (moved == 0) await store.delete(sealed);
      await store.delete(name);
    });
  }

  Future<void> _sealQuietly(String id) async {
    try {
      await sealVoice(id);
    } catch (e) {
      // Stays raw in the private, backup-excluded directory; sync seals it
      // before uploading.
      debugPrint('voice: seal ${e.runtimeType}');
    }
  }

  /// Moves [clip] into the store; `null` (and [onDropped]) when it can't.
  Future<String?> _adopt(VoiceClip? clip, void Function()? onDropped) async {
    if (clip == null) return null;
    final store = _voice;
    if (store == null) {
      onDropped?.call();
      return null;
    }
    try {
      return await store.adopt(clip.path);
    } catch (e) {
      debugPrint('voice: not kept (${e.runtimeType})');
      onDropped?.call();
      return null;
    }
  }

  static int _voiceMs(Duration d) =>
      (d > maxVoiceDuration ? maxVoiceDuration : d).inMilliseconds;

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

  /// Trimmed, de-duplicated, ≤ [maxTagsPerCheckIn] tags of ≤
  /// [maxCustomTagLength] characters each. Characters are grapheme clusters
  /// (a Telugu syllable or an emoji is one), the unit the server counts, so
  /// nothing the app saves is later rejected as `tag_too_long`.
  static List<String> _cleanTags(List<String> tags) => tags
      .map((t) => t.trim().characters.take(maxCustomTagLength).toString())
      .where((t) => t.isNotEmpty)
      .toSet()
      .take(maxTagsPerCheckIn)
      .toList();

  /// ≤ [maxNoteLength] characters, cut between grapheme clusters so an emoji
  /// or a Telugu conjunct is never split.
  static String _clampNote(String text) =>
      text.characters.take(maxNoteLength).toString();
}
