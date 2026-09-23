// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoomViewState {

 RoomLoad get load; RoomDetail? get detail;/// Why the room can't show (with no [detail]), or why it ended (gone,
/// suspended, …).
 RoomsFailure? get failure; RoomLink get link; List<PendingGesture> get pending;/// The tray rests for [gestureCooldown] after a send.
 bool get coolingDown; GestureMoment? get moment;/// You left: nothing more is sent or heard.
 bool get left;
/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomViewStateCopyWith<RoomViewState> get copyWith => _$RoomViewStateCopyWithImpl<RoomViewState>(this as RoomViewState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RoomViewState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomViewState&&(identical(other.load, _this.load) || other.load == _this.load)&&(identical(other.detail, _this.detail) || other.detail == _this.detail)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.link, _this.link) || other.link == _this.link)&&const DeepCollectionEquality().equals(other.pending, _this.pending)&&(identical(other.coolingDown, _this.coolingDown) || other.coolingDown == _this.coolingDown)&&(identical(other.moment, _this.moment) || other.moment == _this.moment)&&(identical(other.left, _this.left) || other.left == _this.left));
}


@override
int get hashCode {
  final _this = this as RoomViewState;
  return Object.hash(runtimeType,_this.load,_this.detail,_this.failure,_this.link,const DeepCollectionEquality().hash(_this.pending),_this.coolingDown,_this.moment,_this.left);
}

@override
String toString() {
  final _this = this as RoomViewState;
  return 'RoomViewState(load: ${_this.load}, detail: ${_this.detail}, failure: ${_this.failure}, link: ${_this.link}, pending: ${_this.pending}, coolingDown: ${_this.coolingDown}, moment: ${_this.moment}, left: ${_this.left})';
}


}

/// @nodoc
abstract mixin class $RoomViewStateCopyWith<$Res>  {
  factory $RoomViewStateCopyWith(RoomViewState value, $Res Function(RoomViewState) _then) = _$RoomViewStateCopyWithImpl;
@useResult
$Res call({
 RoomLoad load, RoomDetail? detail, RoomsFailure? failure, RoomLink link, List<PendingGesture> pending, bool coolingDown, GestureMoment? moment, bool left
});


$RoomDetailCopyWith<$Res>? get detail;

}
/// @nodoc
class _$RoomViewStateCopyWithImpl<$Res>
    implements $RoomViewStateCopyWith<$Res> {
  _$RoomViewStateCopyWithImpl(this._self, this._then);

  final RoomViewState _self;
  final $Res Function(RoomViewState) _then;

/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? load = null,Object? detail = freezed,Object? failure = freezed,Object? link = null,Object? pending = null,Object? coolingDown = null,Object? moment = freezed,Object? left = null,}) {
  return _then(RoomViewState(
load: null == load ? _self.load : load // ignore: cast_nullable_to_non_nullable
as RoomLoad,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as RoomDetail?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RoomsFailure?,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as RoomLink,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as List<PendingGesture>,coolingDown: null == coolingDown ? _self.coolingDown : coolingDown // ignore: cast_nullable_to_non_nullable
as bool,moment: freezed == moment ? _self.moment : moment // ignore: cast_nullable_to_non_nullable
as GestureMoment?,left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomDetailCopyWith<$Res>? get detail {
    if (_self.detail == null) {
    return null;
  }

  return $RoomDetailCopyWith<$Res>(_self.detail!, (value) {
    return _then(_self.copyWith(detail: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomViewState].
extension RoomViewStatePatterns on RoomViewState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomViewState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomViewState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomViewState value)  $default,){
final _that = this;
switch (_that) {
case _RoomViewState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomViewState value)?  $default,){
final _that = this;
switch (_that) {
case _RoomViewState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RoomLoad load,  RoomDetail? detail,  RoomsFailure? failure,  RoomLink link,  List<PendingGesture> pending,  bool coolingDown,  GestureMoment? moment,  bool left)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomViewState() when $default != null:
return $default(_that.load,_that.detail,_that.failure,_that.link,_that.pending,_that.coolingDown,_that.moment,_that.left);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RoomLoad load,  RoomDetail? detail,  RoomsFailure? failure,  RoomLink link,  List<PendingGesture> pending,  bool coolingDown,  GestureMoment? moment,  bool left)  $default,) {final _that = this;
switch (_that) {
case _RoomViewState():
return $default(_that.load,_that.detail,_that.failure,_that.link,_that.pending,_that.coolingDown,_that.moment,_that.left);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RoomLoad load,  RoomDetail? detail,  RoomsFailure? failure,  RoomLink link,  List<PendingGesture> pending,  bool coolingDown,  GestureMoment? moment,  bool left)?  $default,) {final _that = this;
switch (_that) {
case _RoomViewState() when $default != null:
return $default(_that.load,_that.detail,_that.failure,_that.link,_that.pending,_that.coolingDown,_that.moment,_that.left);case _:
  return null;

}
}

}

/// @nodoc


class _RoomViewState extends RoomViewState {
  const _RoomViewState({this.load = RoomLoad.loading, this.detail, this.failure, this.link = RoomLink.off,  List<PendingGesture> pending = const <PendingGesture>[], this.coolingDown = false, this.moment, this.left = false}): _pending = pending,super._();
  

@override@JsonKey() final  RoomLoad load;
@override final  RoomDetail? detail;
/// Why the room can't show (with no [detail]), or why it ended (gone,
/// suspended, …).
@override final  RoomsFailure? failure;
@override@JsonKey() final  RoomLink link;
 final  List<PendingGesture> _pending;
@override@JsonKey() List<PendingGesture> get pending {
  if (_pending is EqualUnmodifiableListView) return _pending;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pending);
}

/// The tray rests for [gestureCooldown] after a send.
@override@JsonKey() final  bool coolingDown;
@override final  GestureMoment? moment;
/// You left: nothing more is sent or heard.
@override@JsonKey() final  bool left;

/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomViewStateCopyWith<_RoomViewState> get copyWith => __$RoomViewStateCopyWithImpl<_RoomViewState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomViewState&&(identical(other.load, load) || other.load == load)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.link, link) || other.link == link)&&const DeepCollectionEquality().equals(other.pending, _pending)&&(identical(other.coolingDown, coolingDown) || other.coolingDown == coolingDown)&&(identical(other.moment, moment) || other.moment == moment)&&(identical(other.left, left) || other.left == left));
}


