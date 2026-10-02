import 'dart:async';
import 'dart:io';

import 'package:aura/src/features/sanctuary/sounds/saved_mixes.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_backend.dart';
import 'package:aura/src/features/sanctuary/sounds/sounds_session_log.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_store.dart';

/// A layer that records what the mixer asked of it (no audio).
class FakeLayer implements SoundsLayer {
  FakeLayer(this.path);

  final String path;
  bool playing = false;
  bool disposed = false;
  double volume = 0;
  final List<double> volumes = [];

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  void setVolume(double v) {
    volume = v;
    volumes.add(v);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}

/// The audio backend for tests: no platform channels, everything recorded.
class FakeSoundsBackend implements SoundsBackend {
  int prepares = 0;
  int releases = 0;
  final List<FakeLayer> layers = [];
  final List<(bool, bool)> media = [];

  /// Like the real backend, whose media session is built inside [prepare]: a media state published
  /// before [prepare] finished has nowhere to go and is dropped. Off by default (older tests record all).
  bool dropMediaBeforePrepare = false;
  bool _prepared = false;
  SoundsTransport? transport;
  final StreamController<SoundsInterruption> _events =
      StreamController.broadcast();

  /// Layers that are open and not disposed.
  List<FakeLayer> get live => [
    for (final l in layers)
      if (!l.disposed) l,
  ];

  FakeLayer? layerFor(String stemId) {
    for (final l in live.reversed) {
      if (l.path.endsWith('/$stemId')) return l;
    }
    return null;
  }

  void emit(SoundsInterruption e) => _events.add(e);

  @override
  Future<void> prepare() async {
    prepares++;
    _prepared = true;
  }

  @override
  Future<SoundsLayer> openLayer(String path, {required int seed}) async {
    final l = FakeLayer(path);
    layers.add(l);
    return l;
  }

  @override
  Stream<SoundsInterruption> get interruptions => _events.stream;

  @override
  void bindTransport(SoundsTransport t) => transport = t;

  @override
  void updateMediaState({required bool active, required bool playing}) {
    if (dropMediaBeforePrepare && !_prepared) return;
    media.add((active, playing));
  }

  @override
  Future<void> release() async => releases++;
}

/// A store with no file I/O: generated stems resolve at once; recordings
/// "download" on demand (or fail with [downloadError]).
class FakeStemStore extends StemStore {
  FakeStemStore({Set<String>? downloaded})
    : downloaded = downloaded ?? {},
      super(
        root: () async => Directory.systemTemp,
        fetcher: _NoFetcher(),
        baseUrl: 'https://example.invalid/sounds',
      );

  final Set<String> downloaded;
  StemDownloadError? downloadError;
  int downloads = 0;
  int removals = 0;

  @override
  Future<bool> isDownloaded(Stem stem) async => downloaded.contains(stem.id);

  @override
  Future<Set<String>> downloadedIds(Iterable<Stem> stems) async => {
    for (final s in stems)
      if (downloaded.contains(s.id)) s.id,
  };

  @override
  Future<void> download(
    Stem stem, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloads++;
    final err = downloadError;
    if (err != null) throw StemDownloadException(err);
    onProgress?.call(stem.file!.bytes, stem.file!.bytes);
    downloaded.add(stem.id);
  }

  @override
  Future<void> removeDownloads() async {
    removals++;
    downloaded.clear();
  }

  @override
  Future<String?> playablePath(Stem stem) async {
    if (downloaded.contains(stem.id)) return 'rec/${stem.id}';
    if (stem.generatedSource != null) return 'gen/${stem.id}';
    return null;
  }
}

class _NoFetcher implements StemFetcher {
  @override
  Future<void> fetch(
    Uri url,
    File dest, {
    void Function(int received, int total)? onProgress,
  }) => throw UnimplementedError();
}

class RecordingSessionLog implements SoundsSessionLog {
  final List<SoundsSessionRecord> records = [];

  @override
  Future<void> record(SoundsSessionRecord session) async =>
      records.add(session);
}

/// Saved mixes in memory (no database).
class MemorySavedMixes extends SavedMixes {
  MemorySavedMixes([this.initial = const []]);

  final List<SavedMix> initial;

  @override
  List<SavedMix> build() => initial;

  @override
  Future<bool> save(SavedMix mix) async {
    if (state.any(mix.sameAs)) return false;
    state = [mix, ...state];
    return true;
  }

  @override
  Future<void> remove(SavedMix mix) async =>
      state = [for (final m in state) if (!identical(m, mix)) m];
}

/// A manifest with one downloadable base recording (rain, with a generated
/// stand-in), one Plus recording-only stem, brown noise and a Plus
/// procedural stem.
StemManifest downloadableManifest() => StemManifest.parse('''
{
  "version": 1,
  "max_layers": 4,
  "stems": [
    {"id": "rain", "title_key": "sounds_stemRain", "tier": "free", "role": "bed",
     "kind": "file", "file": "base/rain.v1.m4a", "bytes": 2500000,
     "sha256": "${'a' * 64}", "licence": "CC0-1.0",
     "source_url": "https://example.org/rain", "status": "available",
     "fallback_generator": "rain"},
    {"id": "brown_noise", "title_key": "sounds_stemBrownNoise", "tier": "free",
     "role": "bed", "kind": "procedural", "generator": "brown_noise",
     "licence": "generated-in-code", "status": "available"},
    {"id": "chimes", "title_key": "sounds_stemChimes", "tier": "free",
     "role": "accent", "kind": "procedural", "generator": "chimes",
     "licence": "generated-in-code", "status": "available"},
    {"id": "pink_noise", "title_key": "sounds_stemPinkNoise", "tier": "plus",
     "role": "bed", "kind": "procedural", "generator": "pink_noise",
     "licence": "generated-in-code", "status": "available"},
    {"id": "stream", "title_key": "sounds_stemStream", "tier": "plus",
     "role": "bed", "kind": "file", "file": "plus/stream.v1.m4a",
     "bytes": 1200000, "sha256": "${'b' * 64}", "licence": "CC0-1.0",
     "source_url": "https://example.org/stream", "status": "available"}
  ]
}
''');
