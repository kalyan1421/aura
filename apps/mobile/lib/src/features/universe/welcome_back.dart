import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../progress/progress_view.dart';

part 'welcome_back.g.dart';

/// Whether the personal universe shows its one-time "Your world is here" card
/// (W04, RULES.md section 13 `welcome`): the person has been away three or more
/// Aura days and the card was not already shown for this absence. Decided once
/// per visit, recorded when it is shown, and never re-evaluated mid-visit
/// (a snapshot refresh must not hide the card the person is reading).
@riverpod
class WelcomeBack extends _$WelcomeBack {
  bool? _decided;

  @override
  Future<bool> build() async {
    // Wait until both progress streams have answered (the last active day can
    // live only in the server snapshot, which may arrive after the events, and
    // a person with no snapshot answers with null). Everything else is read,
    // not watched.
    final loaded =
        ref.watch(progressViewProvider.select((v) => v.loaded)) &&
        ref.watch(snapshotProvider.select((s) => s.hasValue));
    final decided = _decided;
    if (decided != null) return decided;
    if (!loaded) return false;
    final view = ref.read(progressViewProvider);
    final kv = ref.read(kvStoreProvider);
    final last = view.streak.lastActiveDay;
    final show = showWelcomeBack(
      lastActiveDay: last,
      today: view.today,
      shownFor: LocalDay.tryParse(await kv.get(KvKeys.welcomeShownFor)),
    );
    if (show) await kv.set(KvKeys.welcomeShownFor, last!.toIso());
    return _decided = show;
  }

  /// Either button, or leaving: the card is done for this absence.
  void dismiss() {
    _decided = false;
    state = const AsyncData(false);
  }
}
