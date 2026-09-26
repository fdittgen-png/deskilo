// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member_badge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemberBadge {

 String get id; String get workspaceId; String get memberId; String get label; DateTime get createdAt; DateTime? get revokedAt; BadgeKind get kind;/// #662 — this badge may SIGN ITS OWNER IN, not merely check them
/// in. Off until the member says otherwise: the card that opens the
/// door should not become the card that opens the account by
/// default.
 bool get authEnabled;/// #992 — the server's stamp on this row.
 SystemColumns get system;
/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberBadgeCopyWith<MemberBadge> get copyWith => _$MemberBadgeCopyWithImpl<MemberBadge>(this as MemberBadge, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MemberBadge;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemberBadge&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workspaceId, _this.workspaceId) || other.workspaceId == _this.workspaceId)&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.revokedAt, _this.revokedAt) || other.revokedAt == _this.revokedAt)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.authEnabled, _this.authEnabled) || other.authEnabled == _this.authEnabled)&&(identical(other.system, _this.system) || other.system == _this.system));
}


@override
int get hashCode {
  final _this = this as MemberBadge;
  return Object.hash(runtimeType,_this.id,_this.workspaceId,_this.memberId,_this.label,_this.createdAt,_this.revokedAt,_this.kind,_this.authEnabled,_this.system);
}

@override
String toString() {
  final _this = this as MemberBadge;
  return 'MemberBadge(id: ${_this.id}, workspaceId: ${_this.workspaceId}, memberId: ${_this.memberId}, label: ${_this.label}, createdAt: ${_this.createdAt}, revokedAt: ${_this.revokedAt}, kind: ${_this.kind}, authEnabled: ${_this.authEnabled}, system: ${_this.system})';
}


}

/// @nodoc
abstract mixin class $MemberBadgeCopyWith<$Res>  {
  factory $MemberBadgeCopyWith(MemberBadge value, $Res Function(MemberBadge) _then) = _$MemberBadgeCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String memberId, String label, DateTime createdAt, DateTime? revokedAt, BadgeKind kind, bool authEnabled, SystemColumns system
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? label = null,Object? createdAt = null,Object? revokedAt = freezed,Object? kind = null,Object? authEnabled = null,Object? system = null,}) {
  return _then(MemberBadge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BadgeKind,authEnabled: null == authEnabled ? _self.authEnabled : authEnabled // ignore: cast_nullable_to_non_nullable
as bool,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as SystemColumns,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind,  bool authEnabled,  SystemColumns system)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind,_that.authEnabled,_that.system);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind,  bool authEnabled,  SystemColumns system)  $default,) {final _that = this;
switch (_that) {
case _MemberBadge():
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind,_that.authEnabled,_that.system);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String memberId,  String label,  DateTime createdAt,  DateTime? revokedAt,  BadgeKind kind,  bool authEnabled,  SystemColumns system)?  $default,) {final _that = this;
switch (_that) {
case _MemberBadge() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.label,_that.createdAt,_that.revokedAt,_that.kind,_that.authEnabled,_that.system);case _:
  return null;

}
}

}

/// @nodoc


class _MemberBadge extends MemberBadge {
  const _MemberBadge({required this.id, required this.workspaceId, required this.memberId, required this.label, required this.createdAt, this.revokedAt, this.kind = BadgeKind.qr, this.authEnabled = false, this.system = SystemColumns.none}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String memberId;
@override final  String label;
@override final  DateTime createdAt;
@override final  DateTime? revokedAt;
@override@JsonKey() final  BadgeKind kind;
/// #662 — this badge may SIGN ITS OWNER IN, not merely check them
/// in. Off until the member says otherwise: the card that opens the
/// door should not become the card that opens the account by
/// default.
@override@JsonKey() final  bool authEnabled;
/// #992 — the server's stamp on this row.
@override@JsonKey() final  SystemColumns system;

/// Create a copy of MemberBadge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberBadgeCopyWith<_MemberBadge> get copyWith => __$MemberBadgeCopyWithImpl<_MemberBadge>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemberBadge&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.label, label) || other.label == label)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.authEnabled, authEnabled) || other.authEnabled == authEnabled)&&(identical(other.system, system) || other.system == system));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,workspaceId,memberId,label,createdAt,revokedAt,kind,authEnabled,system);
}

@override
String toString() {
    return 'MemberBadge(id: $id, workspaceId: $workspaceId, memberId: $memberId, label: $label, createdAt: $createdAt, revokedAt: $revokedAt, kind: $kind, authEnabled: $authEnabled, system: $system)';
}


}

/// @nodoc
abstract mixin class _$MemberBadgeCopyWith<$Res> implements $MemberBadgeCopyWith<$Res> {
  factory _$MemberBadgeCopyWith(_MemberBadge value, $Res Function(_MemberBadge) _then) = __$MemberBadgeCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String memberId, String label, DateTime createdAt, DateTime? revokedAt, BadgeKind kind, bool authEnabled, SystemColumns system
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? label = null,Object? createdAt = null,Object? revokedAt = freezed,Object? kind = null,Object? authEnabled = null,Object? system = null,}) {
  return _then(_MemberBadge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BadgeKind,authEnabled: null == authEnabled ? _self.authEnabled : authEnabled // ignore: cast_nullable_to_non_nullable
as bool,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as SystemColumns,
  ));
}


}

// dart format on
