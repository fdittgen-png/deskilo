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

 String get period; int get subscriptionPct; int get feeCents; int get includedHalfDays; int get openDays; int get usedHalfDays; int get extraHalfDays; int get overageCents; int get creditsCents; int get balanceCents;/// Sum of the priced accessories of booked seats, per reserved
/// half-day (#170). 0 unless the owner enabled the
/// accessorySupplements feature — older `member_statement` bodies
/// omit the field entirely, so it defaults.
 int get accessorySupplementCents;/// What happens once the entitlement is used up (migration 0041).
 OveragePolicy get overagePolicy;/// The fee band's per-extra-half-day overage rate — what a
/// pay-as-you-go half-day beyond the entitlement costs.
 int get overageRateCents;/// Confirmed extra half-days this period (quota extensions / packages),
/// on top of [includedHalfDays].
 int get grantedHalfDays;/// Half-days still bookable within the cap
/// (included + granted − used, floored at 0).
 int get remainingHalfDays;
/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatementCopyWith<Statement> get copyWith => _$StatementCopyWithImpl<Statement>(this as Statement, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Statement&&(identical(other.period, period) || other.period == period)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.openDays, openDays) || other.openDays == openDays)&&(identical(other.usedHalfDays, usedHalfDays) || other.usedHalfDays == usedHalfDays)&&(identical(other.extraHalfDays, extraHalfDays) || other.extraHalfDays == extraHalfDays)&&(identical(other.overageCents, overageCents) || other.overageCents == overageCents)&&(identical(other.creditsCents, creditsCents) || other.creditsCents == creditsCents)&&(identical(other.balanceCents, balanceCents) || other.balanceCents == balanceCents)&&(identical(other.accessorySupplementCents, accessorySupplementCents) || other.accessorySupplementCents == accessorySupplementCents)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.overageRateCents, overageRateCents) || other.overageRateCents == overageRateCents)&&(identical(other.grantedHalfDays, grantedHalfDays) || other.grantedHalfDays == grantedHalfDays)&&(identical(other.remainingHalfDays, remainingHalfDays) || other.remainingHalfDays == remainingHalfDays));
}


@override
int get hashCode => Object.hash(runtimeType,period,subscriptionPct,feeCents,includedHalfDays,openDays,usedHalfDays,extraHalfDays,overageCents,creditsCents,balanceCents,accessorySupplementCents,overagePolicy,overageRateCents,grantedHalfDays,remainingHalfDays);

@override
String toString() {
  return 'Statement(period: $period, subscriptionPct: $subscriptionPct, feeCents: $feeCents, includedHalfDays: $includedHalfDays, openDays: $openDays, usedHalfDays: $usedHalfDays, extraHalfDays: $extraHalfDays, overageCents: $overageCents, creditsCents: $creditsCents, balanceCents: $balanceCents, accessorySupplementCents: $accessorySupplementCents, overagePolicy: $overagePolicy, overageRateCents: $overageRateCents, grantedHalfDays: $grantedHalfDays, remainingHalfDays: $remainingHalfDays)';
}


}

/// @nodoc
abstract mixin class $StatementCopyWith<$Res>  {
  factory $StatementCopyWith(Statement value, $Res Function(Statement) _then) = _$StatementCopyWithImpl;
@useResult
$Res call({
 String period, int subscriptionPct, int feeCents, int includedHalfDays, int openDays, int usedHalfDays, int extraHalfDays, int overageCents, int creditsCents, int balanceCents, int accessorySupplementCents, OveragePolicy overagePolicy, int overageRateCents, int grantedHalfDays, int remainingHalfDays
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
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? subscriptionPct = null,Object? feeCents = null,Object? includedHalfDays = null,Object? openDays = null,Object? usedHalfDays = null,Object? extraHalfDays = null,Object? overageCents = null,Object? creditsCents = null,Object? balanceCents = null,Object? accessorySupplementCents = null,Object? overagePolicy = null,Object? overageRateCents = null,Object? grantedHalfDays = null,Object? remainingHalfDays = null,}) {
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
as int,accessorySupplementCents: null == accessorySupplementCents ? _self.accessorySupplementCents : accessorySupplementCents // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,overageRateCents: null == overageRateCents ? _self.overageRateCents : overageRateCents // ignore: cast_nullable_to_non_nullable
as int,grantedHalfDays: null == grantedHalfDays ? _self.grantedHalfDays : grantedHalfDays // ignore: cast_nullable_to_non_nullable
as int,remainingHalfDays: null == remainingHalfDays ? _self.remainingHalfDays : remainingHalfDays // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents,  int accessorySupplementCents,  OveragePolicy overagePolicy,  int overageRateCents,  int grantedHalfDays,  int remainingHalfDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Statement() when $default != null:
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents,_that.accessorySupplementCents,_that.overagePolicy,_that.overageRateCents,_that.grantedHalfDays,_that.remainingHalfDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents,  int accessorySupplementCents,  OveragePolicy overagePolicy,  int overageRateCents,  int grantedHalfDays,  int remainingHalfDays)  $default,) {final _that = this;
switch (_that) {
case _Statement():
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents,_that.accessorySupplementCents,_that.overagePolicy,_that.overageRateCents,_that.grantedHalfDays,_that.remainingHalfDays);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String period,  int subscriptionPct,  int feeCents,  int includedHalfDays,  int openDays,  int usedHalfDays,  int extraHalfDays,  int overageCents,  int creditsCents,  int balanceCents,  int accessorySupplementCents,  OveragePolicy overagePolicy,  int overageRateCents,  int grantedHalfDays,  int remainingHalfDays)?  $default,) {final _that = this;
switch (_that) {
case _Statement() when $default != null:
return $default(_that.period,_that.subscriptionPct,_that.feeCents,_that.includedHalfDays,_that.openDays,_that.usedHalfDays,_that.extraHalfDays,_that.overageCents,_that.creditsCents,_that.balanceCents,_that.accessorySupplementCents,_that.overagePolicy,_that.overageRateCents,_that.grantedHalfDays,_that.remainingHalfDays);case _:
  return null;

}
}

}

