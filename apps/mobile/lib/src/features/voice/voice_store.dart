import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/ids/ids.dart';
import '../../core/security/note_cipher.dart';

/// Longest voice note (PRD F1 "voice ≤ 60 s"). Recording stops by itself.
const Duration maxVoiceDuration = Duration(seconds: 60);

/// AAC-LC mono at 64 kbps: 60 s is ≈ 480 KB, well under the upload limit.
const int voiceBitRate = 64000;
const int voiceSampleRate = 44100;

/// Largest ciphertext `POST /v1/media/upload-url` accepts (1 MiB).
const int maxVoiceUploadBytes = 1048576;

/// A recording in the check-in draft, not saved yet: a raw AAC file in the
/// drafts directory and its length.
@immutable
class VoiceClip {
  const VoiceClip({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

/// The voice note a check-in already has (the 24 h edit starts from it).
@immutable
class SavedVoice {
  const SavedVoice({
    required this.checkInId,
    this.file,
    this.path,
    this.duration,
  });

  final String checkInId;

  /// This phone's copy ([VoiceStore] file name), if any.
  final String? file;

  /// The server object, if uploaded / pulled.
  final String? path;
  final Duration? duration;
}

/// A voice file couldn't be kept (storage full, write failed, file gone).
class VoiceStoreException implements Exception {
  const VoiceStoreException(this.reason);

  final String reason;

  @override
  String toString() => 'VoiceStoreException($reason)';
}

/// Voice-note files on this phone (F1; PRD 16-offline: "Voice and photo files
/// live in the app's private directory, encrypted at rest").
///
/// Layout, all inside the app's private support directory under `voice/`,
/// which is excluded from OS backup (iOS: the directory's
/// `isExcludedFromBackup` attribute; Android: `allowBackup=false` plus the
/// data-extraction rules, which also stop device-to-device transfer):
///
/// * `voice/drafts/<rec>.m4a` — the recorder's output while a check-in is
///   being made. A new process deletes leftovers ("App killed before Save:
///   nothing saved").
/// * `voice/<rec>.m4a` — a saved recording not sealed yet. It only stays raw
///   while no data key is on the phone (signed out, or offline before the
///   first key fetch); [seal] runs as soon as one is.
/// * `voice/<rec>.enc` — sealed with the per-user data key (AES-256-GCM,
///   associated data = the check-in id): exactly the bytes that are uploaded.
///
/// Playback of sealed or downloaded notes decrypts into the OS temp directory
/// (`aura-voice/`, never backed up); those files are deleted when playback
/// ends and swept at the next start and at sign-out.
class VoiceStore {
  VoiceStore({
    required this._root,
    required this._temp,
    Future<void> Function(String dirPath)? excludeFromBackup,
    this._referenced,
    this._ids = const Ids(),
  }) : _exclude = excludeFromBackup;

  final Future<Directory> Function() _root;
  final Future<Directory> Function() _temp;
  final Future<void> Function(String dirPath)? _exclude;

  /// File names check-ins still reference; anything else in `voice/` is an
  /// orphan (e.g. the app died between moving a recording and saving it).
  final Future<Set<String>> Function()? _referenced;
  final Ids _ids;

  Future<_Dirs>? _dirs;
  final Map<String, Future<Object?>> _locks = {};

  static const String _sealedExt = '.enc';
  static const String _rawExt = '.m4a';

  /// True for a file sealed with the data key.
  static bool isSealed(String name) => name.endsWith(_sealedExt);

  Future<_Dirs> _ensure() {
    final existing = _dirs;
    if (existing != null) return existing;
    final created = _init();
    _dirs = created;
    // A failed start is retried next time instead of being cached.
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
    final voice = Directory('${base.path}/voice');
    final drafts = Directory('${voice.path}/drafts');
    await drafts.create(recursive: true);
    try {
      await _exclude?.call(voice.path);
    } catch (e) {
      debugPrint('voice: backup exclusion ${e.runtimeType}');
    }
    final temp = Directory('${(await _temp()).path}/aura-voice');
    // A new process never needs an earlier run's drafts or decrypted copies.
    await _clearDir(drafts);
    await _deleteDir(temp);
    final referenced = _referenced;
    if (referenced != null) {
      try {
        final keep = await referenced();
        await for (final e in voice.list(followLinks: false)) {
          if (e is! File) continue;
          if (!keep.contains(_name(e.path))) await _deleteFile(e);
        }
      } catch (e) {
        debugPrint('voice: sweep ${e.runtimeType}');
      }
    }
    return _Dirs(voice: voice, drafts: drafts, temp: temp);
  }

  /// Runs [body] alone for [key] (one sealing per check-in at a time).
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

  /// A fresh path for the recorder, in the drafts directory.
  Future<String> newDraftPath() async {
    final dirs = await _ensure();
    await dirs.drafts.create(recursive: true);
    return '${dirs.drafts.path}/${_ids.v7()}$_rawExt';
  }

  /// Moves a finished draft recording into the store (a rename: no copy, so
  /// it works when storage is almost full). Returns its file name. Throws
  /// [VoiceStoreException] when the draft is missing or empty.
  Future<String> adopt(String draftPath) async {
    final dirs = await _ensure();
    final src = File(draftPath);
    try {
      if (!await src.exists() || await src.length() == 0) {
        throw const VoiceStoreException('missing');
      }
      final name = _name(draftPath);
      await src.rename('${dirs.voice.path}/$name');
      return name;
    } on VoiceStoreException {
      rethrow;
    } on FileSystemException catch (e) {
      debugPrint('voice: adopt ${e.osError?.errorCode}');
      throw const VoiceStoreException('write_failed');
    }
  }

  /// Puts an adopted file back where it was (the check-in row couldn't be
  /// written, so the draft keeps its recording for a retry).
  Future<void> unadopt(String name, String draftPath) async {
    final dirs = await _ensure();
    try {
      await File('${dirs.voice.path}/$name').rename(draftPath);
    } on FileSystemException {
      // Nothing left to put back.
    }
  }

  /// Seals the raw file [name] for the check-in [recordId]: writes
  /// `<rec>.enc` next to it and returns that name. The raw file stays until
  /// the caller has pointed the check-in at the sealed one (then [delete]).
  /// Returns `null` when [name] is gone. Throws [VoiceStoreException] when
  /// the sealed file can't be written.
  Future<String?> seal(
    String name, {
    required String recordId,
    required NoteCipher cipher,
  }) async {
    if (isSealed(name)) return name;
    final dirs = await _ensure();
    final raw = File('${dirs.voice.path}/$name');
    final Uint8List clear;
    try {
      clear = await raw.readAsBytes();
    } on FileSystemException {
      return null;
    }
    final sealed = await cipher.encryptBytes(clear, recordId: recordId);
    final out = '${_stem(name)}$_sealedExt';
    final part = File('${dirs.voice.path}/$out.part');
    try {
      await part.writeAsBytes(sealed, flush: true);
      await part.rename('${dirs.voice.path}/$out');
    } on FileSystemException catch (e) {
      debugPrint('voice: seal ${e.osError?.errorCode}');
      await _deleteFile(part);
      throw const VoiceStoreException('write_failed');
    }
    return out;
  }

  /// The file [name] in the store, or `null` when it isn't there.
  Future<File?> file(String name) async {
    final dirs = await _ensure();
    final f = File('${dirs.voice.path}/$name');
    return await f.exists() ? f : null;
  }

  /// The bytes of [name], or `null` when it is gone.
  Future<Uint8List?> read(String name) async {
    final f = await file(name);
    if (f == null) return null;
    try {
      return await f.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// Deletes the stored file [name] (no-op for `null` or a missing file).
  Future<void> delete(String? name) async {
    if (name == null) return;
    try {
      final dirs = await _ensure();
      await _deleteFile(File('${dirs.voice.path}/$name'));
    } catch (e) {
      debugPrint('voice: delete ${e.runtimeType}');
    }
  }

  /// Writes a decrypted copy for playback into the temp directory.
  Future<File> writeTemp(Uint8List clear) async {
    final dirs = await _ensure();
    await dirs.temp.create(recursive: true);
    final f = File('${dirs.temp.path}/${_ids.v7()}$_rawExt');
    await f.writeAsBytes(clear, flush: true);
    return f;
  }

  Future<void> deleteTemp(String path) => _deleteFile(File(path));

  /// Sign-out / account deletion: every voice file of this phone — saved,
  /// raw, drafts and decrypted temp copies.
  Future<void> wipe() async {
    final base = await _root();
    await _deleteDir(Directory('${base.path}/voice'));
    await _deleteDir(Directory('${(await _temp()).path}/aura-voice'));
    _dirs = null; // recreated (and re-excluded from backup) on next use
  }

  static String _name(String path) => path.split('/').last;

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
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

  static Future<void> _clearDir(Directory d) async {
    try {
      await for (final e in d.list(followLinks: false)) {
        await e.delete(recursive: true);
      }
    } on FileSystemException {
      // Nothing to clear.
    }
  }
}

class _Dirs {
  const _Dirs({required this.voice, required this.drafts, required this.temp});

  final Directory voice;
  final Directory drafts;
  final Directory temp;
}
