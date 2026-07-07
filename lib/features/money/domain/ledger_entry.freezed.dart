// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ledger_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LedgerEntry {

 String get id; String get memberId; LedgerKind get kind; LedgerCategory get category; int get amountCents; String get description; String get period; DateTime get createdAt;
/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LedgerEntryCopyWith<LedgerEntry> get copyWith => _$LedgerEntryCopyWithImpl<LedgerEntry>(this as LedgerEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LedgerEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.description, description) || other.description == description)&&(identical(other.period, period) || other.period == period)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,memberId,kind,category,amountCents,description,period,createdAt);

@override
String toString() {
  return 'LedgerEntry(id: $id, memberId: $memberId, kind: $kind, category: $category, amountCents: $amountCents, description: $description, period: $period, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LedgerEntryCopyWith<$Res>  {
  factory $LedgerEntryCopyWith(LedgerEntry value, $Res Function(LedgerEntry) _then) = _$LedgerEntryCopyWithImpl;
@useResult
$Res call({
 String id, String memberId, LedgerKind kind, LedgerCategory category, int amountCents, String description, String period, DateTime createdAt
});




}
/// @nodoc
class _$LedgerEntryCopyWithImpl<$Res>
    implements $LedgerEntryCopyWith<$Res> {
  _$LedgerEntryCopyWithImpl(this._self, this._then);

  final LedgerEntry _self;
  final $Res Function(LedgerEntry) _then;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? memberId = null,Object? kind = null,Object? category = null,Object? amountCents = null,Object? description = null,Object? period = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LedgerKind,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LedgerCategory,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LedgerEntry].
extension LedgerEntryPatterns on LedgerEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LedgerEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LedgerEntry value)  $default,){
final _that = this;
switch (_that) {
case _LedgerEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LedgerEntry value)?  $default,){
final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String memberId,  LedgerKind kind,  LedgerCategory category,  int amountCents,  String description,  String period,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
return $default(_that.id,_that.memberId,_that.kind,_that.category,_that.amountCents,_that.description,_that.period,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String memberId,  LedgerKind kind,  LedgerCategory category,  int amountCents,  String description,  String period,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LedgerEntry():
return $default(_that.id,_that.memberId,_that.kind,_that.category,_that.amountCents,_that.description,_that.period,_that.createdAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String memberId,  LedgerKind kind,  LedgerCategory category,  int amountCents,  String description,  String period,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
return $default(_that.id,_that.memberId,_that.kind,_that.category,_that.amountCents,_that.description,_that.period,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _LedgerEntry implements LedgerEntry {
  const _LedgerEntry({required this.id, required this.memberId, required this.kind, required this.category, required this.amountCents, required this.description, required this.period, required this.createdAt});
  

@override final  String id;
@override final  String memberId;
@override final  LedgerKind kind;
@override final  LedgerCategory category;
@override final  int amountCents;
@override final  String description;
@override final  String period;
@override final  DateTime createdAt;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LedgerEntryCopyWith<_LedgerEntry> get copyWith => __$LedgerEntryCopyWithImpl<_LedgerEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LedgerEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.category, category) || other.category == category)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.description, description) || other.description == description)&&(identical(other.period, period) || other.period == period)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,memberId,kind,category,amountCents,description,period,createdAt);

@override
String toString() {
  return 'LedgerEntry(id: $id, memberId: $memberId, kind: $kind, category: $category, amountCents: $amountCents, description: $description, period: $period, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LedgerEntryCopyWith<$Res> implements $LedgerEntryCopyWith<$Res> {
  factory _$LedgerEntryCopyWith(_LedgerEntry value, $Res Function(_LedgerEntry) _then) = __$LedgerEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String memberId, LedgerKind kind, LedgerCategory category, int amountCents, String description, String period, DateTime createdAt
});




}
/// @nodoc
class __$LedgerEntryCopyWithImpl<$Res>
    implements _$LedgerEntryCopyWith<$Res> {
  __$LedgerEntryCopyWithImpl(this._self, this._then);

  final _LedgerEntry _self;
  final $Res Function(_LedgerEntry) _then;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? memberId = null,Object? kind = null,Object? category = null,Object? amountCents = null,Object? description = null,Object? period = null,Object? createdAt = null,}) {
  return _then(_LedgerEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LedgerKind,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LedgerCategory,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
