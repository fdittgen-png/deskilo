// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkspaceEvent {

 String get id; String get workspaceId; EventType get type; EventAction get action; String get actorMemberId; String get subjectMemberId; String? get reservationId; Map<String, dynamic> get payload; EventStatus get status; DateTime get createdAt; DateTime? get decidedAt;
/// Create a copy of WorkspaceEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceEventCopyWith<WorkspaceEvent> get copyWith => _$WorkspaceEventCopyWithImpl<WorkspaceEvent>(this as WorkspaceEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.action, action) || other.action == action)&&(identical(other.actorMemberId, actorMemberId) || other.actorMemberId == actorMemberId)&&(identical(other.subjectMemberId, subjectMemberId) || other.subjectMemberId == subjectMemberId)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,type,action,actorMemberId,subjectMemberId,reservationId,const DeepCollectionEquality().hash(payload),status,createdAt,decidedAt);

@override
String toString() {
  return 'WorkspaceEvent(id: $id, workspaceId: $workspaceId, type: $type, action: $action, actorMemberId: $actorMemberId, subjectMemberId: $subjectMemberId, reservationId: $reservationId, payload: $payload, status: $status, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class $WorkspaceEventCopyWith<$Res>  {
  factory $WorkspaceEventCopyWith(WorkspaceEvent value, $Res Function(WorkspaceEvent) _then) = _$WorkspaceEventCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, EventType type, EventAction action, String actorMemberId, String subjectMemberId, String? reservationId, Map<String, dynamic> payload, EventStatus status, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class _$WorkspaceEventCopyWithImpl<$Res>
    implements $WorkspaceEventCopyWith<$Res> {
  _$WorkspaceEventCopyWithImpl(this._self, this._then);

  final WorkspaceEvent _self;
  final $Res Function(WorkspaceEvent) _then;

/// Create a copy of WorkspaceEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? type = null,Object? action = null,Object? actorMemberId = null,Object? subjectMemberId = null,Object? reservationId = freezed,Object? payload = null,Object? status = null,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as EventType,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as EventAction,actorMemberId: null == actorMemberId ? _self.actorMemberId : actorMemberId // ignore: cast_nullable_to_non_nullable
as String,subjectMemberId: null == subjectMemberId ? _self.subjectMemberId : subjectMemberId // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceEvent].
extension WorkspaceEventPatterns on WorkspaceEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceEvent value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceEvent value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  EventType type,  EventAction action,  String actorMemberId,  String subjectMemberId,  String? reservationId,  Map<String, dynamic> payload,  EventStatus status,  DateTime createdAt,  DateTime? decidedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceEvent() when $default != null:
return $default(_that.id,_that.workspaceId,_that.type,_that.action,_that.actorMemberId,_that.subjectMemberId,_that.reservationId,_that.payload,_that.status,_that.createdAt,_that.decidedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  EventType type,  EventAction action,  String actorMemberId,  String subjectMemberId,  String? reservationId,  Map<String, dynamic> payload,  EventStatus status,  DateTime createdAt,  DateTime? decidedAt)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceEvent():
return $default(_that.id,_that.workspaceId,_that.type,_that.action,_that.actorMemberId,_that.subjectMemberId,_that.reservationId,_that.payload,_that.status,_that.createdAt,_that.decidedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  EventType type,  EventAction action,  String actorMemberId,  String subjectMemberId,  String? reservationId,  Map<String, dynamic> payload,  EventStatus status,  DateTime createdAt,  DateTime? decidedAt)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceEvent() when $default != null:
return $default(_that.id,_that.workspaceId,_that.type,_that.action,_that.actorMemberId,_that.subjectMemberId,_that.reservationId,_that.payload,_that.status,_that.createdAt,_that.decidedAt);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceEvent extends WorkspaceEvent {
  const _WorkspaceEvent({required this.id, required this.workspaceId, required this.type, required this.action, required this.actorMemberId, required this.subjectMemberId, this.reservationId, required final  Map<String, dynamic> payload, required this.status, required this.createdAt, this.decidedAt}): _payload = payload,super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  EventType type;
@override final  EventAction action;
@override final  String actorMemberId;
@override final  String subjectMemberId;
@override final  String? reservationId;
 final  Map<String, dynamic> _payload;
@override Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override final  EventStatus status;
@override final  DateTime createdAt;
@override final  DateTime? decidedAt;

/// Create a copy of WorkspaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceEventCopyWith<_WorkspaceEvent> get copyWith => __$WorkspaceEventCopyWithImpl<_WorkspaceEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.action, action) || other.action == action)&&(identical(other.actorMemberId, actorMemberId) || other.actorMemberId == actorMemberId)&&(identical(other.subjectMemberId, subjectMemberId) || other.subjectMemberId == subjectMemberId)&&(identical(other.reservationId, reservationId) || other.reservationId == reservationId)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,type,action,actorMemberId,subjectMemberId,reservationId,const DeepCollectionEquality().hash(_payload),status,createdAt,decidedAt);

@override
String toString() {
  return 'WorkspaceEvent(id: $id, workspaceId: $workspaceId, type: $type, action: $action, actorMemberId: $actorMemberId, subjectMemberId: $subjectMemberId, reservationId: $reservationId, payload: $payload, status: $status, createdAt: $createdAt, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceEventCopyWith<$Res> implements $WorkspaceEventCopyWith<$Res> {
  factory _$WorkspaceEventCopyWith(_WorkspaceEvent value, $Res Function(_WorkspaceEvent) _then) = __$WorkspaceEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, EventType type, EventAction action, String actorMemberId, String subjectMemberId, String? reservationId, Map<String, dynamic> payload, EventStatus status, DateTime createdAt, DateTime? decidedAt
});




}
/// @nodoc
class __$WorkspaceEventCopyWithImpl<$Res>
    implements _$WorkspaceEventCopyWith<$Res> {
  __$WorkspaceEventCopyWithImpl(this._self, this._then);

  final _WorkspaceEvent _self;
  final $Res Function(_WorkspaceEvent) _then;

/// Create a copy of WorkspaceEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? type = null,Object? action = null,Object? actorMemberId = null,Object? subjectMemberId = null,Object? reservationId = freezed,Object? payload = null,Object? status = null,Object? createdAt = null,Object? decidedAt = freezed,}) {
  return _then(_WorkspaceEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as EventType,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as EventAction,actorMemberId: null == actorMemberId ? _self.actorMemberId : actorMemberId // ignore: cast_nullable_to_non_nullable
as String,subjectMemberId: null == subjectMemberId ? _self.subjectMemberId : subjectMemberId // ignore: cast_nullable_to_non_nullable
as String,reservationId: freezed == reservationId ? _self.reservationId : reservationId // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,decidedAt: freezed == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
