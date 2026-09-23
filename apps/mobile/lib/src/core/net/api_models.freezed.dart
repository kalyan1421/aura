// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Snapshot {

 SnapshotAvatar get avatar; SnapshotStreak get streak; SnapshotStarlight get starlight; String get serverTime; String get auraDay;
/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotCopyWith<Snapshot> get copyWith => _$SnapshotCopyWithImpl<Snapshot>(this as Snapshot, _$identity);

  /// Serializes this Snapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Snapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Snapshot&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.streak, _this.streak) || other.streak == _this.streak)&&(identical(other.starlight, _this.starlight) || other.starlight == _this.starlight)&&(identical(other.serverTime, _this.serverTime) || other.serverTime == _this.serverTime)&&(identical(other.auraDay, _this.auraDay) || other.auraDay == _this.auraDay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Snapshot;
  return Object.hash(runtimeType,_this.avatar,_this.streak,_this.starlight,_this.serverTime,_this.auraDay);
}

@override
String toString() {
  final _this = this as Snapshot;
  return 'Snapshot(avatar: ${_this.avatar}, streak: ${_this.streak}, starlight: ${_this.starlight}, serverTime: ${_this.serverTime}, auraDay: ${_this.auraDay})';
}


}

/// @nodoc
abstract mixin class $SnapshotCopyWith<$Res>  {
  factory $SnapshotCopyWith(Snapshot value, $Res Function(Snapshot) _then) = _$SnapshotCopyWithImpl;
@useResult
$Res call({
 SnapshotAvatar avatar, SnapshotStreak streak, SnapshotStarlight starlight, String serverTime, String auraDay
});


$SnapshotAvatarCopyWith<$Res> get avatar;$SnapshotStreakCopyWith<$Res> get streak;$SnapshotStarlightCopyWith<$Res> get starlight;

}
/// @nodoc
class _$SnapshotCopyWithImpl<$Res>
    implements $SnapshotCopyWith<$Res> {
  _$SnapshotCopyWithImpl(this._self, this._then);

  final Snapshot _self;
  final $Res Function(Snapshot) _then;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? avatar = null,Object? streak = null,Object? starlight = null,Object? serverTime = null,Object? auraDay = null,}) {
  return _then(Snapshot(
avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as SnapshotAvatar,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as SnapshotStreak,starlight: null == starlight ? _self.starlight : starlight // ignore: cast_nullable_to_non_nullable
as SnapshotStarlight,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as String,auraDay: null == auraDay ? _self.auraDay : auraDay // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotAvatarCopyWith<$Res> get avatar {
  
  return $SnapshotAvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotStreakCopyWith<$Res> get streak {
  
  return $SnapshotStreakCopyWith<$Res>(_self.streak, (value) {
    return _then(_self.copyWith(streak: value));
  });
}/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotStarlightCopyWith<$Res> get starlight {
  
  return $SnapshotStarlightCopyWith<$Res>(_self.starlight, (value) {
    return _then(_self.copyWith(starlight: value));
  });
}
}


/// Adds pattern-matching-related methods to [Snapshot].
extension SnapshotPatterns on Snapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Snapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Snapshot value)  $default,){
final _that = this;
switch (_that) {
case _Snapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Snapshot value)?  $default,){
final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SnapshotAvatar avatar,  SnapshotStreak streak,  SnapshotStarlight starlight,  String serverTime,  String auraDay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that.avatar,_that.streak,_that.starlight,_that.serverTime,_that.auraDay);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SnapshotAvatar avatar,  SnapshotStreak streak,  SnapshotStarlight starlight,  String serverTime,  String auraDay)  $default,) {final _that = this;
switch (_that) {
case _Snapshot():
return $default(_that.avatar,_that.streak,_that.starlight,_that.serverTime,_that.auraDay);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SnapshotAvatar avatar,  SnapshotStreak streak,  SnapshotStarlight starlight,  String serverTime,  String auraDay)?  $default,) {final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that.avatar,_that.streak,_that.starlight,_that.serverTime,_that.auraDay);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Snapshot extends Snapshot {
  const _Snapshot({required this.avatar, required this.streak, required this.starlight, required this.serverTime, required this.auraDay}): super._();
  factory _Snapshot.fromJson(Map<String, dynamic> json) => _$SnapshotFromJson(json);

@override final  SnapshotAvatar avatar;
@override final  SnapshotStreak streak;
@override final  SnapshotStarlight starlight;
@override final  String serverTime;
@override final  String auraDay;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotCopyWith<_Snapshot> get copyWith => __$SnapshotCopyWithImpl<_Snapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Snapshot&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.streak, streak) || other.streak == streak)&&(identical(other.starlight, starlight) || other.starlight == starlight)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime)&&(identical(other.auraDay, auraDay) || other.auraDay == auraDay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,avatar,streak,starlight,serverTime,auraDay);
}

@override
String toString() {
    return 'Snapshot(avatar: $avatar, streak: $streak, starlight: $starlight, serverTime: $serverTime, auraDay: $auraDay)';
}


}

