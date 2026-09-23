import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_notifications.dart';
import 'package:aura/src/features/capsules/capsule_photo_picker.dart';
import 'package:aura/src/features/capsules/capsule_providers.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Test doubles for F4 capsules: no notification plugin, no photo picker,
/// files in a temp directory.

const String capsuleTestUser = 'user-1';

/// 32 bytes, base64: the test data key.
const String capsuleTestKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';

NoteCipher testCipher() => NoteCipher(SecretKey(base64.decode(capsuleTestKey)));

/// A secure store that already holds [capsuleTestUser]'s data key.
MemorySecureStore secureWithKey() => MemorySecureStore({
  SecureKeys.dataKey(capsuleTestUser): jsonEncode({
    'keyId': 'k1',
    'dataKey': capsuleTestKey,
  }),
});

class SignedInAuth implements AuthRepository {
  AuthUser? user = const AuthUser(id: capsuleTestUser, email: 'a@b.c');

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(user);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async => user = null;
}

/// Notification plugin stand-in: remembers what is scheduled.
class FakeNoticePort implements LocalNoticePort {
  final Map<int, DateTime> scheduled = {};
  final Map<int, String> payloads = {};
  final List<String> bodies = [];
  final List<int> cancelled = [];
  int scheduleCalls = 0;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required CapsuleNoticeText text,
    required String payload,
  }) async {
    scheduleCalls++;
    scheduled[id] = at;
    payloads[id] = payload;
    bodies.add(text.body);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    payloads.remove(id);
  }

  @override
  Future<List<int>> pendingIds() async => scheduled.keys.toList();
}

/// Hands the composer these images (already encoded) on each pick.
class FakePhotoPicker implements CapsulePhotoPicker {
  FakePhotoPicker(this.images);

  List<Uint8List> images;
  final List<int> limits = [];

  @override
  Future<List<Uint8List>> pick({required int limit}) async {
    limits.add(limit);
    return images.take(limit).toList();
  }
}

CapsuleMediaStore tempCapsuleStore(Directory root) => CapsuleMediaStore(
  root: () async => root,
  temp: () async => Directory('${root.path}/tmp'),
);

/// Provider overrides for widget tests (on top of `testOverrides`).
List<Override> capsuleOverrides({
  required CapsuleMediaStore store,
  FakeNoticePort? port,
  CapsulePhotoPicker? picker,
}) => [
  capsuleMediaStoreProvider.overrideWithValue(store),
  capsuleNoticePortProvider.overrideWithValue(port ?? FakeNoticePort()),
  if (picker != null) capsulePhotoPickerProvider.overrideWithValue(picker),
];
