import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../features/account/account_providers.dart';
import '../features/auth/account_closed.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/sign_out_service.dart';
import '../features/avatar/moments_controller.dart';
import '../features/capsules/capsule_providers.dart';
import '../features/checkin/checkin_repository.dart';
import '../features/habits/habit_repository.dart';
import '../features/orbit_loom/constellation_repository.dart';
import '../features/onboarding/gate_controller.dart';
import '../features/profile/profile_service.dart';
import '../features/progress/progress_repository.dart';
import '../features/push/push_messaging.dart';
import '../features/push/push_service.dart';
import '../features/voice/voice_devices.dart';
import '../features/voice/voice_loader.dart';
import '../features/voice/voice_store.dart';
import 'db/database.dart';
import 'db/kv_store.dart';
import 'env/env.dart';
import 'ids/ids.dart';
import 'net/aura_api.dart';
import 'remote_config/device_ban.dart';
import 'remote_config/remote_config_providers.dart';
import 'security/note_cipher.dart';
import 'security/secure_store.dart';
import 'sync/media_sync.dart';
import 'sync/outbox_repository.dart';
import 'sync/pull_service.dart';
import 'sync/sync_service.dart';
import 'time/clock.dart';
import 'time/device_timezone.dart';

part 'providers.g.dart';

// ---- roots (overridden in main / tests) -----------------------------------

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) =>
    throw UnimplementedError('appDatabaseProvider is overridden in main()');

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) =>
    throw UnimplementedError('secureStoreProvider is overridden in main()');

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const Clock();

/// The device zone resolved before the first frame (main.dart).
@Riverpod(keepAlive: true)
String initialTimezone(Ref ref) => 'UTC';

/// The resolved device IANA zone. Re-checked at start and on resume
/// (travel); every new record is stamped in it.
@Riverpod(keepAlive: true)
class DeviceTimezone extends _$DeviceTimezone {
  @override
  String build() => ref.read(initialTimezoneProvider);

  void set(String zone) {
    if (zone != state) state = zone;
  }
}

/// Resolves the device zone (tests override this).
@Riverpod(keepAlive: true)
Future<String> Function() timezoneResolver(Ref ref) => resolveDeviceTimezone;

@Riverpod(keepAlive: true)
TimeContext timeContext(Ref ref) => TimeContext(
  clock: ref.watch(clockProvider),
  timezone: ref.watch(deviceTimezoneProvider),
);

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  if (!Env.hasSupabase) return const UnavailableAuthRepository();
  try {
    return SupabaseAuthRepository(
      sb.Supabase.instance.client,
      // App Review's fixed-code account (docs/setup/app-review.md).
      reviewSignIn: Env.hasApi
          ? HttpReviewSignInApi(baseUrl: Env.apiUrl)
          : null,
    );
  } on Object {
    return const UnavailableAuthRepository();
  }
}

/// `true` while the device has a network interface up.
@Riverpod(keepAlive: true)
Stream<bool> connectivity(Ref ref) async* {
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  final c = Connectivity();
  try {
    yield online(await c.checkConnectivity());
  } on Object {
    yield true;
  }
  yield* c.onConnectivityChanged.map(online);
}

@Riverpod(keepAlive: true)
Ids ids(Ref ref) => const Ids();

/// Device region (ISO country) from the OS locale, never IP or GPS.
@Riverpod(keepAlive: true)
String? deviceRegion(Ref ref) =>
    PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

// ---- repositories ------------------------------------------------------------

@Riverpod(keepAlive: true)
KvStore kvStore(Ref ref) => KvStore(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
OutboxRepository outboxRepository(Ref ref) =>
    OutboxRepository(ref.watch(appDatabaseProvider), ref.watch(idsProvider));

@Riverpod(keepAlive: true)
CheckInRepository checkInRepository(Ref ref) => CheckInRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(outboxRepositoryProvider),
  ref.watch(timeContextProvider),
  voice: ref.watch(voiceStoreProvider),
  // Seal a new recording at once when the key is already on this phone.
  cipher: () => _signedInCipher(ref),
);

