// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'statement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Statement {

 String get period; int get subscriptionPct; int get feeCents; int get includedHalfDays; int get openDays; int get usedHalfDays; int get extraHalfDays; int get overageCents; int get creditsCents; int get balanceCents;
/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatementCopyWith<Statement> get copyWith => _$StatementCopyWithImpl<Statement>(this as Statement, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Statement&&(identical(other.period, period) || other.period == period)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.openDays, openDays) || other.openDays == openDays)&&(identical(other.usedHalfDays, usedHalfDays) || other.usedHalfDays == usedHalfDays)&&(identical(other.extraHalfDays, extraHalfDays) || other.extraHalfDays == extraHalfDays)&&(identical(other.overageCents, overageCents) || other.overageCents == overageCents)&&(identical(other.creditsCents, creditsCents) || other.creditsCents == creditsCents)&&(identical(other.balanceCents, balanceCents) || other.balanceCents == balanceCents));
}


@override
int get hashCode => Object.hash(runtimeType,period,subscriptionPct,feeCents,includedHalfDays,openDays,usedHalfDays,extraHalfDays,overageCents,creditsCents,balanceCents);

@override
String toString() {
  return 'Statement(period: $period, subscriptionPct: $subscriptionPct, feeCents: $feeCents, includedHalfDays: $includedHalfDays, openDays: $openDays, usedHalfDays: $usedHalfDays, extraHalfDays: $extraHalfDays, overageCents: $overageCents, creditsCents: $creditsCents, balanceCents: $balanceCents)';
}


}

/// @nodoc
abstract mixin class $StatementCopyWith<$Res>  {
  factory $StatementCopyWith(Statement value, $Res Function(Statement) _then) = _$StatementCopyWithImpl;
@useResult
$Res call({
 String period, int subscriptionPct, int feeCents, int includedHalfDays, int openDays, int usedHalfDays, int extraHalfDays, int overageCents, int creditsCents, int balanceCents
});




}
/// @nodoc
class _$StatementCopyWithImpl<$Res>
    implements $StatementCopyWith<$Res> {
  _$StatementCopyWithImpl(this._self, this._then);

  final Statement _self;
  final $Res Function(Statement) _then;

/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? subscriptionPct = null,Object? feeCents = null,Object? includedHalfDays = null,Object? openDays = null,Object? usedHalfDays = null,Object? extraHalfDays = null,Object? overageCents = null,Object? creditsCents = null,Object? balanceCents = null,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,feeCents: null == feeCents ? _self.feeCents : feeCents // ignore: cast_nullable_to_non_nullable
as int,includedHalfDays: null == includedHalfDays ? _self.includedHalfDays : includedHalfDays // ignore: cast_nullable_to_non_nullable
as int,openDays: null == openDays ? _self.openDays : openDays // ignore: cast_nullable_to_non_nullable
as int,usedHalfDays: null == usedHalfDays ? _self.usedHalfDays : usedHalfDays // ignore: cast_nullable_to_non_nullable
as int,extraHalfDays: null == extraHalfDays ? _self.extraHalfDays : extraHalfDays // ignore: cast_nullable_to_non_nullable
as int,overageCents: null == overageCents ? _self.overageCents : overageCents // ignore: cast_nullable_to_non_nullable
as int,creditsCents: null == creditsCents ? _self.creditsCents : creditsCents // ignore: cast_nullable_to_non_nullable
as int,balanceCents: null == balanceCents ? _self.balanceCents : balanceCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Statement].
extension StatementPatterns on Statement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Statement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Statement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Statement value)  $default,){
final _that = this;
switch (_that) {
case _Statement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Statement value)?  $default,){
final _that = this;
switch (_that) {
case _Statement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Statement() when $default != null:
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents)  $default,) {final _that = this;
switch (_that) {
case _Statement():
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents)?  $default,) {final _that = this;
switch (_that) {
case _Statement() when $default != null:
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents);case _:
  return null;

}
}

}

