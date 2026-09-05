// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InvoiceLine {

 String get kind; String get label; int get quantity; int get amountCents;/// The VAT rate this position was taxed at (0072). Prices are
/// INCLUSIVE, so [amountCents] is the gross and the tax is extracted
/// from it with `vatSplit`. 0 = no VAT (every pre-0072 line, and every
/// credit — money moving is not a supply).
 double get vatPercent;/// #831 — on a settlement, the number of the source invoice this
/// position was carried over from; '' on every other document.
 String get sourceNumber;
/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceLineCopyWith<InvoiceLine> get copyWith => _$InvoiceLineCopyWithImpl<InvoiceLine>(this as InvoiceLine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.vatPercent, vatPercent) || other.vatPercent == vatPercent)&&(identical(other.sourceNumber, sourceNumber) || other.sourceNumber == sourceNumber));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,quantity,amountCents,vatPercent,sourceNumber);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, label: $label, quantity: $quantity, amountCents: $amountCents, vatPercent: $vatPercent, sourceNumber: $sourceNumber)';
}


}

/// @nodoc
abstract mixin class $InvoiceLineCopyWith<$Res>  {
  factory $InvoiceLineCopyWith(InvoiceLine value, $Res Function(InvoiceLine) _then) = _$InvoiceLineCopyWithImpl;
@useResult
$Res call({
 String kind, String label, int quantity, int amountCents, double vatPercent, String sourceNumber
});




}
/// @nodoc
class _$InvoiceLineCopyWithImpl<$Res>
    implements $InvoiceLineCopyWith<$Res> {
  _$InvoiceLineCopyWithImpl(this._self, this._then);

  final InvoiceLine _self;
  final $Res Function(InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? label = null,Object? quantity = null,Object? amountCents = null,Object? vatPercent = null,Object? sourceNumber = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,vatPercent: null == vatPercent ? _self.vatPercent : vatPercent // ignore: cast_nullable_to_non_nullable
as double,sourceNumber: null == sourceNumber ? _self.sourceNumber : sourceNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceLine].
extension InvoiceLinePatterns on InvoiceLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceLine value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceLine value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String label,  int quantity,  int amountCents,  double vatPercent,  String sourceNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents,_that.vatPercent,_that.sourceNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String label,  int quantity,  int amountCents,  double vatPercent,  String sourceNumber)  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine():
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents,_that.vatPercent,_that.sourceNumber);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String label,  int quantity,  int amountCents,  double vatPercent,  String sourceNumber)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents,_that.vatPercent,_that.sourceNumber);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceLine implements InvoiceLine {
  const _InvoiceLine({this.kind = '', required this.label, this.quantity = 1, required this.amountCents, this.vatPercent = 0.0, this.sourceNumber = ''});
  

@override@JsonKey() final  String kind;
@override final  String label;
@override@JsonKey() final  int quantity;
@override final  int amountCents;
/// The VAT rate this position was taxed at (0072). Prices are
/// INCLUSIVE, so [amountCents] is the gross and the tax is extracted
/// from it with `vatSplit`. 0 = no VAT (every pre-0072 line, and every
/// credit — money moving is not a supply).
@override@JsonKey() final  double vatPercent;
/// #831 — on a settlement, the number of the source invoice this
/// position was carried over from; '' on every other document.
@override@JsonKey() final  String sourceNumber;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceLineCopyWith<_InvoiceLine> get copyWith => __$InvoiceLineCopyWithImpl<_InvoiceLine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.vatPercent, vatPercent) || other.vatPercent == vatPercent)&&(identical(other.sourceNumber, sourceNumber) || other.sourceNumber == sourceNumber));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,quantity,amountCents,vatPercent,sourceNumber);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, label: $label, quantity: $quantity, amountCents: $amountCents, vatPercent: $vatPercent, sourceNumber: $sourceNumber)';
}


}

