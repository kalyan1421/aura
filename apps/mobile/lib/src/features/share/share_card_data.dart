import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart';

/// The four card types of PRD F13.
enum ShareCardKind { evolution, glow, capsuleAnniversary, keepsake }

/// Everything a share card may show — and nothing else (REQ-SHR-02).
///
/// Built only through the named constructors below, which take the avatar
/// state and copy its **whitelisted** traits: stage, rings, glow level,
/// constellation stars and equipped cosmetics. The mood-derived hue, the
/// resting look, moods, quadrants, tags, notes, capsule text, dates, streak
/// counts, pseudonyms, usernames, ages and ids have no field here, so a card
/// can't bind them. `test/share_card_test.dart` pins [fields] to
/// [whitelist]: adding any other field fails the build.
@immutable
class ShareCardData {
  const ShareCardData._({
    required this.kind,
    required this.stage,
    required this.ringCount,
    required this.glowLevel,
    required this.constellationStars,
    required this.cosmetics,
    this.value,
    this.keepsakeKey,
  });

  /// Evolution card: the stage the avatar reached (Ember → Constellation).
  factory ShareCardData.evolution(AuraAvatarState avatar) =>
      ShareCardData._traits(ShareCardKind.evolution, avatar);

  /// Glow milestone: lifetime glow days (7 / 30 / 100 / 365). Never the streak.
  factory ShareCardData.glow(AuraAvatarState avatar, int days) =>
      ShareCardData._traits(ShareCardKind.glow, avatar, value: days);

  /// "Sealed a capsule [years] year(s) ago" (no date, no capsule content).
  factory ShareCardData.capsuleAnniversary(AuraAvatarState avatar, int years) =>
      ShareCardData._traits(
        ShareCardKind.capsuleAnniversary,
        avatar,
        value: years,
      );

  /// A keepsake: the seal and its line (never the day it was kept).
  factory ShareCardData.keepsake(AuraAvatarState avatar, String key) =>
      ShareCardData._traits(ShareCardKind.keepsake, avatar, keepsakeKey: key);

  factory ShareCardData._traits(
    ShareCardKind kind,
    AuraAvatarState avatar, {
    int? value,
    String? keepsakeKey,
  }) => ShareCardData._(
    kind: kind,
    stage: avatar.stage,
    ringCount: avatar.ringCount,
    glowLevel: avatar.glowLevel,
    constellationStars: avatar.constellationStars,
    cosmetics: Set.unmodifiable(avatar.equippedCosmetics),
    value: value,
    keepsakeKey: keepsakeKey,
  );

  final ShareCardKind kind;
  final AuraStage stage;
  final int ringCount;
  final int glowLevel;
  final int constellationStars;
  final Set<String> cosmetics;

  /// Glow days or capsule years (the milestone), when the card has one.
  final int? value;
  final String? keepsakeKey;

  /// The only fields a card template may bind.
  static const Set<String> whitelist = {
    'kind',
    'stage',
    'ringCount',
    'glowLevel',
    'constellationStars',
    'cosmetics',
    'value',
    'keepsakeKey',
  };

  /// Every field this object holds (pinned to [whitelist] by a test).
  Map<String, Object?> get fields => {
    'kind': kind.name,
    'stage': stage.name,
    'ringCount': ringCount,
    'glowLevel': glowLevel,
    'constellationStars': constellationStars,
    'cosmetics': cosmetics.toList()..sort(),
    'value': value,
    'keepsakeKey': keepsakeKey,
  };

  /// The template's fixed hue (PRD: "cards use the template's fixed palette,
  /// not the mood-derived hue, since that mapping is visible in-app and could
  /// be decoded into moods").
  double get templateHue => switch (kind) {
    ShareCardKind.evolution => 262,
    ShareCardKind.glow => 38,
    ShareCardKind.capsuleAnniversary => 205,
    ShareCardKind.keepsake => 318,
  };

  /// The avatar exactly as the card draws it: the whitelisted traits on the
  /// template hue, awake (never the resting look).
  AuraAvatarState get avatar => AuraAvatarState(
    stage: stage,
    hue: templateHue,
    ringCount: ringCount,
    glowLevel: glowLevel,
    constellationStars: constellationStars,
    equippedCosmetics: cosmetics,
  );

  @override
  bool operator ==(Object other) =>
      other is ShareCardData && '${other.fields}' == '$fields';

  @override
  int get hashCode => '$fields'.hashCode;
}
