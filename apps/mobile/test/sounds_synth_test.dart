import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aura/src/features/sanctuary/sounds/procedural_synth.dart';
import 'package:aura/src/features/sanctuary/sounds/sound_rng.dart';
import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Procedural stems (PRD 06d "Audio source"): seeded, deterministic,
/// seamless loops that never clip.
void main() {
  group('SoundRng', () {
    test('the same seed gives the same sequence; another seed does not', () {
      List<int> take(int seed) {
        final r = SoundRng(seed);
        return [for (var i = 0; i < 16; i++) r.nextUint32()];
      }

      expect(take(42), take(42));
      expect(take(42), isNot(take(43)));
      for (final v in take(7)) {
        expect(v, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });

    test('doubles are uniform in [0, 1)', () {
      final r = SoundRng(2026);
      var sum = 0.0;
      for (var i = 0; i < 20000; i++) {
        final v = r.nextDouble();
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(1));
        sum += v;
      }
      expect(sum / 20000, closeTo(0.5, 0.02));
    });

    test('fnv1a32 is stable', () {
      expect(fnv1a32(''), 0x811C9DC5);
      expect(fnv1a32('a'), 0xE40C292C);
      expect(fnv1a32('brown_noise'), fnv1a32('brown_noise'));
    });
  });

  group('generators', () {
    const rate = 8000;
    const seconds = 10;

    for (final g in StemGenerator.values) {
      test('${g.id}: one seamless, audible loop that never clips', () {
        final x = generateStem(g, sampleRate: rate, seconds: seconds);
        expect(x.length, rate * seconds);
        var maxAbs = 0.0;
        var sumSq = 0.0;
        var diffSum = 0.0;
        for (var i = 0; i < x.length; i++) {
          final v = x[i];
          expect(v.isFinite, isTrue);
          maxAbs = math.max(maxAbs, v.abs());
          sumSq += v * v;
          if (i > 0) diffSum += (v - x[i - 1]).abs();
        }
        expect(maxAbs, lessThanOrEqualTo(0.9 + 1e-6));
        expect(math.sqrt(sumSq / x.length), greaterThan(0.005));
        // The loop point is no jump: last → first is like any other step.
        final meanStep = diffSum / (x.length - 1);
        final seam = (x.first - x.last).abs();
        expect(seam, lessThan(meanStep * 8 + 0.02), reason: g.id);
      });

      test('${g.id}: deterministic for a seed', () {
        final a = generateStem(g, sampleRate: rate, seconds: seconds, seed: 9);
        final b = generateStem(g, sampleRate: rate, seconds: seconds, seed: 9);
        final c = generateStem(g, sampleRate: rate, seconds: seconds, seed: 10);
        expect(a, b);
        expect(a, isNot(c));
      });
    }

    test('ids are unique and round-trip', () {
      final ids = {for (final g in StemGenerator.values) g.id};
      expect(ids, hasLength(StemGenerator.values.length));
      for (final g in StemGenerator.values) {
        expect(StemGenerator.byId(g.id), g);
      }
      expect(StemGenerator.byId('binaural'), isNull);
    });

    test('every generator the bundled manifest names exists', () {
      for (final s in StemManifest.bundled.stems) {
        if (s.kind == StemKind.procedural) expect(s.generator, isNotNull);
      }
      expect(
        StemManifest.bundled.stems.where((s) => s.generatedSource != null),
        isNotEmpty,
      );
    });

    test('a full-length brown noise loop renders quickly', () {
      final watch = Stopwatch()..start();
      final x = generateStem(StemGenerator.brownNoise);
      expect(x.length, StemGenerator.brownNoise.loopSeconds * soundsSampleRate);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('WAV', () {
    test('a canonical 16-bit mono PCM header and samples', () {
      final wav = encodeWav(Float32List.fromList([0, 1, -1, 0.5, 2]), 16000);
      final b = ByteData.sublistView(wav);
      String tag(int o) => String.fromCharCodes(wav.sublist(o, o + 4));
      expect(tag(0), 'RIFF');
      expect(b.getUint32(4, Endian.little), 36 + 10);
      expect(tag(8), 'WAVE');
      expect(tag(12), 'fmt ');
      expect(b.getUint16(20, Endian.little), 1);
      expect(b.getUint16(22, Endian.little), 1);
      expect(b.getUint32(24, Endian.little), 16000);
      expect(b.getUint32(28, Endian.little), 32000);
      expect(b.getUint16(34, Endian.little), 16);
      expect(tag(36), 'data');
      expect(b.getUint32(40, Endian.little), 10);
      expect(wav.length, 54);
      expect([
        for (var i = 0; i < 5; i++) b.getInt16(44 + i * 2, Endian.little),
      ], [0, 32767, -32767, 16384, 32767]); // clamped
    });

    test('renderStemWav is the generated loop as WAV', () {
      final wav = renderStemWav(
        StemGenerator.chimes,
        sampleRate: 8000,
        seconds: 10,
      );
      expect(wav.length, 44 + 8000 * 10 * 2);
    });
  });
}
