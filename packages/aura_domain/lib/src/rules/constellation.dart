import 'dart:math' as math;

/// Orbit Loom constellations (RULES.md section 14, U07). Cosmetic: keeping
/// one never touches the ledger, and there is no correct shape or score.

/// Fewest and most stars in one constellation.
const int minLoomStars = 3;
const int maxLoomStars = 7;

/// Most lines in one constellation.
const int maxLoomLinks = 12;

/// Closest two stars may be, in the unit sky.
const double minLoomStarGap = 0.05;

/// Most constellations kept per Aura day.
const int maxLoomConstellationsPerDay = 5;

/// The optional, neutral meanings. All equal: none is suggested or rewarded.
enum ConstellationMeaning {
  noticed('noticed'),
  carrying('carrying'),
  ahead('ahead'),
  thankful('thankful'),
  justBecause('just_because');

  const ConstellationMeaning(this.key);

  /// The wire and storage name.
  final String key;

  static ConstellationMeaning? fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }
}

/// A coordinate as the app keeps it: 3 decimals.
double roundSkyCoordinate(double v) => (v * 1000).round() / 1000;

/// The first problem with a constellation (RULES.md section 14 `problem`),
/// or `null` when it is valid. [stars] are `[x, y]` points in the unit sky,
/// [links] `[a, b]` star indices (unordered), [meaning] a key or `null`.
String? constellationProblem({
  required List<List<num>> stars,
  required List<List<num>> links,
  required String? meaning,
}) {
  if (stars.length < minLoomStars) return 'too_few_stars';
  if (stars.length > maxLoomStars) return 'too_many_stars';
  for (final s in stars) {
    if (s.length != 2) return 'star_outside_sky';
    for (final v in s) {
      if (!v.isFinite || v < 0 || v > 1) return 'star_outside_sky';
    }
  }
  for (var i = 0; i < stars.length; i++) {
    for (var j = i + 1; j < stars.length; j++) {
      final dx = stars[i][0] - stars[j][0];
      final dy = stars[i][1] - stars[j][1];
      if (math.sqrt(dx * dx + dy * dy) < minLoomStarGap - 1e-9) {
        return 'stars_too_close';
      }
    }
  }
  if (links.length > maxLoomLinks) return 'too_many_links';
  final seen = <String>{};
  String? duplicate;
  for (final l in links) {
    if (l.length != 2) return 'bad_link';
    final a = l[0];
    final b = l[1];
    bool index(num n) => n == n.roundToDouble() && n >= 0 && n < stars.length;
    if (!index(a) || !index(b) || a == b) return 'bad_link';
    final key = a < b
        ? '${a.toInt()}-${b.toInt()}'
        : '${b.toInt()}-${a.toInt()}';
    if (!seen.add(key)) duplicate ??= 'duplicate_link';
  }
  if (duplicate != null) return duplicate;
  if (meaning != null && ConstellationMeaning.fromKey(meaning) == null) {
    return 'unknown_meaning';
  }
  return null;
}
