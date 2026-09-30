import 'dart:math' as math;

import 'package:aura/src/features/universe/universe_scene.dart';
import 'package:aura_domain/aura_domain.dart' show GrowthStage, Vitality;
import 'package:flutter_test/flutter_test.dart';

/// T04: the companion's poses and a plant's moment, as geometry. Presentation
/// only; the renderer still receives a slot, stages and vitalities.

double _top(List<WorldFace> faces) =>
    faces.expand((f) => [f.a.y, f.b.y, f.c.y]).reduce(math.max);

/// The faces of one plant as the island draws it when nothing is changing:
/// the run of faces the plant adds to an empty grove.
List<WorldFace> _still(WorldPlant plant) {
  final empty = IslandMesh(growth: 0, plants: const []).faces;
  final full = IslandMesh(growth: 0, plants: [plant]).faces;
  var k = 0;
  while (k < empty.length && _same(empty[k], full[k])) {
    k++;
  }
  return full.sublist(k, k + full.length - empty.length);
}

bool _same(WorldFace a, WorldFace b) =>
    _shape([a]).single == _shape([b]).single && a.color == b.color;

List<String> _shape(List<WorldFace> faces) => [
  for (final f in faces)
    [
      for (final p in [f.a, f.b, f.c])
        '${p.x.toStringAsFixed(6)},${p.y.toStringAsFixed(6)},'
            '${p.z.toStringAsFixed(6)}',
    ].join(' '),
];

