// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'3dfca92a71f809b6497fae6d72d67549ac7c0cdc';

@ProviderFor(secureStore)
final secureStoreProvider = SecureStoreProvider._();

final class SecureStoreProvider
    extends $FunctionalProvider<SecureStore, SecureStore, SecureStore>
    with $Provider<SecureStore> {
  SecureStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStoreHash();

  @$internal
  @override
  $ProviderElement<SecureStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureStore create(Ref ref) {
    return secureStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureStore>(value),
    );
  }
}

String _$secureStoreHash() => r'50ed44bc61878d7168ee3020081196cc8f4e161f';

@ProviderFor(clock)
final clockProvider = ClockProvider._();

final class ClockProvider extends $FunctionalProvider<Clock, Clock, Clock>
    with $Provider<Clock> {
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<Clock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Clock create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Clock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Clock>(value),
    );
  }
}

String _$clockHash() => r'30e71d378a201482bb785bc8babd9bfcb65538f7';

/// The device zone resolved before the first frame (main.dart).

@ProviderFor(initialTimezone)
final initialTimezoneProvider = InitialTimezoneProvider._();

/// The device zone resolved before the first frame (main.dart).

final class InitialTimezoneProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The device zone resolved before the first frame (main.dart).
  InitialTimezoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialTimezoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialTimezoneHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return initialTimezone(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$initialTimezoneHash() => r'60c03561803582ab7b4720960da9285983562be3';

/// The resolved device IANA zone. Re-checked at start and on resume
/// (travel); every new record is stamped in it.

@ProviderFor(DeviceTimezone)
final deviceTimezoneProvider = DeviceTimezoneProvider._();

/// The resolved device IANA zone. Re-checked at start and on resume
/// (travel); every new record is stamped in it.
final class DeviceTimezoneProvider
    extends $NotifierProvider<DeviceTimezone, String> {
  /// The resolved device IANA zone. Re-checked at start and on resume
  /// (travel); every new record is stamped in it.
  DeviceTimezoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceTimezoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceTimezoneHash();

  @$internal
  @override
  DeviceTimezone create() => DeviceTimezone();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$deviceTimezoneHash() => r'08f9aa1c116e2f4012c91737c3de4a2866c91ce5';

/// The resolved device IANA zone. Re-checked at start and on resume
/// (travel); every new record is stamped in it.

abstract class _$DeviceTimezone extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Resolves the device zone (tests override this).

@ProviderFor(timezoneResolver)
final timezoneResolverProvider = TimezoneResolverProvider._();

/// Resolves the device zone (tests override this).

final class TimezoneResolverProvider
    extends
        $FunctionalProvider<
          Future<String> Function(),
          Future<String> Function(),
          Future<String> Function()
        >
    with $Provider<Future<String> Function()> {
  /// Resolves the device zone (tests override this).
  TimezoneResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timezoneResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timezoneResolverHash();

  @$internal
  @override
  $ProviderElement<Future<String> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<String> Function() create(Ref ref) {
    return timezoneResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<String> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<String> Function()>(value),
    );
  }
}

String _$timezoneResolverHash() => r'f0b282d8a7b31f61111733f1c54211fb29cb4d3d';

@ProviderFor(timeContext)
final timeContextProvider = TimeContextProvider._();

final class TimeContextProvider
    extends $FunctionalProvider<TimeContext, TimeContext, TimeContext>
    with $Provider<TimeContext> {
  TimeContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeContextHash();

  @$internal
  @override
  $ProviderElement<TimeContext> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TimeContext create(Ref ref) {
    return timeContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeContext value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeContext>(value),
    );
  }
}

String _$timeContextHash() => r'3533c8453d754b0154f4f811dbfbaa2569cba56e';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'33cc0cf9084cd2a26036e21f98ffc3b033140f86';

/// `true` while the device has a network interface up.

@ProviderFor(connectivity)
final connectivityProvider = ConnectivityProvider._();

/// `true` while the device has a network interface up.

final class ConnectivityProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// `true` while the device has a network interface up.
  ConnectivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return connectivity(ref);
  }
}

String _$connectivityHash() => r'3f79a06dd26de6794a0112daa540a7e672447c21';

@ProviderFor(ids)
final idsProvider = IdsProvider._();

final class IdsProvider extends $FunctionalProvider<Ids, Ids, Ids>
    with $Provider<Ids> {
  IdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idsHash();

  @$internal
  @override
  $ProviderElement<Ids> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Ids create(Ref ref) {
    return ids(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Ids value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Ids>(value),
    );
  }
}

