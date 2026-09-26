// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reservation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Reservation {

 String get id; String get workspaceId; String? get seatId; String? get deskId; String? get officeId;/// Set when the booking covers a WHOLE level (0050); exactly one of
/// seat/office/level is non-null.
 String? get levelId; String get memberId; DateTime get startsAt; DateTime get endsAt; ReservationStatus get status; String? get seriesId;/// Repetition modality of the series ('daily' / 'weekdays' /
/// 'weekly', 0034); null on single bookings and pre-0034 series.
 String? get seriesPattern; DateTime? get checkedInAt; DateTime? get checkedOutAt;/// Audit substitution snapshot (#587): the human-readable chain
/// (workspace · level · room · table · chair, up to the deleted
/// target's depth) written when an OWNER deleted the plan object
/// this reservation pointed at. Null while the target lives.
 String? get spaceLabel;/// #992 — the server's stamp on this row.
 SystemColumns get system;
/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservationCopyWith<Reservation> get copyWith => _$ReservationCopyWithImpl<Reservation>(this as Reservation, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Reservation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reservation&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workspaceId, _this.workspaceId) || other.workspaceId == _this.workspaceId)&&(identical(other.seatId, _this.seatId) || other.seatId == _this.seatId)&&(identical(other.deskId, _this.deskId) || other.deskId == _this.deskId)&&(identical(other.officeId, _this.officeId) || other.officeId == _this.officeId)&&(identical(other.levelId, _this.levelId) || other.levelId == _this.levelId)&&(identical(other.memberId, _this.memberId) || other.memberId == _this.memberId)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.seriesId, _this.seriesId) || other.seriesId == _this.seriesId)&&(identical(other.seriesPattern, _this.seriesPattern) || other.seriesPattern == _this.seriesPattern)&&(identical(other.checkedInAt, _this.checkedInAt) || other.checkedInAt == _this.checkedInAt)&&(identical(other.checkedOutAt, _this.checkedOutAt) || other.checkedOutAt == _this.checkedOutAt)&&(identical(other.spaceLabel, _this.spaceLabel) || other.spaceLabel == _this.spaceLabel)&&(identical(other.system, _this.system) || other.system == _this.system));
}


@override
int get hashCode {
  final _this = this as Reservation;
  return Object.hash(runtimeType,_this.id,_this.workspaceId,_this.seatId,_this.deskId,_this.officeId,_this.levelId,_this.memberId,_this.startsAt,_this.endsAt,_this.status,_this.seriesId,_this.seriesPattern,_this.checkedInAt,_this.checkedOutAt,_this.spaceLabel,_this.system);
}

@override
String toString() {
  final _this = this as Reservation;
  return 'Reservation(id: ${_this.id}, workspaceId: ${_this.workspaceId}, seatId: ${_this.seatId}, deskId: ${_this.deskId}, officeId: ${_this.officeId}, levelId: ${_this.levelId}, memberId: ${_this.memberId}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt}, status: ${_this.status}, seriesId: ${_this.seriesId}, seriesPattern: ${_this.seriesPattern}, checkedInAt: ${_this.checkedInAt}, checkedOutAt: ${_this.checkedOutAt}, spaceLabel: ${_this.spaceLabel}, system: ${_this.system})';
}


}

/// @nodoc
abstract mixin class $ReservationCopyWith<$Res>  {
  factory $ReservationCopyWith(Reservation value, $Res Function(Reservation) _then) = _$ReservationCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String? seatId, String? deskId, String? officeId, String? levelId, String memberId, DateTime startsAt, DateTime endsAt, ReservationStatus status, String? seriesId, String? seriesPattern, DateTime? checkedInAt, DateTime? checkedOutAt, String? spaceLabel, SystemColumns system
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? seatId = freezed,Object? deskId = freezed,Object? officeId = freezed,Object? levelId = freezed,Object? memberId = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? seriesId = freezed,Object? seriesPattern = freezed,Object? checkedInAt = freezed,Object? checkedOutAt = freezed,Object? spaceLabel = freezed,Object? system = null,}) {
  return _then(Reservation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,seatId: freezed == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String?,deskId: freezed == deskId ? _self.deskId : deskId // ignore: cast_nullable_to_non_nullable
as String?,officeId: freezed == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String?,levelId: freezed == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String?,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReservationStatus,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,seriesPattern: freezed == seriesPattern ? _self.seriesPattern : seriesPattern // ignore: cast_nullable_to_non_nullable
as String?,checkedInAt: freezed == checkedInAt ? _self.checkedInAt : checkedInAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedOutAt: freezed == checkedOutAt ? _self.checkedOutAt : checkedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,spaceLabel: freezed == spaceLabel ? _self.spaceLabel : spaceLabel // ignore: cast_nullable_to_non_nullable
as String?,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as SystemColumns,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String? seatId,  String? deskId,  String? officeId,  String? levelId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  String? seriesPattern,  DateTime? checkedInAt,  DateTime? checkedOutAt,  String? spaceLabel,  SystemColumns system)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reservation() when $default != null:
return $default(_that.id,_that.workspaceId,_that.seatId,_that.deskId,_that.officeId,_that.levelId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.seriesPattern,_that.checkedInAt,_that.checkedOutAt,_that.spaceLabel,_that.system);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String? seatId,  String? deskId,  String? officeId,  String? levelId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  String? seriesPattern,  DateTime? checkedInAt,  DateTime? checkedOutAt,  String? spaceLabel,  SystemColumns system)  $default,) {final _that = this;
switch (_that) {
case _Reservation():
return $default(_that.id,_that.workspaceId,_that.seatId,_that.deskId,_that.officeId,_that.levelId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.seriesPattern,_that.checkedInAt,_that.checkedOutAt,_that.spaceLabel,_that.system);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String? seatId,  String? deskId,  String? officeId,  String? levelId,  String memberId,  DateTime startsAt,  DateTime endsAt,  ReservationStatus status,  String? seriesId,  String? seriesPattern,  DateTime? checkedInAt,  DateTime? checkedOutAt,  String? spaceLabel,  SystemColumns system)?  $default,) {final _that = this;
switch (_that) {
case _Reservation() when $default != null:
return $default(_that.id,_that.workspaceId,_that.seatId,_that.deskId,_that.officeId,_that.levelId,_that.memberId,_that.startsAt,_that.endsAt,_that.status,_that.seriesId,_that.seriesPattern,_that.checkedInAt,_that.checkedOutAt,_that.spaceLabel,_that.system);case _:
  return null;

}
}

}

