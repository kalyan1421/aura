import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'procedural_synth.dart';
import 'stem_manifest.dart';

/// Where recorded stems download from: `<base>/<file path>` (for example a
/// public Supabase Storage bucket or a CDN). Empty = downloads are not set
/// up in this build; generated stems still play.
const String soundsBaseUrl = String.fromEnvironment('AURA_SOUNDS_BASE_URL');

/// Why a download did not finish. Each has calm copy in the Sounds screen.
enum StemDownloadError {
  /// No connection. The generated sounds still play.
  offline,

  /// The phone is full (PRD 06d "Storage full").
  noSpace,

  /// The file's size or SHA-256 did not match the manifest; it was deleted.
  integrity,

  /// Downloads aren't configured (no base URL) or the file isn't there.
  unavailable,

  /// Anything else.
  failed,
}

class StemDownloadException implements Exception {
  const StemDownloadException(this.error);

  final StemDownloadError error;

  @override
  String toString() => 'StemDownloadException(${error.name})';
}

/// Fetches one file to [dest], reporting received / total bytes.
abstract interface class StemFetcher {
  Future<void> fetch(
    Uri url,
    File dest, {
    void Function(int received, int total)? onProgress,
  });
}

/// [StemFetcher] over Dio. Network failures become [StemDownloadException].
class DioStemFetcher implements StemFetcher {
  DioStemFetcher([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  final Dio _dio;

  @override
  Future<void> fetch(
    Uri url,
    File dest, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await _dio.downloadUri(url, dest.path, onReceiveProgress: onProgress);
    } on DioException catch (e) {
      if (e.error is FileSystemException) throw e.error!;
      throw StemDownloadException(switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => StemDownloadError.offline,
        DioExceptionType.badResponse => StemDownloadError.unavailable,
        _ => StemDownloadError.failed,
      });
    }
  }
}

/// Whether [file]'s SHA-256 is [expectedHex] (lower-case hex). Streams the
/// file, so large stems never sit in memory.
Future<bool> sha256Matches(File file, String expectedHex) async {
  final sink = Sha256().newHashSink();
  await for (final chunk in file.openRead()) {
    sink.add(chunk);
  }
  sink.close();
  final hash = await sink.hash();
  return _hex(hash.bytes) == expectedHex.toLowerCase();
}

String _hex(List<int> bytes) {
  final b = StringBuffer();
  for (final v in bytes) {
    b.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

/// Renders a generated stem to WAV bytes (in a background isolate).
typedef StemRenderer = Future<Uint8List> Function(StemGenerator generator);

Future<Uint8List> renderInIsolate(StemGenerator generator) =>
    Isolate.run(() => renderStemWav(generator));

/// The on-device Sounds cache (PRD 16-offline: "Full after one download").
///
/// - `gen/`: generated stems as WAV, made on first use (no download).
/// - `rec/`: recorded stems, downloaded once and verified by size and
///   SHA-256. The file name carries the hash, so a new recording in a newer
///   manifest is a new file.
///
/// Lives in the app's cache directory: re-creatable content is never
/// backed up, and "Remove downloaded sounds" clears `rec/`.
class StemStore {
  StemStore({
    required this._root,
    required this._fetcher,
    this._baseUrl = soundsBaseUrl,
    this._render = renderInIsolate,
  });

  /// The app's real store (`<cache>/sounds`).
  factory StemStore.device() => StemStore(
    root: () async =>
        Directory('${(await getApplicationCacheDirectory()).path}/sounds'),
    fetcher: DioStemFetcher(),
  );

  final Future<Directory> Function() _root;
  final StemFetcher _fetcher;
  final String _baseUrl;
  final StemRenderer _render;
  final Map<StemGenerator, Future<String>> _rendering = {};

  Future<Directory> _dir(String name) async {
    final d = Directory('${(await _root()).path}/$name');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File> _recording(Stem stem) async {
    final f = stem.file!;
    final dot = f.path.lastIndexOf('.');
    final ext = dot < 0 ? '' : f.path.substring(dot);
    return File(
      '${(await _dir('rec')).path}/${stem.id}.${f.sha256.substring(0, 16)}$ext',
    );
  }

  /// The WAV file for [generator], rendering it on first use.
  Future<String> generatedPath(StemGenerator generator) =>
      _rendering[generator] ??= _generate(generator).whenComplete(() {
        // A block, not `=>`: returning the removed future would make
        // whenComplete wait on itself.
        _rendering.remove(generator);
      });

  Future<String> _generate(StemGenerator g) async {
    final dir = await _dir('gen');
    final file = File(
      '${dir.path}/${g.id}.v$proceduralVersion.$soundsSampleRate.wav',
    );
    if (file.existsSync() && file.lengthSync() > 44) return file.path;
    final bytes = await _render(g);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    return file.path;
  }

  /// Whether [stem]'s recording is on this phone (checked by size; the hash
  /// was checked when it arrived).
  Future<bool> isDownloaded(Stem stem) async {
    if (!stem.hasRecording) return false;
    final f = await _recording(stem);
    return f.existsSync() && f.lengthSync() == stem.file!.bytes;
  }

  /// Which of [stems] have their recording on this phone.
  Future<Set<String>> downloadedIds(Iterable<Stem> stems) async => {
    for (final s in stems)
      if (await isDownloaded(s)) s.id,
  };

  /// Downloads [stem]'s recording once and verifies it. Throws
  /// [StemDownloadException]; a failed or mismatched file is deleted.
  Future<void> download(
    Stem stem, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!stem.hasRecording || _baseUrl.isEmpty) {
      throw const StemDownloadException(StemDownloadError.unavailable);
    }
    if (await isDownloaded(stem)) return;
    final dest = await _recording(stem);
    final part = File('${dest.path}.part');
    final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    try {
      await _fetcher.fetch(
        Uri.parse(base).resolve(stem.file!.path),
        part,
        onProgress: onProgress,
      );
      final ok =
          part.existsSync() &&
          part.lengthSync() == stem.file!.bytes &&
          await sha256Matches(part, stem.file!.sha256);
      if (!ok) {
        throw const StemDownloadException(StemDownloadError.integrity);
      }
      await part.rename(dest.path);
    } on StemDownloadException {
      await _delete(part);
      rethrow;
    } on FileSystemException catch (e) {
      await _delete(part);
      // ENOSPC is 28 on both iOS and Android.
      final full =
          e.osError?.errorCode == 28 ||
          (e.osError?.message.toLowerCase().contains('no space') ?? false);
      throw StemDownloadException(
        full ? StemDownloadError.noSpace : StemDownloadError.failed,
      );
    } on Object catch (e) {
      await _delete(part);
      debugPrint('sounds: download failed (${e.runtimeType})');
      throw const StemDownloadException(StemDownloadError.failed);
    }
  }

  Future<void> _delete(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Nothing more to do.
    }
  }

  /// Settings' "Remove downloaded sounds": deletes every recording.
  /// Generated stems stay (they are made on the phone, nothing downloaded).
  Future<void> removeDownloads() async {
    final d = Directory('${(await _root()).path}/rec');
    if (d.existsSync()) await d.delete(recursive: true);
  }

  /// A path the player can open for [stem]: its downloaded recording, or
  /// else its generated sound. `null` when neither exists yet (a recording
  /// that still needs its download).
  Future<String?> playablePath(Stem stem) async {
    if (await isDownloaded(stem)) return (await _recording(stem)).path;
    final g = stem.generatedSource;
    if (g == null) return null;
    return generatedPath(g);
  }
}
