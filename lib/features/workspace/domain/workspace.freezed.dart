// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Workspace {

 String get id; String get name; String get countryCode; String get currencyCode; String get timezone; String get inviteCode;/// Per-workspace feature overrides (#146): WorkspaceFeature.name →
/// bool. Absent key = the feature's registry default (ON); resolve
/// with [resolveEnabledFeatures].
 Map<String, dynamic> get featureFlags;/// Workspace-wide developer mode (#419, 0081): admin/owner-set,
/// applies to every member on every device (realtime-pushed).
 bool get devMode;/// Owner-configured payment instructions (#155) as stored — decode
/// with [PaymentInstructions.fromDb]. Empty = none configured.
 Map<String, dynamic> get paymentInstructions;/// Owner-set WhatsApp group invite link (#231), shown to members in
/// the directory (#232); '' = no group configured. Shape-checked
/// against [WhatsappGroupRules.linkPrefix] (0029 column check).
 String get whatsappGroup;/// Postal address (0060): printed on invoices; owner-edited.
 String get address;/// LEGAL IDENTITY (0069) — what an EN 16931 e-invoice cannot omit.
/// [vatRegime] is the wire value of `VatRegime` (money domain) and
/// decides which of the two identifiers is required: category `E`
/// needs [vatId] (BR-E-02), category `O` needs [legalId] and must NOT
/// carry a VAT id at all (BR-O-02 / BR-CO-26).
 String get vatRegime;/// BT-31, the VAT identification number ('FR12345678901').
 String get vatId;/// BT-30, the company register identifier (SIREN/SIRET, HRB, CIF…).
 String get legalId;/// BT-120, why no VAT is charged, in the owner's own words. Category
/// `E` requires a reason; a VATEX code is added automatically where
/// the code lists have one.
 String get taxExemptionReason;/// Structured address parts (BT-35/37/38) beside [address], which
/// stays the free-text block the PDF letterhead prints.
 String get street; String get city; String get postalCode;/// The account VAT is booked to in the FEC export (0072); '' = the
/// French default 445710. Only the accounting export reads it — the
/// app books nothing itself.
 String get vatAccount;/// Desk fill opacity percentage (0040): 100 = solid (default), lower
/// makes desks translucent so a level's background photo shows through.
/// Clamped 20..100 by the column check.
 int get deskOpacity;/// Owner-configured invitation message template (0049) with {tag}
