import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/remote_config/device_ban.dart';
import '../../core/remote_config/remote_config.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../account/account_providers.dart';
import '../auth/account_closed.dart';
import 'reflection_draft.dart';
import 'reflections_api.dart';
import 'reflections_repository.dart';

part 'reflections_providers.g.dart';

/// `null` when this build has no API (debug builds without config): the
/// room then shows no reflections section at all.
@Riverpod(keepAlive: true)
ReflectionsApi? reflectionsApi(Ref ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  return HttpReflectionsApi(
    baseUrl: Env.apiUrl,
    accessToken: auth.accessToken,
    onDeviceBanned: () {
      if (ref.mounted) ref.read(deviceBannedProvider.notifier).report();
    },
  );
}

@Riverpod(keepAlive: true)
ReflectionsRepository reflectionsRepository(Ref ref) => ReflectionsRepository(
  api: ref.watch(reflectionsApiProvider),
  isOnline: () => ref.read(connectivityProvider).value ?? true,
  onDeletionPending: () =>
      unawaited(ref.read(deletionHoldProvider.notifier).reportFromSync()),
  onAccountClosed: () => ref.read(accountClosedProvider.notifier).report(),
);

@Riverpod(keepAlive: true)
ReflectionDraftStore reflectionDraftStore(Ref ref) =>
    ReflectionDraftStore(ref.watch(kvStoreProvider));

/// Remote flag keys (contracts/api/v1-reflections.md §6).
abstract final class ReflectionFlags {
  /// On by default (`payload.pausedPools`); off → no new reflections.
  static const String composer = 'reflections_composer';

  /// Off by default; on → reflections pause while AK is unreachable.
  static const String reducedMode = 'reduced_mode';
}

/// Whether the remote flags let the composer show at all. The server's
/// `composer.state` still decides (a paused language pool is only known
/// there: the room detail carries no pool).
@riverpod
bool reflectionsComposerAllowed(Ref ref) {
  final flags = ref.watch(remoteFlagsProvider);
  return reflectionsComposerAllowedBy(flags);
}

/// [reflectionsComposerAllowed] for a flags snapshot: `reflections_composer`
/// defaults to on (it isn't in the bundled defaults), `reduced_mode` to off.
bool reflectionsComposerAllowedBy(RemoteFlags flags) {
  final composerOn = flags.keys.contains(ReflectionFlags.composer)
      ? flags.enabled(ReflectionFlags.composer)
      : true;
  return composerOn && !flags.enabled(ReflectionFlags.reducedMode);
}
