import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../env/env.dart';
import '../providers.dart';
import '../sync/sync_service.dart';
import 'install_id.dart';
import 'remote_config.dart';
import 'remote_config_store.dart';
import 'remote_helplines.dart';
import 'remote_lexicon.dart';
import 'signed_bundle.dart';

/// Remote config wiring (docs/setup/lexicon-and-flags.md). Other features read
/// flags with `ref.watch(remoteFlagsProvider)` — one line, e.g.
/// `ref.watch(remoteFlagsProvider).roomsEnabled`.

/// The public keys this build trusts for signed bundles.
final bundleKeysProvider = Provider<BundleKeys>((ref) => BundleKeys.forBuild());

final remoteConfigStoreProvider = Provider<RemoteConfigStore>(
  (ref) => FileRemoteConfigStore(getApplicationSupportDirectory),
);

/// `null` when this build has no API (the bundled defaults then apply).
final remoteConfigApiProvider = Provider<RemoteConfigApi?>(
  (ref) => Env.hasApi ? HttpRemoteConfigApi(baseUrl: Env.apiUrl) : null,
);

/// This install's random id, for the calls that check device bans.
final installIdProvider = Provider<InstallId>(
  (ref) => InstallId(ref.watch(secureStoreProvider)),
);

/// Lives for the whole session (AuraApp watches it): the kept config and
/// lexicon at start, then the network while the app is in the foreground —
/// polled every `pollSeconds`, refreshed on resume and after each successful
/// sync. Timers never run in the background, nor where there is no app
/// lifecycle at all (widget tests).
final remoteConfigControllerProvider = Provider<RemoteConfigController>((ref) {
  final store = ref.watch(remoteConfigStoreProvider);
  final controller = RemoteConfigController(
    api: ref.watch(remoteConfigApiProvider),
    store: store,
    lexicon: RemoteLexicon(keys: ref.watch(bundleKeysProvider), store: store),
    helplines: RemoteHelplines(
      keys: ref.watch(bundleKeysProvider),
      store: store,
    ),
  );
  bool visible() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  unawaited(
    controller.start(foreground: visible()).whenComplete(() {
      // Some platforms report "resumed" only after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (visible() && !controller.polling) {
          unawaited(controller.onForeground());
        }
      });
    }),
  );
  final life = AppLifecycleListener(
    onStateChange: (state) {
      switch (state) {
        case AppLifecycleState.resumed:
          unawaited(controller.onForeground());
        case AppLifecycleState.hidden ||
            AppLifecycleState.paused ||
            AppLifecycleState.detached:
          controller.onBackground();
        case AppLifecycleState.inactive:
          break;
      }
    },
  );
  // "Refreshed on sync" (PRD 16 Offline, 06c F9).
  final sync = ref.watch(syncControllerProvider);
  void onPhase() {
    if (sync.phase.value == SyncPhase.idle && visible()) {
      unawaited(controller.refresh());
    }
  }

  sync.phase.addListener(onPhase);
  ref.onDispose(() {
    life.dispose();
    try {
      sync.phase.removeListener(onPhase);
    } on Object {
      // The sync controller was disposed first.
    }
    controller.dispose();
  });
  return controller;
});

/// The typed flags (`RemoteFlags`): the server's last word, else the bundled
/// safe defaults. Rebuilds its readers when a flag changes.
final remoteFlagsProvider = NotifierProvider<RemoteFlagsNotifier, RemoteFlags>(
  RemoteFlagsNotifier.new,
);

class RemoteFlagsNotifier extends Notifier<RemoteFlags> {
  @override
  RemoteFlags build() {
    final flags = ref.watch(remoteConfigControllerProvider).flags;
    void update() => state = flags.value;
    flags.addListener(update);
    ref.onDispose(() => flags.removeListener(update));
    return flags.value;
  }
}

/// Whether anything can be bought in this build right now
/// ([RemoteFlags.plusEnabled]; bundled default off). Every purchase surface
/// (paywall routes, Plus cards and Settings section, gifts, skies, restore,
/// the store plugin itself) checks this one provider.
final plusEnabledProvider = Provider<bool>(
  (ref) => ref.watch(remoteFlagsProvider.select((f) => f.plusEnabled)),
);
