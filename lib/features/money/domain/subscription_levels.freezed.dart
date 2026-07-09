// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_levels.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubscriptionLevels {

 List<int> get enabledPresets; List<int> get extraLevels; bool get allowCustom;
/// Create a copy of SubscriptionLevels
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionLevelsCopyWith<SubscriptionLevels> get copyWith => _$SubscriptionLevelsCopyWithImpl<SubscriptionLevels>(this as SubscriptionLevels, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionLevels&&const DeepCollectionEquality().equals(other.enabledPresets, enabledPresets)&&const DeepCollectionEquality().equals(other.extraLevels, extraLevels)&&(identical(other.allowCustom, allowCustom) || other.allowCustom == allowCustom));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(enabledPresets),const DeepCollectionEquality().hash(extraLevels),allowCustom);

@override
String toString() {
  return 'SubscriptionLevels(enabledPresets: $enabledPresets, extraLevels: $extraLevels, allowCustom: $allowCustom)';
}


}

/// @nodoc
abstract mixin class $SubscriptionLevelsCopyWith<$Res>  {
  factory $SubscriptionLevelsCopyWith(SubscriptionLevels value, $Res Function(SubscriptionLevels) _then) = _$SubscriptionLevelsCopyWithImpl;
@useResult
$Res call({
 List<int> enabledPresets, List<int> extraLevels, bool allowCustom
});




}
/// @nodoc
class _$SubscriptionLevelsCopyWithImpl<$Res>
    implements $SubscriptionLevelsCopyWith<$Res> {
  _$SubscriptionLevelsCopyWithImpl(this._self, this._then);

  final SubscriptionLevels _self;
  final $Res Function(SubscriptionLevels) _then;

/// Create a copy of SubscriptionLevels
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabledPresets = null,Object? extraLevels = null,Object? allowCustom = null,}) {
  return _then(_self.copyWith(
enabledPresets: null == enabledPresets ? _self.enabledPresets : enabledPresets // ignore: cast_nullable_to_non_nullable
as List<int>,extraLevels: null == extraLevels ? _self.extraLevels : extraLevels // ignore: cast_nullable_to_non_nullable
as List<int>,allowCustom: null == allowCustom ? _self.allowCustom : allowCustom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionLevels].
extension SubscriptionLevelsPatterns on SubscriptionLevels {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionLevels value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionLevels() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionLevels value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionLevels():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionLevels value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionLevels() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int> enabledPresets,  List<int> extraLevels,  bool allowCustom)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionLevels() when $default != null:
return $default(_that.enabledPresets,_that.extraLevels,_that.allowCustom);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int> enabledPresets,  List<int> extraLevels,  bool allowCustom)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionLevels():
return $default(_that.enabledPresets,_that.extraLevels,_that.allowCustom);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int> enabledPresets,  List<int> extraLevels,  bool allowCustom)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionLevels() when $default != null:
return $default(_that.enabledPresets,_that.extraLevels,_that.allowCustom);case _:
  return null;

}
}

}

/// @nodoc


class _SubscriptionLevels extends SubscriptionLevels {
  const _SubscriptionLevels({final  List<int> enabledPresets = const [25, 50, 75, 100], final  List<int> extraLevels = const [], this.allowCustom = false}): _enabledPresets = enabledPresets,_extraLevels = extraLevels,super._();
  

 final  List<int> _enabledPresets;
@override@JsonKey() List<int> get enabledPresets {
  if (_enabledPresets is EqualUnmodifiableListView) return _enabledPresets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_enabledPresets);
}

 final  List<int> _extraLevels;
@override@JsonKey() List<int> get extraLevels {
  if (_extraLevels is EqualUnmodifiableListView) return _extraLevels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraLevels);
}

@override@JsonKey() final  bool allowCustom;

/// Create a copy of SubscriptionLevels
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionLevelsCopyWith<_SubscriptionLevels> get copyWith => __$SubscriptionLevelsCopyWithImpl<_SubscriptionLevels>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionLevels&&const DeepCollectionEquality().equals(other._enabledPresets, _enabledPresets)&&const DeepCollectionEquality().equals(other._extraLevels, _extraLevels)&&(identical(other.allowCustom, allowCustom) || other.allowCustom == allowCustom));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_enabledPresets),const DeepCollectionEquality().hash(_extraLevels),allowCustom);

@override
String toString() {
  return 'SubscriptionLevels(enabledPresets: $enabledPresets, extraLevels: $extraLevels, allowCustom: $allowCustom)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionLevelsCopyWith<$Res> implements $SubscriptionLevelsCopyWith<$Res> {
  factory _$SubscriptionLevelsCopyWith(_SubscriptionLevels value, $Res Function(_SubscriptionLevels) _then) = __$SubscriptionLevelsCopyWithImpl;
@override @useResult
$Res call({
 List<int> enabledPresets, List<int> extraLevels, bool allowCustom
});




}
/// @nodoc
class __$SubscriptionLevelsCopyWithImpl<$Res>
    implements _$SubscriptionLevelsCopyWith<$Res> {
  __$SubscriptionLevelsCopyWithImpl(this._self, this._then);

  final _SubscriptionLevels _self;
  final $Res Function(_SubscriptionLevels) _then;

/// Create a copy of SubscriptionLevels
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabledPresets = null,Object? extraLevels = null,Object? allowCustom = null,}) {
  return _then(_SubscriptionLevels(
enabledPresets: null == enabledPresets ? _self._enabledPresets : enabledPresets // ignore: cast_nullable_to_non_nullable
as List<int>,extraLevels: null == extraLevels ? _self._extraLevels : extraLevels // ignore: cast_nullable_to_non_nullable
as List<int>,allowCustom: null == allowCustom ? _self.allowCustom : allowCustom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
