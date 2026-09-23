// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LanternHour _$LanternHourFromJson(Map<String, dynamic> json) => _LanternHour(
  timezone: json['timezone'] as String? ?? '',
  active: json['active'] as bool? ?? false,
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: DateTime.parse(json['endsAt'] as String),
);

Map<String, dynamic> _$LanternHourToJson(_LanternHour instance) =>
    <String, dynamic>{
      'timezone': instance.timezone,
      'active': instance.active,
      'startsAt': instance.startsAt.toIso8601String(),
      'endsAt': instance.endsAt.toIso8601String(),
    };

_RoomInfo _$RoomInfoFromJson(Map<String, dynamic> json) => _RoomInfo(
  roomId: json['roomId'] as String,
  quadrant: json['quadrant'] as String,
  theme: json['theme'] as String? ?? '',
  state: json['state'] as String? ?? 'open',
  readOnly: json['readOnly'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  joinsCloseAt: DateTime.parse(json['joinsCloseAt'] as String),
  memoryAt: DateTime.parse(json['memoryAt'] as String),
  purgeAt: DateTime.parse(json['purgeAt'] as String),
  lanternHour: LanternHour.fromJson(
    json['lanternHour'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$RoomInfoToJson(_RoomInfo instance) => <String, dynamic>{
  'roomId': instance.roomId,
  'quadrant': instance.quadrant,
  'theme': instance.theme,
  'state': instance.state,
  'readOnly': instance.readOnly,
  'createdAt': instance.createdAt.toIso8601String(),
  'joinsCloseAt': instance.joinsCloseAt.toIso8601String(),
  'memoryAt': instance.memoryAt.toIso8601String(),
  'purgeAt': instance.purgeAt.toIso8601String(),
  'lanternHour': instance.lanternHour,
};

_RoomCounts _$RoomCountsFromJson(Map<String, dynamic> json) => _RoomCounts(
  hereNow: (json['hereNow'] as num?)?.toInt() ?? 0,
  today: (json['today'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RoomCountsToJson(_RoomCounts instance) =>
    <String, dynamic>{'hereNow': instance.hereNow, 'today': instance.today};

_Silhouette _$SilhouetteFromJson(Map<String, dynamic> json) => _Silhouette(
  stage: json['stage'] as String? ?? 'spark',
  hue: (json['hue'] as num?)?.toDouble(),
  cosmetic: json['cosmetic'] as String?,
);

Map<String, dynamic> _$SilhouetteToJson(_Silhouette instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'hue': instance.hue,
      'cosmetic': instance.cosmetic,
    };

_RoomMember _$RoomMemberFromJson(Map<String, dynamic> json) => _RoomMember(
  memberId: json['memberId'] as String,
  pseudonym: json['pseudonym'] as String,
  silhouette: json['silhouette'] == null
      ? const Silhouette()
      : Silhouette.fromJson(json['silhouette'] as Map<String, dynamic>),
  moodChip: json['moodChip'] as String? ?? '',
  live: json['live'] as bool? ?? false,
  muted: json['muted'] as bool? ?? false,
  isMe: json['isMe'] as bool? ?? false,
);

Map<String, dynamic> _$RoomMemberToJson(_RoomMember instance) =>
    <String, dynamic>{
      'memberId': instance.memberId,
      'pseudonym': instance.pseudonym,
      'silhouette': instance.silhouette,
      'moodChip': instance.moodChip,
      'live': instance.live,
      'muted': instance.muted,
      'isMe': instance.isMe,
    };

_ReceivedGesture _$ReceivedGestureFromJson(Map<String, dynamic> json) =>
    _ReceivedGesture(
      gestureId: json['gestureId'] as String,
      type: json['type'] as String,
      fromMemberId: json['fromMemberId'] as String,
      fromPseudonym: json['fromPseudonym'] as String,
      at: DateTime.parse(json['at'] as String),
    );

Map<String, dynamic> _$ReceivedGestureToJson(_ReceivedGesture instance) =>
    <String, dynamic>{
      'gestureId': instance.gestureId,
      'type': instance.type,
      'fromMemberId': instance.fromMemberId,
      'fromPseudonym': instance.fromPseudonym,
      'at': instance.at.toIso8601String(),
    };

_SentGesture _$SentGestureFromJson(Map<String, dynamic> json) => _SentGesture(
  gestureId: json['gestureId'] as String,
  type: json['type'] as String,
  target: json['target'] as String? ?? 'room',
  toMemberId: json['toMemberId'] as String?,
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$SentGestureToJson(_SentGesture instance) =>
    <String, dynamic>{
      'gestureId': instance.gestureId,
      'type': instance.type,
      'target': instance.target,
      'toMemberId': instance.toMemberId,
      'at': instance.at.toIso8601String(),
    };

_RoomGesture _$RoomGestureFromJson(Map<String, dynamic> json) => _RoomGesture(
  gestureId: json['gestureId'] as String,
  type: json['type'] as String,
  target: json['target'] as String? ?? 'room',
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$RoomGestureToJson(_RoomGesture instance) =>
    <String, dynamic>{
      'gestureId': instance.gestureId,
      'type': instance.type,
      'target': instance.target,
      'at': instance.at.toIso8601String(),
    };

_RoomMe _$RoomMeFromJson(Map<String, dynamic> json) => _RoomMe(
  memberId: json['memberId'] as String,
  pseudonym: json['pseudonym'] as String,
  moodChip: json['moodChip'] as String? ?? '',
  silhouette: json['silhouette'] == null
      ? null
      : Silhouette.fromJson(json['silhouette'] as Map<String, dynamic>),
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  surveyEligible: json['surveyEligible'] as bool? ?? false,
);

Map<String, dynamic> _$RoomMeToJson(_RoomMe instance) => <String, dynamic>{
  'memberId': instance.memberId,
  'pseudonym': instance.pseudonym,
  'moodChip': instance.moodChip,
  'silhouette': instance.silhouette,
  'joinedAt': instance.joinedAt.toIso8601String(),
  'surveyEligible': instance.surveyEligible,
};

_RoomGestures _$RoomGesturesFromJson(Map<String, dynamic> json) =>
    _RoomGestures(
      received:
          (json['received'] as List<dynamic>?)
              ?.map((e) => ReceivedGesture.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReceivedGesture>[],
      sent:
          (json['sent'] as List<dynamic>?)
              ?.map((e) => SentGesture.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SentGesture>[],
      recent:
          (json['recent'] as List<dynamic>?)
              ?.map((e) => RoomGesture.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RoomGesture>[],
    );

Map<String, dynamic> _$RoomGesturesToJson(_RoomGestures instance) =>
    <String, dynamic>{
      'received': instance.received,
      'sent': instance.sent,
      'recent': instance.recent,
    };

_RealtimeTopics _$RealtimeTopicsFromJson(Map<String, dynamic> json) =>
    _RealtimeTopics(
      roomTopic: json['roomTopic'] as String,
      memberTopic: json['memberTopic'] as String,
    );

Map<String, dynamic> _$RealtimeTopicsToJson(_RealtimeTopics instance) =>
    <String, dynamic>{
      'roomTopic': instance.roomTopic,
      'memberTopic': instance.memberTopic,
    };

_RoomDetail _$RoomDetailFromJson(Map<String, dynamic> json) => _RoomDetail(
  room: RoomInfo.fromJson(json['room'] as Map<String, dynamic>),
  me: RoomMe.fromJson(json['me'] as Map<String, dynamic>),
  counts: json['counts'] == null
      ? const RoomCounts()
      : RoomCounts.fromJson(json['counts'] as Map<String, dynamic>),
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => RoomMember.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <RoomMember>[],
  gestures: json['gestures'] == null
      ? const RoomGestures()
      : RoomGestures.fromJson(json['gestures'] as Map<String, dynamic>),
  realtime: RealtimeTopics.fromJson(json['realtime'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RoomDetailToJson(_RoomDetail instance) =>
    <String, dynamic>{
      'room': instance.room,
      'me': instance.me,
      'counts': instance.counts,
      'members': instance.members,
      'gestures': instance.gestures,
      'realtime': instance.realtime,
    };

_MatchInfo _$MatchInfoFromJson(Map<String, dynamic> json) => _MatchInfo(
  step: (json['step'] as num?)?.toInt() ?? 0,
  reentry: json['reentry'] as bool? ?? false,
  created: json['created'] as bool? ?? false,
  merged: json['merged'] as bool? ?? false,
);

Map<String, dynamic> _$MatchInfoToJson(_MatchInfo instance) =>
    <String, dynamic>{
      'step': instance.step,
      'reentry': instance.reentry,
      'created': instance.created,
      'merged': instance.merged,
    };

_RoomSummary _$RoomSummaryFromJson(Map<String, dynamic> json) => _RoomSummary(
  room: RoomInfo.fromJson(json['room'] as Map<String, dynamic>),
  me: RoomMe.fromJson(json['me'] as Map<String, dynamic>),
  counts: json['counts'] == null
      ? const RoomCounts()
      : RoomCounts.fromJson(json['counts'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RoomSummaryToJson(_RoomSummary instance) =>
    <String, dynamic>{
      'room': instance.room,
      'me': instance.me,
      'counts': instance.counts,
    };

_HeartbeatResult _$HeartbeatResultFromJson(Map<String, dynamic> json) =>
    _HeartbeatResult(
      room: RoomInfo.fromJson(json['room'] as Map<String, dynamic>),
      counts: json['counts'] == null
          ? const RoomCounts()
          : RoomCounts.fromJson(json['counts'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HeartbeatResultToJson(_HeartbeatResult instance) =>
    <String, dynamic>{'room': instance.room, 'counts': instance.counts};

_GestureAck _$GestureAckFromJson(Map<String, dynamic> json) => _GestureAck(
  gestureId: json['gestureId'] as String,
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$GestureAckToJson(_GestureAck instance) =>
    <String, dynamic>{
      'gestureId': instance.gestureId,
      'at': instance.at.toIso8601String(),
    };

_ReportAck _$ReportAckFromJson(Map<String, dynamic> json) => _ReportAck(
  reportId: json['reportId'] as String,
  showHelplines: json['showHelplines'] as bool? ?? false,
);

Map<String, dynamic> _$ReportAckToJson(_ReportAck instance) =>
    <String, dynamic>{
      'reportId': instance.reportId,
      'showHelplines': instance.showHelplines,
    };

_SafetyStanding _$SafetyStandingFromJson(Map<String, dynamic> json) =>
    _SafetyStanding(
      rooms: json['rooms'] as String? ?? 'available',
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
    );

Map<String, dynamic> _$SafetyStandingToJson(_SafetyStanding instance) =>
    <String, dynamic>{
      'rooms': instance.rooms,
      'until': instance.until?.toIso8601String(),
    };
