import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/kv_store.dart';
import '../providers.dart';

part 'comfort_prefs.g.dart';

/// Settings → Comfort. Device preferences (they survive sign-out, see
/// [KvKeys.deviceScoped]); none of them is personal data.
///
/// - [reduceMotion]: in-app Reduce Motion (REQ-A11Y-08). Merged into
///   `MediaQuery.disableAnimations` by `AuraApp`, so every
///   `reduceMotionOf(context)` check honours it together with the OS setting.
/// - [haptics]: restrained haptic feedback; off silences `AuraHaptics`.
/// - [hideStreak]: hides the glow-streak number on Home (F3).
@immutable
class ComfortPrefs {
  const ComfortPrefs({
    this.reduceMotion = false,
    this.haptics = true,
    this.hideStreak = false,
  });

  factory ComfortPrefs.fromJson(Map<String, dynamic>? json) => ComfortPrefs(
    reduceMotion: json?['reduceMotion'] as bool? ?? false,
    haptics: json?['haptics'] as bool? ?? true,
    hideStreak: json?['hideStreak'] as bool? ?? false,
  );

  final bool reduceMotion;
  final bool haptics;
  final bool hideStreak;

  ComfortPrefs copyWith({bool? reduceMotion, bool? haptics, bool? hideStreak}) =>
      ComfortPrefs(
        reduceMotion: reduceMotion ?? this.reduceMotion,
        haptics: haptics ?? this.haptics,
        hideStreak: hideStreak ?? this.hideStreak,
      );

  Map<String, dynamic> toJson() => {
    'reduceMotion': reduceMotion,
    'haptics': haptics,
    'hideStreak': hideStreak,
  };

  @override
  bool operator ==(Object other) =>
      other is ComfortPrefs &&
      other.reduceMotion == reduceMotion &&
      other.haptics == haptics &&
      other.hideStreak == hideStreak;

  @override
  int get hashCode => Object.hash(reduceMotion, haptics, hideStreak);
}

@Riverpod(keepAlive: true)
class ComfortController extends _$ComfortController {
  @override
  ComfortPrefs build() {
    final sub = ref
        .watch(kvStoreProvider)
        .watchJson(KvKeys.comfort)
        .listen((json) => state = ComfortPrefs.fromJson(json));
    ref.onDispose(sub.cancel);
    return const ComfortPrefs();
  }

  Future<void> update(ComfortPrefs Function(ComfortPrefs) change) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    await ref.read(kvStoreProvider).setJson(KvKeys.comfort, next.toJson());
  }
}
