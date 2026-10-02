// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which social buttons this build offers (from `--dart-define`s).

@ProviderFor(socialSignInConfig)
final socialSignInConfigProvider = SocialSignInConfigProvider._();

/// Which social buttons this build offers (from `--dart-define`s).

final class SocialSignInConfigProvider
    extends
        $FunctionalProvider<
          SocialSignInConfig,
          SocialSignInConfig,
          SocialSignInConfig
        >
    with $Provider<SocialSignInConfig> {
  /// Which social buttons this build offers (from `--dart-define`s).
  SocialSignInConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialSignInConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialSignInConfigHash();

  @$internal
  @override
  $ProviderElement<SocialSignInConfig> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SocialSignInConfig create(Ref ref) {
    return socialSignInConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialSignInConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialSignInConfig>(value),
    );
  }
}

String _$socialSignInConfigHash() =>
    r'b3d922ccc90e742216db81a882d12bfabe17e407';

/// Native Apple / Google → Supabase session. `null` when this build has no
/// Supabase (sign-in is unavailable, so no social button shows either).

@ProviderFor(socialSignIn)
final socialSignInProvider = SocialSignInProvider._();

/// Native Apple / Google → Supabase session. `null` when this build has no
/// Supabase (sign-in is unavailable, so no social button shows either).

final class SocialSignInProvider
    extends
        $FunctionalProvider<
          SocialSignInService?,
          SocialSignInService?,
          SocialSignInService?
        >
    with $Provider<SocialSignInService?> {
  /// Native Apple / Google → Supabase session. `null` when this build has no
  /// Supabase (sign-in is unavailable, so no social button shows either).
  SocialSignInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialSignInProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialSignInHash();

  @$internal
  @override
  $ProviderElement<SocialSignInService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SocialSignInService? create(Ref ref) {
    return socialSignIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialSignInService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialSignInService?>(value),
    );
  }
}

String _$socialSignInHash() => r'6c3d22644436e09c8f5ed3f80a8d72e4e1c3ba72';

/// Apple Declared Age Range / Play Age Signals (REQ-ACC-04).

@ProviderFor(ageSignalSource)
final ageSignalSourceProvider = AgeSignalSourceProvider._();

/// Apple Declared Age Range / Play Age Signals (REQ-ACC-04).

final class AgeSignalSourceProvider
    extends
        $FunctionalProvider<AgeSignalSource, AgeSignalSource, AgeSignalSource>
    with $Provider<AgeSignalSource> {
  /// Apple Declared Age Range / Play Age Signals (REQ-ACC-04).
  AgeSignalSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ageSignalSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ageSignalSourceHash();

  @$internal
  @override
  $ProviderElement<AgeSignalSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgeSignalSource create(Ref ref) {
    return ageSignalSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgeSignalSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgeSignalSource>(value),
    );
  }
}

String _$ageSignalSourceHash() => r'0b66bfb495e223543d72f003e8d7b848749d18b3';

/// Applies a signal: the under-13 block or the invisible under-18 flag (on
/// the phone, and on the server with the next profile POST).

@ProviderFor(ageSignalPolicy)
final ageSignalPolicyProvider = AgeSignalPolicyProvider._();

/// Applies a signal: the under-13 block or the invisible under-18 flag (on
/// the phone, and on the server with the next profile POST).

final class AgeSignalPolicyProvider
    extends
        $FunctionalProvider<AgeSignalPolicy, AgeSignalPolicy, AgeSignalPolicy>
    with $Provider<AgeSignalPolicy> {
  /// Applies a signal: the under-13 block or the invisible under-18 flag (on
  /// the phone, and on the server with the next profile POST).
  AgeSignalPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ageSignalPolicyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ageSignalPolicyHash();

  @$internal
  @override
  $ProviderElement<AgeSignalPolicy> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgeSignalPolicy create(Ref ref) {
    return ageSignalPolicy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgeSignalPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgeSignalPolicy>(value),
    );
  }
}

String _$ageSignalPolicyHash() => r'35ee96b2735c84321e62c4ce13c1b1648be54571';