@override
int get hashCode {
    return Object.hash(runtimeType,load,detail,failure,link,const DeepCollectionEquality().hash(_pending),coolingDown,moment,left);
}

@override
String toString() {
    return 'RoomViewState(load: $load, detail: $detail, failure: $failure, link: $link, pending: $pending, coolingDown: $coolingDown, moment: $moment, left: $left)';
}


}

/// @nodoc
abstract mixin class _$RoomViewStateCopyWith<$Res> implements $RoomViewStateCopyWith<$Res> {
  factory _$RoomViewStateCopyWith(_RoomViewState value, $Res Function(_RoomViewState) _then) = __$RoomViewStateCopyWithImpl;
@override @useResult
$Res call({
 RoomLoad load, RoomDetail? detail, RoomsFailure? failure, RoomLink link, List<PendingGesture> pending, bool coolingDown, GestureMoment? moment, bool left
});


@override $RoomDetailCopyWith<$Res>? get detail;

}
/// @nodoc
class __$RoomViewStateCopyWithImpl<$Res>
    implements _$RoomViewStateCopyWith<$Res> {
  __$RoomViewStateCopyWithImpl(this._self, this._then);

  final _RoomViewState _self;
  final $Res Function(_RoomViewState) _then;

/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? load = null,Object? detail = freezed,Object? failure = freezed,Object? link = null,Object? pending = null,Object? coolingDown = null,Object? moment = freezed,Object? left = null,}) {
  return _then(_RoomViewState(
load: null == load ? _self.load : load // ignore: cast_nullable_to_non_nullable
as RoomLoad,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as RoomDetail?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as RoomsFailure?,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as RoomLink,pending: null == pending ? _self._pending : pending // ignore: cast_nullable_to_non_nullable
as List<PendingGesture>,coolingDown: null == coolingDown ? _self.coolingDown : coolingDown // ignore: cast_nullable_to_non_nullable
as bool,moment: freezed == moment ? _self.moment : moment // ignore: cast_nullable_to_non_nullable
as GestureMoment?,left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RoomViewState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomDetailCopyWith<$Res>? get detail {
    if (_self.detail == null) {
    return null;
  }

  return $RoomDetailCopyWith<$Res>(_self.detail!, (value) {
    return _then(_self.copyWith(detail: value));
  });
}
}

// dart format on
