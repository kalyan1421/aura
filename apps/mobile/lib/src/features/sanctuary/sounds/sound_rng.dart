/// A small seeded PRNG (mulberry32) for Sounds. Unlike `dart:math`'s
/// `Random(seed)`, its sequence is fixed by this code, so a seed gives the
/// same generated stem and the same night wind-down order on every phone
/// and every SDK version (REQ-SAN-13: "the same day always gives the same
/// order").
class SoundRng {
  SoundRng(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFF;

  int _state;

  /// The next value in [0, 2^32).
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & _mask)) & _mask;
    return (t ^ (t >>> 14)) & _mask;
  }

  /// The next value in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// The next value in [-1, 1).
  double nextSigned() => nextDouble() * 2 - 1;

  /// The next value in [0, max). [max] must be positive.
  int nextInt(int max) {
    assert(max > 0);
    return nextUint32() % max;
  }

  /// The next value in [min, max).
  double between(double min, double max) => min + (max - min) * nextDouble();

  // 32-bit multiply (the low 32 bits of the product), as JavaScript's
  // Math.imul. Dart's 64-bit ints wrap, and the low bits stay exact.
  static int _imul(int a, int b) => (a * b) & _mask;
}

/// FNV-1a (32-bit) of [text]: a stable seed from a stem id.
int fnv1a32(String text) {
  var h = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
