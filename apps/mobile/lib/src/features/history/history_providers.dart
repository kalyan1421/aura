import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

part 'history_providers.g.dart';

// The two row providers are written by hand: `CheckInRow` is itself
// generated (Drift), and riverpod_generator runs before that type exists.

/// Live (not deleted) check-ins for the private history, newest first.
/// Read from Drift, so it works offline.
final historyEntriesProvider = StreamProvider.autoDispose<List<CheckInRow>>(
  (ref) => ref.watch(checkInRepositoryProvider).watchHistory(),
);

/// One check-in by id (tombstones included); `null` when it is not on this
/// phone.
final checkInEntryProvider = StreamProvider.autoDispose
    .family<CheckInRow?, String>(
      (ref, id) => ref.watch(checkInRepositoryProvider).watchEntry(id),
    );

/// True while a change to this check-in still waits to sync.
@riverpod
Stream<bool> checkInPending(Ref ref, String id) =>
    ref.watch(checkInRepositoryProvider).watchPending(id);

/// The private note of a check-in, via the repository (never logged). Reloads
/// whenever the row changes (e.g. after an edit).
@riverpod
Future<String?> checkInNote(Ref ref, String id) async {
  await ref.watch(checkInEntryProvider(id).future);
  return ref.read(checkInRepositoryProvider).noteOf(id);
}
