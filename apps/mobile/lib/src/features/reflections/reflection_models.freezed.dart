// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reflection_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReflectionAuthor {

 String get memberId;/// The room pseudonym ("Quiet Comet"); never translated.
 String get pseudonym;
/// Create a copy of ReflectionAuthor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReflectionAuthorCopyWith<ReflectionAuthor> get copyWith => _$ReflectionAuthorCopyWithImpl<ReflectionAuthor>(this as ReflectionAuthor, _$identity);

  /// Serializes this ReflectionAuthor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReflectionAuthor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReflectionAuthor&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&(identical(other.pseudonym, _this.pseudonym) || other.pseudonym == _this.pseudonym));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReflectionAuthor;
  return Object.hash(runtimeType,_this.memberId,_this.pseudonym);
}

@override
String toString() {
  final _this = this as ReflectionAuthor;
  return 'ReflectionAuthor(memberId: ${_this.memberId}, pseudonym: ${_this.pseudonym})';
}


}

/// @nodoc
abstract mixin class $ReflectionAuthorCopyWith<$Res>  {
  factory $ReflectionAuthorCopyWith(ReflectionAuthor value, $Res Function(ReflectionAuthor) _then) = _$ReflectionAuthorCopyWithImpl;
@useResult
$Res call({
 String memberId, String pseudonym
});




}
/// @nodoc
class _$ReflectionAuthorCopyWithImpl<$Res>
    implements $ReflectionAuthorCopyWith<$Res> {
  _$ReflectionAuthorCopyWithImpl(this._self, this._then);

  final ReflectionAuthor _self;
  final $Res Function(ReflectionAuthor) _then;

/// Create a copy of ReflectionAuthor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? memberId = null,Object? pseudonym = null,}) {
  return _then(ReflectionAuthor(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReflectionAuthor].
extension ReflectionAuthorPatterns on ReflectionAuthor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReflectionAuthor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReflectionAuthor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReflectionAuthor value)  $default,){
final _that = this;
switch (_that) {
case _ReflectionAuthor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReflectionAuthor value)?  $default,){
final _that = this;
switch (_that) {
case _ReflectionAuthor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String memberId,  String pseudonym)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReflectionAuthor() when $default != null:
return $default(_that.memberId,_that.pseudonym);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String memberId,  String pseudonym)  $default,) {final _that = this;
switch (_that) {
case _ReflectionAuthor():
return $default(_that.memberId,_that.pseudonym);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String memberId,  String pseudonym)?  $default,) {final _that = this;
switch (_that) {
case _ReflectionAuthor() when $default != null:
return $default(_that.memberId,_that.pseudonym);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReflectionAuthor implements ReflectionAuthor {
  const _ReflectionAuthor({required this.memberId, required this.pseudonym});
  factory _ReflectionAuthor.fromJson(Map<String, dynamic> json) => _$ReflectionAuthorFromJson(json);

@override final  String memberId;
/// The room pseudonym ("Quiet Comet"); never translated.
@override final  String pseudonym;

/// Create a copy of ReflectionAuthor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReflectionAuthorCopyWith<_ReflectionAuthor> get copyWith => __$ReflectionAuthorCopyWithImpl<_ReflectionAuthor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReflectionAuthorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReflectionAuthor&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.pseudonym, pseudonym) || other.pseudonym == pseudonym));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,memberId,pseudonym);
}

@override
String toString() {
    return 'ReflectionAuthor(memberId: $memberId, pseudonym: $pseudonym)';
}


}

/// @nodoc
abstract mixin class _$ReflectionAuthorCopyWith<$Res> implements $ReflectionAuthorCopyWith<$Res> {
  factory _$ReflectionAuthorCopyWith(_ReflectionAuthor value, $Res Function(_ReflectionAuthor) _then) = __$ReflectionAuthorCopyWithImpl;
@override @useResult
$Res call({
 String memberId, String pseudonym
});




}
/// @nodoc
class __$ReflectionAuthorCopyWithImpl<$Res>
    implements _$ReflectionAuthorCopyWith<$Res> {
  __$ReflectionAuthorCopyWithImpl(this._self, this._then);

  final _ReflectionAuthor _self;
  final $Res Function(_ReflectionAuthor) _then;

/// Create a copy of ReflectionAuthor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? memberId = null,Object? pseudonym = null,}) {
  return _then(_ReflectionAuthor(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,pseudonym: null == pseudonym ? _self.pseudonym : pseudonym // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Reflection {

 String get reflectionId; String get status; ReflectionAuthor get author; bool get isMine;/// As written (never translated). Never logged.
 String get text; DateTime get createdAt; DateTime? get publishedAt;/// Delivered gestures on it: your own published ones only.
 int? get gestureCount; String? get rejectReason; String? get review;
/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReflectionCopyWith<Reflection> get copyWith => _$ReflectionCopyWithImpl<Reflection>(this as Reflection, _$identity);

  /// Serializes this Reflection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Reflection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reflection&&(identical(other.reflectionId, _this.reflectionId) || other.reflectionId == _this.reflectionId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.isMine, _this.isMine) || other.isMine == _this.isMine)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.publishedAt, _this.publishedAt) || other.publishedAt == _this.publishedAt)&&(identical(other.gestureCount, _this.gestureCount) || other.gestureCount == _this.gestureCount)&&(identical(other.rejectReason, _this.rejectReason) || other.rejectReason == _this.rejectReason)&&(identical(other.review, _this.review) || other.review == _this.review));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Reflection;
  return Object.hash(runtimeType,_this.reflectionId,_this.status,_this.author,_this.isMine,_this.text,_this.createdAt,_this.publishedAt,_this.gestureCount,_this.rejectReason,_this.review);
}

@override
String toString() {
  final _this = this as Reflection;
  return 'Reflection(reflectionId: ${_this.reflectionId}, status: ${_this.status}, author: ${_this.author}, isMine: ${_this.isMine}, text: ${_this.text}, createdAt: ${_this.createdAt}, publishedAt: ${_this.publishedAt}, gestureCount: ${_this.gestureCount}, rejectReason: ${_this.rejectReason}, review: ${_this.review})';
}


}

/// @nodoc
abstract mixin class $ReflectionCopyWith<$Res>  {
  factory $ReflectionCopyWith(Reflection value, $Res Function(Reflection) _then) = _$ReflectionCopyWithImpl;
@useResult
$Res call({
 String reflectionId, String status, ReflectionAuthor author, bool isMine, String text, DateTime createdAt, DateTime? publishedAt, int? gestureCount, String? rejectReason, String? review
});


$ReflectionAuthorCopyWith<$Res> get author;

}
/// @nodoc
class _$ReflectionCopyWithImpl<$Res>
    implements $ReflectionCopyWith<$Res> {
  _$ReflectionCopyWithImpl(this._self, this._then);

  final Reflection _self;
  final $Res Function(Reflection) _then;

/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reflectionId = null,Object? status = null,Object? author = null,Object? isMine = null,Object? text = null,Object? createdAt = null,Object? publishedAt = freezed,Object? gestureCount = freezed,Object? rejectReason = freezed,Object? review = freezed,}) {
  return _then(Reflection(
reflectionId: null == reflectionId ? _self.reflectionId : reflectionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as ReflectionAuthor,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,gestureCount: freezed == gestureCount ? _self.gestureCount : gestureCount // ignore: cast_nullable_to_non_nullable
as int?,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionAuthorCopyWith<$Res> get author {
  
  return $ReflectionAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [Reflection].
extension ReflectionPatterns on Reflection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Reflection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Reflection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Reflection value)  $default,){
final _that = this;
switch (_that) {
case _Reflection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Reflection value)?  $default,){
final _that = this;
switch (_that) {
case _Reflection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reflectionId,  String status,  ReflectionAuthor author,  bool isMine,  String text,  DateTime createdAt,  DateTime? publishedAt,  int? gestureCount,  String? rejectReason,  String? review)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reflection() when $default != null:
return $default(_that.reflectionId,_that.status,_that.author,_that.isMine,_that.text,_that.createdAt,_that.publishedAt,_that.gestureCount,_that.rejectReason,_that.review);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reflectionId,  String status,  ReflectionAuthor author,  bool isMine,  String text,  DateTime createdAt,  DateTime? publishedAt,  int? gestureCount,  String? rejectReason,  String? review)  $default,) {final _that = this;
switch (_that) {
case _Reflection():
return $default(_that.reflectionId,_that.status,_that.author,_that.isMine,_that.text,_that.createdAt,_that.publishedAt,_that.gestureCount,_that.rejectReason,_that.review);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reflectionId,  String status,  ReflectionAuthor author,  bool isMine,  String text,  DateTime createdAt,  DateTime? publishedAt,  int? gestureCount,  String? rejectReason,  String? review)?  $default,) {final _that = this;
switch (_that) {
case _Reflection() when $default != null:
return $default(_that.reflectionId,_that.status,_that.author,_that.isMine,_that.text,_that.createdAt,_that.publishedAt,_that.gestureCount,_that.rejectReason,_that.review);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Reflection extends Reflection {
  const _Reflection({required this.reflectionId, this.status = 'published', required this.author, this.isMine = false, this.text = '', required this.createdAt, this.publishedAt, this.gestureCount, this.rejectReason, this.review}): super._();
  factory _Reflection.fromJson(Map<String, dynamic> json) => _$ReflectionFromJson(json);

@override final  String reflectionId;
@override@JsonKey() final  String status;
@override final  ReflectionAuthor author;
@override@JsonKey() final  bool isMine;
/// As written (never translated). Never logged.
@override@JsonKey() final  String text;
@override final  DateTime createdAt;
@override final  DateTime? publishedAt;
/// Delivered gestures on it: your own published ones only.
@override final  int? gestureCount;
@override final  String? rejectReason;
@override final  String? review;

/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReflectionCopyWith<_Reflection> get copyWith => __$ReflectionCopyWithImpl<_Reflection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReflectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reflection&&(identical(other.reflectionId, reflectionId) || other.reflectionId == reflectionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.author, author) || other.author == author)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.text, text) || other.text == text)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.gestureCount, gestureCount) || other.gestureCount == gestureCount)&&(identical(other.rejectReason, rejectReason) || other.rejectReason == rejectReason)&&(identical(other.review, review) || other.review == review));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reflectionId,status,author,isMine,text,createdAt,publishedAt,gestureCount,rejectReason,review);
}

