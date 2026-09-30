import 'dart:math' as math;

import 'universe_scene.dart';

/// Free-roam movement for the personal universe (W05). Presentation-only:
/// where the companion stands never awards, persists or changes anything, and
/// every place stays reachable by tap-to-travel and the flat list too.

/// Highest point the companion walks at (its feet on the grass).
const double roamHeight = 0.16;

/// Stays inside the ring of small rocks at the island's edge.
const double roamRadius = 2.0;

/// World units per second at full input.
const double roamSpeed = 1.4;

/// One frame never moves further than this many seconds of walking, so a
/// stalled frame cannot teleport the companion.
const double roamMaxStep = 0.05;

/// Close enough to a place to choose it.
const double roamNearRange = 1.05;

/// Breathing room between the companion and a solid object.
const double roamBody = 0.2;

/// Things the companion walks around: the tide pool's wall and the tower.
const List<({WorldPoint center, double radius})> roamObstacles = [
  (center: WorldPoint(1.3, 0.15, 0.8), radius: 0.61),
  (center: WorldPoint(1.25, 0.15, -1.2), radius: 0.36),
];

/// A walking direction in the camera's frame: [right] and [forward], each -1
/// to 1. A drag pad and four held arrows both produce one.
class RoamInput {
  const RoamInput({this.right = 0, this.forward = 0});
  static const RoamInput zero = RoamInput();

  final double right;
  final double forward;

  bool get isZero => right == 0 && forward == 0;

  /// Both inputs together, never stronger than one full push.
  RoamInput operator +(RoamInput other) {
    final r = right + other.right;
    final f = forward + other.forward;
    final length = math.sqrt(r * r + f * f);
    return length > 1 ? RoamInput(right: r / length, forward: f / length) : RoamInput(right: r, forward: f);
  }

  @override
  bool operator ==(Object other) =>
      other is RoamInput && other.right == right && other.forward == forward;

  @override
  int get hashCode => Object.hash(right, forward);
}

/// One small fixed step, for a screen reader's single activation of an arrow.
const double roamNudge = 0.25;

/// The companion's next position after [dt] seconds of [input], walking
/// relative to [camera] (up on screen is away from the camera). Bounded to the
/// island and pushed out of solid objects.
WorldPoint stepRoam(
  WorldPoint position,
  RoamInput input,
  UniverseCamera camera,
  double dt,
) {
  if (input.isZero || dt <= 0) return position;
  final push = math.min(1.0, math.sqrt(input.right * input.right + input.forward * input.forward));
  return _advance(position, input, camera, push * roamSpeed * math.min(dt, roamMaxStep));
}

/// [roamNudge] world units toward [input]'s direction.
WorldPoint nudgeRoam(WorldPoint position, RoamInput input, UniverseCamera camera) =>
    input.isZero ? position : _advance(position, input, camera, roamNudge);

WorldPoint _advance(
  WorldPoint position,
  RoamInput input,
  UniverseCamera camera,
  double distance,
) {
  // Ground-plane basis from the camera (ignore its tilt).
  final f = camera.forward;
  final r = camera.right;
  final fl = math.sqrt(f.x * f.x + f.z * f.z);
  final rl = math.sqrt(r.x * r.x + r.z * r.z);
  final fx = fl < 1e-9 ? 0.0 : f.x / fl;
  final fz = fl < 1e-9 ? -1.0 : f.z / fl;
  final rx = rl < 1e-9 ? 1.0 : r.x / rl;
  final rz = rl < 1e-9 ? 0.0 : r.z / rl;
  final dirLength = math.sqrt(input.right * input.right + input.forward * input.forward);
  final ux = (rx * input.right + fx * input.forward) / dirLength;
  final uz = (rz * input.right + fz * input.forward) / dirLength;
  final next = keepOnIsland(
    WorldPoint(
      position.x + ux * distance,
      roamHeight,
      position.z + uz * distance,
    ),
  );
  // A step that cannot be resolved (against a wall at the island's edge) is
  // simply blocked; the companion never ends up inside an obstacle.
  return isWalkable(next) ? next : position;
}

/// True when [p] is on the island and clear of every obstacle.
bool isWalkable(WorldPoint p) {
  if (math.sqrt(p.x * p.x + p.z * p.z) > roamRadius + 1e-9) return false;
  for (final o in roamObstacles) {
    final dx = p.x - o.center.x;
    final dz = p.z - o.center.z;
    if (math.sqrt(dx * dx + dz * dz) < o.radius + roamBody - 1e-9) return false;
  }
  return true;
}

/// [p] moved back inside the island and out of every obstacle. Pushed out of
/// an obstacle away from its centre; if that would leave the island (the pool
/// sits close to the edge), toward the island's centre instead. Walking uses
/// [_advance], which also refuses a step that cannot be resolved.
WorldPoint keepOnIsland(WorldPoint p) {
  var x = p.x;
  var z = p.z;
  for (var pass = 0; pass < 3; pass++) {
    for (final o in roamObstacles) {
      final dx = x - o.center.x;
      final dz = z - o.center.z;
      final d = math.sqrt(dx * dx + dz * dz);
      final min = o.radius + roamBody;
      if (d >= min) continue;
      final cx = o.center.x;
      final cz = o.center.z;
      final centerDistance = math.sqrt(cx * cx + cz * cz);
      // Outward candidate (or the island centre's side when dropped dead centre).
      var nx = d < 1e-9 ? -cx / centerDistance : dx / d;
      var nz = d < 1e-9 ? -cz / centerDistance : dz / d;
      var px = cx + nx * min;
      var pz = cz + nz * min;
      if (math.sqrt(px * px + pz * pz) > roamRadius) {
        nx = -cx / centerDistance;
        nz = -cz / centerDistance;
        px = cx + nx * min;
        pz = cz + nz * min;
      }
      x = px;
      z = pz;
    }
    final d = math.sqrt(x * x + z * z);
    if (d > roamRadius) {
      x = x / d * roamRadius;
      z = z / d * roamRadius;
    }
  }
  return WorldPoint(x, roamHeight, z);
}

/// The place [p] is close enough to choose, or `null`. The nearest wins.
UniverseDestination? nearestPlace(WorldPoint p) {
  UniverseDestination? best;
  var bestDistance = roamNearRange;
  for (final d in UniverseDestination.values) {
    final dx = p.x - d.position.x;
    final dz = p.z - d.position.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance <= bestDistance) {
      best = d;
      bestDistance = distance;
    }
  }
  return best;
}

/// Where tap-to-travel stands at a place: the place's own stop
/// ([UniverseDestination.avatarStop]) moved out of the pool wall and tower, so
/// switching to free roam never snaps the companion sideways or leaves it
/// stuck inside something solid.
extension RoamStop on UniverseDestination {
  WorldPoint get walkStop => keepOnIsland(avatarStop);
}

/// How much of the way the free-roam camera follows the companion: at 1 it
/// would stay dead centre; a little less keeps more of the island in view
/// when the companion walks to the edge.
const double roamFollowReach = 0.8;

/// Where the camera looks in free roam: the island's centre blended toward
/// the companion by [weight] (0 is the whole-island view, 1 is following).
/// Only the look-at point moves: yaw, pitch and zoom stay the person's own,
/// so walking stays camera-relative without the view turning under them.
WorldPoint followTarget(WorldPoint companion, double weight) {
  final w = weight.clamp(0.0, 1.0) * roamFollowReach;
  return WorldPoint(companion.x * w, UniverseCamera.home.y, companion.z * w);
}
