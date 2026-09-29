import 'dart:math' as math;
import 'dart:ui';

import 'package:aura_domain/aura_domain.dart' show GrowthStage, Vitality;

/// Presentation-only coordinates. No personal text or identifiers enter
/// the renderer, and geometry never awards or persists progression.
class WorldPoint {
  const WorldPoint(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  WorldPoint operator +(WorldPoint b) => WorldPoint(x + b.x, y + b.y, z + b.z);
  WorldPoint operator -(WorldPoint b) => WorldPoint(x - b.x, y - b.y, z - b.z);
  WorldPoint operator *(double s) => WorldPoint(x * s, y * s, z * s);
  double dot(WorldPoint b) => x * b.x + y * b.y + z * b.z;
  WorldPoint cross(WorldPoint b) =>
      WorldPoint(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  WorldPoint get unit {
    final length = math.sqrt(dot(this));
    return length < 1e-9 ? const WorldPoint(0, 0, 0) : this * (1 / length);
  }

  static WorldPoint lerp(WorldPoint a, WorldPoint b, double t) =>
      a + (b - a) * t.clamp(0, 1);
}

enum UniverseDestination {
  grove,
  tidePool,
  reflection,
  observatory;

  WorldPoint get position => switch (this) {
    grove => const WorldPoint(-1.3, 0.15, 0.8),
    tidePool => const WorldPoint(1.3, 0.15, 0.8),
    reflection => const WorldPoint(-1.25, 0.15, -1.2),
    observatory => const WorldPoint(1.25, 0.15, -1.2),
  };

  WorldPoint get avatarStop => position * 0.7;
}

/// Read existing progress; never create a second reward ledger. Today’s
/// missed habits and moods cannot shrink the island or change its weather.
double universeGrowth(int starlight) =>
    (math.log(1 + math.max(0, starlight)) / math.log(1001)).clamp(0, 1);

/// One habit plant as the renderer sees it: a slot, a growth stage and how
/// rested it looks (RULES.md section 13). No habit name, id, note or date
/// crosses this boundary, and drawing it never awards or persists anything.
class WorldPlant {
  const WorldPlant({
    required this.slot,
    required this.stage,
    this.vitality = Vitality.thriving,
  });
  final int slot;
  final GrowthStage stage;
  final Vitality vitality;

  @override
  bool operator ==(Object other) =>
      other is WorldPlant &&
      other.slot == slot &&
      other.stage == stage &&
      other.vitality == vitality;

  @override
  int get hashCode => Object.hash(slot, stage, vitality);
}

/// The most habit plants the grove holds (six presets + three custom habits).
const int maxWorldPlants = 9;

class UniverseCamera {
  const UniverseCamera({
    this.yaw = 0.18,
    this.pitch = 0.66,
    this.distance = 7.8,
  });
  final double yaw;
  final double pitch;
  final double distance;

  UniverseCamera orbit(double horizontal, double vertical) => UniverseCamera(
    yaw: yaw + horizontal,
    pitch: (pitch + vertical).clamp(0.35, 1.15),
    distance: distance,
  );

  UniverseCamera zoom(double delta) => UniverseCamera(
    yaw: yaw,
    pitch: pitch,
    distance: (distance + delta).clamp(6.5, 11),
  );

  WorldPoint get eye => WorldPoint(
    math.sin(yaw) * math.cos(pitch) * distance,
    math.sin(pitch) * distance,
    math.cos(yaw) * math.cos(pitch) * distance,
  );
  WorldPoint get forward => (const WorldPoint(0, 0.25, 0) - eye).unit;
  WorldPoint get right => forward.cross(const WorldPoint(0, 1, 0)).unit;
  WorldPoint get up => right.cross(forward).unit;

  ({Offset point, double depth})? project(WorldPoint p, Size size) =>
      projector(size)(p);

  /// Cache the camera basis once per frame, not once per mesh vertex.
  ({Offset point, double depth})? Function(WorldPoint) projector(Size size) {
    final viewEye = eye;
    final viewForward = forward;
    final viewRight = right;
    final viewUp = up;
    final focal = math.min(size.width, size.height) * 1.65;
    return (p) {
      final relative = p - viewEye;
      final depth = relative.dot(viewForward);
      if (depth <= 0.1 || size.isEmpty) return null;
      return (
        point: Offset(
          size.width / 2 + relative.dot(viewRight) * focal / depth,
          size.height * 0.48 - relative.dot(viewUp) * focal / depth,
        ),
        depth: depth,
      );
    };
  }

  /// Uses the same projection as painting, so picking follows the camera.
  UniverseDestination? pick(Offset point, Size size) {
    UniverseDestination? nearest;
    double best = 42;
    final projectPoint = projector(size);
    for (final d in UniverseDestination.values) {
      final projected = projectPoint(d.position + const WorldPoint(0, 0.35, 0));
      if (projected == null) continue;
      final distance = (projected.point - point).distance;
      if (distance < best) {
        best = distance;
        nearest = d;
      }
    }
    return nearest;
  }
}

class WorldFace {
  const WorldFace(this.a, this.b, this.c, this.color);
  final WorldPoint a;
  final WorldPoint b;
  final WorldPoint c;
  final Color color;
  WorldPoint get center => (a + b + c) * (1 / 3);
  WorldPoint get normal => (b - a).cross(c - a).unit;
}

/// Original, small geometric art. The mesh builder is presentation code,
/// deliberately bounded; no physics, scripting, networking or asset loader.
class IslandMesh {
  /// [plants] draws one plant per habit (W03). Without it the grove falls back
  /// to three plants that follow the aggregate [growth] (the first prototype).
  IslandMesh({
    required double growth,
    this.lowDetail = false,
    List<WorldPlant>? plants,
  }) {
    const rock = Color(0xFF605A83);
    const grass = Color(0xFF547D77);
    const brass = Color(0xFFD7B88A);
    const stone = Color(0xFFADA8B8);
    const water = Color(0xFF72B8BB);
    const leaf = Color(0xFF9CCAAD);
    frustum(
      const WorldPoint(0, -0.72, 0),
      1.55,
      2.55,
      0.76,
      rock,
      18,
      capTop: false,
    );
    frustum(const WorldPoint(0, 0.04, 0), 2.55, 2.50, 0.09, grass, 24);
    terrainFaceCount = faces.length;
    // Stepping stones connect every landmark to the companion.
    for (final d in UniverseDestination.values) {
      for (var i = 1; i <= 4; i++) {
        final p = d.position * (i / 5);
        frustum(WorldPoint(p.x, 0.14, p.z), 0.09, 0.09, 0.035, stone, 6);
      }
    }
    final grove = UniverseDestination.grove.position;
    final plaza = plants == null ? 0.57 : 0.78;
    frustum(grove, plaza, plaza, 0.07, brass, 12);
    if (plants == null) {
      for (var i = 0; i < 3; i++) {
        final p = grove + WorldPoint((i - 1) * 0.32, 0.08, i == 1 ? -0.2 : 0.1);
        final height = 0.28 + growth * 0.58;
        frustum(p, 0.035, 0.025, height, brass, 6);
        sphere(p + WorldPoint(0, height, 0), 0.14 + growth * 0.12, leaf);
        sphere(p + WorldPoint(0.08, height * 0.65, 0), 0.1, grass);
      }
    } else {
      for (final plant in plants.take(maxWorldPlants)) {
        _plant(grove + plantOffset(plant.slot), plant, leaf, grass, brass);
      }
    }
    final pool = UniverseDestination.tidePool.position;
    frustum(pool, 0.61, 0.61, 0.09, stone, 16, capTop: false);
    annulus(pool + const WorldPoint(0, 0.09, 0), 0.5, 0.61, stone, 16);
    frustum(pool + const WorldPoint(0, 0.1, 0), 0.5, 0.5, 0.02, water, 16);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      sphere(
        pool + WorldPoint(math.cos(angle) * 0.51, 0.1, math.sin(angle) * 0.51),
        0.085,
        brass,
      );
    }
    final tower = UniverseDestination.observatory.position;
    frustum(tower, 0.36, 0.36, 0.62, stone, 12);
    sphere(tower + const WorldPoint(0, 0.67, 0), 0.38, const Color(0xFF9185B8));
    sphere(tower + const WorldPoint(0, 0.44, 0.37), 0.1, brass);
    frustum(tower + const WorldPoint(0, 0.9, 0), 0.025, 0.02, 0.25, brass, 6);
    sphere(
      tower + const WorldPoint(0, 1.15, 0),
      0.065,
      const Color(0xFFF8DBA4),
    );
    final stars = UniverseDestination.reflection.position;
    frustum(stars, 0.46, 0.46, 0.06, const Color(0xFF79769C), 12);
    for (var i = 0; i < 4; i++) {
      final p = stars + WorldPoint((i - 1.5) * 0.23, 0.6 + (i % 2) * 0.3, 0);
      frustum(
        WorldPoint(p.x, stars.y, p.z),
        0.013,
        0.013,
        p.y - stars.y,
        brass,
        4,
      );
      sphere(p, 0.08, const Color(0xFFF8DBA4));
    }
    // Small permanent rocks and shrubs give depth without visual noise.
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7;
      sphere(
        WorldPoint(math.cos(angle) * 2.17, 0.18, math.sin(angle) * 2.17),
        0.12,
        stone,
      );
    }
  }

