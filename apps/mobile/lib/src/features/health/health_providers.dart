import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import 'health_source.dart';

part 'health_providers.g.dart';

/// The platform health adapter. Override in the app (or a test) once an
/// adapter exists; the default keeps every health surface hidden.
@Riverpod(keepAlive: true)
HealthSource healthSource(Ref ref) => const UnavailableHealthSource();

@riverpod
Future<HealthAvailability> healthAvailability(Ref ref) async {
  try {
    return await ref.watch(healthSourceProvider).availability();
  } on Object catch (e) {
    debugPrint('health: availability ${e.runtimeType}');
    return HealthAvailability.unavailable;
  }
}

/// Why turning steps on or off ended the way it did.
enum HealthToggleResult { enabled, disabled, denied, unavailable }

/// The person's opt-in to step-lit path stones. Off by default. Only the flag
/// is kept; nothing is read from the health store while it is off.
@riverpod
class HealthStepsEnabled extends _$HealthStepsEnabled {
  @override
  Future<bool> build() async =>
      await ref.watch(kvStoreProvider).get(KvKeys.healthStepsEnabled) == '1';

  Future<HealthToggleResult> setEnabled(bool on) async {
    final kv = ref.read(kvStoreProvider);
    if (!on) {
      await kv.set(KvKeys.healthStepsEnabled, null);
      state = const AsyncData(false);
      return HealthToggleResult.disabled;
    }
    final source = ref.read(healthSourceProvider);
    try {
      var availability = await source.availability();
      if (availability == HealthAvailability.unavailable) {
        return HealthToggleResult.unavailable;
      }
      if (availability == HealthAvailability.needsPermission) {
        if (!await source.requestStepsAccess()) return HealthToggleResult.denied;
        availability = await source.availability();
        if (availability != HealthAvailability.ready) {
          return HealthToggleResult.denied;
        }
      }
    } on Object catch (e) {
      debugPrint('health: enable ${e.runtimeType}');
      return HealthToggleResult.unavailable;
    }
    await kv.set(KvKeys.healthStepsEnabled, '1');
    state = const AsyncData(true);
    return HealthToggleResult.enabled;
  }
}

/// Today's steps for the world, or `null`: off unless the person opted in and
/// access is granted. Read fresh each time the universe opens; the number goes
/// straight into [litStones] and is never stored, logged or shown.
@riverpod
Future<int?> worldSteps(Ref ref) async {
  if (!(await ref.watch(healthStepsEnabledProvider.future))) return null;
  final source = ref.watch(healthSourceProvider);
  final time = ref.watch(timeContextProvider);
  try {
    if (await source.availability() != HealthAvailability.ready) return null;
    return await source.stepsToday(time.now(), time.timezone);
  } on Object catch (e) {
    debugPrint('health: steps ${e.runtimeType}');
    return null;
  }
}
