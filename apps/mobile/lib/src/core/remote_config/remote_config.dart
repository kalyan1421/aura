import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../time/clock.dart';
import 'remote_config_store.dart';
import 'remote_lexicon.dart';

/// Server-authoritative feature flags and kill switches (PRD 19 REQ-ADM-12:
/// "Flag changes reach clients within 5 min without a release";
/// contracts/api/v1.md "Remote config").
///
/// `GET /v1/config` (public, no sign-in) is fetched at start, on resume, after
/// a successful sync and every `pollSeconds` (≤ 240 s) while the app is in the
/// foreground, with `If-None-Match` (a `304` costs nothing). The last document
/// is kept on the phone for offline use; before the first one, or when the
/// kept one is unreadable, the bundled [RemoteFlags.defaults] apply. The same
/// document points at the live signed lexicon; a newer one is downloaded and
/// checked by [RemoteLexicon].
///
/// Flags only hide or grey UI here: the server enforces every kill switch
/// itself (a flag on the phone alone never opens anything).

/// A flag as the server sends it.
@immutable
class FlagValue {
  const FlagValue({required this.enabled, this.payload = const {}});

  final bool enabled;

  /// Extra settings (e.g. a per-partition list); empty when none.
  final Map<String, dynamic> payload;
}

/// The typed flags other features read (`ref.watch(remoteFlagsProvider)`).
@immutable
class RemoteFlags {
  const RemoteFlags([this._values = const {}]);

  /// Safe bundled defaults: what the app does before it has ever heard from
  /// the server. Rooms stay available (the server still decides every join);
  /// pools and features that open later stay closed.
  static const Map<String, bool> bundledDefaults = {
    roomsEnabledKey: true,
    roomsPoolHiKey: false,
  };

  static const RemoteFlags defaults = RemoteFlags();

  /// Kill switch: off → no new room joins (the server answers
  /// `503 rooms_paused`); rooms already joined keep working.
  static const String roomsEnabledKey = 'rooms_enabled';

  /// Hindi + Hinglish rooms are open (off → those accounts are offered an
  /// English room instead, `409 language_pool_unavailable`).
  static const String roomsPoolHiKey = 'rooms_pool_hi';

  final Map<String, FlagValue> _values;

  /// A flag the server sent, else its bundled default, else off.
  bool enabled(String key) =>
      _values[key]?.enabled ?? bundledDefaults[key] ?? false;

  Map<String, dynamic> payload(String key) => _values[key]?.payload ?? const {};

  bool get roomsEnabled => enabled(roomsEnabledKey);
  bool get roomsPoolHi => enabled(roomsPoolHiKey);

  /// Keys the server sent (tests, debug).
  Iterable<String> get keys => _values.keys;

  @override
  bool operator ==(Object other) =>
      other is RemoteFlags &&
      mapEquals(
        {for (final e in _values.entries) e.key: e.value.enabled},
        {for (final e in other._values.entries) e.key: e.value.enabled},
      ) &&
      mapEquals(
        {for (final e in _values.entries) e.key: jsonEncode(e.value.payload)},
        {
          for (final e in other._values.entries)
            e.key: jsonEncode(e.value.payload),
        },
      );

  @override
  int get hashCode => Object.hashAllUnordered(
    _values.entries.map((e) => Object.hash(e.key, e.value.enabled)),
  );
}

/// A signed bundle the server has live.
@immutable
class BundlePointer {
  const BundlePointer({required this.version, required this.seq});

  final int version;
  final int seq;
}

/// `GET /v1/config`.
@immutable
class RemoteConfigDoc {
  const RemoteConfigDoc({
    required this.configVersion,
    required this.pollSeconds,
    required this.flags,
    required this.bundles,
  });

  /// Throws [FormatException] for anything that isn't the contract shape.
  factory RemoteConfigDoc.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('config');
    }
    final version = json['configVersion'];
    final poll = json['pollSeconds'];
    final flags = json['flags'];
    final bundles = json['bundles'] ?? const <String, dynamic>{};
    if (version is! String ||
        poll is! int ||
        flags is! Map<String, dynamic> ||
        bundles is! Map<String, dynamic>) {
      throw const FormatException('config');
    }
    return RemoteConfigDoc(
      configVersion: version,
      pollSeconds: poll,
      flags: RemoteFlags({
        for (final e in flags.entries)
          if (e.value case {'enabled': final bool enabled})
            e.key: FlagValue(
              enabled: enabled,
              payload: switch (e.value) {
                {'payload': final Map<String, dynamic> p} => p,
                _ => const {},
              },
            ),
      }),
      bundles: {
        for (final e in bundles.entries)
          if (e.value case {'version': final int v, 'seq': final int s})
            e.key: BundlePointer(version: v, seq: s),
      },
    );
  }

  final String configVersion;
  final int pollSeconds;
  final RemoteFlags flags;
  final Map<String, BundlePointer> bundles;
}

/// The result of a conditional GET.
sealed class Fetched<T> {
  const Fetched();
}

class NotModified<T> extends Fetched<T> {
  const NotModified();
}

/// `404 not_published` (no lexicon published yet).
class NotPublished<T> extends Fetched<T> {
  const NotPublished();
}

class Got<T> extends Fetched<T> {
  const Got(this.value, {this.etag});

  final T value;
  final String? etag;
}

/// The two public routes (no auth header, nothing about the person).
abstract interface class RemoteConfigApi {
  Future<Fetched<Object?>> config({String? etag});

  /// The live signed lexicon envelope (decoded JSON), unverified.
  Future<Fetched<Object?>> lexicon({String? etag});
}

