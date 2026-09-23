import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/auth/auth_repository.dart';
import '../../features/checkin/checkin_repository.dart';
import '../../features/profile/profile_service.dart';
import '../../features/progress/progress_repository.dart';
import '../db/database.dart';
import '../ids/ids.dart';
import '../db/kv_store.dart';
import '../net/api_models.dart';
import '../net/aura_api.dart';
import '../security/note_cipher.dart';
import '../time/clock.dart';
import 'outbox_repository.dart';

enum SyncPhase {
  /// Everything is on the server.
  idle,
  syncing,

  /// Items wait for a retry (backoff) or for the note key.
  waiting,

  /// No network. Saving still works.
  offline,
  signedOut,

  /// This build has no API/Supabase config: everything stays on the phone.
  unavailable,
}

/// Lets writers nudge sync without depending on the whole service.
abstract interface class SyncTrigger {
  /// A local write happened: push ~2 s later (PRD Offline "2 s after a write").
  void notifyLocalWrite();
}

/// Drains the outbox to `POST /v1/sync/push`, oldest-first in batches of 50.
///
/// Triggers: start, sign-in, reconnect, app resume, 2 s after a write, and a
/// 1-minute heartbeat while items are pending. Network/5xx errors back off
/// exponentially (up to 1 h); validation rejections go to the dead-letter
/// table. Nothing here ever blocks the UI: the app works fully offline.
///
/// A `403 account_deletion_pending` (the account is in its 7-day deletion
/// grace, F8 REQ-ACC-11) holds sync for that account: nothing is dead-lettered
/// or retried until the person chooses "Keep my account" ([releaseDeletionHold])
/// or signs out / another account signs in.
class SyncService implements SyncTrigger {
  SyncService({
    required this._auth,
    required this._api,
    required this._outbox,
    required this._checkIns,
    required this._profile,
    required this._progress,
    required this._dataKeys,
    required this._kv,
    required this._clock,
    required this._ids,
    required this._connectivity,
    required this._pull,
    required this._alreadyPulled,
    required this._onUnder13,
    this._reconcileHabits,
    this._onDeletionPending,
  });

  /// The server refused a push with `403 account_deletion_pending`: the UI
  /// asks "Keep my account?" (features/account). Called once per hold.
  final void Function()? _onDeletionPending;

  /// Adopts the server's habit id when a preset exists twice (e.g. created
  /// offline on two phones) and re-queues the affected habit logs.
  final Future<void> Function()? _reconcileHabits;

  final AuthRepository _auth;
  final AuraApi? _api;
  final OutboxRepository _outbox;
  final CheckInRepository _checkIns;
  final ProfileService _profile;
  final ProgressRepository _progress;
  final DataKeyRepository _dataKeys;
  final KvStore _kv;
  final Clock _clock;
  final Ids _ids;
  final Stream<bool> _connectivity;

  /// Pulls the user's rows; must write nothing once `isCurrent()` is false
  /// (the account signed out meanwhile).
  final Future<void> Function(String userId, bool Function() isCurrent) _pull;
  final Future<bool> Function(String userId) _alreadyPulled;
  final Future<void> Function() _onUnder13;

  final ValueNotifier<SyncPhase> _phase = ValueNotifier(SyncPhase.idle);
  final ValueNotifier<bool> _online = ValueNotifier(true);

  ValueListenable<SyncPhase> get phase => _phase;
  ValueListenable<bool> get online => _online;

  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// Set by [pause] (sign-out): nothing new starts.
  bool _paused = false;

  /// The account whose deletion is pending ([ApiException.isDeletionPending]):
  /// while it is signed in nothing is pulled, flushed or pushed. Another
  /// account (or none) is never held.
  String? _heldFor;

  /// Bumped by [pause]: an in-flight drain from before it writes nothing
  /// more locally (so a signed-out account's data can't reappear after the
  /// wipe).
  int _epoch = 0;
  Completer<void>? _drained;
  Timer? _debounce;
  Timer? _retry;
  Timer? _heartbeat;
  StreamSubscription<AuthUser?>? _authSub;
  StreamSubscription<bool>? _connSub;

