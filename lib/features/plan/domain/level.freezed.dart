// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'level.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Level {

 String get id; String get workspaceId; String get name; int get sortOrder;/// Storage object path of the level's background image (a photo or
/// blueprint of the real space, 0036), or null when none is set.
 String? get backgroundPath;
/// Create a copy of Level
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LevelCopyWith<Level> get copyWith => _$LevelCopyWithImpl<Level>(this as Level, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Level&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.backgroundPath, backgroundPath) || other.backgroundPath == backgroundPath));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,sortOrder,backgroundPath);

@override
String toString() {
  return 'Level(id: $id, workspaceId: $workspaceId, name: $name, sortOrder: $sortOrder, backgroundPath: $backgroundPath)';
}


}

/// @nodoc
abstract mixin class $LevelCopyWith<$Res>  {
  factory $LevelCopyWith(Level value, $Res Function(Level) _then) = _$LevelCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String name, int sortOrder, String? backgroundPath
});




}
/// @nodoc
class _$LevelCopyWithImpl<$Res>
    implements $LevelCopyWith<$Res> {
  _$LevelCopyWithImpl(this._self, this._then);

  final Level _self;
  final $Res Function(Level) _then;

/// Create a copy of Level
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? sortOrder = null,Object? backgroundPath = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,backgroundPath: freezed == backgroundPath ? _self.backgroundPath : backgroundPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Level].
extension LevelPatterns on Level {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Level value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Level() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Level value)  $default,){
final _that = this;
switch (_that) {
case _Level():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Level value)?  $default,){
final _that = this;
switch (_that) {
case _Level() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int sortOrder,  String? backgroundPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Level() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.sortOrder,_that.backgroundPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int sortOrder,  String? backgroundPath)  $default,) {final _that = this;
switch (_that) {
case _Level():
return $default(_that.id,_that.workspaceId,_that.name,_that.sortOrder,_that.backgroundPath);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String name,  int sortOrder,  String? backgroundPath)?  $default,) {final _that = this;
switch (_that) {
case _Level() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.sortOrder,_that.backgroundPath);case _:
  return null;

}
}

}

/// @nodoc


class _Level extends Level {
  const _Level({required this.id, required this.workspaceId, required this.name, required this.sortOrder, this.backgroundPath}): super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String name;
@override final  int sortOrder;
/// Storage object path of the level's background image (a photo or
/// blueprint of the real space, 0036), or null when none is set.
@override final  String? backgroundPath;

/// Create a copy of Level
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LevelCopyWith<_Level> get copyWith => __$LevelCopyWithImpl<_Level>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Level&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.backgroundPath, backgroundPath) || other.backgroundPath == backgroundPath));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,sortOrder,backgroundPath);

@override
String toString() {
  return 'Level(id: $id, workspaceId: $workspaceId, name: $name, sortOrder: $sortOrder, backgroundPath: $backgroundPath)';
}


}

/// @nodoc
abstract mixin class _$LevelCopyWith<$Res> implements $LevelCopyWith<$Res> {
  factory _$LevelCopyWith(_Level value, $Res Function(_Level) _then) = __$LevelCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String name, int sortOrder, String? backgroundPath
});




}
/// @nodoc
class __$LevelCopyWithImpl<$Res>
    implements _$LevelCopyWith<$Res> {
  __$LevelCopyWithImpl(this._self, this._then);

  final _Level _self;
  final $Res Function(_Level) _then;

/// Create a copy of Level
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? sortOrder = null,Object? backgroundPath = freezed,}) {
  return _then(_Level(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,backgroundPath: freezed == backgroundPath ? _self.backgroundPath : backgroundPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
