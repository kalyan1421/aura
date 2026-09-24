import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_rng.dart';

/// Procedural stems (PRD 06d "Audio source": brown noise is synthesized on
/// the device; chimes and bowl strikes are timed in code). Everything here
/// is pure Dart, seeded and deterministic, so it runs in a background
/// isolate and is unit-tested without audio hardware. Output is mono PCM,
/// one seamless loop: noise textures cross-fade their tail into their head;
/// struck sounds (bowl, chimes, bells, crickets, drops) wrap their tails
/// around the loop point.
///
/// No binaural beats, no "frequencies" and no claims (REQ-SAN-12): these are
/// ordinary textures and struck tones.

/// Sample rate of generated stems. 16 kHz keeps a loop small (32 KB/s) and
/// still holds everything generated here (the highest partial is < 6 kHz).
const int soundsSampleRate = 16000;

/// Every generator the manifest can name (`generator` /
/// `fallback_generator`, snake_case ids).
enum StemGenerator {
  brownNoise('brown_noise', 24),
  pinkNoise('pink_noise', 24),
  rain('rain', 30),
  ocean('ocean', 64),
  wind('wind', 48),
  crickets('crickets', 30),
  singingBowl('singing_bowl', 90),
  chimes('chimes', 60),
  deepBell('deep_bell', 120);

  const StemGenerator(this.id, this.loopSeconds);

  /// The manifest id.
  final String id;

  /// Default loop length.
  final int loopSeconds;

  static StemGenerator? byId(String? id) {
    for (final g in values) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Bumped whenever a generator's output changes, so cached WAV files from an
/// older build are regenerated rather than reused.
const int proceduralVersion = 1;

/// One loop of [generator] as samples in [-1, 1]. Same arguments, same
/// samples.
Float32List generateStem(
  StemGenerator generator, {
  int sampleRate = soundsSampleRate,
  int? seconds,
  int? seed,
}) {
  final secs = seconds ?? generator.loopSeconds;
  final n = secs * sampleRate;
  final rng = SoundRng(seed ?? fnv1a32(generator.id));
  final fade = math.min(2 * sampleRate, n ~/ 4);
  return switch (generator) {
    StemGenerator.brownNoise => _fit(_brown(rng, n, fade), rms: 0.16),
    StemGenerator.pinkNoise => _fit(_pink(rng, n, fade), rms: 0.12),
    StemGenerator.rain => _fit(_rain(rng, n, fade, sampleRate), rms: 0.14),
    StemGenerator.ocean => _fit(_ocean(rng, n, fade, secs), rms: 0.15),
    StemGenerator.wind => _fit(_wind(rng, n, fade, sampleRate), rms: 0.14),
    StemGenerator.crickets => _fit(
      _crickets(rng, n, fade, sampleRate),
      peak: 0.6,
    ),
    StemGenerator.singingBowl => _fit(
      _singingBowl(rng, n, sampleRate),
      peak: 0.7,
    ),
    StemGenerator.chimes => _fit(_chimes(rng, n, sampleRate), peak: 0.6),
    StemGenerator.deepBell => _fit(_deepBell(rng, n, sampleRate), peak: 0.7),
  };
}

/// [generateStem] as a playable WAV file (16-bit PCM, mono). Top level, so
/// `Isolate.run` can call it.
Uint8List renderStemWav(
  StemGenerator generator, {
  int sampleRate = soundsSampleRate,
  int? seconds,
  int? seed,
}) => encodeWav(
  generateStem(generator, sampleRate: sampleRate, seconds: seconds, seed: seed),
  sampleRate,
);

/// A canonical 44-byte-header WAV (PCM 16-bit mono, little endian).
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final dataBytes = samples.length * 2;
  final b = ByteData(44 + dataBytes);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      b.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // fmt chunk size
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}

// ---- building blocks ---------------------------------------------------------

/// Renders [n] + [fade] samples, then cross-fades (equal power) the extra
/// tail into the head: the last sample flows into the first one, so the loop
/// has no seam.
Float32List _seamless(int n, int fade, void Function(Float32List raw) render) {
  final raw = Float32List(n + fade);
  render(raw);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = raw[i];
  }
  for (var i = 0; i < fade; i++) {
    final w = (i / fade) * math.pi / 2;
    out[i] = raw[i] * math.sin(w) + raw[n + i] * math.cos(w);
  }
  return out;
}

