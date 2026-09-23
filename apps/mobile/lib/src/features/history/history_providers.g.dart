// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True while a change to this check-in still waits to sync.

@ProviderFor(checkInPending)
final checkInPendingProvider = CheckInPendingFamily._();

/// True while a change to this check-in still waits to sync.

final class CheckInPendingProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// True while a change to this check-in still waits to sync.
  CheckInPendingProvider._({
    required CheckInPendingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'checkInPendingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checkInPendingHash();

  @override
  String toString() {
    return r'checkInPendingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return checkInPending(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CheckInPendingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checkInPendingHash() => r'06c443945cc76ff05d775c22eac907a6783de756';

/// True while a change to this check-in still waits to sync.

final class CheckInPendingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  CheckInPendingFamily._()
    : super(
        retry: null,
        name: r'checkInPendingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// True while a change to this check-in still waits to sync.

  CheckInPendingProvider call(String id) =>
      CheckInPendingProvider._(argument: id, from: this);

  @override
  String toString() => r'checkInPendingProvider';
}

/// The private note of a check-in, via the repository (never logged). Reloads
/// whenever the row changes (e.g. after an edit).

@ProviderFor(checkInNote)
final checkInNoteProvider = CheckInNoteFamily._();

/// The private note of a check-in, via the repository (never logged). Reloads
/// whenever the row changes (e.g. after an edit).

final class CheckInNoteProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The private note of a check-in, via the repository (never logged). Reloads
  /// whenever the row changes (e.g. after an edit).
  CheckInNoteProvider._({
    required CheckInNoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'checkInNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checkInNoteHash();

  @override
  String toString() {
    return r'checkInNoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return checkInNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CheckInNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checkInNoteHash() => r'fecc625370a446b093cd234f3cf6d6bf6c4e6c92';

/// The private note of a check-in, via the repository (never logged). Reloads
/// whenever the row changes (e.g. after an edit).

final class CheckInNoteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  CheckInNoteFamily._()
    : super(
        retry: null,
        name: r'checkInNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The private note of a check-in, via the repository (never logged). Reloads
  /// whenever the row changes (e.g. after an edit).

  CheckInNoteProvider call(String id) =>
      CheckInNoteProvider._(argument: id, from: this);

  @override
  String toString() => r'checkInNoteProvider';
}
