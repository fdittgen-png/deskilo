// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'service_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServiceItem {

 String get id; String get workspaceId; String get name; int get priceCents; bool get active;
/// Create a copy of ServiceItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceItemCopyWith<ServiceItem> get copyWith => _$ServiceItemCopyWithImpl<ServiceItem>(this as ServiceItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServiceItem&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,priceCents,active);

@override
String toString() {
  return 'ServiceItem(id: $id, workspaceId: $workspaceId, name: $name, priceCents: $priceCents, active: $active)';
}


}

/// @nodoc
abstract mixin class $ServiceItemCopyWith<$Res>  {
  factory $ServiceItemCopyWith(ServiceItem value, $Res Function(ServiceItem) _then) = _$ServiceItemCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String name, int priceCents, bool active
});




}
/// @nodoc
class _$ServiceItemCopyWithImpl<$Res>
    implements $ServiceItemCopyWith<$Res> {
  _$ServiceItemCopyWithImpl(this._self, this._then);

  final ServiceItem _self;
  final $Res Function(ServiceItem) _then;

/// Create a copy of ServiceItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? priceCents = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ServiceItem].
extension ServiceItemPatterns on ServiceItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServiceItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServiceItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServiceItem value)  $default,){
final _that = this;
switch (_that) {
case _ServiceItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServiceItem value)?  $default,){
final _that = this;
switch (_that) {
case _ServiceItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int priceCents,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServiceItem() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.priceCents,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String name,  int priceCents,  bool active)  $default,) {final _that = this;
switch (_that) {
case _ServiceItem():
return $default(_that.id,_that.workspaceId,_that.name,_that.priceCents,_that.active);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String name,  int priceCents,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _ServiceItem() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.priceCents,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _ServiceItem implements ServiceItem {
  const _ServiceItem({required this.id, required this.workspaceId, required this.name, required this.priceCents, required this.active});
  

@override final  String id;
@override final  String workspaceId;
@override final  String name;
@override final  int priceCents;
@override final  bool active;

/// Create a copy of ServiceItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceItemCopyWith<_ServiceItem> get copyWith => __$ServiceItemCopyWithImpl<_ServiceItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServiceItem&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,priceCents,active);

@override
String toString() {
  return 'ServiceItem(id: $id, workspaceId: $workspaceId, name: $name, priceCents: $priceCents, active: $active)';
}


}

/// @nodoc
abstract mixin class _$ServiceItemCopyWith<$Res> implements $ServiceItemCopyWith<$Res> {
  factory _$ServiceItemCopyWith(_ServiceItem value, $Res Function(_ServiceItem) _then) = __$ServiceItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String name, int priceCents, bool active
});




}
/// @nodoc
class __$ServiceItemCopyWithImpl<$Res>
    implements _$ServiceItemCopyWith<$Res> {
  __$ServiceItemCopyWithImpl(this._self, this._then);

  final _ServiceItem _self;
  final $Res Function(_ServiceItem) _then;

/// Create a copy of ServiceItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? priceCents = null,Object? active = null,}) {
  return _then(_ServiceItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