class HttpRemoteConfigApi implements RemoteConfigApi {
  HttpRemoteConfigApi({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 12),
              responseType: ResponseType.json,
              // 304 and 404 are answers here, not errors.
              validateStatus: (s) => s == 200 || s == 304 || s == 404,
            ),
          );

  final Dio _dio;

  Future<Fetched<Object?>> _get(String path, String? etag) async {
    final res = await _dio.get<Object?>(
      path,
      options: Options(headers: {'If-None-Match': ?etag}),
    );
    return switch (res.statusCode) {
      304 => const NotModified(),
      404 => const NotPublished(),
      _ => Got(res.data, etag: res.headers.value('etag')),
    };
  }

  @override
  Future<Fetched<Object?>> config({String? etag}) => _get('/v1/config', etag);

  @override
  Future<Fetched<Object?>> lexicon({String? etag}) =>
      _get('/v1/lexicon/crisis', etag);
}

/// Keeps [flags] current and the lexicon up to date. Timers run only while
/// the app is in the foreground ([onForeground] / [onBackground]).
class RemoteConfigController {
  RemoteConfigController({
    required this._api,
    required this._store,
    required this.lexicon,
    this._clock = const Clock(),
    this.minGap = const Duration(seconds: 20),
  });

  static const String storeName = 'config.json';

  /// The poll interval when the server doesn't say (≤ 5 min with margin).
  static const int defaultPollSeconds = 240;

  final RemoteConfigApi? _api;
  final RemoteConfigStore _store;
  final RemoteLexicon lexicon;
  final Clock _clock;

  /// Refreshes closer together than this (resume + sync + poll) are merged.
  final Duration minGap;

  final ValueNotifier<RemoteFlags> flags = ValueNotifier(RemoteFlags.defaults);

  RemoteConfigDoc? _doc;
  String? _etag;
  DateTime? _lastRefresh;
  Future<void>? _inflight;
  Timer? _poll;
  bool _foreground = false;
  bool _disposed = false;

  RemoteConfigDoc? get document => _doc;

  /// Seconds between polls while in the foreground: the server's value,
  /// clamped to 60–300 s (the 5-minute promise), default 240.
  int get pollSeconds =>
      (_doc?.pollSeconds ?? defaultPollSeconds).clamp(60, 300);

  /// Kept config and lexicon first (offline-safe), then — in the foreground —
  /// the network.
  Future<void> start({required bool foreground}) async {
    await _restore();
    await lexicon.restore();
    if (foreground) await onForeground();
  }

  /// The app is visible: refresh now (merged with a very recent one) and keep
  /// polling every [pollSeconds].
  Future<void> onForeground() {
    if (_disposed) return Future.value();
    _foreground = true;
    return refresh();
  }

  /// Hidden or paused: no timers, no calls.
  void onBackground() {
    _foreground = false;
    _poll?.cancel();
    _poll = null;
  }

  /// `GET /v1/config` (+ the lexicon when the server has a newer one). Never
  /// throws; offline or failing, the kept values stay.
  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    final last = _lastRefresh;
    if (!force && last != null && _clock.now().difference(last) < minGap) {
      // Merged with the recent one; keep the running poll as it is.
      if (_poll == null && _inflight == null) _schedule();
      return _inflight ?? Future.value();
    }
    return _inflight ??= _refresh().whenComplete(() {
      _inflight = null;
      _schedule();
    });
  }

  Future<void> _refresh() async {
    final api = _api;
    if (api == null) return;
    _lastRefresh = _clock.now();
    try {
      switch (await api.config(etag: _etag)) {
        case Got(:final value, :final etag):
          final doc = RemoteConfigDoc.fromJson(value);
          _set(doc, etag);
          await _store.write(
            storeName,
            jsonEncode({'etag': etag, 'doc': value}),
          );
        case NotModified() || NotPublished():
          break;
      }
    } on Object catch (e) {
      debugPrint('remote config: ${e.runtimeType}');
    }
    await _updateLexicon();
  }

  Future<void> _updateLexicon() async {
    final api = _api;
    final live = _doc?.bundles[RemoteLexicon.kind];
    if (api == null || live == null || live.seq <= lexicon.activeSeq) return;
    // No key to check it with (a release build without AURA_BUNDLE_PUBLIC_KEYS),
    // or this very bundle was already refused: don't download it again.
    if (lexicon.keys.isEmpty || live.seq == lexicon.refusedSeq) return;
    try {
      switch (await api.lexicon(etag: lexicon.etag)) {
        case Got(:final value, :final etag):
          await lexicon.apply(value, etag: etag);
        case NotModified() || NotPublished():
          break;
      }
    } on Object catch (e) {
      debugPrint('lexicon: download ${e.runtimeType}');
    }
  }

  void _set(RemoteConfigDoc doc, String? etag) {
    _doc = doc;
    _etag = etag;
    if (flags.value != doc.flags) flags.value = doc.flags;
  }

  Future<void> _restore() async {
    final text = await _store.read(storeName);
    if (text == null) return;
    try {
      final saved = jsonDecode(text) as Map<String, dynamic>;
      _set(RemoteConfigDoc.fromJson(saved['doc']), saved['etag'] as String?);
    } on Object catch (e) {
      debugPrint('remote config: kept copy unreadable (${e.runtimeType})');
      await _store.delete(storeName);
    }
  }

  void _schedule() {
    _poll?.cancel();
    _poll = null;
    if (!_foreground || _disposed) return;
    _poll = Timer(Duration(seconds: pollSeconds), () {
      _poll = null;
      unawaited(refresh(force: true));
    });
  }

  /// Whether a poll is scheduled.
  bool get polling => _poll != null;

  void dispose() {
    _disposed = true;
    onBackground();
    flags.dispose();
  }
}
