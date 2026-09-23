// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LanternHour implements DiagnosticableTreeMixin {

/// The room's region clock (e.g. `Asia/Kolkata`).
 String get timezone; bool get active;/// The current window while [active], else the next one.
 DateTime get startsAt; DateTime get endsAt;
/// Create a copy of LanternHour
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LanternHourCopyWith<LanternHour> get copyWith => _$LanternHourCopyWithImpl<LanternHour>(this as LanternHour, _$identity);

  /// Serializes this LanternHour to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as LanternHour;
  properties
    ..add(DiagnosticsProperty('type', 'LanternHour'))
    ..add(DiagnosticsProperty('timezone', _this.timezone))..add(DiagnosticsProperty('active', _this.active))..add(DiagnosticsProperty('startsAt', _this.startsAt))..add(DiagnosticsProperty('endsAt', _this.endsAt));
}

@override
bool operator ==(Object other) {
  final _this = this as LanternHour;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LanternHour&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LanternHour;
  return Object.hash(runtimeType,_this.timezone,_this.active,_this.startsAt,_this.endsAt);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as LanternHour;
  return 'LanternHour(timezone: ${_this.timezone}, active: ${_this.active}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt})';
}


}

/// @nodoc
abstract mixin class $LanternHourCopyWith<$Res>  {
  factory $LanternHourCopyWith(LanternHour value, $Res Function(LanternHour) _then) = _$LanternHourCopyWithImpl;
@useResult
$Res call({
 String timezone, bool active, DateTime startsAt, DateTime endsAt
});




}
/// @nodoc
class _$LanternHourCopyWithImpl<$Res>
    implements $LanternHourCopyWith<$Res> {
  _$LanternHourCopyWithImpl(this._self, this._then);

  final LanternHour _self;
  final $Res Function(LanternHour) _then;

/// Create a copy of LanternHour
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timezone = null,Object? active = null,Object? startsAt = null,Object? endsAt = null,}) {
  return _then(LanternHour(
timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LanternHour].
extension LanternHourPatterns on LanternHour {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LanternHour value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LanternHour() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LanternHour value)  $default,){
final _that = this;
switch (_that) {
case _LanternHour():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LanternHour value)?  $default,){
final _that = this;
switch (_that) {
case _LanternHour() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String timezone,  bool active,  DateTime startsAt,  DateTime endsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LanternHour() when $default != null:
return $default(_that.timezone,_that.active,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String timezone,  bool active,  DateTime startsAt,  DateTime endsAt)  $default,) {final _that = this;
switch (_that) {
case _LanternHour():
return $default(_that.timezone,_that.active,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String timezone,  bool active,  DateTime startsAt,  DateTime endsAt)?  $default,) {final _that = this;
switch (_that) {
case _LanternHour() when $default != null:
return $default(_that.timezone,_that.active,_that.startsAt,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LanternHour with DiagnosticableTreeMixin implements LanternHour {
  const _LanternHour({this.timezone = '', this.active = false, required this.startsAt, required this.endsAt});
  factory _LanternHour.fromJson(Map<String, dynamic> json) => _$LanternHourFromJson(json);

/// The room's region clock (e.g. `Asia/Kolkata`).
@override@JsonKey() final  String timezone;
@override@JsonKey() final  bool active;
/// The current window while [active], else the next one.
@override final  DateTime startsAt;
@override final  DateTime endsAt;

/// Create a copy of LanternHour
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LanternHourCopyWith<_LanternHour> get copyWith => __$LanternHourCopyWithImpl<_LanternHour>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LanternHourToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'LanternHour'))
    ..add(DiagnosticsProperty('timezone', timezone))..add(DiagnosticsProperty('active', active))..add(DiagnosticsProperty('startsAt', startsAt))..add(DiagnosticsProperty('endsAt', endsAt));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LanternHour&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.active, active) || other.active == active)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,timezone,active,startsAt,endsAt);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'LanternHour(timezone: $timezone, active: $active, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$LanternHourCopyWith<$Res> implements $LanternHourCopyWith<$Res> {
  factory _$LanternHourCopyWith(_LanternHour value, $Res Function(_LanternHour) _then) = __$LanternHourCopyWithImpl;
@override @useResult
$Res call({
 String timezone, bool active, DateTime startsAt, DateTime endsAt
});




}
/// @nodoc
class __$LanternHourCopyWithImpl<$Res>
    implements _$LanternHourCopyWith<$Res> {
  __$LanternHourCopyWithImpl(this._self, this._then);

  final _LanternHour _self;
  final $Res Function(_LanternHour) _then;

/// Create a copy of LanternHour
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timezone = null,Object? active = null,Object? startsAt = null,Object? endsAt = null,}) {
  return _then(_LanternHour(
timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$RoomInfo implements DiagnosticableTreeMixin {

 String get roomId; String get quadrant; String get theme; String get state; bool get readOnly; DateTime get createdAt;/// No new members after this ("closing").
 DateTime get joinsCloseAt;/// Read-only memory from here ("becomes a memory at …").
 DateTime get memoryAt; DateTime get purgeAt; LanternHour get lanternHour;
/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<RoomInfo> get copyWith => _$RoomInfoCopyWithImpl<RoomInfo>(this as RoomInfo, _$identity);

  /// Serializes this RoomInfo to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomInfo;
  properties
    ..add(DiagnosticsProperty('type', 'RoomInfo'))
    ..add(DiagnosticsProperty('roomId', _this.roomId))..add(DiagnosticsProperty('quadrant', _this.quadrant))..add(DiagnosticsProperty('theme', _this.theme))..add(DiagnosticsProperty('state', _this.state))..add(DiagnosticsProperty('readOnly', _this.readOnly))..add(DiagnosticsProperty('createdAt', _this.createdAt))..add(DiagnosticsProperty('joinsCloseAt', _this.joinsCloseAt))..add(DiagnosticsProperty('memoryAt', _this.memoryAt))..add(DiagnosticsProperty('purgeAt', _this.purgeAt))..add(DiagnosticsProperty('lanternHour', _this.lanternHour));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomInfo&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.quadrant, _this.quadrant) || other.quadrant == _this.quadrant)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.readOnly, _this.readOnly) || other.readOnly == _this.readOnly)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.joinsCloseAt, _this.joinsCloseAt) || other.joinsCloseAt == _this.joinsCloseAt)&&(identical(other.memoryAt, _this.memoryAt) || other.memoryAt == _this.memoryAt)&&(identical(other.purgeAt, _this.purgeAt) || other.purgeAt == _this.purgeAt)&&(identical(other.lanternHour, _this.lanternHour) || other.lanternHour == _this.lanternHour));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomInfo;
  return Object.hash(runtimeType,_this.roomId,_this.quadrant,_this.theme,_this.state,_this.readOnly,_this.createdAt,_this.joinsCloseAt,_this.memoryAt,_this.purgeAt,_this.lanternHour);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomInfo;
  return 'RoomInfo(roomId: ${_this.roomId}, quadrant: ${_this.quadrant}, theme: ${_this.theme}, state: ${_this.state}, readOnly: ${_this.readOnly}, createdAt: ${_this.createdAt}, joinsCloseAt: ${_this.joinsCloseAt}, memoryAt: ${_this.memoryAt}, purgeAt: ${_this.purgeAt}, lanternHour: ${_this.lanternHour})';
}


}

/// @nodoc
abstract mixin class $RoomInfoCopyWith<$Res>  {
  factory $RoomInfoCopyWith(RoomInfo value, $Res Function(RoomInfo) _then) = _$RoomInfoCopyWithImpl;
@useResult
$Res call({
 String roomId, String quadrant, String theme, String state, bool readOnly, DateTime createdAt, DateTime joinsCloseAt, DateTime memoryAt, DateTime purgeAt, LanternHour lanternHour
});


$LanternHourCopyWith<$Res> get lanternHour;

}
/// @nodoc
class _$RoomInfoCopyWithImpl<$Res>
    implements $RoomInfoCopyWith<$Res> {
  _$RoomInfoCopyWithImpl(this._self, this._then);

  final RoomInfo _self;
  final $Res Function(RoomInfo) _then;

/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = null,Object? quadrant = null,Object? theme = null,Object? state = null,Object? readOnly = null,Object? createdAt = null,Object? joinsCloseAt = null,Object? memoryAt = null,Object? purgeAt = null,Object? lanternHour = null,}) {
  return _then(RoomInfo(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,quadrant: null == quadrant ? _self.quadrant : quadrant // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,readOnly: null == readOnly ? _self.readOnly : readOnly // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,joinsCloseAt: null == joinsCloseAt ? _self.joinsCloseAt : joinsCloseAt // ignore: cast_nullable_to_non_nullable
as DateTime,memoryAt: null == memoryAt ? _self.memoryAt : memoryAt // ignore: cast_nullable_to_non_nullable
as DateTime,purgeAt: null == purgeAt ? _self.purgeAt : purgeAt // ignore: cast_nullable_to_non_nullable
as DateTime,lanternHour: null == lanternHour ? _self.lanternHour : lanternHour // ignore: cast_nullable_to_non_nullable
as LanternHour,
  ));
}
/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LanternHourCopyWith<$Res> get lanternHour {
  
  return $LanternHourCopyWith<$Res>(_self.lanternHour, (value) {
    return _then(_self.copyWith(lanternHour: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomInfo].
extension RoomInfoPatterns on RoomInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomInfo value)  $default,){
final _that = this;
switch (_that) {
case _RoomInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RoomInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomId,  String quadrant,  String theme,  String state,  bool readOnly,  DateTime createdAt,  DateTime joinsCloseAt,  DateTime memoryAt,  DateTime purgeAt,  LanternHour lanternHour)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomInfo() when $default != null:
return $default(_that.roomId,_that.quadrant,_that.theme,_that.state,_that.readOnly,_that.createdAt,_that.joinsCloseAt,_that.memoryAt,_that.purgeAt,_that.lanternHour);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomId,  String quadrant,  String theme,  String state,  bool readOnly,  DateTime createdAt,  DateTime joinsCloseAt,  DateTime memoryAt,  DateTime purgeAt,  LanternHour lanternHour)  $default,) {final _that = this;
switch (_that) {
case _RoomInfo():
return $default(_that.roomId,_that.quadrant,_that.theme,_that.state,_that.readOnly,_that.createdAt,_that.joinsCloseAt,_that.memoryAt,_that.purgeAt,_that.lanternHour);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomId,  String quadrant,  String theme,  String state,  bool readOnly,  DateTime createdAt,  DateTime joinsCloseAt,  DateTime memoryAt,  DateTime purgeAt,  LanternHour lanternHour)?  $default,) {final _that = this;
switch (_that) {
case _RoomInfo() when $default != null:
return $default(_that.roomId,_that.quadrant,_that.theme,_that.state,_that.readOnly,_that.createdAt,_that.joinsCloseAt,_that.memoryAt,_that.purgeAt,_that.lanternHour);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomInfo extends RoomInfo with DiagnosticableTreeMixin {
  const _RoomInfo({required this.roomId, required this.quadrant, this.theme = '', this.state = 'open', this.readOnly = false, required this.createdAt, required this.joinsCloseAt, required this.memoryAt, required this.purgeAt, required this.lanternHour}): super._();
  factory _RoomInfo.fromJson(Map<String, dynamic> json) => _$RoomInfoFromJson(json);

@override final  String roomId;
@override final  String quadrant;
@override@JsonKey() final  String theme;
@override@JsonKey() final  String state;
@override@JsonKey() final  bool readOnly;
@override final  DateTime createdAt;
/// No new members after this ("closing").
@override final  DateTime joinsCloseAt;
/// Read-only memory from here ("becomes a memory at …").
@override final  DateTime memoryAt;
@override final  DateTime purgeAt;
@override final  LanternHour lanternHour;

/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomInfoCopyWith<_RoomInfo> get copyWith => __$RoomInfoCopyWithImpl<_RoomInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomInfoToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomInfo'))
    ..add(DiagnosticsProperty('roomId', roomId))..add(DiagnosticsProperty('quadrant', quadrant))..add(DiagnosticsProperty('theme', theme))..add(DiagnosticsProperty('state', state))..add(DiagnosticsProperty('readOnly', readOnly))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('joinsCloseAt', joinsCloseAt))..add(DiagnosticsProperty('memoryAt', memoryAt))..add(DiagnosticsProperty('purgeAt', purgeAt))..add(DiagnosticsProperty('lanternHour', lanternHour));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomInfo&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.quadrant, quadrant) || other.quadrant == quadrant)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.state, state) || other.state == state)&&(identical(other.readOnly, readOnly) || other.readOnly == readOnly)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.joinsCloseAt, joinsCloseAt) || other.joinsCloseAt == joinsCloseAt)&&(identical(other.memoryAt, memoryAt) || other.memoryAt == memoryAt)&&(identical(other.purgeAt, purgeAt) || other.purgeAt == purgeAt)&&(identical(other.lanternHour, lanternHour) || other.lanternHour == lanternHour));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,roomId,quadrant,theme,state,readOnly,createdAt,joinsCloseAt,memoryAt,purgeAt,lanternHour);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomInfo(roomId: $roomId, quadrant: $quadrant, theme: $theme, state: $state, readOnly: $readOnly, createdAt: $createdAt, joinsCloseAt: $joinsCloseAt, memoryAt: $memoryAt, purgeAt: $purgeAt, lanternHour: $lanternHour)';
}


}

