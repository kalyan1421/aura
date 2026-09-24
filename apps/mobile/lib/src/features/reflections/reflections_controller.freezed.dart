// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reflections_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoomReflectionsState implements DiagnosticableTreeMixin {

 ReflectionsLoad get load;/// Newest first, as the server sent them (minus what you just hid).
 List<Reflection> get reflections; ReflectionComposer? get composer;/// Why the list couldn't load (kept with an older list on screen).
 ReflectionsFailure? get failure;/// The gestures rest for [reflectionGestureCooldown] after a send.
 bool get coolingDown;/// Bumped when one of your reflections was crisis-diverted after the
/// composer closed (`reflection_status`): the room opens the support
/// sheet at once.
 int get supportSerial;
/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomReflectionsStateCopyWith<RoomReflectionsState> get copyWith => _$RoomReflectionsStateCopyWithImpl<RoomReflectionsState>(this as RoomReflectionsState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as RoomReflectionsState;
  properties
    ..add(DiagnosticsProperty('type', 'RoomReflectionsState'))
    ..add(DiagnosticsProperty('load', _this.load))..add(DiagnosticsProperty('reflections', _this.reflections))..add(DiagnosticsProperty('composer', _this.composer))..add(DiagnosticsProperty('failure', _this.failure))..add(DiagnosticsProperty('coolingDown', _this.coolingDown))..add(DiagnosticsProperty('supportSerial', _this.supportSerial));
}

@override
bool operator ==(Object other) {
  final _this = this as RoomReflectionsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomReflectionsState&&(identical(other.load, _this.load) || other.load == _this.load)&&const DeepCollectionEquality().equals(other.reflections, _this.reflections)&&(identical(other.composer, _this.composer) || other.composer == _this.composer)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.coolingDown, _this.coolingDown) || other.coolingDown == _this.coolingDown)&&(identical(other.supportSerial, _this.supportSerial) || other.supportSerial == _this.supportSerial));
}


@override
int get hashCode {
  final _this = this as RoomReflectionsState;
  return Object.hash(runtimeType,_this.load,const DeepCollectionEquality().hash(_this.reflections),_this.composer,_this.failure,_this.coolingDown,_this.supportSerial);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as RoomReflectionsState;
  return 'RoomReflectionsState(load: ${_this.load}, reflections: ${_this.reflections}, composer: ${_this.composer}, failure: ${_this.failure}, coolingDown: ${_this.coolingDown}, supportSerial: ${_this.supportSerial})';
}


}

/// @nodoc
abstract mixin class $RoomReflectionsStateCopyWith<$Res>  {
  factory $RoomReflectionsStateCopyWith(RoomReflectionsState value, $Res Function(RoomReflectionsState) _then) = _$RoomReflectionsStateCopyWithImpl;
@useResult
$Res call({
 ReflectionsLoad load, List<Reflection> reflections, ReflectionComposer? composer, ReflectionsFailure? failure, bool coolingDown, int supportSerial
});


$ReflectionComposerCopyWith<$Res>? get composer;

}
/// @nodoc
class _$RoomReflectionsStateCopyWithImpl<$Res>
    implements $RoomReflectionsStateCopyWith<$Res> {
  _$RoomReflectionsStateCopyWithImpl(this._self, this._then);

  final RoomReflectionsState _self;
  final $Res Function(RoomReflectionsState) _then;

/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? load = null,Object? reflections = null,Object? composer = freezed,Object? failure = freezed,Object? coolingDown = null,Object? supportSerial = null,}) {
  return _then(RoomReflectionsState(
load: null == load ? _self.load : load // ignore: cast_nullable_to_non_nullable
as ReflectionsLoad,reflections: null == reflections ? _self.reflections : reflections // ignore: cast_nullable_to_non_nullable
as List<Reflection>,composer: freezed == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ReflectionsFailure?,coolingDown: null == coolingDown ? _self.coolingDown : coolingDown // ignore: cast_nullable_to_non_nullable
as bool,supportSerial: null == supportSerial ? _self.supportSerial : supportSerial // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res>? get composer {
    if (_self.composer == null) {
    return null;
  }

  return $ReflectionComposerCopyWith<$Res>(_self.composer!, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}


/// Adds pattern-matching-related methods to [RoomReflectionsState].
extension RoomReflectionsStatePatterns on RoomReflectionsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomReflectionsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomReflectionsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomReflectionsState value)  $default,){
final _that = this;
switch (_that) {
case _RoomReflectionsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomReflectionsState value)?  $default,){
final _that = this;
switch (_that) {
case _RoomReflectionsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReflectionsLoad load,  List<Reflection> reflections,  ReflectionComposer? composer,  ReflectionsFailure? failure,  bool coolingDown,  int supportSerial)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomReflectionsState() when $default != null:
return $default(_that.load,_that.reflections,_that.composer,_that.failure,_that.coolingDown,_that.supportSerial);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReflectionsLoad load,  List<Reflection> reflections,  ReflectionComposer? composer,  ReflectionsFailure? failure,  bool coolingDown,  int supportSerial)  $default,) {final _that = this;
switch (_that) {
case _RoomReflectionsState():
return $default(_that.load,_that.reflections,_that.composer,_that.failure,_that.coolingDown,_that.supportSerial);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReflectionsLoad load,  List<Reflection> reflections,  ReflectionComposer? composer,  ReflectionsFailure? failure,  bool coolingDown,  int supportSerial)?  $default,) {final _that = this;
switch (_that) {
case _RoomReflectionsState() when $default != null:
return $default(_that.load,_that.reflections,_that.composer,_that.failure,_that.coolingDown,_that.supportSerial);case _:
  return null;

}
}

}