/// @nodoc
abstract mixin class _$InvoiceLineCopyWith<$Res> implements $InvoiceLineCopyWith<$Res> {
  factory _$InvoiceLineCopyWith(_InvoiceLine value, $Res Function(_InvoiceLine) _then) = __$InvoiceLineCopyWithImpl;
@override @useResult
$Res call({
 String kind, String label, int quantity, int amountCents, double vatPercent, String sourceNumber
});




}
/// @nodoc
class __$InvoiceLineCopyWithImpl<$Res>
    implements _$InvoiceLineCopyWith<$Res> {
  __$InvoiceLineCopyWithImpl(this._self, this._then);

  final _InvoiceLine _self;
  final $Res Function(_InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? label = null,Object? quantity = null,Object? amountCents = null,Object? vatPercent = null,Object? sourceNumber = null,}) {
  return _then(_InvoiceLine(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,vatPercent: null == vatPercent ? _self.vatPercent : vatPercent // ignore: cast_nullable_to_non_nullable
as double,sourceNumber: null == sourceNumber ? _self.sourceNumber : sourceNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$InvoiceDetailEntry {

 String get on; String get category; String get label; int get amountCents;
/// Create a copy of InvoiceDetailEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceDetailEntryCopyWith<InvoiceDetailEntry> get copyWith => _$InvoiceDetailEntryCopyWithImpl<InvoiceDetailEntry>(this as InvoiceDetailEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceDetailEntry&&(identical(other.on, on) || other.on == on)&&(identical(other.category, category) || other.category == category)&&(identical(other.label, label) || other.label == label)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}


@override
int get hashCode => Object.hash(runtimeType,on,category,label,amountCents);

@override
String toString() {
  return 'InvoiceDetailEntry(on: $on, category: $category, label: $label, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class $InvoiceDetailEntryCopyWith<$Res>  {
  factory $InvoiceDetailEntryCopyWith(InvoiceDetailEntry value, $Res Function(InvoiceDetailEntry) _then) = _$InvoiceDetailEntryCopyWithImpl;
@useResult
$Res call({
 String on, String category, String label, int amountCents
});




}
/// @nodoc
class _$InvoiceDetailEntryCopyWithImpl<$Res>
    implements $InvoiceDetailEntryCopyWith<$Res> {
  _$InvoiceDetailEntryCopyWithImpl(this._self, this._then);

  final InvoiceDetailEntry _self;
  final $Res Function(InvoiceDetailEntry) _then;

/// Create a copy of InvoiceDetailEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? on = null,Object? category = null,Object? label = null,Object? amountCents = null,}) {
  return _then(_self.copyWith(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceDetailEntry].
extension InvoiceDetailEntryPatterns on InvoiceDetailEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceDetailEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceDetailEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceDetailEntry value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceDetailEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceDetailEntry value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceDetailEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String on,  String category,  String label,  int amountCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceDetailEntry() when $default != null:
return $default(_that.on,_that.category,_that.label,_that.amountCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String on,  String category,  String label,  int amountCents)  $default,) {final _that = this;
switch (_that) {
case _InvoiceDetailEntry():
return $default(_that.on,_that.category,_that.label,_that.amountCents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String on,  String category,  String label,  int amountCents)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceDetailEntry() when $default != null:
return $default(_that.on,_that.category,_that.label,_that.amountCents);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceDetailEntry implements InvoiceDetailEntry {
  const _InvoiceDetailEntry({required this.on, required this.category, this.label = '', required this.amountCents});
  

@override final  String on;
@override final  String category;
@override@JsonKey() final  String label;
@override final  int amountCents;

/// Create a copy of InvoiceDetailEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceDetailEntryCopyWith<_InvoiceDetailEntry> get copyWith => __$InvoiceDetailEntryCopyWithImpl<_InvoiceDetailEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceDetailEntry&&(identical(other.on, on) || other.on == on)&&(identical(other.category, category) || other.category == category)&&(identical(other.label, label) || other.label == label)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}


@override
int get hashCode => Object.hash(runtimeType,on,category,label,amountCents);

@override
String toString() {
  return 'InvoiceDetailEntry(on: $on, category: $category, label: $label, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class _$InvoiceDetailEntryCopyWith<$Res> implements $InvoiceDetailEntryCopyWith<$Res> {
  factory _$InvoiceDetailEntryCopyWith(_InvoiceDetailEntry value, $Res Function(_InvoiceDetailEntry) _then) = __$InvoiceDetailEntryCopyWithImpl;
@override @useResult
$Res call({
 String on, String category, String label, int amountCents
});




}
/// @nodoc
class __$InvoiceDetailEntryCopyWithImpl<$Res>
    implements _$InvoiceDetailEntryCopyWith<$Res> {
  __$InvoiceDetailEntryCopyWithImpl(this._self, this._then);

  final _InvoiceDetailEntry _self;
  final $Res Function(_InvoiceDetailEntry) _then;

/// Create a copy of InvoiceDetailEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? on = null,Object? category = null,Object? label = null,Object? amountCents = null,}) {
  return _then(_InvoiceDetailEntry(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$InvoiceAttendance {

 String get startsAt; String get endsAt; String get space; String get status;
/// Create a copy of InvoiceAttendance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceAttendanceCopyWith<InvoiceAttendance> get copyWith => _$InvoiceAttendanceCopyWithImpl<InvoiceAttendance>(this as InvoiceAttendance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceAttendance&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.space, space) || other.space == space)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,startsAt,endsAt,space,status);

@override
String toString() {
  return 'InvoiceAttendance(startsAt: $startsAt, endsAt: $endsAt, space: $space, status: $status)';
}


}

/// @nodoc
abstract mixin class $InvoiceAttendanceCopyWith<$Res>  {
  factory $InvoiceAttendanceCopyWith(InvoiceAttendance value, $Res Function(InvoiceAttendance) _then) = _$InvoiceAttendanceCopyWithImpl;
@useResult
$Res call({
 String startsAt, String endsAt, String space, String status
});




}
/// @nodoc
class _$InvoiceAttendanceCopyWithImpl<$Res>
    implements $InvoiceAttendanceCopyWith<$Res> {
  _$InvoiceAttendanceCopyWithImpl(this._self, this._then);

  final InvoiceAttendance _self;
  final $Res Function(InvoiceAttendance) _then;

/// Create a copy of InvoiceAttendance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startsAt = null,Object? endsAt = null,Object? space = null,Object? status = null,}) {
  return _then(_self.copyWith(
startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as String,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as String,space: null == space ? _self.space : space // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceAttendance].
extension InvoiceAttendancePatterns on InvoiceAttendance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceAttendance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceAttendance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceAttendance value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceAttendance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceAttendance value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceAttendance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String startsAt,  String endsAt,  String space,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceAttendance() when $default != null:
return $default(_that.startsAt,_that.endsAt,_that.space,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String startsAt,  String endsAt,  String space,  String status)  $default,) {final _that = this;
switch (_that) {
case _InvoiceAttendance():
return $default(_that.startsAt,_that.endsAt,_that.space,_that.status);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String startsAt,  String endsAt,  String space,  String status)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceAttendance() when $default != null:
return $default(_that.startsAt,_that.endsAt,_that.space,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceAttendance implements InvoiceAttendance {
  const _InvoiceAttendance({required this.startsAt, required this.endsAt, this.space = '', this.status = ''});
  

@override final  String startsAt;
@override final  String endsAt;
@override@JsonKey() final  String space;
@override@JsonKey() final  String status;

/// Create a copy of InvoiceAttendance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceAttendanceCopyWith<_InvoiceAttendance> get copyWith => __$InvoiceAttendanceCopyWithImpl<_InvoiceAttendance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceAttendance&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.space, space) || other.space == space)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,startsAt,endsAt,space,status);

@override
String toString() {
  return 'InvoiceAttendance(startsAt: $startsAt, endsAt: $endsAt, space: $space, status: $status)';
}


}

/// @nodoc
abstract mixin class _$InvoiceAttendanceCopyWith<$Res> implements $InvoiceAttendanceCopyWith<$Res> {
  factory _$InvoiceAttendanceCopyWith(_InvoiceAttendance value, $Res Function(_InvoiceAttendance) _then) = __$InvoiceAttendanceCopyWithImpl;
@override @useResult
$Res call({
 String startsAt, String endsAt, String space, String status
});




}
/// @nodoc
class __$InvoiceAttendanceCopyWithImpl<$Res>
    implements _$InvoiceAttendanceCopyWith<$Res> {
  __$InvoiceAttendanceCopyWithImpl(this._self, this._then);

  final _InvoiceAttendance _self;
  final $Res Function(_InvoiceAttendance) _then;

/// Create a copy of InvoiceAttendance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startsAt = null,Object? endsAt = null,Object? space = null,Object? status = null,}) {
  return _then(_InvoiceAttendance(
startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as String,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as String,space: null == space ? _self.space : space // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$InvoiceMatch {

 String get invoiceId; int get paidCents; String get resolution; String get note; String get status;// 0068 — the REGISTERED payment this match consumed.
 String? get paymentLedgerId; DateTime get matchedAt; String get byName;/// #504 — when the outstanding remainder of an under-paid match was
/// written off through the validation framework. Null = the
/// invoice is STILL OPEN and owed.
 DateTime? get writeoffAt;/// #841 — the event that had to be validated before this match
/// stood. Null on matches recorded before the column was read, and
/// on the ones no rule ever governed.
 String? get eventId;
/// Create a copy of InvoiceMatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceMatchCopyWith<InvoiceMatch> get copyWith => _$InvoiceMatchCopyWithImpl<InvoiceMatch>(this as InvoiceMatch, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceMatch&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.paidCents, paidCents) || other.paidCents == paidCents)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.note, note) || other.note == note)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentLedgerId, paymentLedgerId) || other.paymentLedgerId == paymentLedgerId)&&(identical(other.matchedAt, matchedAt) || other.matchedAt == matchedAt)&&(identical(other.byName, byName) || other.byName == byName)&&(identical(other.writeoffAt, writeoffAt) || other.writeoffAt == writeoffAt)&&(identical(other.eventId, eventId) || other.eventId == eventId));
}


@override
int get hashCode => Object.hash(runtimeType,invoiceId,paidCents,resolution,note,status,paymentLedgerId,matchedAt,byName,writeoffAt,eventId);

@override
String toString() {
  return 'InvoiceMatch(invoiceId: $invoiceId, paidCents: $paidCents, resolution: $resolution, note: $note, status: $status, paymentLedgerId: $paymentLedgerId, matchedAt: $matchedAt, byName: $byName, writeoffAt: $writeoffAt, eventId: $eventId)';
}


}

/// @nodoc
abstract mixin class $InvoiceMatchCopyWith<$Res>  {
  factory $InvoiceMatchCopyWith(InvoiceMatch value, $Res Function(InvoiceMatch) _then) = _$InvoiceMatchCopyWithImpl;
@useResult
$Res call({
 String invoiceId, int paidCents, String resolution, String note, String status, String? paymentLedgerId, DateTime matchedAt, String byName, DateTime? writeoffAt, String? eventId
});




}
/// @nodoc
class _$InvoiceMatchCopyWithImpl<$Res>
    implements $InvoiceMatchCopyWith<$Res> {
  _$InvoiceMatchCopyWithImpl(this._self, this._then);

  final InvoiceMatch _self;
  final $Res Function(InvoiceMatch) _then;

/// Create a copy of InvoiceMatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? invoiceId = null,Object? paidCents = null,Object? resolution = null,Object? note = null,Object? status = null,Object? paymentLedgerId = freezed,Object? matchedAt = null,Object? byName = null,Object? writeoffAt = freezed,Object? eventId = freezed,}) {
  return _then(_self.copyWith(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,paidCents: null == paidCents ? _self.paidCents : paidCents // ignore: cast_nullable_to_non_nullable
as int,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,paymentLedgerId: freezed == paymentLedgerId ? _self.paymentLedgerId : paymentLedgerId // ignore: cast_nullable_to_non_nullable
as String?,matchedAt: null == matchedAt ? _self.matchedAt : matchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,byName: null == byName ? _self.byName : byName // ignore: cast_nullable_to_non_nullable
as String,writeoffAt: freezed == writeoffAt ? _self.writeoffAt : writeoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceMatch].
extension InvoiceMatchPatterns on InvoiceMatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceMatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceMatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceMatch value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceMatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceMatch value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceMatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String invoiceId,  int paidCents,  String resolution,  String note,  String status,  String? paymentLedgerId,  DateTime matchedAt,  String byName,  DateTime? writeoffAt,  String? eventId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceMatch() when $default != null:
return $default(_that.invoiceId,_that.paidCents,_that.resolution,_that.note,_that.status,_that.paymentLedgerId,_that.matchedAt,_that.byName,_that.writeoffAt,_that.eventId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String invoiceId,  int paidCents,  String resolution,  String note,  String status,  String? paymentLedgerId,  DateTime matchedAt,  String byName,  DateTime? writeoffAt,  String? eventId)  $default,) {final _that = this;
switch (_that) {
case _InvoiceMatch():
return $default(_that.invoiceId,_that.paidCents,_that.resolution,_that.note,_that.status,_that.paymentLedgerId,_that.matchedAt,_that.byName,_that.writeoffAt,_that.eventId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String invoiceId,  int paidCents,  String resolution,  String note,  String status,  String? paymentLedgerId,  DateTime matchedAt,  String byName,  DateTime? writeoffAt,  String? eventId)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceMatch() when $default != null:
return $default(_that.invoiceId,_that.paidCents,_that.resolution,_that.note,_that.status,_that.paymentLedgerId,_that.matchedAt,_that.byName,_that.writeoffAt,_that.eventId);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceMatch extends InvoiceMatch {
  const _InvoiceMatch({required this.invoiceId, required this.paidCents, required this.resolution, this.note = '', this.status = 'confirmed', this.paymentLedgerId, required this.matchedAt, this.byName = '', this.writeoffAt, this.eventId}): super._();
  

@override final  String invoiceId;
@override final  int paidCents;
@override final  String resolution;
@override@JsonKey() final  String note;
@override@JsonKey() final  String status;
// 0068 — the REGISTERED payment this match consumed.
@override final  String? paymentLedgerId;
@override final  DateTime matchedAt;
@override@JsonKey() final  String byName;
/// #504 — when the outstanding remainder of an under-paid match was
/// written off through the validation framework. Null = the
/// invoice is STILL OPEN and owed.
@override final  DateTime? writeoffAt;
/// #841 — the event that had to be validated before this match
/// stood. Null on matches recorded before the column was read, and
/// on the ones no rule ever governed.
@override final  String? eventId;

/// Create a copy of InvoiceMatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceMatchCopyWith<_InvoiceMatch> get copyWith => __$InvoiceMatchCopyWithImpl<_InvoiceMatch>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceMatch&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.paidCents, paidCents) || other.paidCents == paidCents)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.note, note) || other.note == note)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentLedgerId, paymentLedgerId) || other.paymentLedgerId == paymentLedgerId)&&(identical(other.matchedAt, matchedAt) || other.matchedAt == matchedAt)&&(identical(other.byName, byName) || other.byName == byName)&&(identical(other.writeoffAt, writeoffAt) || other.writeoffAt == writeoffAt)&&(identical(other.eventId, eventId) || other.eventId == eventId));
}


@override
int get hashCode => Object.hash(runtimeType,invoiceId,paidCents,resolution,note,status,paymentLedgerId,matchedAt,byName,writeoffAt,eventId);

@override
String toString() {
  return 'InvoiceMatch(invoiceId: $invoiceId, paidCents: $paidCents, resolution: $resolution, note: $note, status: $status, paymentLedgerId: $paymentLedgerId, matchedAt: $matchedAt, byName: $byName, writeoffAt: $writeoffAt, eventId: $eventId)';
}


}

/// @nodoc
abstract mixin class _$InvoiceMatchCopyWith<$Res> implements $InvoiceMatchCopyWith<$Res> {
  factory _$InvoiceMatchCopyWith(_InvoiceMatch value, $Res Function(_InvoiceMatch) _then) = __$InvoiceMatchCopyWithImpl;
@override @useResult
$Res call({
 String invoiceId, int paidCents, String resolution, String note, String status, String? paymentLedgerId, DateTime matchedAt, String byName, DateTime? writeoffAt, String? eventId
});




}
/// @nodoc
class __$InvoiceMatchCopyWithImpl<$Res>
    implements _$InvoiceMatchCopyWith<$Res> {
  __$InvoiceMatchCopyWithImpl(this._self, this._then);

  final _InvoiceMatch _self;
  final $Res Function(_InvoiceMatch) _then;

/// Create a copy of InvoiceMatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? invoiceId = null,Object? paidCents = null,Object? resolution = null,Object? note = null,Object? status = null,Object? paymentLedgerId = freezed,Object? matchedAt = null,Object? byName = null,Object? writeoffAt = freezed,Object? eventId = freezed,}) {
  return _then(_InvoiceMatch(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,paidCents: null == paidCents ? _self.paidCents : paidCents // ignore: cast_nullable_to_non_nullable
as int,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,paymentLedgerId: freezed == paymentLedgerId ? _self.paymentLedgerId : paymentLedgerId // ignore: cast_nullable_to_non_nullable
as String?,matchedAt: null == matchedAt ? _self.matchedAt : matchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,byName: null == byName ? _self.byName : byName // ignore: cast_nullable_to_non_nullable
as String,writeoffAt: freezed == writeoffAt ? _self.writeoffAt : writeoffAt // ignore: cast_nullable_to_non_nullable
as DateTime?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$InvoiceParty {

 String get name;/// #886 — the organisation the person is invoiced through (BT-45,
/// the buyer's trading name); '' for a private person.
 String get company;/// #912 — the title the client asked to be addressed by, as a code;
/// each reader prints it in its own language.
 String get courtesy;/// #912 — the PERSON inside the organisation, when [name] is the
/// company. Frozen apart so the block can name them under it.
 String get person;/// BT-35 — one line; legacy free-text addresses land here whole.
 String get street;/// BT-37.
 String get city;/// BT-38.
 String get postalCode;/// BT-40 / BT-55 — ISO 3166-1 alpha-2, mandatory on both parties.
 String get country;/// BT-31 (seller) / BT-48 (buyer).
 String get vatId;/// BT-30, the company register number — the seller identifier a
/// category-O invoice is allowed to carry.
 String get legalId;/// Wire value of [VatRegime]; seller only.
 String get vatRegime;/// Free-text exemption reason (BT-120); seller only.
 String get taxExemptionReason;/// #886 — the contact the document is sent to (BT-43 / BT-42).
 String get email; String get phone;
/// Create a copy of InvoiceParty
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoicePartyCopyWith<InvoiceParty> get copyWith => _$InvoicePartyCopyWithImpl<InvoiceParty>(this as InvoiceParty, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceParty&&(identical(other.name, name) || other.name == name)&&(identical(other.company, company) || other.company == company)&&(identical(other.courtesy, courtesy) || other.courtesy == courtesy)&&(identical(other.person, person) || other.person == person)&&(identical(other.street, street) || other.street == street)&&(identical(other.city, city) || other.city == city)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.country, country) || other.country == country)&&(identical(other.vatId, vatId) || other.vatId == vatId)&&(identical(other.legalId, legalId) || other.legalId == legalId)&&(identical(other.vatRegime, vatRegime) || other.vatRegime == vatRegime)&&(identical(other.taxExemptionReason, taxExemptionReason) || other.taxExemptionReason == taxExemptionReason)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode => Object.hash(runtimeType,name,company,courtesy,person,street,city,postalCode,country,vatId,legalId,vatRegime,taxExemptionReason,email,phone);

@override
String toString() {
  return 'InvoiceParty(name: $name, company: $company, courtesy: $courtesy, person: $person, street: $street, city: $city, postalCode: $postalCode, country: $country, vatId: $vatId, legalId: $legalId, vatRegime: $vatRegime, taxExemptionReason: $taxExemptionReason, email: $email, phone: $phone)';
}


}

/// @nodoc
abstract mixin class $InvoicePartyCopyWith<$Res>  {
  factory $InvoicePartyCopyWith(InvoiceParty value, $Res Function(InvoiceParty) _then) = _$InvoicePartyCopyWithImpl;
@useResult
$Res call({
 String name, String company, String courtesy, String person, String street, String city, String postalCode, String country, String vatId, String legalId, String vatRegime, String taxExemptionReason, String email, String phone
});




}
/// @nodoc
class _$InvoicePartyCopyWithImpl<$Res>
    implements $InvoicePartyCopyWith<$Res> {
  _$InvoicePartyCopyWithImpl(this._self, this._then);

  final InvoiceParty _self;
  final $Res Function(InvoiceParty) _then;

/// Create a copy of InvoiceParty
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? company = null,Object? courtesy = null,Object? person = null,Object? street = null,Object? city = null,Object? postalCode = null,Object? country = null,Object? vatId = null,Object? legalId = null,Object? vatRegime = null,Object? taxExemptionReason = null,Object? email = null,Object? phone = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as String,courtesy: null == courtesy ? _self.courtesy : courtesy // ignore: cast_nullable_to_non_nullable
as String,person: null == person ? _self.person : person // ignore: cast_nullable_to_non_nullable
as String,street: null == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,vatId: null == vatId ? _self.vatId : vatId // ignore: cast_nullable_to_non_nullable
as String,legalId: null == legalId ? _self.legalId : legalId // ignore: cast_nullable_to_non_nullable
as String,vatRegime: null == vatRegime ? _self.vatRegime : vatRegime // ignore: cast_nullable_to_non_nullable
as String,taxExemptionReason: null == taxExemptionReason ? _self.taxExemptionReason : taxExemptionReason // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceParty].
extension InvoicePartyPatterns on InvoiceParty {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceParty value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceParty() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceParty value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceParty():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceParty value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceParty() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String company,  String courtesy,  String person,  String street,  String city,  String postalCode,  String country,  String vatId,  String legalId,  String vatRegime,  String taxExemptionReason,  String email,  String phone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceParty() when $default != null:
return $default(_that.name,_that.company,_that.courtesy,_that.person,_that.street,_that.city,_that.postalCode,_that.country,_that.vatId,_that.legalId,_that.vatRegime,_that.taxExemptionReason,_that.email,_that.phone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String company,  String courtesy,  String person,  String street,  String city,  String postalCode,  String country,  String vatId,  String legalId,  String vatRegime,  String taxExemptionReason,  String email,  String phone)  $default,) {final _that = this;
switch (_that) {
case _InvoiceParty():
return $default(_that.name,_that.company,_that.courtesy,_that.person,_that.street,_that.city,_that.postalCode,_that.country,_that.vatId,_that.legalId,_that.vatRegime,_that.taxExemptionReason,_that.email,_that.phone);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String company,  String courtesy,  String person,  String street,  String city,  String postalCode,  String country,  String vatId,  String legalId,  String vatRegime,  String taxExemptionReason,  String email,  String phone)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceParty() when $default != null:
return $default(_that.name,_that.company,_that.courtesy,_that.person,_that.street,_that.city,_that.postalCode,_that.country,_that.vatId,_that.legalId,_that.vatRegime,_that.taxExemptionReason,_that.email,_that.phone);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceParty implements InvoiceParty {
  const _InvoiceParty({this.name = '', this.company = '', this.courtesy = '', this.person = '', this.street = '', this.city = '', this.postalCode = '', this.country = '', this.vatId = '', this.legalId = '', this.vatRegime = 'not_subject', this.taxExemptionReason = '', this.email = '', this.phone = ''});
  

@override@JsonKey() final  String name;
/// #886 — the organisation the person is invoiced through (BT-45,
/// the buyer's trading name); '' for a private person.
@override@JsonKey() final  String company;
/// #912 — the title the client asked to be addressed by, as a code;
/// each reader prints it in its own language.
@override@JsonKey() final  String courtesy;
/// #912 — the PERSON inside the organisation, when [name] is the
/// company. Frozen apart so the block can name them under it.
@override@JsonKey() final  String person;
/// BT-35 — one line; legacy free-text addresses land here whole.
@override@JsonKey() final  String street;
/// BT-37.
@override@JsonKey() final  String city;
/// BT-38.
@override@JsonKey() final  String postalCode;
/// BT-40 / BT-55 — ISO 3166-1 alpha-2, mandatory on both parties.
@override@JsonKey() final  String country;
/// BT-31 (seller) / BT-48 (buyer).
@override@JsonKey() final  String vatId;
/// BT-30, the company register number — the seller identifier a
/// category-O invoice is allowed to carry.
@override@JsonKey() final  String legalId;
/// Wire value of [VatRegime]; seller only.
@override@JsonKey() final  String vatRegime;
/// Free-text exemption reason (BT-120); seller only.
@override@JsonKey() final  String taxExemptionReason;
/// #886 — the contact the document is sent to (BT-43 / BT-42).
@override@JsonKey() final  String email;
@override@JsonKey() final  String phone;

/// Create a copy of InvoiceParty
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoicePartyCopyWith<_InvoiceParty> get copyWith => __$InvoicePartyCopyWithImpl<_InvoiceParty>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceParty&&(identical(other.name, name) || other.name == name)&&(identical(other.company, company) || other.company == company)&&(identical(other.courtesy, courtesy) || other.courtesy == courtesy)&&(identical(other.person, person) || other.person == person)&&(identical(other.street, street) || other.street == street)&&(identical(other.city, city) || other.city == city)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.country, country) || other.country == country)&&(identical(other.vatId, vatId) || other.vatId == vatId)&&(identical(other.legalId, legalId) || other.legalId == legalId)&&(identical(other.vatRegime, vatRegime) || other.vatRegime == vatRegime)&&(identical(other.taxExemptionReason, taxExemptionReason) || other.taxExemptionReason == taxExemptionReason)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode => Object.hash(runtimeType,name,company,courtesy,person,street,city,postalCode,country,vatId,legalId,vatRegime,taxExemptionReason,email,phone);

@override
String toString() {
  return 'InvoiceParty(name: $name, company: $company, courtesy: $courtesy, person: $person, street: $street, city: $city, postalCode: $postalCode, country: $country, vatId: $vatId, legalId: $legalId, vatRegime: $vatRegime, taxExemptionReason: $taxExemptionReason, email: $email, phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$InvoicePartyCopyWith<$Res> implements $InvoicePartyCopyWith<$Res> {
  factory _$InvoicePartyCopyWith(_InvoiceParty value, $Res Function(_InvoiceParty) _then) = __$InvoicePartyCopyWithImpl;
@override @useResult
$Res call({
 String name, String company, String courtesy, String person, String street, String city, String postalCode, String country, String vatId, String legalId, String vatRegime, String taxExemptionReason, String email, String phone
});




}
/// @nodoc
class __$InvoicePartyCopyWithImpl<$Res>
    implements _$InvoicePartyCopyWith<$Res> {
  __$InvoicePartyCopyWithImpl(this._self, this._then);

  final _InvoiceParty _self;
  final $Res Function(_InvoiceParty) _then;

/// Create a copy of InvoiceParty
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? company = null,Object? courtesy = null,Object? person = null,Object? street = null,Object? city = null,Object? postalCode = null,Object? country = null,Object? vatId = null,Object? legalId = null,Object? vatRegime = null,Object? taxExemptionReason = null,Object? email = null,Object? phone = null,}) {
  return _then(_InvoiceParty(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as String,courtesy: null == courtesy ? _self.courtesy : courtesy // ignore: cast_nullable_to_non_nullable
as String,person: null == person ? _self.person : person // ignore: cast_nullable_to_non_nullable
as String,street: null == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,vatId: null == vatId ? _self.vatId : vatId // ignore: cast_nullable_to_non_nullable
as String,legalId: null == legalId ? _self.legalId : legalId // ignore: cast_nullable_to_non_nullable
as String,vatRegime: null == vatRegime ? _self.vatRegime : vatRegime // ignore: cast_nullable_to_non_nullable
as String,taxExemptionReason: null == taxExemptionReason ? _self.taxExemptionReason : taxExemptionReason // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SettledSource {

 String get invoiceId; String get number; String? get period; InvoiceKind get kind; int get totalCents; List<InvoiceLine> get lines;
/// Create a copy of SettledSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettledSourceCopyWith<SettledSource> get copyWith => _$SettledSourceCopyWithImpl<SettledSource>(this as SettledSource, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettledSource&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.number, number) || other.number == number)&&(identical(other.period, period) || other.period == period)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&const DeepCollectionEquality().equals(other.lines, lines));
}


@override
int get hashCode => Object.hash(runtimeType,invoiceId,number,period,kind,totalCents,const DeepCollectionEquality().hash(lines));

@override
String toString() {
  return 'SettledSource(invoiceId: $invoiceId, number: $number, period: $period, kind: $kind, totalCents: $totalCents, lines: $lines)';
}


}

/// @nodoc
abstract mixin class $SettledSourceCopyWith<$Res>  {
  factory $SettledSourceCopyWith(SettledSource value, $Res Function(SettledSource) _then) = _$SettledSourceCopyWithImpl;
@useResult
$Res call({
 String invoiceId, String number, String? period, InvoiceKind kind, int totalCents, List<InvoiceLine> lines
});




}
/// @nodoc
class _$SettledSourceCopyWithImpl<$Res>
    implements $SettledSourceCopyWith<$Res> {
  _$SettledSourceCopyWithImpl(this._self, this._then);

  final SettledSource _self;
  final $Res Function(SettledSource) _then;

/// Create a copy of SettledSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? invoiceId = null,Object? number = null,Object? period = freezed,Object? kind = null,Object? totalCents = null,Object? lines = null,}) {
  return _then(_self.copyWith(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InvoiceKind,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,
  ));
}

}


/// Adds pattern-matching-related methods to [SettledSource].
extension SettledSourcePatterns on SettledSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettledSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettledSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettledSource value)  $default,){
final _that = this;
switch (_that) {
case _SettledSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettledSource value)?  $default,){
final _that = this;
switch (_that) {
case _SettledSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String invoiceId,  String number,  String? period,  InvoiceKind kind,  int totalCents,  List<InvoiceLine> lines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettledSource() when $default != null:
return $default(_that.invoiceId,_that.number,_that.period,_that.kind,_that.totalCents,_that.lines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String invoiceId,  String number,  String? period,  InvoiceKind kind,  int totalCents,  List<InvoiceLine> lines)  $default,) {final _that = this;
switch (_that) {
case _SettledSource():
return $default(_that.invoiceId,_that.number,_that.period,_that.kind,_that.totalCents,_that.lines);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String invoiceId,  String number,  String? period,  InvoiceKind kind,  int totalCents,  List<InvoiceLine> lines)?  $default,) {final _that = this;
switch (_that) {
case _SettledSource() when $default != null:
return $default(_that.invoiceId,_that.number,_that.period,_that.kind,_that.totalCents,_that.lines);case _:
  return null;

}
}

}

/// @nodoc


class _SettledSource implements SettledSource {
  const _SettledSource({required this.invoiceId, required this.number, this.period, this.kind = InvoiceKind.full, required this.totalCents, final  List<InvoiceLine> lines = const []}): _lines = lines;
  

@override final  String invoiceId;
@override final  String number;
@override final  String? period;
@override@JsonKey() final  InvoiceKind kind;
@override final  int totalCents;
 final  List<InvoiceLine> _lines;
@override@JsonKey() List<InvoiceLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of SettledSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettledSourceCopyWith<_SettledSource> get copyWith => __$SettledSourceCopyWithImpl<_SettledSource>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettledSource&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.number, number) || other.number == number)&&(identical(other.period, period) || other.period == period)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&const DeepCollectionEquality().equals(other._lines, _lines));
}


@override
int get hashCode => Object.hash(runtimeType,invoiceId,number,period,kind,totalCents,const DeepCollectionEquality().hash(_lines));

@override
String toString() {
  return 'SettledSource(invoiceId: $invoiceId, number: $number, period: $period, kind: $kind, totalCents: $totalCents, lines: $lines)';
}


}

/// @nodoc
abstract mixin class _$SettledSourceCopyWith<$Res> implements $SettledSourceCopyWith<$Res> {
  factory _$SettledSourceCopyWith(_SettledSource value, $Res Function(_SettledSource) _then) = __$SettledSourceCopyWithImpl;
@override @useResult
$Res call({
 String invoiceId, String number, String? period, InvoiceKind kind, int totalCents, List<InvoiceLine> lines
});




}
/// @nodoc
class __$SettledSourceCopyWithImpl<$Res>
    implements _$SettledSourceCopyWith<$Res> {
  __$SettledSourceCopyWithImpl(this._self, this._then);

  final _SettledSource _self;
  final $Res Function(_SettledSource) _then;

/// Create a copy of SettledSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? invoiceId = null,Object? number = null,Object? period = freezed,Object? kind = null,Object? totalCents = null,Object? lines = null,}) {
  return _then(_SettledSource(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InvoiceKind,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,
  ));
}


}

/// @nodoc
mixin _$Invoice {

 String get id; String get workspaceId; String get memberId; String get number; DateTime get issuedAt; String? get period; String get title; List<InvoiceLine> get lines; int get totalCents; String get currency; String get memberName; String get memberAddress; String get workspaceName; String get workspaceAddress; String get issuerName; String get signature; DateTime? get voidedAt; String get voidedByName; String? get replacesInvoiceId; String get replacesNumber;// 0064 — the optional SNAPSHOTTED annex; compact invoices carry
// neither.
 bool get detailed; List<InvoiceDetailEntry> get detailLedger; List<InvoiceAttendance> get attendance;// 0069 — the parties' legal identity, snapshotted for the e-invoice.
// Null on pre-0069 documents.
 InvoiceParty? get sellerParty; InvoiceParty? get buyerParty;// 0072 — the VAT breakdown as issued, one entry per rate. Empty on
// pre-0072 invoices and on workspaces that charge no VAT.
 List<InvoiceVatTotal> get vatTotals;/// #802 (0142) — what this document charges for: the subscription of
/// a month still to come, what a finished month actually cost, a
/// regrouping of several, or the historical whole month. Every
/// pre-0142 row reads [InvoiceKind.full], which is what it is.
 InvoiceKind get kind;/// #804 — the settlement that now carries this invoice's balance.
/// The document itself is untouched: it stays exactly as issued and
/// simply stops being separately owed.
 String? get settledByInvoiceId;/// #804 — on a settlement, what it consolidated.
 List<SettledSource> get settles;
/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceCopyWith<Invoice> get copyWith => _$InvoiceCopyWithImpl<Invoice>(this as Invoice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.number, number) || other.number == number)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.period, period) || other.period == period)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAddress, memberAddress) || other.memberAddress == memberAddress)&&(identical(other.workspaceName, workspaceName) || other.workspaceName == workspaceName)&&(identical(other.workspaceAddress, workspaceAddress) || other.workspaceAddress == workspaceAddress)&&(identical(other.issuerName, issuerName) || other.issuerName == issuerName)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidedByName, voidedByName) || other.voidedByName == voidedByName)&&(identical(other.replacesInvoiceId, replacesInvoiceId) || other.replacesInvoiceId == replacesInvoiceId)&&(identical(other.replacesNumber, replacesNumber) || other.replacesNumber == replacesNumber)&&(identical(other.detailed, detailed) || other.detailed == detailed)&&const DeepCollectionEquality().equals(other.detailLedger, detailLedger)&&const DeepCollectionEquality().equals(other.attendance, attendance)&&(identical(other.sellerParty, sellerParty) || other.sellerParty == sellerParty)&&(identical(other.buyerParty, buyerParty) || other.buyerParty == buyerParty)&&const DeepCollectionEquality().equals(other.vatTotals, vatTotals)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.settledByInvoiceId, settledByInvoiceId) || other.settledByInvoiceId == settledByInvoiceId)&&const DeepCollectionEquality().equals(other.settles, settles));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,memberId,number,issuedAt,period,title,const DeepCollectionEquality().hash(lines),totalCents,currency,memberName,memberAddress,workspaceName,workspaceAddress,issuerName,signature,voidedAt,voidedByName,replacesInvoiceId,replacesNumber,detailed,const DeepCollectionEquality().hash(detailLedger),const DeepCollectionEquality().hash(attendance),sellerParty,buyerParty,const DeepCollectionEquality().hash(vatTotals),kind,settledByInvoiceId,const DeepCollectionEquality().hash(settles)]);

@override
String toString() {
  return 'Invoice(id: $id, workspaceId: $workspaceId, memberId: $memberId, number: $number, issuedAt: $issuedAt, period: $period, title: $title, lines: $lines, totalCents: $totalCents, currency: $currency, memberName: $memberName, memberAddress: $memberAddress, workspaceName: $workspaceName, workspaceAddress: $workspaceAddress, issuerName: $issuerName, signature: $signature, voidedAt: $voidedAt, voidedByName: $voidedByName, replacesInvoiceId: $replacesInvoiceId, replacesNumber: $replacesNumber, detailed: $detailed, detailLedger: $detailLedger, attendance: $attendance, sellerParty: $sellerParty, buyerParty: $buyerParty, vatTotals: $vatTotals, kind: $kind, settledByInvoiceId: $settledByInvoiceId, settles: $settles)';
}


}

/// @nodoc
abstract mixin class $InvoiceCopyWith<$Res>  {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) _then) = _$InvoiceCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String memberId, String number, DateTime issuedAt, String? period, String title, List<InvoiceLine> lines, int totalCents, String currency, String memberName, String memberAddress, String workspaceName, String workspaceAddress, String issuerName, String signature, DateTime? voidedAt, String voidedByName, String? replacesInvoiceId, String replacesNumber, bool detailed, List<InvoiceDetailEntry> detailLedger, List<InvoiceAttendance> attendance, InvoiceParty? sellerParty, InvoiceParty? buyerParty, List<InvoiceVatTotal> vatTotals, InvoiceKind kind, String? settledByInvoiceId, List<SettledSource> settles
});


