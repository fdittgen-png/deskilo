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

 String get kind; String get label; int get quantity; int get amountCents;
/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceLineCopyWith<InvoiceLine> get copyWith => _$InvoiceLineCopyWithImpl<InvoiceLine>(this as InvoiceLine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,quantity,amountCents);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, label: $label, quantity: $quantity, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class $InvoiceLineCopyWith<$Res>  {
  factory $InvoiceLineCopyWith(InvoiceLine value, $Res Function(InvoiceLine) _then) = _$InvoiceLineCopyWithImpl;
@useResult
$Res call({
 String kind, String label, int quantity, int amountCents
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
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? label = null,Object? quantity = null,Object? amountCents = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String label,  int quantity,  int amountCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String label,  int quantity,  int amountCents)  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine():
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String label,  int quantity,  int amountCents)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.label,_that.quantity,_that.amountCents);case _:
  return null;

}
}

}

/// @nodoc


class _InvoiceLine implements InvoiceLine {
  const _InvoiceLine({this.kind = '', required this.label, this.quantity = 1, required this.amountCents});
  

@override@JsonKey() final  String kind;
@override final  String label;
@override@JsonKey() final  int quantity;
@override final  int amountCents;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceLineCopyWith<_InvoiceLine> get copyWith => __$InvoiceLineCopyWithImpl<_InvoiceLine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,quantity,amountCents);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, label: $label, quantity: $quantity, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class _$InvoiceLineCopyWith<$Res> implements $InvoiceLineCopyWith<$Res> {
  factory _$InvoiceLineCopyWith(_InvoiceLine value, $Res Function(_InvoiceLine) _then) = __$InvoiceLineCopyWithImpl;
@override @useResult
$Res call({
 String kind, String label, int quantity, int amountCents
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
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? label = null,Object? quantity = null,Object? amountCents = null,}) {
  return _then(_InvoiceLine(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$Invoice {

 String get id; String get workspaceId; String get memberId; String get number; DateTime get issuedAt; String? get period; String get title; List<InvoiceLine> get lines; int get totalCents; String get currency; String get memberName; String get memberAddress; String get workspaceName; String get workspaceAddress; String get issuerName; String get signature; DateTime? get voidedAt; String get voidedByName; String? get replacesInvoiceId; String get replacesNumber;
/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceCopyWith<Invoice> get copyWith => _$InvoiceCopyWithImpl<Invoice>(this as Invoice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.number, number) || other.number == number)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.period, period) || other.period == period)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAddress, memberAddress) || other.memberAddress == memberAddress)&&(identical(other.workspaceName, workspaceName) || other.workspaceName == workspaceName)&&(identical(other.workspaceAddress, workspaceAddress) || other.workspaceAddress == workspaceAddress)&&(identical(other.issuerName, issuerName) || other.issuerName == issuerName)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidedByName, voidedByName) || other.voidedByName == voidedByName)&&(identical(other.replacesInvoiceId, replacesInvoiceId) || other.replacesInvoiceId == replacesInvoiceId)&&(identical(other.replacesNumber, replacesNumber) || other.replacesNumber == replacesNumber));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,memberId,number,issuedAt,period,title,const DeepCollectionEquality().hash(lines),totalCents,currency,memberName,memberAddress,workspaceName,workspaceAddress,issuerName,signature,voidedAt,voidedByName,replacesInvoiceId,replacesNumber]);

@override
String toString() {
  return 'Invoice(id: $id, workspaceId: $workspaceId, memberId: $memberId, number: $number, issuedAt: $issuedAt, period: $period, title: $title, lines: $lines, totalCents: $totalCents, currency: $currency, memberName: $memberName, memberAddress: $memberAddress, workspaceName: $workspaceName, workspaceAddress: $workspaceAddress, issuerName: $issuerName, signature: $signature, voidedAt: $voidedAt, voidedByName: $voidedByName, replacesInvoiceId: $replacesInvoiceId, replacesNumber: $replacesNumber)';
}


}

