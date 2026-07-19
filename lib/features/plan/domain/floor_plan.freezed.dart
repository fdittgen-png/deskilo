// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'floor_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FloorPlan {

 String get levelId; List<Office> get offices; List<Desk> get desks; List<Seat> get seats; List<PlanImage> get images;
/// Create a copy of FloorPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FloorPlanCopyWith<FloorPlan> get copyWith => _$FloorPlanCopyWithImpl<FloorPlan>(this as FloorPlan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FloorPlan&&(identical(other.levelId, levelId) || other.levelId == levelId)&&const DeepCollectionEquality().equals(other.offices, offices)&&const DeepCollectionEquality().equals(other.desks, desks)&&const DeepCollectionEquality().equals(other.seats, seats)&&const DeepCollectionEquality().equals(other.images, images));
}


@override
int get hashCode => Object.hash(runtimeType,levelId,const DeepCollectionEquality().hash(offices),const DeepCollectionEquality().hash(desks),const DeepCollectionEquality().hash(seats),const DeepCollectionEquality().hash(images));

@override
String toString() {
  return 'FloorPlan(levelId: $levelId, offices: $offices, desks: $desks, seats: $seats, images: $images)';
}


}

/// @nodoc
abstract mixin class $FloorPlanCopyWith<$Res>  {
  factory $FloorPlanCopyWith(FloorPlan value, $Res Function(FloorPlan) _then) = _$FloorPlanCopyWithImpl;
@useResult
$Res call({
 String levelId, List<Office> offices, List<Desk> desks, List<Seat> seats, List<PlanImage> images
});




}
/// @nodoc
class _$FloorPlanCopyWithImpl<$Res>
    implements $FloorPlanCopyWith<$Res> {
  _$FloorPlanCopyWithImpl(this._self, this._then);

  final FloorPlan _self;
  final $Res Function(FloorPlan) _then;

/// Create a copy of FloorPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? levelId = null,Object? offices = null,Object? desks = null,Object? seats = null,Object? images = null,}) {
  return _then(_self.copyWith(
levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,offices: null == offices ? _self.offices : offices // ignore: cast_nullable_to_non_nullable
as List<Office>,desks: null == desks ? _self.desks : desks // ignore: cast_nullable_to_non_nullable
as List<Desk>,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as List<Seat>,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<PlanImage>,
  ));
}

}


/// Adds pattern-matching-related methods to [FloorPlan].
extension FloorPlanPatterns on FloorPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FloorPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FloorPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FloorPlan value)  $default,){
final _that = this;
switch (_that) {
case _FloorPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FloorPlan value)?  $default,){
final _that = this;
switch (_that) {
case _FloorPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String levelId,  List<Office> offices,  List<Desk> desks,  List<Seat> seats,  List<PlanImage> images)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FloorPlan() when $default != null:
return $default(_that.levelId,_that.offices,_that.desks,_that.seats,_that.images);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String levelId,  List<Office> offices,  List<Desk> desks,  List<Seat> seats,  List<PlanImage> images)  $default,) {final _that = this;
switch (_that) {
case _FloorPlan():
return $default(_that.levelId,_that.offices,_that.desks,_that.seats,_that.images);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String levelId,  List<Office> offices,  List<Desk> desks,  List<Seat> seats,  List<PlanImage> images)?  $default,) {final _that = this;
switch (_that) {
case _FloorPlan() when $default != null:
return $default(_that.levelId,_that.offices,_that.desks,_that.seats,_that.images);case _:
  return null;

}
}

}

/// @nodoc


class _FloorPlan extends FloorPlan {
  const _FloorPlan({required this.levelId, required final  List<Office> offices, required final  List<Desk> desks, required final  List<Seat> seats, final  List<PlanImage> images = const <PlanImage>[]}): _offices = offices,_desks = desks,_seats = seats,_images = images,super._();
  

@override final  String levelId;
 final  List<Office> _offices;
@override List<Office> get offices {
  if (_offices is EqualUnmodifiableListView) return _offices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_offices);
}

 final  List<Desk> _desks;
@override List<Desk> get desks {
  if (_desks is EqualUnmodifiableListView) return _desks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_desks);
}

 final  List<Seat> _seats;
@override List<Seat> get seats {
  if (_seats is EqualUnmodifiableListView) return _seats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seats);
}

 final  List<PlanImage> _images;
@override@JsonKey() List<PlanImage> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}


/// Create a copy of FloorPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FloorPlanCopyWith<_FloorPlan> get copyWith => __$FloorPlanCopyWithImpl<_FloorPlan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FloorPlan&&(identical(other.levelId, levelId) || other.levelId == levelId)&&const DeepCollectionEquality().equals(other._offices, _offices)&&const DeepCollectionEquality().equals(other._desks, _desks)&&const DeepCollectionEquality().equals(other._seats, _seats)&&const DeepCollectionEquality().equals(other._images, _images));
}


@override
int get hashCode => Object.hash(runtimeType,levelId,const DeepCollectionEquality().hash(_offices),const DeepCollectionEquality().hash(_desks),const DeepCollectionEquality().hash(_seats),const DeepCollectionEquality().hash(_images));

@override
String toString() {
  return 'FloorPlan(levelId: $levelId, offices: $offices, desks: $desks, seats: $seats, images: $images)';
}


}

/// @nodoc
abstract mixin class _$FloorPlanCopyWith<$Res> implements $FloorPlanCopyWith<$Res> {
  factory _$FloorPlanCopyWith(_FloorPlan value, $Res Function(_FloorPlan) _then) = __$FloorPlanCopyWithImpl;
@override @useResult
$Res call({
 String levelId, List<Office> offices, List<Desk> desks, List<Seat> seats, List<PlanImage> images
});




}
/// @nodoc
class __$FloorPlanCopyWithImpl<$Res>
    implements _$FloorPlanCopyWith<$Res> {
  __$FloorPlanCopyWithImpl(this._self, this._then);

  final _FloorPlan _self;
  final $Res Function(_FloorPlan) _then;

/// Create a copy of FloorPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? levelId = null,Object? offices = null,Object? desks = null,Object? seats = null,Object? images = null,}) {
  return _then(_FloorPlan(
levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,offices: null == offices ? _self._offices : offices // ignore: cast_nullable_to_non_nullable
as List<Office>,desks: null == desks ? _self._desks : desks // ignore: cast_nullable_to_non_nullable
as List<Desk>,seats: null == seats ? _self._seats : seats // ignore: cast_nullable_to_non_nullable
as List<Seat>,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<PlanImage>,
  ));
}


}

// dart format on
