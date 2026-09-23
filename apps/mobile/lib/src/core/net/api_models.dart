import 'package:aura_domain/aura_domain.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_models.freezed.dart';
part 'api_models.g.dart';

/// `Snapshot` from contracts/api/v1.md — the server's authoritative view of
/// the avatar, streak and Starlight (DS-5).
@freezed
abstract class Snapshot with _$Snapshot {
  const factory Snapshot({
    required SnapshotAvatar avatar,
    required SnapshotStreak streak,
    required SnapshotStarlight starlight,
    required String serverTime,
    required String auraDay,
  }) = _Snapshot;

  const Snapshot._();

  factory Snapshot.fromJson(Map<String, dynamic> json) =>
      _$SnapshotFromJson(json);

  StreakState get streakState => StreakState(
    glowStreak: streak.glowStreak,
    lifetimeGlowDays: streak.lifetimeGlowDays,
    restBank: streak.restBank,
    earnCounter: streak.earnCounter,
    lastActiveDay: LocalDay.tryParse(streak.lastActiveDay),
  );

  /// The avatar state, holding [fallbackHue] when the server has no hue yet.
  AuraAvatarState avatarState({double? fallbackHue}) => AuraAvatarState(
    stage: AuraStage.fromName(avatar.stage),
    hue: avatar.hue ?? fallbackHue ?? AuraAvatarState.defaultHue,
    isResting: avatar.isResting,
    ringCount: avatar.ringCount,
    glowLevel: avatar.glowLevel,
    constellationStars: avatar.constellationStars,
    equippedCosmetics: avatar.equippedCosmetics.toSet(),
  );
}

@freezed
abstract class SnapshotAvatar with _$SnapshotAvatar {
  const factory SnapshotAvatar({
    @Default('spark') String stage,
    double? hue,
    @Default(false) bool isResting,
    @Default(0) int ringCount,
    @Default(0) int glowLevel,
    @Default(0) int constellationStars,
    @Default(<String>[]) List<String> equippedCosmetics,
  }) = _SnapshotAvatar;

  factory SnapshotAvatar.fromJson(Map<String, dynamic> json) =>
      _$SnapshotAvatarFromJson(json);
}

@freezed
abstract class SnapshotStreak with _$SnapshotStreak {
  const factory SnapshotStreak({
    @Default(0) int glowStreak,
    @Default(0) int lifetimeGlowDays,
    @Default(1) int restBank,
    @Default(0) int earnCounter,
    String? lastActiveDay,
  }) = _SnapshotStreak;

  factory SnapshotStreak.fromJson(Map<String, dynamic> json) =>
      _$SnapshotStreakFromJson(json);
}

@freezed
abstract class SnapshotStarlight with _$SnapshotStarlight {
  const factory SnapshotStarlight({
    @Default(0) int total,
    @Default(0) int today,
  }) = _SnapshotStarlight;

  factory SnapshotStarlight.fromJson(Map<String, dynamic> json) =>
      _$SnapshotStarlightFromJson(json);
}

/// One mutation in `POST /v1/sync/push`.
@freezed
abstract class SyncMutation with _$SyncMutation {
  const factory SyncMutation({
    required String id,
    required String entity,
    required String op,
    required String deviceTs,
    required String localDay,
    required Map<String, dynamic> payload,

    /// IANA zone `localDay` was stamped in; the server judges backfill and
    /// eligibility in it (falls back to the profile zone when absent).
    @JsonKey(includeIfNull: false) String? tz,
  }) = _SyncMutation;

  factory SyncMutation.fromJson(Map<String, dynamic> json) =>
      _$SyncMutationFromJson(json);
}

@freezed
abstract class MutationResult with _$MutationResult {
  const factory MutationResult({
    required String id,
    required String status, // applied | duplicate | rejected
    String? reason,
  }) = _MutationResult;

  factory MutationResult.fromJson(Map<String, dynamic> json) =>
      _$MutationResultFromJson(json);
}

@freezed
abstract class PushResponse with _$PushResponse {
  const factory PushResponse({
    @Default(<MutationResult>[]) List<MutationResult> results,
    Snapshot? snapshot,
  }) = _PushResponse;

  factory PushResponse.fromJson(Map<String, dynamic> json) =>
      _$PushResponseFromJson(json);
}

/// `POST /v1/profile` body.
@freezed
abstract class ProfileRequest with _$ProfileRequest {
  const factory ProfileRequest({
    required String birthDate,
    required String uiLocale,
    required String timezone,
    String? country,
  }) = _ProfileRequest;

  factory ProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$ProfileRequestFromJson(json);
}

/// `GET /v1/keys/data-key`.
@freezed
abstract class DataKeyResponse with _$DataKeyResponse {
  const factory DataKeyResponse({
    required String keyId,
    required String dataKey,
  }) = _DataKeyResponse;

  factory DataKeyResponse.fromJson(Map<String, dynamic> json) =>
      _$DataKeyResponseFromJson(json);
}

/// `GET /v1/account`, `POST /v1/account/deletion` (202) and
/// `DELETE /v1/account/deletion`: when the account's scheduled purge runs,
/// or `null` when none is scheduled (F8 REQ-ACC-11, 7-day grace).
@freezed
abstract class AccountStatus with _$AccountStatus {
  const factory AccountStatus({String? deletionScheduledFor}) = _AccountStatus;

  const AccountStatus._();

  factory AccountStatus.fromJson(Map<String, dynamic> json) =>
      _$AccountStatusFromJson(json);

  /// The scheduled purge time, or `null` (none, or unreadable).
  DateTime? get scheduledFor {
    final raw = deletionScheduledFor;
    return raw == null ? null : DateTime.tryParse(raw);
  }
}

/// `POST /v1/media/upload-url` → where to `PUT` one encrypted media object
/// (contracts/api/v1.md "Media: voice notes"). [path] is used verbatim as
/// the check-in's `voicePath` and for downloads.
@freezed
abstract class MediaUploadUrl with _$MediaUploadUrl {
  const factory MediaUploadUrl({
    required String path,
    required String uploadUrl,
    String? expiresAt,
  }) = _MediaUploadUrl;

  factory MediaUploadUrl.fromJson(Map<String, dynamic> json) =>
      _$MediaUploadUrlFromJson(json);
}

/// `POST /v1/media/download-url` → a short-lived URL for the ciphertext.
@freezed
abstract class MediaDownloadUrl with _$MediaDownloadUrl {
  const factory MediaDownloadUrl({
    required String downloadUrl,
    String? expiresAt,
  }) = _MediaDownloadUrl;

  factory MediaDownloadUrl.fromJson(Map<String, dynamic> json) =>
      _$MediaDownloadUrlFromJson(json);
}