/// @nodoc


class _RoomReflectionsState extends RoomReflectionsState with DiagnosticableTreeMixin {
  const _RoomReflectionsState({this.load = ReflectionsLoad.loading,  List<Reflection> reflections = const <Reflection>[], this.composer, this.failure, this.coolingDown = false, this.supportSerial = 0}): _reflections = reflections,super._();
  

@override@JsonKey() final  ReflectionsLoad load;
/// Newest first, as the server sent them (minus what you just hid).
 final  List<Reflection> _reflections;
/// Newest first, as the server sent them (minus what you just hid).
@override@JsonKey() List<Reflection> get reflections {
  if (_reflections is EqualUnmodifiableListView) return _reflections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reflections);
}

@override final  ReflectionComposer? composer;
/// Why the list couldn't load (kept with an older list on screen).
@override final  ReflectionsFailure? failure;
/// The gestures rest for [reflectionGestureCooldown] after a send.
@override@JsonKey() final  bool coolingDown;
/// Bumped when one of your reflections was crisis-diverted after the
/// composer closed (`reflection_status`): the room opens the support
/// sheet at once.
@override@JsonKey() final  int supportSerial;

/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomReflectionsStateCopyWith<_RoomReflectionsState> get copyWith => __$RoomReflectionsStateCopyWithImpl<_RoomReflectionsState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'RoomReflectionsState'))
    ..add(DiagnosticsProperty('load', load))..add(DiagnosticsProperty('reflections', reflections))..add(DiagnosticsProperty('composer', composer))..add(DiagnosticsProperty('failure', failure))..add(DiagnosticsProperty('coolingDown', coolingDown))..add(DiagnosticsProperty('supportSerial', supportSerial));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomReflectionsState&&(identical(other.load, load) || other.load == load)&&const DeepCollectionEquality().equals(other.reflections, _reflections)&&(identical(other.composer, composer) || other.composer == composer)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.coolingDown, coolingDown) || other.coolingDown == coolingDown)&&(identical(other.supportSerial, supportSerial) || other.supportSerial == supportSerial));
}


@override
int get hashCode {
    return Object.hash(runtimeType,load,const DeepCollectionEquality().hash(_reflections),composer,failure,coolingDown,supportSerial);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'RoomReflectionsState(load: $load, reflections: $reflections, composer: $composer, failure: $failure, coolingDown: $coolingDown, supportSerial: $supportSerial)';
}


}

/// @nodoc
abstract mixin class _$RoomReflectionsStateCopyWith<$Res> implements $RoomReflectionsStateCopyWith<$Res> {
  factory _$RoomReflectionsStateCopyWith(_RoomReflectionsState value, $Res Function(_RoomReflectionsState) _then) = __$RoomReflectionsStateCopyWithImpl;
@override @useResult
$Res call({
 ReflectionsLoad load, List<Reflection> reflections, ReflectionComposer? composer, ReflectionsFailure? failure, bool coolingDown, int supportSerial
});


@override $ReflectionComposerCopyWith<$Res>? get composer;

}
/// @nodoc
class __$RoomReflectionsStateCopyWithImpl<$Res>
    implements _$RoomReflectionsStateCopyWith<$Res> {
  __$RoomReflectionsStateCopyWithImpl(this._self, this._then);

  final _RoomReflectionsState _self;
  final $Res Function(_RoomReflectionsState) _then;

/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? load = null,Object? reflections = null,Object? composer = freezed,Object? failure = freezed,Object? coolingDown = null,Object? supportSerial = null,}) {
  return _then(_RoomReflectionsState(
load: null == load ? _self.load : load // ignore: cast_nullable_to_non_nullable
as ReflectionsLoad,reflections: null == reflections ? _self._reflections : reflections // ignore: cast_nullable_to_non_nullable
as List<Reflection>,composer: freezed == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ReflectionsFailure?,coolingDown: null == coolingDown ? _self.coolingDown : coolingDown // ignore: cast_nullable_to_non_nullable
as bool,supportSerial: null == supportSerial ? _self.supportSerial : supportSerial // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of RoomReflectionsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res>? get composer {
    if (_self.composer == null) {
    return null;
  }

  return $ReflectionComposerCopyWith<$Res>(_self.composer!, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}

// dart format on
