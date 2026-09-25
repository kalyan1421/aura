import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_service.dart' show SyncPhase;
import 'keepsakes_api.dart';
import 'keepsakes_repository.dart';

/// Plain providers (no codegen), like features/ripples. Tests override the
/// API.

/// `null` when this build has no API, or nobody is signed in (keepsakes are
/// awarded by the server to an account).
final keepsakesApiProvider = Provider<KeepsakesApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAvailable) return null;
  return HttpKeepsakesApi(baseUrl: Env.apiUrl, accessToken: auth.accessToken);
});

final keepsakesRepositoryProvider = Provider<KeepsakesRepository>(
  (ref) => KeepsakesRepository(
    kv: ref.watch(kvStoreProvider),
    api: ref.watch(keepsakesApiProvider),
  ),
);

/// The cached keepsakes (catalogue order). `null` until the first fetch on
/// this phone.
final keepsakesProvider = StreamProvider<List<OwnKeepsake>?>(
  (ref) => ref.watch(keepsakesRepositoryProvider).watch(),
);

/// Keepsakes already shown on Home.
final seenKeepsakesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(keepsakesRepositoryProvider).watchSeen(),
);

/// Keeps the cache fresh: once when first watched (Home), then after every
/// sync that ends with everything on the server (a seal, a check-in or a
/// Sanctuary record may have earned one), at most once a minute. The server
/// awards; this only asks.
final keepsakesAutoRefreshProvider = Provider<void>((ref) {
  final repo = ref.watch(keepsakesRepositoryProvider);
  final sync = ref.watch(syncControllerProvider);
  DateTime? last;
  void refresh() {
    final now = DateTime.now();
    if (last != null && now.difference(last!) < const Duration(minutes: 1)) {
      return;
    }
    last = now;
    unawaited(repo.refresh());
  }

  void onPhase() {
    if (sync.phase.value == SyncPhase.idle) refresh();
  }

  sync.phase.addListener(onPhase);
  ref.onDispose(() => sync.phase.removeListener(onPhase));
  refresh();
});

/// The keepsakes shown on Home this session (the new-seal card shows once).
/// `null` when no card is showing.
class KeepsakeHomeController extends Notifier<List<OwnKeepsake>?> {
  @override
  List<OwnKeepsake>? build() => null;

  /// Shows [fresh] once: they are marked seen straight away and stay on Home
  /// for this session until dismissed or opened. [quiet] keys (glow seals
  /// while Comfort › hide streak number is on) are marked seen without a card.
  Future<void> show(List<OwnKeepsake> fresh, {Set<String> quiet = const {}}) {
    final visible = fresh.where((k) => !quiet.contains(k.key)).toList();
    if (visible.isNotEmpty && state == null) state = visible;
    return ref
        .read(keepsakesRepositoryProvider)
        .markSeen(fresh.map((k) => k.key));
  }

  void dismiss() => state = null;

  @visibleForTesting
  List<OwnKeepsake>? get showing => state;
}

final keepsakeHomeProvider =
    NotifierProvider<KeepsakeHomeController, List<OwnKeepsake>?>(
      KeepsakeHomeController.new,
    );