/// @nodoc


class _Statement extends Statement {
  const _Statement({required this.period, required this.subscriptionPct, required this.feeCents, required this.includedHalfDays, required this.openDays, required this.usedHalfDays, required this.extraHalfDays, required this.overageCents, required this.creditsCents, required this.balanceCents, this.accessorySupplementCents = 0, this.overagePolicy = OveragePolicy.blocked, this.overageRateCents = 0, this.grantedHalfDays = 0, this.remainingHalfDays = 0}): super._();
  

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
/// Sum of the priced accessories of booked seats, per reserved
/// half-day (#170). 0 unless the owner enabled the
/// accessorySupplements feature — older `member_statement` bodies
/// omit the field entirely, so it defaults.
@override@JsonKey() final  int accessorySupplementCents;
/// What happens once the entitlement is used up (migration 0041).
@override@JsonKey() final  OveragePolicy overagePolicy;
/// The fee band's per-extra-half-day overage rate — what a
/// pay-as-you-go half-day beyond the entitlement costs.
@override@JsonKey() final  int overageRateCents;
/// Confirmed extra half-days this period (quota extensions / packages),
/// on top of [includedHalfDays].
@override@JsonKey() final  int grantedHalfDays;
/// Half-days still bookable within the cap
/// (included + granted − used, floored at 0).
@override@JsonKey() final  int remainingHalfDays;

/// Create a copy of Statement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StatementCopyWith<_Statement> get copyWith => __$StatementCopyWithImpl<_Statement>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Statement&&(identical(other.period, period) || other.period == period)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.feeCents, feeCents) || other.feeCents == feeCents)&&(identical(other.includedHalfDays, includedHalfDays) || other.includedHalfDays == includedHalfDays)&&(identical(other.openDays, openDays) || other.openDays == openDays)&&(identical(other.usedHalfDays, usedHalfDays) || other.usedHalfDays == usedHalfDays)&&(identical(other.extraHalfDays, extraHalfDays) || other.extraHalfDays == extraHalfDays)&&(identical(other.overageCents, overageCents) || other.overageCents == overageCents)&&(identical(other.creditsCents, creditsCents) || other.creditsCents == creditsCents)&&(identical(other.balanceCents, balanceCents) || other.balanceCents == balanceCents)&&(identical(other.accessorySupplementCents, accessorySupplementCents) || other.accessorySupplementCents == accessorySupplementCents)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.overageRateCents, overageRateCents) || other.overageRateCents == overageRateCents)&&(identical(other.grantedHalfDays, grantedHalfDays) || other.grantedHalfDays == grantedHalfDays)&&(identical(other.remainingHalfDays, remainingHalfDays) || other.remainingHalfDays == remainingHalfDays));
}


@override
int get hashCode => Object.hash(runtimeType,period,subscriptionPct,feeCents,includedHalfDays,openDays,usedHalfDays,extraHalfDays,overageCents,creditsCents,balanceCents,accessorySupplementCents,overagePolicy,overageRateCents,grantedHalfDays,remainingHalfDays);

@override
String toString() {
  return 'Statement(period: $period, subscriptionPct: $subscriptionPct, feeCents: $feeCents, includedHalfDays: $includedHalfDays, openDays: $openDays, usedHalfDays: $usedHalfDays, extraHalfDays: $extraHalfDays, overageCents: $overageCents, creditsCents: $creditsCents, balanceCents: $balanceCents, accessorySupplementCents: $accessorySupplementCents, overagePolicy: $overagePolicy, overageRateCents: $overageRateCents, grantedHalfDays: $grantedHalfDays, remainingHalfDays: $remainingHalfDays)';
}


}

/// @nodoc
abstract mixin class _$StatementCopyWith<$Res> implements $StatementCopyWith<$Res> {
  factory _$StatementCopyWith(_Statement value, $Res Function(_Statement) _then) = __$StatementCopyWithImpl;
@override @useResult
$Res call({
 String period, int subscriptionPct, int feeCents, int includedHalfDays, int openDays, int usedHalfDays, int extraHalfDays, int overageCents, int creditsCents, int balanceCents, int accessorySupplementCents, OveragePolicy overagePolicy, int overageRateCents, int grantedHalfDays, int remainingHalfDays
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
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? subscriptionPct = null,Object? feeCents = null,Object? includedHalfDays = null,Object? openDays = null,Object? usedHalfDays = null,Object? extraHalfDays = null,Object? overageCents = null,Object? creditsCents = null,Object? balanceCents = null,Object? accessorySupplementCents = null,Object? overagePolicy = null,Object? overageRateCents = null,Object? grantedHalfDays = null,Object? remainingHalfDays = null,}) {
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
as int,accessorySupplementCents: null == accessorySupplementCents ? _self.accessorySupplementCents : accessorySupplementCents // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,overageRateCents: null == overageRateCents ? _self.overageRateCents : overageRateCents // ignore: cast_nullable_to_non_nullable
as int,grantedHalfDays: null == grantedHalfDays ? _self.grantedHalfDays : grantedHalfDays // ignore: cast_nullable_to_non_nullable
as int,remainingHalfDays: null == remainingHalfDays ? _self.remainingHalfDays : remainingHalfDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
