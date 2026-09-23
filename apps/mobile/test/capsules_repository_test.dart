import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/sync/capsule_media_sync.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_payload.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

import 'capsules_fakes.dart';
import 'helpers.dart';

/// F4 local-first capsules: sealing (window, limits, encryption at rest,
/// media, hard moment), the outbox ops (seal/open/fire/rearm/delete) and the
/// trigger evaluation for a saved check-in.
void main() {
  late Directory root;
  late AppDatabase db;
  late OutboxRepository outbox;
  late CapsuleMediaStore store;
  late FixedClock clock;
  late TimeContext time;
  NoteCipher? key;

  CapsuleRepository repo() => CapsuleRepository(
    db,
    outbox,
    time,
    store: store,
    cipher: () async => key,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-capsules-repo');
    db = memoryDb();
    outbox = OutboxRepository(db, const Ids());
    store = tempCapsuleStore(root);
    clock = FixedClock(testNow); // 15:30 IST, 8 Oct 2026
    time = TimeContext(clock: clock, timezone: 'Asia/Kolkata');
    key = testCipher();
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<List<OutboxRow>> queued() => (db.select(
    db.outbox,
  )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  Map<String, dynamic> payloadOf(OutboxRow r) =>
      jsonDecode(r.payload) as Map<String, dynamic>;

  Future<CapsulePayload> decrypt(CapsuleRow r) async => CapsulePayload.decode(
    await testCipher().decrypt(r.payloadCt!, recordId: r.id.toLowerCase()),
  );

  group('seal', () {
    test('a date capsule: ciphertext at rest, one seal mutation', () async {
      final r = repo();
      final row = await r.seal(
        id: 'c0192f0c-0000-7000-8000-00000000000a',
        content: const CapsuleContent(title: 'For Arjun', text: 'You made it.'),
        unlock: DateUnlock(LocalDay.parse('2027-10-08')),
      );
      expect(row.unlockType, 'date');
      expect(row.unlockLocalDate, '2027-10-08');
      expect(row.triggerMoodId, isNull);
      expect(row.armedAt, isNull);
      expect(row.sealTz, 'Asia/Kolkata');
      expect(row.payloadClear, isNull, reason: 'decrypted only in memory');
      expect(row.payloadCt, isNotNull);
      // Only ciphertext: nothing readable in the stored value.
      expect(row.payloadCt, isNot(contains('Arjun')));
      final p = await decrypt(row);
      expect(p.title, 'For Arjun');
      expect(p.text, 'You made it.');
      expect(p.hardMoment, isFalse);
      expect(await r.payloadOf(row), p);

      final o = await queued();
      expect(o, hasLength(1));
      expect(o.single.entity, Entities.capsule);
      expect(o.single.op, Ops.seal);
      expect(o.single.needsNote, isTrue, reason: 'ciphertext filled at push');
      expect(o.single.needsMedia, isFalse);
      expect(o.single.tz, 'Asia/Kolkata');
      expect(o.single.deviceTs, testNow);
      expect(payloadOf(o.single), {
        'id': 'c0192f0c-0000-7000-8000-00000000000a',
        'payloadCt': null,
        'unlockType': 'date',
        'unlockLocalDate': '2027-10-08',
      });
    });

    test('without a data key the payload waits, then seals at push', () async {
      key = null;
      final r = repo();
      final row = await r.seal(
        id: 'c1',
        content: const CapsuleContent(text: 'later'),
        unlock: DateUnlock(LocalDay.parse('2026-12-01')),
      );
      expect(row.payloadCt, isNull);
      expect(CapsulePayload.decode(row.payloadClear!).text, 'later');

      final ct = await r.sealPayload('c1', testCipher());
      final sealed = (await r.row('c1'))!;
      expect(sealed.payloadCt, ct);
      expect(sealed.payloadClear, isNull);
      expect((await decrypt(sealed)).text, 'later');
    });

    test('REQ-CAP-01: 7 days to 5 years after the seal date only', () async {
      final r = repo();
      Future<void> seal(String id, String date) => r.seal(
        id: id,
        content: const CapsuleContent(text: 'x'),
        unlock: DateUnlock(LocalDay.parse(date)),
      );
      await expectLater(
        seal('a', '2026-10-14'),
        throwsA(isA<CapsuleUnlockOutOfRange>()),
      );
      await expectLater(
        seal('b', '2031-10-09'),
        throwsA(isA<CapsuleUnlockOutOfRange>()),
      );
      await seal('c', '2026-10-15');
      await seal('d', '2031-10-08');
      expect((await r.allRows()).map((c) => c.id), ['c', 'd']);
      expect(await queued(), hasLength(2));
    });

    test('a mood capsule arms 24 h after sealing; one target only', () async {
      final r = repo();
      final row = await r.seal(
        id: 'm1',
        content: const CapsuleContent(text: 'breathe'),
        unlock: const MoodUnlock.mood('overwhelmed'),
      );
      expect(row.unlockType, 'mood');
      expect(row.triggerMoodId, 'overwhelmed');
      expect(row.triggerQuadrant, isNull);
      expect(row.armedAt, testNow.add(const Duration(hours: 24)));
      expect(payloadOf((await queued()).single), {
        'id': 'm1',
        'payloadCt': null,
        'unlockType': 'mood',
        'triggerMoodId': 'overwhelmed',
      });

      final q = await r.seal(
        id: 'm2',
        content: const CapsuleContent(text: 'rain'),
        unlock: const MoodUnlock.quadrant(Quadrant.rain),
      );
      expect(q.triggerQuadrant, 'rain');
      expect(payloadOf((await queued()).last)['triggerQuadrant'], 'rain');
      expect(payloadOf((await queued()).last).containsKey('triggerMoodId'), isFalse);
    });

    test('REQ-CAP-04: a 4th active trigger capsule is refused; dates never', () async {
      final r = repo();
      for (var i = 0; i < 3; i++) {
        await r.seal(
          id: 'm$i',
          content: const CapsuleContent(text: 'x'),
          unlock: const MoodUnlock.quadrant(Quadrant.storm),
        );
      }
      await expectLater(
        r.seal(
          id: 'm3',
          content: const CapsuleContent(text: 'x'),
          unlock: const MoodUnlock.mood('calm'),
        ),
        throwsA(isA<TriggerCapsuleLimitReached>()),
      );
      expect(await r.row('m3'), isNull, reason: 'nothing stored');
      // Date capsules never hit the limit.
      await r.seal(
        id: 'd1',
        content: const CapsuleContent(text: 'x'),
        unlock: DateUnlock(LocalDay.parse('2027-01-01')),
      );
      expect(await r.activeTriggerCount(), 3);
    });

    test('sealing the same id twice is one capsule (double tap)', () async {
      final r = repo();
      for (var i = 0; i < 2; i++) {
        await r.seal(
          id: 'same',
          content: const CapsuleContent(text: 'once'),
          unlock: DateUnlock(LocalDay.parse('2027-01-01')),
        );
      }
      expect(await r.allRows(), hasLength(1));
      expect(await queued(), hasLength(1));
    });

    test('an empty capsule is refused', () async {
      await expectLater(
        repo().seal(
          id: 'e',
          content: const CapsuleContent(title: '  ', text: ' '),
          unlock: DateUnlock(LocalDay.parse('2027-01-01')),
        ),
        throwsA(isA<CapsuleEmpty>()),
      );
    });

    test('limits: title ≤ 60 and text ≤ 2,000 grapheme clusters', () async {
      final r = repo();
      final row = await r.seal(
        id: 'long',
        content: CapsuleContent(
          title: 'అ' * 70,
          text: '👋🏽' * 2100,
        ),
        unlock: DateUnlock(LocalDay.parse('2027-01-01')),
      );
      final p = await decrypt(row);
      expect(p.title.characters.length, maxCapsuleTitleLength);
      expect(p.text.characters.length, maxCapsuleTextLength);
      expect(p.text.endsWith('👋🏽'), isTrue, reason: 'never split');
    });

    test('hard moment: only inside the ciphertext', () async {
      final r = repo();
      final row = await r.seal(
        id: 'hard',
        content: const CapsuleContent(text: 'a heavy day'),
        unlock: DateUnlock(LocalDay.parse('2027-01-01')),
        hardMoment: true,
      );
      expect((await decrypt(row)).hardMoment, isTrue);
      final cols = await db.customSelect("PRAGMA table_info('capsules')").get();
      expect(
        cols.map((c) => c.data['name']).any((n) => '$n'.contains('hard')),
        isFalse,
      );
    });

    test('media move into the capsule, sealed per slot, seal waits for upload', () async {
      final r = repo();
      final voicePath = await store.newDraftVoicePath('draft-1');
      final voiceBytes = Uint8List.fromList(List.generate(900, (i) => i % 251));
      await File(voicePath).writeAsBytes(voiceBytes);
      final photoBytes = Uint8List.fromList(List.generate(500, (i) => i % 7));
      final photo0 = await store.writeDraftPhoto('draft-1', photoBytes);
      final photo1 = await store.writeDraftPhoto('draft-1', photoBytes);

      final row = await r.seal(
        id: 'withmedia',
        content: CapsuleContent(
          text: 'listen',
          voice: CapsuleVoiceDraft(
            path: voicePath,
            duration: const Duration(minutes: 3), // clamped to 2:00
          ),
          photos: [
            CapsulePhotoDraft(path: photo0, width: 2048, height: 1536),
            CapsulePhotoDraft(path: photo1, width: 1536, height: 2048),
          ],
        ),
        unlock: DateUnlock(LocalDay.parse('2027-01-01')),
      );
      expect(File(voicePath).existsSync(), isFalse, reason: 'moved');
      final p = await decrypt(row);
      expect(p.voice?.durationMs, 120000);
      expect(p.photos.map((m) => (m.slot, m.width, m.height)), [
        ('photo-0', 2048, 1536),
        ('photo-1', 1536, 2048),
      ]);
      expect((await queued()).single.needsMedia, isTrue);

      // Sealed with the data key per slot (AD `<id>/<slot>`).
      for (final slot in ['voice', 'photo-0', 'photo-1']) {
        final name = await sealCapsuleMediaSlot(
          db,
          store,
          'withmedia',
          slot,
          cipher: testCipher(),
        );
        expect(name, '$slot.enc');
        final sealed = await store.read('withmedia', name!);
        final clear = await testCipher().decryptBytes(
          sealed!,
          recordId: 'withmedia/$slot',
        );
        expect(clear, slot == 'voice' ? voiceBytes : photoBytes);
      }
      final media = await r.mediaOf('withmedia');
      expect(media.map((m) => (m.slot, m.file, m.path)), [
        ('photo-0', 'photo-0.enc', null),
        ('photo-1', 'photo-1.enc', null),
        ('voice', 'voice.enc', null),
      ]);
    });
  });

  group('open, fire, re-arm, delete', () {
    test('sealed means sealed: a date capsule opens from 10:00 on its day', () async {
      final r = repo();
      await r.seal(
        id: 'd',
        content: const CapsuleContent(text: 'hi'),
        unlock: DateUnlock(LocalDay.parse('2026-10-15')),
      );
      clock.instant = DateTime.utc(2026, 10, 15, 4, 29); // 09:59 IST
      await expectLater(r.open('d'), throwsA(isA<CapsuleNotOpenable>()));
      clock.instant = DateTime.utc(2026, 10, 15, 4, 30); // 10:00 IST
      await r.open('d');
      final row = (await r.row('d'))!;
      expect(row.openedAt, clock.instant);
      expect(row.openedDeviceTs, clock.instant);
      await r.open('d'); // one-way; again is a no-op
      final o = await queued();
      expect(o.map((x) => x.op), [Ops.seal, Ops.open]);
      expect(payloadOf(o.last), {'id': 'd', 'cycle': 0});
    });

    test('a trigger capsule: fire (cooldown), open, keep for next time', () async {
      final r = repo();
      await r.seal(
        id: 'm',
        content: const CapsuleContent(text: 'hi'),
        unlock: const MoodUnlock.quadrant(Quadrant.storm),
      );
      expect(await r.fire('m'), isFalse, reason: 'not armed yet');
      await expectLater(r.open('m'), throwsA(isA<CapsuleNotOpenable>()));

      clock.instant = testNow.add(const Duration(hours: 24));
      expect(await r.fire('m'), isTrue);
      var row = (await r.row('m'))!;
      expect(row.firedAt, clock.instant);
      expect(row.cooldownUntil, clock.instant.add(const Duration(hours: 168)));
      expect(await r.fire('m'), isFalse, reason: 'at most once per cycle');

      clock.instant = clock.instant.add(const Duration(minutes: 1));
      await r.open('m');
      row = (await r.row('m'))!;
      expect(row.openedAt, clock.instant);
      final cooldown = row.cooldownUntil;

      clock.instant = clock.instant.add(const Duration(minutes: 5));
      await r.rearm('m');
      row = (await r.row('m'))!;
      expect(row.cycle, 1);
      expect(row.armedAt, clock.instant, reason: 'armed at once');
      expect(row.firedAt, isNull);
      expect(row.openedAt, isNull);
      expect(row.cooldownUntil, cooldown, reason: 'the cooldown still holds');

      final o = await queued();
      expect(o.map((x) => x.op), [Ops.seal, Ops.fire, Ops.open, Ops.rearm]);
      expect(o.map((x) => payloadOf(x)['cycle']), [null, 0, 0, 0]);
      expect(o.map((x) => x.deviceTs).toSet(), hasLength(4));
    });

    test('keep for next time respects the Free limit', () async {
      final r = repo();
      await r.seal(
        id: 'first',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('calm'),
      );
      clock.instant = testNow.add(const Duration(hours: 25));
      await r.fire('first');
      await r.open('first');
      for (var i = 0; i < 3; i++) {
        await r.seal(
          id: 'other$i',
          content: const CapsuleContent(text: 'x'),
          unlock: const MoodUnlock.mood('calm'),
        );
      }
      await expectLater(
        r.rearm('first'),
        throwsA(isA<TriggerCapsuleLimitReached>()),
      );
      expect((await r.row('first'))!.openedAt, isNotNull, reason: 'unchanged');
    });

    test('delete: a tombstone without content, media or target', () async {
      final r = repo();
      final photo = await store.writeDraftPhoto('dr', Uint8List(10)..[0] = 1);
      await r.seal(
        id: 'gone',
        content: CapsuleContent(
          text: 'bye',
          photos: [CapsulePhotoDraft(path: photo, width: 1, height: 1)],
        ),
        unlock: const MoodUnlock.mood('lonely'),
      );
      clock.instant = testNow.add(const Duration(hours: 25));
      await r.fire('gone');
      final cooldown = (await r.row('gone'))!.cooldownUntil;

      await r.delete('gone');
      final row = (await r.row('gone'))!;
      expect(row.deletedAt, clock.instant);
      expect(row.payloadCt, isNull);
      expect(row.payloadClear, isNull);
      expect(row.triggerMoodId, isNull);
      expect(row.cooldownUntil, cooldown, reason: 'still holds the cooldown');
      expect(await r.mediaOf('gone'), isEmpty);
      expect(Directory('${root.path}/capsules/gone').existsSync(), isFalse);
      final o = await queued();
      expect(o.last.op, Ops.delete);
      expect(payloadOf(o.last), {'id': 'gone'});
      await r.delete('gone'); // no-op
      expect(await queued(), hasLength(o.length));
    });

    test('a refused mood capsule can become a date capsule (same id)', () async {
      final r = repo();
      await r.seal(
        id: 'refused',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('joyful'),
      );
      await (db.update(db.capsules)..where((t) => t.id.equals('refused')))
          .write(const CapsulesCompanion(rejected: Value('trigger_capsule_limit')));
      await expectLater(
        r.convertToDate('refused', LocalDay.parse('2026-10-10')),
        throwsA(isA<CapsuleUnlockOutOfRange>()),
      );
      await r.convertToDate('refused', LocalDay.parse('2027-02-01'));
      final row = (await r.row('refused'))!;
      expect(row.unlockType, 'date');
      expect(row.unlockLocalDate, '2027-02-01');
      expect(row.triggerMoodId, isNull);
      expect(row.armedAt, isNull);
      expect(row.rejected, isNull);
      final seals = (await queued()).where((o) => o.op == Ops.seal).toList();
      expect(seals, hasLength(2));
      expect(seals.last.mutationId, isNot(seals.first.mutationId));
      expect(payloadOf(seals.last), {
        'id': 'refused',
        'payloadCt': null,
        'unlockType': 'date',
        'unlockLocalDate': '2027-02-01',
      });
    });

    test('the sealed count (account deletion) skips opened and deleted', () async {
      final r = repo();
      final counts = <int>[];
      final sub = r.watchSealedCount().listen(counts.add);
      addTearDown(sub.cancel);
      for (final id in ['a', 'b', 'c']) {
        await r.seal(
          id: id,
          content: const CapsuleContent(text: 'x'),
          unlock: DateUnlock(LocalDay.parse('2026-10-15')),
        );
      }
      clock.instant = DateTime.utc(2026, 10, 15, 5);
      await r.open('a');
      await r.delete('b');
      await pumpEventQueue();
      expect(counts.last, 1);
    });
  });

  group('trigger evaluation after a check-in', () {
    late CheckInRepository checkIns;

    setUp(() => checkIns = CheckInRepository(db, outbox, time));

    Future<String> checkIn(String mood, {LocalDay? backfill}) async {
      final id = const Ids().v7();
      await checkIns.save(id: id, mood: moodById(mood)!, backfillDay: backfill);
      return id;
    }

    test('armed, matching, oldest first; crisis holds; backfill fires nothing', () async {
      final r = repo();
      await r.seal(
        id: 'q',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.quadrant(Quadrant.storm),
      );
      clock.instant = testNow.add(const Duration(hours: 1));
      await r.seal(
        id: 'm',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('anxious'),
      );
      // Not armed yet.
      var ci = await checkIn('anxious');
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('anxious')!, crisis: false),
        TriggerPick.none,
      );
      clock.instant = testNow.add(const Duration(hours: 26));
      ci = await checkIn('anxious');
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('anxious')!, crisis: false),
        const TriggerPick(fire: 'q'),
      );
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('anxious')!, crisis: true),
        const TriggerPick(hold: 'q'),
      );
      final back = await checkIn(
        'anxious',
        backfill: time.today().addDays(-1),
      );
      expect(
        await r.pickFor(checkInId: back, mood: moodById('anxious')!, crisis: false),
        TriggerPick.none,
      );
    });

    test('REQ-CAP-03: a fire holds every trigger capsule for 7 days', () async {
      final r = repo();
      for (final id in ['a', 'b']) {
        await r.seal(
          id: id,
          content: const CapsuleContent(text: 'x'),
          unlock: const MoodUnlock.quadrant(Quadrant.rain),
        );
      }
      clock.instant = testNow.add(const Duration(days: 2));
      final firedAt = clock.instant;
      expect(await r.fire('a'), isTrue);
      await r.delete('a'); // a deleted capsule's fire still counts
      clock.instant = firedAt.add(const Duration(hours: 167, minutes: 59));
      var ci = await checkIn('drained');
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('drained')!, crisis: false),
        TriggerPick.none,
      );
      clock.instant = firedAt.add(const Duration(hours: 168));
      ci = await checkIn('drained');
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('drained')!, crisis: false),
        const TriggerPick(fire: 'b'),
      );
    });

    test('a capsule the server refused never fires', () async {
      final r = repo();
      await r.seal(
        id: 'r',
        content: const CapsuleContent(text: 'x'),
        unlock: const MoodUnlock.mood('calm'),
      );
      await (db.update(db.capsules)..where((t) => t.id.equals('r'))).write(
        const CapsulesCompanion(rejected: Value('trigger_capsule_limit')),
      );
      clock.instant = testNow.add(const Duration(days: 2));
      final ci = await checkIn('calm');
      expect(
        await r.pickFor(checkInId: ci, mood: moodById('calm')!, crisis: false),
        TriggerPick.none,
      );
      expect(await r.fire('r'), isFalse);
    });
  });
}
