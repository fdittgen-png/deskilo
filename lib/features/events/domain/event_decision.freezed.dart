// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event_decision.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EventDecision {

 String get id; String get eventId;/// Null when the timeout sweep decided (see [decidedBySystem]).
 String? get memberId; bool get accept; bool get decidedBySystem; DateTime get decidedAt;
/// Create a copy of EventDecision
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventDecisionCopyWith<EventDecision> get copyWith => _$EventDecisionCopyWithImpl<EventDecision>(this as EventDecision, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventDecision&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.accept, accept) || other.accept == accept)&&(identical(other.decidedBySystem, decidedBySystem) || other.decidedBySystem == decidedBySystem)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,eventId,memberId,accept,decidedBySystem,decidedAt);

@override
String toString() {
  return 'EventDecision(id: $id, eventId: $eventId, memberId: $memberId, accept: $accept, decidedBySystem: $decidedBySystem, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class $EventDecisionCopyWith<$Res>  {
  factory $EventDecisionCopyWith(EventDecision value, $Res Function(EventDecision) _then) = _$EventDecisionCopyWithImpl;
@useResult
$Res call({
 String id, String eventId, String? memberId, bool accept, bool decidedBySystem, DateTime decidedAt
});




}
/// @nodoc
class _$EventDecisionCopyWithImpl<$Res>
    implements $EventDecisionCopyWith<$Res> {
  _$EventDecisionCopyWithImpl(this._self, this._then);

  final EventDecision _self;
  final $Res Function(EventDecision) _then;

/// Create a copy of EventDecision
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? eventId = null,Object? memberId = freezed,Object? accept = null,Object? decidedBySystem = null,Object? decidedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,accept: null == accept ? _self.accept : accept // ignore: cast_nullable_to_non_nullable
as bool,decidedBySystem: null == decidedBySystem ? _self.decidedBySystem : decidedBySystem // ignore: cast_nullable_to_non_nullable
as bool,decidedAt: null == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EventDecision].
extension EventDecisionPatterns on EventDecision {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventDecision value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventDecision() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventDecision value)  $default,){
final _that = this;
switch (_that) {
case _EventDecision():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventDecision value)?  $default,){
final _that = this;
switch (_that) {
case _EventDecision() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String eventId,  String? memberId,  bool accept,  bool decidedBySystem,  DateTime decidedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventDecision() when $default != null:
return $default(_that.id,_that.eventId,_that.memberId,_that.accept,_that.decidedBySystem,_that.decidedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String eventId,  String? memberId,  bool accept,  bool decidedBySystem,  DateTime decidedAt)  $default,) {final _that = this;
switch (_that) {
case _EventDecision():
return $default(_that.id,_that.eventId,_that.memberId,_that.accept,_that.decidedBySystem,_that.decidedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String eventId,  String? memberId,  bool accept,  bool decidedBySystem,  DateTime decidedAt)?  $default,) {final _that = this;
switch (_that) {
case _EventDecision() when $default != null:
return $default(_that.id,_that.eventId,_that.memberId,_that.accept,_that.decidedBySystem,_that.decidedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EventDecision extends EventDecision {
  const _EventDecision({required this.id, required this.eventId, this.memberId, required this.accept, required this.decidedBySystem, required this.decidedAt}): super._();
  

@override final  String id;
@override final  String eventId;
/// Null when the timeout sweep decided (see [decidedBySystem]).
@override final  String? memberId;
@override final  bool accept;
@override final  bool decidedBySystem;
@override final  DateTime decidedAt;

/// Create a copy of EventDecision
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventDecisionCopyWith<_EventDecision> get copyWith => __$EventDecisionCopyWithImpl<_EventDecision>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventDecision&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.accept, accept) || other.accept == accept)&&(identical(other.decidedBySystem, decidedBySystem) || other.decidedBySystem == decidedBySystem)&&(identical(other.decidedAt, decidedAt) || other.decidedAt == decidedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,eventId,memberId,accept,decidedBySystem,decidedAt);

@override
String toString() {
  return 'EventDecision(id: $id, eventId: $eventId, memberId: $memberId, accept: $accept, decidedBySystem: $decidedBySystem, decidedAt: $decidedAt)';
}


}

/// @nodoc
abstract mixin class _$EventDecisionCopyWith<$Res> implements $EventDecisionCopyWith<$Res> {
  factory _$EventDecisionCopyWith(_EventDecision value, $Res Function(_EventDecision) _then) = __$EventDecisionCopyWithImpl;
@override @useResult
$Res call({
 String id, String eventId, String? memberId, bool accept, bool decidedBySystem, DateTime decidedAt
});




}
/// @nodoc
class __$EventDecisionCopyWithImpl<$Res>
    implements _$EventDecisionCopyWith<$Res> {
  __$EventDecisionCopyWithImpl(this._self, this._then);

  final _EventDecision _self;
  final $Res Function(_EventDecision) _then;

/// Create a copy of EventDecision
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? eventId = null,Object? memberId = freezed,Object? accept = null,Object? decidedBySystem = null,Object? decidedAt = null,}) {
  return _then(_EventDecision(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,accept: null == accept ? _self.accept : accept // ignore: cast_nullable_to_non_nullable
as bool,decidedBySystem: null == decidedBySystem ? _self.decidedBySystem : decidedBySystem // ignore: cast_nullable_to_non_nullable
as bool,decidedAt: null == decidedAt ? _self.decidedAt : decidedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