@override
String toString() {
    return 'Reflection(reflectionId: $reflectionId, status: $status, author: $author, isMine: $isMine, text: $text, createdAt: $createdAt, publishedAt: $publishedAt, gestureCount: $gestureCount, rejectReason: $rejectReason, review: $review)';
}


}

/// @nodoc
abstract mixin class _$ReflectionCopyWith<$Res> implements $ReflectionCopyWith<$Res> {
  factory _$ReflectionCopyWith(_Reflection value, $Res Function(_Reflection) _then) = __$ReflectionCopyWithImpl;
@override @useResult
$Res call({
 String reflectionId, String status, ReflectionAuthor author, bool isMine, String text, DateTime createdAt, DateTime? publishedAt, int? gestureCount, String? rejectReason, String? review
});


@override $ReflectionAuthorCopyWith<$Res> get author;

}
/// @nodoc
class __$ReflectionCopyWithImpl<$Res>
    implements _$ReflectionCopyWith<$Res> {
  __$ReflectionCopyWithImpl(this._self, this._then);

  final _Reflection _self;
  final $Res Function(_Reflection) _then;

/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reflectionId = null,Object? status = null,Object? author = null,Object? isMine = null,Object? text = null,Object? createdAt = null,Object? publishedAt = freezed,Object? gestureCount = freezed,Object? rejectReason = freezed,Object? review = freezed,}) {
  return _then(_Reflection(
reflectionId: null == reflectionId ? _self.reflectionId : reflectionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as ReflectionAuthor,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,gestureCount: freezed == gestureCount ? _self.gestureCount : gestureCount // ignore: cast_nullable_to_non_nullable
as int?,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Reflection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionAuthorCopyWith<$Res> get author {
  
  return $ReflectionAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// @nodoc
mixin _$ReflectionComposer {

 String get state; int get maxChars; int get perRoom;/// "2 of 3 left today" (rolling 24 h).
 int get remainingInRoom;/// Of 10 across rooms (rolling 24 h).
 int get remainingToday;/// The automatic check is degraded: "Reflections are slower right now".
 bool get slow;
/// Create a copy of ReflectionComposer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<ReflectionComposer> get copyWith => _$ReflectionComposerCopyWithImpl<ReflectionComposer>(this as ReflectionComposer, _$identity);

  /// Serializes this ReflectionComposer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReflectionComposer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReflectionComposer&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.maxChars, _this.maxChars) || other.maxChars == _this.maxChars)&&(identical(other.perRoom, _this.perRoom) || other.perRoom == _this.perRoom)&&(identical(other.remainingInRoom, _this.remainingInRoom) || other.remainingInRoom == _this.remainingInRoom)&&(identical(other.remainingToday, _this.remainingToday) || other.remainingToday == _this.remainingToday)&&(identical(other.slow, _this.slow) || other.slow == _this.slow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReflectionComposer;
  return Object.hash(runtimeType,_this.state,_this.maxChars,_this.perRoom,_this.remainingInRoom,_this.remainingToday,_this.slow);
}

@override
String toString() {
  final _this = this as ReflectionComposer;
  return 'ReflectionComposer(state: ${_this.state}, maxChars: ${_this.maxChars}, perRoom: ${_this.perRoom}, remainingInRoom: ${_this.remainingInRoom}, remainingToday: ${_this.remainingToday}, slow: ${_this.slow})';
}


}

/// @nodoc
abstract mixin class $ReflectionComposerCopyWith<$Res>  {
  factory $ReflectionComposerCopyWith(ReflectionComposer value, $Res Function(ReflectionComposer) _then) = _$ReflectionComposerCopyWithImpl;
@useResult
$Res call({
 String state, int maxChars, int perRoom, int remainingInRoom, int remainingToday, bool slow
});




}
/// @nodoc
class _$ReflectionComposerCopyWithImpl<$Res>
    implements $ReflectionComposerCopyWith<$Res> {
  _$ReflectionComposerCopyWithImpl(this._self, this._then);

  final ReflectionComposer _self;
  final $Res Function(ReflectionComposer) _then;

/// Create a copy of ReflectionComposer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? maxChars = null,Object? perRoom = null,Object? remainingInRoom = null,Object? remainingToday = null,Object? slow = null,}) {
  return _then(ReflectionComposer(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,maxChars: null == maxChars ? _self.maxChars : maxChars // ignore: cast_nullable_to_non_nullable
as int,perRoom: null == perRoom ? _self.perRoom : perRoom // ignore: cast_nullable_to_non_nullable
as int,remainingInRoom: null == remainingInRoom ? _self.remainingInRoom : remainingInRoom // ignore: cast_nullable_to_non_nullable
as int,remainingToday: null == remainingToday ? _self.remainingToday : remainingToday // ignore: cast_nullable_to_non_nullable
as int,slow: null == slow ? _self.slow : slow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReflectionComposer].
extension ReflectionComposerPatterns on ReflectionComposer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReflectionComposer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReflectionComposer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReflectionComposer value)  $default,){
final _that = this;
switch (_that) {
case _ReflectionComposer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReflectionComposer value)?  $default,){
final _that = this;
switch (_that) {
case _ReflectionComposer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String state,  int maxChars,  int perRoom,  int remainingInRoom,  int remainingToday,  bool slow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReflectionComposer() when $default != null:
return $default(_that.state,_that.maxChars,_that.perRoom,_that.remainingInRoom,_that.remainingToday,_that.slow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String state,  int maxChars,  int perRoom,  int remainingInRoom,  int remainingToday,  bool slow)  $default,) {final _that = this;
switch (_that) {
case _ReflectionComposer():
return $default(_that.state,_that.maxChars,_that.perRoom,_that.remainingInRoom,_that.remainingToday,_that.slow);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String state,  int maxChars,  int perRoom,  int remainingInRoom,  int remainingToday,  bool slow)?  $default,) {final _that = this;
switch (_that) {
case _ReflectionComposer() when $default != null:
return $default(_that.state,_that.maxChars,_that.perRoom,_that.remainingInRoom,_that.remainingToday,_that.slow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReflectionComposer extends ReflectionComposer {
  const _ReflectionComposer({this.state = 'open', this.maxChars = 200, this.perRoom = 3, this.remainingInRoom = 3, this.remainingToday = 10, this.slow = false}): super._();
  factory _ReflectionComposer.fromJson(Map<String, dynamic> json) => _$ReflectionComposerFromJson(json);

@override@JsonKey() final  String state;
@override@JsonKey() final  int maxChars;
@override@JsonKey() final  int perRoom;
/// "2 of 3 left today" (rolling 24 h).
@override@JsonKey() final  int remainingInRoom;
/// Of 10 across rooms (rolling 24 h).
@override@JsonKey() final  int remainingToday;
/// The automatic check is degraded: "Reflections are slower right now".
@override@JsonKey() final  bool slow;

/// Create a copy of ReflectionComposer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReflectionComposerCopyWith<_ReflectionComposer> get copyWith => __$ReflectionComposerCopyWithImpl<_ReflectionComposer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReflectionComposerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReflectionComposer&&(identical(other.state, state) || other.state == state)&&(identical(other.maxChars, maxChars) || other.maxChars == maxChars)&&(identical(other.perRoom, perRoom) || other.perRoom == perRoom)&&(identical(other.remainingInRoom, remainingInRoom) || other.remainingInRoom == remainingInRoom)&&(identical(other.remainingToday, remainingToday) || other.remainingToday == remainingToday)&&(identical(other.slow, slow) || other.slow == slow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state,maxChars,perRoom,remainingInRoom,remainingToday,slow);
}

@override
String toString() {
    return 'ReflectionComposer(state: $state, maxChars: $maxChars, perRoom: $perRoom, remainingInRoom: $remainingInRoom, remainingToday: $remainingToday, slow: $slow)';
}


}

/// @nodoc
abstract mixin class _$ReflectionComposerCopyWith<$Res> implements $ReflectionComposerCopyWith<$Res> {
  factory _$ReflectionComposerCopyWith(_ReflectionComposer value, $Res Function(_ReflectionComposer) _then) = __$ReflectionComposerCopyWithImpl;
@override @useResult
$Res call({
 String state, int maxChars, int perRoom, int remainingInRoom, int remainingToday, bool slow
});




}
/// @nodoc
class __$ReflectionComposerCopyWithImpl<$Res>
    implements _$ReflectionComposerCopyWith<$Res> {
  __$ReflectionComposerCopyWithImpl(this._self, this._then);

  final _ReflectionComposer _self;
  final $Res Function(_ReflectionComposer) _then;

/// Create a copy of ReflectionComposer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? maxChars = null,Object? perRoom = null,Object? remainingInRoom = null,Object? remainingToday = null,Object? slow = null,}) {
  return _then(_ReflectionComposer(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,maxChars: null == maxChars ? _self.maxChars : maxChars // ignore: cast_nullable_to_non_nullable
as int,perRoom: null == perRoom ? _self.perRoom : perRoom // ignore: cast_nullable_to_non_nullable
as int,remainingInRoom: null == remainingInRoom ? _self.remainingInRoom : remainingInRoom // ignore: cast_nullable_to_non_nullable
as int,remainingToday: null == remainingToday ? _self.remainingToday : remainingToday // ignore: cast_nullable_to_non_nullable
as int,slow: null == slow ? _self.slow : slow // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ReflectionList {

/// Newest first (by `createdAt`; no ranking).
 List<Reflection> get reflections; ReflectionComposer get composer;
/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReflectionListCopyWith<ReflectionList> get copyWith => _$ReflectionListCopyWithImpl<ReflectionList>(this as ReflectionList, _$identity);

  /// Serializes this ReflectionList to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReflectionList;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReflectionList&&const DeepCollectionEquality().equals(other.reflections, _this.reflections)&&(identical(other.composer, _this.composer) || other.composer == _this.composer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReflectionList;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.reflections),_this.composer);
}

@override
String toString() {
  final _this = this as ReflectionList;
  return 'ReflectionList(reflections: ${_this.reflections}, composer: ${_this.composer})';
}


}

/// @nodoc
abstract mixin class $ReflectionListCopyWith<$Res>  {
  factory $ReflectionListCopyWith(ReflectionList value, $Res Function(ReflectionList) _then) = _$ReflectionListCopyWithImpl;
@useResult
$Res call({
 List<Reflection> reflections, ReflectionComposer composer
});


$ReflectionComposerCopyWith<$Res> get composer;

}
/// @nodoc
class _$ReflectionListCopyWithImpl<$Res>
    implements $ReflectionListCopyWith<$Res> {
  _$ReflectionListCopyWithImpl(this._self, this._then);

  final ReflectionList _self;
  final $Res Function(ReflectionList) _then;

/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reflections = null,Object? composer = null,}) {
  return _then(ReflectionList(
reflections: null == reflections ? _self.reflections : reflections // ignore: cast_nullable_to_non_nullable
as List<Reflection>,composer: null == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer,
  ));
}
/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res> get composer {
  
  return $ReflectionComposerCopyWith<$Res>(_self.composer, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReflectionList].
extension ReflectionListPatterns on ReflectionList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReflectionList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReflectionList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReflectionList value)  $default,){
final _that = this;
switch (_that) {
case _ReflectionList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReflectionList value)?  $default,){
final _that = this;
switch (_that) {
case _ReflectionList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Reflection> reflections,  ReflectionComposer composer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReflectionList() when $default != null:
return $default(_that.reflections,_that.composer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Reflection> reflections,  ReflectionComposer composer)  $default,) {final _that = this;
switch (_that) {
case _ReflectionList():
return $default(_that.reflections,_that.composer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Reflection> reflections,  ReflectionComposer composer)?  $default,) {final _that = this;
switch (_that) {
case _ReflectionList() when $default != null:
return $default(_that.reflections,_that.composer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReflectionList implements ReflectionList {
  const _ReflectionList({ List<Reflection> reflections = const <Reflection>[], this.composer = const ReflectionComposer()}): _reflections = reflections;
  factory _ReflectionList.fromJson(Map<String, dynamic> json) => _$ReflectionListFromJson(json);

/// Newest first (by `createdAt`; no ranking).
 final  List<Reflection> _reflections;
/// Newest first (by `createdAt`; no ranking).
@override@JsonKey() List<Reflection> get reflections {
  if (_reflections is EqualUnmodifiableListView) return _reflections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reflections);
}

@override@JsonKey() final  ReflectionComposer composer;

/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReflectionListCopyWith<_ReflectionList> get copyWith => __$ReflectionListCopyWithImpl<_ReflectionList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReflectionListToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReflectionList&&const DeepCollectionEquality().equals(other.reflections, _reflections)&&(identical(other.composer, composer) || other.composer == composer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_reflections),composer);
}

@override
String toString() {
    return 'ReflectionList(reflections: $reflections, composer: $composer)';
}


}

/// @nodoc
abstract mixin class _$ReflectionListCopyWith<$Res> implements $ReflectionListCopyWith<$Res> {
  factory _$ReflectionListCopyWith(_ReflectionList value, $Res Function(_ReflectionList) _then) = __$ReflectionListCopyWithImpl;
@override @useResult
$Res call({
 List<Reflection> reflections, ReflectionComposer composer
});


@override $ReflectionComposerCopyWith<$Res> get composer;

}
/// @nodoc
class __$ReflectionListCopyWithImpl<$Res>
    implements _$ReflectionListCopyWith<$Res> {
  __$ReflectionListCopyWithImpl(this._self, this._then);

  final _ReflectionList _self;
  final $Res Function(_ReflectionList) _then;

/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reflections = null,Object? composer = null,}) {
  return _then(_ReflectionList(
reflections: null == reflections ? _self._reflections : reflections // ignore: cast_nullable_to_non_nullable
as List<Reflection>,composer: null == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer,
  ));
}

/// Create a copy of ReflectionList
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res> get composer {
  
  return $ReflectionComposerCopyWith<$Res>(_self.composer, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}


/// @nodoc
mixin _$SendOutcome {

 String get reflectionId; String get status; String? get rejectReason; String? get review;/// `crisis_diverted` only: open the F9 support sheet at once.
 bool get showSupport;/// The stored item (null for rejected-by-rules and crisis_diverted).
 Reflection? get reflection; ReflectionComposer get composer;
/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendOutcomeCopyWith<SendOutcome> get copyWith => _$SendOutcomeCopyWithImpl<SendOutcome>(this as SendOutcome, _$identity);

  /// Serializes this SendOutcome to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SendOutcome;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendOutcome&&(identical(other.reflectionId, _this.reflectionId) || other.reflectionId == _this.reflectionId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.rejectReason, _this.rejectReason) || other.rejectReason == _this.rejectReason)&&(identical(other.review, _this.review) || other.review == _this.review)&&(identical(other.showSupport, _this.showSupport) || other.showSupport == _this.showSupport)&&(identical(other.reflection, _this.reflection) || other.reflection == _this.reflection)&&(identical(other.composer, _this.composer) || other.composer == _this.composer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SendOutcome;
  return Object.hash(runtimeType,_this.reflectionId,_this.status,_this.rejectReason,_this.review,_this.showSupport,_this.reflection,_this.composer);
}

@override
String toString() {
  final _this = this as SendOutcome;
  return 'SendOutcome(reflectionId: ${_this.reflectionId}, status: ${_this.status}, rejectReason: ${_this.rejectReason}, review: ${_this.review}, showSupport: ${_this.showSupport}, reflection: ${_this.reflection}, composer: ${_this.composer})';
}


}

/// @nodoc
abstract mixin class $SendOutcomeCopyWith<$Res>  {
  factory $SendOutcomeCopyWith(SendOutcome value, $Res Function(SendOutcome) _then) = _$SendOutcomeCopyWithImpl;
@useResult
$Res call({
 String reflectionId, String status, String? rejectReason, String? review, bool showSupport, Reflection? reflection, ReflectionComposer composer
});


$ReflectionCopyWith<$Res>? get reflection;$ReflectionComposerCopyWith<$Res> get composer;

}
/// @nodoc
class _$SendOutcomeCopyWithImpl<$Res>
    implements $SendOutcomeCopyWith<$Res> {
  _$SendOutcomeCopyWithImpl(this._self, this._then);

  final SendOutcome _self;
  final $Res Function(SendOutcome) _then;

/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reflectionId = null,Object? status = null,Object? rejectReason = freezed,Object? review = freezed,Object? showSupport = null,Object? reflection = freezed,Object? composer = null,}) {
  return _then(SendOutcome(
reflectionId: null == reflectionId ? _self.reflectionId : reflectionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,showSupport: null == showSupport ? _self.showSupport : showSupport // ignore: cast_nullable_to_non_nullable
as bool,reflection: freezed == reflection ? _self.reflection : reflection // ignore: cast_nullable_to_non_nullable
as Reflection?,composer: null == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer,
  ));
}
/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionCopyWith<$Res>? get reflection {
    if (_self.reflection == null) {
    return null;
  }

  return $ReflectionCopyWith<$Res>(_self.reflection!, (value) {
    return _then(_self.copyWith(reflection: value));
  });
}/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res> get composer {
  
  return $ReflectionComposerCopyWith<$Res>(_self.composer, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}


/// Adds pattern-matching-related methods to [SendOutcome].
extension SendOutcomePatterns on SendOutcome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SendOutcome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SendOutcome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SendOutcome value)  $default,){
final _that = this;
switch (_that) {
case _SendOutcome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SendOutcome value)?  $default,){
final _that = this;
switch (_that) {
case _SendOutcome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reflectionId,  String status,  String? rejectReason,  String? review,  bool showSupport,  Reflection? reflection,  ReflectionComposer composer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SendOutcome() when $default != null:
return $default(_that.reflectionId,_that.status,_that.rejectReason,_that.review,_that.showSupport,_that.reflection,_that.composer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reflectionId,  String status,  String? rejectReason,  String? review,  bool showSupport,  Reflection? reflection,  ReflectionComposer composer)  $default,) {final _that = this;
switch (_that) {
case _SendOutcome():
return $default(_that.reflectionId,_that.status,_that.rejectReason,_that.review,_that.showSupport,_that.reflection,_that.composer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reflectionId,  String status,  String? rejectReason,  String? review,  bool showSupport,  Reflection? reflection,  ReflectionComposer composer)?  $default,) {final _that = this;
switch (_that) {
case _SendOutcome() when $default != null:
return $default(_that.reflectionId,_that.status,_that.rejectReason,_that.review,_that.showSupport,_that.reflection,_that.composer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SendOutcome extends SendOutcome {
  const _SendOutcome({required this.reflectionId, required this.status, this.rejectReason, this.review, this.showSupport = false, this.reflection, this.composer = const ReflectionComposer()}): super._();
  factory _SendOutcome.fromJson(Map<String, dynamic> json) => _$SendOutcomeFromJson(json);

@override final  String reflectionId;
@override final  String status;
@override final  String? rejectReason;
@override final  String? review;
/// `crisis_diverted` only: open the F9 support sheet at once.
@override@JsonKey() final  bool showSupport;
/// The stored item (null for rejected-by-rules and crisis_diverted).
@override final  Reflection? reflection;
@override@JsonKey() final  ReflectionComposer composer;

/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendOutcomeCopyWith<_SendOutcome> get copyWith => __$SendOutcomeCopyWithImpl<_SendOutcome>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendOutcomeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendOutcome&&(identical(other.reflectionId, reflectionId) || other.reflectionId == reflectionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.rejectReason, rejectReason) || other.rejectReason == rejectReason)&&(identical(other.review, review) || other.review == review)&&(identical(other.showSupport, showSupport) || other.showSupport == showSupport)&&(identical(other.reflection, reflection) || other.reflection == reflection)&&(identical(other.composer, composer) || other.composer == composer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reflectionId,status,rejectReason,review,showSupport,reflection,composer);
}

@override
String toString() {
    return 'SendOutcome(reflectionId: $reflectionId, status: $status, rejectReason: $rejectReason, review: $review, showSupport: $showSupport, reflection: $reflection, composer: $composer)';
}


}

/// @nodoc
abstract mixin class _$SendOutcomeCopyWith<$Res> implements $SendOutcomeCopyWith<$Res> {
  factory _$SendOutcomeCopyWith(_SendOutcome value, $Res Function(_SendOutcome) _then) = __$SendOutcomeCopyWithImpl;
@override @useResult
$Res call({
 String reflectionId, String status, String? rejectReason, String? review, bool showSupport, Reflection? reflection, ReflectionComposer composer
});


@override $ReflectionCopyWith<$Res>? get reflection;@override $ReflectionComposerCopyWith<$Res> get composer;

}
/// @nodoc
class __$SendOutcomeCopyWithImpl<$Res>
    implements _$SendOutcomeCopyWith<$Res> {
  __$SendOutcomeCopyWithImpl(this._self, this._then);

  final _SendOutcome _self;
  final $Res Function(_SendOutcome) _then;

/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reflectionId = null,Object? status = null,Object? rejectReason = freezed,Object? review = freezed,Object? showSupport = null,Object? reflection = freezed,Object? composer = null,}) {
  return _then(_SendOutcome(
reflectionId: null == reflectionId ? _self.reflectionId : reflectionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,review: freezed == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as String?,showSupport: null == showSupport ? _self.showSupport : showSupport // ignore: cast_nullable_to_non_nullable
as bool,reflection: freezed == reflection ? _self.reflection : reflection // ignore: cast_nullable_to_non_nullable
as Reflection?,composer: null == composer ? _self.composer : composer // ignore: cast_nullable_to_non_nullable
as ReflectionComposer,
  ));
}

/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionCopyWith<$Res>? get reflection {
    if (_self.reflection == null) {
    return null;
  }

  return $ReflectionCopyWith<$Res>(_self.reflection!, (value) {
    return _then(_self.copyWith(reflection: value));
  });
}/// Create a copy of SendOutcome
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReflectionComposerCopyWith<$Res> get composer {
  
  return $ReflectionComposerCopyWith<$Res>(_self.composer, (value) {
    return _then(_self.copyWith(composer: value));
  });
}
}

// dart format on