String _$idsHash() => r'bf8f60696c47235e3ab775c94e82562b9ec4f25d';

/// Device region (ISO country) from the OS locale, never IP or GPS.

@ProviderFor(deviceRegion)
final deviceRegionProvider = DeviceRegionProvider._();

/// Device region (ISO country) from the OS locale, never IP or GPS.

final class DeviceRegionProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Device region (ISO country) from the OS locale, never IP or GPS.
  DeviceRegionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceRegionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceRegionHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return deviceRegion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$deviceRegionHash() => r'2df83c3d8812bb60c4438765cc4bb4ca6c23e3b5';

@ProviderFor(kvStore)
final kvStoreProvider = KvStoreProvider._();

final class KvStoreProvider
    extends $FunctionalProvider<KvStore, KvStore, KvStore>
    with $Provider<KvStore> {
  KvStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kvStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kvStoreHash();

  @$internal
  @override
  $ProviderElement<KvStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KvStore create(Ref ref) {
    return kvStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KvStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KvStore>(value),
    );
  }
}

String _$kvStoreHash() => r'983fd246a981fc68943695f8807645ba03f64685';

@ProviderFor(outboxRepository)
final outboxRepositoryProvider = OutboxRepositoryProvider._();

final class OutboxRepositoryProvider
    extends
        $FunctionalProvider<
          OutboxRepository,
          OutboxRepository,
          OutboxRepository
        >
    with $Provider<OutboxRepository> {
  OutboxRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxRepositoryHash();

  @$internal
  @override
  $ProviderElement<OutboxRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OutboxRepository create(Ref ref) {
    return outboxRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutboxRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutboxRepository>(value),
    );
  }
}

String _$outboxRepositoryHash() => r'f8fda0aa179ae99a70414b8251c387358ce0d956';

@ProviderFor(checkInRepository)
final checkInRepositoryProvider = CheckInRepositoryProvider._();

final class CheckInRepositoryProvider
    extends
        $FunctionalProvider<
          CheckInRepository,
          CheckInRepository,
          CheckInRepository
        >
    with $Provider<CheckInRepository> {
  CheckInRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkInRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkInRepositoryHash();

  @$internal
  @override
  $ProviderElement<CheckInRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CheckInRepository create(Ref ref) {
    return checkInRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckInRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckInRepository>(value),
    );
  }
}

String _$checkInRepositoryHash() => r'141da8af8f19073be47cae8ecdf1f3828d5f0025';

/// App ↔ OS glue: Settings deep link, iOS backup exclusion.

@ProviderFor(auraPlatform)
final auraPlatformProvider = AuraPlatformProvider._();

/// App ↔ OS glue: Settings deep link, iOS backup exclusion.

final class AuraPlatformProvider
    extends $FunctionalProvider<AuraPlatform, AuraPlatform, AuraPlatform>
    with $Provider<AuraPlatform> {
  /// App ↔ OS glue: Settings deep link, iOS backup exclusion.
  AuraPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'auraPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$auraPlatformHash();

  @$internal
  @override
  $ProviderElement<AuraPlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuraPlatform create(Ref ref) {
    return auraPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuraPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuraPlatform>(value),
    );
  }
}

String _$auraPlatformHash() => r'9883a32aee3545a20e94a0bdc00cc8a99d8d1827';

/// Voice files in the app's private, backup-excluded directory. Nothing
/// touches the disk until the first voice operation.

@ProviderFor(voiceStore)
final voiceStoreProvider = VoiceStoreProvider._();

/// Voice files in the app's private, backup-excluded directory. Nothing
/// touches the disk until the first voice operation.

final class VoiceStoreProvider
    extends $FunctionalProvider<VoiceStore, VoiceStore, VoiceStore>
    with $Provider<VoiceStore> {
  /// Voice files in the app's private, backup-excluded directory. Nothing
  /// touches the disk until the first voice operation.
  VoiceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceStoreHash();

  @$internal
  @override
  $ProviderElement<VoiceStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoiceStore create(Ref ref) {
    return voiceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceStore>(value),
    );
  }
}

String _$voiceStoreHash() => r'e8485050e342832b7234c951548c12b69feae65e';

/// Creates the microphone recorder (the plugin starts on the first mic tap).

@ProviderFor(voiceRecorderFactory)
final voiceRecorderFactoryProvider = VoiceRecorderFactoryProvider._();

/// Creates the microphone recorder (the plugin starts on the first mic tap).