  final bool lowDetail;
  final List<WorldFace> faces = [];
  int terrainFaceCount = 0;

  /// Stable place of a plant on the grove plaza: three in an inner ring, then
  /// six in an outer one, so a habit keeps its spot while others change.
  static WorldPoint plantOffset(int slot) {
    final i = slot.clamp(0, maxWorldPlants - 1);
    final inner = i < 3;
    final angle = inner ? 0.5 + i * math.pi * 2 / 3 : (i - 3) * math.pi / 3;
    final radius = inner ? 0.28 : 0.56;
    return WorldPoint(math.cos(angle) * radius, 0.07, math.sin(angle) * radius);
  }

  // Stage sets the size; vitality only changes colour and how high the crown
  // sits. A resting plant stays, keeps its stage and never turns brown or
  // grey: dusk blue reads as asleep, not dead (RULES.md section 13).
  static const List<double> _stageHeight = [0, 0.14, 0.26, 0.38, 0.5, 0.6];
  static const List<double> _stageCrown = [
    0.045,
    0.055,
    0.075,
    0.095,
    0.115,
    0.135,
  ];

  void _plant(
    WorldPoint base,
    WorldPlant plant,
    Color leaf,
    Color grass,
    Color brass,
  ) {
    final stage = plant.stage.index;
    final crown = _stageCrown[stage];
    const dusk = Color(0xFF7480A6);
    final (double droop, Color color) = switch (plant.vitality) {
      Vitality.thriving => (1.0, leaf),
      Vitality.dimmed => (0.95, Color.lerp(leaf, dusk, 0.3)!),
      Vitality.wilting => (0.78, Color.lerp(leaf, dusk, 0.6)!),
      Vitality.dormant => (0.62, Color.lerp(leaf, dusk, 0.85)!),
    };
    if (stage == 0) {
      sphere(base + const WorldPoint(0, 0.02, 0), crown, brass, coarse: true);
      return;
    }
    final height = _stageHeight[stage] * droop;
    frustum(base, 0.03, 0.02, height, brass, 6);
    sphere(base + WorldPoint(0, height, 0), crown, color, coarse: true);
    if (stage >= 3) {
      sphere(
        base + WorldPoint(0.07, height * 0.62, 0),
        crown * 0.7,
        plant.vitality == Vitality.thriving ? grass : color,
        coarse: true,
      );
    }
  }

