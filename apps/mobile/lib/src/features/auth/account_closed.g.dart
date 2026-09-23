// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_closed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `null` when this build has no API.

@ProviderFor(accountStanding)
final accountStandingProvider = AccountStandingProvider._();

/// `null` when this build has no API.

final class AccountStandingProvider
    extends
        $FunctionalProvider<
          AccountStanding?,
          AccountStanding?,
          AccountStanding?
        >
    with $Provider<AccountStanding?> {
  /// `null` when this build has no API.
  AccountStandingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountStandingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountStandingHash();

  @$internal
  @override
  $ProviderElement<AccountStanding?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountStanding? create(Ref ref) {
    return accountStanding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountStanding? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountStanding?>(value),
    );
  }
}

String _$accountStandingHash() => r'ecd56989918f2ba98959fd1abc2b53267b60062e';

@ProviderFor(accountClosedPresenter)
final accountClosedPresenterProvider = AccountClosedPresenterProvider._();

final class AccountClosedPresenterProvider
    extends
        $FunctionalProvider<
          AccountClosedPresenter,
          AccountClosedPresenter,
          AccountClosedPresenter
        >
    with $Provider<AccountClosedPresenter> {
  AccountClosedPresenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountClosedPresenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountClosedPresenterHash();

  @$internal
  @override
  $ProviderElement<AccountClosedPresenter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountClosedPresenter create(Ref ref) {
    return accountClosedPresenter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountClosedPresenter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountClosedPresenter>(value),
    );
  }
}

String _$accountClosedPresenterHash() =>
    r'8fca58403f9549d8c306fbb19cfd2d2366e78b87';

/// The id of the signed-in account when it is closed, else `null`. Signing
/// out or switching accounts clears it.

@ProviderFor(AccountClosed)
final accountClosedProvider = AccountClosedProvider._();

/// The id of the signed-in account when it is closed, else `null`. Signing
/// out or switching accounts clears it.
final class AccountClosedProvider
    extends $NotifierProvider<AccountClosed, String?> {
  /// The id of the signed-in account when it is closed, else `null`. Signing
  /// out or switching accounts clears it.
  AccountClosedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountClosedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountClosedHash();

  @$internal
  @override
  AccountClosed create() => AccountClosed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$accountClosedHash() => r'17d0a5969b8a187af0143c3549dbd1b7e2d23ad9';

/// The id of the signed-in account when it is closed, else `null`. Signing
/// out or switching accounts clears it.

abstract class _$AccountClosed extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