/// @nodoc
abstract mixin class _$SnapshotCopyWith<$Res> implements $SnapshotCopyWith<$Res> {
  factory _$SnapshotCopyWith(_Snapshot value, $Res Function(_Snapshot) _then) = __$SnapshotCopyWithImpl;
@override @useResult
$Res call({
 SnapshotAvatar avatar, SnapshotStreak streak, SnapshotStarlight starlight, String serverTime, String auraDay
});


@override $SnapshotAvatarCopyWith<$Res> get avatar;@override $SnapshotStreakCopyWith<$Res> get streak;@override $SnapshotStarlightCopyWith<$Res> get starlight;

}
/// @nodoc
class __$SnapshotCopyWithImpl<$Res>
    implements _$SnapshotCopyWith<$Res> {
  __$SnapshotCopyWithImpl(this._self, this._then);

  final _Snapshot _self;
  final $Res Function(_Snapshot) _then;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? avatar = null,Object? streak = null,Object? starlight = null,Object? serverTime = null,Object? auraDay = null,}) {
  return _then(_Snapshot(
avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as SnapshotAvatar,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as SnapshotStreak,starlight: null == starlight ? _self.starlight : starlight // ignore: cast_nullable_to_non_nullable
as SnapshotStarlight,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as String,auraDay: null == auraDay ? _self.auraDay : auraDay // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotAvatarCopyWith<$Res> get avatar {
  
  return $SnapshotAvatarCopyWith<$Res>(_self.avatar, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotStreakCopyWith<$Res> get streak {
  
  return $SnapshotStreakCopyWith<$Res>(_self.streak, (value) {
    return _then(_self.copyWith(streak: value));
  });
}/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotStarlightCopyWith<$Res> get starlight {
  
  return $SnapshotStarlightCopyWith<$Res>(_self.starlight, (value) {
    return _then(_self.copyWith(starlight: value));
  });
}
}


/// @nodoc
mixin _$SnapshotAvatar {

 String get stage; double? get hue; bool get isResting; int get ringCount; int get glowLevel; int get constellationStars; List<String> get equippedCosmetics;
/// Create a copy of SnapshotAvatar
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotAvatarCopyWith<SnapshotAvatar> get copyWith => _$SnapshotAvatarCopyWithImpl<SnapshotAvatar>(this as SnapshotAvatar, _$identity);

  /// Serializes this SnapshotAvatar to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotAvatar;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotAvatar&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.hue, _this.hue) || other.hue == _this.hue)&&(identical(other.isResting, _this.isResting) || other.isResting == _this.isResting)&&(identical(other.ringCount, _this.ringCount) || other.ringCount == _this.ringCount)&&(identical(other.glowLevel, _this.glowLevel) || other.glowLevel == _this.glowLevel)&&(identical(other.constellationStars, _this.constellationStars) || other.constellationStars == _this.constellationStars)&&const DeepCollectionEquality().equals(other.equippedCosmetics, _this.equippedCosmetics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotAvatar;
  return Object.hash(runtimeType,_this.stage,_this.hue,_this.isResting,_this.ringCount,_this.glowLevel,_this.constellationStars,const DeepCollectionEquality().hash(_this.equippedCosmetics));
}

@override
String toString() {
  final _this = this as SnapshotAvatar;
  return 'SnapshotAvatar(stage: ${_this.stage}, hue: ${_this.hue}, isResting: ${_this.isResting}, ringCount: ${_this.ringCount}, glowLevel: ${_this.glowLevel}, constellationStars: ${_this.constellationStars}, equippedCosmetics: ${_this.equippedCosmetics})';
}


}

/// @nodoc
abstract mixin class $SnapshotAvatarCopyWith<$Res>  {
  factory $SnapshotAvatarCopyWith(SnapshotAvatar value, $Res Function(SnapshotAvatar) _then) = _$SnapshotAvatarCopyWithImpl;
@useResult
$Res call({
 String stage, double? hue, bool isResting, int ringCount, int glowLevel, int constellationStars, List<String> equippedCosmetics
});




}
/// @nodoc
class _$SnapshotAvatarCopyWithImpl<$Res>
    implements $SnapshotAvatarCopyWith<$Res> {
  _$SnapshotAvatarCopyWithImpl(this._self, this._then);

  final SnapshotAvatar _self;
  final $Res Function(SnapshotAvatar) _then;

/// Create a copy of SnapshotAvatar
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? hue = freezed,Object? isResting = null,Object? ringCount = null,Object? glowLevel = null,Object? constellationStars = null,Object? equippedCosmetics = null,}) {
  return _then(SnapshotAvatar(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,hue: freezed == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as double?,isResting: null == isResting ? _self.isResting : isResting // ignore: cast_nullable_to_non_nullable
as bool,ringCount: null == ringCount ? _self.ringCount : ringCount // ignore: cast_nullable_to_non_nullable
as int,glowLevel: null == glowLevel ? _self.glowLevel : glowLevel // ignore: cast_nullable_to_non_nullable
as int,constellationStars: null == constellationStars ? _self.constellationStars : constellationStars // ignore: cast_nullable_to_non_nullable
as int,equippedCosmetics: null == equippedCosmetics ? _self.equippedCosmetics : equippedCosmetics // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SnapshotAvatar].
extension SnapshotAvatarPatterns on SnapshotAvatar {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotAvatar value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotAvatar() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotAvatar value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotAvatar():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotAvatar value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotAvatar() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stage,  double? hue,  bool isResting,  int ringCount,  int glowLevel,  int constellationStars,  List<String> equippedCosmetics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotAvatar() when $default != null:
return $default(_that.stage,_that.hue,_that.isResting,_that.ringCount,_that.glowLevel,_that.constellationStars,_that.equippedCosmetics);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stage,  double? hue,  bool isResting,  int ringCount,  int glowLevel,  int constellationStars,  List<String> equippedCosmetics)  $default,) {final _that = this;
switch (_that) {
case _SnapshotAvatar():
return $default(_that.stage,_that.hue,_that.isResting,_that.ringCount,_that.glowLevel,_that.constellationStars,_that.equippedCosmetics);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stage,  double? hue,  bool isResting,  int ringCount,  int glowLevel,  int constellationStars,  List<String> equippedCosmetics)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotAvatar() when $default != null:
return $default(_that.stage,_that.hue,_that.isResting,_that.ringCount,_that.glowLevel,_that.constellationStars,_that.equippedCosmetics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SnapshotAvatar implements SnapshotAvatar {
  const _SnapshotAvatar({this.stage = 'spark', this.hue, this.isResting = false, this.ringCount = 0, this.glowLevel = 0, this.constellationStars = 0,  List<String> equippedCosmetics = const <String>[]}): _equippedCosmetics = equippedCosmetics;
  factory _SnapshotAvatar.fromJson(Map<String, dynamic> json) => _$SnapshotAvatarFromJson(json);

@override@JsonKey() final  String stage;
@override final  double? hue;
@override@JsonKey() final  bool isResting;
@override@JsonKey() final  int ringCount;
@override@JsonKey() final  int glowLevel;
@override@JsonKey() final  int constellationStars;
 final  List<String> _equippedCosmetics;
@override@JsonKey() List<String> get equippedCosmetics {
  if (_equippedCosmetics is EqualUnmodifiableListView) return _equippedCosmetics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_equippedCosmetics);
}


/// Create a copy of SnapshotAvatar
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotAvatarCopyWith<_SnapshotAvatar> get copyWith => __$SnapshotAvatarCopyWithImpl<_SnapshotAvatar>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotAvatarToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotAvatar&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.hue, hue) || other.hue == hue)&&(identical(other.isResting, isResting) || other.isResting == isResting)&&(identical(other.ringCount, ringCount) || other.ringCount == ringCount)&&(identical(other.glowLevel, glowLevel) || other.glowLevel == glowLevel)&&(identical(other.constellationStars, constellationStars) || other.constellationStars == constellationStars)&&const DeepCollectionEquality().equals(other.equippedCosmetics, _equippedCosmetics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,stage,hue,isResting,ringCount,glowLevel,constellationStars,const DeepCollectionEquality().hash(_equippedCosmetics));
}

@override
String toString() {
    return 'SnapshotAvatar(stage: $stage, hue: $hue, isResting: $isResting, ringCount: $ringCount, glowLevel: $glowLevel, constellationStars: $constellationStars, equippedCosmetics: $equippedCosmetics)';
}


}

/// @nodoc
abstract mixin class _$SnapshotAvatarCopyWith<$Res> implements $SnapshotAvatarCopyWith<$Res> {
  factory _$SnapshotAvatarCopyWith(_SnapshotAvatar value, $Res Function(_SnapshotAvatar) _then) = __$SnapshotAvatarCopyWithImpl;
@override @useResult
$Res call({
 String stage, double? hue, bool isResting, int ringCount, int glowLevel, int constellationStars, List<String> equippedCosmetics
});




}
/// @nodoc
class __$SnapshotAvatarCopyWithImpl<$Res>
    implements _$SnapshotAvatarCopyWith<$Res> {
  __$SnapshotAvatarCopyWithImpl(this._self, this._then);

  final _SnapshotAvatar _self;
  final $Res Function(_SnapshotAvatar) _then;

/// Create a copy of SnapshotAvatar
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? hue = freezed,Object? isResting = null,Object? ringCount = null,Object? glowLevel = null,Object? constellationStars = null,Object? equippedCosmetics = null,}) {
  return _then(_SnapshotAvatar(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,hue: freezed == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as double?,isResting: null == isResting ? _self.isResting : isResting // ignore: cast_nullable_to_non_nullable
as bool,ringCount: null == ringCount ? _self.ringCount : ringCount // ignore: cast_nullable_to_non_nullable
as int,glowLevel: null == glowLevel ? _self.glowLevel : glowLevel // ignore: cast_nullable_to_non_nullable
as int,constellationStars: null == constellationStars ? _self.constellationStars : constellationStars // ignore: cast_nullable_to_non_nullable
as int,equippedCosmetics: null == equippedCosmetics ? _self._equippedCosmetics : equippedCosmetics // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$SnapshotStreak {

 int get glowStreak; int get lifetimeGlowDays; int get restBank; int get earnCounter; String? get lastActiveDay;
/// Create a copy of SnapshotStreak
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotStreakCopyWith<SnapshotStreak> get copyWith => _$SnapshotStreakCopyWithImpl<SnapshotStreak>(this as SnapshotStreak, _$identity);

  /// Serializes this SnapshotStreak to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotStreak;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotStreak&&(identical(other.glowStreak, _this.glowStreak) || other.glowStreak == _this.glowStreak)&&(identical(other.lifetimeGlowDays, _this.lifetimeGlowDays) || other.lifetimeGlowDays == _this.lifetimeGlowDays)&&(identical(other.restBank, _this.restBank) || other.restBank == _this.restBank)&&(identical(other.earnCounter, _this.earnCounter) || other.earnCounter == _this.earnCounter)&&(identical(other.lastActiveDay, _this.lastActiveDay) || other.lastActiveDay == _this.lastActiveDay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotStreak;
  return Object.hash(runtimeType,_this.glowStreak,_this.lifetimeGlowDays,_this.restBank,_this.earnCounter,_this.lastActiveDay);
}

@override
String toString() {
  final _this = this as SnapshotStreak;
  return 'SnapshotStreak(glowStreak: ${_this.glowStreak}, lifetimeGlowDays: ${_this.lifetimeGlowDays}, restBank: ${_this.restBank}, earnCounter: ${_this.earnCounter}, lastActiveDay: ${_this.lastActiveDay})';
}


}

/// @nodoc
abstract mixin class $SnapshotStreakCopyWith<$Res>  {
  factory $SnapshotStreakCopyWith(SnapshotStreak value, $Res Function(SnapshotStreak) _then) = _$SnapshotStreakCopyWithImpl;
@useResult
$Res call({
 int glowStreak, int lifetimeGlowDays, int restBank, int earnCounter, String? lastActiveDay
});




}
/// @nodoc
class _$SnapshotStreakCopyWithImpl<$Res>
    implements $SnapshotStreakCopyWith<$Res> {
  _$SnapshotStreakCopyWithImpl(this._self, this._then);

  final SnapshotStreak _self;
  final $Res Function(SnapshotStreak) _then;

/// Create a copy of SnapshotStreak
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? glowStreak = null,Object? lifetimeGlowDays = null,Object? restBank = null,Object? earnCounter = null,Object? lastActiveDay = freezed,}) {
  return _then(SnapshotStreak(
glowStreak: null == glowStreak ? _self.glowStreak : glowStreak // ignore: cast_nullable_to_non_nullable
as int,lifetimeGlowDays: null == lifetimeGlowDays ? _self.lifetimeGlowDays : lifetimeGlowDays // ignore: cast_nullable_to_non_nullable
as int,restBank: null == restBank ? _self.restBank : restBank // ignore: cast_nullable_to_non_nullable
as int,earnCounter: null == earnCounter ? _self.earnCounter : earnCounter // ignore: cast_nullable_to_non_nullable
as int,lastActiveDay: freezed == lastActiveDay ? _self.lastActiveDay : lastActiveDay // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SnapshotStreak].
extension SnapshotStreakPatterns on SnapshotStreak {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotStreak value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotStreak() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotStreak value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotStreak():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotStreak value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotStreak() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int glowStreak,  int lifetimeGlowDays,  int restBank,  int earnCounter,  String? lastActiveDay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotStreak() when $default != null:
return $default(_that.glowStreak,_that.lifetimeGlowDays,_that.restBank,_that.earnCounter,_that.lastActiveDay);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int glowStreak,  int lifetimeGlowDays,  int restBank,  int earnCounter,  String? lastActiveDay)  $default,) {final _that = this;
switch (_that) {
case _SnapshotStreak():
return $default(_that.glowStreak,_that.lifetimeGlowDays,_that.restBank,_that.earnCounter,_that.lastActiveDay);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int glowStreak,  int lifetimeGlowDays,  int restBank,  int earnCounter,  String? lastActiveDay)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotStreak() when $default != null:
return $default(_that.glowStreak,_that.lifetimeGlowDays,_that.restBank,_that.earnCounter,_that.lastActiveDay);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SnapshotStreak implements SnapshotStreak {
  const _SnapshotStreak({this.glowStreak = 0, this.lifetimeGlowDays = 0, this.restBank = 1, this.earnCounter = 0, this.lastActiveDay});
  factory _SnapshotStreak.fromJson(Map<String, dynamic> json) => _$SnapshotStreakFromJson(json);

@override@JsonKey() final  int glowStreak;
@override@JsonKey() final  int lifetimeGlowDays;
@override@JsonKey() final  int restBank;
@override@JsonKey() final  int earnCounter;
@override final  String? lastActiveDay;

/// Create a copy of SnapshotStreak
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotStreakCopyWith<_SnapshotStreak> get copyWith => __$SnapshotStreakCopyWithImpl<_SnapshotStreak>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotStreakToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotStreak&&(identical(other.glowStreak, glowStreak) || other.glowStreak == glowStreak)&&(identical(other.lifetimeGlowDays, lifetimeGlowDays) || other.lifetimeGlowDays == lifetimeGlowDays)&&(identical(other.restBank, restBank) || other.restBank == restBank)&&(identical(other.earnCounter, earnCounter) || other.earnCounter == earnCounter)&&(identical(other.lastActiveDay, lastActiveDay) || other.lastActiveDay == lastActiveDay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,glowStreak,lifetimeGlowDays,restBank,earnCounter,lastActiveDay);
}

@override
String toString() {
    return 'SnapshotStreak(glowStreak: $glowStreak, lifetimeGlowDays: $lifetimeGlowDays, restBank: $restBank, earnCounter: $earnCounter, lastActiveDay: $lastActiveDay)';
}


}

/// @nodoc
abstract mixin class _$SnapshotStreakCopyWith<$Res> implements $SnapshotStreakCopyWith<$Res> {
  factory _$SnapshotStreakCopyWith(_SnapshotStreak value, $Res Function(_SnapshotStreak) _then) = __$SnapshotStreakCopyWithImpl;
@override @useResult
$Res call({
 int glowStreak, int lifetimeGlowDays, int restBank, int earnCounter, String? lastActiveDay
});




}
/// @nodoc
class __$SnapshotStreakCopyWithImpl<$Res>
    implements _$SnapshotStreakCopyWith<$Res> {
  __$SnapshotStreakCopyWithImpl(this._self, this._then);

  final _SnapshotStreak _self;
  final $Res Function(_SnapshotStreak) _then;

/// Create a copy of SnapshotStreak
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? glowStreak = null,Object? lifetimeGlowDays = null,Object? restBank = null,Object? earnCounter = null,Object? lastActiveDay = freezed,}) {
  return _then(_SnapshotStreak(
glowStreak: null == glowStreak ? _self.glowStreak : glowStreak // ignore: cast_nullable_to_non_nullable
as int,lifetimeGlowDays: null == lifetimeGlowDays ? _self.lifetimeGlowDays : lifetimeGlowDays // ignore: cast_nullable_to_non_nullable
as int,restBank: null == restBank ? _self.restBank : restBank // ignore: cast_nullable_to_non_nullable
as int,earnCounter: null == earnCounter ? _self.earnCounter : earnCounter // ignore: cast_nullable_to_non_nullable
as int,lastActiveDay: freezed == lastActiveDay ? _self.lastActiveDay : lastActiveDay // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SnapshotStarlight {

 int get total; int get today;
/// Create a copy of SnapshotStarlight
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotStarlightCopyWith<SnapshotStarlight> get copyWith => _$SnapshotStarlightCopyWithImpl<SnapshotStarlight>(this as SnapshotStarlight, _$identity);

  /// Serializes this SnapshotStarlight to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotStarlight;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotStarlight&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.today, _this.today) || other.today == _this.today));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotStarlight;
  return Object.hash(runtimeType,_this.total,_this.today);
}

@override
String toString() {
  final _this = this as SnapshotStarlight;
  return 'SnapshotStarlight(total: ${_this.total}, today: ${_this.today})';
}


}

/// @nodoc
abstract mixin class $SnapshotStarlightCopyWith<$Res>  {
  factory $SnapshotStarlightCopyWith(SnapshotStarlight value, $Res Function(SnapshotStarlight) _then) = _$SnapshotStarlightCopyWithImpl;
@useResult
$Res call({
 int total, int today
});




}
/// @nodoc
class _$SnapshotStarlightCopyWithImpl<$Res>
    implements $SnapshotStarlightCopyWith<$Res> {
  _$SnapshotStarlightCopyWithImpl(this._self, this._then);

  final SnapshotStarlight _self;
  final $Res Function(SnapshotStarlight) _then;

/// Create a copy of SnapshotStarlight
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? today = null,}) {
  return _then(SnapshotStarlight(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SnapshotStarlight].
extension SnapshotStarlightPatterns on SnapshotStarlight {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotStarlight value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotStarlight() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotStarlight value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotStarlight():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotStarlight value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotStarlight() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int today)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotStarlight() when $default != null:
return $default(_that.total,_that.today);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int today)  $default,) {final _that = this;
switch (_that) {
case _SnapshotStarlight():
return $default(_that.total,_that.today);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int today)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotStarlight() when $default != null:
return $default(_that.total,_that.today);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SnapshotStarlight implements SnapshotStarlight {
  const _SnapshotStarlight({this.total = 0, this.today = 0});
  factory _SnapshotStarlight.fromJson(Map<String, dynamic> json) => _$SnapshotStarlightFromJson(json);

@override@JsonKey() final  int total;
@override@JsonKey() final  int today;

/// Create a copy of SnapshotStarlight
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotStarlightCopyWith<_SnapshotStarlight> get copyWith => __$SnapshotStarlightCopyWithImpl<_SnapshotStarlight>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotStarlightToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotStarlight&&(identical(other.total, total) || other.total == total)&&(identical(other.today, today) || other.today == today));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,total,today);
}

