import 'package:aura_domain/aura_domain.dart' show SkyPhase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/perf/device_profile.dart';
import 'native/native_scene_view.dart';
import 'native/scene_probe.dart';
import 'universe_scene.dart';
import 'universe_scene_view.dart';

/// Whether the GPU renderer may be used (T01). Off unless the build passes
/// `--dart-define=AURA_NATIVE_SCENE=true`: the Canvas renderer is the shipping
/// default until the GPU one has device evidence (docs/releases/T01_RENDERER.md).
/// Tests and a future remote switch override this provider.
final nativeSceneEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('AURA_NATIVE_SCENE'),
);

/// The scene the universe screen shows: the GPU renderer when it is enabled,
/// the phone is not on the low tier, and Flutter GPU actually starts; the Canvas
/// renderer otherwise, and instantly if the GPU one fails. Same inputs as
/// [UniverseSceneView].
class UniverseSceneHost extends ConsumerStatefulWidget {
  const UniverseSceneHost({
    super.key,
    required this.mesh,
    required this.camera,
    required this.companion,
    required this.selected,
    required this.onOrbit,
    required this.onSelect,
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

  @override
  ConsumerState<UniverseSceneHost> createState() => _UniverseSceneHostState();
}

class _UniverseSceneHostState extends ConsumerState<UniverseSceneHost> {
  bool _gpuOk = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(nativeSceneEnabledProvider)) {
      nativeSceneAvailable().then((ok) {
        if (mounted) setState(() => _gpuOk = ok);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(nativeSceneEnabledProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceProfile.instance.prefersLowTier,
      builder: (context, lowTier, _) {
        if (enabled && _gpuOk && !_failed && !lowTier) {
          return NativeSceneView(
            mesh: widget.mesh,
            camera: widget.camera,
            companion: widget.companion,
            selected: widget.selected,
            sky: widget.sky,
            pose: widget.pose,
            changes: widget.changes,
            changeProgress: widget.changeProgress,
            onOrbit: widget.onOrbit,
            onSelect: widget.onSelect,
            onUnavailable: () {
              if (mounted) setState(() => _failed = true);
            },
          );
        }
        return UniverseSceneView(
          mesh: widget.mesh,
          camera: widget.camera,
          companion: widget.companion,
          selected: widget.selected,
          sky: widget.sky,
          pose: widget.pose,
          changes: widget.changes,
          changeProgress: widget.changeProgress,
          onOrbit: widget.onOrbit,
          onSelect: widget.onSelect,
        );
      },
    );
  }
}
