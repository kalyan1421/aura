import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart' as rec;

import 'voice_store.dart';

// Device seams for voice notes (F1). Widgets and tests only see these
// interfaces; the plugins are created lazily, on the first mic tap or play,
// so nothing touches a platform channel while a screen merely builds.

/// Microphone capture (foreground only, PRD 15-permissions).
abstract interface class VoiceRecorder {
  /// Whether the OS allows the microphone. With [request] the OS prompt is
  /// shown when the person hasn't answered it yet; once declined it just
  /// returns false (iOS never asks twice; Android stops after two denials).
  Future<bool> hasPermission({bool request = false});

  /// Starts recording AAC-LC (m4a) into [path].
  Future<void> start(String path);

  /// Stops and returns the file path (null when nothing was recorded).
  Future<String?> stop();

  /// Stops and deletes the file.
  Future<void> cancel();

  /// Input level, 0 (silence) … 1 (loud), a few times a second while
  /// recording. Drives the level ring (never under Reduce Motion).
  Stream<double> levels();

  Future<void> dispose();
}

/// Plays one local audio file at a time.
abstract interface class VoicePlayer {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  /// Playback position while playing.
  Stream<Duration> get position;

  /// The file's length once known.
  Stream<Duration> get duration;

  /// Fires when the file played to its end.
  Stream<void> get completed;

  Future<void> dispose();
}

/// App ↔ OS glue for voice notes (one small method channel, no plugin):
/// the app's page in OS Settings (mic denied → "turn it on in Settings") and
/// excluding a directory from iCloud backup.
abstract interface class AuraPlatform {
  /// Opens this app's page in the OS Settings app. False when it couldn't.
  Future<bool> openAppSettings();

  /// iOS: sets `isExcludedFromBackup` on [path] (a directory covers its
  /// contents). Android: nothing to do — backup and device-to-device
  /// transfer are off for the whole app (AndroidManifest.xml).
  Future<void> excludeFromBackup(String path);
}

/// [AuraPlatform] over `com.akvega.aura/platform` (AppDelegate.swift,
/// MainActivity.kt).
class ChannelAuraPlatform implements AuraPlatform {
  const ChannelAuraPlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.akvega.aura/platform',
  );

  @override
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on Object catch (e) {
      debugPrint('platform: openAppSettings ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<void> excludeFromBackup(String path) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod<bool>('excludeFromBackup', path);
  }
}

/// [VoiceRecorder] over package:record. AAC-LC mono ≈ 64 kbps (m4a).
class RecordVoiceRecorder implements VoiceRecorder {
  rec.AudioRecorder? _recorder;

  rec.AudioRecorder get _r => _recorder ??= rec.AudioRecorder();

  @override
  Future<bool> hasPermission({bool request = false}) =>
      _r.hasPermission(request: request);

  @override
  Future<void> start(String path) => _r.start(
    const rec.RecordConfig(
      encoder: rec.AudioEncoder.aacLc,
      bitRate: voiceBitRate,
      sampleRate: voiceSampleRate,
      numChannels: 1,
      // Voice, not music: let the OS clean it up.
      noiseSuppress: true,
      echoCancel: true,
    ),
    path: path,
  );

  @override
  Future<String?> stop() async => _recorder?.stop();

  @override
  Future<void> cancel() async => _recorder?.cancel();

  @override
  Stream<double> levels() => _r
      .onAmplitudeChanged(const Duration(milliseconds: 160))
      // dBFS (-160 … 0) → 0 … 1 over the useful -50 … 0 range.
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  @override
  Future<void> dispose() async {
    final r = _recorder;
    _recorder = null;
    await r?.dispose();
  }
}

/// [VoicePlayer] over package:audioplayers.
class AudioplayersVoicePlayer implements VoicePlayer {
  ap.AudioPlayer? _player;
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];

  ap.AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final p = ap.AudioPlayer();
    _subs
      ..add(p.onPositionChanged.listen(_position.add))
      ..add(p.onDurationChanged.listen(_duration.add))
      ..add(p.onPlayerComplete.listen((_) => _completed.add(null)));
    return _player = p;
  }

  @override
  Future<void> play(String path) =>
      _p.play(ap.DeviceFileSource(path, mimeType: 'audio/mp4'));

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> resume() async => _player?.resume();

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    final p = _player;
    _player = null;
    await p?.dispose();
    await _position.close();
    await _duration.close();
    await _completed.close();
  }
}