@override
String toString() {
    return 'SnapshotStarlight(total: $total, today: $today)';
}


}

/// @nodoc
abstract mixin class _$SnapshotStarlightCopyWith<$Res> implements $SnapshotStarlightCopyWith<$Res> {
  factory _$SnapshotStarlightCopyWith(_SnapshotStarlight value, $Res Function(_SnapshotStarlight) _then) = __$SnapshotStarlightCopyWithImpl;
@override @useResult
$Res call({
 int total, int today
});




}
/// @nodoc
class __$SnapshotStarlightCopyWithImpl<$Res>
    implements _$SnapshotStarlightCopyWith<$Res> {
  __$SnapshotStarlightCopyWithImpl(this._self, this._then);

  final _SnapshotStarlight _self;
  final $Res Function(_SnapshotStarlight) _then;

/// Create a copy of SnapshotStarlight
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? today = null,}) {
  return _then(_SnapshotStarlight(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SyncMutation {

 String get id; String get entity; String get op; String get deviceTs; String get localDay; Map<String, dynamic> get payload;/// IANA zone `localDay` was stamped in; the server judges backfill and
/// eligibility in it (falls back to the profile zone when absent).
@JsonKey(includeIfNull: false) String? get tz;
/// Create a copy of SyncMutation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncMutationCopyWith<SyncMutation> get copyWith => _$SyncMutationCopyWithImpl<SyncMutation>(this as SyncMutation, _$identity);

  /// Serializes this SyncMutation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SyncMutation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncMutation&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&(identical(other.op, _this.op) || other.op == _this.op)&&(identical(other.deviceTs, _this.deviceTs) || other.deviceTs == _this.deviceTs)&&(identical(other.localDay, _this.localDay) || other.localDay == _this.localDay)&&const DeepCollectionEquality().equals(other.payload, _this.payload)&&(identical(other.tz, _this.tz) || other.tz == _this.tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SyncMutation;
  return Object.hash(runtimeType,_this.id,_this.entity,_this.op,_this.deviceTs,_this.localDay,const DeepCollectionEquality().hash(_this.payload),_this.tz);
}

@override
String toString() {
  final _this = this as SyncMutation;
  return 'SyncMutation(id: ${_this.id}, entity: ${_this.entity}, op: ${_this.op}, deviceTs: ${_this.deviceTs}, localDay: ${_this.localDay}, payload: ${_this.payload}, tz: ${_this.tz})';
}


}

/// @nodoc
abstract mixin class $SyncMutationCopyWith<$Res>  {
  factory $SyncMutationCopyWith(SyncMutation value, $Res Function(SyncMutation) _then) = _$SyncMutationCopyWithImpl;
@useResult
$Res call({
 String id, String entity, String op, String deviceTs, String localDay, Map<String, dynamic> payload,@JsonKey(includeIfNull: false) String? tz
});




}
/// @nodoc
class _$SyncMutationCopyWithImpl<$Res>
    implements $SyncMutationCopyWith<$Res> {
  _$SyncMutationCopyWithImpl(this._self, this._then);

  final SyncMutation _self;
  final $Res Function(SyncMutation) _then;

/// Create a copy of SyncMutation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entity = null,Object? op = null,Object? deviceTs = null,Object? localDay = null,Object? payload = null,Object? tz = freezed,}) {
  return _then(SyncMutation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as String,deviceTs: null == deviceTs ? _self.deviceTs : deviceTs // ignore: cast_nullable_to_non_nullable
as String,localDay: null == localDay ? _self.localDay : localDay // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncMutation].
extension SyncMutationPatterns on SyncMutation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncMutation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncMutation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncMutation value)  $default,){
final _that = this;
switch (_that) {
case _SyncMutation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncMutation value)?  $default,){
final _that = this;
switch (_that) {
case _SyncMutation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String entity,  String op,  String deviceTs,  String localDay,  Map<String, dynamic> payload, @JsonKey(includeIfNull: false)  String? tz)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncMutation() when $default != null:
return $default(_that.id,_that.entity,_that.op,_that.deviceTs,_that.localDay,_that.payload,_that.tz);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String entity,  String op,  String deviceTs,  String localDay,  Map<String, dynamic> payload, @JsonKey(includeIfNull: false)  String? tz)  $default,) {final _that = this;
switch (_that) {
case _SyncMutation():
return $default(_that.id,_that.entity,_that.op,_that.deviceTs,_that.localDay,_that.payload,_that.tz);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String entity,  String op,  String deviceTs,  String localDay,  Map<String, dynamic> payload, @JsonKey(includeIfNull: false)  String? tz)?  $default,) {final _that = this;
switch (_that) {
case _SyncMutation() when $default != null:
return $default(_that.id,_that.entity,_that.op,_that.deviceTs,_that.localDay,_that.payload,_that.tz);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncMutation implements SyncMutation {
  const _SyncMutation({required this.id, required this.entity, required this.op, required this.deviceTs, required this.localDay, required  Map<String, dynamic> payload, @JsonKey(includeIfNull: false) this.tz}): _payload = payload;
  factory _SyncMutation.fromJson(Map<String, dynamic> json) => _$SyncMutationFromJson(json);

@override final  String id;
@override final  String entity;
@override final  String op;
@override final  String deviceTs;
@override final  String localDay;
 final  Map<String, dynamic> _payload;
@override Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

/// IANA zone `localDay` was stamped in; the server judges backfill and
/// eligibility in it (falls back to the profile zone when absent).
@override@JsonKey(includeIfNull: false) final  String? tz;

/// Create a copy of SyncMutation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncMutationCopyWith<_SyncMutation> get copyWith => __$SyncMutationCopyWithImpl<_SyncMutation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncMutationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncMutation&&(identical(other.id, id) || other.id == id)&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.op, op) || other.op == op)&&(identical(other.deviceTs, deviceTs) || other.deviceTs == deviceTs)&&(identical(other.localDay, localDay) || other.localDay == localDay)&&const DeepCollectionEquality().equals(other.payload, _payload)&&(identical(other.tz, tz) || other.tz == tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,entity,op,deviceTs,localDay,const DeepCollectionEquality().hash(_payload),tz);
}

@override
String toString() {
    return 'SyncMutation(id: $id, entity: $entity, op: $op, deviceTs: $deviceTs, localDay: $localDay, payload: $payload, tz: $tz)';
}


}

/// @nodoc
abstract mixin class _$SyncMutationCopyWith<$Res> implements $SyncMutationCopyWith<$Res> {
  factory _$SyncMutationCopyWith(_SyncMutation value, $Res Function(_SyncMutation) _then) = __$SyncMutationCopyWithImpl;
@override @useResult
$Res call({
 String id, String entity, String op, String deviceTs, String localDay, Map<String, dynamic> payload,@JsonKey(includeIfNull: false) String? tz
});




}
/// @nodoc
class __$SyncMutationCopyWithImpl<$Res>
    implements _$SyncMutationCopyWith<$Res> {
  __$SyncMutationCopyWithImpl(this._self, this._then);

  final _SyncMutation _self;
  final $Res Function(_SyncMutation) _then;

/// Create a copy of SyncMutation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entity = null,Object? op = null,Object? deviceTs = null,Object? localDay = null,Object? payload = null,Object? tz = freezed,}) {
  return _then(_SyncMutation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as String,deviceTs: null == deviceTs ? _self.deviceTs : deviceTs // ignore: cast_nullable_to_non_nullable
as String,localDay: null == localDay ? _self.localDay : localDay // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MutationResult {

 String get id; String get status; String? get reason;
/// Create a copy of MutationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MutationResultCopyWith<MutationResult> get copyWith => _$MutationResultCopyWithImpl<MutationResult>(this as MutationResult, _$identity);

  /// Serializes this MutationResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MutationResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MutationResult&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.reason, _this.reason) || other.reason == _this.reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MutationResult;
  return Object.hash(runtimeType,_this.id,_this.status,_this.reason);
}

@override
String toString() {
  final _this = this as MutationResult;
  return 'MutationResult(id: ${_this.id}, status: ${_this.status}, reason: ${_this.reason})';
}


}

/// @nodoc
abstract mixin class $MutationResultCopyWith<$Res>  {
  factory $MutationResultCopyWith(MutationResult value, $Res Function(MutationResult) _then) = _$MutationResultCopyWithImpl;
@useResult
$Res call({
 String id, String status, String? reason
});




}
/// @nodoc
class _$MutationResultCopyWithImpl<$Res>
    implements $MutationResultCopyWith<$Res> {
  _$MutationResultCopyWithImpl(this._self, this._then);

  final MutationResult _self;
  final $Res Function(MutationResult) _then;

/// Create a copy of MutationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? reason = freezed,}) {
  return _then(MutationResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MutationResult].
extension MutationResultPatterns on MutationResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MutationResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MutationResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MutationResult value)  $default,){
final _that = this;
switch (_that) {
case _MutationResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MutationResult value)?  $default,){
final _that = this;
switch (_that) {
case _MutationResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MutationResult() when $default != null:
return $default(_that.id,_that.status,_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _MutationResult():
return $default(_that.id,_that.status,_that.reason);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _MutationResult() when $default != null:
return $default(_that.id,_that.status,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MutationResult implements MutationResult {
  const _MutationResult({required this.id, required this.status, this.reason});
  factory _MutationResult.fromJson(Map<String, dynamic> json) => _$MutationResultFromJson(json);

@override final  String id;
@override final  String status;
@override final  String? reason;

/// Create a copy of MutationResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MutationResultCopyWith<_MutationResult> get copyWith => __$MutationResultCopyWithImpl<_MutationResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MutationResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MutationResult&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,status,reason);
}

@override
String toString() {
    return 'MutationResult(id: $id, status: $status, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$MutationResultCopyWith<$Res> implements $MutationResultCopyWith<$Res> {
  factory _$MutationResultCopyWith(_MutationResult value, $Res Function(_MutationResult) _then) = __$MutationResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String status, String? reason
});




}
/// @nodoc
class __$MutationResultCopyWithImpl<$Res>
    implements _$MutationResultCopyWith<$Res> {
  __$MutationResultCopyWithImpl(this._self, this._then);

  final _MutationResult _self;
  final $Res Function(_MutationResult) _then;

/// Create a copy of MutationResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? reason = freezed,}) {
  return _then(_MutationResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PushResponse {

 List<MutationResult> get results; Snapshot? get snapshot;
/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushResponseCopyWith<PushResponse> get copyWith => _$PushResponseCopyWithImpl<PushResponse>(this as PushResponse, _$identity);

  /// Serializes this PushResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PushResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushResponse&&const DeepCollectionEquality().equals(other.results, _this.results)&&(identical(other.snapshot, _this.snapshot) || other.snapshot == _this.snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PushResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.results),_this.snapshot);
}

@override
String toString() {
  final _this = this as PushResponse;
  return 'PushResponse(results: ${_this.results}, snapshot: ${_this.snapshot})';
}


}

/// @nodoc
abstract mixin class $PushResponseCopyWith<$Res>  {
  factory $PushResponseCopyWith(PushResponse value, $Res Function(PushResponse) _then) = _$PushResponseCopyWithImpl;
@useResult
$Res call({
 List<MutationResult> results, Snapshot? snapshot
});


$SnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class _$PushResponseCopyWithImpl<$Res>
    implements $PushResponseCopyWith<$Res> {
  _$PushResponseCopyWithImpl(this._self, this._then);

  final PushResponse _self;
  final $Res Function(PushResponse) _then;

/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? results = null,Object? snapshot = freezed,}) {
  return _then(PushResponse(
results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<MutationResult>,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as Snapshot?,
  ));
}
/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $SnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [PushResponse].
extension PushResponsePatterns on PushResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushResponse value)  $default,){
final _that = this;
switch (_that) {
case _PushResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PushResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MutationResult> results,  Snapshot? snapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushResponse() when $default != null:
return $default(_that.results,_that.snapshot);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MutationResult> results,  Snapshot? snapshot)  $default,) {final _that = this;
switch (_that) {
case _PushResponse():
return $default(_that.results,_that.snapshot);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MutationResult> results,  Snapshot? snapshot)?  $default,) {final _that = this;
switch (_that) {
case _PushResponse() when $default != null:
return $default(_that.results,_that.snapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushResponse implements PushResponse {
  const _PushResponse({ List<MutationResult> results = const <MutationResult>[], this.snapshot}): _results = results;
  factory _PushResponse.fromJson(Map<String, dynamic> json) => _$PushResponseFromJson(json);

 final  List<MutationResult> _results;
@override@JsonKey() List<MutationResult> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}

@override final  Snapshot? snapshot;

/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushResponseCopyWith<_PushResponse> get copyWith => __$PushResponseCopyWithImpl<_PushResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushResponse&&const DeepCollectionEquality().equals(other.results, _results)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_results),snapshot);
}

@override
String toString() {
    return 'PushResponse(results: $results, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class _$PushResponseCopyWith<$Res> implements $PushResponseCopyWith<$Res> {
  factory _$PushResponseCopyWith(_PushResponse value, $Res Function(_PushResponse) _then) = __$PushResponseCopyWithImpl;
@override @useResult
$Res call({
 List<MutationResult> results, Snapshot? snapshot
});


@override $SnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class __$PushResponseCopyWithImpl<$Res>
    implements _$PushResponseCopyWith<$Res> {
  __$PushResponseCopyWithImpl(this._self, this._then);

  final _PushResponse _self;
  final $Res Function(_PushResponse) _then;

/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? results = null,Object? snapshot = freezed,}) {
  return _then(_PushResponse(
results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<MutationResult>,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as Snapshot?,
  ));
}

/// Create a copy of PushResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $SnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// @nodoc
mixin _$ProfileRequest {

 String get birthDate; String get uiLocale; String get timezone; String? get country;/// Platform age band read before sign-in (F8 REQ-ACC-04/10):
/// `under13` | `under18` | `adult`. Sent only when set; the server keeps
/// the invisible under-18 flag and never returns it.
@JsonKey(includeIfNull: false) String? get ageSignal;
/// Create a copy of ProfileRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileRequestCopyWith<ProfileRequest> get copyWith => _$ProfileRequestCopyWithImpl<ProfileRequest>(this as ProfileRequest, _$identity);

  /// Serializes this ProfileRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileRequest&&(identical(other.birthDate, _this.birthDate) || other.birthDate == _this.birthDate)&&(identical(other.uiLocale, _this.uiLocale) || other.uiLocale == _this.uiLocale)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.ageSignal, _this.ageSignal) || other.ageSignal == _this.ageSignal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileRequest;
  return Object.hash(runtimeType,_this.birthDate,_this.uiLocale,_this.timezone,_this.country,_this.ageSignal);
}

@override
String toString() {
  final _this = this as ProfileRequest;
  return 'ProfileRequest(birthDate: ${_this.birthDate}, uiLocale: ${_this.uiLocale}, timezone: ${_this.timezone}, country: ${_this.country}, ageSignal: ${_this.ageSignal})';
}


}

/// @nodoc
abstract mixin class $ProfileRequestCopyWith<$Res>  {
  factory $ProfileRequestCopyWith(ProfileRequest value, $Res Function(ProfileRequest) _then) = _$ProfileRequestCopyWithImpl;
@useResult
$Res call({
 String birthDate, String uiLocale, String timezone, String? country,@JsonKey(includeIfNull: false) String? ageSignal
});




}
/// @nodoc
class _$ProfileRequestCopyWithImpl<$Res>
    implements $ProfileRequestCopyWith<$Res> {
  _$ProfileRequestCopyWithImpl(this._self, this._then);

  final ProfileRequest _self;
  final $Res Function(ProfileRequest) _then;

/// Create a copy of ProfileRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? birthDate = null,Object? uiLocale = null,Object? timezone = null,Object? country = freezed,Object? ageSignal = freezed,}) {
  return _then(ProfileRequest(
birthDate: null == birthDate ? _self.birthDate : birthDate // ignore: cast_nullable_to_non_nullable
as String,uiLocale: null == uiLocale ? _self.uiLocale : uiLocale // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,ageSignal: freezed == ageSignal ? _self.ageSignal : ageSignal // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileRequest].
extension ProfileRequestPatterns on ProfileRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileRequest value)  $default,){
final _that = this;
switch (_that) {
case _ProfileRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String birthDate,  String uiLocale,  String timezone,  String? country, @JsonKey(includeIfNull: false)  String? ageSignal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileRequest() when $default != null:
return $default(_that.birthDate,_that.uiLocale,_that.timezone,_that.country,_that.ageSignal);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String birthDate,  String uiLocale,  String timezone,  String? country, @JsonKey(includeIfNull: false)  String? ageSignal)  $default,) {final _that = this;
switch (_that) {
case _ProfileRequest():
return $default(_that.birthDate,_that.uiLocale,_that.timezone,_that.country,_that.ageSignal);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String birthDate,  String uiLocale,  String timezone,  String? country, @JsonKey(includeIfNull: false)  String? ageSignal)?  $default,) {final _that = this;
switch (_that) {
case _ProfileRequest() when $default != null:
return $default(_that.birthDate,_that.uiLocale,_that.timezone,_that.country,_that.ageSignal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileRequest implements ProfileRequest {
  const _ProfileRequest({required this.birthDate, required this.uiLocale, required this.timezone, this.country, @JsonKey(includeIfNull: false) this.ageSignal});
  factory _ProfileRequest.fromJson(Map<String, dynamic> json) => _$ProfileRequestFromJson(json);

@override final  String birthDate;
@override final  String uiLocale;
@override final  String timezone;
@override final  String? country;
/// Platform age band read before sign-in (F8 REQ-ACC-04/10):
/// `under13` | `under18` | `adult`. Sent only when set; the server keeps
/// the invisible under-18 flag and never returns it.
@override@JsonKey(includeIfNull: false) final  String? ageSignal;

/// Create a copy of ProfileRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileRequestCopyWith<_ProfileRequest> get copyWith => __$ProfileRequestCopyWithImpl<_ProfileRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileRequest&&(identical(other.birthDate, birthDate) || other.birthDate == birthDate)&&(identical(other.uiLocale, uiLocale) || other.uiLocale == uiLocale)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.country, country) || other.country == country)&&(identical(other.ageSignal, ageSignal) || other.ageSignal == ageSignal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,birthDate,uiLocale,timezone,country,ageSignal);
}

@override
String toString() {
    return 'ProfileRequest(birthDate: $birthDate, uiLocale: $uiLocale, timezone: $timezone, country: $country, ageSignal: $ageSignal)';
}


}

/// @nodoc
abstract mixin class _$ProfileRequestCopyWith<$Res> implements $ProfileRequestCopyWith<$Res> {
  factory _$ProfileRequestCopyWith(_ProfileRequest value, $Res Function(_ProfileRequest) _then) = __$ProfileRequestCopyWithImpl;
@override @useResult
$Res call({
 String birthDate, String uiLocale, String timezone, String? country,@JsonKey(includeIfNull: false) String? ageSignal
});




}
/// @nodoc
class __$ProfileRequestCopyWithImpl<$Res>
    implements _$ProfileRequestCopyWith<$Res> {
  __$ProfileRequestCopyWithImpl(this._self, this._then);

  final _ProfileRequest _self;
  final $Res Function(_ProfileRequest) _then;

/// Create a copy of ProfileRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? birthDate = null,Object? uiLocale = null,Object? timezone = null,Object? country = freezed,Object? ageSignal = freezed,}) {
  return _then(_ProfileRequest(
birthDate: null == birthDate ? _self.birthDate : birthDate // ignore: cast_nullable_to_non_nullable
as String,uiLocale: null == uiLocale ? _self.uiLocale : uiLocale // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,ageSignal: freezed == ageSignal ? _self.ageSignal : ageSignal // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DataKeyResponse {

 String get keyId; String get dataKey;
/// Create a copy of DataKeyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DataKeyResponseCopyWith<DataKeyResponse> get copyWith => _$DataKeyResponseCopyWithImpl<DataKeyResponse>(this as DataKeyResponse, _$identity);

  /// Serializes this DataKeyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DataKeyResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DataKeyResponse&&(identical(other.keyId, _this.keyId) || other.keyId == _this.keyId)&&(identical(other.dataKey, _this.dataKey) || other.dataKey == _this.dataKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DataKeyResponse;
  return Object.hash(runtimeType,_this.keyId,_this.dataKey);
}

@override
String toString() {
  final _this = this as DataKeyResponse;
  return 'DataKeyResponse(keyId: ${_this.keyId}, dataKey: ${_this.dataKey})';
}


}

/// @nodoc
abstract mixin class $DataKeyResponseCopyWith<$Res>  {
  factory $DataKeyResponseCopyWith(DataKeyResponse value, $Res Function(DataKeyResponse) _then) = _$DataKeyResponseCopyWithImpl;
@useResult
$Res call({
 String keyId, String dataKey
});




}
/// @nodoc
class _$DataKeyResponseCopyWithImpl<$Res>
    implements $DataKeyResponseCopyWith<$Res> {
  _$DataKeyResponseCopyWithImpl(this._self, this._then);

  final DataKeyResponse _self;
  final $Res Function(DataKeyResponse) _then;

/// Create a copy of DataKeyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? keyId = null,Object? dataKey = null,}) {
  return _then(DataKeyResponse(
keyId: null == keyId ? _self.keyId : keyId // ignore: cast_nullable_to_non_nullable
as String,dataKey: null == dataKey ? _self.dataKey : dataKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DataKeyResponse].
extension DataKeyResponsePatterns on DataKeyResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DataKeyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DataKeyResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DataKeyResponse value)  $default,){
final _that = this;
switch (_that) {
case _DataKeyResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DataKeyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _DataKeyResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String keyId,  String dataKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DataKeyResponse() when $default != null:
return $default(_that.keyId,_that.dataKey);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String keyId,  String dataKey)  $default,) {final _that = this;
switch (_that) {
case _DataKeyResponse():
return $default(_that.keyId,_that.dataKey);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String keyId,  String dataKey)?  $default,) {final _that = this;
switch (_that) {
case _DataKeyResponse() when $default != null:
return $default(_that.keyId,_that.dataKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DataKeyResponse implements DataKeyResponse {
  const _DataKeyResponse({required this.keyId, required this.dataKey});
  factory _DataKeyResponse.fromJson(Map<String, dynamic> json) => _$DataKeyResponseFromJson(json);

@override final  String keyId;
@override final  String dataKey;

/// Create a copy of DataKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DataKeyResponseCopyWith<_DataKeyResponse> get copyWith => __$DataKeyResponseCopyWithImpl<_DataKeyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DataKeyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DataKeyResponse&&(identical(other.keyId, keyId) || other.keyId == keyId)&&(identical(other.dataKey, dataKey) || other.dataKey == dataKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,keyId,dataKey);
}

@override
String toString() {
    return 'DataKeyResponse(keyId: $keyId, dataKey: $dataKey)';
}


}

/// @nodoc
abstract mixin class _$DataKeyResponseCopyWith<$Res> implements $DataKeyResponseCopyWith<$Res> {
  factory _$DataKeyResponseCopyWith(_DataKeyResponse value, $Res Function(_DataKeyResponse) _then) = __$DataKeyResponseCopyWithImpl;
@override @useResult
$Res call({
 String keyId, String dataKey
});




}
/// @nodoc
class __$DataKeyResponseCopyWithImpl<$Res>
    implements _$DataKeyResponseCopyWith<$Res> {
  __$DataKeyResponseCopyWithImpl(this._self, this._then);

  final _DataKeyResponse _self;
  final $Res Function(_DataKeyResponse) _then;

/// Create a copy of DataKeyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? keyId = null,Object? dataKey = null,}) {
  return _then(_DataKeyResponse(
keyId: null == keyId ? _self.keyId : keyId // ignore: cast_nullable_to_non_nullable
as String,dataKey: null == dataKey ? _self.dataKey : dataKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AccountStatus {

 String? get deletionScheduledFor;
/// Create a copy of AccountStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountStatusCopyWith<AccountStatus> get copyWith => _$AccountStatusCopyWithImpl<AccountStatus>(this as AccountStatus, _$identity);

  /// Serializes this AccountStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AccountStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountStatus&&(identical(other.deletionScheduledFor, _this.deletionScheduledFor) || other.deletionScheduledFor == _this.deletionScheduledFor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AccountStatus;
  return Object.hash(runtimeType,_this.deletionScheduledFor);
}

@override
String toString() {
  final _this = this as AccountStatus;
  return 'AccountStatus(deletionScheduledFor: ${_this.deletionScheduledFor})';
}


}

/// @nodoc
abstract mixin class $AccountStatusCopyWith<$Res>  {
  factory $AccountStatusCopyWith(AccountStatus value, $Res Function(AccountStatus) _then) = _$AccountStatusCopyWithImpl;
@useResult
$Res call({
 String? deletionScheduledFor
});




}
/// @nodoc
class _$AccountStatusCopyWithImpl<$Res>
    implements $AccountStatusCopyWith<$Res> {
  _$AccountStatusCopyWithImpl(this._self, this._then);

  final AccountStatus _self;
  final $Res Function(AccountStatus) _then;

/// Create a copy of AccountStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deletionScheduledFor = freezed,}) {
  return _then(AccountStatus(
deletionScheduledFor: freezed == deletionScheduledFor ? _self.deletionScheduledFor : deletionScheduledFor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountStatus].
extension AccountStatusPatterns on AccountStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountStatus value)  $default,){
final _that = this;
switch (_that) {
case _AccountStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountStatus value)?  $default,){
final _that = this;
switch (_that) {
case _AccountStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? deletionScheduledFor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountStatus() when $default != null:
return $default(_that.deletionScheduledFor);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? deletionScheduledFor)  $default,) {final _that = this;
switch (_that) {
case _AccountStatus():
return $default(_that.deletionScheduledFor);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? deletionScheduledFor)?  $default,) {final _that = this;
switch (_that) {
case _AccountStatus() when $default != null:
return $default(_that.deletionScheduledFor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountStatus extends AccountStatus {
  const _AccountStatus({this.deletionScheduledFor}): super._();
  factory _AccountStatus.fromJson(Map<String, dynamic> json) => _$AccountStatusFromJson(json);

@override final  String? deletionScheduledFor;

/// Create a copy of AccountStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountStatusCopyWith<_AccountStatus> get copyWith => __$AccountStatusCopyWithImpl<_AccountStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountStatus&&(identical(other.deletionScheduledFor, deletionScheduledFor) || other.deletionScheduledFor == deletionScheduledFor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,deletionScheduledFor);
}

@override
String toString() {
    return 'AccountStatus(deletionScheduledFor: $deletionScheduledFor)';
}


}

/// @nodoc
abstract mixin class _$AccountStatusCopyWith<$Res> implements $AccountStatusCopyWith<$Res> {
  factory _$AccountStatusCopyWith(_AccountStatus value, $Res Function(_AccountStatus) _then) = __$AccountStatusCopyWithImpl;
@override @useResult
$Res call({
 String? deletionScheduledFor
});




}
/// @nodoc
class __$AccountStatusCopyWithImpl<$Res>
    implements _$AccountStatusCopyWith<$Res> {
  __$AccountStatusCopyWithImpl(this._self, this._then);

  final _AccountStatus _self;
  final $Res Function(_AccountStatus) _then;

/// Create a copy of AccountStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deletionScheduledFor = freezed,}) {
  return _then(_AccountStatus(
deletionScheduledFor: freezed == deletionScheduledFor ? _self.deletionScheduledFor : deletionScheduledFor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MediaUploadUrl {

 String get path; String get uploadUrl; String? get expiresAt;
/// Create a copy of MediaUploadUrl
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaUploadUrlCopyWith<MediaUploadUrl> get copyWith => _$MediaUploadUrlCopyWithImpl<MediaUploadUrl>(this as MediaUploadUrl, _$identity);

  /// Serializes this MediaUploadUrl to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MediaUploadUrl;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaUploadUrl&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.uploadUrl, _this.uploadUrl) || other.uploadUrl == _this.uploadUrl)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MediaUploadUrl;
  return Object.hash(runtimeType,_this.path,_this.uploadUrl,_this.expiresAt);
}

@override
String toString() {
  final _this = this as MediaUploadUrl;
  return 'MediaUploadUrl(path: ${_this.path}, uploadUrl: ${_this.uploadUrl}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $MediaUploadUrlCopyWith<$Res>  {
  factory $MediaUploadUrlCopyWith(MediaUploadUrl value, $Res Function(MediaUploadUrl) _then) = _$MediaUploadUrlCopyWithImpl;
@useResult
$Res call({
 String path, String uploadUrl, String? expiresAt
});




}
/// @nodoc
class _$MediaUploadUrlCopyWithImpl<$Res>
    implements $MediaUploadUrlCopyWith<$Res> {
  _$MediaUploadUrlCopyWithImpl(this._self, this._then);

  final MediaUploadUrl _self;
  final $Res Function(MediaUploadUrl) _then;

/// Create a copy of MediaUploadUrl
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? uploadUrl = null,Object? expiresAt = freezed,}) {
  return _then(MediaUploadUrl(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,uploadUrl: null == uploadUrl ? _self.uploadUrl : uploadUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaUploadUrl].
extension MediaUploadUrlPatterns on MediaUploadUrl {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaUploadUrl value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaUploadUrl() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaUploadUrl value)  $default,){
final _that = this;
switch (_that) {
case _MediaUploadUrl():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaUploadUrl value)?  $default,){
final _that = this;
switch (_that) {
case _MediaUploadUrl() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String uploadUrl,  String? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaUploadUrl() when $default != null:
return $default(_that.path,_that.uploadUrl,_that.expiresAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String uploadUrl,  String? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _MediaUploadUrl():
return $default(_that.path,_that.uploadUrl,_that.expiresAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String uploadUrl,  String? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _MediaUploadUrl() when $default != null:
return $default(_that.path,_that.uploadUrl,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaUploadUrl implements MediaUploadUrl {
  const _MediaUploadUrl({required this.path, required this.uploadUrl, this.expiresAt});
  factory _MediaUploadUrl.fromJson(Map<String, dynamic> json) => _$MediaUploadUrlFromJson(json);

@override final  String path;
@override final  String uploadUrl;
@override final  String? expiresAt;

/// Create a copy of MediaUploadUrl
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaUploadUrlCopyWith<_MediaUploadUrl> get copyWith => __$MediaUploadUrlCopyWithImpl<_MediaUploadUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaUploadUrlToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaUploadUrl&&(identical(other.path, path) || other.path == path)&&(identical(other.uploadUrl, uploadUrl) || other.uploadUrl == uploadUrl)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,uploadUrl,expiresAt);
}

@override
String toString() {
    return 'MediaUploadUrl(path: $path, uploadUrl: $uploadUrl, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$MediaUploadUrlCopyWith<$Res> implements $MediaUploadUrlCopyWith<$Res> {
  factory _$MediaUploadUrlCopyWith(_MediaUploadUrl value, $Res Function(_MediaUploadUrl) _then) = __$MediaUploadUrlCopyWithImpl;
@override @useResult
$Res call({
 String path, String uploadUrl, String? expiresAt
});




}
/// @nodoc
class __$MediaUploadUrlCopyWithImpl<$Res>
    implements _$MediaUploadUrlCopyWith<$Res> {
  __$MediaUploadUrlCopyWithImpl(this._self, this._then);

  final _MediaUploadUrl _self;
  final $Res Function(_MediaUploadUrl) _then;

/// Create a copy of MediaUploadUrl
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? uploadUrl = null,Object? expiresAt = freezed,}) {
  return _then(_MediaUploadUrl(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,uploadUrl: null == uploadUrl ? _self.uploadUrl : uploadUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MediaDownloadUrl {

 String get downloadUrl; String? get expiresAt;
/// Create a copy of MediaDownloadUrl
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaDownloadUrlCopyWith<MediaDownloadUrl> get copyWith => _$MediaDownloadUrlCopyWithImpl<MediaDownloadUrl>(this as MediaDownloadUrl, _$identity);

  /// Serializes this MediaDownloadUrl to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MediaDownloadUrl;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaDownloadUrl&&(identical(other.downloadUrl, _this.downloadUrl) || other.downloadUrl == _this.downloadUrl)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MediaDownloadUrl;
  return Object.hash(runtimeType,_this.downloadUrl,_this.expiresAt);
}

@override
String toString() {
  final _this = this as MediaDownloadUrl;
  return 'MediaDownloadUrl(downloadUrl: ${_this.downloadUrl}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $MediaDownloadUrlCopyWith<$Res>  {
  factory $MediaDownloadUrlCopyWith(MediaDownloadUrl value, $Res Function(MediaDownloadUrl) _then) = _$MediaDownloadUrlCopyWithImpl;
@useResult
$Res call({
 String downloadUrl, String? expiresAt
});




}
/// @nodoc
class _$MediaDownloadUrlCopyWithImpl<$Res>
    implements $MediaDownloadUrlCopyWith<$Res> {
  _$MediaDownloadUrlCopyWithImpl(this._self, this._then);

  final MediaDownloadUrl _self;
  final $Res Function(MediaDownloadUrl) _then;

/// Create a copy of MediaDownloadUrl
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? downloadUrl = null,Object? expiresAt = freezed,}) {
  return _then(MediaDownloadUrl(
downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaDownloadUrl].
extension MediaDownloadUrlPatterns on MediaDownloadUrl {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaDownloadUrl value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaDownloadUrl() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaDownloadUrl value)  $default,){
final _that = this;
switch (_that) {
case _MediaDownloadUrl():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaDownloadUrl value)?  $default,){
final _that = this;
switch (_that) {
case _MediaDownloadUrl() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String downloadUrl,  String? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaDownloadUrl() when $default != null:
return $default(_that.downloadUrl,_that.expiresAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String downloadUrl,  String? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _MediaDownloadUrl():
return $default(_that.downloadUrl,_that.expiresAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String downloadUrl,  String? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _MediaDownloadUrl() when $default != null:
return $default(_that.downloadUrl,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaDownloadUrl implements MediaDownloadUrl {
  const _MediaDownloadUrl({required this.downloadUrl, this.expiresAt});
  factory _MediaDownloadUrl.fromJson(Map<String, dynamic> json) => _$MediaDownloadUrlFromJson(json);

@override final  String downloadUrl;
@override final  String? expiresAt;

/// Create a copy of MediaDownloadUrl
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaDownloadUrlCopyWith<_MediaDownloadUrl> get copyWith => __$MediaDownloadUrlCopyWithImpl<_MediaDownloadUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaDownloadUrlToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaDownloadUrl&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,downloadUrl,expiresAt);
}

@override
String toString() {
    return 'MediaDownloadUrl(downloadUrl: $downloadUrl, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$MediaDownloadUrlCopyWith<$Res> implements $MediaDownloadUrlCopyWith<$Res> {
  factory _$MediaDownloadUrlCopyWith(_MediaDownloadUrl value, $Res Function(_MediaDownloadUrl) _then) = __$MediaDownloadUrlCopyWithImpl;
@override @useResult
$Res call({
 String downloadUrl, String? expiresAt
});




}
/// @nodoc
class __$MediaDownloadUrlCopyWithImpl<$Res>
    implements _$MediaDownloadUrlCopyWith<$Res> {
  __$MediaDownloadUrlCopyWithImpl(this._self, this._then);

  final _MediaDownloadUrl _self;
  final $Res Function(_MediaDownloadUrl) _then;

/// Create a copy of MediaDownloadUrl
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? downloadUrl = null,Object? expiresAt = freezed,}) {
  return _then(_MediaDownloadUrl(
downloadUrl: null == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