/// The signed-in person's data key. Without [api] only a key already in
/// Keychain/Keystore is used (no network).
Future<NoteCipher?> _signedInCipher(Ref ref, {AuraApi? api}) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return ref.read(dataKeyRepositoryProvider).cipherFor(user.id, api: api);
}

// ---- voice notes (F1) --------------------------------------------------------

/// App ↔ OS glue: Settings deep link, iOS backup exclusion.
@Riverpod(keepAlive: true)
AuraPlatform auraPlatform(Ref ref) => const ChannelAuraPlatform();

/// Voice files in the app's private, backup-excluded directory. Nothing
/// touches the disk until the first voice operation.
@Riverpod(keepAlive: true)
VoiceStore voiceStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final platform = ref.watch(auraPlatformProvider);
  return VoiceStore(
    root: getApplicationSupportDirectory,
    temp: getTemporaryDirectory,
    excludeFromBackup: platform.excludeFromBackup,
    referenced: () => referencedVoiceFiles(db),
  );
}

/// Creates the microphone recorder (the plugin starts on the first mic tap).
@Riverpod(keepAlive: true)
VoiceRecorder Function() voiceRecorderFactory(Ref ref) =>
    RecordVoiceRecorder.new;

/// Creates an audio player (the plugin starts on the first play).
@Riverpod(keepAlive: true)
VoicePlayer Function() voicePlayerFactory(Ref ref) =>
    AudioplayersVoicePlayer.new;

/// Finds a check-in's voice note for playback (local copy or lazy download).
@Riverpod(keepAlive: true)
VoiceLoader voiceLoader(Ref ref) {
  final api = ref.watch(auraApiProvider);
  return VoiceLoader(
    store: ref.watch(voiceStoreProvider),
    api: api,
    cipher: ({bool fetch = false}) =>
        _signedInCipher(ref, api: fetch ? api : null),
    online: () => ref.read(syncControllerProvider).online.value,
  );
}

@Riverpod(keepAlive: true)
HabitRepository habitRepository(Ref ref) => HabitRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(outboxRepositoryProvider),
  ref.watch(timeContextProvider),
  ref.watch(idsProvider),
);

@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) => ProgressRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(kvStoreProvider),
);

@Riverpod(keepAlive: true)
DataKeyRepository dataKeyRepository(Ref ref) =>
    DataKeyRepository(ref.watch(secureStoreProvider));

@Riverpod(keepAlive: true)
ProfileService profileService(Ref ref) {
  final service = ProfileService(
    kv: ref.watch(kvStoreProvider),
    timezone: () => ref.read(timeContextProvider).timezone,
    progress: ref.watch(progressRepositoryProvider),
    country: () => ref.read(deviceRegionProvider),
    // 403 account_deletion_pending on POST /v1/profile: hold, ask
    // "Keep my account?" (same hold as sync).
    onDeletionPending: () =>
        unawaited(ref.read(deletionHoldProvider.notifier).reportFromSync()),
  );
  ref.listen(deletionHoldProvider, (prev, next) {
    if (prev != null && next == null) service.releaseDeletionHold();
  });
  return service;
}

@Riverpod(keepAlive: true)
AuraApi? auraApi(Ref ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  final install = ref.watch(installIdProvider);
  return AuraApi(
    baseUrl: Env.apiUrl,
    accessToken: auth.accessToken,
    // Signed Storage URLs are rewritten to this build's Supabase host when
    // the API signed a loopback one (Android emulator / LAN device).
    supabaseUrl: Env.supabaseUrl,
    // 403 account_closed from any call: the calm "This account is closed"
    // screen (features/auth/account_closed.dart).
    onAccountClosed: () {
      if (ref.mounted) ref.read(accountClosedProvider.notifier).report();
    },
    // REQ-ADM-14: this install's id on the profile and push registration;
    // 403 device_banned → the calm "This device can't use Aura" screen
    // (core/remote_config/device_ban.dart).
    deviceHeaders: install.headers,
    onDeviceBanned: () {
      if (ref.mounted) ref.read(deviceBannedProvider.notifier).report();
    },
  );
}