final class VoiceRecorderFactoryProvider
    extends
        $FunctionalProvider<
          VoiceRecorder Function(),
          VoiceRecorder Function(),
          VoiceRecorder Function()
        >
    with $Provider<VoiceRecorder Function()> {
  /// Creates the microphone recorder (the plugin starts on the first mic tap).
  VoiceRecorderFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceRecorderFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceRecorderFactoryHash();

  @$internal
  @override
  $ProviderElement<VoiceRecorder Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VoiceRecorder Function() create(Ref ref) {
    return voiceRecorderFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceRecorder Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceRecorder Function()>(value),
    );
  }
}

String _$voiceRecorderFactoryHash() =>
    r'301decc320adb60f2b927b8c3994495ddb3d5b32';

/// Creates an audio player (the plugin starts on the first play).

@ProviderFor(voicePlayerFactory)
final voicePlayerFactoryProvider = VoicePlayerFactoryProvider._();

/// Creates an audio player (the plugin starts on the first play).

final class VoicePlayerFactoryProvider
    extends
        $FunctionalProvider<
          VoicePlayer Function(),
          VoicePlayer Function(),
          VoicePlayer Function()
        >
    with $Provider<VoicePlayer Function()> {
  /// Creates an audio player (the plugin starts on the first play).
  VoicePlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voicePlayerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voicePlayerFactoryHash();

  @$internal
  @override
  $ProviderElement<VoicePlayer Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VoicePlayer Function() create(Ref ref) {
    return voicePlayerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoicePlayer Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoicePlayer Function()>(value),
    );
  }
}

String _$voicePlayerFactoryHash() =>
    r'7f5a6b3d7ed7ff0afc07e73268fb4e65a779955a';

/// Finds a check-in's voice note for playback (local copy or lazy download).

@ProviderFor(voiceLoader)
final voiceLoaderProvider = VoiceLoaderProvider._();

/// Finds a check-in's voice note for playback (local copy or lazy download).

final class VoiceLoaderProvider
    extends $FunctionalProvider<VoiceLoader, VoiceLoader, VoiceLoader>
    with $Provider<VoiceLoader> {
  /// Finds a check-in's voice note for playback (local copy or lazy download).
  VoiceLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceLoaderHash();

  @$internal
  @override
  $ProviderElement<VoiceLoader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoiceLoader create(Ref ref) {
    return voiceLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceLoader>(value),
    );
  }
}

String _$voiceLoaderHash() => r'b5dd0aa6282a71576d063fd998e1e4675b97ea3f';

@ProviderFor(habitRepository)
final habitRepositoryProvider = HabitRepositoryProvider._();

final class HabitRepositoryProvider
    extends
        $FunctionalProvider<HabitRepository, HabitRepository, HabitRepository>
    with $Provider<HabitRepository> {
  HabitRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitRepositoryHash();

  @$internal
  @override
  $ProviderElement<HabitRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HabitRepository create(Ref ref) {
    return habitRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitRepository>(value),
    );
  }
}

String _$habitRepositoryHash() => r'fb41b1fed519663485a336d6ba9f54dd304931fe';

@ProviderFor(progressRepository)
final progressRepositoryProvider = ProgressRepositoryProvider._();

final class ProgressRepositoryProvider
    extends
        $FunctionalProvider<
          ProgressRepository,
          ProgressRepository,
          ProgressRepository
        >
    with $Provider<ProgressRepository> {
  ProgressRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProgressRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProgressRepository create(Ref ref) {
    return progressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressRepository>(value),
    );
  }
}

String _$progressRepositoryHash() =>
    r'fccd9c7e4e2a3b42abe8370d2b142a79a19393a0';

@ProviderFor(dataKeyRepository)
final dataKeyRepositoryProvider = DataKeyRepositoryProvider._();

final class DataKeyRepositoryProvider
    extends
        $FunctionalProvider<
          DataKeyRepository,
          DataKeyRepository,
          DataKeyRepository
        >
    with $Provider<DataKeyRepository> {
  DataKeyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataKeyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataKeyRepositoryHash();

  @$internal
  @override
  $ProviderElement<DataKeyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DataKeyRepository create(Ref ref) {
    return dataKeyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataKeyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataKeyRepository>(value),
    );
  }
}

String _$dataKeyRepositoryHash() => r'e4e1064a6f89316949446cf61d01356ca09830ff';

@ProviderFor(profileService)
final profileServiceProvider = ProfileServiceProvider._();

final class ProfileServiceProvider
    extends $FunctionalProvider<ProfileService, ProfileService, ProfileService>
    with $Provider<ProfileService> {
  ProfileServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileServiceHash();

  @$internal
  @override
  $ProviderElement<ProfileService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileService create(Ref ref) {
    return profileService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileService>(value),
    );
  }
}