/// Scales [x] so its RMS is [rms] (when given) without any sample passing
/// [peak]; removes any DC offset first.
Float32List _fit(Float32List x, {double? rms, double peak = 0.9}) {
  if (x.isEmpty) return x;
  var mean = 0.0;
  for (final v in x) {
    mean += v;
  }
  mean /= x.length;
  var maxAbs = 0.0;
  var sumSq = 0.0;
  for (var i = 0; i < x.length; i++) {
    final v = x[i] - mean;
    x[i] = v;
    final a = v.abs();
    if (a > maxAbs) maxAbs = a;
    sumSq += v * v;
  }
  if (maxAbs == 0) return x;
  var scale = peak / maxAbs;
  if (rms != null) {
    final current = math.sqrt(sumSq / x.length);
    scale = math.min(scale, rms / current);
  }
  for (var i = 0; i < x.length; i++) {
    x[i] *= scale;
  }
  return x;
}

/// Leaky-integrated white noise (brown / red noise).
class _Brown {
  _Brown(this._rng) {
    for (var i = 0; i < 4000; i++) {
      next(); // settle
    }
  }

  final SoundRng _rng;
  double _b = 0;

  double next() {
    _b = (_b + 0.02 * _rng.nextSigned()) / 1.02;
    return _b * 3.5;
  }
}

/// Pink noise (Paul Kellet's refined filter).
class _Pink {
  _Pink(this._rng) {
    for (var i = 0; i < 4000; i++) {
      next();
    }
  }

  final SoundRng _rng;
  double _b0 = 0, _b1 = 0, _b2 = 0, _b3 = 0, _b4 = 0, _b5 = 0, _b6 = 0;

  double next() {
    final w = _rng.nextSigned();
    _b0 = 0.99886 * _b0 + w * 0.0555179;
    _b1 = 0.99332 * _b1 + w * 0.0750759;
    _b2 = 0.96900 * _b2 + w * 0.1538520;
    _b3 = 0.86650 * _b3 + w * 0.3104856;
    _b4 = 0.55000 * _b4 + w * 0.5329522;
    _b5 = -0.7616 * _b5 - w * 0.0168980;
    final out = _b0 + _b1 + _b2 + _b3 + _b4 + _b5 + _b6 + w * 0.5362;
    _b6 = w * 0.115926;
    return out * 0.11;
  }
}

/// Adds a damped sinusoid (a struck partial) to [buf] at [start], wrapping
/// around the loop point. A recurrence, not `sin()` per sample: cheap enough
/// for long bell tails.
void _addDamped(
  Float32List buf,
  int start,
  double freq,
  double amp,
  double tau,
  int fs, {
  double maxSeconds = 45,
  int attack = 0,
}) {
  if (freq <= 0 || freq >= fs * 0.45 || amp == 0) return;
  final n = buf.length;
  final len = math.min((tau * 5 * fs).round(), (maxSeconds * fs).round());
  final tail = math.max(1, len ~/ 10);
  final w = 2 * math.pi * freq / fs;
  final r = math.exp(-1 / (tau * fs));
  final c = 2 * r * math.cos(w);
  final r2 = r * r;
  var prev = 0.0; // s[k-1]
  var cur = r * math.sin(w); // s[1]
  for (var k = 1; k < len; k++) {
    var g = amp;
    if (k < attack) g *= k / attack;
    final fromEnd = len - k;
    if (fromEnd < tail) g *= fromEnd / tail;
    final i = (start + k) % n;
    buf[i] += cur * g;
    final next = c * cur - r2 * prev;
    prev = cur;
    cur = next;
  }
}

/// A struck object: [partials] (ratio to [f0]) with their amplitudes and
/// decay times, each doubled with a slightly detuned twin for a slow beat.
void _strike(
  Float32List buf,
  int start,
  double f0,
  double amp,
  List<(double ratio, double amp, double tau)> partials,
  int fs, {
  double detune = 0.003,
  double maxSeconds = 45,
}) {
  final attack = (0.008 * fs).round();
  for (final (ratio, a, tau) in partials) {
    final f = f0 * ratio;
    _addDamped(
      buf,
      start,
      f,
      amp * a * 0.5,
      tau,
      fs,
      attack: attack,
      maxSeconds: maxSeconds,
    );
    _addDamped(
      buf,
      start,
      f * (1 + detune),
      amp * a * 0.5,
      tau,
      fs,
      attack: attack,
      maxSeconds: maxSeconds,
    );
  }
}