/// placeholders (see [InvitationTags]); '' = use the app's localized
/// default message. Max length enforced by the column check.
 String get invitationTemplate;
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<Workspace> get copyWith => _$WorkspaceCopyWithImpl<Workspace>(this as Workspace, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other.featureFlags, featureFlags)&&(identical(other.devMode, devMode) || other.devMode == devMode)&&const DeepCollectionEquality().equals(other.paymentInstructions, paymentInstructions)&&(identical(other.whatsappGroup, whatsappGroup) || other.whatsappGroup == whatsappGroup)&&(identical(other.address, address) || other.address == address)&&(identical(other.vatRegime, vatRegime) || other.vatRegime == vatRegime)&&(identical(other.vatId, vatId) || other.vatId == vatId)&&(identical(other.legalId, legalId) || other.legalId == legalId)&&(identical(other.taxExemptionReason, taxExemptionReason) || other.taxExemptionReason == taxExemptionReason)&&(identical(other.street, street) || other.street == street)&&(identical(other.city, city) || other.city == city)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.vatAccount, vatAccount) || other.vatAccount == vatAccount)&&(identical(other.deskOpacity, deskOpacity) || other.deskOpacity == deskOpacity)&&(identical(other.invitationTemplate, invitationTemplate) || other.invitationTemplate == invitationTemplate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,countryCode,currencyCode,timezone,inviteCode,const DeepCollectionEquality().hash(featureFlags),devMode,const DeepCollectionEquality().hash(paymentInstructions),whatsappGroup,address,vatRegime,vatId,legalId,taxExemptionReason,street,city,postalCode,vatAccount,deskOpacity,invitationTemplate]);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, countryCode: $countryCode, currencyCode: $currencyCode, timezone: $timezone, inviteCode: $inviteCode, featureFlags: $featureFlags, devMode: $devMode, paymentInstructions: $paymentInstructions, whatsappGroup: $whatsappGroup, address: $address, vatRegime: $vatRegime, vatId: $vatId, legalId: $legalId, taxExemptionReason: $taxExemptionReason, street: $street, city: $city, postalCode: $postalCode, vatAccount: $vatAccount, deskOpacity: $deskOpacity, invitationTemplate: $invitationTemplate)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCopyWith<$Res>  {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) _then) = _$WorkspaceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String countryCode, String currencyCode, String timezone, String inviteCode, Map<String, dynamic> featureFlags, bool devMode, Map<String, dynamic> paymentInstructions, String whatsappGroup, String address, String vatRegime, String vatId, String legalId, String taxExemptionReason, String street, String city, String postalCode, String vatAccount, int deskOpacity, String invitationTemplate
});




}
/// @nodoc
class _$WorkspaceCopyWithImpl<$Res>
    implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._self, this._then);

  final Workspace _self;
  final $Res Function(Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? inviteCode = null,Object? featureFlags = null,Object? devMode = null,Object? paymentInstructions = null,Object? whatsappGroup = null,Object? address = null,Object? vatRegime = null,Object? vatId = null,Object? legalId = null,Object? taxExemptionReason = null,Object? street = null,Object? city = null,Object? postalCode = null,Object? vatAccount = null,Object? deskOpacity = null,Object? invitationTemplate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self.featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,devMode: null == devMode ? _self.devMode : devMode // ignore: cast_nullable_to_non_nullable
as bool,paymentInstructions: null == paymentInstructions ? _self.paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,whatsappGroup: null == whatsappGroup ? _self.whatsappGroup : whatsappGroup // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,vatRegime: null == vatRegime ? _self.vatRegime : vatRegime // ignore: cast_nullable_to_non_nullable
as String,vatId: null == vatId ? _self.vatId : vatId // ignore: cast_nullable_to_non_nullable
as String,legalId: null == legalId ? _self.legalId : legalId // ignore: cast_nullable_to_non_nullable
as String,taxExemptionReason: null == taxExemptionReason ? _self.taxExemptionReason : taxExemptionReason // ignore: cast_nullable_to_non_nullable
as String,street: null == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,vatAccount: null == vatAccount ? _self.vatAccount : vatAccount // ignore: cast_nullable_to_non_nullable
as String,deskOpacity: null == deskOpacity ? _self.deskOpacity : deskOpacity // ignore: cast_nullable_to_non_nullable
as int,invitationTemplate: null == invitationTemplate ? _self.invitationTemplate : invitationTemplate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Workspace].
extension WorkspacePatterns on Workspace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workspace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workspace value)  $default,){
final _that = this;
switch (_that) {
case _Workspace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workspace value)?  $default,){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  bool devMode,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  String address,  String vatRegime,  String vatId,  String legalId,  String taxExemptionReason,  String street,  String city,  String postalCode,  String vatAccount,  int deskOpacity,  String invitationTemplate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.devMode,_that.paymentInstructions,_that.whatsappGroup,_that.address,_that.vatRegime,_that.vatId,_that.legalId,_that.taxExemptionReason,_that.street,_that.city,_that.postalCode,_that.vatAccount,_that.deskOpacity,_that.invitationTemplate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  bool devMode,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  String address,  String vatRegime,  String vatId,  String legalId,  String taxExemptionReason,  String street,  String city,  String postalCode,  String vatAccount,  int deskOpacity,  String invitationTemplate)  $default,) {final _that = this;
switch (_that) {
case _Workspace():
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.devMode,_that.paymentInstructions,_that.whatsappGroup,_that.address,_that.vatRegime,_that.vatId,_that.legalId,_that.taxExemptionReason,_that.street,_that.city,_that.postalCode,_that.vatAccount,_that.deskOpacity,_that.invitationTemplate);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  bool devMode,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  String address,  String vatRegime,  String vatId,  String legalId,  String taxExemptionReason,  String street,  String city,  String postalCode,  String vatAccount,  int deskOpacity,  String invitationTemplate)?  $default,) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.devMode,_that.paymentInstructions,_that.whatsappGroup,_that.address,_that.vatRegime,_that.vatId,_that.legalId,_that.taxExemptionReason,_that.street,_that.city,_that.postalCode,_that.vatAccount,_that.deskOpacity,_that.invitationTemplate);case _:
  return null;

}
}

}

/// @nodoc


