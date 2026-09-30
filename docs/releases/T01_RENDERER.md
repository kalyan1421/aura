# T01 — the GPU renderer for the personal universe (result)

**Decision: the Canvas painter stays the shipping renderer.** The GPU renderer (`flutter_scene`, Flutter GPU) is built, tested and
switched off; it is turned on per build with `--dart-define=AURA_NATIVE_SCENE=true`. It is not adopted until the physical-device run
below shows it is worth its cost.

## What was built

| Piece | Where |
|---|---|
| Host that picks the renderer (Canvas unless the flag is on **and** the probe says the GPU works, else Canvas) | `lib/src/features/universe/universe_scene_host.dart` |
| GPU view: the same `IslandMesh` faces baked to one vertex buffer, unlit double-sided material, depth buffer, on-demand rendering | `.../universe/native/` |
| Camera parity with the Canvas projector (`camera.target`, focal, drop) | `native/gpu_camera.dart` |
| Sky behind and sparkles/place lights over the GPU faces come from the **same** `IslandPainter` (`IslandLayer.background` / `.overlay`), so nothing is drawn twice or drifts | `universe_scene_view.dart` |
| Probe: touches `gpu.gpuContext` and loads the shaders; any failure means "Canvas" | `native/scene_probe.dart` |
| Hands-off benchmark (orbit + walk, 8 s per renderer, frame times, RSS) | `lib/universe_bench.dart` |

Only geometry, camera and a companion position cross the renderer boundary, as before: no personal data reaches either renderer.

## Evidence so far

| Check | Result |
|---|---|
| Picture parity, iOS simulator (debug, Impeller/Metal) | After fixing three bugs (mirrored x, too light, too dark: sRGB→linear, linear tone mapping) the GPU frame and the Canvas frame differ by a mean of 0.56/255 per channel. Simulator only |
| Widget tests | `universe_native_scene_test.dart`, `universe_reallife_test.dart` |
| Android emulator (Pixel 9 AVD, profile, Impeller **OpenGLES**), Canvas | 55 fps of 60; build 13.6 ms avg, raster 5.8 ms avg (emulator CPU, not a phone; not a budget verdict) |
| Android emulator, **GPU renderer** | **The process hangs** (ANR "executing service … AudioService, waited 20 s", the app is killed) as soon as Flutter GPU is touched. Reproduced twice; the same build with the probe skipped runs fine, and the normal app starts cleanly |
| iOS simulator, profile | Not supported by Flutter for simulators, so no timings there |

### Consequence: the probe refuses on Android

Flutter GPU on Android's OpenGLES backend blocks the process, and Dart cannot ask which backend is in use. So `nativeSceneAvailable()` says
**no on Android** unless the build passes `--dart-define=AURA_GPU_ANDROID=true` (for measuring on a Vulkan phone). A person can therefore never
be frozen by the flag; the worst case is the Canvas renderer, as today.

## Cost of carrying it

- `flutter_scene` shader bundles add about 10.6 MB uncompressed to a debug APK (T01 spike). Release size per ABI: not measured (a release
  APK with the package would show the true number; the profile APK is 55.7 MB, the last release APK before it was 95.9 MB with different contents, so they are not comparable).
- Resolving `flutter_scene` downgrades three build tools (`code_assets`, `native_toolchain_c`, `objective_c`); the full app builds and tests pass with them.
- `FLTEnableFlutterGPU` (iOS) / `EnableFlutterGPU` (Android) are now on for every build (they only enable the capability). `minSdk` is 26 (also required by Health Connect).
- The package is pre-1.0 with breaking minor releases: pin it (`^0.23.0` today).

## Still open (needs hardware)

1. **Physical iPhone**, profile build. The phone was unreachable when this was attempted (`tunnelState: unavailable`). When it is connected and unlocked:
   `cd apps/mobile && flutter run --profile -d <device-id> -t lib/universe_bench.dart`
   and read the `AURA_BENCH` lines (canvas vs gpu: fps, raster ms, p95, frames over budget, RSS). This installs a bench app that reuses the bundle id `com.akvega.aura`
   and needs signing (the HealthKit entitlement requires a provisioned profile), so it replaces any Aura install on that phone (the bench itself stores nothing), and the real app must be reinstalled afterwards.
2. A **Vulkan Android phone** with `--dart-define=AURA_GPU_ANDROID=true`, and one 3 GB low-tier phone (the PRD low tier).
3. Battery and heat over a five-minute session; backgrounding and resume; a skinned, animated rig (T02).

## Decision rule for when the numbers arrive

Adopt the GPU renderer for a device class only if, on that class, it holds the display's frame budget with `framesOverBudget` under 5%,
uses no more than 60 MB more RSS than Canvas, and the 5-minute run is not noticeably warmer. Otherwise keep Canvas for that class (the host already falls back per device).