double _smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// ---- generators ----------------------------------------------------------------

Float32List _brown(SoundRng rng, int n, int fade) {
  final brown = _Brown(rng);
  return _seamless(n, fade, (raw) {
    for (var i = 0; i < raw.length; i++) {
      raw[i] = brown.next();
    }
  });
}

Float32List _pink(SoundRng rng, int n, int fade) {
  final pink = _Pink(rng);
  return _seamless(n, fade, (raw) {
    for (var i = 0; i < raw.length; i++) {
      raw[i] = pink.next();
    }
  });
}

/// A steady hiss of rain plus a patter of drops.
Float32List _rain(SoundRng rng, int n, int fade, int fs) {
  final pink = _Pink(rng);
  final brown = _Brown(rng);
  final out = _seamless(n, fade, (raw) {
    var lp = 0.0;
    for (var i = 0; i < raw.length; i++) {
      final p = pink.next();
      lp += 0.12 * (p - lp);
      raw[i] = (p - lp) * 0.9 + brown.next() * 0.12;
    }
  });
  final seconds = n / fs;
  final drops = (seconds * 38).round();
  for (var d = 0; d < drops; d++) {
    final at = rng.nextInt(n);
    final u = rng.nextDouble();
    final amp = 0.04 + 0.28 * u * u * u;
    _addDamped(
      out,
      at,
      rng.between(1600, 4800),
      amp,
      rng.between(0.003, 0.011),
      fs,
    );
  }
  return out;
}

/// Swells of surf: brown noise under a brighter wash that rises and falls
/// with each wave. The waves divide the loop exactly, so the swell is
/// seamless too.
Float32List _ocean(SoundRng rng, int n, int fade, int seconds) {
  final waves = math.max(1, (seconds / 8).round());
  final weights = [for (var i = 0; i < waves; i++) rng.between(0.75, 1.25)];
  final total = weights.reduce((a, b) => a + b);
  final env = Float32List(n);
  var at = 0;
  for (var w = 0; w < waves; w++) {
    final len = w == waves - 1 ? n - at : (n * weights[w] / total).round();
    for (var j = 0; j < len; j++) {
      final p = j / len;
      env[at + j] = p < 0.35
          ? _smoothstep(p / 0.35)
          : math.pow(1 - (p - 0.35) / 0.65, 1.8).toDouble();
    }
    at += len;
  }
  final brown = _Brown(rng);
  final pink = _Pink(rng);
  return _seamless(n, fade, (raw) {
    var lp = 0.0;
    for (var i = 0; i < raw.length; i++) {
      final e = env[i % n];
      lp += (0.04 + 0.3 * e) * (pink.next() - lp);
      raw[i] = brown.next() * (0.45 + 0.55 * e) + lp * (0.2 + 2.2 * e * e);
    }
  });
}

/// Moving air: pink noise through a band-pass whose centre drifts slowly,
/// with gusts. The drift and gusts repeat exactly once per loop.
Float32List _wind(SoundRng rng, int n, int fade, int fs) {
  final pink = _Pink(rng);
  final brown = _Brown(rng);
  final p1 = rng.between(0, 2 * math.pi);
  final p2 = rng.between(0, 2 * math.pi);
  final p3 = rng.between(0, 2 * math.pi);
  final p4 = rng.between(0, 2 * math.pi);
  return _seamless(n, fade, (raw) {
    var low = 0.0, band = 0.0;
    for (var i = 0; i < raw.length; i++) {
      final t = (i % n) / n * 2 * math.pi;
      final m =
          0.5 + 0.3 * math.sin(2 * t + p1) + 0.2 * math.sin(5 * t + p2);
      final g0 = 0.5 + 0.5 * math.sin(3 * t + p3);
      final gust = 0.35 + 0.65 * g0 * g0 * (0.75 + 0.25 * math.sin(7 * t + p4));
      final fc = 220 + 620 * m;
      final f = 2 * math.sin(math.pi * fc / fs);
      // Chamberlin state-variable filter, damping 0.5.
      final input = pink.next();
      low += f * band;
      final high = input - low - 0.5 * band;
      band += f * high;
      raw[i] = band * gust * 1.6 + brown.next() * 0.1;
    }
  });
}