class _Workspace extends Workspace {
  const _Workspace({required this.id, required this.name, required this.countryCode, required this.currencyCode, required this.timezone, required this.inviteCode, final  Map<String, dynamic> featureFlags = const <String, dynamic>{}, this.devMode = false, final  Map<String, dynamic> paymentInstructions = const <String, dynamic>{}, this.whatsappGroup = '', this.address = '', this.vatRegime = 'not_subject', this.vatId = '', this.legalId = '', this.taxExemptionReason = '', this.street = '', this.city = '', this.postalCode = '', this.vatAccount = '', this.deskOpacity = 100, this.invitationTemplate = ''}): _featureFlags = featureFlags,_paymentInstructions = paymentInstructions,super._();
  

@override final  String id;
@override final  String name;
@override final  String countryCode;
@override final  String currencyCode;
@override final  String timezone;
@override final  String inviteCode;
/// Per-workspace feature overrides (#146): WorkspaceFeature.name →
/// bool. Absent key = the feature's registry default (ON); resolve
/// with [resolveEnabledFeatures].
 final  Map<String, dynamic> _featureFlags;
/// Per-workspace feature overrides (#146): WorkspaceFeature.name →
/// bool. Absent key = the feature's registry default (ON); resolve
/// with [resolveEnabledFeatures].
@override@JsonKey() Map<String, dynamic> get featureFlags {
  if (_featureFlags is EqualUnmodifiableMapView) return _featureFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_featureFlags);
}

/// Workspace-wide developer mode (#419, 0081): admin/owner-set,
/// applies to every member on every device (realtime-pushed).
@override@JsonKey() final  bool devMode;
/// Owner-configured payment instructions (#155) as stored — decode
/// with [PaymentInstructions.fromDb]. Empty = none configured.
 final  Map<String, dynamic> _paymentInstructions;
/// Owner-configured payment instructions (#155) as stored — decode
/// with [PaymentInstructions.fromDb]. Empty = none configured.
@override@JsonKey() Map<String, dynamic> get paymentInstructions {
  if (_paymentInstructions is EqualUnmodifiableMapView) return _paymentInstructions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_paymentInstructions);
}

