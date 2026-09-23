import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/db/kv_store.dart';
import '../../core/net/aura_api.dart';
import '../../core/time/clock.dart';
import '../auth/auth_repository.dart';
import 'push_messaging.dart';

/// The user's answer on the pre-permission explainer.
enum SoftAskAnswer { allow, notNow }

/// FCM registration (sending pushes is F14).
///
/// - **Nothing at launch.** The OS prompt only follows the warm explainer,
///   which is offered only after a check-in has been saved and only until it
///   is answered once (PRD 15-permissions). FCM auto-init stays off until
///   then, so no token exists before the user opts in.
/// - "Not now" never fires the OS prompt. On iOS it registers provisional
///   authorisation (quiet delivery, no prompt).
/// - Signed in + permission + a profile on the server → FCM token (on iOS
///   after the APNs token) → `PUT /v1/devices`. Re-registers on token
///   refresh. Offline or before the profile exists, the registration is owed
///   and retried after the next successful sync.
/// - Sign-out: `DELETE /v1/devices` (best effort) + `deleteToken()`.
/// - Payloads are content-free (`{type, id?}`); only the `type` is logged, in
///   debug. Tokens are never logged.
class PushService {
  PushService({
    required this._messaging,
    required this._auth,
    required this._api,
    required this._kv,
    required this._hasProfile,
    required this._hasCheckedIn,
    this._clock = const Clock(),
    this._syncSucceeded,
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed;

  final PushMessaging? _messaging;
  final AuthRepository _auth;
  final AuraApi? _api;
  final KvStore _kv;

  /// The profile has reached the server (registration waits for it).
  final Future<bool> Function() _hasProfile;

  /// At least one check-in is saved on this phone.
  final Future<bool> Function() _hasCheckedIn;
  final Clock _clock;
  final Stream<void>? _syncSucceeded;
  final Future<void> Function(Duration) _sleep;

  static const int _apnsAttempts = 5;
  static const Duration _apnsWait = Duration(seconds: 2);
  static const Duration _netTimeout = Duration(seconds: 6);

  final List<StreamSubscription<Object?>> _subs = [];
  Future<void> _chain = Future<void>.value();

  /// Bumped by [unregister]: an in-flight registration from before a
  /// sign-out never writes its result afterwards.
  int _epoch = 0;
  bool _autoInitOn = false;
  bool _disposed = false;

  /// False when Firebase did not initialise (the app runs without push).
  bool get isAvailable => _messaging != null;

  void start() {
    final m = _messaging;
    if (m == null) return;
    _subs
      ..add(_auth.watchUser().listen((u) => unawaited(_onUser(u))))
      ..add(m.onTokenRefresh.listen((t) => unawaited(register(refreshed: t))))
      ..add(m.onMessageType.listen((t) => _logType('foreground', t)))
      ..add(m.onOpenedType.listen((t) => _logType('opened', t)));
    final synced = _syncSucceeded;
    if (synced != null) {
      _subs.add(synced.listen((_) => unawaited(_retryOwed())));
    }
  }

  // ---- soft ask ---------------------------------------------------------------

  /// Whether the explainer should be shown now: push is available, a
  /// check-in has been saved and the user has never answered.
  Future<bool> shouldOffer() async {
    if (_messaging == null || _disposed) return false;
    if (await _kv.get(KvKeys.pushSoftAsk) != null) return false;
    return _hasCheckedIn();
  }

  /// Call right after a check-in is saved. Shows [explain] (the warm
  /// explainer) at most once per account; `null` (dismissed without a choice)
  /// offers it again after the next check-in.
  Future<void> offerAfterCheckIn(
    Future<SoftAskAnswer?> Function() explain,
  ) async {
    if (!await shouldOffer()) return;
    final answer = await explain();
    if (answer == null) return;
    await _answer(answer);
  }

  Future<void> _answer(SoftAskAnswer answer) async {
    final m = _messaging;
    if (m == null) return;
    await _kv.setJson(KvKeys.pushSoftAsk, {
      'answer': answer.name,
      'at': _clock.now().toUtc().toIso8601String(),
    });
    try {
      switch (answer) {
        case SoftAskAnswer.allow:
          await m.requestPermission();
        case SoftAskAnswer.notNow:
          // The one-time iOS prompt is saved for a real yes; capsule notices
          // can still arrive quietly in Notification Center.
          if (m.supportsProvisional) await m.requestPermission(provisional: true);
      }
    } catch (e) {
      debugPrint('push: permission ${e.runtimeType}');
    }
    // Registration can wait on the APNs token; never hold the UI for it.
    unawaited(register());
  }

  // ---- registration -------------------------------------------------------------

  /// Registers this install for the signed-in account if everything is in
  /// place; otherwise records it as owed (or does nothing before the soft
  /// ask). Serialised; safe to call from any trigger.
  Future<void> register({String? refreshed}) =>
      _serial(() => _register(refreshed));

  Future<void> _register(String? refreshed) async {
    final m = _messaging;
    final api = _api;
    if (m == null || api == null || _disposed) return;
    final epoch = _epoch;
    bool stale() => epoch != _epoch || _disposed;

    final user = _auth.currentUser;
    if (user == null) return;
    if (await _kv.get(KvKeys.pushSoftAsk) == null) return;
    if (!(await m.permission()).allowsPush) return;
    if (!await _hasProfile()) return _owe(epoch);

    await _payDeleteOwed();
    if (!_autoInitOn) {
      await m.setAutoInitEnabled(true);
      _autoInitOn = true;
    }
    if (refreshed == null &&
        m.needsApnsToken &&
        await _waitForApns(m) == null) {
      // e.g. a simulator without APNs, or no network yet.
      debugPrint('push: no APNs token yet; will retry');
      return _owe(epoch);
    }
    final token = refreshed ?? await m.token();
    if (token == null || token.isEmpty) return _owe(epoch);
    if (stale()) return;

    final reg = await _registered();
    final owed = await _kv.get(KvKeys.pushPending) != null;
    if (!owed && reg != null && reg.userId == user.id && reg.token == token) {
      return;
    }
    try {
      await api.putDevice(token: token, platform: m.platform);
    } on ApiException catch (e) {
      if (e.isRetryable) return _owe(epoch);
      debugPrint('push: registration refused (${e.code})');
      if (!stale()) await _kv.set(KvKeys.pushPending, null);
      return;
    }
    if (stale()) return;
    // FCM rotated this account's token: drop the old row (best effort; F14
    // also prunes tokens FCM reports as unregistered).
    if (reg != null && reg.userId == user.id && reg.token != token) {
      try {
        await api.deleteDevice(reg.token).timeout(_netTimeout);
      } catch (e) {
        debugPrint('push: old token cleanup ${e.runtimeType}');
      }
      if (stale()) return;
    }
    await _kv.setJson(KvKeys.pushRegistered, {
      'userId': user.id,
      'token': token,
    });
    await _kv.set(KvKeys.pushPending, null);
  }

  /// Best-effort unregistration before sign-out: `DELETE /v1/devices`, then
  /// `deleteToken()` and auto-init off. Needs the session, so call it before
  /// `auth.signOut()`. Never throws.
  Future<void> unregister() async {
    _epoch++;
    final m = _messaging;
    if (m == null) return;
    try {
      final reg = await _registered();
      final api = _api;
      if (reg != null && api != null) {
        try {
          await api.deleteDevice(reg.token).timeout(_netTimeout);
        } catch (e) {
          debugPrint('push: unregister ${e.runtimeType}');
        }
      }
      if (reg != null || await _kv.get(KvKeys.pushSoftAsk) != null) {
        await _deleteLocalToken(m);
      }
      await _kv.set(KvKeys.pushRegistered, null);
      await _kv.set(KvKeys.pushPending, null);
    } catch (e) {
      debugPrint('push: unregister ${e.runtimeType}');
    }
  }

  Future<void> _onUser(AuthUser? user) async {
    if (user != null) return register();
    // Signed out elsewhere (session revoked, under-13 path): the server row
    // can't be deleted without a session, but the token can.
    if (await _registered() != null) return unregister();
    await _serial(_payDeleteOwed);
  }

  Future<void> _retryOwed() async {
    if (await _kv.get(KvKeys.pushPending) != null) await register();
  }

  Future<void> _owe(int epoch) async {
    if (epoch == _epoch && !_disposed) await _kv.set(KvKeys.pushPending, '1');
  }

  Future<String?> _waitForApns(PushMessaging m) async {
    for (var i = 0; i < _apnsAttempts; i++) {
      final t = await m.apnsToken();
      if (t != null && t.isNotEmpty) return t;
      if (i < _apnsAttempts - 1) await _sleep(_apnsWait);
    }
    return null;
  }

  Future<void> _deleteLocalToken(PushMessaging m) async {
    try {
      await m.deleteToken().timeout(_netTimeout);
      await _kv.set(KvKeys.pushDeleteOwed, null);
    } catch (e) {
      debugPrint('push: deleteToken ${e.runtimeType}; will retry');
      await _kv.set(KvKeys.pushDeleteOwed, '1');
    }
    try {
      await m.setAutoInitEnabled(false);
      _autoInitOn = false;
    } catch (_) {}
  }

  /// A token from a previous sign-out that couldn't be deleted offline.
  Future<void> _payDeleteOwed() async {
    final m = _messaging;
    if (m == null || await _kv.get(KvKeys.pushDeleteOwed) == null) return;
    await _deleteLocalToken(m);
  }

  Future<({String userId, String token})?> _registered() async {
    final j = await _kv.getJson(KvKeys.pushRegistered);
    final u = j?['userId'];
    final t = j?['token'];
    return u is String && t is String ? (userId: u, token: t) : null;
  }

  /// Completes when the work queued so far has finished (tests).
  @visibleForTesting
  Future<void> settled() => _chain;

  Future<void> _serial(Future<void> Function() body) {
    final next = _chain.then((_) async {
      try {
        await body();
      } catch (e) {
        debugPrint('push: ${e.runtimeType}');
      }
    });
    return _chain = next;
  }

  void _logType(String kind, String? type) {
    // Routing comes with F14. Never log anything but the type.
    if (kDebugMode) debugPrint('push: $kind type=$type');
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
