import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/ids/ids.dart';
import '../../core/security/note_cipher.dart';
import 'capsule_payload.dart';

/// A capsule media file couldn't be kept (storage full, write failed, gone).
class CapsuleMediaException implements Exception {
  const CapsuleMediaException(this.reason);

  final String reason;

  @override
  String toString() => 'CapsuleMediaException($reason)';
}

/// Capsule photos and voice notes on this phone (F4; PRD 16-offline: "Voice
/// and photo files live in the app's private directory, encrypted at rest").
///
/// Layout inside the app's private support directory, under `capsules/`,
/// which is excluded from OS backup (iOS `isExcludedFromBackup`; Android has
/// backup and device transfer off for the whole app):
///
/// * `capsules/drafts/<draft id>/` — the composer's photos (already resized
///   and stripped of EXIF/GPS) and voice recordings. Drafts persist until
///   they are sealed or discarded (PRD 14-states "never lose input").
/// * `capsules/<capsule id>/<slot>.enc` — a sealed capsule's media, sealed
///   with the per-user data key (AES-256-GCM, associated data
///   `<capsule id>/<slot>`): exactly the bytes that are uploaded. A raw
///   `<slot>.m4a` / `<slot>.jpg` only exists until a data key is on the
///   phone. Downloaded ciphertext is cached here too.
///
/// Opening decrypts into the OS temp directory (`aura-capsules/`, never
/// backed up); those copies are deleted after use and at the next start.
class CapsuleMediaStore {
  CapsuleMediaStore({
    required this._root,
    required this._temp,
    Future<void> Function(String dirPath)? excludeFromBackup,
    this._ids = const Ids(),
  }) : _exclude = excludeFromBackup;

  final Future<Directory> Function() _root;
  final Future<Directory> Function() _temp;
  final Future<void> Function(String dirPath)? _exclude;
  final Ids _ids;

  Future<_Dirs>? _dirs;
  final Map<String, Future<Object?>> _locks = {};

  static const String sealedExt = '.enc';

  /// True for a file sealed with the data key.
  static bool isSealed(String name) => name.endsWith(sealedExt);

  /// The sealed file name of [slot].
  static String sealedName(String slot) => '$slot$sealedExt';