void main() {
  group('companion poses', () {
    const at = WorldPoint(0.4, 0, -0.3);

    test('standing still draws the W05 companion exactly', () {
      expect(
        _shape(IslandMesh.companion(at)),
        _shape(IslandMesh.companion(at, pose: CompanionPose.still)),
      );
    });

    test('the eyes follow the heading; the body stays where it stands', () {
      WorldPoint eyes(double heading) {
        final faces = IslandMesh.companion(
          at,
          pose: CompanionPose(heading: heading),
        );
        // The two small dark spheres.
        final dark = faces.where((f) => f.color.r < 0.3).toList();
        final n = dark.length * 3;
        var x = 0.0, z = 0.0;
        for (final f in dark) {
          for (final p in [f.a, f.b, f.c]) {
            x += p.x;
            z += p.z;
          }
        }
        return WorldPoint(x / n - at.x, 0, z / n - at.z);
      }

      for (final heading in [0.0, math.pi / 2, math.pi, -math.pi / 3]) {
        final e = eyes(heading);
        final length = math.sqrt(e.x * e.x + e.z * e.z);
        expect(
          e.x / length,
          closeTo(math.sin(heading), 1e-6),
          reason: '$heading',
        );
        expect(
          e.z / length,
          closeTo(math.cos(heading), 1e-6),
          reason: '$heading',
        );
      }
    });

    test('walking bobs a little; celebrating hops higher, then settles', () {
      expect(CompanionPose.still.lift, 0);
      for (var s = 0.0; s < 4; s += 0.1) {
        final walk = CompanionPose(motion: CompanionMotion.walk, phase: s);
        expect(walk.lift, inInclusiveRange(0, 0.035 + 1e-9));
      }
      final hops = [
        for (var t = 0.0; t <= 1.0001; t += 0.05)
          CompanionPose(motion: CompanionMotion.celebrate, phase: t).lift,
      ];
      expect(hops.reduce(math.max), greaterThan(0.08));
      expect(hops.first, closeTo(0, 1e-9));
      expect(hops.last, closeTo(0, 1e-9)); // back on the grass at the end
      final standing = _top(IslandMesh.companion(at));
      final hopping = _top(
        IslandMesh.companion(
          at,
          pose: const CompanionPose(
            motion: CompanionMotion.celebrate,
            phase: 0.2,
          ),
        ),
      );
      expect(hopping, greaterThan(standing + 0.08));
    });

    test('poses stay inside the scene budget', () {
      for (final motion in CompanionMotion.values) {
        expect(
          IslandMesh.companion(
            at,
            pose: CompanionPose(motion: motion, phase: 0.5),
          ).length,
          lessThan(400),
        );
      }
    });
  });

  group('headings', () {
    test(
      'toward a point on the ground, or the fallback when already there',
      () {
        const o = WorldPoint(0, 0.16, 0);
        expect(headingToward(o, const WorldPoint(0, 0, 1)), closeTo(0, 1e-9));
        expect(
          headingToward(o, const WorldPoint(1, 0, 0)),
          closeTo(math.pi / 2, 1e-9),
        );
        expect(headingToward(o, o, fallback: 1.25), 1.25);
      },
    );

    test('turning takes the short way round', () {
      final a = math.pi - 0.1;
      final b = -math.pi + 0.1;
      final half = lerpHeading(a, b, 0.5);
      expect(math.cos(half), closeTo(-1, 1e-6)); // through pi, not zero
      expect(lerpHeading(0.3, 1.2, 1), closeTo(1.2, 1e-9));
      expect(lerpHeading(0.3, 1.2, 7), closeTo(1.2, 1e-9)); // clamped
    });
  });

  group('a plant moment', () {
    const sprout = WorldPlant(slot: 2, stage: GrowthStage.sprout);
    const grown = WorldPlant(slot: 2, stage: GrowthStage.grown);

    test('starts as last seen and ends exactly as the island draws it', () {
      const change = WorldPlantChange(from: sprout, to: grown);
      expect(
        _shape(IslandMesh.changingPlant(change, 1)),
        _shape(_still(grown)),
      );
      expect(
        _shape(IslandMesh.changingPlant(change, 0)),
        _shape(_still(sprout)),
      );
    });

    test('it rises as it grows', () {
      const change = WorldPlantChange(from: sprout, to: grown);
      final early = _top(IslandMesh.changingPlant(change, 0.2));
      final late = _top(IslandMesh.changingPlant(change, 0.7));
      expect(late, greaterThan(early));
      expect(early, greaterThan(_top(_still(sprout))));
    });

    test('from a seed, the stem comes up and the seed turns to leaf', () {
      const seed = WorldPlant(slot: 0, stage: GrowthStage.seed);
      const first = WorldPlant(slot: 0, stage: GrowthStage.sprout);
      const change = WorldPlantChange(from: seed, to: first);
      expect(_shape(IslandMesh.changingPlant(change, 0)), _shape(_still(seed)));
      expect(
        _shape(IslandMesh.changingPlant(change, 1)),
        _shape(_still(first)),
      );
      expect(IslandMesh.changingPlant(change, 0.5), isNotEmpty);
    });

    test('a waking plant warms and lifts; the stage never changes', () {
      const resting = WorldPlant(
        slot: 1,
        stage: GrowthStage.grown,
        vitality: Vitality.dormant,
      );
      const awake = WorldPlant(slot: 1, stage: GrowthStage.grown);
      const change = WorldPlantChange(from: resting, to: awake);
      expect(
        _top(IslandMesh.changingPlant(change, 0.5)),
        greaterThan(_top(_still(resting))),
      );
      expect(
        _shape(IslandMesh.changingPlant(change, 1)),
        _shape(_still(awake)),
      );
    });

    test('a new plant comes up out of the ground', () {
      const change = WorldPlantChange(from: null, to: sprout);
      final start = IslandMesh.changingPlant(change, 0);
      expect(_top(start), lessThan(0.25)); // flat on the plaza (top 0.22)
      expect(
        _shape(IslandMesh.changingPlant(change, 1)),
        _shape(_still(sprout)),
      );
    });

    test('the island leaves a changing slot out while it plays', () {
      final plants = [
        for (var i = 0; i < 4; i++)
          WorldPlant(slot: i, stage: GrowthStage.young),
      ];
      final all = IslandMesh(growth: 0, plants: plants).faces.length;
      final one = _still(plants.first).length;
      expect(
        IslandMesh(growth: 0, plants: plants, changingSlots: {2}).faces.length,
        all - one,
      );
    });

    test('its sparkle sits above the crown it grows into', () {
      expect(IslandMesh.crownOf(grown).y, greaterThan(_top(_still(grown))));
    });
  });
}
