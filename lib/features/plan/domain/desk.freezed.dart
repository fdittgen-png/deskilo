// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Desk {

 String get id; String get workspaceId; String get officeId; String get name; GridRect get rect;
/// Create a copy of Desk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeskCopyWith<Desk> get copyWith => _$DeskCopyWithImpl<Desk>(this as Desk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Desk&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.officeId, officeId) || other.officeId == officeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.rect, rect) || other.rect == rect));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,officeId,name,rect);

@override
String toString() {
  return 'Desk(id: $id, workspaceId: $workspaceId, officeId: $officeId, name: $name, rect: $rect)';
}


}

/// @nodoc
abstract mixin class $DeskCopyWith<$Res>  {
  factory $DeskCopyWith(Desk value, $Res Function(Desk) _then) = _$DeskCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String officeId, String name, GridRect rect
});


$GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class _$DeskCopyWithImpl<$Res>
    implements $DeskCopyWith<$Res> {
  _$DeskCopyWithImpl(this._self, this._then);

  final Desk _self;
  final $Res Function(Desk) _then;

/// Create a copy of Desk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? officeId = null,Object? name = null,Object? rect = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,officeId: null == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,
  ));
}
/// Create a copy of Desk
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}


/// Adds pattern-matching-related methods to [Desk].
extension DeskPatterns on Desk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Desk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Desk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Desk value)  $default,){
final _that = this;
switch (_that) {
case _Desk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Desk value)?  $default,){
final _that = this;
switch (_that) {
case _Desk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String officeId,  String name,  GridRect rect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Desk() when $default != null:
return $default(_that.id,_that.workspaceId,_that.officeId,_that.name,_that.rect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String officeId,  String name,  GridRect rect)  $default,) {final _that = this;
switch (_that) {
case _Desk():
return $default(_that.id,_that.workspaceId,_that.officeId,_that.name,_that.rect);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String officeId,  String name,  GridRect rect)?  $default,) {final _that = this;
switch (_that) {
case _Desk() when $default != null:
return $default(_that.id,_that.workspaceId,_that.officeId,_that.name,_that.rect);case _:
  return null;

}
}

}

/// @nodoc


class _Desk implements Desk {
  const _Desk({required this.id, required this.workspaceId, required this.officeId, required this.name, required this.rect});
  

@override final  String id;
@override final  String workspaceId;
@override final  String officeId;
@override final  String name;
@override final  GridRect rect;

/// Create a copy of Desk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeskCopyWith<_Desk> get copyWith => __$DeskCopyWithImpl<_Desk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Desk&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.officeId, officeId) || other.officeId == officeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.rect, rect) || other.rect == rect));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,officeId,name,rect);

@override
String toString() {
  return 'Desk(id: $id, workspaceId: $workspaceId, officeId: $officeId, name: $name, rect: $rect)';
}


}

/// @nodoc
abstract mixin class _$DeskCopyWith<$Res> implements $DeskCopyWith<$Res> {
  factory _$DeskCopyWith(_Desk value, $Res Function(_Desk) _then) = __$DeskCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String officeId, String name, GridRect rect
});


@override $GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class __$DeskCopyWithImpl<$Res>
    implements _$DeskCopyWith<$Res> {
  __$DeskCopyWithImpl(this._self, this._then);

  final _Desk _self;
  final $Res Function(_Desk) _then;

/// Create a copy of Desk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? officeId = null,Object? name = null,Object? rect = null,}) {
  return _then(_Desk(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,officeId: null == officeId ? _self.officeId : officeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,
  ));
}

/// Create a copy of Desk
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