  Future<_Dirs> _ensure() {
    final existing = _dirs;
    if (existing != null) return existing;
    final created = _init();
    _dirs = created;
    created.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_dirs, created)) _dirs = null;
      },
    );
    return created;
  }

  Future<_Dirs> _init() async {
    final base = await _root();
    final root = Directory('${base.path}/capsules');
    final drafts = Directory('${root.path}/drafts');
    await drafts.create(recursive: true);
    try {
      await _exclude?.call(root.path);
    } catch (e) {
      debugPrint('capsules: backup exclusion ${e.runtimeType}');
    }
    final temp = Directory('${(await _temp()).path}/aura-capsules');
    // A new process never needs an earlier run's decrypted copies.
    await _deleteDir(temp);
    return _Dirs(root: root, drafts: drafts, temp: temp);
  }

  /// Runs [body] alone for [key] (one sealing per capsule slot at a time).
  Future<T> guard<T>(String key, Future<T> Function() body) {
    final previous = _locks[key];
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // The earlier run's error is its caller's.
        }
      }
      return body();
    }();
    _locks[key] = next;
    next.whenComplete(() {
      if (identical(_locks[key], next)) _locks.remove(key);
    }).ignore();
    return next;
  }

  // ---- drafts ------------------------------------------------------------------

  Future<Directory> _draftDir(String draftId) async {
    final dirs = await _ensure();
    final d = Directory('${dirs.drafts.path}/$draftId');
    await d.create(recursive: true);
    return d;
  }

  /// A fresh path for the recorder inside the draft [draftId].
  Future<String> newDraftVoicePath(String draftId) async =>
      '${(await _draftDir(draftId)).path}/voice-${_ids.v7()}.m4a';

  /// Keeps a processed (resized, EXIF-free) photo in the draft; returns its
  /// path. Throws [CapsuleMediaException] when it can't be written.
  Future<String> writeDraftPhoto(String draftId, Uint8List jpeg) async {
    try {
      final dir = await _draftDir(draftId);
      final f = File('${dir.path}/photo-${_ids.v7()}.jpg');
      await f.writeAsBytes(jpeg, flush: true);
      return f.path;
    } on FileSystemException catch (e) {
      debugPrint('capsules: draft photo ${e.osError?.errorCode}');
      throw const CapsuleMediaException('write_failed');
    }
  }

  /// Whether a draft file still exists (drafts restored after a restart).
  Future<bool> exists(String path) => File(path).exists();

  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    await _deleteFile(File(path));
  }

  /// The draft [draftId] was sealed or discarded: its folder goes.
  Future<void> deleteDraft(String draftId) async {
    try {
      final dirs = await _ensure();
      await _deleteDir(Directory('${dirs.drafts.path}/$draftId'));
    } catch (e) {
      debugPrint('capsules: draft delete ${e.runtimeType}');
    }
  }

  // ---- a capsule's media ---------------------------------------------------------

  Future<Directory> _capsuleDir(String capsuleId) async {
    final dirs = await _ensure();
    final d = Directory('${dirs.root.path}/${capsuleId.toLowerCase()}');
    await d.create(recursive: true);
    return d;
  }

  /// Moves draft files into the capsule's folder (renames: no copy, so it
  /// works when storage is almost full). [files] maps slot → draft path.
  /// Returns slot → file name. On failure nothing is left half-moved.
  Future<Map<String, String>> adopt(
    String capsuleId,
    Map<String, String> files,
  ) async {
    final dir = await _capsuleDir(capsuleId);
    final moved = <String, String>{};
    final origins = <String, String>{};
    try {
      for (final e in files.entries) {
        final src = File(e.value);
        if (!await src.exists() || await src.length() == 0) {
          throw const CapsuleMediaException('missing');
        }
        final ext = e.value.endsWith('.jpg') ? '.jpg' : '.m4a';
        final name = '${e.key}$ext';
        await src.rename('${dir.path}/$name');
        moved[e.key] = name;
        origins[name] = e.value;
      }
      return moved;
    } on Object catch (e) {
      // Put back what already moved, so the draft stays whole for a retry.
      for (final entry in origins.entries) {
        try {
          await File('${dir.path}/${entry.key}').rename(entry.value);
        } on FileSystemException {
          // Nothing left to put back.
        }
      }
      if (e is CapsuleMediaException) rethrow;
      debugPrint('capsules: adopt ${e.runtimeType}');
      throw const CapsuleMediaException('write_failed');
    }
  }

  /// Puts adopted files back where they came from (the capsule row couldn't
  /// be written, so the draft keeps its media for a retry). [adopted] maps
  /// slot → file name, [origins] slot → the draft path.
  Future<void> unadopt(
    String capsuleId,
    Map<String, String> adopted,
    Map<String, String> origins,
  ) async {
    if (adopted.isEmpty) return;
    final dir = await _capsuleDir(capsuleId);
    for (final e in adopted.entries) {
      final back = origins[e.key];
      if (back == null) continue;
      try {
        await File('${dir.path}/${e.value}').rename(back);
      } on FileSystemException {
        // Nothing left to put back.
      }
    }
    await _deleteDir(dir);
  }

  /// Seals the raw file [name] of [slot] with the data key: writes
  /// `<slot>.enc` next to it and deletes the raw file. Returns the sealed
  /// name, or `null` when [name] is gone. Throws [CapsuleMediaException]
  /// when the sealed file can't be written.
  Future<String?> seal(
    String capsuleId,
    String slot,
    String name, {
    required NoteCipher cipher,
  }) async {
    if (isSealed(name)) return name;
    final dirs = await _ensure();
    // Never re-creates a folder a delete just removed.
    final dir = Directory('${dirs.root.path}/${capsuleId.toLowerCase()}');
    final raw = File('${dir.path}/$name');
    final Uint8List clear;
    try {
      clear = await raw.readAsBytes();
    } on FileSystemException {
      return null;
    }
    final sealed = await cipher.encryptBytes(
      clear,
      recordId: CapsuleSlots.aadOf(capsuleId, slot),
    );
    final out = sealedName(slot);
    final part = File('${dir.path}/$out.part');
    try {
      await part.writeAsBytes(sealed, flush: true);
      await part.rename('${dir.path}/$out');
    } on FileSystemException catch (e) {
      debugPrint('capsules: seal ${e.osError?.errorCode}');
      await _deleteFile(part);
      throw const CapsuleMediaException('write_failed');
    }
    await _deleteFile(raw);
    return out;
  }

  /// The bytes of [name] in the capsule's folder, or `null` when it's gone.
  Future<Uint8List?> read(String capsuleId, String name) async {
    try {
      final dirs = await _ensure();
      final f = File('${dirs.root.path}/${capsuleId.toLowerCase()}/$name');
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// Caches a downloaded ciphertext of [slot] (opened again later offline).
  Future<String?> cacheSealed(
    String capsuleId,
    String slot,
    Uint8List sealed,
  ) async {
    try {
      final dir = await _capsuleDir(capsuleId);
      final name = sealedName(slot);
      final part = File('${dir.path}/$name.part');
      await part.writeAsBytes(sealed, flush: true);
      await part.rename('${dir.path}/$name');
      return name;
    } on FileSystemException {
      return null; // Only a cache: it downloads again next time.
    }
  }

  /// Deletes a capsule's folder (delete, a tombstone from another phone).
  Future<void> deleteCapsule(String capsuleId) async {
    try {
      final dirs = await _ensure();
      await _deleteDir(
        Directory('${dirs.root.path}/${capsuleId.toLowerCase()}'),
      );
    } catch (e) {
      debugPrint('capsules: delete ${e.runtimeType}');
    }
  }

  // ---- decrypted copies ------------------------------------------------------------

  /// Writes a decrypted copy for viewing / playback into the temp directory.
  Future<File> writeTemp(Uint8List clear, {required String extension}) async {
    final dirs = await _ensure();
    await dirs.temp.create(recursive: true);
    final f = File('${dirs.temp.path}/${_ids.v7()}$extension');
    await f.writeAsBytes(clear, flush: true);
    return f;
  }

  Future<void> deleteTemp(String path) => _deleteFile(File(path));

  // ---- housekeeping ------------------------------------------------------------------

  /// Deletes capsule folders and drafts nothing references any more (the
  /// app died mid-seal, a sign-out wiped the rows). Never touches [keep]
  /// capsules, [keepDrafts], or anything changed within [minAge] (a seal
  /// moves files in before its row is written).
  Future<void> sweep({
    required Set<String> keep,
    required Set<String> keepDrafts,
    Duration minAge = const Duration(minutes: 10),
    DateTime? now,
  }) async {
    try {
      final dirs = await _ensure();
      final keepLower = keep.map((k) => k.toLowerCase()).toSet();
      final cutoff = (now ?? DateTime.now()).subtract(minAge);
      bool recent(FileSystemEntity e) => e.statSync().modified.isAfter(cutoff);
      await for (final e in dirs.root.list(followLinks: false)) {
        if (e is! Directory) continue;
        final name = e.path.split('/').last;
        if (name == 'drafts' || keepLower.contains(name) || recent(e)) {
          continue;
        }
        await _deleteDir(e);
      }
      await for (final e in dirs.drafts.list(followLinks: false)) {
        final name = e.path.split('/').last;
        if (keepDrafts.contains(name) || recent(e)) continue;
        await e.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('capsules: sweep ${e.runtimeType}');
    }
  }

  /// Sign-out / account deletion: every capsule file on this phone — sealed,
  /// raw, drafts and decrypted temp copies.
  Future<void> wipeAll() async {
    final base = await _root();
    await _deleteDir(Directory('${base.path}/capsules'));
    await _deleteDir(Directory('${(await _temp()).path}/aura-capsules'));
    _dirs = null; // recreated (and re-excluded from backup) on next use
  }

  static Future<void> _deleteFile(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  static Future<void> _deleteDir(Directory d) async {
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  }
}

class _Dirs {
  const _Dirs({required this.root, required this.drafts, required this.temp});

  final Directory root;
  final Directory drafts;
  final Directory temp;
}
