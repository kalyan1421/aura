import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/voice/voice_store.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Local voice notes (F1 · DS-1): the recording moves into the private voice
/// store, is sealed with the data key, and its upsert waits for the upload.
void main() {
  late Directory root;
  late Directory temp;
  late AppDatabase db;
  late OutboxRepository outbox;
  late VoiceStore store;
  late CheckInRepository repo;
  final cipher = NoteCipher(SecretKey(List<int>.generate(32, (i) => i)));
  final audio = Uint8List.fromList(List<int>.generate(4000, (i) => i % 251));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-voice-root');
    temp = await Directory.systemTemp.createTemp('aura-voice-tmp');
    db = memoryDb();
    outbox = OutboxRepository(db, const Ids());
    store = VoiceStore(
      root: () async => root,
      temp: () async => temp,
      referenced: () => referencedVoiceFiles(db),
    );
    repo = CheckInRepository(db, outbox, testTime(), voice: store);
  });

  tearDown(() async {
    await db.close();
    for (final d in [root, temp]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  /// A finished draft recording, as the recorder leaves it.
  Future<VoiceClip> record([List<int>? bytes, int seconds = 12]) async {
    final path = await store.newDraftPath();
    await File(path).writeAsBytes(bytes ?? audio);
    return VoiceClip(
      path: path,
      duration: Duration(seconds: seconds),
    );
  }

  Future<CheckInRow> rowOf(String id) =>
      (db.select(db.checkIns)..where((t) => t.id.equals(id))).getSingle();

  Future<List<OutboxRow>> queued() =>
      (db.select(db.outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  File fileOf(String name) => File('${root.path}/voice/$name');

  test('a check-in with voice: the draft moves into the store, the upsert '
      'waits for the upload and carries no voicePath yet', () async {
    final clip = await record();
    final id = const Ids().v7();
    final row = await repo.save(id: id, mood: moodById('calm')!, voice: clip);

    expect(File(clip.path).existsSync(), isFalse); // moved, not copied
    expect(row.voiceFile, isNotNull);
    expect(VoiceStore.isSealed(row.voiceFile!), isFalse); // no key here
    expect(fileOf(row.voiceFile!).readAsBytesSync(), audio);
    expect(row.voiceMs, 12000);
    expect(row.voicePath, isNull);
    final m = (await queued()).single;
    expect(m.needsMedia, isTrue);
    expect(jsonDecode(m.payload), isNot(contains('voicePath')));
  });

  test('sealVoice: sealed with the data key and the check-in id, the raw '
      'file is gone', () async {
    final id = const Ids().v7();
    await repo.save(id: id, mood: moodById('calm')!, voice: await record());
    final raw = (await rowOf(id)).voiceFile!;

    await repo.sealVoice(id, cipher: cipher);

    final sealedName = (await rowOf(id)).voiceFile!;
    expect(VoiceStore.isSealed(sealedName), isTrue);
    expect(fileOf(raw).existsSync(), isFalse);
    final sealed = fileOf(sealedName).readAsBytesSync();
    expect(sealed.length, audio.length + NoteCipher.overhead);
    expect(await cipher.decryptBytes(sealed, recordId: id), audio);
    // Idempotent.
    await repo.sealVoice(id, cipher: cipher);
    expect((await rowOf(id)).voiceFile, sealedName);
  });

  test('with the key already on the phone the recording is sealed right '
      'after saving', () async {
    final sealing = CheckInRepository(
      db,
      outbox,
      testTime(),
      voice: store,
      cipher: () async => cipher,
    );
    final id = const Ids().v7();
    await sealing.save(id: id, mood: moodById('calm')!, voice: await record());
    await sealing.sealVoice(id); // waits for the save's own sealing
    expect(VoiceStore.isSealed((await rowOf(id)).voiceFile!), isTrue);
    final names = Directory('${root.path}/voice')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .toList();
    expect(names, [(await rowOf(id)).voiceFile]); // no raw copy left
  });

  test('storage full: the check-in saves without voice and says so', () async {
    final clip = VoiceClip(
      path: '${root.path}/voice/drafts/missing.m4a',
      duration: const Duration(seconds: 5),
    );
    var dropped = false;
    final id = const Ids().v7();
    final row = await repo.save(
      id: id,
      mood: moodById('calm')!,
      note: 'still here',
      voice: clip,
      onVoiceDropped: () => dropped = true,
    );
    expect(dropped, isTrue);
    expect(row.voiceFile, isNull);
    expect(row.note, 'still here');
    expect((await queued()).single.needsMedia, isFalse);
  });

  test('edit: remove sends voicePath null and deletes the file', () async {
    final id = const Ids().v7();
    await repo.save(id: id, mood: moodById('calm')!, voice: await record());
    final file = (await rowOf(id)).voiceFile!;

    await repo.edit(id: id, mood: moodById('calm')!, removeVoice: true);

    final row = await rowOf(id);
    expect(row.voiceFile, isNull);
    expect(row.voicePath, isNull);
    expect(row.voiceMs, isNull);
    expect(fileOf(file).existsSync(), isFalse);
    final edit = (await queued()).last;
    final payload = jsonDecode(edit.payload) as Map<String, dynamic>;
    expect(payload.containsKey('voicePath'), isTrue);
    expect(payload['voicePath'], isNull);
    expect(payload['editedAt'], isNotNull);
    expect(edit.needsMedia, isFalse);
  });

  test('edit: a new recording replaces the old one (uploaded again)', () async {
    final id = const Ids().v7();
    await repo.save(id: id, mood: moodById('calm')!, voice: await record());
    final old = (await rowOf(id)).voiceFile!;
    // Uploaded earlier.
    await (db.update(db.checkIns)..where((t) => t.id.equals(id))).write(
      const CheckInsCompanion(voicePath: Value('u/voice/x')),
    );

    await repo.edit(
      id: id,
      mood: moodById('joyful')!,
      voice: await record([1, 2, 3], 3),
    );

    final row = await rowOf(id);
    expect(row.voiceFile, isNot(old));
    expect(row.voicePath, isNull); // the new one isn't uploaded yet
    expect(row.voiceMs, 3000);
    expect(fileOf(old).existsSync(), isFalse);
    expect(fileOf(row.voiceFile!).readAsBytesSync(), [1, 2, 3]);
    final edit = (await queued()).last;
    expect(edit.needsMedia, isTrue);
    expect(jsonDecode(edit.payload), isNot(contains('voicePath')));
  });

  test('edit that keeps the voice: voicePath is left out (kept by the '
      'server); a recording never uploaded tries again', () async {
    final id = const Ids().v7();
    await repo.save(id: id, mood: moodById('calm')!, voice: await record());
    await repo.edit(id: id, mood: moodById('joyful')!);
    var edit = (await queued()).last;
    expect(jsonDecode(edit.payload), isNot(contains('voicePath')));
    expect(edit.needsMedia, isTrue); // not uploaded yet

    await (db.update(db.checkIns)..where((t) => t.id.equals(id))).write(
      const CheckInsCompanion(voicePath: Value('u/voice/x')),
    );
    await repo.edit(id: id, mood: moodById('calm')!);
    edit = (await queued()).last;
    expect(jsonDecode(edit.payload), isNot(contains('voicePath')));
    expect(edit.needsMedia, isFalse);
  });

  test('delete removes the local file and forgets the voice note', () async {
    final id = const Ids().v7();
    await repo.save(id: id, mood: moodById('calm')!, voice: await record());
    final file = (await rowOf(id)).voiceFile!;

    await repo.delete(id);

    final row = await rowOf(id);
    expect(row.deletedAt, isNotNull);
    expect(row.voiceFile, isNull);
    expect(row.voicePath, isNull);
    expect(fileOf(file).existsSync(), isFalse);
    expect((await queued()).last.op, Ops.delete);
  });

  test(
    'a new process sweeps drafts, decrypted copies and orphans, keeps '
    'what check-ins reference; the directory is excluded from backup',
    () async {
      final id = const Ids().v7();
      await repo.save(id: id, mood: moodById('calm')!, voice: await record());
      final kept = (await rowOf(id)).voiceFile!;
      final draft = await record(); // never saved
      File('${root.path}/voice/orphan.enc').writeAsBytesSync([1]);
      final tmp = await store.writeTemp(Uint8List.fromList([9]));

      final excluded = <String>[];
      final next = VoiceStore(
        root: () async => root,
        temp: () async => temp,
        excludeFromBackup: (p) async => excluded.add(p),
        referenced: () => referencedVoiceFiles(db),
      );
      await next.newDraftPath(); // first use starts it

      expect(fileOf(kept).existsSync(), isTrue);
      expect(File(draft.path).existsSync(), isFalse);
      expect(fileOf('orphan.enc').existsSync(), isFalse);
      expect(tmp.existsSync(), isFalse);
      expect(excluded, ['${root.path}/voice']);
    },
  );

  test('a failed row write puts the recording back into the draft', () async {
    final clip = await record();
    final id = const Ids().v7();
    await db.close(); // any write now fails
    await expectLater(
      repo.save(id: id, mood: moodById('calm')!, voice: clip),
      throwsA(anything),
    );
    expect(File(clip.path).existsSync(), isTrue);
    db = memoryDb(); // for tearDown
  });
}
