import 'dart:async';

import 'package:aura_domain/aura_domain.dart';

import '../../core/db/kv_store.dart';
import '../../core/net/aura_api.dart' show ApiException;
import 'keepsakes_api.dart';

/// Keys of this feature in the encrypted key/value table. All are the
/// signed-in person's (wiped at sign-out with everything else that isn't
/// device-scoped), so a shared phone never shows someone else's keepsakes.
abstract final class KeepsakeKv {
  /// `{keepsakes: [{key, earnedOn}]}`: the last list the server sent
  /// (PRD 16-offline "keepsakes cached; new ones awarded on sync").
  static const String cache = 'keepsakes.cache';

  /// `{keys: [...]}`: keepsakes already shown on the Home card.
  static const String seen = 'keepsakes.seen';
}

/// Result of a [KeepsakesRepository.refresh].
enum KeepsakesRefresh {
  updated,
  offline,
  network,
  signedOut,
  accountUnavailable,
  unavailable,
  failed,
}

/// The person's own keepsakes: fetched from NestJS (which awards anything
/// newly reached first), cached on the phone for offline use. Never written
/// by the app: there is no way to grant, change or remove one here.
class KeepsakesRepository {
  KeepsakesRepository({required this._kv, required this._api, this._isOnline});

  final KvStore _kv;
  final KeepsakesApi? _api;
  final bool Function()? _isOnline;

  /// The cached keepsakes in catalogue order, known keys only (a key from a
  /// newer server is simply not shown). `null` until the first fetch.
  Stream<List<OwnKeepsake>?> watch() =>
      _kv.watchJson(KeepsakeKv.cache).map(_decode);

  static List<OwnKeepsake>? _decode(Map<String, dynamic>? json) {
    if (json == null) return null;
    final raw = json['keepsakes'];
    if (raw is! List) return const [];
    final list = [for (final j in raw) ?OwnKeepsake.tryFromJson(j)]
        .where((k) => keepsakeIndex(k.key) != null)
        .toList();
    list.sort((a, b) => keepsakeIndex(a.key)!.compareTo(keepsakeIndex(b.key)!));
    return list;
  }

  Future<KeepsakesRefresh> refresh() async {
    final api = _api;
    if (api == null) return KeepsakesRefresh.unavailable;
    if (_isOnline?.call() == false) return KeepsakesRefresh.offline;
    try {
      final list = await api.mine();
      await _kv.setJson(KeepsakeKv.cache, {
        'keepsakes': [for (final k in list) k.toJson()],
      });
      return KeepsakesRefresh.updated;
    } on ApiException catch (e) {
      if (e.status == 401) return KeepsakesRefresh.signedOut;
      if (e.isDeletionPending || e.isAccountClosed || e.isDeviceBanned) {
        return KeepsakesRefresh.accountUnavailable;
      }
      if (e.isNetwork ||
          (e.status ?? 0) >= 500 ||
          e.status == 408 ||
          e.status == 429) {
        return KeepsakesRefresh.network;
      }
      return KeepsakesRefresh.failed;
    } on Object {
      // Keep the cache for every failure; an unknown error isn't proof
      // that the phone is offline.
      return KeepsakesRefresh.failed;
    }
  }

  Stream<Set<String>> watchSeen() => _kv
      .watchJson(KeepsakeKv.seen)
      .map(
        (j) => {...((j?['keys'] as List<dynamic>?) ?? const []).cast<String>()},
      );

  Future<void> markSeen(Iterable<String> keys) async {
    final current = await _kv.getJson(KeepsakeKv.seen);
    final all = {
      ...((current?['keys'] as List<dynamic>?) ?? const []).cast<String>(),
      ...keys,
    };
    await _kv.setJson(KeepsakeKv.seen, {'keys': all.toList()..sort()});
  }
}