$InvoicePartyCopyWith<$Res>? get sellerParty;$InvoicePartyCopyWith<$Res>? get buyerParty;

}
/// @nodoc
class _$InvoiceCopyWithImpl<$Res>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._self, this._then);

  final Invoice _self;
  final $Res Function(Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? number = null,Object? issuedAt = null,Object? period = freezed,Object? title = null,Object? lines = null,Object? totalCents = null,Object? currency = null,Object? memberName = null,Object? memberAddress = null,Object? workspaceName = null,Object? workspaceAddress = null,Object? issuerName = null,Object? signature = null,Object? voidedAt = freezed,Object? voidedByName = null,Object? replacesInvoiceId = freezed,Object? replacesNumber = null,Object? detailed = null,Object? detailLedger = null,Object? attendance = null,Object? sellerParty = freezed,Object? buyerParty = freezed,Object? vatTotals = null,Object? kind = null,Object? settledByInvoiceId = freezed,Object? settles = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as DateTime,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,memberName: null == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String,memberAddress: null == memberAddress ? _self.memberAddress : memberAddress // ignore: cast_nullable_to_non_nullable
as String,workspaceName: null == workspaceName ? _self.workspaceName : workspaceName // ignore: cast_nullable_to_non_nullable
as String,workspaceAddress: null == workspaceAddress ? _self.workspaceAddress : workspaceAddress // ignore: cast_nullable_to_non_nullable
as String,issuerName: null == issuerName ? _self.issuerName : issuerName // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,voidedAt: freezed == voidedAt ? _self.voidedAt : voidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,voidedByName: null == voidedByName ? _self.voidedByName : voidedByName // ignore: cast_nullable_to_non_nullable
as String,replacesInvoiceId: freezed == replacesInvoiceId ? _self.replacesInvoiceId : replacesInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,replacesNumber: null == replacesNumber ? _self.replacesNumber : replacesNumber // ignore: cast_nullable_to_non_nullable
as String,detailed: null == detailed ? _self.detailed : detailed // ignore: cast_nullable_to_non_nullable
as bool,detailLedger: null == detailLedger ? _self.detailLedger : detailLedger // ignore: cast_nullable_to_non_nullable
as List<InvoiceDetailEntry>,attendance: null == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<InvoiceAttendance>,sellerParty: freezed == sellerParty ? _self.sellerParty : sellerParty // ignore: cast_nullable_to_non_nullable
as InvoiceParty?,buyerParty: freezed == buyerParty ? _self.buyerParty : buyerParty // ignore: cast_nullable_to_non_nullable
as InvoiceParty?,vatTotals: null == vatTotals ? _self.vatTotals : vatTotals // ignore: cast_nullable_to_non_nullable
as List<InvoiceVatTotal>,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InvoiceKind,settledByInvoiceId: freezed == settledByInvoiceId ? _self.settledByInvoiceId : settledByInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,settles: null == settles ? _self.settles : settles // ignore: cast_nullable_to_non_nullable
as List<SettledSource>,
  ));
}
/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoicePartyCopyWith<$Res>? get sellerParty {
    if (_self.sellerParty == null) {
    return null;
  }

  return $InvoicePartyCopyWith<$Res>(_self.sellerParty!, (value) {
    return _then(_self.copyWith(sellerParty: value));
  });
}/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoicePartyCopyWith<$Res>? get buyerParty {
    if (_self.buyerParty == null) {
    return null;
  }

  return $InvoicePartyCopyWith<$Res>(_self.buyerParty!, (value) {
    return _then(_self.copyWith(buyerParty: value));
  });
}
}


