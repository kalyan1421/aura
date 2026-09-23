// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Snapshot _$SnapshotFromJson(Map<String, dynamic> json) => _Snapshot(
  avatar: SnapshotAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
  streak: SnapshotStreak.fromJson(json['streak'] as Map<String, dynamic>),
  starlight: SnapshotStarlight.fromJson(
    json['starlight'] as Map<String, dynamic>,
  ),
  serverTime: json['serverTime'] as String,
  auraDay: json['auraDay'] as String,
);

Map<String, dynamic> _$SnapshotToJson(_Snapshot instance) => <String, dynamic>{
  'avatar': instance.avatar,
  'streak': instance.streak,
  'starlight': instance.starlight,
  'serverTime': instance.serverTime,
  'auraDay': instance.auraDay,
};

_SnapshotAvatar _$SnapshotAvatarFromJson(Map<String, dynamic> json) =>
    _SnapshotAvatar(
      stage: json['stage'] as String? ?? 'spark',
      hue: (json['hue'] as num?)?.toDouble(),
      isResting: json['isResting'] as bool? ?? false,
      ringCount: (json['ringCount'] as num?)?.toInt() ?? 0,
      glowLevel: (json['glowLevel'] as num?)?.toInt() ?? 0,
      constellationStars: (json['constellationStars'] as num?)?.toInt() ?? 0,
      equippedCosmetics:
          (json['equippedCosmetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$SnapshotAvatarToJson(_SnapshotAvatar instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'hue': instance.hue,
      'isResting': instance.isResting,
      'ringCount': instance.ringCount,
      'glowLevel': instance.glowLevel,
      'constellationStars': instance.constellationStars,
      'equippedCosmetics': instance.equippedCosmetics,
    };

_SnapshotStreak _$SnapshotStreakFromJson(Map<String, dynamic> json) =>
    _SnapshotStreak(
      glowStreak: (json['glowStreak'] as num?)?.toInt() ?? 0,
      lifetimeGlowDays: (json['lifetimeGlowDays'] as num?)?.toInt() ?? 0,
      restBank: (json['restBank'] as num?)?.toInt() ?? 1,
      earnCounter: (json['earnCounter'] as num?)?.toInt() ?? 0,
      lastActiveDay: json['lastActiveDay'] as String?,
    );

Map<String, dynamic> _$SnapshotStreakToJson(_SnapshotStreak instance) =>
    <String, dynamic>{
      'glowStreak': instance.glowStreak,
      'lifetimeGlowDays': instance.lifetimeGlowDays,
      'restBank': instance.restBank,
      'earnCounter': instance.earnCounter,
      'lastActiveDay': instance.lastActiveDay,
    };

_SnapshotStarlight _$SnapshotStarlightFromJson(Map<String, dynamic> json) =>
    _SnapshotStarlight(
      total: (json['total'] as num?)?.toInt() ?? 0,
      today: (json['today'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SnapshotStarlightToJson(_SnapshotStarlight instance) =>
    <String, dynamic>{'total': instance.total, 'today': instance.today};

_SyncMutation _$SyncMutationFromJson(Map<String, dynamic> json) =>
    _SyncMutation(
      id: json['id'] as String,
      entity: json['entity'] as String,
      op: json['op'] as String,
      deviceTs: json['deviceTs'] as String,
      localDay: json['localDay'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      tz: json['tz'] as String?,
    );

Map<String, dynamic> _$SyncMutationToJson(_SyncMutation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entity': instance.entity,
      'op': instance.op,
      'deviceTs': instance.deviceTs,
      'localDay': instance.localDay,
      'payload': instance.payload,
      'tz': ?instance.tz,
    };

_MutationResult _$MutationResultFromJson(Map<String, dynamic> json) =>
    _MutationResult(
      id: json['id'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$MutationResultToJson(_MutationResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'reason': instance.reason,
    };

_PushResponse _$PushResponseFromJson(Map<String, dynamic> json) =>
    _PushResponse(
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => MutationResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MutationResult>[],
      snapshot: json['snapshot'] == null
          ? null
          : Snapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PushResponseToJson(_PushResponse instance) =>
    <String, dynamic>{
      'results': instance.results,
      'snapshot': instance.snapshot,
    };

_ProfileRequest _$ProfileRequestFromJson(Map<String, dynamic> json) =>
    _ProfileRequest(
      birthDate: json['birthDate'] as String,
      uiLocale: json['uiLocale'] as String,
      timezone: json['timezone'] as String,
      country: json['country'] as String?,
      ageSignal: json['ageSignal'] as String?,
    );

Map<String, dynamic> _$ProfileRequestToJson(_ProfileRequest instance) =>
    <String, dynamic>{
      'birthDate': instance.birthDate,
      'uiLocale': instance.uiLocale,
      'timezone': instance.timezone,
      'country': instance.country,
      'ageSignal': ?instance.ageSignal,
    };

_DataKeyResponse _$DataKeyResponseFromJson(Map<String, dynamic> json) =>
    _DataKeyResponse(
      keyId: json['keyId'] as String,
      dataKey: json['dataKey'] as String,
    );

Map<String, dynamic> _$DataKeyResponseToJson(_DataKeyResponse instance) =>
    <String, dynamic>{'keyId': instance.keyId, 'dataKey': instance.dataKey};

_AccountStatus _$AccountStatusFromJson(Map<String, dynamic> json) =>
    _AccountStatus(
      deletionScheduledFor: json['deletionScheduledFor'] as String?,
    );

Map<String, dynamic> _$AccountStatusToJson(_AccountStatus instance) =>
    <String, dynamic>{'deletionScheduledFor': instance.deletionScheduledFor};

_MediaUploadUrl _$MediaUploadUrlFromJson(Map<String, dynamic> json) =>
    _MediaUploadUrl(
      path: json['path'] as String,
      uploadUrl: json['uploadUrl'] as String,
      expiresAt: json['expiresAt'] as String?,
    );

Map<String, dynamic> _$MediaUploadUrlToJson(_MediaUploadUrl instance) =>
    <String, dynamic>{
      'path': instance.path,
      'uploadUrl': instance.uploadUrl,
      'expiresAt': instance.expiresAt,
    };

_MediaDownloadUrl _$MediaDownloadUrlFromJson(Map<String, dynamic> json) =>
    _MediaDownloadUrl(
      downloadUrl: json['downloadUrl'] as String,
      expiresAt: json['expiresAt'] as String?,
    );

Map<String, dynamic> _$MediaDownloadUrlToJson(_MediaDownloadUrl instance) =>
    <String, dynamic>{
      'downloadUrl': instance.downloadUrl,
      'expiresAt': instance.expiresAt,
    };