/// A few crickets, each chirping at its own pitch and pace, over quiet
/// night air.
Float32List _crickets(SoundRng rng, int n, int fade, int fs) {
  final brown = _Brown(rng);
  final out = _seamless(n, fade, (raw) {
    for (var i = 0; i < raw.length; i++) {
      raw[i] = brown.next() * 0.04;
    }
  });
  for (var c = 0; c < 3; c++) {
    final carrier = rng.between(3900, 4600);
    final period = rng.between(0.45, 0.8);
    final pulses = 3 + rng.nextInt(2);
    final pulseLen = (rng.between(0.012, 0.018) * fs).round();
    final gap = (rng.between(0.014, 0.02) * fs).round();
    final amp = rng.between(0.25, 0.7);
    var t = rng.between(0, period);
    final seconds = n / fs;
    while (t < seconds) {
      if (rng.nextDouble() > 0.15) {
        final start = (t * fs).round();
        for (var p = 0; p < pulses; p++) {
          final s0 = start + p * (pulseLen + gap);
          for (var k = 0; k < pulseLen; k++) {
            final hann = 0.5 - 0.5 * math.cos(2 * math.pi * k / pulseLen);
            final v = math.sin(2 * math.pi * carrier * k / fs) * hann * amp;
            out[(s0 + k) % n] += v;
          }
        }
      }
      t += period * rng.between(0.95, 1.05);
    }
  }
  return out;
}

/// Singing-bowl strikes about every 16–26 s, at one of three pitches. The
/// partial ratios are those of a struck bowl (inharmonic), each with a slow
/// beat.
Float32List _singingBowl(SoundRng rng, int n, int fs) {
  final out = Float32List(n);
  const pitches = [196.0, 220.0, 246.94];
  const partials = [
    (1.0, 1.0, 12.0),
    (2.76, 0.45, 7.0),
    (5.40, 0.22, 3.5),
    (8.93, 0.10, 1.8),
  ];
  final seconds = n / fs;
  var t = rng.between(0, 2);
  while (t < seconds - 4) {
    _strike(
      out,
      (t * fs).round(),
      pitches[rng.nextInt(pitches.length)],
      rng.between(0.6, 1.0),
      partials,
      fs,
    );
    t += rng.between(16, 26);
  }
  return out;
}

/// Wind chimes: every 4–11 s a breath of air rings one to four tubes of a
/// pentatonic set, a moment apart.
Float32List _chimes(SoundRng rng, int n, int fs) {
  final out = Float32List(n);
  const notes = [587.33, 659.25, 783.99, 880.0, 1046.5];
  const partials = [(1.0, 1.0, 3.0), (2.76, 0.3, 1.2), (5.40, 0.1, 0.5)];
  final seconds = n / fs;
  var t = rng.between(0, 1);
  while (t < seconds) {
    final rings = 1 + rng.nextInt(4);
    var at = t;
    for (var r = 0; r < rings; r++) {
      _strike(
        out,
        (at * fs).round(),
        notes[rng.nextInt(notes.length)],
        rng.between(0.3, 1.0),
        partials,
        fs,
        detune: 0.0015,
      );
      at += rng.between(0.08, 0.4);
    }
    t += rng.between(4, 11);
  }
  return out;
}

/// A low, distant bell every 25–40 s (hum, prime, minor third, fifth,
/// octave and upper partials of a cast bell).
Float32List _deepBell(SoundRng rng, int n, int fs) {
  final out = Float32List(n);
  const pitches = [98.0, 110.0, 116.54];
  const partials = [
    (0.5, 0.6, 20.0),
    (1.0, 1.0, 14.0),
    (1.19, 0.5, 10.0),
    (1.5, 0.35, 8.0),
    (2.0, 0.45, 6.0),
    (2.52, 0.2, 4.0),
    (3.0, 0.15, 3.0),
  ];
  final seconds = n / fs;
  var t = rng.between(0, 3);
  while (t < seconds - 5) {
    _strike(
      out,
      (t * fs).round(),
      pitches[rng.nextInt(pitches.length)],
      rng.between(0.7, 1.0),
      partials,
      fs,
      detune: 0.002,
      maxSeconds: 60,
    );
    t += rng.between(25, 40);
  }
  return out;
}
