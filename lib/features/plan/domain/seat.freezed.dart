// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Seat {

 String get id; String get workspaceId; String get deskId; String get name; int get x; int get y; SeatOrientation get orientation; String get chair; List<String> get amenities; DateTime? get blockedFrom; DateTime? get blockedTo;
/// Create a copy of Seat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeatCopyWith<Seat> get copyWith => _$SeatCopyWithImpl<Seat>(this as Seat, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Seat&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.deskId, deskId) || other.deskId == deskId)&&(identical(other.name, name) || other.name == name)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.chair, chair) || other.chair == chair)&&const DeepCollectionEquality().equals(other.amenities, amenities)&&(identical(other.blockedFrom, blockedFrom) || other.blockedFrom == blockedFrom)&&(identical(other.blockedTo, blockedTo) || other.blockedTo == blockedTo));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,deskId,name,x,y,orientation,chair,const DeepCollectionEquality().hash(amenities),blockedFrom,blockedTo);

@override
String toString() {
  return 'Seat(id: $id, workspaceId: $workspaceId, deskId: $deskId, name: $name, x: $x, y: $y, orientation: $orientation, chair: $chair, amenities: $amenities, blockedFrom: $blockedFrom, blockedTo: $blockedTo)';
}


}

/// @nodoc
abstract mixin class $SeatCopyWith<$Res>  {
  factory $SeatCopyWith(Seat value, $Res Function(Seat) _then) = _$SeatCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String deskId, String name, int x, int y, SeatOrientation orientation, String chair, List<String> amenities, DateTime? blockedFrom, DateTime? blockedTo
});




}
/// @nodoc
class _$SeatCopyWithImpl<$Res>
    implements $SeatCopyWith<$Res> {
  _$SeatCopyWithImpl(this._self, this._then);

  final Seat _self;
  final $Res Function(Seat) _then;

/// Create a copy of Seat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? deskId = null,Object? name = null,Object? x = null,Object? y = null,Object? orientation = null,Object? chair = null,Object? amenities = null,Object? blockedFrom = freezed,Object? blockedTo = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,deskId: null == deskId ? _self.deskId : deskId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as SeatOrientation,chair: null == chair ? _self.chair : chair // ignore: cast_nullable_to_non_nullable
as String,amenities: null == amenities ? _self.amenities : amenities // ignore: cast_nullable_to_non_nullable
as List<String>,blockedFrom: freezed == blockedFrom ? _self.blockedFrom : blockedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,blockedTo: freezed == blockedTo ? _self.blockedTo : blockedTo // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Seat].
extension SeatPatterns on Seat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Seat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Seat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Seat value)  $default,){
final _that = this;
switch (_that) {
case _Seat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Seat value)?  $default,){
final _that = this;
switch (_that) {
case _Seat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String deskId,  String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  DateTime? blockedFrom,  DateTime? blockedTo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Seat() when $default != null:
return $default(_that.id,_that.workspaceId,_that.deskId,_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.blockedFrom,_that.blockedTo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String deskId,  String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  DateTime? blockedFrom,  DateTime? blockedTo)  $default,) {final _that = this;
switch (_that) {
case _Seat():
return $default(_that.id,_that.workspaceId,_that.deskId,_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.blockedFrom,_that.blockedTo);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String deskId,  String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  DateTime? blockedFrom,  DateTime? blockedTo)?  $default,) {final _that = this;
switch (_that) {
case _Seat() when $default != null:
return $default(_that.id,_that.workspaceId,_that.deskId,_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.blockedFrom,_that.blockedTo);case _:
  return null;

}
}

}

/// @nodoc


class _Seat extends Seat {
  const _Seat({required this.id, required this.workspaceId, required this.deskId, required this.name, required this.x, required this.y, required this.orientation, required this.chair, required final  List<String> amenities, this.blockedFrom, this.blockedTo}): _amenities = amenities,super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String deskId;
@override final  String name;
@override final  int x;
@override final  int y;
@override final  SeatOrientation orientation;
@override final  String chair;
 final  List<String> _amenities;
@override List<String> get amenities {
  if (_amenities is EqualUnmodifiableListView) return _amenities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_amenities);
}

@override final  DateTime? blockedFrom;
@override final  DateTime? blockedTo;

/// Create a copy of Seat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeatCopyWith<_Seat> get copyWith => __$SeatCopyWithImpl<_Seat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Seat&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.deskId, deskId) || other.deskId == deskId)&&(identical(other.name, name) || other.name == name)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.chair, chair) || other.chair == chair)&&const DeepCollectionEquality().equals(other._amenities, _amenities)&&(identical(other.blockedFrom, blockedFrom) || other.blockedFrom == blockedFrom)&&(identical(other.blockedTo, blockedTo) || other.blockedTo == blockedTo));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,deskId,name,x,y,orientation,chair,const DeepCollectionEquality().hash(_amenities),blockedFrom,blockedTo);

@override
String toString() {
  return 'Seat(id: $id, workspaceId: $workspaceId, deskId: $deskId, name: $name, x: $x, y: $y, orientation: $orientation, chair: $chair, amenities: $amenities, blockedFrom: $blockedFrom, blockedTo: $blockedTo)';
}


}

/// @nodoc
abstract mixin class _$SeatCopyWith<$Res> implements $SeatCopyWith<$Res> {
  factory _$SeatCopyWith(_Seat value, $Res Function(_Seat) _then) = __$SeatCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String deskId, String name, int x, int y, SeatOrientation orientation, String chair, List<String> amenities, DateTime? blockedFrom, DateTime? blockedTo
});




}
/// @nodoc
class __$SeatCopyWithImpl<$Res>
    implements _$SeatCopyWith<$Res> {
  __$SeatCopyWithImpl(this._self, this._then);

  final _Seat _self;
  final $Res Function(_Seat) _then;

/// Create a copy of Seat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? deskId = null,Object? name = null,Object? x = null,Object? y = null,Object? orientation = null,Object? chair = null,Object? amenities = null,Object? blockedFrom = freezed,Object? blockedTo = freezed,}) {
  return _then(_Seat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,deskId: null == deskId ? _self.deskId : deskId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as SeatOrientation,chair: null == chair ? _self.chair : chair // ignore: cast_nullable_to_non_nullable
as String,amenities: null == amenities ? _self._amenities : amenities // ignore: cast_nullable_to_non_nullable
as List<String>,blockedFrom: freezed == blockedFrom ? _self.blockedFrom : blockedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,blockedTo: freezed == blockedTo ? _self.blockedTo : blockedTo // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
