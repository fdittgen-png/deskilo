// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlanImage {

 String get id; String get levelId; GridRect get rect; String get storagePath;
/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlanImageCopyWith<PlanImage> get copyWith => _$PlanImageCopyWithImpl<PlanImage>(this as PlanImage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlanImage&&(identical(other.id, id) || other.id == id)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.rect, rect) || other.rect == rect)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath));
}


@override
int get hashCode => Object.hash(runtimeType,id,levelId,rect,storagePath);

@override
String toString() {
  return 'PlanImage(id: $id, levelId: $levelId, rect: $rect, storagePath: $storagePath)';
}


}

/// @nodoc
abstract mixin class $PlanImageCopyWith<$Res>  {
  factory $PlanImageCopyWith(PlanImage value, $Res Function(PlanImage) _then) = _$PlanImageCopyWithImpl;
@useResult
$Res call({
 String id, String levelId, GridRect rect, String storagePath
});


$GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class _$PlanImageCopyWithImpl<$Res>
    implements $PlanImageCopyWith<$Res> {
  _$PlanImageCopyWithImpl(this._self, this._then);

  final PlanImage _self;
  final $Res Function(PlanImage) _then;

/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? levelId = null,Object? rect = null,Object? storagePath = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlanImage].
extension PlanImagePatterns on PlanImage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlanImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlanImage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlanImage value)  $default,){
final _that = this;
switch (_that) {
case _PlanImage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlanImage value)?  $default,){
final _that = this;
switch (_that) {
case _PlanImage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String levelId,  GridRect rect,  String storagePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlanImage() when $default != null:
return $default(_that.id,_that.levelId,_that.rect,_that.storagePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String levelId,  GridRect rect,  String storagePath)  $default,) {final _that = this;
switch (_that) {
case _PlanImage():
return $default(_that.id,_that.levelId,_that.rect,_that.storagePath);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String levelId,  GridRect rect,  String storagePath)?  $default,) {final _that = this;
switch (_that) {
case _PlanImage() when $default != null:
return $default(_that.id,_that.levelId,_that.rect,_that.storagePath);case _:
  return null;

}
}

}

/// @nodoc


class _PlanImage implements PlanImage {
  const _PlanImage({required this.id, required this.levelId, required this.rect, required this.storagePath});
  

@override final  String id;
@override final  String levelId;
@override final  GridRect rect;
@override final  String storagePath;

/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlanImageCopyWith<_PlanImage> get copyWith => __$PlanImageCopyWithImpl<_PlanImage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlanImage&&(identical(other.id, id) || other.id == id)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.rect, rect) || other.rect == rect)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath));
}


@override
int get hashCode => Object.hash(runtimeType,id,levelId,rect,storagePath);

@override
String toString() {
  return 'PlanImage(id: $id, levelId: $levelId, rect: $rect, storagePath: $storagePath)';
}


}

/// @nodoc
abstract mixin class _$PlanImageCopyWith<$Res> implements $PlanImageCopyWith<$Res> {
  factory _$PlanImageCopyWith(_PlanImage value, $Res Function(_PlanImage) _then) = __$PlanImageCopyWithImpl;
@override @useResult
$Res call({
 String id, String levelId, GridRect rect, String storagePath
});


@override $GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class __$PlanImageCopyWithImpl<$Res>
    implements _$PlanImageCopyWith<$Res> {
  __$PlanImageCopyWithImpl(this._self, this._then);

  final _PlanImage _self;
  final $Res Function(_PlanImage) _then;

/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? levelId = null,Object? rect = null,Object? storagePath = null,}) {
  return _then(_PlanImage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PlanImage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}

// dart format on
