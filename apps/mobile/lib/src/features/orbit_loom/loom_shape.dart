import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart'
    show
        constellationProblem,
        maxLoomLinks,
        maxLoomStars,
        minLoomStarGap,
        minLoomStars,
        roundSkyCoordinate;
import 'package:flutter/foundation.dart' show immutable, listEquals;

/// One star in the Orbit Loom sky (U07): a point in the unit sky, `x` left to
/// right, `y` top to bottom (RULES.md section 14).
@immutable
class LoomStar {
  const LoomStar(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(LoomStar o) => math.sqrt(_sq(x - o.x) + _sq(y - o.y));

  @override
  bool operator ==(Object other) =>
      other is LoomStar && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

double _sq(double v) => v * v;

/// A line between two stars, stored with the smaller index first.
@immutable
class LoomLink {
  factory LoomLink(int a, int b) =>
      a <= b ? LoomLink._(a, b) : LoomLink._(b, a);
  const LoomLink._(this.a, this.b);
  final int a;
  final int b;

  bool touches(int i) => a == i || b == i;

  @override
  bool operator ==(Object other) =>
      other is LoomLink && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

/// How close to the sky's edge a star can sit, so its glow stays inside.
const double loomMargin = 0.06;

/// Spacing the app keeps between stars it places itself: roomier than the
/// rule's minimum, so a shape made by the buttons always reads clearly.
const double loomComfortGap = 0.16;

/// The closest the app places two stars: the rule's minimum plus room for
/// rounding to 3 decimals, so a shape the person makes can always be kept.
const double loomPlaceGap = minLoomStarGap + 0.002;

/// A tap this close to a star (unit sky) means that star, not a new one.
const double loomTouchRadius = 0.07;

/// A constellation in the making. Immutable: every change returns a new
/// shape, so undo is a list of shapes. Presentation only; nothing here is
/// kept until the person chooses to keep it.
@immutable
class LoomShape {
  const LoomShape({this.stars = const [], this.links = const []});
  static const LoomShape empty = LoomShape();

  final List<LoomStar> stars;
  final List<LoomLink> links;

  bool get isFull => stars.length >= maxLoomStars;
  bool get canKeep => problem == null;

  /// Lines touching star [i].
  int linksOf(int i) => links.where((l) => l.touches(i)).length;

  /// The star at or near ([loomTouchRadius]) a point, or `null`.
  int? starNear(double x, double y, {double radius = loomTouchRadius}) {
    int? best;
    var bestDistance = radius;
    for (var i = 0; i < stars.length; i++) {
      final d = stars[i].distanceTo(LoomStar(x, y));
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// A star placed at a point (kept inside the margins), or this shape when
  /// the sky is full or the point is too close to a star.
  LoomShape addStar(double x, double y) {
    if (isFull) return this;
    final s = _inside(x, y);
    if (_crowded(s, gap: loomPlaceGap)) return this;
    return LoomShape(stars: [...stars, s], links: links);
  }

  /// Star [i] moved to a point, or this shape when that would crowd it.
  LoomShape moveStar(int i, double x, double y) {
    if (i < 0 || i >= stars.length) return this;
    final s = _inside(x, y);
    if (_crowded(s, gap: loomPlaceGap, except: i)) return this;
    return LoomShape(
      stars: [for (var k = 0; k < stars.length; k++) k == i ? s : stars[k]],
      links: links,
    );
  }

  /// Joins stars [a] and [b], or unjoins them when they already are. A new
  /// line past [maxLoomLinks] is left out.
  LoomShape toggleLink(int a, int b) {
    if (a == b || a < 0 || b < 0 || a >= stars.length || b >= stars.length) {
      return this;
    }
    final link = LoomLink(a, b);
    if (links.contains(link)) {
      return LoomShape(
        stars: stars,
        links: [
          for (final l in links)
            if (l != link) l,
        ],
      );
    }
    if (links.length >= maxLoomLinks) return this;
    return LoomShape(stars: stars, links: [...links, link]);
  }

  /// "Join for me": the shortest set of lines that joins every star (a
  /// minimum spanning tree), replacing any lines drawn so far. Always a tidy,
  /// connected shape, whatever the stars are.
  LoomShape joinForMe() {
    if (stars.length < 2) return LoomShape(stars: stars);
    final inTree = <int>{0};
    final out = <LoomLink>[];
    while (inTree.length < stars.length) {
      LoomLink? best;
      var bestDistance = double.infinity;
      for (final a in inTree) {
        for (var b = 0; b < stars.length; b++) {
          if (inTree.contains(b)) continue;
          final d = stars[a].distanceTo(stars[b]);
          if (d < bestDistance) {
            bestDistance = d;
            best = LoomLink(a, b);
          }
        }
      }
      out.add(best!);
      inTree
        ..add(best.a)
        ..add(best.b);
    }
    return LoomShape(stars: stars, links: out);
  }

  /// "Add a star": one star at a roomy free spot, or this shape when full.
  LoomShape addSomewhere(math.Random random) {
    if (isFull) return this;
    for (final gap in [loomComfortGap, loomComfortGap / 2, loomPlaceGap]) {
      for (var attempt = 0; attempt < 60; attempt++) {
        final s = _inside(random.nextDouble(), random.nextDouble());
        if (!_crowded(s, gap: gap)) {
          return LoomShape(stars: [...stars, s], links: links);
        }
      }
    }
    return this;
  }

  /// "Scatter for me": fills the sky up to five stars (or keeps what is
  /// there when it already has five or more).
  LoomShape scatter(math.Random random) {
    var shape = this;
    while (shape.stars.length < 5) {
      final next = shape.addSomewhere(random);
      if (identical(next, shape)) break;
      shape = next;
    }
    return shape;
  }

  /// The first problem with keeping this shape (RULES.md section 14), after
  /// rounding as it would be kept, or `null`.
  String? get problem =>
      constellationProblem(stars: wireStars, links: wireLinks, meaning: null);

  /// Stars as kept: `[x, y]`, 3 decimals.
  List<List<double>> get wireStars => [
    for (final s in stars) [roundSkyCoordinate(s.x), roundSkyCoordinate(s.y)],
  ];

  List<List<int>> get wireLinks => [
    for (final l in links) [l.a, l.b],
  ];

  /// Enough stars to keep (the rule's minimum); the shape may still need a
  /// line or two moved, which [problem] names.
  bool get hasEnoughStars => stars.length >= minLoomStars;

  LoomStar _inside(double x, double y) => LoomStar(
    x.clamp(loomMargin, 1 - loomMargin),
    y.clamp(loomMargin, 1 - loomMargin),
  );

  bool _crowded(LoomStar s, {required double gap, int? except}) {
    for (var i = 0; i < stars.length; i++) {
      if (i != except && stars[i].distanceTo(s) < gap) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is LoomShape &&
      listEquals(other.stars, stars) &&
      listEquals(other.links, links);

  @override
  int get hashCode => Object.hash(Object.hashAll(stars), Object.hashAll(links));
}
