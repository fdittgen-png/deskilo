// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fee_band.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeeBand {

 String get id; String get workspaceId; int get fromPct; int get toPct; int get feeCents; int get overageFeeCents;
/// Create a copy of FeeBand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeeBandCopyWith<FeeBand> get copyWith => _$FeeBandCopyWithImpl<FeeBand>(this as FeeBand, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeeBand&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.fromPct, fromPct) || other.fromPct == fromPct)&&(identical(other.toPct, toPct) || other.toPct == toPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.overageFeeCents, overageFeeCents) || other.overageFeeCents == overageFeeCents));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,fromPct,toPct,feeCents,overageFeeCents);

@override
String toString() {
  return 'FeeBand(id: $id, workspaceId: $workspaceId, fromPct: $fromPct, toPct: $toPct, feeCents: $feeCents, overageFeeCents: $overageFeeCents)';
}


}

/// @nodoc
abstract mixin class $FeeBandCopyWith<$Res>  {
  factory $FeeBandCopyWith(FeeBand value, $Res Function(FeeBand) _then) = _$FeeBandCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, int fromPct, int toPct, int feeCents, int overageFeeCents
});




}
/// @nodoc
class _$FeeBandCopyWithImpl<$Res>
    implements $FeeBandCopyWith<$Res> {
  _$FeeBandCopyWithImpl(this._self, this._then);

  final FeeBand _self;
  final $Res Function(FeeBand) _then;

/// Create a copy of FeeBand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? fromPct = null,Object? toPct = null,Object? feeCents = null,Object? overageFeeCents = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,fromPct: null == fromPct ? _self.fromPct : fromPct // ignore: cast_nullable_to_non_nullable
as int,toPct: null == toPct ? _self.toPct : toPct // ignore: cast_nullable_to_non_nullable
as int,feeCents: null == feeCents ? _self.feeCents : feeCents // ignore: cast_nullable_to_non_nullable
as int,overageFeeCents: null == overageFeeCents ? _self.overageFeeCents : overageFeeCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FeeBand].
extension FeeBandPatterns on FeeBand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeeBand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeeBand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeeBand value)  $default,){
final _that = this;
switch (_that) {
case _FeeBand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeeBand value)?  $default,){
final _that = this;
switch (_that) {
case _FeeBand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  int fromPct,  int toPct,  int feeCents,  int overageFeeCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeeBand() when $default != null:
return $default(_that.id,_that.workspaceId,_that.fromPct,_that.toPct,_that.feeCents,_that.overageFeeCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  int fromPct,  int toPct,  int feeCents,  int overageFeeCents)  $default,) {final _that = this;
switch (_that) {
case _FeeBand():
return $default(_that.id,_that.workspaceId,_that.fromPct,_that.toPct,_that.feeCents,_that.overageFeeCents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  int fromPct,  int toPct,  int feeCents,  int overageFeeCents)?  $default,) {final _that = this;
switch (_that) {
case _FeeBand() when $default != null:
return $default(_that.id,_that.workspaceId,_that.fromPct,_that.toPct,_that.feeCents,_that.overageFeeCents);case _:
  return null;

}
}

}

/// @nodoc


class _FeeBand implements FeeBand {
  const _FeeBand({required this.id, required this.workspaceId, required this.fromPct, required this.toPct, required this.feeCents, required this.overageFeeCents});
  

@override final  String id;
@override final  String workspaceId;
@override final  int fromPct;
@override final  int toPct;
@override final  int feeCents;
@override final  int overageFeeCents;

/// Create a copy of FeeBand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeeBandCopyWith<_FeeBand> get copyWith => __$FeeBandCopyWithImpl<_FeeBand>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeeBand&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.fromPct, fromPct) || other.fromPct == fromPct)&&(identical(other.toPct, toPct) || other.toPct == toPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.overageFeeCents, overageFeeCents) || other.overageFeeCents == overageFeeCents));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,fromPct,toPct,feeCents,overageFeeCents);

@override
String toString() {
  return 'FeeBand(id: $id, workspaceId: $workspaceId, fromPct: $fromPct, toPct: $toPct, feeCents: $feeCents, overageFeeCents: $overageFeeCents)';
}


}

/// @nodoc
abstract mixin class _$FeeBandCopyWith<$Res> implements $FeeBandCopyWith<$Res> {
  factory _$FeeBandCopyWith(_FeeBand value, $Res Function(_FeeBand) _then) = __$FeeBandCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, int fromPct, int toPct, int feeCents, int overageFeeCents
});




}
/// @nodoc
class __$FeeBandCopyWithImpl<$Res>
    implements _$FeeBandCopyWith<$Res> {
  __$FeeBandCopyWithImpl(this._self, this._then);

  final _FeeBand _self;
  final $Res Function(_FeeBand) _then;

/// Create a copy of FeeBand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? fromPct = null,Object? toPct = null,Object? feeCents = null,Object? overageFeeCents = null,}) {
  return _then(_FeeBand(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,fromPct: null == fromPct ? _self.fromPct : fromPct // ignore: cast_nullable_to_non_nullable
as int,toPct: null == toPct ? _self.toPct : toPct // ignore: cast_nullable_to_non_nullable
as int,feeCents: null == feeCents ? _self.feeCents : feeCents // ignore: cast_nullable_to_non_nullable
as int,overageFeeCents: null == overageFeeCents ? _self.overageFeeCents : overageFeeCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