/// Adds pattern-matching-related methods to [Invoice].
extension InvoicePatterns on Invoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Invoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Invoice value)  $default,){
final _that = this;
switch (_that) {
case _Invoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Invoice value)?  $default,){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber,  bool detailed,  List<InvoiceDetailEntry> detailLedger,  List<InvoiceAttendance> attendance,  InvoiceParty? sellerParty,  InvoiceParty? buyerParty,  List<InvoiceVatTotal> vatTotals,  InvoiceKind kind,  String? settledByInvoiceId,  List<SettledSource> settles)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber,_that.detailed,_that.detailLedger,_that.attendance,_that.sellerParty,_that.buyerParty,_that.vatTotals,_that.kind,_that.settledByInvoiceId,_that.settles);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber,  bool detailed,  List<InvoiceDetailEntry> detailLedger,  List<InvoiceAttendance> attendance,  InvoiceParty? sellerParty,  InvoiceParty? buyerParty,  List<InvoiceVatTotal> vatTotals,  InvoiceKind kind,  String? settledByInvoiceId,  List<SettledSource> settles)  $default,) {final _that = this;
switch (_that) {
case _Invoice():
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber,_that.detailed,_that.detailLedger,_that.attendance,_that.sellerParty,_that.buyerParty,_that.vatTotals,_that.kind,_that.settledByInvoiceId,_that.settles);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber,  bool detailed,  List<InvoiceDetailEntry> detailLedger,  List<InvoiceAttendance> attendance,  InvoiceParty? sellerParty,  InvoiceParty? buyerParty,  List<InvoiceVatTotal> vatTotals,  InvoiceKind kind,  String? settledByInvoiceId,  List<SettledSource> settles)?  $default,) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber,_that.detailed,_that.detailLedger,_that.attendance,_that.sellerParty,_that.buyerParty,_that.vatTotals,_that.kind,_that.settledByInvoiceId,_that.settles);case _:
  return null;

}
}

}