/// @nodoc


class _Statement extends Statement {
  const _Statement({required this.period, required this.subscriptionPct, required this.feeCents, required this.includedHalfDays, required this.openDays, required this.usedHalfDays, required this.extraHalfDays, required this.overageCents, required this.creditsCents, required this.balanceCents}): super._();
  

@override final  String period;
@override final  int subscriptionPct;
@override final  int feeCents;
@override final  int includedHalfDays;
@override final  int openDays;
@override final  int usedHalfDays;
@override final  int extraHalfDays;
@override final  int overageCents;
@override final  int creditsCents;
@override final  int balanceCents;

/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StatementCopyWith<_Statement> get copyWith => __$StatementCopyWithImpl<_Statement>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Statement&&(identical(other.period, period) || other.period == period)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.openDays, openDays) || other.openDays == openDays)&&(identical(other.usedHalfDays, usedHalfDays) || other.usedHalfDays == usedHalfDays)&&(identical(other.extraHalfDays, extraHalfDays) || other.extraHalfDays == extraHalfDays)&&(identical(other.overageCents, overageCents) || other.overageCents == overageCents)&&(identical(other.creditsCents, creditsCents) || other.creditsCents == creditsCents)&&(identical(other.balanceCents, balanceCents) || other.balanceCents == balanceCents));
}


@override
int get hashCode => Object.hash(runtimeType,period,subscriptionPct,feeCents,includedHalfDays,openDays,usedHalfDays,extraHalfDays,overageCents,creditsCents,balanceCents);

@override
String toString() {
  return 'Statement(period: $period, subscriptionPct: $subscriptionPct, feeCents: $feeCents, includedHalfDays: $includedHalfDays, openDays: $openDays, usedHalfDays: $usedHalfDays, extraHalfDays: $extraHalfDays, overageCents: $overageCents, creditsCents: $creditsCents, balanceCents: $balanceCents)';
}


}

/// @nodoc
abstract mixin class _$StatementCopyWith<$Res> implements $StatementCopyWith<$Res> {
  factory _$StatementCopyWith(_Statement value, $Res Function(_Statement) _then) = __$StatementCopyWithImpl;
@override @useResult
$Res call({
 String period, int subscriptionPct, int feeCents, int includedHalfDays, int openDays, int usedHalfDays, int extraHalfDays, int overageCents, int creditsCents, int balanceCents
});




}
/// @nodoc
class __$StatementCopyWithImpl<$Res>
    implements _$StatementCopyWith<$Res> {
  __$StatementCopyWithImpl(this._self, this._then);

  final _Statement _self;
  final $Res Function(_Statement) _then;

/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? subscriptionPct = null,Object? feeCents = null,Object? includedHalfDays = null,Object? openDays = null,Object? usedHalfDays = null,Object? extraHalfDays = null,Object? overageCents = null,Object? creditsCents = null,Object? balanceCents = null,}) {
  return _then(_Statement(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,feeCents: null == feeCents ? _self.feeCents : feeCents // ignore: cast_nullable_to_non_nullable
as int,includedHalfDays: null == includedHalfDays ? _self.includedHalfDays : includedHalfDays // ignore: cast_nullable_to_non_nullable
as int,openDays: null == openDays ? _self.openDays : openDays // ignore: cast_nullable_to_non_nullable
as int,usedHalfDays: null == usedHalfDays ? _self.usedHalfDays : usedHalfDays // ignore: cast_nullable_to_non_nullable
as int,extraHalfDays: null == extraHalfDays ? _self.extraHalfDays : extraHalfDays // ignore: cast_nullable_to_non_nullable
as int,overageCents: null == overageCents ? _self.overageCents : overageCents // ignore: cast_nullable_to_non_nullable
as int,creditsCents: null == creditsCents ? _self.creditsCents : creditsCents // ignore: cast_nullable_to_non_nullable
as int,balanceCents: null == balanceCents ? _self.balanceCents : balanceCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
