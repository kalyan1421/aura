import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';

/// At start and on resume: adopt the device zone for new records, and if it
/// differs from the zone last sent in `POST /v1/profile`, queue a profile
/// re-send so the server's fallback zone follows the phone (travel).
Future<void> refreshDeviceTimezone(WidgetRef ref) async {
  final zone = await ref.read(timezoneResolverProvider)();
  ref.read(deviceTimezoneProvider.notifier).set(zone);
  final sent = await ref.read(kvStoreProvider).get(KvKeys.profileTimezone);
  if (sent != null && sent != zone) {
    await ref.read(profileServiceProvider).markDirty();
    ref.read(syncControllerProvider).notifyLocalWrite();
  }
}
