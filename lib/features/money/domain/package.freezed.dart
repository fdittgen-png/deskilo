// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'package.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Package {

 String get id; String get workspaceId; String get name; int get days; int get priceCents; bool get active;
/// Create a copy of Package
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PackageCopyWith<Package> get copyWith => _$PackageCopyWithImpl<Package>(this as Package, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Package&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.days, days) || other.days == days)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,days,priceCents,active);

@override
String toString() {
  return 'Package(id: $id, workspaceId: $workspaceId, name: $name, days: $days, priceCents: $priceCents, active: $active)';
}


}

/// @nodoc
abstract mixin class $PackageCopyWith<$Res>  {
  factory $PackageCopyWith(Package value, $Res Function(Package) _then) = _$PackageCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String name, int days, int priceCents, bool active
});




}
/// @nodoc
class _$PackageCopyWithImpl<$Res>
    implements $PackageCopyWith<$Res> {
  _$PackageCopyWithImpl(this._self, this._then);

  final Package _self;
  final $Res Function(Package) _then;

/// Create a copy of Package
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? days = null,Object? priceCents = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as int,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Package].
extension PackagePatterns on Package {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Package value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Package() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Package value)  $default,){
final _that = this;
switch (_that) {
case _Package():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Package value)?  $default,){
final _that = this;
switch (_that) {
case _Package() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int days,  int priceCents,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Package() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.days,_that.priceCents,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int days,  int priceCents,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Package():
return $default(_that.id,_that.workspaceId,_that.name,_that.days,_that.priceCents,_that.active);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String name,  int days,  int priceCents,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Package() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.days,_that.priceCents,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Package implements Package {
  const _Package({required this.id, required this.workspaceId, required this.name, required this.days, required this.priceCents, this.active = true});
  

@override final  String id;
@override final  String workspaceId;
@override final  String name;
@override final  int days;
@override final  int priceCents;
@override@JsonKey() final  bool active;

/// Create a copy of Package
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PackageCopyWith<_Package> get copyWith => __$PackageCopyWithImpl<_Package>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Package&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.days, days) || other.days == days)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,days,priceCents,active);

@override
String toString() {
  return 'Package(id: $id, workspaceId: $workspaceId, name: $name, days: $days, priceCents: $priceCents, active: $active)';
}


}

/// @nodoc
abstract mixin class _$PackageCopyWith<$Res> implements $PackageCopyWith<$Res> {
  factory _$PackageCopyWith(_Package value, $Res Function(_Package) _then) = __$PackageCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String name, int days, int priceCents, bool active
});




}
/// @nodoc
class __$PackageCopyWithImpl<$Res>
    implements _$PackageCopyWith<$Res> {
  __$PackageCopyWithImpl(this._self, this._then);

  final _Package _self;
  final $Res Function(_Package) _then;

/// Create a copy of Package
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? days = null,Object? priceCents = null,Object? active = null,}) {
  return _then(_Package(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as int,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
