import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'capsule_payload.dart';

/// Picks photos for a capsule through the system picker: iOS PHPicker,
/// Android's picker — never a photo-library permission (PRD 15-permissions:
/// the picker shares only what the person selects). Returns the raw bytes;
/// the composer resizes and strips them ([processCapsulePhoto]) before
/// anything is kept.
abstract interface class CapsulePhotoPicker {
  /// Up to [limit] photos (1–3); empty when the person cancels.
  Future<List<Uint8List>> pick({required int limit});
}

/// [CapsulePhotoPicker] over package:image_picker. `requestFullMetadata:
/// false` keeps iOS from asking for library access. The picker's own temp
/// copies (which still carry EXIF/GPS) are deleted right after reading.
class ImagePickerCapsulePhotoPicker implements CapsulePhotoPicker {
  ImagePickerCapsulePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<Uint8List>> pick({required int limit}) async {
    if (limit < 1) return const [];
    final files = await _picker.pickMultiImage(
      limit: limit,
      // A first, native downscale (HEIC → JPEG on iOS); the exact 2,048 px
      // cap and the metadata strip happen in Dart afterwards.
      maxWidth: maxCapsulePhotoEdge.toDouble(),
      maxHeight: maxCapsulePhotoEdge.toDouble(),
      imageQuality: 92,
      requestFullMetadata: false,
    );
    final out = <Uint8List>[];
    for (final f in files.take(limit)) {
      try {
        out.add(await f.readAsBytes());
      } on Object catch (e) {
        debugPrint('capsules: picked photo unreadable (${e.runtimeType})');
      } finally {
        try {
          await File(f.path).delete();
        } on Object {
          // The picker's copy is already gone (or never was a file).
        }
      }
    }
    return out;
  }
}

/// The photo picker (tests override it).
final capsulePhotoPickerProvider = Provider<CapsulePhotoPicker>(
  (ref) => ImagePickerCapsulePhotoPicker(),
);
