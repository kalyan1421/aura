import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';

part 'roam_mode.g.dart';

/// Whether the personal universe opens in free roam (W05): the mode the
/// person last chose with the Tap to travel / Free roam switch. Tap-to-travel
/// is the default for everyone and stays one tap away. Presentation only:
/// kept on this phone, never pushed, and nothing is awarded for either mode.
@riverpod
class RoamModePreference extends _$RoamModePreference {
  static const String _roam = 'roam';

  @override
  Future<bool> build() async =>
      await ref.read(kvStoreProvider).get(KvKeys.universeRoamMode) == _roam;

  /// The person chose a mode on the switch.
  Future<void> choose({required bool freeRoam}) async {
    state = AsyncData(freeRoam);
    await ref
        .read(kvStoreProvider)
        .set(KvKeys.universeRoamMode, freeRoam ? _roam : null);
  }
}
