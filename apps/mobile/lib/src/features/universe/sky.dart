import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';

part 'sky.g.dart';

/// The wall-clock hour (0-23) on the phone at [instant] in the app's zone.
int localHourOf(DateTime instant, int offsetMinutes) {
  final minutes = instant.toUtc().hour * 60 + instant.toUtc().minute;
  return (((minutes + offsetMinutes) ~/ 60) % 24 + 24) % 24;
}

/// The sky over the personal universe (W06, RULES.md section 13 `sky`): the
/// phone's own time of day. No location, no permission, no personal data.
/// Rebuilds only when the phase changes, not on every clock tick.
@riverpod
SkyPhase sky(Ref ref) {
  final time = ref.watch(timeContextProvider);
  final hour = ref.watch(
    nowProvider.select(
      (n) => localHourOf(
        n.value ?? time.now(),
        time.offsetMinutes(n.value ?? time.now()),
      ),
    ),
  );
  return skyPhase(hour);
}
