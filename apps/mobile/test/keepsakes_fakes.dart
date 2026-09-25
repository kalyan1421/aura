import 'dart:typed_data';
import 'dart:ui';

import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/features/keepsakes/keepsakes_api.dart';
import 'package:aura/src/features/share/share_gateway.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura_domain/aura_domain.dart';

/// `GET /v1/keepsakes` stand-in: returns [list], or throws while [offline].
class FakeKeepsakesApi implements KeepsakesApi {
  FakeKeepsakesApi([this.list = const []]);

  List<OwnKeepsake> list;
  bool offline = false;
  int calls = 0;

  @override
  Future<List<OwnKeepsake>> mine() async {
    calls++;
    if (offline) {
      throw const ApiException(code: 'connectionError', isNetwork: true);
    }
    return list;
  }
}

/// The OS share sheet stand-in: records what would be shared.
class FakeShareGateway implements ShareGateway {
  final List<({Uint8List png, String text})> shared = [];

  @override
  Future<void> shareImage(
    Uint8List png, {
    required String text,
    Rect? origin,
  }) async => shared.add((png: png, text: text));
}

OwnKeepsake keep(String key, String day) =>
    OwnKeepsake(key, LocalDay.parse(day));

/// A loaded Home progress view (8 Oct 2026).
ProgressView progressFor({
  AuraStage stage = AuraStage.spark,
  int lifetimeGlowDays = 3,
  double hue = 175,
  bool resting = false,
}) => ProgressView(
  loaded: true,
  today: const LocalDay(2026, 10, 8),
  avatar: AuraAvatarState(
    stage: stage,
    hue: hue,
    isResting: resting,
    ringCount: 2,
    glowLevel: 1,
    equippedCosmetics: const {'first_light'},
  ),
  todayStarlight: 10,
  totalStarlight: stage.threshold + 10,
  streak: StreakState(glowStreak: 2, lifetimeGlowDays: lifetimeGlowDays),
  glow: GlowStatus.activeToday,
  provisional: false,
  hasActivity: true,
  awards: const {},
  localHue: null,
);