/// @nodoc
abstract mixin class _$RoomInfoCopyWith<$Res> implements $RoomInfoCopyWith<$Res> {
  factory _$RoomInfoCopyWith(_RoomInfo value, $Res Function(_RoomInfo) _then) = __$RoomInfoCopyWithImpl;
@override @useResult
$Res call({
 String roomId, String quadrant, String theme, String state, bool readOnly, DateTime createdAt, DateTime joinsCloseAt, DateTime memoryAt, DateTime purgeAt, LanternHour lanternHour
});


@override $LanternHourCopyWith<$Res> get lanternHour;

}
/// @nodoc
class __$RoomInfoCopyWithImpl<$Res>
    implements _$RoomInfoCopyWith<$Res> {
  __$RoomInfoCopyWithImpl(this._self, this._then);

  final _RoomInfo _self;
  final $Res Function(_RoomInfo) _then;

/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = null,Object? quadrant = null,Object? theme = null,Object? state = null,Object? readOnly = null,Object? createdAt = null,Object? joinsCloseAt = null,Object? memoryAt = null,Object? purgeAt = null,Object? lanternHour = null,}) {
  return _then(_RoomInfo(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,quadrant: null == quadrant ? _self.quadrant : quadrant // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,readOnly: null == readOnly ? _self.readOnly : readOnly // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,joinsCloseAt: null == joinsCloseAt ? _self.joinsCloseAt : joinsCloseAt // ignore: cast_nullable_to_non_nullable
as DateTime,memoryAt: null == memoryAt ? _self.memoryAt : memoryAt // ignore: cast_nullable_to_non_nullable
as DateTime,purgeAt: null == purgeAt ? _self.purgeAt : purgeAt // ignore: cast_nullable_to_non_nullable
as DateTime,lanternHour: null == lanternHour ? _self.lanternHour : lanternHour // ignore: cast_nullable_to_non_nullable
as LanternHour,
  ));
}

/// Create a copy of RoomInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LanternHourCopyWith<$Res> get lanternHour {
  
  return $LanternHourCopyWith<$Res>(_self.lanternHour, (value) {
    return _then(_self.copyWith(lanternHour: value));
  });
}
}


/// @nodoc
mixin _$RoomCounts implements DiagnosticableTreeMixin {

/// Current members seen in the last 2 min.
 int get hereNow;/// Everyone who has been a member of this room (it lives 24 h).
 int get today;
/// Create a copy of RoomCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<RoomCounts> get copyWith => _$RoomCountsCopyWithImpl<RoomCounts>(this as RoomCounts, _$identity);

  /// Serializes this RoomCounts to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomCounts;
  properties
    ..add(DiagnosticsProperty('type', 'RoomCounts'))
    ..add(DiagnosticsProperty('hereNow', _this.hereNow))..add(DiagnosticsProperty('today', _this.today));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomCounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomCounts&&(identical(other.hereNow, _this.hereNow) || other.hereNow == _this.hereNow)&&(identical(other.today, _this.today) || other.today == _this.today));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomCounts;
  return Object.hash(runtimeType,_this.hereNow,_this.today);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomCounts;
  return 'RoomCounts(hereNow: ${_this.hereNow}, today: ${_this.today})';
}


}

/// @nodoc
abstract mixin class $RoomCountsCopyWith<$Res>  {
  factory $RoomCountsCopyWith(RoomCounts value, $Res Function(RoomCounts) _then) = _$RoomCountsCopyWithImpl;
@useResult
$Res call({
 int hereNow, int today
});




}
/// @nodoc
class _$RoomCountsCopyWithImpl<$Res>
    implements $RoomCountsCopyWith<$Res> {
  _$RoomCountsCopyWithImpl(this._self, this._then);

  final RoomCounts _self;
  final $Res Function(RoomCounts) _then;

/// Create a copy of RoomCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hereNow = null,Object? today = null,}) {
  return _then(RoomCounts(
hereNow: null == hereNow ? _self.hereNow : hereNow // ignore: cast_nullable_to_non_nullable
as int,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomCounts].
extension RoomCountsPatterns on RoomCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomCounts value)  $default,){
final _that = this;
switch (_that) {
case _RoomCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomCounts value)?  $default,){
final _that = this;
switch (_that) {
case _RoomCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int hereNow,  int today)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomCounts() when $default != null:
return $default(_that.hereNow,_that.today);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int hereNow,  int today)  $default,) {final _that = this;
switch (_that) {
case _RoomCounts():
return $default(_that.hereNow,_that.today);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int hereNow,  int today)?  $default,) {final _that = this;
switch (_that) {
case _RoomCounts() when $default != null:
return $default(_that.hereNow,_that.today);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomCounts with DiagnosticableTreeMixin implements RoomCounts {
  const _RoomCounts({this.hereNow = 0, this.today = 0});
  factory _RoomCounts.fromJson(Map<String, dynamic> json) => _$RoomCountsFromJson(json);

/// Current members seen in the last 2 min.
@override@JsonKey() final  int hereNow;
/// Everyone who has been a member of this room (it lives 24 h).
@override@JsonKey() final  int today;

/// Create a copy of RoomCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomCountsCopyWith<_RoomCounts> get copyWith => __$RoomCountsCopyWithImpl<_RoomCounts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomCountsToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomCounts'))
    ..add(DiagnosticsProperty('hereNow', hereNow))..add(DiagnosticsProperty('today', today));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomCounts&&(identical(other.hereNow, hereNow) || other.hereNow == hereNow)&&(identical(other.today, today) || other.today == today));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hereNow,today);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomCounts(hereNow: $hereNow, today: $today)';
}


}

