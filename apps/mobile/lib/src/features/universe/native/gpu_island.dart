import 'package:flutter_scene/scene.dart';

import '../universe_scene.dart';
import 'gpu_faces.dart';

/// The island as a `flutter_scene` [Scene] (T01): the static world baked once
/// per [IslandMesh], and one small updatable mesh for what moves (the
/// companion and plants in the middle of a moment). Unlit, vertex-coloured,
/// double-sided: the colours are already shaded (see [bakeFaces]) and the depth
/// buffer decides what hides what.
class GpuIsland {
  // No tone curve: the colours are the exact shaded sRGB the Canvas renderer
  // draws (the engine's default tone mapper would darken and shift them).
  final Scene scene = Scene()..toneMapping = ToneMappingMode.linear;

  Node? _static;
  IslandMesh? _staticFor;
  MeshGeometry? _dynamicGeometry;
  UnlitMaterial? _material;

  /// Loads the engine's shader library. Fails (throws) where Flutter GPU is not
  /// available; [nativeSceneAvailable] turns that into a fallback.
  static Future<void> prepare() => Scene.initializeStaticResources();

  UnlitMaterial _unlit() => _material ??= (UnlitMaterial()..doubleSided = true);

  MeshGeometry _geometry(BakedFaces baked, {bool updatable = false}) =>
      MeshGeometry.fromArrays(
        positions: baked.positions,
        normals: baked.normals,
        colors: baked.colors,
        storage: updatable ? GeometryStorage.updatable : GeometryStorage.fixed,
      );

  /// The world that does not move. Rebuilt only when [mesh] is a new mesh.
  void setStatic(IslandMesh mesh) {
    if (identical(_staticFor, mesh)) return;
    _staticFor = mesh;
    final old = _static;
    if (old != null) scene.remove(old);
    final node = Node(
      name: 'island',
      mesh: Mesh(_geometry(bakeFaces(mesh.faces)), _unlit()),
    );
    scene.add(node);
    _static = node;
  }

  /// What moves: the companion and any plants changing. Cheap enough to call on
  /// every animated frame (a few hundred triangles).
  void setDynamic(List<WorldFace> faces) {
    final baked = bakeFaces(faces);
    final existing = _dynamicGeometry;
    if (existing == null) {
      final geometry = _geometry(baked, updatable: true);
      _dynamicGeometry = geometry;
      scene.add(Node(name: 'moving', mesh: Mesh(geometry, _unlit())));
    } else {
      existing.rebuild(
        positions: baked.positions,
        normals: baked.normals,
        colors: baked.colors,
      );
    }
  }
}