/// @nodoc


class _Invoice extends Invoice {
  const _Invoice({required this.id, required this.workspaceId, required this.memberId, required this.number, required this.issuedAt, this.period, required this.title, required final  List<InvoiceLine> lines, required this.totalCents, required this.currency, required this.memberName, required this.memberAddress, required this.workspaceName, required this.workspaceAddress, required this.issuerName, required this.signature, this.voidedAt, this.voidedByName = '', this.replacesInvoiceId, this.replacesNumber = '', this.detailed = false, final  List<InvoiceDetailEntry> detailLedger = const [], final  List<InvoiceAttendance> attendance = const [], this.sellerParty, this.buyerParty, final  List<InvoiceVatTotal> vatTotals = const [], this.kind = InvoiceKind.full, this.settledByInvoiceId, final  List<SettledSource> settles = const []}): _lines = lines,_detailLedger = detailLedger,_attendance = attendance,_vatTotals = vatTotals,_settles = settles,super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String memberId;
@override final  String number;
@override final  DateTime issuedAt;
@override final  String? period;
@override final  String title;
 final  List<InvoiceLine> _lines;
@override List<InvoiceLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override final  int totalCents;
@override final  String currency;
@override final  String memberName;
@override final  String memberAddress;
@override final  String workspaceName;
@override final  String workspaceAddress;
@override final  String issuerName;
@override final  String signature;
@override final  DateTime? voidedAt;
@override@JsonKey() final  String voidedByName;
@override final  String? replacesInvoiceId;
@override@JsonKey() final  String replacesNumber;
// 0064 — the optional SNAPSHOTTED annex; compact invoices carry
// neither.
@override@JsonKey() final  bool detailed;
 final  List<InvoiceDetailEntry> _detailLedger;
@override@JsonKey() List<InvoiceDetailEntry> get detailLedger {
  if (_detailLedger is EqualUnmodifiableListView) return _detailLedger;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_detailLedger);
}

 final  List<InvoiceAttendance> _attendance;
