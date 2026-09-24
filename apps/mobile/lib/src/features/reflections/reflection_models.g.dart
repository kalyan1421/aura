// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReflectionAuthor _$ReflectionAuthorFromJson(Map<String, dynamic> json) =>
    _ReflectionAuthor(
      memberId: json['memberId'] as String,
      pseudonym: json['pseudonym'] as String,
    );

Map<String, dynamic> _$ReflectionAuthorToJson(_ReflectionAuthor instance) =>
    <String, dynamic>{
      'memberId': instance.memberId,
      'pseudonym': instance.pseudonym,
    };

_Reflection _$ReflectionFromJson(Map<String, dynamic> json) => _Reflection(
  reflectionId: json['reflectionId'] as String,
  status: json['status'] as String? ?? 'published',
  author: ReflectionAuthor.fromJson(json['author'] as Map<String, dynamic>),
  isMine: json['isMine'] as bool? ?? false,
  text: json['text'] as String? ?? '',
  createdAt: DateTime.parse(json['createdAt'] as String),
  publishedAt: json['publishedAt'] == null
      ? null
      : DateTime.parse(json['publishedAt'] as String),
  gestureCount: (json['gestureCount'] as num?)?.toInt(),
  rejectReason: json['rejectReason'] as String?,
  review: json['review'] as String?,
);

Map<String, dynamic> _$ReflectionToJson(_Reflection instance) =>
    <String, dynamic>{
      'reflectionId': instance.reflectionId,
      'status': instance.status,
      'author': instance.author,
      'isMine': instance.isMine,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
      'publishedAt': instance.publishedAt?.toIso8601String(),
      'gestureCount': instance.gestureCount,
      'rejectReason': instance.rejectReason,
      'review': instance.review,
    };

_ReflectionComposer _$ReflectionComposerFromJson(Map<String, dynamic> json) =>
    _ReflectionComposer(
      state: json['state'] as String? ?? 'open',
      maxChars: (json['maxChars'] as num?)?.toInt() ?? 200,
      perRoom: (json['perRoom'] as num?)?.toInt() ?? 3,
      remainingInRoom: (json['remainingInRoom'] as num?)?.toInt() ?? 3,
      remainingToday: (json['remainingToday'] as num?)?.toInt() ?? 10,
      slow: json['slow'] as bool? ?? false,
    );

Map<String, dynamic> _$ReflectionComposerToJson(_ReflectionComposer instance) =>
    <String, dynamic>{
      'state': instance.state,
      'maxChars': instance.maxChars,
      'perRoom': instance.perRoom,
      'remainingInRoom': instance.remainingInRoom,
      'remainingToday': instance.remainingToday,
      'slow': instance.slow,
    };

_ReflectionList _$ReflectionListFromJson(Map<String, dynamic> json) =>
    _ReflectionList(
      reflections:
          (json['reflections'] as List<dynamic>?)
              ?.map((e) => Reflection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Reflection>[],
      composer: json['composer'] == null
          ? const ReflectionComposer()
          : ReflectionComposer.fromJson(
              json['composer'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ReflectionListToJson(_ReflectionList instance) =>
    <String, dynamic>{
      'reflections': instance.reflections,
      'composer': instance.composer,
    };

_SendOutcome _$SendOutcomeFromJson(Map<String, dynamic> json) => _SendOutcome(
  reflectionId: json['reflectionId'] as String,
  status: json['status'] as String,
  rejectReason: json['rejectReason'] as String?,
  review: json['review'] as String?,
  showSupport: json['showSupport'] as bool? ?? false,
  reflection: json['reflection'] == null
      ? null
      : Reflection.fromJson(json['reflection'] as Map<String, dynamic>),
  composer: json['composer'] == null
      ? const ReflectionComposer()
      : ReflectionComposer.fromJson(json['composer'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SendOutcomeToJson(_SendOutcome instance) =>
    <String, dynamic>{
      'reflectionId': instance.reflectionId,
      'status': instance.status,
      'rejectReason': instance.rejectReason,
      'review': instance.review,
      'showSupport': instance.showSupport,
      'reflection': instance.reflection,
      'composer': instance.composer,
    };
