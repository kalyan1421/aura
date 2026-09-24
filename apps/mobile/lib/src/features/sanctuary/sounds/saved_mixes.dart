import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Favourite mixes, saved on this phone only (PRD 06d). A mix is just stem
/// ids with volumes: no name to type, nothing synced. Kept in the local
/// key/value store, which the sign-out wipe clears (shared phones).
const String savedMixesKey = 'sounds.saved_mixes';

/// At most this many saved mixes; saving one more drops the oldest.
const int maxSavedMixes = 8;

@immutable
class SavedMix {
  const SavedMix(this.layers);

  factory SavedMix.fromJson(Map<String, dynamic> json) => SavedMix([
    for (final l in (json['layers'] as List? ?? const []))
      if (l is Map && l['id'] is String && l['v'] is num)
        (l['id'] as String, (l['v'] as num).toDouble().clamp(0.0, 1.0)),
  ]);

  /// (stem id, volume 0…1), in play order.
  final List<(String, double)> layers;

  List<String> get stemIds => [for (final (id, _) in layers) id];

  Map<String, dynamic> toJson() => {
    'layers': [
      for (final (id, v) in layers) {'id': id, 'v': (v * 100).round() / 100},
    ],
  };

  /// Same stems at (nearly) the same volumes.
  bool sameAs(SavedMix other) {
    if (other.layers.length != layers.length) return false;
    for (var i = 0; i < layers.length; i++) {
      final (a, va) = layers[i];
      final (b, vb) = other.layers[i];
      if (a != b || (va - vb).abs() > 0.02) return false;
    }
    return true;
  }
}

final savedMixesProvider = NotifierProvider<SavedMixes, List<SavedMix>>(
  SavedMixes.new,
);

class SavedMixes extends Notifier<List<SavedMix>> {
  @override
  List<SavedMix> build() {
    final sub = ref
        .watch(kvStoreProvider)
        .watchJson(savedMixesKey)
        .listen(
          (json) => state = [
            for (final m in (json?['mixes'] as List? ?? const []))
              if (m is Map<String, dynamic>) SavedMix.fromJson(m),
          ],
          onError: (Object e) =>
              debugPrint('sounds: saved mixes unreadable (${e.runtimeType})'),
        );
    ref.onDispose(sub.cancel);
    return const [];
  }

  /// Saves [mix] (first in the list). Returns false if it was already saved.
  Future<bool> save(SavedMix mix) async {
    if (mix.layers.isEmpty) return false;
    if (state.any(mix.sameAs)) return false;
    await _write([mix, ...state].take(maxSavedMixes).toList());
    return true;
  }

  Future<void> remove(SavedMix mix) =>
      _write([for (final m in state) if (!identical(m, mix)) m]);

  Future<void> _write(List<SavedMix> mixes) async {
    state = mixes;
    await ref.read(kvStoreProvider).setJson(savedMixesKey, {
      'mixes': [for (final m in mixes) m.toJson()],
    });
  }
}
