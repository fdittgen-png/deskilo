// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'closure_day.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClosureDay {

 String get id; String get workspaceId; DateTime get day; String get reason;
/// Create a copy of ClosureDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClosureDayCopyWith<ClosureDay> get copyWith => _$ClosureDayCopyWithImpl<ClosureDay>(this as ClosureDay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClosureDay&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.day, day) || other.day == day)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,day,reason);

@override
String toString() {
  return 'ClosureDay(id: $id, workspaceId: $workspaceId, day: $day, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ClosureDayCopyWith<$Res>  {
  factory $ClosureDayCopyWith(ClosureDay value, $Res Function(ClosureDay) _then) = _$ClosureDayCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, DateTime day, String reason
});




}
/// @nodoc
class _$ClosureDayCopyWithImpl<$Res>
    implements $ClosureDayCopyWith<$Res> {
  _$ClosureDayCopyWithImpl(this._self, this._then);

  final ClosureDay _self;
  final $Res Function(ClosureDay) _then;

/// Create a copy of ClosureDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? day = null,Object? reason = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ClosureDay].
extension ClosureDayPatterns on ClosureDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClosureDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClosureDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClosureDay value)  $default,){
final _that = this;
switch (_that) {
case _ClosureDay():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClosureDay value)?  $default,){
final _that = this;
switch (_that) {
case _ClosureDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  DateTime day,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClosureDay() when $default != null:
return $default(_that.id,_that.workspaceId,_that.day,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  DateTime day,  String reason)  $default,) {final _that = this;
switch (_that) {
case _ClosureDay():
return $default(_that.id,_that.workspaceId,_that.day,_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  DateTime day,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _ClosureDay() when $default != null:
return $default(_that.id,_that.workspaceId,_that.day,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _ClosureDay implements ClosureDay {
  const _ClosureDay({required this.id, required this.workspaceId, required this.day, required this.reason});
  

@override final  String id;
@override final  String workspaceId;
@override final  DateTime day;
@override final  String reason;

/// Create a copy of ClosureDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClosureDayCopyWith<_ClosureDay> get copyWith => __$ClosureDayCopyWithImpl<_ClosureDay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClosureDay&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.day, day) || other.day == day)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,day,reason);

@override
String toString() {
  return 'ClosureDay(id: $id, workspaceId: $workspaceId, day: $day, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$ClosureDayCopyWith<$Res> implements $ClosureDayCopyWith<$Res> {
  factory _$ClosureDayCopyWith(_ClosureDay value, $Res Function(_ClosureDay) _then) = __$ClosureDayCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, DateTime day, String reason
});




}
/// @nodoc
class __$ClosureDayCopyWithImpl<$Res>
    implements _$ClosureDayCopyWith<$Res> {
  __$ClosureDayCopyWithImpl(this._self, this._then);

  final _ClosureDay _self;
  final $Res Function(_ClosureDay) _then;

/// Create a copy of ClosureDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? day = null,Object? reason = null,}) {
  return _then(_ClosureDay(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
