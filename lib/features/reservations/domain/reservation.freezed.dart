// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reservation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Reservation {

 String get id; String get workspaceId; String? get seatId; String? get officeId; String get memberId; DateTime get startsAt; DateTime get endsAt; ReservationStatus get status; String? get seriesId; DateTime? get checkedInAt; DateTime? get checkedOutAt;
/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservationCopyWith<Reservation> get copyWith => _$ReservationCopyWithImpl<Reservation>(this as Reservation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reservation&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.officeId, officeId) || other.officeId == officeId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.checkedInAt, checkedInAt) || other.checkedInAt == checkedInAt)&&(identical(other.checkedOutAt, checkedOutAt) || other.checkedOutAt == checkedOutAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,seatId,officeId,memberId,startsAt,endsAt,status,seriesId,checkedInAt,checkedOutAt);

@override
String toString() {
  return 'Reservation(id: $id, workspaceId: $workspaceId, seatId: $seatId, officeId: $officeId, memberId: $memberId, startsAt: $startsAt, endsAt: $endsAt, status: $status, seriesId: $seriesId, checkedInAt: $checkedInAt, checkedOutAt: $checkedOutAt)';
}


}

/// @nodoc
abstract mixin class $ReservationCopyWith<$Res>  {
  factory $ReservationCopyWith(Reservation value, $Res Function(Reservation) _then) = _$ReservationCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String? seatId, String? officeId, String memberId, DateTime startsAt, DateTime endsAt, ReservationStatus status, String? seriesId, DateTime? checkedInAt, DateTime? checkedOutAt
});




}
/// @nodoc
class _$ReservationCopyWithImpl<$Res>
    implements $ReservationCopyWith<$Res> {
  _$ReservationCopyWithImpl(this._self, this._then);

  final Reservation _self;
  final $Res Function(Reservation) _then;

/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? seatId = freezed,Object? officeId = freezed,Object? memberId = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? seriesId = freezed,Object? checkedInAt = freezed,Object? checkedOutAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,seatId: freezed == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String?,officeId: freezed == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String?,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReservationStatus,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,checkedInAt: freezed == checkedInAt ? _self.checkedInAt : checkedInAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedOutAt: freezed == checkedOutAt ? _self.checkedOutAt : checkedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Reservation].
extension ReservationPatterns on Reservation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Reservation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Reservation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Reservation value)  $default,){
final _that = this;
switch (_that) {
case _Reservation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Reservation value)?  $default,){
final _that = this;
switch (_that) {
case _Reservation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String? seatId,  String? officeId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  DateTime? checkedInAt,  DateTime? checkedOutAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reservation() when $default != null:
return $default(_that.id,_that.workspaceId,_that.seatId,_that.officeId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.checkedInAt,_that.checkedOutAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String? seatId,  String? officeId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  DateTime? checkedInAt,  DateTime? checkedOutAt)  $default,) {final _that = this;
switch (_that) {
case _Reservation():
return $default(_that.id,_that.workspaceId,_that.seatId,_that.officeId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.checkedInAt,_that.checkedOutAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String? seatId,  String? officeId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  DateTime? checkedInAt,  DateTime? checkedOutAt)?  $default,) {final _that = this;
switch (_that) {
case _Reservation() when $default != null:
return $default(_that.id,_that.workspaceId,_that.seatId,_that.officeId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.checkedInAt,_that.checkedOutAt);case _:
  return null;

}
}

}

/// @nodoc


class _Reservation extends Reservation {
  const _Reservation({required this.id, required this.workspaceId, this.seatId, this.officeId, required this.memberId, required this.startsAt, required this.endsAt, required this.status, this.seriesId, this.checkedInAt, this.checkedOutAt}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String? seatId;
@override final  String? officeId;
@override final  String memberId;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  ReservationStatus status;
@override final  String? seriesId;
@override final  DateTime? checkedInAt;
@override final  DateTime? checkedOutAt;

/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservationCopyWith<_Reservation> get copyWith => __$ReservationCopyWithImpl<_Reservation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reservation&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.officeId, officeId) || other.officeId == officeId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.checkedInAt, checkedInAt) || other.checkedInAt == checkedInAt)&&(identical(other.checkedOutAt, checkedOutAt) || other.checkedOutAt == checkedOutAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,seatId,officeId,memberId,startsAt,endsAt,status,seriesId,checkedInAt,checkedOutAt);

@override
String toString() {
  return 'Reservation(id: $id, workspaceId: $workspaceId, seatId: $seatId, officeId: $officeId, memberId: $memberId, startsAt: $startsAt, endsAt: $endsAt, status: $status, seriesId: $seriesId, checkedInAt: $checkedInAt, checkedOutAt: $checkedOutAt)';
}


}

/// @nodoc
abstract mixin class _$ReservationCopyWith<$Res> implements $ReservationCopyWith<$Res> {
  factory _$ReservationCopyWith(_Reservation value, $Res Function(_Reservation) _then) = __$ReservationCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String? seatId, String? officeId, String memberId, DateTime startsAt, DateTime endsAt, ReservationStatus status, String? seriesId, DateTime? checkedInAt, DateTime? checkedOutAt
});




}
/// @nodoc
class __$ReservationCopyWithImpl<$Res>
    implements _$ReservationCopyWith<$Res> {
  __$ReservationCopyWithImpl(this._self, this._then);

  final _Reservation _self;
  final $Res Function(_Reservation) _then;

/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? seatId = freezed,Object? officeId = freezed,Object? memberId = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? seriesId = freezed,Object? checkedInAt = freezed,Object? checkedOutAt = freezed,}) {
  return _then(_Reservation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,seatId: freezed == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String?,officeId: freezed == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String?,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReservationStatus,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,checkedInAt: freezed == checkedInAt ? _self.checkedInAt : checkedInAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedOutAt: freezed == checkedOutAt ? _self.checkedOutAt : checkedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
