// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member_badge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemberBadge {

 String get id; String get workspaceId; String get memberId; String get label; DateTime get createdAt; DateTime? get revokedAt; BadgeKind get kind;
/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberBadgeCopyWith<MemberBadge> get copyWith => _$MemberBadgeCopyWithImpl<MemberBadge>(this as MemberBadge, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemberBadge&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.label, label) || other.label == label)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,memberId,label,createdAt,revokedAt,kind);

@override
String toString() {
  return 'MemberBadge(id: $id, workspaceId: $workspaceId, memberId: $memberId, label: $label, createdAt: $createdAt, revokedAt: $revokedAt, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $MemberBadgeCopyWith<$Res>  {
  factory $MemberBadgeCopyWith(MemberBadge value, $Res Function(MemberBadge) _then) = _$MemberBadgeCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String memberId, String label, DateTime createdAt, DateTime? revokedAt, BadgeKind kind
});




}
/// @nodoc
class _$MemberBadgeCopyWithImpl<$Res>
    implements $MemberBadgeCopyWith<$Res> {
  _$MemberBadgeCopyWithImpl(this._self, this._then);

  final MemberBadge _self;
  final $Res Function(MemberBadge) _then;

/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? label = null,Object? createdAt = null,Object? revokedAt = freezed,Object? kind = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BadgeKind,
  ));
}

}


/// Adds pattern-matching-related methods to [MemberBadge].
extension MemberBadgePatterns on MemberBadge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemberBadge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemberBadge value)  $default,){
final _that = this;
switch (_that) {
case _MemberBadge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemberBadge value)?  $default,){
final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind)  $default,) {final _that = this;
switch (_that) {
case _MemberBadge():
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind)?  $default,) {final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class _MemberBadge extends MemberBadge {
  const _MemberBadge({required this.id, required this.workspaceId, required this.memberId, required this.label, required this.createdAt, this.revokedAt, this.kind = BadgeKind.qr}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String memberId;
@override final  String label;
@override final  DateTime createdAt;
@override final  DateTime? revokedAt;
@override@JsonKey() final  BadgeKind kind;

/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberBadgeCopyWith<_MemberBadge> get copyWith => __$MemberBadgeCopyWithImpl<_MemberBadge>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemberBadge&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.label, label) || other.label == label)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,memberId,label,createdAt,revokedAt,kind);

@override
String toString() {
  return 'MemberBadge(id: $id, workspaceId: $workspaceId, memberId: $memberId, label: $label, createdAt: $createdAt, revokedAt: $revokedAt, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$MemberBadgeCopyWith<$Res> implements $MemberBadgeCopyWith<$Res> {
  factory _$MemberBadgeCopyWith(_MemberBadge value, $Res Function(_MemberBadge) _then) = __$MemberBadgeCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String memberId, String label, DateTime createdAt, DateTime? revokedAt, BadgeKind kind
});




}
/// @nodoc
class __$MemberBadgeCopyWithImpl<$Res>
    implements _$MemberBadgeCopyWith<$Res> {
  __$MemberBadgeCopyWithImpl(this._self, this._then);

  final _MemberBadge _self;
  final $Res Function(_MemberBadge) _then;

/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? label = null,Object? createdAt = null,Object? revokedAt = freezed,Object? kind = null,}) {
  return _then(_MemberBadge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BadgeKind,
  ));
}


}

// dart format on
