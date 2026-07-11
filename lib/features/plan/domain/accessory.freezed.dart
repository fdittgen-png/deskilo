// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'accessory.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Accessory {

 String get id; String get workspaceId; String get name; int get supplementCents; bool get active; int get sortOrder;
/// Create a copy of Accessory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccessoryCopyWith<Accessory> get copyWith => _$AccessoryCopyWithImpl<Accessory>(this as Accessory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Accessory&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.supplementCents, supplementCents) || other.supplementCents == supplementCents)&&(identical(other.active, active) || other.active == active)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,supplementCents,active,sortOrder);

@override
String toString() {
  return 'Accessory(id: $id, workspaceId: $workspaceId, name: $name, supplementCents: $supplementCents, active: $active, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $AccessoryCopyWith<$Res>  {
  factory $AccessoryCopyWith(Accessory value, $Res Function(Accessory) _then) = _$AccessoryCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String name, int supplementCents, bool active, int sortOrder
});




}
/// @nodoc
class _$AccessoryCopyWithImpl<$Res>
    implements $AccessoryCopyWith<$Res> {
  _$AccessoryCopyWithImpl(this._self, this._then);

  final Accessory _self;
  final $Res Function(Accessory) _then;

/// Create a copy of Accessory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? supplementCents = null,Object? active = null,Object? sortOrder = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supplementCents: null == supplementCents ? _self.supplementCents : supplementCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Accessory].
extension AccessoryPatterns on Accessory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Accessory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Accessory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Accessory value)  $default,){
final _that = this;
switch (_that) {
case _Accessory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Accessory value)?  $default,){
final _that = this;
switch (_that) {
case _Accessory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int supplementCents,  bool active,  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Accessory() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.supplementCents,_that.active,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int supplementCents,  bool active,  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _Accessory():
return $default(_that.id,_that.workspaceId,_that.name,_that.supplementCents,_that.active,_that.sortOrder);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String name,  int supplementCents,  bool active,  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _Accessory() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.supplementCents,_that.active,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc


class _Accessory implements Accessory {
  const _Accessory({required this.id, required this.workspaceId, required this.name, required this.supplementCents, required this.active, required this.sortOrder});
  

@override final  String id;
@override final  String workspaceId;
@override final  String name;
@override final  int supplementCents;
@override final  bool active;
@override final  int sortOrder;

/// Create a copy of Accessory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessoryCopyWith<_Accessory> get copyWith => __$AccessoryCopyWithImpl<_Accessory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Accessory&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.supplementCents, supplementCents) || other.supplementCents == supplementCents)&&(identical(other.active, active) || other.active == active)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,supplementCents,active,sortOrder);

@override
String toString() {
  return 'Accessory(id: $id, workspaceId: $workspaceId, name: $name, supplementCents: $supplementCents, active: $active, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$AccessoryCopyWith<$Res> implements $AccessoryCopyWith<$Res> {
  factory _$AccessoryCopyWith(_Accessory value, $Res Function(_Accessory) _then) = __$AccessoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String name, int supplementCents, bool active, int sortOrder
});




}
/// @nodoc
class __$AccessoryCopyWithImpl<$Res>
    implements _$AccessoryCopyWith<$Res> {
  __$AccessoryCopyWithImpl(this._self, this._then);

  final _Accessory _self;
  final $Res Function(_Accessory) _then;

/// Create a copy of Accessory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? supplementCents = null,Object? active = null,Object? sortOrder = null,}) {
  return _then(_Accessory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supplementCents: null == supplementCents ? _self.supplementCents : supplementCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