  void frustum(
    WorldPoint base,
    double bottom,
    double top,
    double height,
    Color color,
    int segments, {
    bool capTop = true,
  }) {
    for (var i = 0; i < segments; i++) {
      final a = i * math.pi * 2 / segments;
      final b = (i + 1) * math.pi * 2 / segments;
      WorldPoint ring(double angle, double r, double y) =>
          base + WorldPoint(math.cos(angle) * r, y, math.sin(angle) * r);
      final p = ring(a, bottom, 0);
      final q = ring(b, bottom, 0);
      final r = ring(a, top, height);
      final s = ring(b, top, height);
      faces.addAll([
        WorldFace(p, r, q, color),
        WorldFace(q, r, s, color),
        if (capTop) WorldFace(base + WorldPoint(0, height, 0), s, r, color),
      ]);
    }
  }

  // A real opening for water, instead of overlapping coplanar disks.
  void annulus(
    WorldPoint center,
    double inner,
    double outer,
    Color color,
    int segments,
  ) {
    WorldPoint point(double angle, double radius) =>
        center +
        WorldPoint(math.cos(angle) * radius, 0, math.sin(angle) * radius);
    for (var i = 0; i < segments; i++) {
      final a = i * math.pi * 2 / segments;
      final b = (i + 1) * math.pi * 2 / segments;
      final p = point(a, inner);
      final q = point(b, inner);
      final r = point(a, outer);
      final s = point(b, outer);
      faces.addAll([WorldFace(p, s, r, color), WorldFace(p, q, s, color)]);
    }
  }

