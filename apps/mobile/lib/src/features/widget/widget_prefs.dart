import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// KV keys of the widget feature. All belong to the signed-in person: they
/// are wiped at sign-out (not in `KvKeys.deviceScoped`), so the next person
/// starts from the private defaults and a new owner token.
abstract final class WidgetKvKeys {
  static const String prefs = 'widget.prefs';

  /// Opaque token stamped on widget check-ins (see `WidgetCheckIn.owner`).
  static const String owner = 'widget.owner';

  /// Ids of widget check-ins imported in the background, waiting for the
  /// capsule step at the next app open (widget_background.dart).
  static const String followUps = 'widget.followUps';
}

/// Settings → Home-screen widget (F11 privacy). Both off by default: the
/// widget shows no mood unless the person asks for it.
@immutable
class WidgetPrefs {
  const WidgetPrefs({this.showLastMood = false, this.discreet = false});

  factory WidgetPrefs.fromJson(Map<String, dynamic>? json) => WidgetPrefs(
    showLastMood: json?['showLastMood'] as bool? ?? false,
    discreet: json?['discreet'] as bool? ?? false,
  );

  /// "Show my last mood" (home screen only; never lock screen or StandBy).
  final bool showLastMood;

  /// Discreet widget: a plain star, no "Aura", no mood words.
  final bool discreet;

  WidgetPrefs copyWith({bool? showLastMood, bool? discreet}) => WidgetPrefs(
    showLastMood: showLastMood ?? this.showLastMood,
    discreet: discreet ?? this.discreet,
  );

  Map<String, dynamic> toJson() => {
    'showLastMood': showLastMood,
    'discreet': discreet,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetPrefs &&
      other.showLastMood == showLastMood &&
      other.discreet == discreet;

  @override
  int get hashCode => Object.hash(showLastMood, discreet);
}

class WidgetPrefsController extends Notifier<WidgetPrefs> {
  @override
  WidgetPrefs build() {
    final sub = ref
        .watch(kvStoreProvider)
        .watchJson(WidgetKvKeys.prefs)
        .listen((json) => state = WidgetPrefs.fromJson(json));
    ref.onDispose(sub.cancel);
    return const WidgetPrefs();
  }

  Future<void> update(WidgetPrefs Function(WidgetPrefs) change) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    await ref.read(kvStoreProvider).setJson(WidgetKvKeys.prefs, next.toJson());
  }
}

final widgetPrefsProvider =
    NotifierProvider<WidgetPrefsController, WidgetPrefs>(
      WidgetPrefsController.new,
    );
