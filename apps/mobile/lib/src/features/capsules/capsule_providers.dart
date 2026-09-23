import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../l10n/app_localizations.dart';
import '../../core/db/database.dart';
import '../../core/env/env.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/net/aura_api.dart';
import '../../core/providers.dart';
import '../../core/security/note_cipher.dart';
import '../../core/sync/capsule_media_sync.dart';
import '../../core/sync/capsule_sync.dart';
import 'capsule_draft.dart';
import 'capsule_media_loader.dart';
import 'capsule_media_store.dart';
import 'capsule_notifications.dart';
import 'capsule_payload.dart';
import 'capsule_repository.dart';

// F4 time capsules: dependency wiring and derived state. Plain (keep-alive)
// providers; tests override the device seams (store, notices).

/// The signed-in person's data key. Without [api] only a key already in
/// Keychain/Keystore is used (no network).
Future<NoteCipher?> _cipher(Ref ref, {AuraApi? api}) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.read(dataKeyRepositoryProvider).cipherFor(user.id, api: api);
}

/// Capsule photos and voice notes on this phone (private, backup-excluded).
final capsuleMediaStoreProvider = Provider<CapsuleMediaStore>((ref) {
  final platform = ref.watch(auraPlatformProvider);
  return CapsuleMediaStore(
    root: getApplicationSupportDirectory,
    temp: getTemporaryDirectory,
    excludeFromBackup: platform.excludeFromBackup,
  );
});

/// Local-first capsules.
final capsuleRepositoryProvider = Provider<CapsuleRepository>(
  (ref) => CapsuleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(timeContextProvider),
    store: ref.watch(capsuleMediaStoreProvider),
    ids: ref.watch(idsProvider),
    cipher: () => _cipher(ref),
  ),
);

/// Capsules in the sync loop (SyncService `capsules:`): seal ciphertext,
/// media uploads, rejections and the `public.capsules` pull.
final capsuleSyncProvider = Provider<CapsuleSync>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final store = ref.watch(capsuleMediaStoreProvider);
  return CapsuleSync(
    db: db,
    outbox: ref.watch(outboxRepositoryProvider),
    kv: ref.watch(kvStoreProvider),
    // Read, not watched: a timezone change must not restart sync.
    capsules: ref.read(capsuleRepositoryProvider),
    media: CapsuleMediaSync(db: db, store: store),
    store: store,
    rows: Env.hasSupabase
        ? SupabaseCapsuleRowSource(() => sb.Supabase.instance.client)
        : null,
    clock: ref.watch(clockProvider),
  );
});

/// Opened capsules' photos and voice notes (lazy download + decrypt).
final capsuleMediaLoaderProvider = Provider<CapsuleMediaLoader>((ref) {
  final api = ref.watch(auraApiProvider);
  return CapsuleMediaLoader(
    db: ref.watch(appDatabaseProvider),
    store: ref.watch(capsuleMediaStoreProvider),
    api: api,
    cipher: ({bool fetch = false}) => _cipher(ref, api: fetch ? api : null),
    online: () => ref.read(syncControllerProvider).online.value,
    userId: () => ref.read(authRepositoryProvider).currentUser?.id,
  );
});

/// The composer's kept draft.
final capsuleDraftStoreProvider = Provider<CapsuleDraftStore>(
  (ref) => CapsuleDraftStore(ref.watch(kvStoreProvider)),
);

/// Whether a capsule draft is kept on this phone.
final capsuleHasDraftProvider = StreamProvider<bool>(
  (ref) => ref.watch(capsuleDraftStoreProvider).watchHasDraft(),
);

// ---- notices ----------------------------------------------------------------------

/// The OS notifications seam (tests override it with a fake).
final capsuleNoticePortProvider = Provider<LocalNoticePort>(
  (ref) => FlutterLocalNoticePort(),
);