String _$profileServiceHash() => r'67b8d9f3a375f26f730b602646b52685ac5713bc';

@ProviderFor(auraApi)
final auraApiProvider = AuraApiProvider._();

final class AuraApiProvider
    extends $FunctionalProvider<AuraApi?, AuraApi?, AuraApi?>
    with $Provider<AuraApi?> {
  AuraApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'auraApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$auraApiHash();

  @$internal
  @override
  $ProviderElement<AuraApi?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuraApi? create(Ref ref) {
    return auraApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuraApi? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuraApi?>(value),
    );
  }
}

String _$auraApiHash() => r'e7caffebe76bd91dcac9a7872bdddd29bfddc7fb';

@ProviderFor(syncController)
final syncControllerProvider = SyncControllerProvider._();

final class SyncControllerProvider
    extends $FunctionalProvider<SyncController, SyncController, SyncController>
    with $Provider<SyncController> {
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  $ProviderElement<SyncController> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncController create(Ref ref) {
    return syncController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncController>(value),
    );
  }
}

String _$syncControllerHash() => r'bd86eece9b3ba50ce836329e2d4fae10ffa537cd';

/// The FCM adapter, or `null` when Firebase did not initialise (main.dart
/// overrides it). Push is then simply off; the app works fully without it.

@ProviderFor(pushMessaging)
final pushMessagingProvider = PushMessagingProvider._();

/// The FCM adapter, or `null` when Firebase did not initialise (main.dart
/// overrides it). Push is then simply off; the app works fully without it.

final class PushMessagingProvider
    extends $FunctionalProvider<PushMessaging?, PushMessaging?, PushMessaging?>
    with $Provider<PushMessaging?> {
  /// The FCM adapter, or `null` when Firebase did not initialise (main.dart
  /// overrides it). Push is then simply off; the app works fully without it.
  PushMessagingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushMessagingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushMessagingHash();

  @$internal
  @override
  $ProviderElement<PushMessaging?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushMessaging? create(Ref ref) {
    return pushMessaging(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushMessaging? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushMessaging?>(value),
    );
  }
}

String _$pushMessagingHash() => r'4dab53858c393571788905f3a5f94a81c2088980';

@ProviderFor(pushService)
final pushServiceProvider = PushServiceProvider._();

final class PushServiceProvider
    extends $FunctionalProvider<PushService, PushService, PushService>
    with $Provider<PushService> {
  PushServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushServiceHash();

  @$internal
  @override
  $ProviderElement<PushService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushService create(Ref ref) {
    return pushService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushService>(value),
    );
  }
}

String _$pushServiceHash() => r'77c3673255b1f59c4d9c4544a7a341c29b3049e4';

@ProviderFor(signOutService)
final signOutServiceProvider = SignOutServiceProvider._();

final class SignOutServiceProvider
    extends $FunctionalProvider<SignOutService, SignOutService, SignOutService>
    with $Provider<SignOutService> {
  SignOutServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutServiceHash();

  @$internal
  @override
  $ProviderElement<SignOutService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignOutService create(Ref ref) {
    return signOutService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignOutService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignOutService>(value),
    );
  }
}

String _$signOutServiceHash() => r'604d3baf1cbd4128f625db021658b2eabaa1d131';

@ProviderFor(pendingCount)
final pendingCountProvider = PendingCountProvider._();

final class PendingCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  PendingCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return pendingCount(ref);
  }
}

String _$pendingCountHash() => r'f7baa5d9e69233b72941be069b53e30f4e4ab1d0';

@ProviderFor(authUser)
final authUserProvider = AuthUserProvider._();

final class AuthUserProvider
    extends
        $FunctionalProvider<AsyncValue<AuthUser?>, AuthUser?, Stream<AuthUser?>>
    with $FutureModifier<AuthUser?>, $StreamProvider<AuthUser?> {
  AuthUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authUserHash();

  @$internal
  @override
  $StreamProviderElement<AuthUser?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AuthUser?> create(Ref ref) {
    return authUser(ref);
  }
}

String _$authUserHash() => r'eb5861fccca8a24b7df59fc0415964608897267f';

/// Ticks every 30 s so the Aura day rolls over at 04:00 without a restart.

@ProviderFor(now)
final nowProvider = NowProvider._();

/// Ticks every 30 s so the Aura day rolls over at 04:00 without a restart.

final class NowProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Ticks every 30 s so the Aura day rolls over at 04:00 without a restart.
  NowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nowHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return now(ref);
  }
}

String _$nowHash() => r'58a3ba71953abb77732fad3f8e8cc12ed245be25';
