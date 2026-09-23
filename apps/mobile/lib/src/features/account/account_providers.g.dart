// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `null` when this build has no API (debug builds without config).

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

/// `null` when this build has no API (debug builds without config).

final class AccountRepositoryProvider
    extends
        $FunctionalProvider<
          AccountRepository?,
          AccountRepository?,
          AccountRepository?
        >
    with $Provider<AccountRepository?> {
  /// `null` when this build has no API (debug builds without config).
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountRepository? create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository?>(value),
    );
  }
}

String _$accountRepositoryHash() => r'c5b2e399c95eb41d7fc23a704a352056643b4b45';

/// Whether the signed-in account has a deletion scheduled. While it does,
/// the server refuses every write, sync holds the outbox, and the app asks
/// "Keep my account?" — after sign-in (the sign-in screen), and in Settings.
/// Clearing it (`null`) releases sync (wired in `syncControllerProvider`).

@ProviderFor(DeletionHold)
final deletionHoldProvider = DeletionHoldProvider._();

/// Whether the signed-in account has a deletion scheduled. While it does,
/// the server refuses every write, sync holds the outbox, and the app asks
/// "Keep my account?" — after sign-in (the sign-in screen), and in Settings.
/// Clearing it (`null`) releases sync (wired in `syncControllerProvider`).
final class DeletionHoldProvider
    extends $NotifierProvider<DeletionHold, DeletionPending?> {
  /// Whether the signed-in account has a deletion scheduled. While it does,
  /// the server refuses every write, sync holds the outbox, and the app asks
  /// "Keep my account?" — after sign-in (the sign-in screen), and in Settings.
  /// Clearing it (`null`) releases sync (wired in `syncControllerProvider`).
  DeletionHoldProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deletionHoldProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deletionHoldHash();

  @$internal
  @override
  DeletionHold create() => DeletionHold();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeletionPending? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeletionPending?>(value),
    );
  }
}

String _$deletionHoldHash() => r'63bf175923d255cce9e8ad04f91e945878d26dd4';

/// Whether the signed-in account has a deletion scheduled. While it does,
/// the server refuses every write, sync holds the outbox, and the app asks
/// "Keep my account?" — after sign-in (the sign-in screen), and in Settings.
/// Clearing it (`null`) releases sync (wired in `syncControllerProvider`).

abstract class _$DeletionHold extends $Notifier<DeletionPending?> {
  DeletionPending? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DeletionPending?, DeletionPending?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeletionPending?, DeletionPending?>,
              DeletionPending?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