@override@JsonKey() List<InvoiceAttendance> get attendance {
  if (_attendance is EqualUnmodifiableListView) return _attendance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attendance);
}

// 0069 — the parties' legal identity, snapshotted for the e-invoice.
// Null on pre-0069 documents.
@override final  InvoiceParty? sellerParty;
@override final  InvoiceParty? buyerParty;
// 0072 — the VAT breakdown as issued, one entry per rate. Empty on
// pre-0072 invoices and on workspaces that charge no VAT.
 final  List<InvoiceVatTotal> _vatTotals;
// 0072 — the VAT breakdown as issued, one entry per rate. Empty on
// pre-0072 invoices and on workspaces that charge no VAT.
@override@JsonKey() List<InvoiceVatTotal> get vatTotals {
  if (_vatTotals is EqualUnmodifiableListView) return _vatTotals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vatTotals);
}

/// #802 (0142) — what this document charges for: the subscription of
/// a month still to come, what a finished month actually cost, a
/// regrouping of several, or the historical whole month. Every
/// pre-0142 row reads [InvoiceKind.full], which is what it is.
@override@JsonKey() final  InvoiceKind kind;
/// #804 — the settlement that now carries this invoice's balance.
/// The document itself is untouched: it stays exactly as issued and
/// simply stops being separately owed.
@override final  String? settledByInvoiceId;
/// #804 — on a settlement, what it consolidated.
 final  List<SettledSource> _settles;