  void sphere(
    WorldPoint center,
    double radius,
    Color color, {
    bool coarse = false,
  }) {
    // Plants are small: the coarse mesh keeps nine of them cheap.
    final rings = lowDetail || coarse ? 3 : 5;
    final segments = lowDetail || coarse ? 6 : 8;
    WorldPoint point(int row, int col) {
      final phi = row * math.pi / rings;
      final theta = col * math.pi * 2 / segments;
      return center +
          WorldPoint(
            radius * math.sin(phi) * math.cos(theta),
            radius * math.cos(phi),
            radius * math.sin(phi) * math.sin(theta),
          );
    }

    for (var row = 0; row < rings; row++) {
      for (var col = 0; col < segments; col++) {
        final a = point(row, col);
        final b = point(row, col + 1);
        final c = point(row + 1, col);
        final d = point(row + 1, col + 1);
        if (row > 0) faces.add(WorldFace(a, b, c, color));
        if (row < rings - 1) faces.add(WorldFace(b, d, c, color));
      }
    }
  }

  static List<WorldFace> companion(
    WorldPoint position, {
    bool lowDetail = false,
  }) {
    // Reuse the bounded mesh primitives without rebuilding the island.
    final art = IslandMesh._(lowDetail);
    const coat = Color(0xFFE9C79D);
    const face = Color(0xFFF9EED6);
    final p = WorldPoint(position.x, 0.16, position.z);
    art.frustum(p, 0.21, 0.12, 0.39, coat, 10);
    art.sphere(p + const WorldPoint(0, 0.48, 0), 0.18, face);
    art.sphere(
      p + const WorldPoint(-0.063, 0.5, 0.157),
      0.021,
      const Color(0xFF403D53),
    );
    art.sphere(
      p + const WorldPoint(0.063, 0.5, 0.157),
      0.021,
      const Color(0xFF403D53),
    );
    art.sphere(
      p + const WorldPoint(0, 0.69, 0),
      0.065,
      const Color(0xFFB7DDBA),
    );
    return art.faces;
  }

  IslandMesh._(this.lowDetail);
}
