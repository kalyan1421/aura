import 'dart:math' as math;
import 'dart:typed_data';

import '../universe_scene.dart';

/// The island's triangles as flat GPU vertex arrays (T01). Pure Dart, no GPU
/// import, so it is tested without a device.
///
/// The Canvas renderer shades each face with a fixed light at paint time. That
/// light never moves, so the shading is baked into the vertex colours here and
/// the GPU draws them unlit: the same picture, with a real depth buffer instead
/// of painter's-algorithm ordering.
class BakedFaces {
  const BakedFaces({
    required this.positions,
    required this.normals,
    required this.colors,
  });

  /// Three floats per vertex.
  final Float32List positions;
  final Float32List normals;

  /// Four floats (r, g, b, a) per vertex, already shaded.
  final Float32List colors;

  int get vertexCount => positions.length ~/ 3;
  int get faceCount => vertexCount ~/ 3;
}

/// The direction the light comes from: the same constant the Canvas painter
/// uses, so both renderers shade alike.
final WorldPoint islandLight = const WorldPoint(-0.5, 1, 0.6).unit;

/// How lit a face is (0.68 in shadow up to 1.0 facing the light).
double faceBrightness(WorldFace face) =>
    0.68 + 0.32 * math.max(0, face.normal.dot(islandLight));

/// The GPU pipeline is mirrored left to right compared with the Canvas
/// projection (Flutter GPU's handedness), so the GPU scene is built with the
/// world's x axis negated, and its camera is placed the same way
/// ([mirrorX]). Picking and the overlay layers keep using the ordinary
/// (unmirrored) world, so everything lines up on screen.
double mirrorX(double x) => -x;

/// sRGB to linear light. The GPU treats vertex colours as linear and encodes
/// the result to sRGB on output, so colours authored (and shaded) in sRGB, as
/// the Canvas renderer does, must be linearised or they come out washed out.
double srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Bakes [faces]: flat normals, and each colour times its [faceBrightness]
/// (shaded in sRGB like Canvas, then linearised), in the GPU's mirrored world.
BakedFaces bakeFaces(Iterable<WorldFace> faces) {
  final list = faces is List<WorldFace> ? faces : faces.toList();
  final positions = Float32List(list.length * 9);
  final normals = Float32List(list.length * 9);
  final colors = Float32List(list.length * 12);
  var p = 0;
  var c = 0;
  for (final face in list) {
    final n = face.normal;
    final b = faceBrightness(face);
    for (final v in [face.a, face.b, face.c]) {
      positions[p] = mirrorX(v.x);
      positions[p + 1] = v.y;
      positions[p + 2] = v.z;
      normals[p] = mirrorX(n.x);
      normals[p + 1] = n.y;
      normals[p + 2] = n.z;
      p += 3;
      colors[c] = srgbToLinear(face.color.r * b);
      colors[c + 1] = srgbToLinear(face.color.g * b);
      colors[c + 2] = srgbToLinear(face.color.b * b);
      colors[c + 3] = 1;
      c += 4;
    }
  }
  return BakedFaces(positions: positions, normals: normals, colors: colors);
}