// ---- sync --------------------------------------------------------------------

/// What the UI needs from sync (tests override this with a quiet fake).
abstract interface class SyncController implements SyncTrigger {
  ValueListenable<SyncPhase> get phase;
  ValueListenable<bool> get online;
  void onResume();

  /// "Sync now" from the sync status sheet: pushes everything pending,
  /// ignoring retry backoff.
  void syncNow();

  /// Sign-out: stop syncing (and wait for an in-flight drain) until [resume].
  Future<void> pause();
  void resume();

  /// Background runs (F11 widget refresh): push what is due and wait for it,
  /// at most [timeout].
  Future<void> drain({Duration timeout});
}

class _ServiceController implements SyncController {
  _ServiceController(this._s);
  final SyncService _s;

  @override
  ValueListenable<SyncPhase> get phase => _s.phase;
  @override
  ValueListenable<bool> get online => _s.online;
  @override
  void notifyLocalWrite() => _s.notifyLocalWrite();
  @override
  void onResume() => _s.onResume();
  @override
  void syncNow() => unawaited(_s.syncNow());
  @override
  Future<void> pause() => _s.pause();
  @override
  void resume() => _s.resume();
  @override
  Future<void> drain({Duration timeout = const Duration(seconds: 20)}) =>
      _s.drainNow(timeout: timeout);
}

@Riverpod(keepAlive: true)
SyncController syncController(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  final api = ref.watch(auraApiProvider);
  final kv = ref.watch(kvStoreProvider);
  final progress = ref.watch(progressRepositoryProvider);
  final dataKeys = ref.watch(dataKeyRepositoryProvider);
  final pull = PullService(
    db: ref.watch(appDatabaseProvider),
    kv: kv,
    progress: progress,
    dataKeys: dataKeys,
  );
  final connectivity = StreamController<bool>();
  ref.listen(connectivityProvider, (_, next) {
    final v = next.value;
    if (v != null) connectivity.add(v);
  }, fireImmediately: true);

  final db = ref.watch(appDatabaseProvider);
  final service = SyncService(
    auth: auth,
    api: api,
    outbox: ref.watch(outboxRepositoryProvider),
    // Read, not watched: a timezone change must not restart sync.
    checkIns: ref.read(checkInRepositoryProvider),
    profile: ref.watch(profileServiceProvider),
    progress: progress,
    dataKeys: dataKeys,
    kv: kv,
    clock: ref.watch(clockProvider),
    ids: ref.watch(idsProvider),
    connectivity: connectivity.stream,
    alreadyPulled: pull.alreadyPulled,
    pull: (userId, isCurrent) async {
      if (api == null) return;
      await pull.pullAll(
        client: sb.Supabase.instance.client,
        userId: userId,
        api: api,
        isCurrent: isCurrent,
      );
    },
    deltaPull: (userId, isCurrent) async {
      if (api == null || !Env.hasSupabase) return;
      await pull.pullDelta(
        client: sb.Supabase.instance.client,
        userId: userId,
        api: api,
        isCurrent: isCurrent,
      );
    },
    reconcileHabits: () async {
      if (!Env.hasSupabase) return;
      await pull.reconcilePresetHabits(sb.Supabase.instance.client);
    },
    onCommitmentRejected: (habitId, reason) => ref
        .read(habitRepositoryProvider)
        .clearRejectedCommitment(habitId, reason),
    onConstellationRejected: (id) =>
        ref.read(constellationRepositoryProvider).dropRejected(id),
    onUnder13: () async {
      await ref.read(gateControllerProvider.notifier).blockUnder13();
      await auth.signOut();
    },
    // 403 account_deletion_pending: hold, and ask "Keep my account?".
    onDeletionPending: () =>
        unawaited(ref.read(deletionHoldProvider.notifier).reportFromSync()),
    // Voice notes upload before their check-in is pushed.
    media: MediaSync(
      db: db,
      checkIns: ref.read(checkInRepositoryProvider),
      store: ref.watch(voiceStoreProvider),
    ),
    // F4 capsules: seal ciphertext + media first, rejections, media
    // retries and the public.capsules pull (features/capsules).
    capsules: ref.read(capsuleSyncProvider),
  )..start();
  // "Keep my account" (or a sign-out) clears the hold: push again.
  ref.listen(deletionHoldProvider, (prev, next) {
    if (prev != null && next == null) {
      service.releaseDeletionHold();
      // A held profile goes out now too, even when no push was held.
      unawaited(service.kick());
    }
  });
  ref.onDispose(() {
    unawaited(service.dispose());
    unawaited(connectivity.close());
  });
  return _ServiceController(service);
}