/// #804 — on a settlement, what it consolidated.
@override@JsonKey() List<SettledSource> get settles {
  if (_settles is EqualUnmodifiableListView) return _settles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_settles);
}


/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceCopyWith<_Invoice> get copyWith => __$InvoiceCopyWithImpl<_Invoice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.number, number) || other.number == number)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.period, period) || other.period == period)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAddress, memberAddress) || other.memberAddress == memberAddress)&&(identical(other.workspaceName, workspaceName) || other.workspaceName == workspaceName)&&(identical(other.workspaceAddress, workspaceAddress) || other.workspaceAddress == workspaceAddress)&&(identical(other.issuerName, issuerName) || other.issuerName == issuerName)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidedByName, voidedByName) || other.voidedByName == voidedByName)&&(identical(other.replacesInvoiceId, replacesInvoiceId) || other.replacesInvoiceId == replacesInvoiceId)&&(identical(other.replacesNumber, replacesNumber) || other.replacesNumber == replacesNumber)&&(identical(other.detailed, detailed) || other.detailed == detailed)&&const DeepCollectionEquality().equals(other._detailLedger, _detailLedger)&&const DeepCollectionEquality().equals(other._attendance, _attendance)&&(identical(other.sellerParty, sellerParty) || other.sellerParty == sellerParty)&&(identical(other.buyerParty, buyerParty) || other.buyerParty == buyerParty)&&const DeepCollectionEquality().equals(other._vatTotals, _vatTotals)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.settledByInvoiceId, settledByInvoiceId) || other.settledByInvoiceId == settledByInvoiceId)&&const DeepCollectionEquality().equals(other._settles, _settles));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,memberId,number,issuedAt,period,title,const DeepCollectionEquality().hash(_lines),totalCents,currency,memberName,memberAddress,workspaceName,workspaceAddress,issuerName,signature,voidedAt,voidedByName,replacesInvoiceId,replacesNumber,detailed,const DeepCollectionEquality().hash(_detailLedger),const DeepCollectionEquality().hash(_attendance),sellerParty,buyerParty,const DeepCollectionEquality().hash(_vatTotals),kind,settledByInvoiceId,const DeepCollectionEquality().hash(_settles)]);

