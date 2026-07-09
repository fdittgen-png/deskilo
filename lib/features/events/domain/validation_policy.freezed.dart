// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'validation_policy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ValidationPolicy {

/// Null until persisted (defaults are never stored).
 String? get id; String get workspaceId;/// events.type db value; null = workspace default for types without
/// their own row.
 String? get eventType; int get requiredCount; bool get adminsMayValidate;/// Empty = every admin may validate (owners always may).
 List<String> get eligibleAdminIds; bool get ownerRequired;
/// Create a copy of ValidationPolicy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidationPolicyCopyWith<ValidationPolicy> get copyWith => _$ValidationPolicyCopyWithImpl<ValidationPolicy>(this as ValidationPolicy, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidationPolicy&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.requiredCount, requiredCount) || other.requiredCount == requiredCount)&&(identical(other.adminsMayValidate, adminsMayValidate) || other.adminsMayValidate == adminsMayValidate)&&const DeepCollectionEquality().equals(other.eligibleAdminIds, eligibleAdminIds)&&(identical(other.ownerRequired, ownerRequired) || other.ownerRequired == ownerRequired));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,eventType,requiredCount,adminsMayValidate,const DeepCollectionEquality().hash(eligibleAdminIds),ownerRequired);

@override
String toString() {
  return 'ValidationPolicy(id: $id, workspaceId: $workspaceId, eventType: $eventType, requiredCount: $requiredCount, adminsMayValidate: $adminsMayValidate, eligibleAdminIds: $eligibleAdminIds, ownerRequired: $ownerRequired)';
}


}

/// @nodoc
abstract mixin class $ValidationPolicyCopyWith<$Res>  {
  factory $ValidationPolicyCopyWith(ValidationPolicy value, $Res Function(ValidationPolicy) _then) = _$ValidationPolicyCopyWithImpl;
@useResult
$Res call({
 String? id, String workspaceId, String? eventType, int requiredCount, bool adminsMayValidate, List<String> eligibleAdminIds, bool ownerRequired
});




}
/// @nodoc
class _$ValidationPolicyCopyWithImpl<$Res>
    implements $ValidationPolicyCopyWith<$Res> {
  _$ValidationPolicyCopyWithImpl(this._self, this._then);

  final ValidationPolicy _self;
  final $Res Function(ValidationPolicy) _then;

/// Create a copy of ValidationPolicy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? workspaceId = null,Object? eventType = freezed,Object? requiredCount = null,Object? adminsMayValidate = null,Object? eligibleAdminIds = null,Object? ownerRequired = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,requiredCount: null == requiredCount ? _self.requiredCount : requiredCount // ignore: cast_nullable_to_non_nullable
as int,adminsMayValidate: null == adminsMayValidate ? _self.adminsMayValidate : adminsMayValidate // ignore: cast_nullable_to_non_nullable
as bool,eligibleAdminIds: null == eligibleAdminIds ? _self.eligibleAdminIds : eligibleAdminIds // ignore: cast_nullable_to_non_nullable
as List<String>,ownerRequired: null == ownerRequired ? _self.ownerRequired : ownerRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ValidationPolicy].
extension ValidationPolicyPatterns on ValidationPolicy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidationPolicy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidationPolicy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidationPolicy value)  $default,){
final _that = this;
switch (_that) {
case _ValidationPolicy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidationPolicy value)?  $default,){
final _that = this;
switch (_that) {
case _ValidationPolicy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String workspaceId,  String? eventType,  int requiredCount,  bool adminsMayValidate,  List<String> eligibleAdminIds,  bool ownerRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidationPolicy() when $default != null:
return $default(_that.id,_that.workspaceId,_that.eventType,_that.requiredCount,_that.adminsMayValidate,_that.eligibleAdminIds,_that.ownerRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String workspaceId,  String? eventType,  int requiredCount,  bool adminsMayValidate,  List<String> eligibleAdminIds,  bool ownerRequired)  $default,) {final _that = this;
switch (_that) {
case _ValidationPolicy():
return $default(_that.id,_that.workspaceId,_that.eventType,_that.requiredCount,_that.adminsMayValidate,_that.eligibleAdminIds,_that.ownerRequired);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String workspaceId,  String? eventType,  int requiredCount,  bool adminsMayValidate,  List<String> eligibleAdminIds,  bool ownerRequired)?  $default,) {final _that = this;
switch (_that) {
case _ValidationPolicy() when $default != null:
return $default(_that.id,_that.workspaceId,_that.eventType,_that.requiredCount,_that.adminsMayValidate,_that.eligibleAdminIds,_that.ownerRequired);case _:
  return null;

}
}

}

