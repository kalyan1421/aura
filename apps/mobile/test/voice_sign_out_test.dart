import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/sign_out_service.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/voice/voice_store.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _Auth implements AuthRepository {
  AuthUser? user = const AuthUser(id: 'user-a', email: 'a@aura.test');
  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(user);
  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async => user = null;
}

/// Sign-out / account deletion (same wipe): no voice file of the account
/// stays on the phone — saved, raw, drafts or decrypted temp copies.
void main() {
  late Directory root;
  late Directory temp;
  late AppDatabase db;
  late VoiceStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-voice-wipe');
    temp = await Directory.systemTemp.createTemp('aura-voice-wipe-tmp');
    db = memoryDb();
    store = VoiceStore(root: () async => root, temp: () async => temp);
  });

  tearDown(() async {
    await db.close();
    for (final d in [root, temp]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  test('sign-out deletes every voice file with the rows', () async {
    final repo = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
      voice: store,
    );
    for (var i = 0; i < 2; i++) {
      final path = await store.newDraftPath();
      File(path).writeAsBytesSync([1, 2, 3]);
      await repo.save(
        id: const Ids().v7(),
        mood: moodById('calm')!,
        voice: VoiceClip(path: path, duration: const Duration(seconds: 1)),
      );
    }
    final draft = await store.newDraftPath();
    File(draft).writeAsBytesSync([4]);
    final decrypted = await store.writeTemp(Uint8List.fromList([5]));
    expect(
      Directory('${root.path}/voice').listSync(recursive: true),
      isNotEmpty,
    );

    await SignOutService(
      auth: _Auth(),
      db: db,
      secure: MemorySecureStore(),
      dataKeys: DataKeyRepository(MemorySecureStore()),
      unregisterPush: () async {},
      pauseSync: () async {},
      resumeSync: () {},
      afterWipe: () async {},
      wipeFiles: store.wipe,
    ).signOut();

    expect(await db.select(db.checkIns).get(), isEmpty);
    expect(Directory('${root.path}/voice').existsSync(), isFalse);
    expect(File(draft).existsSync(), isFalse);
    expect(decrypted.existsSync(), isFalse);
    // The store works again for the next person.
    final next = await store.newDraftPath();
    expect(Directory(File(next).parent.path).existsSync(), isTrue);
  });

  test('a failing file wipe never stops the sign-out', () async {
    var reset = false;
    await SignOutService(
      auth: _Auth(),
      db: db,
      secure: MemorySecureStore(),
      dataKeys: DataKeyRepository(MemorySecureStore()),
      unregisterPush: () async {},
      pauseSync: () async {},
      resumeSync: () {},
      afterWipe: () async => reset = true,
      wipeFiles: () async => throw const FileSystemException('busy'),
    ).signOut();
    expect(reset, isTrue);
  });
}
