import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/photo_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'capsules_fakes.dart';

/// Capsule photos are resized to ≤ 2,048 px and every metadata block (EXIF
/// with GPS, camera, orientation) is stripped on the phone before anything
/// is kept (PRD F4, 15-permissions); media files live in the private
/// capsule store, sealed per slot, and are wiped at sign-out.
void main() {
  /// A camera-like JPEG: EXIF with camera, GPS and "rotate 90°".
  Uint8List cameraJpeg({int w = 3000, int h = 1500, int orientation = 6}) {
    final src = img.Image(width: w, height: h);
    img.fill(src, color: img.ColorRgb8(200, 120, 60));
    // A marker in the top-left corner to check the rotation.
    img.fillRect(src, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(0, 0, 255));
    src.exif.imageIfd.make = 'AuraTestCam';
    src.exif.imageIfd.model = 'Model-X';
    src.exif.imageIfd.orientation = orientation;
    src.exif.gpsIfd.setGpsLocation(latitude: 17.3850, longitude: 78.4867);
    return img.encodeJpg(src, quality: 90);
  }

  bool containsAscii(Uint8List bytes, String s) {
    final needle = ascii.encode(s);
    outer:
    for (var i = 0; i <= bytes.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  group('photo processing', () {
    test('the fixture really carries EXIF and GPS', () {
      final input = cameraJpeg();
      final decoded = img.decodeJpg(input)!;
      expect(decoded.exif.gpsIfd.hasGPSLatitude, isTrue);
      expect(decoded.exif.imageIfd.make, 'AuraTestCam');
      expect(containsAscii(input, 'Exif'), isTrue);
      expect(containsAscii(input, 'AuraTestCam'), isTrue);
    });

    test('EXIF/GPS stripped, upright, long edge ≤ 2,048 px', () {
      final out = processCapsulePhoto(cameraJpeg());
      // Orientation 6 → the upright photo is portrait: 1500×3000 → 1024×2048.
      expect(out.width, 1024);
      expect(out.height, 2048);
      final decoded = img.decodeJpg(out.jpeg)!;
      expect(decoded.width, 1024);
      expect(decoded.height, 2048);
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(decoded.exif.imageIfd.hasOrientation, isFalse);
      expect(decoded.iccProfile, isNull);
      // Nothing of the metadata survives in the bytes either.
      expect(containsAscii(out.jpeg, 'Exif'), isFalse);
      expect(containsAscii(out.jpeg, 'AuraTestCam'), isFalse);
      expect(containsAscii(out.jpeg, 'Model-X'), isFalse);
      // Rotated 90° clockwise: the blue corner is now top-right.
      final corner = decoded.getPixel(decoded.width - 10, 10);
      expect(corner.b, greaterThan(200));
      expect(corner.r, lessThan(60));
    });

    test('a small photo keeps its size (still stripped)', () {
      final out = processCapsulePhoto(cameraJpeg(w: 800, h: 600, orientation: 1));
      expect((out.width, out.height), (800, 600));
      expect(img.decodeJpg(out.jpeg)!.exif.isEmpty, isTrue);
    });

    test('a landscape photo caps its width', () {
      final out = processCapsulePhoto(cameraJpeg(w: 4096, h: 3072, orientation: 1));
      expect((out.width, out.height), (2048, 1536));
    });

    test('transparent PNG is flattened onto white', () {
      final png = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(png, color: img.ColorRgba8(0, 0, 0, 0));
      final out = processCapsulePhoto(img.encodePng(png));
      final p = img.decodeJpg(out.jpeg)!.getPixel(5, 5);
      expect(p.r, greaterThan(240));
      expect(p.g, greaterThan(240));
    });

    test('something that is not an image is refused', () {
      expect(
        () => processCapsulePhoto(Uint8List.fromList(utf8.encode('not a photo'))),
        throwsA(isA<PhotoUnreadable>()),
      );
    });

    test('runs off the UI isolate', () async {
      final out = await processCapsulePhotoInBackground(
        cameraJpeg(w: 2500, h: 100, orientation: 1),
      );
      expect(out.width, 2048);
    });
  });

  group('capsule media store', () {
    late Directory root;
    late CapsuleMediaStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('aura-capsule-store');
      store = tempCapsuleStore(root);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('adopt moves draft files; seal writes `<slot>.enc` and drops the raw', () async {
      final photo = await store.writeDraftPhoto('d1', Uint8List.fromList([1, 2, 3]));
      final adopted = await store.adopt('CAP', {'photo-0': photo});
      expect(adopted, {'photo-0': 'photo-0.jpg'});
      expect(File(photo).existsSync(), isFalse);
      final sealed = await store.seal(
        'CAP',
        'photo-0',
        'photo-0.jpg',
        cipher: testCipher(),
      );
      expect(sealed, 'photo-0.enc');
      expect(await store.read('CAP', 'photo-0.jpg'), isNull);
      final clear = await testCipher().decryptBytes(
        (await store.read('CAP', 'photo-0.enc'))!,
        recordId: 'cap/photo-0',
      );
      expect(clear, [1, 2, 3]);
    });

    test('a missing draft file adopts nothing', () async {
      await expectLater(
        store.adopt('X', {'voice': '${root.path}/nope.m4a'}),
        throwsA(isA<CapsuleMediaException>()),
      );
    });

    test('sweep keeps what is referenced (and anything recent)', () async {
      await store.adopt('keep', {
        'photo-0': await store.writeDraftPhoto('d', Uint8List(4)),
      });
      await store.adopt('orphan', {
        'photo-0': await store.writeDraftPhoto('d', Uint8List(4)),
      });
      await store.writeDraftPhoto('draft-kept', Uint8List(4));
      await store.writeDraftPhoto('draft-old', Uint8List(4));

      // Just made: nothing is swept yet (a seal may be in flight).
      await store.sweep(keep: {'keep'}, keepDrafts: {'draft-kept'});
      expect(Directory('${root.path}/capsules/orphan').existsSync(), isTrue);

      await store.sweep(
        keep: {'keep'},
        keepDrafts: {'draft-kept'},
        now: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(Directory('${root.path}/capsules/keep').existsSync(), isTrue);
      expect(Directory('${root.path}/capsules/orphan').existsSync(), isFalse);
      expect(
        Directory('${root.path}/capsules/drafts/draft-kept').existsSync(),
        isTrue,
      );
      expect(
        Directory('${root.path}/capsules/drafts/draft-old').existsSync(),
        isFalse,
      );
    });

    test('wipeAll removes every capsule file and decrypted copy', () async {
      await store.adopt('a', {
        'photo-0': await store.writeDraftPhoto('d', Uint8List(4)),
      });
      await store.writeDraftPhoto('draft', Uint8List(4));
      final tmp = await store.writeTemp(Uint8List(4), extension: '.jpg');
      expect(tmp.existsSync(), isTrue);
      await store.wipeAll();
      expect(Directory('${root.path}/capsules').existsSync(), isFalse);
      expect(tmp.existsSync(), isFalse);
      // Usable again afterwards.
      await store.writeDraftPhoto('new', Uint8List(4));
      expect(Directory('${root.path}/capsules/drafts/new').existsSync(), isTrue);
    });
  });
}