/// @nodoc


class _ValidationPolicy extends ValidationPolicy {
  const _ValidationPolicy({this.id, required this.workspaceId, this.eventType, required this.requiredCount, required this.adminsMayValidate, required final  List<String> eligibleAdminIds, required this.ownerRequired}): _eligibleAdminIds = eligibleAdminIds,super._();
  

/// Null until persisted (defaults are never stored).
@override final  String? id;
@override final  String workspaceId;
/// events.type db value; null = workspace default for types without
/// their own row.
@override final  String? eventType;
@override final  int requiredCount;
@override final  bool adminsMayValidate;
/// Empty = every admin may validate (owners always may).
 final  List<String> _eligibleAdminIds;
/// Empty = every admin may validate (owners always may).
@override List<String> get eligibleAdminIds {
  if (_eligibleAdminIds is EqualUnmodifiableListView) return _eligibleAdminIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_eligibleAdminIds);
}

@override final  bool ownerRequired;

/// Create a copy of ValidationPolicy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidationPolicyCopyWith<_ValidationPolicy> get copyWith => __$ValidationPolicyCopyWithImpl<_ValidationPolicy>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidationPolicy&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.requiredCount, requiredCount) || other.requiredCount == requiredCount)&&(identical(other.adminsMayValidate, adminsMayValidate) || other.adminsMayValidate == adminsMayValidate)&&const DeepCollectionEquality().equals(other._eligibleAdminIds, _eligibleAdminIds)&&(identical(other.ownerRequired, ownerRequired) || other.ownerRequired == ownerRequired));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,eventType,requiredCount,adminsMayValidate,const DeepCollectionEquality().hash(_eligibleAdminIds),ownerRequired);

@override
String toString() {
  return 'ValidationPolicy(id: $id, workspaceId: $workspaceId, eventType: $eventType, requiredCount: $requiredCount, adminsMayValidate: $adminsMayValidate, eligibleAdminIds: $eligibleAdminIds, ownerRequired: $ownerRequired)';
}


}

/// @nodoc
abstract mixin class _$ValidationPolicyCopyWith<$Res> implements $ValidationPolicyCopyWith<$Res> {
  factory _$ValidationPolicyCopyWith(_ValidationPolicy value, $Res Function(_ValidationPolicy) _then) = __$ValidationPolicyCopyWithImpl;
@override @useResult
$Res call({
 String? id, String workspaceId, String? eventType, int requiredCount, bool adminsMayValidate, List<String> eligibleAdminIds, bool ownerRequired
});




}
/// @nodoc
class __$ValidationPolicyCopyWithImpl<$Res>
    implements _$ValidationPolicyCopyWith<$Res> {
  __$ValidationPolicyCopyWithImpl(this._self, this._then);

  final _ValidationPolicy _self;
  final $Res Function(_ValidationPolicy) _then;

/// Create a copy of ValidationPolicy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? workspaceId = null,Object? eventType = freezed,Object? requiredCount = null,Object? adminsMayValidate = null,Object? eligibleAdminIds = null,Object? ownerRequired = null,}) {
  return _then(_ValidationPolicy(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,requiredCount: null == requiredCount ? _self.requiredCount : requiredCount // ignore: cast_nullable_to_non_nullable
as int,adminsMayValidate: null == adminsMayValidate ? _self.adminsMayValidate : adminsMayValidate // ignore: cast_nullable_to_non_nullable
as bool,eligibleAdminIds: null == eligibleAdminIds ? _self._eligibleAdminIds : eligibleAdminIds // ignore: cast_nullable_to_non_nullable
as List<String>,ownerRequired: null == ownerRequired ? _self.ownerRequired : ownerRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
