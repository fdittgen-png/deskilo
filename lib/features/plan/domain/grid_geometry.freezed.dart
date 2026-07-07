// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grid_geometry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GridRect {

 int get x; int get y; int get w; int get h;
/// Create a copy of GridRect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GridRectCopyWith<GridRect> get copyWith => _$GridRectCopyWithImpl<GridRect>(this as GridRect, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GridRect&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}


@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridRect(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class $GridRectCopyWith<$Res>  {
  factory $GridRectCopyWith(GridRect value, $Res Function(GridRect) _then) = _$GridRectCopyWithImpl;
@useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class _$GridRectCopyWithImpl<$Res>
    implements $GridRectCopyWith<$Res> {
  _$GridRectCopyWithImpl(this._self, this._then);

  final GridRect _self;
  final $Res Function(GridRect) _then;

/// Create a copy of GridRect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,Object? w = null,Object? h = null,}) {
  return _then(_self.copyWith(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as int,h: null == h ? _self.h : h // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GridRect].
extension GridRectPatterns on GridRect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GridRect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GridRect() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GridRect value)  $default,){
final _that = this;
switch (_that) {
case _GridRect():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GridRect value)?  $default,){
final _that = this;
switch (_that) {
case _GridRect() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int x,  int y,  int w,  int h)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GridRect() when $default != null:
return $default(_that.x,_that.y,_that.w,_that.h);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int x,  int y,  int w,  int h)  $default,) {final _that = this;
switch (_that) {
case _GridRect():
return $default(_that.x,_that.y,_that.w,_that.h);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int x,  int y,  int w,  int h)?  $default,) {final _that = this;
switch (_that) {
case _GridRect() when $default != null:
return $default(_that.x,_that.y,_that.w,_that.h);case _:
  return null;

}
}

}

/// @nodoc


class _GridRect extends GridRect {
  const _GridRect({required this.x, required this.y, required this.w, required this.h}): super._();
  

@override final  int x;
@override final  int y;
@override final  int w;
@override final  int h;

/// Create a copy of GridRect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GridRectCopyWith<_GridRect> get copyWith => __$GridRectCopyWithImpl<_GridRect>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GridRect&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}


@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridRect(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class _$GridRectCopyWith<$Res> implements $GridRectCopyWith<$Res> {
  factory _$GridRectCopyWith(_GridRect value, $Res Function(_GridRect) _then) = __$GridRectCopyWithImpl;
@override @useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class __$GridRectCopyWithImpl<$Res>
    implements _$GridRectCopyWith<$Res> {
  __$GridRectCopyWithImpl(this._self, this._then);

  final _GridRect _self;
  final $Res Function(_GridRect) _then;

/// Create a copy of GridRect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? w = null,Object? h = null,}) {
  return _then(_GridRect(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as int,h: null == h ? _self.h : h // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