/// Owner-set WhatsApp group invite link (#231), shown to members in
/// the directory (#232); '' = no group configured. Shape-checked
/// against [WhatsappGroupRules.linkPrefix] (0029 column check).
@override@JsonKey() final  String whatsappGroup;
/// Postal address (0060): printed on invoices; owner-edited.
@override@JsonKey() final  String address;
/// LEGAL IDENTITY (0069) — what an EN 16931 e-invoice cannot omit.
/// [vatRegime] is the wire value of `VatRegime` (money domain) and
/// decides which of the two identifiers is required: category `E`
/// needs [vatId] (BR-E-02), category `O` needs [legalId] and must NOT
/// carry a VAT id at all (BR-O-02 / BR-CO-26).
@override@JsonKey() final  String vatRegime;
/// BT-31, the VAT identification number ('FR12345678901').
@override@JsonKey() final  String vatId;
/// BT-30, the company register identifier (SIREN/SIRET, HRB, CIF…).
@override@JsonKey() final  String legalId;
/// BT-120, why no VAT is charged, in the owner's own words. Category
/// `E` requires a reason; a VATEX code is added automatically where
/// the code lists have one.
@override@JsonKey() final  String taxExemptionReason;
/// Structured address parts (BT-35/37/38) beside [address], which
/// stays the free-text block the PDF letterhead prints.
@override@JsonKey() final  String street;
@override@JsonKey() final  String city;
@override@JsonKey() final  String postalCode;
/// The account VAT is booked to in the FEC export (0072); '' = the
/// French default 445710. Only the accounting export reads it — the
/// app books nothing itself.
@override@JsonKey() final  String vatAccount;
/// Desk fill opacity percentage (0040): 100 = solid (default), lower
/// makes desks translucent so a level's background photo shows through.
/// Clamped 20..100 by the column check.
@override@JsonKey() final  int deskOpacity;
/// Owner-configured invitation message template (0049) with {tag}
/// placeholders (see [InvitationTags]); '' = use the app's localized
/// default message. Max length enforced by the column check.
@override@JsonKey() final  String invitationTemplate;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCopyWith<_Workspace> get copyWith => __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other._featureFlags, _featureFlags)&&(identical(other.devMode, devMode) || other.devMode == devMode)&&const DeepCollectionEquality().equals(other._paymentInstructions, _paymentInstructions)&&(identical(other.whatsappGroup, whatsappGroup) || other.whatsappGroup == whatsappGroup)&&(identical(other.address, address) || other.address == address)&&(identical(other.vatRegime, vatRegime) || other.vatRegime == vatRegime)&&(identical(other.vatId, vatId) || other.vatId == vatId)&&(identical(other.legalId, legalId) || other.legalId == legalId)&&(identical(other.taxExemptionReason, taxExemptionReason) || other.taxExemptionReason == taxExemptionReason)&&(identical(other.street, street) || other.street == street)&&(identical(other.city, city) || other.city == city)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.vatAccount, vatAccount) || other.vatAccount == vatAccount)&&(identical(other.deskOpacity, deskOpacity) || other.deskOpacity == deskOpacity)&&(identical(other.invitationTemplate, invitationTemplate) || other.invitationTemplate == invitationTemplate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,countryCode,currencyCode,timezone,inviteCode,const DeepCollectionEquality().hash(_featureFlags),devMode,const DeepCollectionEquality().hash(_paymentInstructions),whatsappGroup,address,vatRegime,vatId,legalId,taxExemptionReason,street,city,postalCode,vatAccount,deskOpacity,invitationTemplate]);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, countryCode: $countryCode, currencyCode: $currencyCode, timezone: $timezone, inviteCode: $inviteCode, featureFlags: $featureFlags, devMode: $devMode, paymentInstructions: $paymentInstructions, whatsappGroup: $whatsappGroup, address: $address, vatRegime: $vatRegime, vatId: $vatId, legalId: $legalId, taxExemptionReason: $taxExemptionReason, street: $street, city: $city, postalCode: $postalCode, vatAccount: $vatAccount, deskOpacity: $deskOpacity, invitationTemplate: $invitationTemplate)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(_Workspace value, $Res Function(_Workspace) _then) = __$WorkspaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String countryCode, String currencyCode, String timezone, String inviteCode, Map<String, dynamic> featureFlags, bool devMode, Map<String, dynamic> paymentInstructions, String whatsappGroup, String address, String vatRegime, String vatId, String legalId, String taxExemptionReason, String street, String city, String postalCode, String vatAccount, int deskOpacity, String invitationTemplate
});




}
/// @nodoc
class __$WorkspaceCopyWithImpl<$Res>
    implements _$WorkspaceCopyWith<$Res> {
  __$WorkspaceCopyWithImpl(this._self, this._then);

  final _Workspace _self;
  final $Res Function(_Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? inviteCode = null,Object? featureFlags = null,Object? devMode = null,Object? paymentInstructions = null,Object? whatsappGroup = null,Object? address = null,Object? vatRegime = null,Object? vatId = null,Object? legalId = null,Object? taxExemptionReason = null,Object? street = null,Object? city = null,Object? postalCode = null,Object? vatAccount = null,Object? deskOpacity = null,Object? invitationTemplate = null,}) {
  return _then(_Workspace(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self._featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,devMode: null == devMode ? _self.devMode : devMode // ignore: cast_nullable_to_non_nullable
as bool,paymentInstructions: null == paymentInstructions ? _self._paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,whatsappGroup: null == whatsappGroup ? _self.whatsappGroup : whatsappGroup // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,vatRegime: null == vatRegime ? _self.vatRegime : vatRegime // ignore: cast_nullable_to_non_nullable
as String,vatId: null == vatId ? _self.vatId : vatId // ignore: cast_nullable_to_non_nullable
as String,legalId: null == legalId ? _self.legalId : legalId // ignore: cast_nullable_to_non_nullable
as String,taxExemptionReason: null == taxExemptionReason ? _self.taxExemptionReason : taxExemptionReason // ignore: cast_nullable_to_non_nullable
as String,street: null == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,vatAccount: null == vatAccount ? _self.vatAccount : vatAccount // ignore: cast_nullable_to_non_nullable
as String,deskOpacity: null == deskOpacity ? _self.deskOpacity : deskOpacity // ignore: cast_nullable_to_non_nullable
as int,invitationTemplate: null == invitationTemplate ? _self.invitationTemplate : invitationTemplate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
