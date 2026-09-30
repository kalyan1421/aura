import 'package:aura_domain/aura_domain.dart' show SkyPhase;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../universe_scene.dart';
import '../universe_scene_view.dart';
import 'gpu_camera.dart';
import 'gpu_faces.dart' show mirrorX;
import 'gpu_island.dart';
import 'scene_probe.dart';

/// The GPU renderer behind the same boundary as [UniverseSceneView] (T01):
/// the same mesh, camera, companion, sky and moments go in, and only a picture
/// comes out. The sky and the sparkles/place lights are drawn by the very same
/// [IslandPainter] (as the layers behind and in front); only the faces are
/// drawn by the GPU. It renders on demand (no frame loop while nothing moves).
/// If the GPU cannot start, [onUnavailable] is called and the host switches
/// back to Canvas.
class NativeSceneView extends StatefulWidget {
  const NativeSceneView({
    super.key,
    required this.mesh,
    required this.camera,
    required this.companion,
    required this.selected,
    required this.onOrbit,
    required this.onSelect,
    required this.onUnavailable,
    this.sky = SkyPhase.night,
    this.pose = CompanionPose.still,
    this.changes = const [],
    this.changeProgress = 1,
  });

  final IslandMesh mesh;
  final UniverseCamera camera;
  final WorldPoint companion;
  final UniverseDestination? selected;
  final SkyPhase sky;
  final CompanionPose pose;
  final List<WorldPlantChange> changes;
  final double changeProgress;
  final void Function(double horizontal, double vertical) onOrbit;
  final ValueChanged<UniverseDestination> onSelect;
  final VoidCallback onUnavailable;

  @override
  State<NativeSceneView> createState() => _NativeSceneViewState();
}

class _NativeSceneViewState extends State<NativeSceneView> {
  // Created only once the probe says the GPU works: constructing a scene
  // already touches it.
  GpuIsland? _island;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    nativeSceneAvailable().then((ok) {
      if (!mounted) return;
      if (!ok) {
        widget.onUnavailable();
        return;
      }
      _island = GpuIsland();
      _sync();
      setState(() => _ready = true);
    });
  }

  void _sync() {
    final island = _island!;
    island.setStatic(widget.mesh);
    island.setDynamic([
      for (final change in widget.changes)
        ...IslandMesh.changingPlant(
          change,
          widget.changeProgress,
          lowDetail: widget.mesh.lowDetail,
        ),
      ...IslandMesh.companion(
        widget.companion,
        lowDetail: widget.mesh.lowDetail,
        pose: widget.pose,
      ),
    ]);
  }

  @override
  void didUpdateWidget(NativeSceneView old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    if (!identical(old.mesh, widget.mesh) ||
        old.companion != widget.companion ||
        old.pose != widget.pose ||
        old.changeProgress != widget.changeProgress ||
        !listEquals(old.changes, widget.changes)) {
      _sync();
    }
  }

  IslandPainter _painter(IslandLayer layer) => IslandPainter(
    widget.mesh,
    widget.camera,
    widget.companion,
    widget.selected,
    widget.sky,
    widget.pose,
    widget.changes,
    widget.changeProgress,
    layer: layer,
  );

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, box) {
          final params = gpuCameraFor(
            widget.camera,
            box.maxWidth,
            box.maxHeight,
          );
          final camera = PerspectiveCamera(
            fovRadiansY: params.fovYRadians,
            position: vm.Vector3(
              mirrorX(params.eye.x),
              params.eye.y,
              params.eye.z,
            ),
            target: vm.Vector3(
              mirrorX(params.target.x),
              params.target.y,
              params.target.z,
            ),
            up: vm.Vector3(0, 1, 0),
            fovNear: 0.1,
            fovFar: 100,
          );
          return ExcludeSemantics(
            // The labelled destination buttons provide equivalent access.
            child: GestureDetector(
              key: const ValueKey('universe-scene'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) =>
                  widget.onOrbit(-d.delta.dx * 0.009, 0),
              onTapUp: (d) {
                final destination = widget.camera.pick(
                  d.localPosition,
                  box.biggest,
                );
                if (destination != null) widget.onSelect(destination);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _painter(IslandLayer.background)),
                  if (_ready)
                    SceneView(
                      _island!.scene,
                      camera: camera,
                      // Render when the view is rebuilt (a new camera or
                      // companion), never on a timer: no idle frame loop.
                      autoTick: false,
                    ),
                  CustomPaint(painter: _painter(IslandLayer.overlay)),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
