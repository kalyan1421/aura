// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkin_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The person's recent custom tags, offered again as chips in the picker and
/// the edit view (F1 custom tags). Read once per screen; deleted check-ins
/// never contribute.

@ProviderFor(recentCustomTags)
final recentCustomTagsProvider = RecentCustomTagsProvider._();

/// The person's recent custom tags, offered again as chips in the picker and
/// the edit view (F1 custom tags). Read once per screen; deleted check-ins
/// never contribute.

final class RecentCustomTagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// The person's recent custom tags, offered again as chips in the picker and
  /// the edit view (F1 custom tags). Read once per screen; deleted check-ins
  /// never contribute.
  RecentCustomTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentCustomTagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentCustomTagsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return recentCustomTags(ref);
  }
}

String _$recentCustomTagsHash() => r'fa8d24897c23b2025e44413e87c739cafdad93b2';
