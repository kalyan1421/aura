// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streak.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreakState {


/// Create a copy of StreakState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreakStateCopyWith<StreakState> get copyWith => _$StreakStateCopyWithImpl<StreakState>(this as StreakState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StreakState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreakState&&(identical(other.glowStreak, _this.glowStreak) || other.glowStreak == _this.glowStreak)&&(identical(other.lifetimeGlowDays, _this.lifetimeGlowDays) || other.lifetimeGlowDays == _this.lifetimeGlowDays)&&(identical(other.restBank, _this.restBank) || other.restBank == _this.restBank)&&(identical(other.earnCounter, _this.earnCounter) || other.earnCounter == _this.earnCounter)&&(identical(other.lastActiveDay, _this.lastActiveDay) || other.lastActiveDay == _this.lastActiveDay));
}


@override
int get hashCode {
  final _this = this as StreakState;
  return Object.hash(runtimeType,_this.glowStreak,_this.lifetimeGlowDays,_this.restBank,_this.earnCounter,_this.lastActiveDay);
}

@override
String toString() {
  final _this = this as StreakState;
  return 'StreakState(glowStreak: ${_this.glowStreak}, lifetimeGlowDays: ${_this.lifetimeGlowDays}, restBank: ${_this.restBank}, earnCounter: ${_this.earnCounter}, lastActiveDay: ${_this.lastActiveDay})';
}


}

/// @nodoc
abstract mixin class $StreakStateCopyWith<$Res>  {
  factory $StreakStateCopyWith(StreakState value, $Res Function(StreakState) _then) = _$StreakStateCopyWithImpl;
@useResult
$Res call({
 int glowStreak, int lifetimeGlowDays, int restBank, int earnCounter, LocalDay? lastActiveDay
});




}
/// @nodoc
class _$StreakStateCopyWithImpl<$Res>
    implements $StreakStateCopyWith<$Res> {
  _$StreakStateCopyWithImpl(this._self, this._then);

  final StreakState _self;
  final $Res Function(StreakState) _then;

/// Create a copy of StreakState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? glowStreak = null,Object? lifetimeGlowDays = null,Object? restBank = null,Object? earnCounter = null,Object? lastActiveDay = freezed,}) {
  return _then(StreakState(
glowStreak: null == glowStreak ? _self.glowStreak : glowStreak // ignore: cast_nullable_to_non_nullable
as int,lifetimeGlowDays: null == lifetimeGlowDays ? _self.lifetimeGlowDays : lifetimeGlowDays // ignore: cast_nullable_to_non_nullable
as int,restBank: null == restBank ? _self.restBank : restBank // ignore: cast_nullable_to_non_nullable
as int,earnCounter: null == earnCounter ? _self.earnCounter : earnCounter // ignore: cast_nullable_to_non_nullable
as int,lastActiveDay: freezed == lastActiveDay ? _self.lastActiveDay : lastActiveDay // ignore: cast_nullable_to_non_nullable
as LocalDay?,
  ));
}

}


/// Adds pattern-matching-related methods to [StreakState].
extension StreakStatePatterns on StreakState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