  void start() {
    _authSub = _auth.watchUser().listen((user) {
      if (user == null) {
        _dataKeys.forget();
        _setPhase(
          _auth.isAvailable ? SyncPhase.signedOut : SyncPhase.unavailable,
        );
      } else {
        unawaited(kick());
      }
    });
    _connSub = _connectivity.listen((isOnline) async {
      final wasOnline = _online.value;
      _online.value = isOnline;
      if (!isOnline) {
        _setPhase(SyncPhase.offline);
      } else if (!wasOnline) {
        await _outbox.resetBackoff();
        unawaited(kick());
      }
    });
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) => kick());
    unawaited(kick());
  }

  @override
  void notifyLocalWrite() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), kick);
  }

  /// App came back to the foreground.
  void onResume() => unawaited(kick());

  /// The person tapped "Sync now": items waiting out a retry backoff go
  /// too, not only the ones already due.
  Future<void> syncNow() async {
    if (_disposed || _paused) return;
    await _outbox.resetBackoff();
    await kick();
  }

  /// Sign-out: stops syncing and waits (up to [timeout]) for an in-flight
  /// drain; whatever it still receives is dropped. Call [resume] after the
  /// local data is wiped.
  Future<void> pause({Duration timeout = const Duration(seconds: 10)}) async {
    _paused = true;
    _epoch++;
    _debounce?.cancel();
    _retry?.cancel();
    if (_running) {
      final done = _drained ??= Completer<void>();
      await done.future.timeout(timeout, onTimeout: () {});
    }
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    unawaited(kick());
  }

  /// True while pushing waits for the "Keep my account?" choice.
  bool get isHeldForDeletion =>
      _heldFor != null && _heldFor == _auth.currentUser?.id;

  /// "Keep my account" succeeded (or the server no longer has a deletion
  /// scheduled): the held rows go out now.
  void releaseDeletionHold() {
    if (_heldFor == null) return;
    _heldFor = null;
    unawaited(kick());
  }

  Future<void> kick() async {
    if (_disposed || _paused) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _drain();
      } while (_again && !_disposed);
    } catch (e) {
      // Never surface sync failures to the user; log the type only.
      debugPrint('sync: ${e.runtimeType}');
      _setPhase(SyncPhase.waiting);
      _scheduleRetry(const Duration(seconds: 30));
    } finally {
      _running = false;
      _drained?.complete();
      _drained = null;
    }
  }

  Future<void> _drain() async {
    final api = _api;
    if (api == null || !_auth.isAvailable) {
      _setPhase(SyncPhase.unavailable);
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      _setPhase(SyncPhase.signedOut);
      return;
    }
    final epoch = _epoch;
    bool current() =>
        epoch == _epoch && !_disposed && _auth.currentUser?.id == user.id;
    if (!_online.value) {
      _setPhase(SyncPhase.offline);
      return;
    }
    if (_heldFor != null) {
      if (_heldFor == user.id) {
        // Deletion pending: the server writes nothing for this account.
        _setPhase(SyncPhase.waiting);
        return;
      }
      _heldFor = null; // a different account signed in
    }
    _setPhase(SyncPhase.syncing);

    // 1. First sign-in on this install: pull own rows (Supabase reads only,
    //    so a new phone restores even while the API is unreachable).
    if (!await _alreadyPulled(user.id)) {
      try {
        await _pull(user.id, current);
      } catch (e) {
        debugPrint('pull: ${e.runtimeType}');
      }
      if (!current()) return;
    }

    // 2. The profile must exist before personal writes.
    switch (await _profile.flush(api)) {
      case ProfileFlush.under13:
        await _onUnder13();
        return;
      case ProfileFlush.retryLater:
        _setPhase(SyncPhase.waiting);
        _scheduleRetry(const Duration(seconds: 30));
        return;
      case ProfileFlush.nothingPending ||
          ProfileFlush.saved ||
          ProfileFlush.failed ||
          ProfileFlush.deferred:
        break;
    }
    if (!current()) return;

    // 3. Push.
    final deviceId = await _deviceId();
    final skipped = <int>{};
    var reconcile = false;
    while (!_disposed) {
      if (!current()) return;
      final due = await _outbox.due(
        _clock.now(),
        limit: OutboxRepository.batchSize + skipped.length,
      );
      final rows = due
          .where((r) => !skipped.contains(r.seq))
          .take(OutboxRepository.batchSize)
          .toList();
      if (rows.isEmpty) break;

      final ready = <OutboxRow>[];
      final mutations = <SyncMutation>[];
      NoteCipher? cipher;
      var cipherTried = false;
      for (final r in rows) {
        final payload = jsonDecode(r.payload) as Map<String, dynamic>;
        if (r.needsNote) {
          if (!cipherTried) {
            cipher = await _dataKeys.cipherFor(user.id, api: api);
            cipherTried = true;
          }
          if (cipher == null) {
            skipped.add(r.seq); // wait for the data key; never send plaintext
            continue;
          }
          final note = await _checkIns.noteOf(r.entityId);
          payload['noteCt'] = note == null
              ? null
              : await cipher.encrypt(note, recordId: r.entityId);
        }
        ready.add(r);
        mutations.add(
          SyncMutation(
            id: r.mutationId,
            entity: r.entity,
            op: r.op,
            deviceTs: r.deviceTs.toUtc().toIso8601String(),
            localDay: r.localDay,
            payload: payload,
            tz: r.tz,
          ),
        );
      }
      if (ready.isEmpty) break;

      final PushResponse res;
      try {
        res = await api.push(deviceId: deviceId, mutations: mutations);
      } on ApiException catch (e) {
        if (!current()) return;
        if (e.isDeletionPending) {
          // The account is in its deletion grace period: keep every row as
          // it is (no backoff, no dead letter) and stop until the person
          // decides. Retrying would only be refused again.
          _heldFor = user.id;
          _retry?.cancel();
          _setPhase(SyncPhase.waiting);
          _onDeletionPending?.call();
          return;
        }
        // A request-level error says nothing about the rows: they are never
        // dead-lettered for it (only per-mutation `rejected` results are).
        final now = _clock.now();
        if (e.isRetryable) {
          await _outbox.backoff(ready, now, deadLetter: false);
          _setPhase(e.isNetwork ? SyncPhase.offline : SyncPhase.waiting);
        } else if (e.code == 'profile_required') {
          // The server has no profile (its POST was lost or refused):
          // re-queue it; these rows go again once it is in.
          await _profile.markDirty(resetBackoff: false);
          await _outbox.backoff(ready, now, deadLetter: false);
          _setPhase(SyncPhase.waiting);
        } else {
          // Any other refusal of the whole batch (400 invalid_request, …):
          // keep the rows and try much later (e.g. after an app update).
          debugPrint('sync: push refused (${e.code})');
          await _outbox.backoff(
            ready,
            now,
            deadLetter: false,
            minWait: OutboxRepository.maxBackoff,
          );
          _setPhase(SyncPhase.waiting);
        }
        await _scheduleNextRetry();
        return;
      }
      if (!current()) return;

      final byId = {for (final r in res.results) r.id.toLowerCase(): r};
      final acked = <OutboxRow>[];
      final missing = <OutboxRow>[];
      for (final row in ready) {
        final r = byId[row.mutationId.toLowerCase()];
        if (r == null) {
          missing.add(row);
        } else if (r.status == 'applied' || r.status == 'duplicate') {
          acked.add(row);
        } else {
          debugPrint('sync: rejected ${row.entity}/${row.op} (${r.reason})');
          await _outbox.reject([row], r.reason ?? 'rejected', _clock.now());
          if (r.reason == 'duplicate_preset_habit') reconcile = true;
        }
      }
      await _outbox.acknowledge(acked);
      if (missing.isNotEmpty) await _outbox.backoff(missing, _clock.now());
      final snapshot = res.snapshot;
      if (snapshot != null) await _progress.saveSnapshot(snapshot);
      if (reconcile && _reconcileHabits != null) {
        reconcile = false;
        try {
          await _reconcileHabits();
        } catch (e) {
          debugPrint('sync: reconcile ${e.runtimeType}');
        }
      }
    }

    final remaining = await _outbox.count();
    if (remaining == 0) {
      _setPhase(SyncPhase.idle);
    } else {
      _setPhase(SyncPhase.waiting);
      await _scheduleNextRetry();
    }
  }

  Future<String> _deviceId() async {
    final existing = await _kv.get(KvKeys.deviceId);
    if (existing != null) return existing;
    final id = _ids.v7();
    await _kv.set(KvKeys.deviceId, id);
    return id;
  }

  Future<void> _scheduleNextRetry() async {
    final next = await _outbox.nextRetryAt();
    final wait = next == null
        ? const Duration(seconds: 30)
        : next.difference(_clock.now());
    _scheduleRetry(
      wait < const Duration(seconds: 2) ? const Duration(seconds: 2) : wait,
    );
  }

  void _scheduleRetry(Duration wait) {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(wait, kick);
  }

  void _setPhase(SyncPhase p) {
    if (!_disposed) _phase.value = p;
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
    _heartbeat?.cancel();
    await _authSub?.cancel();
    await _connSub?.cancel();
    _phase.dispose();
    _online.dispose();
  }
}