// ---- push & sign-out ---------------------------------------------------------

/// The FCM adapter, or `null` when Firebase did not initialise (main.dart
/// overrides it). Push is then simply off; the app works fully without it.
@Riverpod(keepAlive: true)
PushMessaging? pushMessaging(Ref ref) => null;

@Riverpod(keepAlive: true)
PushService pushService(Ref ref) {
  final sync = ref.watch(syncControllerProvider);
  final profile = ref.watch(profileServiceProvider);
  // Owed registrations retry after the next successful sync.
  final synced = StreamController<void>.broadcast();
  void onPhase() {
    if (sync.phase.value == SyncPhase.idle) synced.add(null);
  }

  sync.phase.addListener(onPhase);
  final service = PushService(
    messaging: ref.watch(pushMessagingProvider),
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(auraApiProvider),
    kv: ref.watch(kvStoreProvider),
    hasProfile: profile.isOnServer,
    // Read, not watched: a timezone change must not restart push.
    hasCheckedIn: ref.read(checkInRepositoryProvider).any,
    clock: ref.watch(clockProvider),
    syncSucceeded: synced.stream,
  )..start();
  ref.onDispose(() {
    try {
      sync.phase.removeListener(onPhase);
    } on Object {
      // The sync controller was disposed first.
    }
    unawaited(service.dispose());
    unawaited(synced.close());
  });
  return service;
}

@Riverpod(keepAlive: true)
SignOutService signOutService(Ref ref) => SignOutService(
  auth: ref.watch(authRepositoryProvider),
  db: ref.watch(appDatabaseProvider),
  secure: ref.watch(secureStoreProvider),
  dataKeys: ref.watch(dataKeyRepositoryProvider),
  unregisterPush: () => ref.read(pushServiceProvider).unregister(),
  pauseSync: () => ref.read(syncControllerProvider).pause(),
  resumeSync: () => ref.read(syncControllerProvider).resume(),
  // Every voice file (saved, raw, drafts, decrypted temp copies) and every
  // capsule file (media, drafts, scheduled notices, decrypted copies). The
  // capsule wipe runs even if the voice wipe fails.
  wipeFiles: () async {
    try {
      await ref.read(voiceStoreProvider).wipe();
    } finally {
      await ref.read(capsuleWiperProvider).wipeAll();
    }
  },
  afterWipe: () async {
    await ref
        .read(gateControllerProvider.notifier)
        .goTo(OnboardingStage.welcome);
    ref.invalidate(momentsControllerProvider);
  },
);

@Riverpod(keepAlive: true)
Stream<int> pendingCount(Ref ref) =>
    ref.watch(outboxRepositoryProvider).watchCount();

@Riverpod(keepAlive: true)
Stream<AuthUser?> authUser(Ref ref) =>
    ref.watch(authRepositoryProvider).watchUser();

/// Ticks every 30 s so the Aura day rolls over at 04:00 without a restart.
@Riverpod(keepAlive: true)
Stream<DateTime> now(Ref ref) async* {
  final time = ref.watch(timeContextProvider);
  yield time.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => time.now());
}
