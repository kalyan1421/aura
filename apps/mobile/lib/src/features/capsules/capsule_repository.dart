import 'dart:async';

import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/db/database.dart';
import '../../core/ids/ids.dart';
import '../../core/security/note_cipher.dart';
import '../../core/sync/capsule_media_sync.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/time/clock.dart';
import 'capsule_media_store.dart';
import 'capsule_payload.dart';

/// How a capsule unlocks.
@immutable
sealed class CapsuleUnlock {
  const CapsuleUnlock();
}

/// At 10:00 local on [date] (7 days – 5 years after sealing).
final class DateUnlock extends CapsuleUnlock {
  const DateUnlock(this.date);

  final LocalDay date;

  @override
  bool operator ==(Object other) => other is DateUnlock && other.date == date;

  @override
  int get hashCode => date.hashCode;
}

/// On the next matching check-in: one mood ([moodId]) or a whole
/// [quadrant] — exactly one of the two.
final class MoodUnlock extends CapsuleUnlock {
  const MoodUnlock.mood(String this.moodId) : quadrant = null;
  const MoodUnlock.quadrant(Quadrant this.quadrant) : moodId = null;

  final String? moodId;
  final Quadrant? quadrant;

  @override
  bool operator ==(Object other) =>
      other is MoodUnlock &&
      other.moodId == moodId &&
      other.quadrant == quadrant;

  @override
  int get hashCode => Object.hash(moodId, quadrant);
}