/// @nodoc


class _Reservation extends Reservation {
  const _Reservation({required this.id, required this.workspaceId, this.seatId, this.deskId, this.officeId, this.levelId, required this.memberId, required this.startsAt, required this.endsAt, required this.status, this.seriesId, this.seriesPattern, this.checkedInAt, this.checkedOutAt, this.spaceLabel, this.system = SystemColumns.none}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String? seatId;
@override final  String? deskId;
@override final  String? officeId;
/// Set when the booking covers a WHOLE level (0050); exactly one of
/// seat/office/level is non-null.
@override final  String? levelId;
@override final  String memberId;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  ReservationStatus status;
@override final  String? seriesId;
/// Repetition modality of the series ('daily' / 'weekdays' /
/// 'weekly', 0034); null on single bookings and pre-0034 series.
@override final  String? seriesPattern;
@override final  DateTime? checkedInAt;
@override final  DateTime? checkedOutAt;
/// Audit substitution snapshot (#587): the human-readable chain
/// (workspace · level · room · table · chair, up to the deleted
/// target's depth) written when an OWNER deleted the plan object
/// this reservation pointed at. Null while the target lives.
@override final  String? spaceLabel;
/// #992 — the server's stamp on this row.
@override@JsonKey() final  SystemColumns system;

/// Create a copy of Reservation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservationCopyWith<_Reservation> get copyWith => __$ReservationCopyWithImpl<_Reservation>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reservation&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.seatId, seatId) || other.seatId == seatId)&&(identical(other.deskId, deskId) || other.deskId == deskId)&&(identical(other.officeId, officeId) || other.officeId == officeId)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.seriesPattern, seriesPattern) || other.seriesPattern == seriesPattern)&&(identical(other.checkedInAt, checkedInAt) || other.checkedInAt == checkedInAt)&&(identical(other.checkedOutAt, checkedOutAt) || other.checkedOutAt == checkedOutAt)&&(identical(other.spaceLabel, spaceLabel) || other.spaceLabel == spaceLabel)&&(identical(other.system, system) || other.system == system));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,workspaceId,seatId,deskId,officeId,levelId,memberId,startsAt,endsAt,status,seriesId,seriesPattern,checkedInAt,checkedOutAt,spaceLabel,system);
}

@override
String toString() {
    return 'Reservation(id: $id, workspaceId: $workspaceId, seatId: $seatId, deskId: $deskId, officeId: $officeId, levelId: $levelId, memberId: $memberId, startsAt: $startsAt, endsAt: $endsAt, status: $status, seriesId: $seriesId, seriesPattern: $seriesPattern, checkedInAt: $checkedInAt, checkedOutAt: $checkedOutAt, spaceLabel: $spaceLabel, system: $system)';
}


}

/// @nodoc
abstract mixin class _$ReservationCopyWith<$Res> implements $ReservationCopyWith<$Res> {
  factory _$ReservationCopyWith(_Reservation value, $Res Function(_Reservation) _then) = __$ReservationCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String? seatId, String? deskId, String? officeId, String? levelId, String memberId, DateTime startsAt, DateTime endsAt, ReservationStatus status, String? seriesId, String? seriesPattern, DateTime? checkedInAt, DateTime? checkedOutAt, String? spaceLabel, SystemColumns system
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? seatId = freezed,Object? deskId = freezed,Object? officeId = freezed,Object? levelId = freezed,Object? memberId = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? seriesId = freezed,Object? seriesPattern = freezed,Object? checkedInAt = freezed,Object? checkedOutAt = freezed,Object? spaceLabel = freezed,Object? system = null,}) {
  return _then(_Reservation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,seatId: freezed == seatId ? _self.seatId : seatId // ignore: cast_nullable_to_non_nullable
as String?,deskId: freezed == deskId ? _self.deskId : deskId // ignore: cast_nullable_to_non_nullable
as String?,officeId: freezed == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String?,levelId: freezed == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String?,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ReservationStatus,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,seriesPattern: freezed == seriesPattern ? _self.seriesPattern : seriesPattern // ignore: cast_nullable_to_non_nullable
as String?,checkedInAt: freezed == checkedInAt ? _self.checkedInAt : checkedInAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedOutAt: freezed == checkedOutAt ? _self.checkedOutAt : checkedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,spaceLabel: freezed == spaceLabel ? _self.spaceLabel : spaceLabel // ignore: cast_nullable_to_non_nullable
as String?,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as SystemColumns,
  ));
}


}

// dart format on