final capsuleUnlockSchedulerProvider = Provider<CapsuleUnlockScheduler>(
  (ref) => CapsuleUnlockScheduler(
    db: ref.watch(appDatabaseProvider),
    kv: ref.watch(kvStoreProvider),
    port: ref.watch(capsuleNoticePortProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The notice copy in the current language (generic: never a title, date
/// or mood).
CapsuleNoticeText capsuleNoticeText(String localeTag) {
  final l = lookupAppLocalizations(localeFromTag(localeTag));
  return CapsuleNoticeText(
    body: l.capsules_readyTitle,
    channelName: l.capsules_channelName,
    channelDescription: l.capsules_channelDescription,
  );
}

/// Keeps capsule side effects in step for the session: the local "ready to
/// open" notices follow every change of the capsules table (seal, open,
/// delete, a pull from another phone, a sign-out wipe), of the device zone
/// (10:00 in the current zone) and of the language; media folders of
/// capsules that are gone are removed. Started by the first capsule
/// surface that shows (Home's card, the Sanctuary entry); keep it alive for
/// the whole session with `ref.watch(capsuleCoordinatorProvider)` in
/// `AuraApp`.
class CapsuleCoordinator {
  CapsuleCoordinator(this._ref);

  final Ref _ref;
  bool _queued = false;
  bool _disposed = false;
  Set<String>? _known;
  StreamSubscription<List<CapsuleRow>>? _sub;

  void _start() {
    final db = _ref.read(appDatabaseProvider);
    _sub = db
        .select(db.capsules)
        .watch()
        .listen(
          _onRows,
          onError: (Object e) => debugPrint('capsules: watch ${e.runtimeType}'),
        );
    unawaited(_sweep());
  }

  void _onRows(List<CapsuleRow> rows) {
    final ids = {for (final r in rows) r.id};
    final known = _known;
    _known = ids;
    // Rows that vanished entirely (a sign-out wipe): their files go too.
    if (known != null) {
      final store = _ref.read(capsuleMediaStoreProvider);
      for (final gone in known.difference(ids)) {
        unawaited(store.deleteCapsule(gone));
      }
    }
    schedule();
  }

  /// Re-plans the notices soon (coalesced; no timers).
  void schedule() {
    if (_queued || _disposed) return;
    _queued = true;
    scheduleMicrotask(() async {
      _queued = false;
      if (_disposed) return;
      try {
        await _ref
            .read(capsuleUnlockSchedulerProvider)
            .reconcile(
              tz: _ref.read(deviceTimezoneProvider),
              text: capsuleNoticeText(_ref.read(localeControllerProvider)),
            );
      } on Object catch (e) {
        debugPrint('capsules: notices ${e.runtimeType}');
      }
    });
  }

  /// Once per session: files of capsules and drafts nothing references.
  Future<void> _sweep() async {
    try {
      final db = _ref.read(appDatabaseProvider);
      final rows = await db.select(db.capsules).get();
      final draft = await _ref.read(capsuleDraftStoreProvider).keptId();
      if (_disposed) return;
      await _ref
          .read(capsuleMediaStoreProvider)
          .sweep(
            keep: {
              for (final r in rows)
                if (r.deletedAt == null) r.id,
            },
            keepDrafts: {?draft},
          );
    } on Object catch (e) {
      debugPrint('capsules: sweep ${e.runtimeType}');
    }
  }

  void _dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
  }
}

final capsuleCoordinatorProvider = Provider<CapsuleCoordinator>((ref) {
  final c = CapsuleCoordinator(ref).._start();
  ref.listen(deviceTimezoneProvider, (_, _) => c.schedule());
  ref.listen(localeControllerProvider, (_, _) => c.schedule());
  ref.onDispose(c._dispose);
  return c;
});

// ---- state for the screens ------------------------------------------------------------

/// Capsules the person can see (no tombstones), newest first.
final capsulesProvider = StreamProvider<List<CapsuleRow>>(
  (ref) => ref.watch(capsuleRepositoryProvider).watchVisible(),
);

/// One capsule (tombstones included, so a page can tell "deleted").
final capsuleProvider = StreamProvider.family<CapsuleRow?, String>(
  (ref, id) => ref.watch(capsuleRepositoryProvider).watchRow(id),
);

/// A capsule's content, decrypted in memory (`null` when this phone can't
/// read it yet).
final capsulePayloadProvider = FutureProvider.autoDispose
    .family<CapsulePayload?, CapsuleRow>(
      (ref, row) => ref.watch(capsuleRepositoryProvider).payloadOf(row),
    );

/// The instant "now" for capsule states (ticks every 30 s, so 10:00 flips a
/// date capsule to ready while the app is open).
DateTime _now(Ref ref) =>
    ref.watch(nowProvider).value ?? ref.read(timeContextProvider).now();

/// Date capsules whose 10:00 has come (in the current zone), unopened —
/// Home's card. Soonest first.
final readyDateCapsulesProvider = Provider<List<CapsuleRow>>((ref) {
  final rows = ref.watch(capsulesProvider).value ?? const <CapsuleRow>[];
  final tz = ref.watch(deviceTimezoneProvider);
  final now = _now(ref);
  return rows.where((r) => isCapsuleDue(r, tz, now)).toList()
    ..sort((a, b) => a.unlockLocalDate!.compareTo(b.unlockLocalDate!));
});

/// Every capsule that can be opened now: due date capsules and trigger
/// capsules that fired and wait unopened ("Later").
final readyCapsulesProvider = Provider<List<CapsuleRow>>((ref) {
  final rows = ref.watch(capsulesProvider).value ?? const <CapsuleRow>[];
  final tz = ref.watch(deviceTimezoneProvider);
  final now = _now(ref);
  return rows.where((r) => isCapsuleReady(r, tz, now)).toList();
});

/// How many sealed (unopened) capsules there are. The delete-account
/// confirmation says how many will be lost (PRD F4 edge cases; copy:
/// `capsules_accountDeletionCount`).
final sealedCapsuleCountProvider = StreamProvider<int>(
  (ref) => ref.watch(capsuleRepositoryProvider).watchSealedCount(),
);

/// Active trigger capsules (the Free limit is 3).
final activeTriggerCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(capsulesProvider);
  return ref.read(capsuleRepositoryProvider).activeTriggerCount();
});

// ---- sign-out ----------------------------------------------------------------------------

/// Clears everything capsule-related that lives outside the database:
/// pending notices, media files (sealed, raw, drafts, decrypted copies) and
/// decrypted content in memory. The rows themselves go with
/// `AppDatabase.wipeUserData`.
class CapsuleWiper {
  CapsuleWiper(this._ref);

  final Ref _ref;

  Future<void> wipeAll() async {
    try {
      await _ref.read(capsuleUnlockSchedulerProvider).cancelAll();
    } on Object catch (e) {
      debugPrint('capsules: wipe notices ${e.runtimeType}');
    }
    _ref.read(capsuleRepositoryProvider).forgetAll();
    await _ref.read(capsuleMediaStoreProvider).wipeAll();
  }
}

/// Sign-out / account-deletion hook:
/// `await ref.read(capsuleWiperProvider).wipeAll();` in SignOutService's
/// `wipeFiles`.
final capsuleWiperProvider = Provider<CapsuleWiper>(CapsuleWiper.new);
