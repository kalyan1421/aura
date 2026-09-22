import 'dart:async';
import 'dart:convert';

import 'package:aura_domain/aura_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/kv_store.dart';
import '../../core/providers.dart';
import '../progress/progress_view.dart';

part 'moments_controller.g.dart';

/// One-shot avatar moments (`evolve`, `wakeUp`). They are events, not state:
/// each has an id and plays once per id on this device, even if a later sync
/// re-delivers the same stage (REQ-AVA-05).
@Riverpod(keepAlive: true)
class MomentsController extends _$MomentsController {
  Set<String>? _played;
  AuraAvatarState? _last;

  @override
  AvatarMoment? build() {
    ref.listen<ProgressView>(progressViewProvider, (prev, next) {
      if (!next.loaded) return;
      final before = _last;
      _last = next.avatar;
      // The first loaded frame is the baseline, never a moment.
      if (before == null) return;
      final moments = momentsBetween(
        before,
        next.avatar,
        causeId: next.today.toIso(),
      );
      if (moments.isNotEmpty) unawaited(_offer(moments));
    }, fireImmediately: true);
    return null;
  }

  Future<void> _offer(List<AvatarMoment> moments) async {
    final played = await _playedIds();
    for (final m in moments) {
      if (played.contains(m.id)) continue;
      state = m;
      return;
    }
  }

  /// The UI finished (or skipped) [moment].
  Future<void> markPlayed(AvatarMoment moment) async {
    final played = await _playedIds();
    played.add(moment.id);
    // Keep the list small: evolve ids are per stage, wake ids per day.
    final trimmed = played.length > 60
        ? played.skip(played.length - 60).toSet()
        : played;
    _played = trimmed;
    await ref
        .read(kvStoreProvider)
        .set(KvKeys.playedMoments, jsonEncode(trimmed.toList()));
    if (state == moment) state = null;
  }

  Future<Set<String>> _playedIds() async {
    final cached = _played;
    if (cached != null) return cached;
    final raw = await ref.read(kvStoreProvider).get(KvKeys.playedMoments);
    return _played = raw == null
        ? <String>{}
        : (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }
}