/// @nodoc
abstract mixin class _$RoomCountsCopyWith<$Res> implements $RoomCountsCopyWith<$Res> {
  factory _$RoomCountsCopyWith(_RoomCounts value, $Res Function(_RoomCounts) _then) = __$RoomCountsCopyWithImpl;
@override @useResult
$Res call({
 int hereNow, int today
});




}
/// @nodoc
class __$RoomCountsCopyWithImpl<$Res>
    implements _$RoomCountsCopyWith<$Res> {
  __$RoomCountsCopyWithImpl(this._self, this._then);

  final _RoomCounts _self;
  final $Res Function(_RoomCounts) _then;

/// Create a copy of RoomCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hereNow = null,Object? today = null,}) {
  return _then(_RoomCounts(
hereNow: null == hereNow ? _self.hereNow : hereNow // ignore: cast_nullable_to_non_nullable
as int,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Silhouette implements DiagnosticableTreeMixin {

 String get stage; double? get hue; String? get cosmetic;
/// Create a copy of Silhouette
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SilhouetteCopyWith<Silhouette> get copyWith => _$SilhouetteCopyWithImpl<Silhouette>(this as Silhouette, _$identity);

  /// Serializes this Silhouette to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as Silhouette;
  properties
    ..add(DiagnosticsProperty('type', 'Silhouette'))
    ..add(DiagnosticsProperty('stage', _this.stage))..add(DiagnosticsProperty('hue', _this.hue))..add(DiagnosticsProperty('cosmetic', _this.cosmetic));
}

@override
bool operator ==(Object other) {
  final _this = this as Silhouette;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Silhouette&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.hue, _this.hue) || other.hue == _this.hue)&&(identical(other.cosmetic, _this.cosmetic) || other.cosmetic == _this.cosmetic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Silhouette;
  return Object.hash(runtimeType,_this.stage,_this.hue,_this.cosmetic);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as Silhouette;
  return 'Silhouette(stage: ${_this.stage}, hue: ${_this.hue}, cosmetic: ${_this.cosmetic})';
}


}

/// @nodoc
abstract mixin class $SilhouetteCopyWith<$Res>  {
  factory $SilhouetteCopyWith(Silhouette value, $Res Function(Silhouette) _then) = _$SilhouetteCopyWithImpl;
@useResult
$Res call({
 String stage, double? hue, String? cosmetic
});




}
/// @nodoc
class _$SilhouetteCopyWithImpl<$Res>
    implements $SilhouetteCopyWith<$Res> {
  _$SilhouetteCopyWithImpl(this._self, this._then);

  final Silhouette _self;
  final $Res Function(Silhouette) _then;

/// Create a copy of Silhouette
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? hue = freezed,Object? cosmetic = freezed,}) {
  return _then(Silhouette(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,hue: freezed == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as double?,cosmetic: freezed == cosmetic ? _self.cosmetic : cosmetic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Silhouette].
extension SilhouettePatterns on Silhouette {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Silhouette value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Silhouette() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Silhouette value)  $default,){
final _that = this;
switch (_that) {
case _Silhouette():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Silhouette value)?  $default,){
final _that = this;
switch (_that) {
case _Silhouette() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stage,  double? hue,  String? cosmetic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Silhouette() when $default != null:
return $default(_that.stage,_that.hue,_that.cosmetic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stage,  double? hue,  String? cosmetic)  $default,) {final _that = this;
switch (_that) {
case _Silhouette():
return $default(_that.stage,_that.hue,_that.cosmetic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stage,  double? hue,  String? cosmetic)?  $default,) {final _that = this;
switch (_that) {
case _Silhouette() when $default != null:
return $default(_that.stage,_that.hue,_that.cosmetic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Silhouette extends Silhouette with DiagnosticableTreeMixin {
  const _Silhouette({this.stage = 'spark', this.hue, this.cosmetic}): super._();
  factory _Silhouette.fromJson(Map<String, dynamic> json) => _$SilhouetteFromJson(json);

@override@JsonKey() final  String stage;
@override final  double? hue;
@override final  String? cosmetic;

/// Create a copy of Silhouette
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SilhouetteCopyWith<_Silhouette> get copyWith => __$SilhouetteCopyWithImpl<_Silhouette>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SilhouetteToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'Silhouette'))
    ..add(DiagnosticsProperty('stage', stage))..add(DiagnosticsProperty('hue', hue))..add(DiagnosticsProperty('cosmetic', cosmetic));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Silhouette&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.hue, hue) || other.hue == hue)&&(identical(other.cosmetic, cosmetic) || other.cosmetic == cosmetic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,stage,hue,cosmetic);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'Silhouette(stage: $stage, hue: $hue, cosmetic: $cosmetic)';
}


}

/// @nodoc
abstract mixin class _$SilhouetteCopyWith<$Res> implements $SilhouetteCopyWith<$Res> {
  factory _$SilhouetteCopyWith(_Silhouette value, $Res Function(_Silhouette) _then) = __$SilhouetteCopyWithImpl;
@override @useResult
$Res call({
 String stage, double? hue, String? cosmetic
});




}
/// @nodoc
class __$SilhouetteCopyWithImpl<$Res>
    implements _$SilhouetteCopyWith<$Res> {
  __$SilhouetteCopyWithImpl(this._self, this._then);

  final _Silhouette _self;
  final $Res Function(_Silhouette) _then;

/// Create a copy of Silhouette
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? hue = freezed,Object? cosmetic = freezed,}) {
  return _then(_Silhouette(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,hue: freezed == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as double?,cosmetic: freezed == cosmetic ? _self.cosmetic : cosmetic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$RoomMember implements DiagnosticableTreeMixin {

 String get memberId;/// Fresh per room ("Quiet Comet"), from the server; never translated.
 String get pseudonym; Silhouette get silhouette;/// Catalogue mood id at join; the app localises it.
 String get moodChip; bool get live;/// You muted this member (you still see the silhouette).
 bool get muted; bool get isMe;
/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomMemberCopyWith<RoomMember> get copyWith => _$RoomMemberCopyWithImpl<RoomMember>(this as RoomMember, _$identity);

  /// Serializes this RoomMember to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomMember;
  properties
    ..add(DiagnosticsProperty('type', 'RoomMember'))
    ..add(DiagnosticsProperty('memberId', _this.memberId))..add(DiagnosticsProperty('pseudonym', _this.pseudonym))..add(DiagnosticsProperty('silhouette', _this.silhouette))..add(DiagnosticsProperty('moodChip', _this.moodChip))..add(DiagnosticsProperty('live', _this.live))..add(DiagnosticsProperty('muted', _this.muted))..add(DiagnosticsProperty('isMe', _this.isMe));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomMember;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomMember&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&(identical(other.pseudonym, _this.pseudonym) || other.pseudonym == _this.pseudonym)&&(identical(other.silhouette, _this.silhouette) || other.silhouette == _this.silhouette)&&(identical(other.moodChip, _this.moodChip) || other.moodChip == _this.moodChip)&&(identical(other.live, _this.live) || other.live == _this.live)&&(identical(other.muted, _this.muted) || other.muted == _this.muted)&&(identical(other.isMe, _this.isMe) || other.isMe == _this.isMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomMember;
  return Object.hash(runtimeType,_this.memberId,_this.pseudonym,_this.silhouette,_this.moodChip,_this.live,_this.muted,_this.isMe);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomMember;
  return 'RoomMember(memberId: ${_this.memberId}, pseudonym: ${_this.pseudonym}, silhouette: ${_this.silhouette}, moodChip: ${_this.moodChip}, live: ${_this.live}, muted: ${_this.muted}, isMe: ${_this.isMe})';
}


}

/// @nodoc
abstract mixin class $RoomMemberCopyWith<$Res>  {
  factory $RoomMemberCopyWith(RoomMember value, $Res Function(RoomMember) _then) = _$RoomMemberCopyWithImpl;
@useResult
$Res call({
 String memberId, String pseudonym, Silhouette silhouette, String moodChip, bool live, bool muted, bool isMe
});


$SilhouetteCopyWith<$Res> get silhouette;

}
/// @nodoc
class _$RoomMemberCopyWithImpl<$Res>
    implements $RoomMemberCopyWith<$Res> {
  _$RoomMemberCopyWithImpl(this._self, this._then);

  final RoomMember _self;
  final $Res Function(RoomMember) _then;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? memberId = null,Object? pseudonym = null,Object? silhouette = null,Object? moodChip = null,Object? live = null,Object? muted = null,Object? isMe = null,}) {
  return _then(RoomMember(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,silhouette: null == silhouette ? _self.silhouette : silhouette // ignore: cast_nullable_to_non_nullable
as Silhouette,moodChip: null == moodChip ? _self.moodChip : moodChip // ignore: cast_nullable_to_non_nullable
as String,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SilhouetteCopyWith<$Res> get silhouette {
  
  return $SilhouetteCopyWith<$Res>(_self.silhouette, (value) {
    return _then(_self.copyWith(silhouette: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomMember].
extension RoomMemberPatterns on RoomMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomMember value)  $default,){
final _that = this;
switch (_that) {
case _RoomMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomMember value)?  $default,){
final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String memberId,  String pseudonym,  Silhouette silhouette,  String moodChip,  bool live,  bool muted,  bool isMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.memberId,_that.pseudonym,_that.silhouette,_that.moodChip,_that.live,_that.muted,_that.isMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String memberId,  String pseudonym,  Silhouette silhouette,  String moodChip,  bool live,  bool muted,  bool isMe)  $default,) {final _that = this;
switch (_that) {
case _RoomMember():
return $default(_that.memberId,_that.pseudonym,_that.silhouette,_that.moodChip,_that.live,_that.muted,_that.isMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String memberId,  String pseudonym,  Silhouette silhouette,  String moodChip,  bool live,  bool muted,  bool isMe)?  $default,) {final _that = this;
switch (_that) {
case _RoomMember() when $default != null:
return $default(_that.memberId,_that.pseudonym,_that.silhouette,_that.moodChip,_that.live,_that.muted,_that.isMe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomMember with DiagnosticableTreeMixin implements RoomMember {
  const _RoomMember({required this.memberId, required this.pseudonym, this.silhouette = const Silhouette(), this.moodChip = '', this.live = false, this.muted = false, this.isMe = false});
  factory _RoomMember.fromJson(Map<String, dynamic> json) => _$RoomMemberFromJson(json);

@override final  String memberId;
/// Fresh per room ("Quiet Comet"), from the server; never translated.
@override final  String pseudonym;
@override@JsonKey() final  Silhouette silhouette;
/// Catalogue mood id at join; the app localises it.
@override@JsonKey() final  String moodChip;
@override@JsonKey() final  bool live;
/// You muted this member (you still see the silhouette).
@override@JsonKey() final  bool muted;
@override@JsonKey() final  bool isMe;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomMemberCopyWith<_RoomMember> get copyWith => __$RoomMemberCopyWithImpl<_RoomMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomMemberToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomMember'))
    ..add(DiagnosticsProperty('memberId', memberId))..add(DiagnosticsProperty('pseudonym', pseudonym))..add(DiagnosticsProperty('silhouette', silhouette))..add(DiagnosticsProperty('moodChip', moodChip))..add(DiagnosticsProperty('live', live))..add(DiagnosticsProperty('muted', muted))..add(DiagnosticsProperty('isMe', isMe));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomMember&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.pseudonym, pseudonym) || other.pseudonym == pseudonym)&&(identical(other.silhouette, silhouette) || other.silhouette == silhouette)&&(identical(other.moodChip, moodChip) || other.moodChip == moodChip)&&(identical(other.live, live) || other.live == live)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.isMe, isMe) || other.isMe == isMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,memberId,pseudonym,silhouette,moodChip,live,muted,isMe);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomMember(memberId: $memberId, pseudonym: $pseudonym, silhouette: $silhouette, moodChip: $moodChip, live: $live, muted: $muted, isMe: $isMe)';
}


}

/// @nodoc
abstract mixin class _$RoomMemberCopyWith<$Res> implements $RoomMemberCopyWith<$Res> {
  factory _$RoomMemberCopyWith(_RoomMember value, $Res Function(_RoomMember) _then) = __$RoomMemberCopyWithImpl;
@override @useResult
$Res call({
 String memberId, String pseudonym, Silhouette silhouette, String moodChip, bool live, bool muted, bool isMe
});


@override $SilhouetteCopyWith<$Res> get silhouette;

}
/// @nodoc
class __$RoomMemberCopyWithImpl<$Res>
    implements _$RoomMemberCopyWith<$Res> {
  __$RoomMemberCopyWithImpl(this._self, this._then);

  final _RoomMember _self;
  final $Res Function(_RoomMember) _then;

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? memberId = null,Object? pseudonym = null,Object? silhouette = null,Object? moodChip = null,Object? live = null,Object? muted = null,Object? isMe = null,}) {
  return _then(_RoomMember(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,silhouette: null == silhouette ? _self.silhouette : silhouette // ignore: cast_nullable_to_non_nullable
as Silhouette,moodChip: null == moodChip ? _self.moodChip : moodChip // ignore: cast_nullable_to_non_nullable
as String,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as bool,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,isMe: null == isMe ? _self.isMe : isMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RoomMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SilhouetteCopyWith<$Res> get silhouette {
  
  return $SilhouetteCopyWith<$Res>(_self.silhouette, (value) {
    return _then(_self.copyWith(silhouette: value));
  });
}
}


/// @nodoc
mixin _$ReceivedGesture implements DiagnosticableTreeMixin {

 String get gestureId; String get type; String get fromMemberId; String get fromPseudonym; DateTime get at;
/// Create a copy of ReceivedGesture
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceivedGestureCopyWith<ReceivedGesture> get copyWith => _$ReceivedGestureCopyWithImpl<ReceivedGesture>(this as ReceivedGesture, _$identity);

  /// Serializes this ReceivedGesture to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as ReceivedGesture;
  properties
    ..add(DiagnosticsProperty('type', 'ReceivedGesture'))
    ..add(DiagnosticsProperty('gestureId', _this.gestureId))..add(DiagnosticsProperty('type', _this.type))..add(DiagnosticsProperty('fromMemberId', _this.fromMemberId))..add(DiagnosticsProperty('fromPseudonym', _this.fromPseudonym))..add(DiagnosticsProperty('at', _this.at));
}

@override
bool operator ==(Object other) {
  final _this = this as ReceivedGesture;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceivedGesture&&(identical(other.gestureId, _this.gestureId) || other.gestureId == _this.gestureId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.fromMemberId, _this.fromMemberId) || other.fromMemberId == _this.fromMemberId)&&(identical(other.fromPseudonym, _this.fromPseudonym) || other.fromPseudonym == _this.fromPseudonym)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReceivedGesture;
  return Object.hash(runtimeType,_this.gestureId,_this.type,_this.fromMemberId,_this.fromPseudonym,_this.at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as ReceivedGesture;
  return 'ReceivedGesture(gestureId: ${_this.gestureId}, type: ${_this.type}, fromMemberId: ${_this.fromMemberId}, fromPseudonym: ${_this.fromPseudonym}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $ReceivedGestureCopyWith<$Res>  {
  factory $ReceivedGestureCopyWith(ReceivedGesture value, $Res Function(ReceivedGesture) _then) = _$ReceivedGestureCopyWithImpl;
@useResult
$Res call({
 String gestureId, String type, String fromMemberId, String fromPseudonym, DateTime at
});




}
/// @nodoc
class _$ReceivedGestureCopyWithImpl<$Res>
    implements $ReceivedGestureCopyWith<$Res> {
  _$ReceivedGestureCopyWithImpl(this._self, this._then);

  final ReceivedGesture _self;
  final $Res Function(ReceivedGesture) _then;

/// Create a copy of ReceivedGesture
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gestureId = null,Object? type = null,Object? fromMemberId = null,Object? fromPseudonym = null,Object? at = null,}) {
  return _then(ReceivedGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,fromMemberId: null == fromMemberId ? _self.fromMemberId : fromMemberId // ignore: cast_nullable_to_non_nullable
as String,fromPseudonym: null == fromPseudonym ? _self.fromPseudonym : fromPseudonym // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceivedGesture].
extension ReceivedGesturePatterns on ReceivedGesture {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceivedGesture value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceivedGesture() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceivedGesture value)  $default,){
final _that = this;
switch (_that) {
case _ReceivedGesture():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceivedGesture value)?  $default,){
final _that = this;
switch (_that) {
case _ReceivedGesture() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String gestureId,  String type,  String fromMemberId,  String fromPseudonym,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceivedGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.fromMemberId,_that.fromPseudonym,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String gestureId,  String type,  String fromMemberId,  String fromPseudonym,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _ReceivedGesture():
return $default(_that.gestureId,_that.type,_that.fromMemberId,_that.fromPseudonym,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String gestureId,  String type,  String fromMemberId,  String fromPseudonym,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _ReceivedGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.fromMemberId,_that.fromPseudonym,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceivedGesture extends ReceivedGesture with DiagnosticableTreeMixin {
  const _ReceivedGesture({required this.gestureId, required this.type, required this.fromMemberId, required this.fromPseudonym, required this.at}): super._();
  factory _ReceivedGesture.fromJson(Map<String, dynamic> json) => _$ReceivedGestureFromJson(json);

@override final  String gestureId;
@override final  String type;
@override final  String fromMemberId;
@override final  String fromPseudonym;
@override final  DateTime at;

/// Create a copy of ReceivedGesture
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceivedGestureCopyWith<_ReceivedGesture> get copyWith => __$ReceivedGestureCopyWithImpl<_ReceivedGesture>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceivedGestureToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'ReceivedGesture'))
    ..add(DiagnosticsProperty('gestureId', gestureId))..add(DiagnosticsProperty('type', type))..add(DiagnosticsProperty('fromMemberId', fromMemberId))..add(DiagnosticsProperty('fromPseudonym', fromPseudonym))..add(DiagnosticsProperty('at', at));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceivedGesture&&(identical(other.gestureId, gestureId) || other.gestureId == gestureId)&&(identical(other.type, type) || other.type == type)&&(identical(other.fromMemberId, fromMemberId) || other.fromMemberId == fromMemberId)&&(identical(other.fromPseudonym, fromPseudonym) || other.fromPseudonym == fromPseudonym)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gestureId,type,fromMemberId,fromPseudonym,at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'ReceivedGesture(gestureId: $gestureId, type: $type, fromMemberId: $fromMemberId, fromPseudonym: $fromPseudonym, at: $at)';
}


}

/// @nodoc
abstract mixin class _$ReceivedGestureCopyWith<$Res> implements $ReceivedGestureCopyWith<$Res> {
  factory _$ReceivedGestureCopyWith(_ReceivedGesture value, $Res Function(_ReceivedGesture) _then) = __$ReceivedGestureCopyWithImpl;
@override @useResult
$Res call({
 String gestureId, String type, String fromMemberId, String fromPseudonym, DateTime at
});




}
/// @nodoc
class __$ReceivedGestureCopyWithImpl<$Res>
    implements _$ReceivedGestureCopyWith<$Res> {
  __$ReceivedGestureCopyWithImpl(this._self, this._then);

  final _ReceivedGesture _self;
  final $Res Function(_ReceivedGesture) _then;

/// Create a copy of ReceivedGesture
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gestureId = null,Object? type = null,Object? fromMemberId = null,Object? fromPseudonym = null,Object? at = null,}) {
  return _then(_ReceivedGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,fromMemberId: null == fromMemberId ? _self.fromMemberId : fromMemberId // ignore: cast_nullable_to_non_nullable
as String,fromPseudonym: null == fromPseudonym ? _self.fromPseudonym : fromPseudonym // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SentGesture implements DiagnosticableTreeMixin {

 String get gestureId; String get type; String get target; String? get toMemberId; DateTime get at;
/// Create a copy of SentGesture
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SentGestureCopyWith<SentGesture> get copyWith => _$SentGestureCopyWithImpl<SentGesture>(this as SentGesture, _$identity);

  /// Serializes this SentGesture to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as SentGesture;
  properties
    ..add(DiagnosticsProperty('type', 'SentGesture'))
    ..add(DiagnosticsProperty('gestureId', _this.gestureId))..add(DiagnosticsProperty('type', _this.type))..add(DiagnosticsProperty('target', _this.target))..add(DiagnosticsProperty('toMemberId', _this.toMemberId))..add(DiagnosticsProperty('at', _this.at));
}

@override
bool operator ==(Object other) {
  final _this = this as SentGesture;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentGesture&&(identical(other.gestureId, _this.gestureId) || other.gestureId == _this.gestureId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.toMemberId, _this.toMemberId) || other.toMemberId == _this.toMemberId)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SentGesture;
  return Object.hash(runtimeType,_this.gestureId,_this.type,_this.target,_this.toMemberId,_this.at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as SentGesture;
  return 'SentGesture(gestureId: ${_this.gestureId}, type: ${_this.type}, target: ${_this.target}, toMemberId: ${_this.toMemberId}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $SentGestureCopyWith<$Res>  {
  factory $SentGestureCopyWith(SentGesture value, $Res Function(SentGesture) _then) = _$SentGestureCopyWithImpl;
@useResult
$Res call({
 String gestureId, String type, String target, String? toMemberId, DateTime at
});




}
/// @nodoc
class _$SentGestureCopyWithImpl<$Res>
    implements $SentGestureCopyWith<$Res> {
  _$SentGestureCopyWithImpl(this._self, this._then);

  final SentGesture _self;
  final $Res Function(SentGesture) _then;

/// Create a copy of SentGesture
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gestureId = null,Object? type = null,Object? target = null,Object? toMemberId = freezed,Object? at = null,}) {
  return _then(SentGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,toMemberId: freezed == toMemberId ? _self.toMemberId : toMemberId // ignore: cast_nullable_to_non_nullable
as String?,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SentGesture].
extension SentGesturePatterns on SentGesture {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SentGesture value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentGesture() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SentGesture value)  $default,){
final _that = this;
switch (_that) {
case _SentGesture():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SentGesture value)?  $default,){
final _that = this;
switch (_that) {
case _SentGesture() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String gestureId,  String type,  String target,  String? toMemberId,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.target,_that.toMemberId,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String gestureId,  String type,  String target,  String? toMemberId,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _SentGesture():
return $default(_that.gestureId,_that.type,_that.target,_that.toMemberId,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String gestureId,  String type,  String target,  String? toMemberId,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _SentGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.target,_that.toMemberId,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SentGesture extends SentGesture with DiagnosticableTreeMixin {
  const _SentGesture({required this.gestureId, required this.type, this.target = 'room', this.toMemberId, required this.at}): super._();
  factory _SentGesture.fromJson(Map<String, dynamic> json) => _$SentGestureFromJson(json);

@override final  String gestureId;
@override final  String type;
@override@JsonKey() final  String target;
@override final  String? toMemberId;
@override final  DateTime at;

/// Create a copy of SentGesture
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentGestureCopyWith<_SentGesture> get copyWith => __$SentGestureCopyWithImpl<_SentGesture>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentGestureToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'SentGesture'))
    ..add(DiagnosticsProperty('gestureId', gestureId))..add(DiagnosticsProperty('type', type))..add(DiagnosticsProperty('target', target))..add(DiagnosticsProperty('toMemberId', toMemberId))..add(DiagnosticsProperty('at', at));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentGesture&&(identical(other.gestureId, gestureId) || other.gestureId == gestureId)&&(identical(other.type, type) || other.type == type)&&(identical(other.target, target) || other.target == target)&&(identical(other.toMemberId, toMemberId) || other.toMemberId == toMemberId)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gestureId,type,target,toMemberId,at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'SentGesture(gestureId: $gestureId, type: $type, target: $target, toMemberId: $toMemberId, at: $at)';
}


}

/// @nodoc
abstract mixin class _$SentGestureCopyWith<$Res> implements $SentGestureCopyWith<$Res> {
  factory _$SentGestureCopyWith(_SentGesture value, $Res Function(_SentGesture) _then) = __$SentGestureCopyWithImpl;
@override @useResult
$Res call({
 String gestureId, String type, String target, String? toMemberId, DateTime at
});




}
/// @nodoc
class __$SentGestureCopyWithImpl<$Res>
    implements _$SentGestureCopyWith<$Res> {
  __$SentGestureCopyWithImpl(this._self, this._then);

  final _SentGesture _self;
  final $Res Function(_SentGesture) _then;

/// Create a copy of SentGesture
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gestureId = null,Object? type = null,Object? target = null,Object? toMemberId = freezed,Object? at = null,}) {
  return _then(_SentGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,toMemberId: freezed == toMemberId ? _self.toMemberId : toMemberId // ignore: cast_nullable_to_non_nullable
as String?,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$RoomGesture implements DiagnosticableTreeMixin {

 String get gestureId; String get type; String get target; DateTime get at;
/// Create a copy of RoomGesture
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomGestureCopyWith<RoomGesture> get copyWith => _$RoomGestureCopyWithImpl<RoomGesture>(this as RoomGesture, _$identity);

  /// Serializes this RoomGesture to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomGesture;
  properties
    ..add(DiagnosticsProperty('type', 'RoomGesture'))
    ..add(DiagnosticsProperty('gestureId', _this.gestureId))..add(DiagnosticsProperty('type', _this.type))..add(DiagnosticsProperty('target', _this.target))..add(DiagnosticsProperty('at', _this.at));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomGesture;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomGesture&&(identical(other.gestureId, _this.gestureId) || other.gestureId == _this.gestureId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomGesture;
  return Object.hash(runtimeType,_this.gestureId,_this.type,_this.target,_this.at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomGesture;
  return 'RoomGesture(gestureId: ${_this.gestureId}, type: ${_this.type}, target: ${_this.target}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $RoomGestureCopyWith<$Res>  {
  factory $RoomGestureCopyWith(RoomGesture value, $Res Function(RoomGesture) _then) = _$RoomGestureCopyWithImpl;
@useResult
$Res call({
 String gestureId, String type, String target, DateTime at
});




}
/// @nodoc
class _$RoomGestureCopyWithImpl<$Res>
    implements $RoomGestureCopyWith<$Res> {
  _$RoomGestureCopyWithImpl(this._self, this._then);

  final RoomGesture _self;
  final $Res Function(RoomGesture) _then;

/// Create a copy of RoomGesture
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gestureId = null,Object? type = null,Object? target = null,Object? at = null,}) {
  return _then(RoomGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomGesture].
extension RoomGesturePatterns on RoomGesture {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomGesture value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomGesture() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomGesture value)  $default,){
final _that = this;
switch (_that) {
case _RoomGesture():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomGesture value)?  $default,){
final _that = this;
switch (_that) {
case _RoomGesture() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String gestureId,  String type,  String target,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.target,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String gestureId,  String type,  String target,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _RoomGesture():
return $default(_that.gestureId,_that.type,_that.target,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String gestureId,  String type,  String target,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _RoomGesture() when $default != null:
return $default(_that.gestureId,_that.type,_that.target,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomGesture extends RoomGesture with DiagnosticableTreeMixin {
  const _RoomGesture({required this.gestureId, required this.type, this.target = 'room', required this.at}): super._();
  factory _RoomGesture.fromJson(Map<String, dynamic> json) => _$RoomGestureFromJson(json);

@override final  String gestureId;
@override final  String type;
@override@JsonKey() final  String target;
@override final  DateTime at;

/// Create a copy of RoomGesture
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomGestureCopyWith<_RoomGesture> get copyWith => __$RoomGestureCopyWithImpl<_RoomGesture>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomGestureToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomGesture'))
    ..add(DiagnosticsProperty('gestureId', gestureId))..add(DiagnosticsProperty('type', type))..add(DiagnosticsProperty('target', target))..add(DiagnosticsProperty('at', at));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomGesture&&(identical(other.gestureId, gestureId) || other.gestureId == gestureId)&&(identical(other.type, type) || other.type == type)&&(identical(other.target, target) || other.target == target)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gestureId,type,target,at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomGesture(gestureId: $gestureId, type: $type, target: $target, at: $at)';
}


}

/// @nodoc
abstract mixin class _$RoomGestureCopyWith<$Res> implements $RoomGestureCopyWith<$Res> {
  factory _$RoomGestureCopyWith(_RoomGesture value, $Res Function(_RoomGesture) _then) = __$RoomGestureCopyWithImpl;
@override @useResult
$Res call({
 String gestureId, String type, String target, DateTime at
});




}
/// @nodoc
class __$RoomGestureCopyWithImpl<$Res>
    implements _$RoomGestureCopyWith<$Res> {
  __$RoomGestureCopyWithImpl(this._self, this._then);

  final _RoomGesture _self;
  final $Res Function(_RoomGesture) _then;

/// Create a copy of RoomGesture
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gestureId = null,Object? type = null,Object? target = null,Object? at = null,}) {
  return _then(_RoomGesture(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$RoomMe implements DiagnosticableTreeMixin {

 String get memberId; String get pseudonym; String get moodChip; Silhouette? get silhouette; DateTime get joinedAt;/// Show "Did you feel less alone?" on exit (≥ 30 s here, not asked in
/// the last 24 h).
 bool get surveyEligible;
/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomMeCopyWith<RoomMe> get copyWith => _$RoomMeCopyWithImpl<RoomMe>(this as RoomMe, _$identity);

  /// Serializes this RoomMe to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomMe;
  properties
    ..add(DiagnosticsProperty('type', 'RoomMe'))
    ..add(DiagnosticsProperty('memberId', _this.memberId))..add(DiagnosticsProperty('pseudonym', _this.pseudonym))..add(DiagnosticsProperty('moodChip', _this.moodChip))..add(DiagnosticsProperty('silhouette', _this.silhouette))..add(DiagnosticsProperty('joinedAt', _this.joinedAt))..add(DiagnosticsProperty('surveyEligible', _this.surveyEligible));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomMe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomMe&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&(identical(other.pseudonym, _this.pseudonym) || other.pseudonym == _this.pseudonym)&&(identical(other.moodChip, _this.moodChip) || other.moodChip == _this.moodChip)&&(identical(other.silhouette, _this.silhouette) || other.silhouette == _this.silhouette)&&(identical(other.joinedAt, _this.joinedAt) || other.joinedAt == _this.joinedAt)&&(identical(other.surveyEligible, _this.surveyEligible) || other.surveyEligible == _this.surveyEligible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomMe;
  return Object.hash(runtimeType,_this.memberId,_this.pseudonym,_this.moodChip,_this.silhouette,_this.joinedAt,_this.surveyEligible);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomMe;
  return 'RoomMe(memberId: ${_this.memberId}, pseudonym: ${_this.pseudonym}, moodChip: ${_this.moodChip}, silhouette: ${_this.silhouette}, joinedAt: ${_this.joinedAt}, surveyEligible: ${_this.surveyEligible})';
}


}

/// @nodoc
abstract mixin class $RoomMeCopyWith<$Res>  {
  factory $RoomMeCopyWith(RoomMe value, $Res Function(RoomMe) _then) = _$RoomMeCopyWithImpl;
@useResult
$Res call({
 String memberId, String pseudonym, String moodChip, Silhouette? silhouette, DateTime joinedAt, bool surveyEligible
});


$SilhouetteCopyWith<$Res>? get silhouette;

}
/// @nodoc
class _$RoomMeCopyWithImpl<$Res>
    implements $RoomMeCopyWith<$Res> {
  _$RoomMeCopyWithImpl(this._self, this._then);

  final RoomMe _self;
  final $Res Function(RoomMe) _then;

/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? memberId = null,Object? pseudonym = null,Object? moodChip = null,Object? silhouette = freezed,Object? joinedAt = null,Object? surveyEligible = null,}) {
  return _then(RoomMe(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,moodChip: null == moodChip ? _self.moodChip : moodChip // ignore: cast_nullable_to_non_nullable
as String,silhouette: freezed == silhouette ? _self.silhouette : silhouette // ignore: cast_nullable_to_non_nullable
as Silhouette?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,surveyEligible: null == surveyEligible ? _self.surveyEligible : surveyEligible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SilhouetteCopyWith<$Res>? get silhouette {
    if (_self.silhouette == null) {
    return null;
  }

  return $SilhouetteCopyWith<$Res>(_self.silhouette!, (value) {
    return _then(_self.copyWith(silhouette: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomMe].
extension RoomMePatterns on RoomMe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomMe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomMe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomMe value)  $default,){
final _that = this;
switch (_that) {
case _RoomMe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomMe value)?  $default,){
final _that = this;
switch (_that) {
case _RoomMe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String memberId,  String pseudonym,  String moodChip,  Silhouette? silhouette,  DateTime joinedAt,  bool surveyEligible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomMe() when $default != null:
return $default(_that.memberId,_that.pseudonym,_that.moodChip,_that.silhouette,_that.joinedAt,_that.surveyEligible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String memberId,  String pseudonym,  String moodChip,  Silhouette? silhouette,  DateTime joinedAt,  bool surveyEligible)  $default,) {final _that = this;
switch (_that) {
case _RoomMe():
return $default(_that.memberId,_that.pseudonym,_that.moodChip,_that.silhouette,_that.joinedAt,_that.surveyEligible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String memberId,  String pseudonym,  String moodChip,  Silhouette? silhouette,  DateTime joinedAt,  bool surveyEligible)?  $default,) {final _that = this;
switch (_that) {
case _RoomMe() when $default != null:
return $default(_that.memberId,_that.pseudonym,_that.moodChip,_that.silhouette,_that.joinedAt,_that.surveyEligible);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomMe with DiagnosticableTreeMixin implements RoomMe {
  const _RoomMe({required this.memberId, required this.pseudonym, this.moodChip = '', this.silhouette, required this.joinedAt, this.surveyEligible = false});
  factory _RoomMe.fromJson(Map<String, dynamic> json) => _$RoomMeFromJson(json);

@override final  String memberId;
@override final  String pseudonym;
@override@JsonKey() final  String moodChip;
@override final  Silhouette? silhouette;
@override final  DateTime joinedAt;
/// Show "Did you feel less alone?" on exit (≥ 30 s here, not asked in
/// the last 24 h).
@override@JsonKey() final  bool surveyEligible;

/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomMeCopyWith<_RoomMe> get copyWith => __$RoomMeCopyWithImpl<_RoomMe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomMeToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomMe'))
    ..add(DiagnosticsProperty('memberId', memberId))..add(DiagnosticsProperty('pseudonym', pseudonym))..add(DiagnosticsProperty('moodChip', moodChip))..add(DiagnosticsProperty('silhouette', silhouette))..add(DiagnosticsProperty('joinedAt', joinedAt))..add(DiagnosticsProperty('surveyEligible', surveyEligible));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomMe&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.pseudonym, pseudonym) || other.pseudonym == pseudonym)&&(identical(other.moodChip, moodChip) || other.moodChip == moodChip)&&(identical(other.silhouette, silhouette) || other.silhouette == silhouette)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.surveyEligible, surveyEligible) || other.surveyEligible == surveyEligible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,memberId,pseudonym,moodChip,silhouette,joinedAt,surveyEligible);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomMe(memberId: $memberId, pseudonym: $pseudonym, moodChip: $moodChip, silhouette: $silhouette, joinedAt: $joinedAt, surveyEligible: $surveyEligible)';
}


}

/// @nodoc
abstract mixin class _$RoomMeCopyWith<$Res> implements $RoomMeCopyWith<$Res> {
  factory _$RoomMeCopyWith(_RoomMe value, $Res Function(_RoomMe) _then) = __$RoomMeCopyWithImpl;
@override @useResult
$Res call({
 String memberId, String pseudonym, String moodChip, Silhouette? silhouette, DateTime joinedAt, bool surveyEligible
});


@override $SilhouetteCopyWith<$Res>? get silhouette;

}
/// @nodoc
class __$RoomMeCopyWithImpl<$Res>
    implements _$RoomMeCopyWith<$Res> {
  __$RoomMeCopyWithImpl(this._self, this._then);

  final _RoomMe _self;
  final $Res Function(_RoomMe) _then;

/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? memberId = null,Object? pseudonym = null,Object? moodChip = null,Object? silhouette = freezed,Object? joinedAt = null,Object? surveyEligible = null,}) {
  return _then(_RoomMe(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,moodChip: null == moodChip ? _self.moodChip : moodChip // ignore: cast_nullable_to_non_nullable
as String,silhouette: freezed == silhouette ? _self.silhouette : silhouette // ignore: cast_nullable_to_non_nullable
as Silhouette?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,surveyEligible: null == surveyEligible ? _self.surveyEligible : surveyEligible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RoomMe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SilhouetteCopyWith<$Res>? get silhouette {
    if (_self.silhouette == null) {
    return null;
  }

  return $SilhouetteCopyWith<$Res>(_self.silhouette!, (value) {
    return _then(_self.copyWith(silhouette: value));
  });
}
}


/// @nodoc
mixin _$RoomGestures implements DiagnosticableTreeMixin {

 List<ReceivedGesture> get received; List<SentGesture> get sent; List<RoomGesture> get recent;
/// Create a copy of RoomGestures
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomGesturesCopyWith<RoomGestures> get copyWith => _$RoomGesturesCopyWithImpl<RoomGestures>(this as RoomGestures, _$identity);

  /// Serializes this RoomGestures to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomGestures;
  properties
    ..add(DiagnosticsProperty('type', 'RoomGestures'))
    ..add(DiagnosticsProperty('received', _this.received))..add(DiagnosticsProperty('sent', _this.sent))..add(DiagnosticsProperty('recent', _this.recent));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomGestures;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomGestures&&const DeepCollectionEquality().equals(other.received, _this.received)&&const DeepCollectionEquality().equals(other.sent, _this.sent)&&const DeepCollectionEquality().equals(other.recent, _this.recent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomGestures;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.received),const DeepCollectionEquality().hash(_this.sent),const DeepCollectionEquality().hash(_this.recent));
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomGestures;
  return 'RoomGestures(received: ${_this.received}, sent: ${_this.sent}, recent: ${_this.recent})';
}


}

/// @nodoc
abstract mixin class $RoomGesturesCopyWith<$Res>  {
  factory $RoomGesturesCopyWith(RoomGestures value, $Res Function(RoomGestures) _then) = _$RoomGesturesCopyWithImpl;
@useResult
$Res call({
 List<ReceivedGesture> received, List<SentGesture> sent, List<RoomGesture> recent
});




}
/// @nodoc
class _$RoomGesturesCopyWithImpl<$Res>
    implements $RoomGesturesCopyWith<$Res> {
  _$RoomGesturesCopyWithImpl(this._self, this._then);

  final RoomGestures _self;
  final $Res Function(RoomGestures) _then;

/// Create a copy of RoomGestures
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? received = null,Object? sent = null,Object? recent = null,}) {
  return _then(RoomGestures(
received: null == received ? _self.received : received // ignore: cast_nullable_to_non_nullable
as List<ReceivedGesture>,sent: null == sent ? _self.sent : sent // ignore: cast_nullable_to_non_nullable
as List<SentGesture>,recent: null == recent ? _self.recent : recent // ignore: cast_nullable_to_non_nullable
as List<RoomGesture>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomGestures].
extension RoomGesturesPatterns on RoomGestures {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomGestures value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomGestures() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomGestures value)  $default,){
final _that = this;
switch (_that) {
case _RoomGestures():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomGestures value)?  $default,){
final _that = this;
switch (_that) {
case _RoomGestures() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ReceivedGesture> received,  List<SentGesture> sent,  List<RoomGesture> recent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomGestures() when $default != null:
return $default(_that.received,_that.sent,_that.recent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ReceivedGesture> received,  List<SentGesture> sent,  List<RoomGesture> recent)  $default,) {final _that = this;
switch (_that) {
case _RoomGestures():
return $default(_that.received,_that.sent,_that.recent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ReceivedGesture> received,  List<SentGesture> sent,  List<RoomGesture> recent)?  $default,) {final _that = this;
switch (_that) {
case _RoomGestures() when $default != null:
return $default(_that.received,_that.sent,_that.recent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomGestures with DiagnosticableTreeMixin implements RoomGestures {
  const _RoomGestures({ List<ReceivedGesture> received = const <ReceivedGesture>[],  List<SentGesture> sent = const <SentGesture>[],  List<RoomGesture> recent = const <RoomGesture>[]}): _received = received,_sent = sent,_recent = recent;
  factory _RoomGestures.fromJson(Map<String, dynamic> json) => _$RoomGesturesFromJson(json);

 final  List<ReceivedGesture> _received;
@override@JsonKey() List<ReceivedGesture> get received {
  if (_received is EqualUnmodifiableListView) return _received;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_received);
}

 final  List<SentGesture> _sent;
@override@JsonKey() List<SentGesture> get sent {
  if (_sent is EqualUnmodifiableListView) return _sent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sent);
}

 final  List<RoomGesture> _recent;
@override@JsonKey() List<RoomGesture> get recent {
  if (_recent is EqualUnmodifiableListView) return _recent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recent);
}


/// Create a copy of RoomGestures
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomGesturesCopyWith<_RoomGestures> get copyWith => __$RoomGesturesCopyWithImpl<_RoomGestures>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomGesturesToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomGestures'))
    ..add(DiagnosticsProperty('received', received))..add(DiagnosticsProperty('sent', sent))..add(DiagnosticsProperty('recent', recent));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomGestures&&const DeepCollectionEquality().equals(other.received, _received)&&const DeepCollectionEquality().equals(other.sent, _sent)&&const DeepCollectionEquality().equals(other.recent, _recent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_received),const DeepCollectionEquality().hash(_sent),const DeepCollectionEquality().hash(_recent));
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomGestures(received: $received, sent: $sent, recent: $recent)';
}


}

/// @nodoc
abstract mixin class _$RoomGesturesCopyWith<$Res> implements $RoomGesturesCopyWith<$Res> {
  factory _$RoomGesturesCopyWith(_RoomGestures value, $Res Function(_RoomGestures) _then) = __$RoomGesturesCopyWithImpl;
@override @useResult
$Res call({
 List<ReceivedGesture> received, List<SentGesture> sent, List<RoomGesture> recent
});




}
/// @nodoc
class __$RoomGesturesCopyWithImpl<$Res>
    implements _$RoomGesturesCopyWith<$Res> {
  __$RoomGesturesCopyWithImpl(this._self, this._then);

  final _RoomGestures _self;
  final $Res Function(_RoomGestures) _then;

/// Create a copy of RoomGestures
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? received = null,Object? sent = null,Object? recent = null,}) {
  return _then(_RoomGestures(
received: null == received ? _self._received : received // ignore: cast_nullable_to_non_nullable
as List<ReceivedGesture>,sent: null == sent ? _self._sent : sent // ignore: cast_nullable_to_non_nullable
as List<SentGesture>,recent: null == recent ? _self._recent : recent // ignore: cast_nullable_to_non_nullable
as List<RoomGesture>,
  ));
}


}


/// @nodoc
mixin _$RealtimeTopics implements DiagnosticableTreeMixin {

 String get roomTopic; String get memberTopic;
/// Create a copy of RealtimeTopics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RealtimeTopicsCopyWith<RealtimeTopics> get copyWith => _$RealtimeTopicsCopyWithImpl<RealtimeTopics>(this as RealtimeTopics, _$identity);

  /// Serializes this RealtimeTopics to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RealtimeTopics;
  properties
    ..add(DiagnosticsProperty('type', 'RealtimeTopics'))
    ..add(DiagnosticsProperty('roomTopic', _this.roomTopic))..add(DiagnosticsProperty('memberTopic', _this.memberTopic));
}

@override
bool operator ==(Object other) {
  final _this = this as RealtimeTopics;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RealtimeTopics&&(identical(other.roomTopic, _this.roomTopic) || other.roomTopic == _this.roomTopic)&&(identical(other.memberTopic, _this.memberTopic) || other.memberTopic == _this.memberTopic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RealtimeTopics;
  return Object.hash(runtimeType,_this.roomTopic,_this.memberTopic);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RealtimeTopics;
  return 'RealtimeTopics(roomTopic: ${_this.roomTopic}, memberTopic: ${_this.memberTopic})';
}


}

/// @nodoc
abstract mixin class $RealtimeTopicsCopyWith<$Res>  {
  factory $RealtimeTopicsCopyWith(RealtimeTopics value, $Res Function(RealtimeTopics) _then) = _$RealtimeTopicsCopyWithImpl;
@useResult
$Res call({
 String roomTopic, String memberTopic
});




}
/// @nodoc
class _$RealtimeTopicsCopyWithImpl<$Res>
    implements $RealtimeTopicsCopyWith<$Res> {
  _$RealtimeTopicsCopyWithImpl(this._self, this._then);

  final RealtimeTopics _self;
  final $Res Function(RealtimeTopics) _then;

/// Create a copy of RealtimeTopics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomTopic = null,Object? memberTopic = null,}) {
  return _then(RealtimeTopics(
roomTopic: null == roomTopic ? _self.roomTopic : roomTopic // ignore: cast_nullable_to_non_nullable
as String,memberTopic: null == memberTopic ? _self.memberTopic : memberTopic // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RealtimeTopics].
extension RealtimeTopicsPatterns on RealtimeTopics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RealtimeTopics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RealtimeTopics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RealtimeTopics value)  $default,){
final _that = this;
switch (_that) {
case _RealtimeTopics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RealtimeTopics value)?  $default,){
final _that = this;
switch (_that) {
case _RealtimeTopics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomTopic,  String memberTopic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RealtimeTopics() when $default != null:
return $default(_that.roomTopic,_that.memberTopic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomTopic,  String memberTopic)  $default,) {final _that = this;
switch (_that) {
case _RealtimeTopics():
return $default(_that.roomTopic,_that.memberTopic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomTopic,  String memberTopic)?  $default,) {final _that = this;
switch (_that) {
case _RealtimeTopics() when $default != null:
return $default(_that.roomTopic,_that.memberTopic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RealtimeTopics with DiagnosticableTreeMixin implements RealtimeTopics {
  const _RealtimeTopics({required this.roomTopic, required this.memberTopic});
  factory _RealtimeTopics.fromJson(Map<String, dynamic> json) => _$RealtimeTopicsFromJson(json);

@override final  String roomTopic;
@override final  String memberTopic;

/// Create a copy of RealtimeTopics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RealtimeTopicsCopyWith<_RealtimeTopics> get copyWith => __$RealtimeTopicsCopyWithImpl<_RealtimeTopics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RealtimeTopicsToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RealtimeTopics'))
    ..add(DiagnosticsProperty('roomTopic', roomTopic))..add(DiagnosticsProperty('memberTopic', memberTopic));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RealtimeTopics&&(identical(other.roomTopic, roomTopic) || other.roomTopic == roomTopic)&&(identical(other.memberTopic, memberTopic) || other.memberTopic == memberTopic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,roomTopic,memberTopic);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RealtimeTopics(roomTopic: $roomTopic, memberTopic: $memberTopic)';
}


}

/// @nodoc
abstract mixin class _$RealtimeTopicsCopyWith<$Res> implements $RealtimeTopicsCopyWith<$Res> {
  factory _$RealtimeTopicsCopyWith(_RealtimeTopics value, $Res Function(_RealtimeTopics) _then) = __$RealtimeTopicsCopyWithImpl;
@override @useResult
$Res call({
 String roomTopic, String memberTopic
});




}
/// @nodoc
class __$RealtimeTopicsCopyWithImpl<$Res>
    implements _$RealtimeTopicsCopyWith<$Res> {
  __$RealtimeTopicsCopyWithImpl(this._self, this._then);

  final _RealtimeTopics _self;
  final $Res Function(_RealtimeTopics) _then;

/// Create a copy of RealtimeTopics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomTopic = null,Object? memberTopic = null,}) {
  return _then(_RealtimeTopics(
roomTopic: null == roomTopic ? _self.roomTopic : roomTopic // ignore: cast_nullable_to_non_nullable
as String,memberTopic: null == memberTopic ? _self.memberTopic : memberTopic // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RoomDetail implements DiagnosticableTreeMixin {

 RoomInfo get room; RoomMe get me; RoomCounts get counts;/// Current members incl. you, oldest first (blocked people left out).
 List<RoomMember> get members; RoomGestures get gestures; RealtimeTopics get realtime;
/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomDetailCopyWith<RoomDetail> get copyWith => _$RoomDetailCopyWithImpl<RoomDetail>(this as RoomDetail, _$identity);

  /// Serializes this RoomDetail to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomDetail;
  properties
    ..add(DiagnosticsProperty('type', 'RoomDetail'))
    ..add(DiagnosticsProperty('room', _this.room))..add(DiagnosticsProperty('me', _this.me))..add(DiagnosticsProperty('counts', _this.counts))..add(DiagnosticsProperty('members', _this.members))..add(DiagnosticsProperty('gestures', _this.gestures))..add(DiagnosticsProperty('realtime', _this.realtime));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomDetail&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.me, _this.me) || other.me == _this.me)&&(identical(other.counts, _this.counts) || other.counts == _this.counts)&&const DeepCollectionEquality().equals(other.members, _this.members)&&(identical(other.gestures, _this.gestures) || other.gestures == _this.gestures)&&(identical(other.realtime, _this.realtime) || other.realtime == _this.realtime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomDetail;
  return Object.hash(runtimeType,_this.room,_this.me,_this.counts,const DeepCollectionEquality().hash(_this.members),_this.gestures,_this.realtime);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomDetail;
  return 'RoomDetail(room: ${_this.room}, me: ${_this.me}, counts: ${_this.counts}, members: ${_this.members}, gestures: ${_this.gestures}, realtime: ${_this.realtime})';
}


}

/// @nodoc
abstract mixin class $RoomDetailCopyWith<$Res>  {
  factory $RoomDetailCopyWith(RoomDetail value, $Res Function(RoomDetail) _then) = _$RoomDetailCopyWithImpl;
@useResult
$Res call({
 RoomInfo room, RoomMe me, RoomCounts counts, List<RoomMember> members, RoomGestures gestures, RealtimeTopics realtime
});


$RoomInfoCopyWith<$Res> get room;$RoomMeCopyWith<$Res> get me;$RoomCountsCopyWith<$Res> get counts;$RoomGesturesCopyWith<$Res> get gestures;$RealtimeTopicsCopyWith<$Res> get realtime;

}
/// @nodoc
class _$RoomDetailCopyWithImpl<$Res>
    implements $RoomDetailCopyWith<$Res> {
  _$RoomDetailCopyWithImpl(this._self, this._then);

  final RoomDetail _self;
  final $Res Function(RoomDetail) _then;

/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? me = null,Object? counts = null,Object? members = null,Object? gestures = null,Object? realtime = null,}) {
  return _then(RoomDetail(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as RoomMe,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<RoomMember>,gestures: null == gestures ? _self.gestures : gestures // ignore: cast_nullable_to_non_nullable
as RoomGestures,realtime: null == realtime ? _self.realtime : realtime // ignore: cast_nullable_to_non_nullable
as RealtimeTopics,
  ));
}
/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomMeCopyWith<$Res> get me {
  
  return $RoomMeCopyWith<$Res>(_self.me, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomGesturesCopyWith<$Res> get gestures {
  
  return $RoomGesturesCopyWith<$Res>(_self.gestures, (value) {
    return _then(_self.copyWith(gestures: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RealtimeTopicsCopyWith<$Res> get realtime {
  
  return $RealtimeTopicsCopyWith<$Res>(_self.realtime, (value) {
    return _then(_self.copyWith(realtime: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomDetail].
extension RoomDetailPatterns on RoomDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomDetail value)  $default,){
final _that = this;
switch (_that) {
case _RoomDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomDetail value)?  $default,){
final _that = this;
switch (_that) {
case _RoomDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RoomInfo room,  RoomMe me,  RoomCounts counts,  List<RoomMember> members,  RoomGestures gestures,  RealtimeTopics realtime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomDetail() when $default != null:
return $default(_that.room,_that.me,_that.counts,_that.members,_that.gestures,_that.realtime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RoomInfo room,  RoomMe me,  RoomCounts counts,  List<RoomMember> members,  RoomGestures gestures,  RealtimeTopics realtime)  $default,) {final _that = this;
switch (_that) {
case _RoomDetail():
return $default(_that.room,_that.me,_that.counts,_that.members,_that.gestures,_that.realtime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RoomInfo room,  RoomMe me,  RoomCounts counts,  List<RoomMember> members,  RoomGestures gestures,  RealtimeTopics realtime)?  $default,) {final _that = this;
switch (_that) {
case _RoomDetail() when $default != null:
return $default(_that.room,_that.me,_that.counts,_that.members,_that.gestures,_that.realtime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomDetail with DiagnosticableTreeMixin implements RoomDetail {
  const _RoomDetail({required this.room, required this.me, this.counts = const RoomCounts(),  List<RoomMember> members = const <RoomMember>[], this.gestures = const RoomGestures(), required this.realtime}): _members = members;
  factory _RoomDetail.fromJson(Map<String, dynamic> json) => _$RoomDetailFromJson(json);

@override final  RoomInfo room;
@override final  RoomMe me;
@override@JsonKey() final  RoomCounts counts;
/// Current members incl. you, oldest first (blocked people left out).
 final  List<RoomMember> _members;
/// Current members incl. you, oldest first (blocked people left out).
@override@JsonKey() List<RoomMember> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override@JsonKey() final  RoomGestures gestures;
@override final  RealtimeTopics realtime;

/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomDetailCopyWith<_RoomDetail> get copyWith => __$RoomDetailCopyWithImpl<_RoomDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomDetailToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomDetail'))
    ..add(DiagnosticsProperty('room', room))..add(DiagnosticsProperty('me', me))..add(DiagnosticsProperty('counts', counts))..add(DiagnosticsProperty('members', members))..add(DiagnosticsProperty('gestures', gestures))..add(DiagnosticsProperty('realtime', realtime));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomDetail&&(identical(other.room, room) || other.room == room)&&(identical(other.me, me) || other.me == me)&&(identical(other.counts, counts) || other.counts == counts)&&const DeepCollectionEquality().equals(other.members, _members)&&(identical(other.gestures, gestures) || other.gestures == gestures)&&(identical(other.realtime, realtime) || other.realtime == realtime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,me,counts,const DeepCollectionEquality().hash(_members),gestures,realtime);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomDetail(room: $room, me: $me, counts: $counts, members: $members, gestures: $gestures, realtime: $realtime)';
}


}

/// @nodoc
abstract mixin class _$RoomDetailCopyWith<$Res> implements $RoomDetailCopyWith<$Res> {
  factory _$RoomDetailCopyWith(_RoomDetail value, $Res Function(_RoomDetail) _then) = __$RoomDetailCopyWithImpl;
@override @useResult
$Res call({
 RoomInfo room, RoomMe me, RoomCounts counts, List<RoomMember> members, RoomGestures gestures, RealtimeTopics realtime
});


@override $RoomInfoCopyWith<$Res> get room;@override $RoomMeCopyWith<$Res> get me;@override $RoomCountsCopyWith<$Res> get counts;@override $RoomGesturesCopyWith<$Res> get gestures;@override $RealtimeTopicsCopyWith<$Res> get realtime;

}
/// @nodoc
class __$RoomDetailCopyWithImpl<$Res>
    implements _$RoomDetailCopyWith<$Res> {
  __$RoomDetailCopyWithImpl(this._self, this._then);

  final _RoomDetail _self;
  final $Res Function(_RoomDetail) _then;

/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? me = null,Object? counts = null,Object? members = null,Object? gestures = null,Object? realtime = null,}) {
  return _then(_RoomDetail(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as RoomMe,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<RoomMember>,gestures: null == gestures ? _self.gestures : gestures // ignore: cast_nullable_to_non_nullable
as RoomGestures,realtime: null == realtime ? _self.realtime : realtime // ignore: cast_nullable_to_non_nullable
as RealtimeTopics,
  ));
}

/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomMeCopyWith<$Res> get me {
  
  return $RoomMeCopyWith<$Res>(_self.me, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomGesturesCopyWith<$Res> get gestures {
  
  return $RoomGesturesCopyWith<$Res>(_self.gestures, (value) {
    return _then(_self.copyWith(gestures: value));
  });
}/// Create a copy of RoomDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RealtimeTopicsCopyWith<$Res> get realtime {
  
  return $RealtimeTopicsCopyWith<$Res>(_self.realtime, (value) {
    return _then(_self.copyWith(realtime: value));
  });
}
}


/// @nodoc
mixin _$MatchInfo implements DiagnosticableTreeMixin {

 int get step;/// Step 0: the same room, pseudonym and memberId as before.
 bool get reentry; bool get created; bool get merged;
/// Create a copy of MatchInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchInfoCopyWith<MatchInfo> get copyWith => _$MatchInfoCopyWithImpl<MatchInfo>(this as MatchInfo, _$identity);

  /// Serializes this MatchInfo to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as MatchInfo;
  properties
    ..add(DiagnosticsProperty('type', 'MatchInfo'))
    ..add(DiagnosticsProperty('step', _this.step))..add(DiagnosticsProperty('reentry', _this.reentry))..add(DiagnosticsProperty('created', _this.created))..add(DiagnosticsProperty('merged', _this.merged));
}

@override
bool operator ==(Object other) {
  final _this = this as MatchInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchInfo&&(identical(other.step, _this.step) || other.step == _this.step)&&(identical(other.reentry, _this.reentry) || other.reentry == _this.reentry)&&(identical(other.created, _this.created) || other.created == _this.created)&&(identical(other.merged, _this.merged) || other.merged == _this.merged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MatchInfo;
  return Object.hash(runtimeType,_this.step,_this.reentry,_this.created,_this.merged);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as MatchInfo;
  return 'MatchInfo(step: ${_this.step}, reentry: ${_this.reentry}, created: ${_this.created}, merged: ${_this.merged})';
}


}

/// @nodoc
abstract mixin class $MatchInfoCopyWith<$Res>  {
  factory $MatchInfoCopyWith(MatchInfo value, $Res Function(MatchInfo) _then) = _$MatchInfoCopyWithImpl;
@useResult
$Res call({
 int step, bool reentry, bool created, bool merged
});




}
/// @nodoc
class _$MatchInfoCopyWithImpl<$Res>
    implements $MatchInfoCopyWith<$Res> {
  _$MatchInfoCopyWithImpl(this._self, this._then);

  final MatchInfo _self;
  final $Res Function(MatchInfo) _then;

/// Create a copy of MatchInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? step = null,Object? reentry = null,Object? created = null,Object? merged = null,}) {
  return _then(MatchInfo(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as int,reentry: null == reentry ? _self.reentry : reentry // ignore: cast_nullable_to_non_nullable
as bool,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,merged: null == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchInfo].
extension MatchInfoPatterns on MatchInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchInfo value)  $default,){
final _that = this;
switch (_that) {
case _MatchInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchInfo value)?  $default,){
final _that = this;
switch (_that) {
case _MatchInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int step,  bool reentry,  bool created,  bool merged)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchInfo() when $default != null:
return $default(_that.step,_that.reentry,_that.created,_that.merged);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int step,  bool reentry,  bool created,  bool merged)  $default,) {final _that = this;
switch (_that) {
case _MatchInfo():
return $default(_that.step,_that.reentry,_that.created,_that.merged);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int step,  bool reentry,  bool created,  bool merged)?  $default,) {final _that = this;
switch (_that) {
case _MatchInfo() when $default != null:
return $default(_that.step,_that.reentry,_that.created,_that.merged);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchInfo with DiagnosticableTreeMixin implements MatchInfo {
  const _MatchInfo({this.step = 0, this.reentry = false, this.created = false, this.merged = false});
  factory _MatchInfo.fromJson(Map<String, dynamic> json) => _$MatchInfoFromJson(json);

@override@JsonKey() final  int step;
/// Step 0: the same room, pseudonym and memberId as before.
@override@JsonKey() final  bool reentry;
@override@JsonKey() final  bool created;
@override@JsonKey() final  bool merged;

/// Create a copy of MatchInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchInfoCopyWith<_MatchInfo> get copyWith => __$MatchInfoCopyWithImpl<_MatchInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchInfoToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'MatchInfo'))
    ..add(DiagnosticsProperty('step', step))..add(DiagnosticsProperty('reentry', reentry))..add(DiagnosticsProperty('created', created))..add(DiagnosticsProperty('merged', merged));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchInfo&&(identical(other.step, step) || other.step == step)&&(identical(other.reentry, reentry) || other.reentry == reentry)&&(identical(other.created, created) || other.created == created)&&(identical(other.merged, merged) || other.merged == merged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,step,reentry,created,merged);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'MatchInfo(step: $step, reentry: $reentry, created: $created, merged: $merged)';
}


}

/// @nodoc
abstract mixin class _$MatchInfoCopyWith<$Res> implements $MatchInfoCopyWith<$Res> {
  factory _$MatchInfoCopyWith(_MatchInfo value, $Res Function(_MatchInfo) _then) = __$MatchInfoCopyWithImpl;
@override @useResult
$Res call({
 int step, bool reentry, bool created, bool merged
});




}
/// @nodoc
class __$MatchInfoCopyWithImpl<$Res>
    implements _$MatchInfoCopyWith<$Res> {
  __$MatchInfoCopyWithImpl(this._self, this._then);

  final _MatchInfo _self;
  final $Res Function(_MatchInfo) _then;

/// Create a copy of MatchInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? step = null,Object? reentry = null,Object? created = null,Object? merged = null,}) {
  return _then(_MatchInfo(
step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as int,reentry: null == reentry ? _self.reentry : reentry // ignore: cast_nullable_to_non_nullable
as bool,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,merged: null == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$RoomSummary implements DiagnosticableTreeMixin {

 RoomInfo get room; RoomMe get me; RoomCounts get counts;
/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomSummaryCopyWith<RoomSummary> get copyWith => _$RoomSummaryCopyWithImpl<RoomSummary>(this as RoomSummary, _$identity);

  /// Serializes this RoomSummary to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomSummary;
  properties
    ..add(DiagnosticsProperty('type', 'RoomSummary'))
    ..add(DiagnosticsProperty('room', _this.room))..add(DiagnosticsProperty('me', _this.me))..add(DiagnosticsProperty('counts', _this.counts));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomSummary&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.me, _this.me) || other.me == _this.me)&&(identical(other.counts, _this.counts) || other.counts == _this.counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomSummary;
  return Object.hash(runtimeType,_this.room,_this.me,_this.counts);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomSummary;
  return 'RoomSummary(room: ${_this.room}, me: ${_this.me}, counts: ${_this.counts})';
}


}

/// @nodoc
abstract mixin class $RoomSummaryCopyWith<$Res>  {
  factory $RoomSummaryCopyWith(RoomSummary value, $Res Function(RoomSummary) _then) = _$RoomSummaryCopyWithImpl;
@useResult
$Res call({
 RoomInfo room, RoomMe me, RoomCounts counts
});


$RoomInfoCopyWith<$Res> get room;$RoomMeCopyWith<$Res> get me;$RoomCountsCopyWith<$Res> get counts;

}
/// @nodoc
class _$RoomSummaryCopyWithImpl<$Res>
    implements $RoomSummaryCopyWith<$Res> {
  _$RoomSummaryCopyWithImpl(this._self, this._then);

  final RoomSummary _self;
  final $Res Function(RoomSummary) _then;

/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? me = null,Object? counts = null,}) {
  return _then(RoomSummary(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as RoomMe,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,
  ));
}
/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomMeCopyWith<$Res> get me {
  
  return $RoomMeCopyWith<$Res>(_self.me, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomSummary].
extension RoomSummaryPatterns on RoomSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomSummary value)  $default,){
final _that = this;
switch (_that) {
case _RoomSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomSummary value)?  $default,){
final _that = this;
switch (_that) {
case _RoomSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RoomInfo room,  RoomMe me,  RoomCounts counts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomSummary() when $default != null:
return $default(_that.room,_that.me,_that.counts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RoomInfo room,  RoomMe me,  RoomCounts counts)  $default,) {final _that = this;
switch (_that) {
case _RoomSummary():
return $default(_that.room,_that.me,_that.counts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RoomInfo room,  RoomMe me,  RoomCounts counts)?  $default,) {final _that = this;
switch (_that) {
case _RoomSummary() when $default != null:
return $default(_that.room,_that.me,_that.counts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomSummary with DiagnosticableTreeMixin implements RoomSummary {
  const _RoomSummary({required this.room, required this.me, this.counts = const RoomCounts()});
  factory _RoomSummary.fromJson(Map<String, dynamic> json) => _$RoomSummaryFromJson(json);

@override final  RoomInfo room;
@override final  RoomMe me;
@override@JsonKey() final  RoomCounts counts;

/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomSummaryCopyWith<_RoomSummary> get copyWith => __$RoomSummaryCopyWithImpl<_RoomSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomSummaryToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomSummary'))
    ..add(DiagnosticsProperty('room', room))..add(DiagnosticsProperty('me', me))..add(DiagnosticsProperty('counts', counts));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomSummary&&(identical(other.room, room) || other.room == room)&&(identical(other.me, me) || other.me == me)&&(identical(other.counts, counts) || other.counts == counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,me,counts);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomSummary(room: $room, me: $me, counts: $counts)';
}


}

/// @nodoc
abstract mixin class _$RoomSummaryCopyWith<$Res> implements $RoomSummaryCopyWith<$Res> {
  factory _$RoomSummaryCopyWith(_RoomSummary value, $Res Function(_RoomSummary) _then) = __$RoomSummaryCopyWithImpl;
@override @useResult
$Res call({
 RoomInfo room, RoomMe me, RoomCounts counts
});


@override $RoomInfoCopyWith<$Res> get room;@override $RoomMeCopyWith<$Res> get me;@override $RoomCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$RoomSummaryCopyWithImpl<$Res>
    implements _$RoomSummaryCopyWith<$Res> {
  __$RoomSummaryCopyWithImpl(this._self, this._then);

  final _RoomSummary _self;
  final $Res Function(_RoomSummary) _then;

/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? me = null,Object? counts = null,}) {
  return _then(_RoomSummary(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,me: null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as RoomMe,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,
  ));
}

/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomMeCopyWith<$Res> get me {
  
  return $RoomMeCopyWith<$Res>(_self.me, (value) {
    return _then(_self.copyWith(me: value));
  });
}/// Create a copy of RoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// @nodoc
mixin _$HeartbeatResult implements DiagnosticableTreeMixin {

 RoomInfo get room; RoomCounts get counts;
/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeartbeatResultCopyWith<HeartbeatResult> get copyWith => _$HeartbeatResultCopyWithImpl<HeartbeatResult>(this as HeartbeatResult, _$identity);

  /// Serializes this HeartbeatResult to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as HeartbeatResult;
  properties
    ..add(DiagnosticsProperty('type', 'HeartbeatResult'))
    ..add(DiagnosticsProperty('room', _this.room))..add(DiagnosticsProperty('counts', _this.counts));
}

@override
bool operator ==(Object other) {
  final _this = this as HeartbeatResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeartbeatResult&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.counts, _this.counts) || other.counts == _this.counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HeartbeatResult;
  return Object.hash(runtimeType,_this.room,_this.counts);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as HeartbeatResult;
  return 'HeartbeatResult(room: ${_this.room}, counts: ${_this.counts})';
}


}

/// @nodoc
abstract mixin class $HeartbeatResultCopyWith<$Res>  {
  factory $HeartbeatResultCopyWith(HeartbeatResult value, $Res Function(HeartbeatResult) _then) = _$HeartbeatResultCopyWithImpl;
@useResult
$Res call({
 RoomInfo room, RoomCounts counts
});


$RoomInfoCopyWith<$Res> get room;$RoomCountsCopyWith<$Res> get counts;

}
/// @nodoc
class _$HeartbeatResultCopyWithImpl<$Res>
    implements $HeartbeatResultCopyWith<$Res> {
  _$HeartbeatResultCopyWithImpl(this._self, this._then);

  final HeartbeatResult _self;
  final $Res Function(HeartbeatResult) _then;

/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? counts = null,}) {
  return _then(HeartbeatResult(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,
  ));
}
/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// Adds pattern-matching-related methods to [HeartbeatResult].
extension HeartbeatResultPatterns on HeartbeatResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeartbeatResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeartbeatResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeartbeatResult value)  $default,){
final _that = this;
switch (_that) {
case _HeartbeatResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeartbeatResult value)?  $default,){
final _that = this;
switch (_that) {
case _HeartbeatResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RoomInfo room,  RoomCounts counts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeartbeatResult() when $default != null:
return $default(_that.room,_that.counts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RoomInfo room,  RoomCounts counts)  $default,) {final _that = this;
switch (_that) {
case _HeartbeatResult():
return $default(_that.room,_that.counts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RoomInfo room,  RoomCounts counts)?  $default,) {final _that = this;
switch (_that) {
case _HeartbeatResult() when $default != null:
return $default(_that.room,_that.counts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HeartbeatResult with DiagnosticableTreeMixin implements HeartbeatResult {
  const _HeartbeatResult({required this.room, this.counts = const RoomCounts()});
  factory _HeartbeatResult.fromJson(Map<String, dynamic> json) => _$HeartbeatResultFromJson(json);

@override final  RoomInfo room;
@override@JsonKey() final  RoomCounts counts;

/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeartbeatResultCopyWith<_HeartbeatResult> get copyWith => __$HeartbeatResultCopyWithImpl<_HeartbeatResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeartbeatResultToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'HeartbeatResult'))
    ..add(DiagnosticsProperty('room', room))..add(DiagnosticsProperty('counts', counts));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeartbeatResult&&(identical(other.room, room) || other.room == room)&&(identical(other.counts, counts) || other.counts == counts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,counts);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'HeartbeatResult(room: $room, counts: $counts)';
}


}

/// @nodoc
abstract mixin class _$HeartbeatResultCopyWith<$Res> implements $HeartbeatResultCopyWith<$Res> {
  factory _$HeartbeatResultCopyWith(_HeartbeatResult value, $Res Function(_HeartbeatResult) _then) = __$HeartbeatResultCopyWithImpl;
@override @useResult
$Res call({
 RoomInfo room, RoomCounts counts
});


@override $RoomInfoCopyWith<$Res> get room;@override $RoomCountsCopyWith<$Res> get counts;

}
/// @nodoc
class __$HeartbeatResultCopyWithImpl<$Res>
    implements _$HeartbeatResultCopyWith<$Res> {
  __$HeartbeatResultCopyWithImpl(this._self, this._then);

  final _HeartbeatResult _self;
  final $Res Function(_HeartbeatResult) _then;

/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? counts = null,}) {
  return _then(_HeartbeatResult(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as RoomInfo,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as RoomCounts,
  ));
}

/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomInfoCopyWith<$Res> get room {
  
  return $RoomInfoCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}/// Create a copy of HeartbeatResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomCountsCopyWith<$Res> get counts {
  
  return $RoomCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}
}


/// @nodoc
mixin _$GestureAck implements DiagnosticableTreeMixin {

 String get gestureId; DateTime get at;
/// Create a copy of GestureAck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureAckCopyWith<GestureAck> get copyWith => _$GestureAckCopyWithImpl<GestureAck>(this as GestureAck, _$identity);

  /// Serializes this GestureAck to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as GestureAck;
  properties
    ..add(DiagnosticsProperty('type', 'GestureAck'))
    ..add(DiagnosticsProperty('gestureId', _this.gestureId))..add(DiagnosticsProperty('at', _this.at));
}

@override
bool operator ==(Object other) {
  final _this = this as GestureAck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureAck&&(identical(other.gestureId, _this.gestureId) || other.gestureId == _this.gestureId)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GestureAck;
  return Object.hash(runtimeType,_this.gestureId,_this.at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as GestureAck;
  return 'GestureAck(gestureId: ${_this.gestureId}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $GestureAckCopyWith<$Res>  {
  factory $GestureAckCopyWith(GestureAck value, $Res Function(GestureAck) _then) = _$GestureAckCopyWithImpl;
@useResult
$Res call({
 String gestureId, DateTime at
});




}
/// @nodoc
class _$GestureAckCopyWithImpl<$Res>
    implements $GestureAckCopyWith<$Res> {
  _$GestureAckCopyWithImpl(this._self, this._then);

  final GestureAck _self;
  final $Res Function(GestureAck) _then;

/// Create a copy of GestureAck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gestureId = null,Object? at = null,}) {
  return _then(GestureAck(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [GestureAck].
extension GestureAckPatterns on GestureAck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GestureAck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GestureAck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GestureAck value)  $default,){
final _that = this;
switch (_that) {
case _GestureAck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GestureAck value)?  $default,){
final _that = this;
switch (_that) {
case _GestureAck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String gestureId,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GestureAck() when $default != null:
return $default(_that.gestureId,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String gestureId,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _GestureAck():
return $default(_that.gestureId,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String gestureId,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _GestureAck() when $default != null:
return $default(_that.gestureId,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GestureAck with DiagnosticableTreeMixin implements GestureAck {
  const _GestureAck({required this.gestureId, required this.at});
  factory _GestureAck.fromJson(Map<String, dynamic> json) => _$GestureAckFromJson(json);

@override final  String gestureId;
@override final  DateTime at;

/// Create a copy of GestureAck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GestureAckCopyWith<_GestureAck> get copyWith => __$GestureAckCopyWithImpl<_GestureAck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureAckToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'GestureAck'))
    ..add(DiagnosticsProperty('gestureId', gestureId))..add(DiagnosticsProperty('at', at));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GestureAck&&(identical(other.gestureId, gestureId) || other.gestureId == gestureId)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gestureId,at);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'GestureAck(gestureId: $gestureId, at: $at)';
}


}

/// @nodoc
abstract mixin class _$GestureAckCopyWith<$Res> implements $GestureAckCopyWith<$Res> {
  factory _$GestureAckCopyWith(_GestureAck value, $Res Function(_GestureAck) _then) = __$GestureAckCopyWithImpl;
@override @useResult
$Res call({
 String gestureId, DateTime at
});




}
/// @nodoc
class __$GestureAckCopyWithImpl<$Res>
    implements _$GestureAckCopyWith<$Res> {
  __$GestureAckCopyWithImpl(this._self, this._then);

  final _GestureAck _self;
  final $Res Function(_GestureAck) _then;

/// Create a copy of GestureAck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gestureId = null,Object? at = null,}) {
  return _then(_GestureAck(
gestureId: null == gestureId ? _self.gestureId : gestureId // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ReportAck implements DiagnosticableTreeMixin {

 String get reportId;/// Reason 1 (crisis lane): the reporter sees helplines at once.
 bool get showHelplines;
/// Create a copy of ReportAck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportAckCopyWith<ReportAck> get copyWith => _$ReportAckCopyWithImpl<ReportAck>(this as ReportAck, _$identity);

  /// Serializes this ReportAck to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as ReportAck;
  properties
    ..add(DiagnosticsProperty('type', 'ReportAck'))
    ..add(DiagnosticsProperty('reportId', _this.reportId))..add(DiagnosticsProperty('showHelplines', _this.showHelplines));
}

@override
bool operator ==(Object other) {
  final _this = this as ReportAck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportAck&&(identical(other.reportId, _this.reportId) || other.reportId == _this.reportId)&&(identical(other.showHelplines, _this.showHelplines) || other.showHelplines == _this.showHelplines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReportAck;
  return Object.hash(runtimeType,_this.reportId,_this.showHelplines);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as ReportAck;
  return 'ReportAck(reportId: ${_this.reportId}, showHelplines: ${_this.showHelplines})';
}


}

/// @nodoc
abstract mixin class $ReportAckCopyWith<$Res>  {
  factory $ReportAckCopyWith(ReportAck value, $Res Function(ReportAck) _then) = _$ReportAckCopyWithImpl;
@useResult
$Res call({
 String reportId, bool showHelplines
});




}
/// @nodoc
class _$ReportAckCopyWithImpl<$Res>
    implements $ReportAckCopyWith<$Res> {
  _$ReportAckCopyWithImpl(this._self, this._then);

  final ReportAck _self;
  final $Res Function(ReportAck) _then;

/// Create a copy of ReportAck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reportId = null,Object? showHelplines = null,}) {
  return _then(ReportAck(
reportId: null == reportId ? _self.reportId : reportId // ignore: cast_nullable_to_non_nullable
as String,showHelplines: null == showHelplines ? _self.showHelplines : showHelplines // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportAck].
extension ReportAckPatterns on ReportAck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportAck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportAck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportAck value)  $default,){
final _that = this;
switch (_that) {
case _ReportAck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportAck value)?  $default,){
final _that = this;
switch (_that) {
case _ReportAck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reportId,  bool showHelplines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportAck() when $default != null:
return $default(_that.reportId,_that.showHelplines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reportId,  bool showHelplines)  $default,) {final _that = this;
switch (_that) {
case _ReportAck():
return $default(_that.reportId,_that.showHelplines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reportId,  bool showHelplines)?  $default,) {final _that = this;
switch (_that) {
case _ReportAck() when $default != null:
return $default(_that.reportId,_that.showHelplines);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReportAck with DiagnosticableTreeMixin implements ReportAck {
  const _ReportAck({required this.reportId, this.showHelplines = false});
  factory _ReportAck.fromJson(Map<String, dynamic> json) => _$ReportAckFromJson(json);

@override final  String reportId;
/// Reason 1 (crisis lane): the reporter sees helplines at once.
@override@JsonKey() final  bool showHelplines;

/// Create a copy of ReportAck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportAckCopyWith<_ReportAck> get copyWith => __$ReportAckCopyWithImpl<_ReportAck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReportAckToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'ReportAck'))
    ..add(DiagnosticsProperty('reportId', reportId))..add(DiagnosticsProperty('showHelplines', showHelplines));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportAck&&(identical(other.reportId, reportId) || other.reportId == reportId)&&(identical(other.showHelplines, showHelplines) || other.showHelplines == showHelplines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reportId,showHelplines);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'ReportAck(reportId: $reportId, showHelplines: $showHelplines)';
}


}

/// @nodoc
abstract mixin class _$ReportAckCopyWith<$Res> implements $ReportAckCopyWith<$Res> {
  factory _$ReportAckCopyWith(_ReportAck value, $Res Function(_ReportAck) _then) = __$ReportAckCopyWithImpl;
@override @useResult
$Res call({
 String reportId, bool showHelplines
});




}
/// @nodoc
class __$ReportAckCopyWithImpl<$Res>
    implements _$ReportAckCopyWith<$Res> {
  __$ReportAckCopyWithImpl(this._self, this._then);

  final _ReportAck _self;
  final $Res Function(_ReportAck) _then;

/// Create a copy of ReportAck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reportId = null,Object? showHelplines = null,}) {
  return _then(_ReportAck(
reportId: null == reportId ? _self.reportId : reportId // ignore: cast_nullable_to_non_nullable
as String,showHelplines: null == showHelplines ? _self.showHelplines : showHelplines // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SafetyStanding implements DiagnosticableTreeMixin {

/// `available` · `suspended` · `closed`.
 String get rooms; DateTime? get until;
/// Create a copy of SafetyStanding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SafetyStandingCopyWith<SafetyStanding> get copyWith => _$SafetyStandingCopyWithImpl<SafetyStanding>(this as SafetyStanding, _$identity);

  /// Serializes this SafetyStanding to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as SafetyStanding;
  properties
    ..add(DiagnosticsProperty('type', 'SafetyStanding'))
    ..add(DiagnosticsProperty('rooms', _this.rooms))..add(DiagnosticsProperty('until', _this.until));
}

@override
bool operator ==(Object other) {
  final _this = this as SafetyStanding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SafetyStanding&&(identical(other.rooms, _this.rooms) || other.rooms == _this.rooms)&&(identical(other.until, _this.until) || other.until == _this.until));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SafetyStanding;
  return Object.hash(runtimeType,_this.rooms,_this.until);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as SafetyStanding;
  return 'SafetyStanding(rooms: ${_this.rooms}, until: ${_this.until})';
}


}

/// @nodoc
abstract mixin class $SafetyStandingCopyWith<$Res>  {
  factory $SafetyStandingCopyWith(SafetyStanding value, $Res Function(SafetyStanding) _then) = _$SafetyStandingCopyWithImpl;
@useResult
$Res call({
 String rooms, DateTime? until
});




}
/// @nodoc
class _$SafetyStandingCopyWithImpl<$Res>
    implements $SafetyStandingCopyWith<$Res> {
  _$SafetyStandingCopyWithImpl(this._self, this._then);

  final SafetyStanding _self;
  final $Res Function(SafetyStanding) _then;

/// Create a copy of SafetyStanding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rooms = null,Object? until = freezed,}) {
  return _then(SafetyStanding(
rooms: null == rooms ? _self.rooms : rooms // ignore: cast_nullable_to_non_nullable
as String,until: freezed == until ? _self.until : until // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SafetyStanding].
extension SafetyStandingPatterns on SafetyStanding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SafetyStanding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SafetyStanding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SafetyStanding value)  $default,){
final _that = this;
switch (_that) {
case _SafetyStanding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SafetyStanding value)?  $default,){
final _that = this;
switch (_that) {
case _SafetyStanding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String rooms,  DateTime? until)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SafetyStanding() when $default != null:
return $default(_that.rooms,_that.until);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String rooms,  DateTime? until)  $default,) {final _that = this;
switch (_that) {
case _SafetyStanding():
return $default(_that.rooms,_that.until);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String rooms,  DateTime? until)?  $default,) {final _that = this;
switch (_that) {
case _SafetyStanding() when $default != null:
return $default(_that.rooms,_that.until);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SafetyStanding with DiagnosticableTreeMixin implements SafetyStanding {
  const _SafetyStanding({this.rooms = 'available', this.until});
  factory _SafetyStanding.fromJson(Map<String, dynamic> json) => _$SafetyStandingFromJson(json);

/// `available` · `suspended` · `closed`.
@override@JsonKey() final  String rooms;
@override final  DateTime? until;

/// Create a copy of SafetyStanding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SafetyStandingCopyWith<_SafetyStanding> get copyWith => __$SafetyStandingCopyWithImpl<_SafetyStanding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SafetyStandingToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'SafetyStanding'))
    ..add(DiagnosticsProperty('rooms', rooms))..add(DiagnosticsProperty('until', until));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SafetyStanding&&(identical(other.rooms, rooms) || other.rooms == rooms)&&(identical(other.until, until) || other.until == until));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,rooms,until);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'SafetyStanding(rooms: $rooms, until: $until)';
}


}

/// @nodoc
abstract mixin class _$SafetyStandingCopyWith<$Res> implements $SafetyStandingCopyWith<$Res> {
  factory _$SafetyStandingCopyWith(_SafetyStanding value, $Res Function(_SafetyStanding) _then) = __$SafetyStandingCopyWithImpl;
@override @useResult
$Res call({
 String rooms, DateTime? until
});




}
/// @nodoc
class __$SafetyStandingCopyWithImpl<$Res>
    implements _$SafetyStandingCopyWith<$Res> {
  __$SafetyStandingCopyWithImpl(this._self, this._then);

  final _SafetyStanding _self;
  final $Res Function(_SafetyStanding) _then;

/// Create a copy of SafetyStanding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rooms = null,Object? until = freezed,}) {
  return _then(_SafetyStanding(
rooms: null == rooms ? _self.rooms : rooms // ignore: cast_nullable_to_non_nullable
as String,until: freezed == until ? _self.until : until // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