/// A recording in the composer, not sealed yet.
@immutable
class CapsuleVoiceDraft {
  const CapsuleVoiceDraft({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

/// A processed (resized, EXIF-free) photo in the composer.
@immutable
class CapsulePhotoDraft {
  const CapsulePhotoDraft({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// What goes inside a capsule.
@immutable
class CapsuleContent {
  const CapsuleContent({
    this.title = '',
    this.text = '',
    this.voice,
    this.photos = const [],
  });

  final String title;
  final String text;
  final CapsuleVoiceDraft? voice;
  final List<CapsulePhotoDraft> photos;

  bool get isEmpty =>
      text.trim().isEmpty &&
      title.trim().isEmpty &&
      voice == null &&
      photos.isEmpty;
}

/// A 4th active trigger capsule on Free (REQ-CAP-04): nothing is saved.
class TriggerCapsuleLimitReached implements Exception {
  const TriggerCapsuleLimitReached();
}

/// The unlock date is outside 7 days – 5 years (REQ-CAP-01).
class CapsuleUnlockOutOfRange implements Exception {
  const CapsuleUnlockOutOfRange();
}

/// Nothing to seal (no words, voice or photo).
class CapsuleEmpty implements Exception {
  const CapsuleEmpty();
}

/// Sealed means sealed: not due, not fired, deleted or missing.
class CapsuleNotOpenable implements Exception {
  const CapsuleNotOpenable();
}

/// The unlock target of a mood capsule, or `null` for a date capsule.
MoodUnlock? moodTargetOf(CapsuleRow row) {
  if (row.unlockType != CapsuleUnlockType.mood.name) return null;
  final mood = row.triggerMoodId;
  if (mood != null) return MoodUnlock.mood(mood);
  final q = row.triggerQuadrant == null
      ? null
      : quadrantByName(row.triggerQuadrant!);
  return q == null ? null : MoodUnlock.quadrant(q);
}

/// The unlock date of a date capsule (`null` otherwise / erased).
LocalDay? unlockDateOf(CapsuleRow row) =>
    row.unlockType == CapsuleUnlockType.date.name
    ? parseCalendarDate(row.unlockLocalDate)
    : null;

/// The row as the RULES.md §9 trigger rule sees it.
TriggerCapsule triggerCapsuleOf(CapsuleRow row) => TriggerCapsule(
  id: row.id,
  unlockType:
      CapsuleUnlockType.byName(row.unlockType) ?? CapsuleUnlockType.date,
  triggerMoodId: row.triggerMoodId,
  triggerQuadrant: row.triggerQuadrant == null
      ? null
      : quadrantByName(row.triggerQuadrant!),
  sealedAt: row.sealedAt,
  armedAt: row.armedAt,
  firedAt: row.firedAt,
  openedAt: row.openedAt,
  deletedAt: row.deletedAt,
  cooldownUntil: row.cooldownUntil,
);

/// Whether a date capsule can be opened now (its 10:00 passed in [tz]).
bool isCapsuleDue(CapsuleRow row, String tz, DateTime now) {
  final date = unlockDateOf(row);
  return date != null &&
      row.deletedAt == null &&
      row.openedAt == null &&
      isDateCapsuleDue(date, tz, now);
}

/// Whether [row] may be opened now: a due date capsule, or a trigger
/// capsule that fired in this cycle and isn't opened yet.
bool isCapsuleReady(CapsuleRow row, String tz, DateTime now) {
  if (row.deletedAt != null || row.openedAt != null) return false;
  if (row.unlockType == CapsuleUnlockType.mood.name) {
    return row.firedAt != null;
  }
  return isCapsuleDue(row, tz, now);
}

/// An active trigger capsule counts toward the Free limit of 3: a mood
/// capsule, not deleted, not opened in its cycle, and on the server's side
/// (a seal the server refused lives only here and blocks nothing).
bool isActiveTrigger(CapsuleRow row) =>
    row.unlockType == CapsuleUnlockType.mood.name &&
    row.deletedAt == null &&
    row.openedAt == null &&
    row.rejected == null;

/// Local-first capsules (F4): the row and its outbox mutation are written in
/// one transaction, before any network call, so sealing, opening, firing
/// and deleting all work offline (PRD 16-offline).
///
/// Content is encrypted with the per-user data key as soon as it is sealed
/// (it waits as plaintext inside the encrypted database only when no key is
/// on the phone yet; sync seals it before the push). Media move from the
/// composer's draft folder into the capsule's folder and are sealed the same
/// way; the `seal` mutation waits until they are uploaded (`needsMedia`).
class CapsuleRepository {
  CapsuleRepository(
    this._db,
    this._outbox,
    this._time, {
    required this._store,
    this._cipher,
    this._ids = const Ids(),
  });

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final TimeContext _time;
  final CapsuleMediaStore _store;
  final Ids _ids;

  /// The signed-in person's data key if it is already on this phone (no
  /// network). `null` → content waits for sync to fetch the key.
  final Future<NoteCipher?> Function()? _cipher;

  /// Decrypted payloads by `id:ciphertext`, so a list of titles doesn't
  /// decrypt on every rebuild. In memory only.
  final Map<String, CapsulePayload> _plain = {};

  String get newId => _ids.v7();

  // ---- writes ------------------------------------------------------------------

  /// Seals a capsule with the client id [id]. Sealing the same id twice is a
  /// no-op (double tap). Throws [CapsuleEmpty], [CapsuleUnlockOutOfRange] or
  /// [TriggerCapsuleLimitReached] (nothing saved), or
  /// [CapsuleMediaException] when the media couldn't be kept.
  ///
  /// [hardMoment]: the crisis lexicon matched the title or text (PRD
  /// `sealed_in_hard_moment`); stored only inside the ciphertext.
  Future<CapsuleRow> seal({
    required String id,
    required CapsuleContent content,
    required CapsuleUnlock unlock,
    bool hardMoment = false,
  }) async {
    final existing = await row(id);
    if (existing != null) return existing;
    if (content.isEmpty) throw const CapsuleEmpty();
    final now = _time.now();
    final tz = _time.timezone;
    _checkUnlock(unlock, now, tz);
    if (unlock is MoodUnlock &&
        await activeTriggerCount() >= maxActiveTriggerCapsules) {
      throw const TriggerCapsuleLimitReached();
    }

    // Media: the draft files move into the capsule's folder.
    final files = <String, String>{};
    final refs = <CapsuleMediaRef>[];
    final voice = content.voice;
    if (voice != null) {
      files[CapsuleSlots.voice] = voice.path;
      final d = voice.duration > maxCapsuleVoiceDuration
          ? maxCapsuleVoiceDuration
          : voice.duration;
      refs.add(
        CapsuleMediaRef(slot: CapsuleSlots.voice, durationMs: d.inMilliseconds),
      );
    }
    final photos = content.photos.take(maxCapsulePhotos).toList();
    for (var i = 0; i < photos.length; i++) {
      final slot = CapsuleSlots.photo(i);
      files[slot] = photos[i].path;
      refs.add(
        CapsuleMediaRef(
          slot: slot,
          width: photos[i].width,
          height: photos[i].height,
        ),
      );
    }
    final adopted = files.isEmpty
        ? const <String, String>{}
        : await _store.adopt(id, files);

    final payload = CapsulePayload(
      title: clampCapsuleText(content.title, maxCapsuleTitleLength),
      text: clampCapsuleText(content.text, maxCapsuleTextLength),
      hardMoment: hardMoment,
      media: refs,
    ).encode();
    final cipher = await _cipher?.call();
    final ct = cipher == null
        ? null
        : await cipher.encrypt(payload, recordId: id.toLowerCase());

    final CapsuleRow saved;
    try {
      saved = await _db.transaction(() async {
        final mood = unlock is MoodUnlock ? unlock : null;
        await _db
            .into(_db.capsules)
            .insert(
              CapsulesCompanion.insert(
                id: id,
                unlockType: mood == null
                    ? CapsuleUnlockType.date.name
                    : CapsuleUnlockType.mood.name,
                unlockLocalDate: Value(
                  unlock is DateUnlock ? unlock.date.toIso() : null,
                ),
                triggerMoodId: Value(mood?.moodId),
                triggerQuadrant: Value(mood?.quadrant?.name),
                payloadCt: Value(ct),
                payloadClear: Value(ct == null ? payload : null),
                sealedAt: now,
                sealTz: Value(tz),
                armedAt: Value(mood == null ? null : capsuleArmedAt(now)),
              ),
            );
        for (final e in adopted.entries) {
          await _db
              .into(_db.capsuleMedia)
              .insert(
                CapsuleMediaCompanion.insert(
                  capsuleId: id,
                  slot: e.key,
                  file: Value(e.value),
                ),
              );
        }
        await _enqueueSeal(
          id,
          now: now,
          tz: tz,
          unlock: unlock,
          media: adopted.isNotEmpty,
        );
        return (await row(id))!;
      });
    } catch (_) {
      // Nothing was written: the draft gets its files back for a retry.
      await _store.unadopt(id, adopted, files);
      rethrow;
    }
    if (cipher != null && adopted.isNotEmpty) {
      unawaited(_sealMediaQuietly(id, adopted.keys, cipher));
    }
    return saved;
  }

  /// A trigger capsule the server refused (`trigger_capsule_limit`) becomes
  /// a date capsule: the same id is sealed again, as `date`, under a new
  /// mutation (its uploaded media stay valid). Also used for any capsule
  /// whose seal was refused for good. Throws [CapsuleUnlockOutOfRange].
  Future<void> convertToDate(String id, LocalDay date) async {
    final now = _time.now();
    final tz = _time.timezone;
    _checkUnlock(DateUnlock(date), now, tz);
    await _db.transaction(() async {
      final r = await row(id);
      if (r == null || r.deletedAt != null || r.openedAt != null) {
        throw const CapsuleNotOpenable();
      }
      await (_db.update(_db.capsules)..where((t) => t.id.equals(id))).write(
        CapsulesCompanion(
          unlockType: Value(CapsuleUnlockType.date.name),
          unlockLocalDate: Value(date.toIso()),
          triggerMoodId: const Value(null),
          triggerQuadrant: const Value(null),
          armedAt: const Value(null),
          firedAt: const Value(null),
          sealedAt: Value(now),
          sealTz: Value(tz),
          rejected: const Value(null),
          synced: const Value(false),
        ),
      );
      final media = await mediaOf(id);
      await _enqueueSeal(
        id,
        now: now,
        tz: tz,
        unlock: DateUnlock(date),
        media: media.any((m) => m.path == null && !m.failed && m.file != null),
      );
    });
  }

  /// A trigger capsule fired (RULES.md §9: the card appears after a live
  /// check-in, or "Now" on the crisis hold card). Starts the global 7-day
  /// cooldown. Returns false when it can't fire (not armed, already fired or
  /// opened, deleted, refused by the server).
  Future<bool> fire(String id) async {
    final now = _time.now();
    return _db.transaction(() async {
      final r = await row(id);
      if (r == null ||
          r.unlockType != CapsuleUnlockType.mood.name ||
          r.deletedAt != null ||
          r.firedAt != null ||
          r.openedAt != null ||
          r.rejected != null ||
          r.armedAt == null ||
          r.armedAt!.isAfter(now)) {
        return false;
      }
      await (_db.update(_db.capsules)..where((t) => t.id.equals(id))).write(
        CapsulesCompanion(
          firedAt: Value(now),
          cooldownUntil: Value(capsuleCooldownUntil(now)),
        ),
      );
      await _enqueue(id, Ops.fire, now, {'id': id, 'cycle': r.cycle});
      return true;
    });
  }

  /// Opens a capsule — one-way. A date capsule must be due (sealed means
  /// sealed: no early open); a trigger capsule must have fired in this
  /// cycle. Opening an opened capsule again is a no-op. Throws
  /// [CapsuleNotOpenable].
  Future<void> open(String id) async {
    final now = _time.now();
    final tz = _time.timezone;
    await _db.transaction(() async {
      final r = await row(id);
      if (r == null || r.deletedAt != null) throw const CapsuleNotOpenable();
      if (r.openedAt != null) return;
      if (!isCapsuleReady(r, tz, now)) throw const CapsuleNotOpenable();
      await (_db.update(_db.capsules)..where((t) => t.id.equals(id))).write(
        CapsulesCompanion(openedAt: Value(now), openedDeviceTs: Value(now)),
      );
      await _enqueue(id, Ops.open, now, {'id': id, 'cycle': r.cycle});
    });
  }

  /// "Keep for next time": an opened trigger capsule waits for its feeling
  /// again (a new cycle, armed at once; the running cooldown still holds
  /// it). Throws [TriggerCapsuleLimitReached] when 3 others are active.
  Future<void> rearm(String id) async {
    final now = _time.now();
    await _db.transaction(() async {
      final r = await row(id);
      if (r == null ||
          r.unlockType != CapsuleUnlockType.mood.name ||
          r.deletedAt != null ||
          r.openedAt == null) {
        throw const CapsuleNotOpenable();
      }
      if (await activeTriggerCount(excluding: id) >= maxActiveTriggerCapsules) {
        throw const TriggerCapsuleLimitReached();
      }
      await (_db.update(_db.capsules)..where((t) => t.id.equals(id))).write(
        CapsulesCompanion(
          cycle: Value(r.cycle + 1),
          armedAt: Value(now),
          firedAt: const Value(null),
          openedAt: const Value(null),
          openedDeviceTs: const Value(null),
        ),
      );
      await _enqueue(id, Ops.rearm, now, {'id': id, 'cycle': r.cycle});
    });
  }

  /// Deletes a capsule at any time, without showing its content: a tombstone
  /// (content and target erased; its cooldown still counts) plus a `delete`
  /// mutation. Its media files go at once.
  Future<void> delete(String id) async {
    final now = _time.now();
    await _db.transaction(() async {
      final r = await row(id);
      if (r == null || r.deletedAt != null) return;
      await (_db.update(_db.capsules)..where((t) => t.id.equals(id))).write(
        CapsulesCompanion(
          deletedAt: Value(now),
          payloadCt: const Value(null),
          payloadClear: const Value(null),
          unlockLocalDate: const Value(null),
          triggerMoodId: const Value(null),
          triggerQuadrant: const Value(null),
          notifyAt: const Value(null),
        ),
      );
      await (_db.delete(
        _db.capsuleMedia,
      )..where((t) => t.capsuleId.equals(id))).go();
      await _enqueue(id, Ops.delete, now, {'id': id});
    });
    _forget(id);
    await _store.deleteCapsule(id);
  }

  // ---- content -----------------------------------------------------------------

  /// Seals a payload that waited for the data key and returns its
  /// ciphertext (sync calls this right before the push). `null` when there
  /// is nothing to seal.
  Future<String?> sealPayload(String id, NoteCipher cipher) async {
    final r = await row(id);
    if (r == null || r.deletedAt != null) return null;
    if (r.payloadCt != null) return r.payloadCt;
    final clear = r.payloadClear;
    if (clear == null) return null;
    final ct = await cipher.encrypt(clear, recordId: id.toLowerCase());
    await (_db.update(
      _db.capsules,
    )..where((t) => t.id.equals(id) & t.payloadCt.isNull())).write(
      CapsulesCompanion(payloadCt: Value(ct), payloadClear: const Value(null)),
    );
    return ct;
  }

  /// The capsule's content, decrypted in memory, or `null` when this phone
  /// can't read it yet (no data key) or it is gone.
  Future<CapsulePayload?> payloadOf(CapsuleRow r) async {
    final clear = r.payloadClear;
    if (clear != null) {
      try {
        return CapsulePayload.decode(clear);
      } on Object {
        return null;
      }
    }
    final ct = r.payloadCt;
    if (ct == null) return null;
    final key = '${r.id}:${ct.hashCode}';
    final cached = _plain[key];
    if (cached != null) return cached;
    final cipher = await _cipher?.call();
    if (cipher == null) return null;
    try {
      final payload = CapsulePayload.decode(
        await cipher.decrypt(ct, recordId: r.id.toLowerCase()),
      );
      return _plain[key] = payload;
    } on Object catch (e) {
      debugPrint('capsules: decrypt ${e.runtimeType}');
      return null;
    }
  }

  void _forget(String id) => _plain.removeWhere((k, _) => k.startsWith('$id:'));

  /// Clears decrypted content from memory (sign-out).
  void forgetAll() => _plain.clear();

  // ---- reads -------------------------------------------------------------------

  Future<CapsuleRow?> row(String id) => (_db.select(
    _db.capsules,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<CapsuleRow?> watchRow(String id) => (_db.select(
    _db.capsules,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Every capsule the person can see (no tombstones), newest first.
  Stream<List<CapsuleRow>> watchVisible() =>
      (_db.select(_db.capsules)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.sealedAt)]))
          .watch();

  /// Every row, tombstones included (the trigger rule needs their cooldown).
  Future<List<CapsuleRow>> allRows() => _db.select(_db.capsules).get();

  Future<List<CapsuleMediaRow>> mediaOf(String capsuleId) =>
      (_db.select(_db.capsuleMedia)
            ..where((t) => t.capsuleId.equals(capsuleId))
            ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
          .get();

  /// Active trigger capsules (REQ-CAP-04 counts these against Free's 3).
  Future<int> activeTriggerCount({String? excluding}) async {
    final rows = await (_db.select(
      _db.capsules,
    )..where((t) => t.unlockType.equals(CapsuleUnlockType.mood.name))).get();
    return rows.where((r) => isActiveTrigger(r) && r.id != excluding).length;
  }

  /// Sealed capsules (not deleted, not opened) — the account-deletion
  /// confirmation says how many will be lost (contracts §3).
  Stream<int> watchSealedCount() {
    final count = _db.capsules.id.count();
    return (_db.selectOnly(_db.capsules)
          ..addColumns([count])
          ..where(
            _db.capsules.deletedAt.isNull() & _db.capsules.openedAt.isNull(),
          ))
        .watchSingle()
        .map((r) => r.read(count) ?? 0);
  }

  /// True while a mutation for [id] still waits in the outbox.
  Future<bool> isPending(String id) => _outbox.hasPending(id);

  // ---- triggers ------------------------------------------------------------------

  /// RULES.md §9 `trigger` for a saved check-in: which capsule fires (or is
  /// held, [crisis]). A backfill — its Aura day isn't the day it was made on
  /// — fires nothing. Capsules the server refused never fire.
  Future<TriggerPick> pickFor({
    required String checkInId,
    required Mood mood,
    required bool crisis,
  }) async {
    final checkIn = await (_db.select(
      _db.checkIns,
    )..where((t) => t.id.equals(checkInId))).getSingleOrNull();
    final at = checkIn?.deviceTs ?? _time.now();
    final live =
        checkIn == null ||
        LocalDay.tryParse(checkIn.localDay) ==
            auraDay(checkIn.deviceTs, checkIn.tz ?? _time.timezone);
    final rows = await allRows();
    return pickTrigger(
      [
        for (final r in rows)
          if (r.rejected == null) triggerCapsuleOf(r),
      ],
      TriggerCheckIn(
        moodId: mood.id,
        quadrant: mood.quadrant,
        deviceTs: at,
        live: live,
        crisis: crisis,
      ),
    );
  }

  // ---- internals -----------------------------------------------------------------

  void _checkUnlock(CapsuleUnlock unlock, DateTime now, String tz) {
    switch (unlock) {
      case DateUnlock(:final date):
        if (!isValidUnlockDate(now, tz, date.toIso())) {
          throw const CapsuleUnlockOutOfRange();
        }
      case MoodUnlock(:final moodId, :final quadrant):
        if ((moodId == null) == (quadrant == null) ||
            (moodId != null && moodById(moodId) == null)) {
          throw ArgumentError('A mood capsule needs one mood or one quadrant');
        }
    }
  }

  Future<void> _enqueueSeal(
    String id, {
    required DateTime now,
    required String tz,
    required CapsuleUnlock unlock,
    required bool media,
  }) => _outbox.enqueue(
    entity: Entities.capsule,
    op: Ops.seal,
    entityId: id,
    deviceTs: now,
    localDay: _time.dayOf(now), // ignored for capsules
    tz: tz,
    // The ciphertext is read from the row at push time (sealed then if it
    // still waits for the key): the outbox never holds content.
    needsNote: true,
    needsMedia: media,
    payload: {
      'id': id,
      'payloadCt': null,
      ...switch (unlock) {
        DateUnlock(:final date) => {
          'unlockType': CapsuleUnlockType.date.name,
          'unlockLocalDate': date.toIso(),
        },
        MoodUnlock(:final moodId, :final quadrant) => {
          'unlockType': CapsuleUnlockType.mood.name,
          'triggerMoodId': ?moodId,
          'triggerQuadrant': ?quadrant?.name,
        },
      },
    },
  );

  Future<void> _enqueue(
    String id,
    String op,
    DateTime now,
    Map<String, Object?> payload,
  ) => _outbox.enqueue(
    entity: Entities.capsule,
    op: op,
    entityId: id,
    deviceTs: now,
    localDay: _time.dayOf(now), // ignored for capsules
    tz: _time.timezone,
    payload: payload,
  );

  Future<void> _sealMediaQuietly(
    String id,
    Iterable<String> slots,
    NoteCipher cipher,
  ) async {
    for (final slot in slots) {
      try {
        await sealCapsuleMediaSlot(_db, _store, id, slot, cipher: cipher);
      } catch (e) {
        // Stays raw in the private, backup-excluded folder; sync seals it
        // before uploading.
        debugPrint('capsules: seal media ${e.runtimeType}');
      }
    }
  }
}
