// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_assets.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(avatarAssets)
final avatarAssetsProvider = AvatarAssetsProvider._();

final class AvatarAssetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AvatarAssets>,
          AvatarAssets,
          FutureOr<AvatarAssets>
        >
    with $FutureModifier<AvatarAssets>, $FutureProvider<AvatarAssets> {
  AvatarAssetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarAssetsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarAssetsHash();

  @$internal
  @override
  $FutureProviderElement<AvatarAssets> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AvatarAssets> create(Ref ref) {
    return avatarAssets(ref);
  }
}

String _$avatarAssetsHash() => r'fbb57645752a60b3e0a40edf588c96db831b435c';
