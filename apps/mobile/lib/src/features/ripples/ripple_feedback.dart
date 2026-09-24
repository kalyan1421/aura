import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/a11y/haptics.dart';
import '../sanctuary/sounds/procedural_synth.dart' show encodeWav;

/// Haptics and tones of a Breath Ripples session. Haptics go through
/// [AuraHaptics], so Settings › Comfort › Haptics (and the system setting)
/// turns every one of them off; the session then shows a visual pulse
/// instead (PRD 15 "Breath Ripples falls back to a visual pulse"). Tones play
/// only in accessible mode, which the person turned on (or a screen reader
/// did): nothing sounds uninvited (06d "Silent until chosen").
abstract interface class RippleFeedback {
  /// A pacer phase began. [strength] (0–1) carries the group sync in
  /// accessible mode ("sync shown by tone and haptic strength, not colour");
  /// `null` = the ordinary soft pattern.
  void phase({required bool inhale, double? strength, bool tone = false});

  /// Someone sent a one-tap pulse (or a gesture).
  void pulse();

  Future<void> dispose();
}

/// Plays the rising (inhale) / falling (exhale) tones.
abstract interface class RippleTones {
  Future<void> play({required bool inhale, required double volume});

  Future<void> dispose();
}

class AuraRippleFeedback implements RippleFeedback {
  AuraRippleFeedback({this.tones});

  final RippleTones? tones;
  static const Duration gap = Duration(milliseconds: 120);

  @override
  void phase({required bool inhale, double? strength, bool tone = false}) {
    if (strength != null && strength >= 0.66 && AuraHaptics.enabled) {
      // Well in step: a firmer cue (still obeys Comfort › Haptics).
      unawaited(HapticFeedback.mediumImpact());
    } else if (inhale) {
      // Rising: a tick, then a tap (the Sanctuary Breathe pattern).
      AuraHaptics.selection();
      Timer(gap, AuraHaptics.light);
    } else {
      // Falling: a tap, then a tick.
      AuraHaptics.light();
      Timer(gap, AuraHaptics.selection);
    }
    if (tone) {
      unawaited(
        tones?.play(inhale: inhale, volume: 0.35 + 0.65 * (strength ?? 0.5)),
      );
    }
  }

  @override
  void pulse() => AuraHaptics.light();

  @override
  Future<void> dispose() async => tones?.dispose();
}

/// Two short sine glides (rising / falling), generated once on the device.
class JustAudioRippleTones implements RippleTones {
  AudioPlayer? _in;
  AudioPlayer? _out;
  Future<void>? _ready;

  static const int _rate = 16000;

  static Float32List glide({required bool rising, int ms = 600}) {
    final n = _rate * ms ~/ 1000;
    final out = Float32List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final p = i / n;
      final f = rising ? 330 + 220 * p : 550 - 220 * p;
      phase += 2 * math.pi * f / _rate;
      final env = math.sin(math.pi * p); // soft in, soft out: no click
      out[i] = 0.4 * env * math.sin(phase);
    }
    return out;
  }

  Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    Future<AudioPlayer> make(String name, bool rising) async {
      final f = File('${dir.path}/aura_ripples_$name.wav');
      if (!f.existsSync()) {
        await f.writeAsBytes(encodeWav(glide(rising: rising), _rate));
      }
      final p = AudioPlayer();
      await p.setFilePath(f.path);
      return p;
    }

    _in = await make('in', true);
    _out = await make('out', false);
  }

  @override
  Future<void> play({required bool inhale, required double volume}) async {
    try {
      await (_ready ??= _prepare());
      final p = inhale ? _in : _out;
      if (p == null) return;
      await p.setVolume(volume.clamp(0, 1));
      await p.seek(Duration.zero);
      unawaited(p.play());
    } on Object catch (e) {
      debugPrint('ripples: tone skipped (${e.runtimeType})');
    }
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      if (_in != null) _in!.dispose(),
      if (_out != null) _out!.dispose(),
    ]);
  }
}

/// Where a session sends its haptics and tones (tests record them).
final rippleFeedbackProvider = Provider<RippleFeedback>(
  (ref) => AuraRippleFeedback(tones: JustAudioRippleTones()),
);
