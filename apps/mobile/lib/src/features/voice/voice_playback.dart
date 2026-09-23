import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_devices.dart';
import 'voice_loader.dart';

enum VoicePlaybackState {
  idle,

  /// Finding / downloading / decrypting the file.
  loading,
  playing,
  paused,

  /// Only on the server and there is no connection.
  offline,

  /// Couldn't be loaded or played; the person can try again.
  failed,
}

/// Play/pause for one voice note. The file is loaded on the first play (a
/// download for a note that is only on the server) and a decrypted temp copy
/// is deleted when the controller is disposed (leaving the screen).
class VoicePlaybackController extends ChangeNotifier {
  VoicePlaybackController({
    required this._createPlayer,
    required this._load,
    this._deleteTemp,
    this._duration,
  });

  final VoicePlayer Function() _createPlayer;
  final Future<VoiceSource> Function() _load;
  final Future<void> Function(String path)? _deleteTemp;

  VoicePlaybackState _state = VoicePlaybackState.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  VoicePlayer? _player;
  VoiceSource? _source;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _disposed = false;

  VoicePlaybackState get state => _state;
  Duration get position => _position;

  /// The note's length: from the recording, or from the player once known.
  Duration? get duration => _duration;

  bool get isPlaying => _state == VoicePlaybackState.playing;

  void _set(VoicePlaybackState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  VoicePlayer _playerOrNew() {
    final existing = _player;
    if (existing != null) return existing;
    final p = _createPlayer();
    _subs
      ..add(
        p.position.listen((d) {
          if (_disposed) return;
          _position = d;
          notifyListeners();
        }),
      )
      ..add(
        p.duration.listen((d) {
          if (_disposed || d <= Duration.zero) return;
          _duration = d;
          notifyListeners();
        }),
      )
      ..add(
        p.completed.listen((_) {
          _position = Duration.zero;
          _set(VoicePlaybackState.idle);
        }),
      );
    return _player = p;
  }

  /// Play ↔ pause; from idle/failed/offline (re)loads first.
  Future<void> toggle() async {
    switch (_state) {
      case VoicePlaybackState.loading:
        return;
      case VoicePlaybackState.playing:
        await _player?.pause();
        _set(VoicePlaybackState.paused);
      case VoicePlaybackState.paused:
        _set(VoicePlaybackState.playing);
        await _player?.resume();
      case VoicePlaybackState.idle ||
          VoicePlaybackState.offline ||
          VoicePlaybackState.failed:
        await _start();
    }
  }

  Future<void> _start() async {
    var source = _source;
    if (source == null) {
      _set(VoicePlaybackState.loading);
      try {
        source = await _load();
      } on VoiceUnavailable catch (e) {
        _set(
          e.offline ? VoicePlaybackState.offline : VoicePlaybackState.failed,
        );
        return;
      } catch (e) {
        debugPrint('voice: load ${e.runtimeType}');
        _set(VoicePlaybackState.failed);
        return;
      }
      if (_disposed) {
        if (source.isTemp) await _deleteTemp?.call(source.path);
        return;
      }
      _source = source;
    }
    try {
      _position = Duration.zero;
      _set(VoicePlaybackState.playing);
      await _playerOrNew().play(source.path);
    } catch (e) {
      debugPrint('voice: play ${e.runtimeType}');
      _set(VoicePlaybackState.failed);
    }
  }

  /// Stops playback (e.g. before recording again).
  Future<void> stop() async {
    if (_state == VoicePlaybackState.playing ||
        _state == VoicePlaybackState.paused) {
      await _player?.stop();
      _position = Duration.zero;
      _set(VoicePlaybackState.idle);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    final p = _player;
    _player = null;
    if (p != null) {
      unawaited(() async {
        try {
          await p.stop();
        } catch (_) {}
        await p.dispose();
      }());
    }
    final source = _source;
    if (source != null && source.isTemp) {
      unawaited(_deleteTemp?.call(source.path));
    }
    super.dispose();
  }
}
