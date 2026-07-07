// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'office.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Office {

 String get id; String get workspaceId; String get levelId; String get name; int get color; bool get bookableAsWhole; GridRect get rect;
/// Create a copy of Office
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfficeCopyWith<Office> get copyWith => _$OfficeCopyWithImpl<Office>(this as Office, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Office&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.bookableAsWhole, bookableAsWhole) || other.bookableAsWhole == bookableAsWhole)&&(identical(other.rect, rect) || other.rect == rect));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,levelId,name,color,bookableAsWhole,rect);

@override
String toString() {
  return 'Office(id: $id, workspaceId: $workspaceId, levelId: $levelId, name: $name, color: $color, bookableAsWhole: $bookableAsWhole, rect: $rect)';
}


}

/// @nodoc
abstract mixin class $OfficeCopyWith<$Res>  {
  factory $OfficeCopyWith(Office value, $Res Function(Office) _then) = _$OfficeCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String levelId, String name, int color, bool bookableAsWhole, GridRect rect
});


$GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class _$OfficeCopyWithImpl<$Res>
    implements $OfficeCopyWith<$Res> {
  _$OfficeCopyWithImpl(this._self, this._then);

  final Office _self;
  final $Res Function(Office) _then;

/// Create a copy of Office
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? levelId = null,Object? name = null,Object? color = null,Object? bookableAsWhole = null,Object? rect = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,
  ));
}
/// Create a copy of Office
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}


/// Adds pattern-matching-related methods to [Office].
extension OfficePatterns on Office {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Office value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Office() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Office value)  $default,){
final _that = this;
switch (_that) {
case _Office():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Office value)?  $default,){
final _that = this;
switch (_that) {
case _Office() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String levelId,  String name,  int color,  bool bookableAsWhole,  GridRect rect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Office() when $default != null:
return $default(_that.id,_that.workspaceId,_that.levelId,_that.name,_that.color,_that.bookableAsWhole,_that.rect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String levelId,  String name,  int color,  bool bookableAsWhole,  GridRect rect)  $default,) {final _that = this;
switch (_that) {
case _Office():
return $default(_that.id,_that.workspaceId,_that.levelId,_that.name,_that.color,_that.bookableAsWhole,_that.rect);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String levelId,  String name,  int color,  bool bookableAsWhole,  GridRect rect)?  $default,) {final _that = this;
switch (_that) {
case _Office() when $default != null:
return $default(_that.id,_that.workspaceId,_that.levelId,_that.name,_that.color,_that.bookableAsWhole,_that.rect);case _:
  return null;

}
}

}

/// @nodoc


class _Office implements Office {
  const _Office({required this.id, required this.workspaceId, required this.levelId, required this.name, required this.color, required this.bookableAsWhole, required this.rect});
  

@override final  String id;
@override final  String workspaceId;
@override final  String levelId;
@override final  String name;
@override final  int color;
@override final  bool bookableAsWhole;
@override final  GridRect rect;

/// Create a copy of Office
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfficeCopyWith<_Office> get copyWith => __$OfficeCopyWithImpl<_Office>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Office&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.bookableAsWhole, bookableAsWhole) || other.bookableAsWhole == bookableAsWhole)&&(identical(other.rect, rect) || other.rect == rect));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,levelId,name,color,bookableAsWhole,rect);

@override
String toString() {
  return 'Office(id: $id, workspaceId: $workspaceId, levelId: $levelId, name: $name, color: $color, bookableAsWhole: $bookableAsWhole, rect: $rect)';
}


}

/// @nodoc
abstract mixin class _$OfficeCopyWith<$Res> implements $OfficeCopyWith<$Res> {
  factory _$OfficeCopyWith(_Office value, $Res Function(_Office) _then) = __$OfficeCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String levelId, String name, int color, bool bookableAsWhole, GridRect rect
});


@override $GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class __$OfficeCopyWithImpl<$Res>
    implements _$OfficeCopyWith<$Res> {
  __$OfficeCopyWithImpl(this._self, this._then);

  final _Office _self;
  final $Res Function(_Office) _then;

/// Create a copy of Office
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? levelId = null,Object? name = null,Object? color = null,Object? bookableAsWhole = null,Object? rect = null,}) {
  return _then(_Office(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,
  ));
}

/// Create a copy of Office
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
