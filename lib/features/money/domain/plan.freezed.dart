// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Plan {

 String get id; String get workspaceId; String get name; int get baseFeeCents; int? get includedHalfDays; int get overageFeeCents; bool get active;
/// Create a copy of Plan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlanCopyWith<Plan> get copyWith => _$PlanCopyWithImpl<Plan>(this as Plan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Plan&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.baseFeeCents, baseFeeCents) || other.baseFeeCents == baseFeeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.overageFeeCents, overageFeeCents) || other.overageFeeCents == overageFeeCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,baseFeeCents,includedHalfDays,overageFeeCents,active);

@override
String toString() {
  return 'Plan(id: $id, workspaceId: $workspaceId, name: $name, baseFeeCents: $baseFeeCents, includedHalfDays: $includedHalfDays, overageFeeCents: $overageFeeCents, active: $active)';
}


}

/// @nodoc
abstract mixin class $PlanCopyWith<$Res>  {
  factory $PlanCopyWith(Plan value, $Res Function(Plan) _then) = _$PlanCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String name, int baseFeeCents, int? includedHalfDays, int overageFeeCents, bool active
});




}
/// @nodoc
class _$PlanCopyWithImpl<$Res>
    implements $PlanCopyWith<$Res> {
  _$PlanCopyWithImpl(this._self, this._then);

  final Plan _self;
  final $Res Function(Plan) _then;

/// Create a copy of Plan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? baseFeeCents = null,Object? includedHalfDays = freezed,Object? overageFeeCents = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,baseFeeCents: null == baseFeeCents ? _self.baseFeeCents : baseFeeCents // ignore: cast_nullable_to_non_nullable
as int,includedHalfDays: freezed == includedHalfDays ? _self.includedHalfDays : includedHalfDays // ignore: cast_nullable_to_non_nullable
as int?,overageFeeCents: null == overageFeeCents ? _self.overageFeeCents : overageFeeCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Plan].
extension PlanPatterns on Plan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Plan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Plan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Plan value)  $default,){
final _that = this;
switch (_that) {
case _Plan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Plan value)?  $default,){
final _that = this;
switch (_that) {
case _Plan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int baseFeeCents,  int? includedHalfDays,  int overageFeeCents,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Plan() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.baseFeeCents,_that.includedHalfDays,_that.overageFeeCents,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int baseFeeCents,  int? includedHalfDays,  int overageFeeCents,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Plan():
return $default(_that.id,_that.workspaceId,_that.name,_that.baseFeeCents,_that.includedHalfDays,_that.overageFeeCents,_that.active);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String name,  int baseFeeCents,  int? includedHalfDays,  int overageFeeCents,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Plan() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.baseFeeCents,_that.includedHalfDays,_that.overageFeeCents,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Plan implements Plan {
  const _Plan({required this.id, required this.workspaceId, required this.name, required this.baseFeeCents, this.includedHalfDays, required this.overageFeeCents, required this.active});
  

@override final  String id;
@override final  String workspaceId;
@override final  String name;
@override final  int baseFeeCents;
@override final  int? includedHalfDays;
@override final  int overageFeeCents;
@override final  bool active;

/// Create a copy of Plan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlanCopyWith<_Plan> get copyWith => __$PlanCopyWithImpl<_Plan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Plan&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.baseFeeCents, baseFeeCents) || other.baseFeeCents == baseFeeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.overageFeeCents, overageFeeCents) || other.overageFeeCents == overageFeeCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,baseFeeCents,includedHalfDays,overageFeeCents,active);

@override
String toString() {
  return 'Plan(id: $id, workspaceId: $workspaceId, name: $name, baseFeeCents: $baseFeeCents, includedHalfDays: $includedHalfDays, overageFeeCents: $overageFeeCents, active: $active)';
}


}

/// @nodoc
abstract mixin class _$PlanCopyWith<$Res> implements $PlanCopyWith<$Res> {
  factory _$PlanCopyWith(_Plan value, $Res Function(_Plan) _then) = __$PlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String name, int baseFeeCents, int? includedHalfDays, int overageFeeCents, bool active
});




}
/// @nodoc
class __$PlanCopyWithImpl<$Res>
    implements _$PlanCopyWith<$Res> {
  __$PlanCopyWithImpl(this._self, this._then);

  final _Plan _self;
  final $Res Function(_Plan) _then;

/// Create a copy of Plan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? baseFeeCents = null,Object? includedHalfDays = freezed,Object? overageFeeCents = null,Object? active = null,}) {
  return _then(_Plan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,baseFeeCents: null == baseFeeCents ? _self.baseFeeCents : baseFeeCents // ignore: cast_nullable_to_non_nullable
as int,includedHalfDays: freezed == includedHalfDays ? _self.includedHalfDays : includedHalfDays // ignore: cast_nullable_to_non_nullable
as int?,overageFeeCents: null == overageFeeCents ? _self.overageFeeCents : overageFeeCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
