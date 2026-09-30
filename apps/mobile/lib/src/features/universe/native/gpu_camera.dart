import 'dart:math' as math;

import '../universe_scene.dart';

/// What a GPU camera needs to frame the island exactly as [UniverseCamera]
/// does on Canvas (T01). Pure Dart, tested against the Canvas projection.
class GpuCameraParams {
  const GpuCameraParams({
    required this.eye,
    required this.target,
    required this.fovYRadians,
  });

  final WorldPoint eye;
  final WorldPoint target;

  /// Vertical field of view for a viewport of the given size.
  final double fovYRadians;
}

/// Camera parameters for [camera] over a viewport of [size].
///
/// The Canvas projection uses a focal length of `1.65 x min(width, height)`
/// pixels and puts the look-at point ([UniverseCamera.target]) 2% of the height
/// above the centre. The
/// field of view reproduces the focal length; the 2% offset is reproduced by
/// aiming a little below the look-at point (a small rotation, so taps still
/// land within the place-picking radius).
GpuCameraParams gpuCameraFor(
  UniverseCamera camera,
  double width,
  double height,
) {
  final lookAt =
      camera.target; // the island's centre, or the companion in free roam
  final focal = math.min(width, height) * 1.65;
  final fovY = 2 * math.atan(height / (2 * focal));
  // Aim below the look-at point along the camera's up axis so that point
  // projects 2% of the height above the centre, like the Canvas projection.
  final drop = 0.02 * height / focal * camera.distance;
  final target = lookAt - camera.up * drop;
  return GpuCameraParams(eye: camera.eye, target: target, fovYRadians: fovY);
}
