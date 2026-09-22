// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'aura_avatar_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuraAvatarState {


/// Create a copy of AuraAvatarState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuraAvatarStateCopyWith<AuraAvatarState> get copyWith => _$AuraAvatarStateCopyWithImpl<AuraAvatarState>(this as AuraAvatarState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AuraAvatarState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuraAvatarState&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.hue, _this.hue) || other.hue == _this.hue)&&(identical(other.isResting, _this.isResting) || other.isResting == _this.isResting)&&(identical(other.ringCount, _this.ringCount) || other.ringCount == _this.ringCount)&&(identical(other.glowLevel, _this.glowLevel) || other.glowLevel == _this.glowLevel)&&(identical(other.constellationStars, _this.constellationStars) || other.constellationStars == _this.constellationStars)&&const DeepCollectionEquality().equals(other.equippedCosmetics, _this.equippedCosmetics));
}


@override
int get hashCode {
  final _this = this as AuraAvatarState;
  return Object.hash(runtimeType,_this.stage,_this.hue,_this.isResting,_this.ringCount,_this.glowLevel,_this.constellationStars,const DeepCollectionEquality().hash(_this.equippedCosmetics));
}

@override
String toString() {
  final _this = this as AuraAvatarState;
  return 'AuraAvatarState(stage: ${_this.stage}, hue: ${_this.hue}, isResting: ${_this.isResting}, ringCount: ${_this.ringCount}, glowLevel: ${_this.glowLevel}, constellationStars: ${_this.constellationStars}, equippedCosmetics: ${_this.equippedCosmetics})';
}


}

/// @nodoc
abstract mixin class $AuraAvatarStateCopyWith<$Res>  {
  factory $AuraAvatarStateCopyWith(AuraAvatarState value, $Res Function(AuraAvatarState) _then) = _$AuraAvatarStateCopyWithImpl;
@useResult
$Res call({
 AuraStage stage, double hue, bool isResting, int ringCount, int glowLevel, int constellationStars, Set<CosmeticId> equippedCosmetics
});




}
/// @nodoc
class _$AuraAvatarStateCopyWithImpl<$Res>
    implements $AuraAvatarStateCopyWith<$Res> {
  _$AuraAvatarStateCopyWithImpl(this._self, this._then);

  final AuraAvatarState _self;
  final $Res Function(AuraAvatarState) _then;

/// Create a copy of AuraAvatarState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? hue = null,Object? isResting = null,Object? ringCount = null,Object? glowLevel = null,Object? constellationStars = null,Object? equippedCosmetics = null,}) {
  return _then(AuraAvatarState(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as AuraStage,hue: null == hue ? _self.hue : hue // ignore: cast_nullable_to_non_nullable
as double,isResting: null == isResting ? _self.isResting : isResting // ignore: cast_nullable_to_non_nullable
as bool,ringCount: null == ringCount ? _self.ringCount : ringCount // ignore: cast_nullable_to_non_nullable
as int,glowLevel: null == glowLevel ? _self.glowLevel : glowLevel // ignore: cast_nullable_to_non_nullable
as int,constellationStars: null == constellationStars ? _self.constellationStars : constellationStars // ignore: cast_nullable_to_non_nullable
as int,equippedCosmetics: null == equippedCosmetics ? _self.equippedCosmetics : equippedCosmetics // ignore: cast_nullable_to_non_nullable
as Set<CosmeticId>,
  ));
}

}


/// Adds pattern-matching-related methods to [AuraAvatarState].
extension AuraAvatarStatePatterns on AuraAvatarState {
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
