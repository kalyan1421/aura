import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aura/src/core/security/note_cipher.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// DS-1 envelope for media: the same `0x01 | nonce | ct | tag` as notes, as
/// raw bytes, bound to the check-in id.
void main() {
  final key = NoteCipher(SecretKey(List<int>.generate(32, (i) => i)));
  final other = NoteCipher(SecretKey(List<int>.generate(32, (i) => 31 - i)));
  const id = '0199aaaa-0000-7000-8000-000000000001';

  Uint8List audio(int n) {
    final r = Random(7);
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  test(
    'bytes round-trip; the envelope is exactly plaintext + overhead',
    () async {
      final clear = audio(480 * 1024); // ≈ 60 s at 64 kbps
      final sealed = await key.encryptBytes(clear, recordId: id);
      expect(sealed.length, clear.length + NoteCipher.overhead);
      expect(sealed[0], 1);
      expect(await key.decryptBytes(sealed, recordId: id), clear);
    },
  );

  test(
    'a fresh nonce each time: the same recording seals differently',
    () async {
      final clear = audio(1000);
      final a = await key.encryptBytes(clear, recordId: id);
      final b = await key.encryptBytes(clear, recordId: id);
      expect(a, isNot(b));
    },
  );

  test('bound to the check-in id, the key, and untampered bytes', () async {
    final sealed = await key.encryptBytes(audio(2048), recordId: id);
    expect(
      () => key.decryptBytes(sealed, recordId: 'other-id'),
      throwsA(anything),
    );
    expect(() => other.decryptBytes(sealed, recordId: id), throwsA(anything));
    final flipped = Uint8List.fromList(sealed)..[40] ^= 1;
    expect(() => key.decryptBytes(flipped, recordId: id), throwsA(anything));
    expect(
      () => key.decryptBytes(Uint8List(10), recordId: id),
      throwsA(isA<FormatException>()),
    );
  });

  test('notes keep their format: base64 of the same byte envelope', () async {
    final ct = await key.encrypt('missing home', recordId: id);
    expect(
      utf8.decode(await key.decryptBytes(base64.decode(ct), recordId: id)),
      'missing home',
    );
    final fromBytes = base64.encode(
      await key.encryptBytes(utf8.encode('chai'), recordId: id),
    );
    expect(await key.decrypt(fromBytes, recordId: id), 'chai');
  });
}
