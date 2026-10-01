import 'dart:math' as math;

import 'package:aura/src/features/orbit_loom/loom_shape.dart';
import 'package:aura_domain/aura_domain.dart'
    show maxLoomLinks, maxLoomStars, minLoomStarGap;
import 'package:flutter_test/flutter_test.dart';

/// Orbit Loom (U07): the shape being made. Forgiving by construction: there is
/// no wrong shape, the buttons alone can finish one, and anything the person
/// can make can be kept.

LoomShape _three() =>
    LoomShape.empty.addStar(0.2, 0.2).addStar(0.8, 0.3).addStar(0.5, 0.8);

void main() {
  test('placing stars: inside the margins, never crowded, at most seven', () {
    var s = LoomShape.empty.addStar(-1, 2);
    expect(s.stars.single, const LoomStar(loomMargin, 1 - loomMargin));
    expect(identical(s.addStar(loomMargin + 0.01, 1 - loomMargin), s), isTrue);
    for (var i = 0; i < 10; i++) {
      s = s.addStar(0.2 + (i % 4) * 0.2, 0.2 + (i ~/ 4) * 0.2);
    }
    expect(s.stars, hasLength(maxLoomStars));
    expect(s.isFull, isTrue);
  });

  test('a tap near a star means that star', () {
    final s = _three();
    expect(s.starNear(0.21, 0.22), 0);
    expect(s.starNear(0.5, 0.5), isNull);
  });

  test(
    'two taps join, the same two taps unjoin; a star never joins itself',
    () {
      final s = _three().toggleLink(0, 1);
      expect(s.links, [LoomLink(0, 1)]);
      expect(s.toggleLink(1, 0).links, isEmpty); // either order is one line
      expect(identical(s.toggleLink(2, 2), s), isTrue);
      expect(identical(s.toggleLink(0, 9), s), isTrue);
      expect(s.linksOf(0), 1);
      expect(s.linksOf(2), 0);
    },
  );

  test('lines stop at the most a constellation holds', () {
    var s = LoomShape.empty;
    for (var i = 0; i < maxLoomStars; i++) {
      s = s.addStar(0.1 + i * 0.13, i.isEven ? 0.2 : 0.7);
    }
    for (var a = 0; a < maxLoomStars; a++) {
      for (var b = a + 1; b < maxLoomStars; b++) {
        s = s.toggleLink(a, b);
      }
    }
    expect(s.links, hasLength(maxLoomLinks));
    expect(s.canKeep, isTrue);
  });

  test('moving a star keeps its lines; it cannot land on another star', () {
    final s = _three().toggleLink(0, 2);
    final moved = s.moveStar(0, 0.3, 0.4);
    expect(moved.stars[0], const LoomStar(0.3, 0.4));
    expect(moved.links, s.links);
    expect(identical(s.moveStar(0, 0.8, 0.3), s), isTrue);
  });

  test('"Join for me" joins every star with the shortest lines', () {
    final s = LoomShape.empty
        .addStar(0.1, 0.5)
        .addStar(0.3, 0.5)
        .addStar(0.9, 0.5)
        .addStar(0.5, 0.5)
        .toggleLink(0, 2)
        .joinForMe();
    expect(s.links.toSet(), {LoomLink(0, 1), LoomLink(1, 3), LoomLink(2, 3)});
    expect(s.canKeep, isTrue);
  });

  test('the buttons alone make a shape that can be kept, every time', () {
    for (var seed = 0; seed < 200; seed++) {
      final r = math.Random(seed);
      final s = LoomShape.empty.scatter(r).joinForMe();
      expect(s.stars, hasLength(5), reason: 'seed $seed');
      expect(s.links, hasLength(4));
      expect(s.canKeep, isTrue, reason: '${s.problem} seed $seed');
      for (var i = 0; i < s.stars.length; i++) {
        for (var j = i + 1; j < s.stars.length; j++) {
          expect(
            s.stars[i].distanceTo(s.stars[j]),
            greaterThanOrEqualTo(minLoomStarGap),
          );
        }
      }
      // "Add a star" fills the rest of the sky too.
      var full = s;
      for (var k = 0; k < 4; k++) {
        full = full.addSomewhere(r);
      }
      expect(full.stars, hasLength(maxLoomStars));
      expect(full.canKeep, isTrue);
    }
  });

  test('anything placed by hand, however close, can still be kept after '
      'rounding', () {
    final r = math.Random(7);
    for (var n = 0; n < 300; n++) {
      var s = LoomShape.empty;
      while (s.stars.length < 3) {
        s = s.addStar(r.nextDouble(), r.nextDouble());
      }
      // Squeeze a fourth one as close as placing allows.
      final t = s.stars.first;
      for (final dx in [loomPlaceGap, loomPlaceGap + 1e-6]) {
        s = s.addStar(t.x + dx, t.y);
      }
      expect(s.canKeep, isTrue, reason: s.problem);
    }
  });

  test('fewer than three stars cannot be kept yet; no lines is fine', () {
    final two = LoomShape.empty.addStar(0.2, 0.2).addStar(0.8, 0.8);
    expect(two.canKeep, isFalse);
    expect(two.problem, 'too_few_stars');
    expect(two.hasEnoughStars, isFalse);
    expect(_three().canKeep, isTrue);
    expect(_three().links, isEmpty);
  });

  test('kept as the rule reads it: 3 decimals, indices pairs', () {
    final s = LoomShape.empty
        .addStar(0.123456, 0.2)
        .addStar(0.8, 0.3)
        .addStar(0.5, 0.8)
        .toggleLink(2, 0);
    expect(s.wireStars.first, [0.123, 0.2]);
    expect(s.wireLinks, [
      [0, 2],
    ]);
  });
}
