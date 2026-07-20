// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Member {

 String get id; String get workspaceId; String get userId; bool get isAdmin; bool get isOwner; MemberStatus get status;/// Subscription percentage 1–100 (ADR 0008): the membership level the
/// fee band and the half-day entitlement derive from.
 int get subscriptionPct;/// What happens once the member has used their whole monthly
/// entitlement (migration 0041): blocked (default), pay-as-you-go, or
/// buy-a-package.
 OveragePolicy get overagePolicy;/// Wall-mounted tablet account (migration 0043): the app locks to the
/// plan view; real members act through it by presenting a badge.
 bool get isKiosk;
/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberCopyWith<Member> get copyWith => _$MemberCopyWithImpl<Member>(this as Member, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Member&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.status, status) || other.status == status)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.isKiosk, isKiosk) || other.isKiosk == isKiosk));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,userId,isAdmin,isOwner,status,subscriptionPct,overagePolicy,isKiosk);

@override
String toString() {
  return 'Member(id: $id, workspaceId: $workspaceId, userId: $userId, isAdmin: $isAdmin, isOwner: $isOwner, status: $status, subscriptionPct: $subscriptionPct, overagePolicy: $overagePolicy, isKiosk: $isKiosk)';
}


}

/// @nodoc
abstract mixin class $MemberCopyWith<$Res>  {
  factory $MemberCopyWith(Member value, $Res Function(Member) _then) = _$MemberCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String userId, bool isAdmin, bool isOwner, MemberStatus status, int subscriptionPct, OveragePolicy overagePolicy, bool isKiosk
});




}
/// @nodoc
class _$MemberCopyWithImpl<$Res>
    implements $MemberCopyWith<$Res> {
  _$MemberCopyWithImpl(this._self, this._then);

  final Member _self;
  final $Res Function(Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? userId = null,Object? isAdmin = null,Object? isOwner = null,Object? status = null,Object? subscriptionPct = null,Object? overagePolicy = null,Object? isKiosk = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MemberStatus,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,isKiosk: null == isKiosk ? _self.isKiosk : isKiosk // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Member].
extension MemberPatterns on Member {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Member value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Member value)  $default,){
final _that = this;
switch (_that) {
case _Member():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Member value)?  $default,){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk)  $default,) {final _that = this;
switch (_that) {
case _Member():
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk)?  $default,) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk);case _:
  return null;

}
}

}

/// @nodoc


class _Member extends Member {
  const _Member({required this.id, required this.workspaceId, required this.userId, required this.isAdmin, required this.isOwner, required this.status, this.subscriptionPct = 100, this.overagePolicy = OveragePolicy.blocked, this.isKiosk = false}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String userId;
@override final  bool isAdmin;
@override final  bool isOwner;
@override final  MemberStatus status;
/// Subscription percentage 1–100 (ADR 0008): the membership level the
/// fee band and the half-day entitlement derive from.
@override@JsonKey() final  int subscriptionPct;
/// What happens once the member has used their whole monthly
/// entitlement (migration 0041): blocked (default), pay-as-you-go, or
/// buy-a-package.
@override@JsonKey() final  OveragePolicy overagePolicy;
/// Wall-mounted tablet account (migration 0043): the app locks to the
/// plan view; real members act through it by presenting a badge.
@override@JsonKey() final  bool isKiosk;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberCopyWith<_Member> get copyWith => __$MemberCopyWithImpl<_Member>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Member&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.status, status) || other.status == status)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.isKiosk, isKiosk) || other.isKiosk == isKiosk));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,userId,isAdmin,isOwner,status,subscriptionPct,overagePolicy,isKiosk);

@override
String toString() {
  return 'Member(id: $id, workspaceId: $workspaceId, userId: $userId, isAdmin: $isAdmin, isOwner: $isOwner, status: $status, subscriptionPct: $subscriptionPct, overagePolicy: $overagePolicy, isKiosk: $isKiosk)';
}


}

/// @nodoc
abstract mixin class _$MemberCopyWith<$Res> implements $MemberCopyWith<$Res> {
  factory _$MemberCopyWith(_Member value, $Res Function(_Member) _then) = __$MemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String userId, bool isAdmin, bool isOwner, MemberStatus status, int subscriptionPct, OveragePolicy overagePolicy, bool isKiosk
});




}
/// @nodoc
class __$MemberCopyWithImpl<$Res>
    implements _$MemberCopyWith<$Res> {
  __$MemberCopyWithImpl(this._self, this._then);

  final _Member _self;
  final $Res Function(_Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? userId = null,Object? isAdmin = null,Object? isOwner = null,Object? status = null,Object? subscriptionPct = null,Object? overagePolicy = null,Object? isKiosk = null,}) {
  return _then(_Member(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MemberStatus,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,isKiosk: null == isKiosk ? _self.isKiosk : isKiosk // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
