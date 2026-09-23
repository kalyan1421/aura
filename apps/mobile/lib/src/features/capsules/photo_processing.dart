import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'capsule_payload.dart';

/// A capsule photo ready to keep: JPEG bytes with no metadata at all.
@immutable
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
  });

  final Uint8List jpeg;
  final int width;
  final int height;
}

/// The picked file isn't an image this phone can read.
class PhotoUnreadable implements Exception {
  const PhotoUnreadable();

  @override
  String toString() => 'PhotoUnreadable()';
}

/// Makes a picked photo safe to seal (PRD F4, 15-permissions "EXIF and
/// location metadata are stripped before storage"):
///
/// 1. decodes it (JPEG, PNG, GIF's first frame, WebP, …),
/// 2. turns it upright by its EXIF orientation,
/// 3. scales it so the long edge is at most [maxEdge] px,
/// 4. flattens transparency onto white,
/// 5. re-encodes the pixels alone as JPEG: no EXIF (GPS, camera, time), no
///    XMP/IPTC, no ICC profile, no text chunks survive.
///
/// Pure Dart and synchronous; run it off the UI isolate with
/// [processCapsulePhotoInBackground]. Throws [PhotoUnreadable].
ProcessedPhoto processCapsulePhoto(
  Uint8List input, {
  int maxEdge = maxCapsulePhotoEdge,
  int quality = 85,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const PhotoUnreadable();
  }
  // One still frame of plain 8-bit channels (a GIF's first frame, a
  // palette PNG expanded), upright by its EXIF orientation.
  var image = img.Image.from(decoded, noAnimation: true);
  if (image.hasPalette || image.format != img.Format.uint8) {
    image = image.convert(
      format: img.Format.uint8,
      numChannels: image.hasAlpha ? 4 : 3,
      noAnimation: true,
    );
  }
  image = img.bakeOrientation(image);
  final longEdge = image.width > image.height ? image.width : image.height;
  if (longEdge > maxEdge) {
    final scale = maxEdge / longEdge;
    image = img.copyResize(
      image,
      width: (image.width * scale).round().clamp(1, maxEdge),
      height: (image.height * scale).round().clamp(1, maxEdge),
      interpolation: img.Interpolation.average,
    );
  }
  if (image.hasAlpha) {
    final flat = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    )..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(flat, image);
  }
  // A fresh image of just the pixels: whatever metadata the decoder kept
  // (EXIF incl. GPS, ICC, text) is left behind.
  final clean = img.Image.from(image)
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;
  final jpeg = img.encodeJpg(clean, quality: quality);
  return ProcessedPhoto(jpeg: jpeg, width: clean.width, height: clean.height);
}

/// [processCapsulePhoto] on a background isolate (decoding a large photo
/// takes a moment; the composer stays responsive).
Future<ProcessedPhoto> processCapsulePhotoInBackground(Uint8List input) =>
    Isolate.run(() => processCapsulePhoto(input));
