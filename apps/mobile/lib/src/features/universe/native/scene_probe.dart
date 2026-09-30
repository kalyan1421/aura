import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_gpu/gpu.dart' as gpu;

import 'gpu_island.dart';

Future<bool>? _probe;

/// Whether the GPU renderer can run here: Impeller and Flutter GPU switched on
/// (the real GPU context is created, which throws otherwise) and the engine's
/// shaders loadable. Loading the shaders alone is not enough: it can succeed
/// where drawing later fails. Asked once, then remembered. Any failure means
/// "no", never an error the person sees: the Canvas renderer takes over.
Future<bool> nativeSceneAvailable() => _probe ??= _run();

/// Forgets the answer (a test's fake-async zone must not outlive its test).
@visibleForTesting
void resetNativeSceneProbe() => _probe = null;

/// Flutter GPU on Android's OpenGLES backend (emulators, old phones) blocks the
/// process for good (an ANR on the first frame, measured in T01), and Dart cannot
/// ask which backend is in use. So Android says "no" unless a build forces it
/// (`--dart-define=AURA_GPU_ANDROID=true`, for measuring on a Vulkan phone).
const bool _forceAndroid = bool.fromEnvironment('AURA_GPU_ANDROID');

Future<bool> _run() async {
  if (Platform.isAndroid && !_forceAndroid) {
    debugPrint('scene: gpu renderer off on Android (T01: hangs on GLES)');
    return false;
  }
  try {
    gpu.gpuContext; // throws unless Flutter GPU and Impeller are enabled
    await GpuIsland.prepare();
    return true;
  } on Object catch (e) {
    debugPrint('scene: gpu renderer unavailable (${e.runtimeType})');
    return false;
  }
}