/// @nodoc
abstract mixin class $InvoiceCopyWith<$Res>  {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) _then) = _$InvoiceCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String memberId, String number, DateTime issuedAt, String? period, String title, List<InvoiceLine> lines, int totalCents, String currency, String memberName, String memberAddress, String workspaceName, String workspaceAddress, String issuerName, String signature, DateTime? voidedAt, String voidedByName, String? replacesInvoiceId, String replacesNumber
});




}
/// @nodoc
class _$InvoiceCopyWithImpl<$Res>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._self, this._then);

  final Invoice _self;
  final $Res Function(Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? number = null,Object? issuedAt = null,Object? period = freezed,Object? title = null,Object? lines = null,Object? totalCents = null,Object? currency = null,Object? memberName = null,Object? memberAddress = null,Object? workspaceName = null,Object? workspaceAddress = null,Object? issuerName = null,Object? signature = null,Object? voidedAt = freezed,Object? voidedByName = null,Object? replacesInvoiceId = freezed,Object? replacesNumber = null,}) {
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
as String,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber)  $default,) {final _that = this;
switch (_that) {
case _Invoice():
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String memberId,  String number,  DateTime issuedAt,  String? period,  String title,  List<InvoiceLine> lines,  int totalCents,  String currency,  String memberName,  String memberAddress,  String workspaceName,  String workspaceAddress,  String issuerName,  String signature,  DateTime? voidedAt,  String voidedByName,  String? replacesInvoiceId,  String replacesNumber)?  $default,) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.workspaceId,_that.memberId,_that.number,_that.issuedAt,_that.period,_that.title,_that.lines,_that.totalCents,_that.currency,_that.memberName,_that.memberAddress,_that.workspaceName,_that.workspaceAddress,_that.issuerName,_that.signature,_that.voidedAt,_that.voidedByName,_that.replacesInvoiceId,_that.replacesNumber);case _:
  return null;

}
}

}

/// @nodoc


class _Invoice extends Invoice {
  const _Invoice({required this.id, required this.workspaceId, required this.memberId, required this.number, required this.issuedAt, this.period, required this.title, required final  List<InvoiceLine> lines, required this.totalCents, required this.currency, required this.memberName, required this.memberAddress, required this.workspaceName, required this.workspaceAddress, required this.issuerName, required this.signature, this.voidedAt, this.voidedByName = '', this.replacesInvoiceId, this.replacesNumber = ''}): _lines = lines,super._();
  

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

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceCopyWith<_Invoice> get copyWith => __$InvoiceCopyWithImpl<_Invoice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.number, number) || other.number == number)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.period, period) || other.period == period)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAddress, memberAddress) || other.memberAddress == memberAddress)&&(identical(other.workspaceName, workspaceName) || other.workspaceName == workspaceName)&&(identical(other.workspaceAddress, workspaceAddress) || other.workspaceAddress == workspaceAddress)&&(identical(other.issuerName, issuerName) || other.issuerName == issuerName)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidedByName, voidedByName) || other.voidedByName == voidedByName)&&(identical(other.replacesInvoiceId, replacesInvoiceId) || other.replacesInvoiceId == replacesInvoiceId)&&(identical(other.replacesNumber, replacesNumber) || other.replacesNumber == replacesNumber));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,memberId,number,issuedAt,period,title,const DeepCollectionEquality().hash(_lines),totalCents,currency,memberName,memberAddress,workspaceName,workspaceAddress,issuerName,signature,voidedAt,voidedByName,replacesInvoiceId,replacesNumber]);

@override
String toString() {
  return 'Invoice(id: $id, workspaceId: $workspaceId, memberId: $memberId, number: $number, issuedAt: $issuedAt, period: $period, title: $title, lines: $lines, totalCents: $totalCents, currency: $currency, memberName: $memberName, memberAddress: $memberAddress, workspaceName: $workspaceName, workspaceAddress: $workspaceAddress, issuerName: $issuerName, signature: $signature, voidedAt: $voidedAt, voidedByName: $voidedByName, replacesInvoiceId: $replacesInvoiceId, replacesNumber: $replacesNumber)';
}


}

/// @nodoc
abstract mixin class _$InvoiceCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$InvoiceCopyWith(_Invoice value, $Res Function(_Invoice) _then) = __$InvoiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String memberId, String number, DateTime issuedAt, String? period, String title, List<InvoiceLine> lines, int totalCents, String currency, String memberName, String memberAddress, String workspaceName, String workspaceAddress, String issuerName, String signature, DateTime? voidedAt, String voidedByName, String? replacesInvoiceId, String replacesNumber
});




}
/// @nodoc
class __$InvoiceCopyWithImpl<$Res>
    implements _$InvoiceCopyWith<$Res> {
  __$InvoiceCopyWithImpl(this._self, this._then);

  final _Invoice _self;
  final $Res Function(_Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? memberId = null,Object? number = null,Object? issuedAt = null,Object? period = freezed,Object? title = null,Object? lines = null,Object? totalCents = null,Object? currency = null,Object? memberName = null,Object? memberAddress = null,Object? workspaceName = null,Object? workspaceAddress = null,Object? issuerName = null,Object? signature = null,Object? voidedAt = freezed,Object? voidedByName = null,Object? replacesInvoiceId = freezed,Object? replacesNumber = null,}) {
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
as String,
  ));
}


}

// dart format on
