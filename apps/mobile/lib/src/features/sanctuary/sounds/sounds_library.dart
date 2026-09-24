import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stem_manifest.dart';
import 'stem_store.dart';

/// The manifest in use (tests swap in their own).
final stemManifestProvider = Provider<StemManifest>(
  (ref) => StemManifest.bundled,
);

/// The on-device Sounds cache.
final stemStoreProvider = Provider<StemStore>((ref) => StemStore.device());

/// What can play right now, what needs its one-time download, and any
/// download in progress.
@immutable
class SoundsLibraryState {
  const SoundsLibraryState({
    required this.manifest,
    this.downloaded = const {},
    this.downloading = const {},
    this.loaded = false,
  });

  final StemManifest manifest;

  /// Stems whose recording is on this phone.
  final Set<String> downloaded;

  /// Stems downloading now → progress 0…1.
  final Map<String, double> downloading;

  /// The download check has run.
  final bool loaded;

  /// The stems the Sounds screen shows.
  List<Stem> get stems => manifest.listed;

  /// Plays with no download: generated, or its recording is here.
  bool isPlayable(Stem stem) =>
      downloaded.contains(stem.id) || stem.generatedSource != null;

  /// A recording-only stem (a Plus extra) that hasn't been downloaded.
  bool needsDownload(Stem stem) => !isPlayable(stem);

  /// Base recordings not yet on this phone. Until they are, their
  /// generated stand-ins play (PRD 06d: "downloaded once, on first use").
  List<Stem> get baseToDownload => [
    for (final s in stems)
      if (!s.isPlus && s.hasRecording && !downloaded.contains(s.id)) s,
  ];

  int get baseDownloadBytes =>
      baseToDownload.fold(0, (sum, s) => sum + s.file!.bytes);

  bool get isDownloading => downloading.isNotEmpty;

  SoundsLibraryState copyWith({
    Set<String>? downloaded,
    Map<String, double>? downloading,
    bool? loaded,
  }) => SoundsLibraryState(
    manifest: manifest,
    downloaded: downloaded ?? this.downloaded,
    downloading: downloading ?? this.downloading,
    loaded: loaded ?? this.loaded,
  );
}

final soundsLibraryProvider =
    NotifierProvider<SoundsLibrary, SoundsLibraryState>(SoundsLibrary.new);

class SoundsLibrary extends Notifier<SoundsLibraryState> {
  @override
  SoundsLibraryState build() {
    final manifest = ref.watch(stemManifestProvider);
    Future.microtask(refresh);
    return SoundsLibraryState(manifest: manifest);
  }

  StemStore get _store => ref.read(stemStoreProvider);

  /// Re-checks which recordings are on this phone.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final withFiles = [
      for (final s in state.manifest.stems)
        if (s.hasRecording) s,
    ];
    try {
      final ids = withFiles.isEmpty
          ? <String>{}
          : await _store.downloadedIds(withFiles);
      if (!ref.mounted) return;
      state = state.copyWith(downloaded: ids, loaded: true);
    } on Object catch (e) {
      debugPrint('sounds: download check failed (${e.runtimeType})');
      if (ref.mounted) state = state.copyWith(loaded: true);
    }
  }

  /// Downloads every base recording (the size was shown first). Returns
  /// the first error, or `null` when all arrived.
  Future<StemDownloadError?> downloadBase() async {
    StemDownloadError? first;
    for (final s in state.baseToDownload) {
      final err = await downloadStem(s.id);
      first ??= err;
      if (err == StemDownloadError.offline ||
          err == StemDownloadError.noSpace) {
        break;
      }
    }
    return first;
  }

  /// Downloads one stem's recording. Returns the error, or `null`.
  Future<StemDownloadError?> downloadStem(String id) async {
    final stem = state.manifest.byId(id);
    if (stem == null || !stem.hasRecording) {
      return StemDownloadError.unavailable;
    }
    if (state.downloaded.contains(id)) return null;
    if (state.downloading.containsKey(id)) return null;
    _progress(id, 0);
    try {
      await _store.download(
        stem,
        onProgress: (received, total) {
          if (!ref.mounted) return;
          final t = total > 0 ? total : stem.file!.bytes;
          _progress(id, (received / t).clamp(0.0, 1.0));
        },
      );
      if (!ref.mounted) return null;
      state = state.copyWith(
        downloaded: {...state.downloaded, id},
        downloading: {...state.downloading}..remove(id),
      );
      return null;
    } on StemDownloadException catch (e) {
      if (!ref.mounted) return e.error;
      state = state.copyWith(
        downloading: {...state.downloading}..remove(id),
      );
      return e.error;
    }
  }

  void _progress(String id, double value) {
    state = state.copyWith(downloading: {...state.downloading, id: value});
  }

  /// "Remove downloaded sounds". The generated stand-ins keep playing.
  Future<void> removeDownloads() async {
    await _store.removeDownloads();
    if (!ref.mounted) return;
    state = state.copyWith(downloaded: const {});
  }
}
