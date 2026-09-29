// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'welcome_back.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the personal universe shows its one-time "Your world is here" card
/// (W04, RULES.md section 13 `welcome`): the person has been away three or more
/// Aura days and the card was not already shown for this absence. Decided once
/// per visit, recorded when it is shown, and never re-evaluated mid-visit
/// (a snapshot refresh must not hide the card the person is reading).

@ProviderFor(WelcomeBack)
final welcomeBackProvider = WelcomeBackProvider._();

/// Whether the personal universe shows its one-time "Your world is here" card
/// (W04, RULES.md section 13 `welcome`): the person has been away three or more
/// Aura days and the card was not already shown for this absence. Decided once
/// per visit, recorded when it is shown, and never re-evaluated mid-visit
/// (a snapshot refresh must not hide the card the person is reading).
final class WelcomeBackProvider
    extends $AsyncNotifierProvider<WelcomeBack, bool> {
  /// Whether the personal universe shows its one-time "Your world is here" card
  /// (W04, RULES.md section 13 `welcome`): the person has been away three or more
  /// Aura days and the card was not already shown for this absence. Decided once
  /// per visit, recorded when it is shown, and never re-evaluated mid-visit
  /// (a snapshot refresh must not hide the card the person is reading).
  WelcomeBackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'welcomeBackProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$welcomeBackHash();

  @$internal
  @override
  WelcomeBack create() => WelcomeBack();
}

String _$welcomeBackHash() => r'20d489bd81ea984a4268d38550de759ed283f101';

/// Whether the personal universe shows its one-time "Your world is here" card
/// (W04, RULES.md section 13 `welcome`): the person has been away three or more
/// Aura days and the card was not already shown for this absence. Decided once
/// per visit, recorded when it is shown, and never re-evaluated mid-visit
/// (a snapshot refresh must not hide the card the person is reading).

abstract class _$WelcomeBack extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