@override
String toString() {
  return 'Invoice(id: $id, workspaceId: $workspaceId, memberId: $memberId, number: $number, issuedAt: $issuedAt, period: $period, title: $title, lines: $lines, totalCents: $totalCents, currency: $currency, memberName: $memberName, memberAddress: $memberAddress, workspaceName: $workspaceName, workspaceAddress: $workspaceAddress, issuerName: $issuerName, signature: $signature, voidedAt: $voidedAt, voidedByName: $voidedByName, replacesInvoiceId: $replacesInvoiceId, replacesNumber: $replacesNumber, detailed: $detailed, detailLedger: $detailLedger, attendance: $attendance, sellerParty: $sellerParty, buyerParty: $buyerParty, vatTotals: $vatTotals, kind: $kind, settledByInvoiceId: $settledByInvoiceId, settles: $settles)';
}


}

/// @nodoc
abstract mixin class _$InvoiceCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$InvoiceCopyWith(_Invoice value, $Res Function(_Invoice) _then) = __$InvoiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String memberId, String number, DateTime issuedAt, String? period, String title, List<InvoiceLine> lines, int totalCents, String currency, String memberName, String memberAddress, String workspaceName, String workspaceAddress, String issuerName, String signature, DateTime? voidedAt, String voidedByName, String? replacesInvoiceId, String replacesNumber, bool detailed, List<InvoiceDetailEntry> detailLedger, List<InvoiceAttendance> attendance, InvoiceParty? sellerParty, InvoiceParty? buyerParty, List<InvoiceVatTotal> vatTotals, InvoiceKind kind, String? settledByInvoiceId, List<SettledSource> settles
});


@override $InvoicePartyCopyWith<$Res>? get sellerParty;@override $InvoicePartyCopyWith<$Res>? get buyerParty;

}
/// @nodoc
class __$InvoiceCopyWithImpl<$Res>
    implements _$InvoiceCopyWith<$Res> {
  __$InvoiceCopyWithImpl(this._self, this._then);

  final _Invoice _self;
  final $Res Function(_Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? number = null,Object? issuedAt = null,Object? period = freezed,Object? title = null,Object? lines = null,Object? totalCents = null,Object? currency = null,Object? memberName = null,Object? memberAddress = null,Object? workspaceName = null,Object? workspaceAddress = null,Object? issuerName = null,Object? signature = null,Object? voidedAt = freezed,Object? voidedByName = null,Object? replacesInvoiceId = freezed,Object? replacesNumber = null,Object? detailed = null,Object? detailLedger = null,Object? attendance = null,Object? sellerParty = freezed,Object? buyerParty = freezed,Object? vatTotals = null,Object? kind = null,Object? settledByInvoiceId = freezed,Object? settles = null,}) {
  return _then(_Invoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as DateTime,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,memberName: null == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String,memberAddress: null == memberAddress ? _self.memberAddress : memberAddress // ignore: cast_nullable_to_non_nullable
as String,workspaceName: null == workspaceName ? _self.workspaceName : workspaceName // ignore: cast_nullable_to_non_nullable
as String,workspaceAddress: null == workspaceAddress ? _self.workspaceAddress : workspaceAddress // ignore: cast_nullable_to_non_nullable
as String,issuerName: null == issuerName ? _self.issuerName : issuerName // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,voidedAt: freezed == voidedAt ? _self.voidedAt : voidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,voidedByName: null == voidedByName ? _self.voidedByName : voidedByName // ignore: cast_nullable_to_non_nullable
as String,replacesInvoiceId: freezed == replacesInvoiceId ? _self.replacesInvoiceId : replacesInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,replacesNumber: null == replacesNumber ? _self.replacesNumber : replacesNumber // ignore: cast_nullable_to_non_nullable
as String,detailed: null == detailed ? _self.detailed : detailed // ignore: cast_nullable_to_non_nullable
as bool,detailLedger: null == detailLedger ? _self._detailLedger : detailLedger // ignore: cast_nullable_to_non_nullable
as List<InvoiceDetailEntry>,attendance: null == attendance ? _self._attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<InvoiceAttendance>,sellerParty: freezed == sellerParty ? _self.sellerParty : sellerParty // ignore: cast_nullable_to_non_nullable
as InvoiceParty?,buyerParty: freezed == buyerParty ? _self.buyerParty : buyerParty // ignore: cast_nullable_to_non_nullable
as InvoiceParty?,vatTotals: null == vatTotals ? _self._vatTotals : vatTotals // ignore: cast_nullable_to_non_nullable
as List<InvoiceVatTotal>,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InvoiceKind,settledByInvoiceId: freezed == settledByInvoiceId ? _self.settledByInvoiceId : settledByInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,settles: null == settles ? _self._settles : settles // ignore: cast_nullable_to_non_nullable
as List<SettledSource>,
  ));
}

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoicePartyCopyWith<$Res>? get sellerParty {
    if (_self.sellerParty == null) {
    return null;
  }

  return $InvoicePartyCopyWith<$Res>(_self.sellerParty!, (value) {
    return _then(_self.copyWith(sellerParty: value));
  });
}/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoicePartyCopyWith<$Res>? get buyerParty {
    if (_self.buyerParty == null) {
    return null;
  }

  return $InvoicePartyCopyWith<$Res>(_self.buyerParty!, (value) {
    return _then(_self.copyWith(buyerParty: value));
  });
}
}

// dart format on
