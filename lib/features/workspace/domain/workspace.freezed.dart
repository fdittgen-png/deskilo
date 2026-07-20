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
 Map<String, dynamic> get featureFlags;/// Owner-configured payment instructions (#155) as stored — decode
/// with [PaymentInstructions.fromDb]. Empty = none configured.
 Map<String, dynamic> get paymentInstructions;/// Owner-set WhatsApp group invite link (#231), shown to members in
/// the directory (#232); '' = no group configured. Shape-checked
/// against [WhatsappGroupRules.linkPrefix] (0029 column check).
 String get whatsappGroup;/// Desk fill opacity percentage (0040): 100 = solid (default), lower
/// makes desks translucent so a level's background photo shows through.
/// Clamped 20..100 by the column check.
 int get deskOpacity;
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<Workspace> get copyWith => _$WorkspaceCopyWithImpl<Workspace>(this as Workspace, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other.featureFlags, featureFlags)&&const DeepCollectionEquality().equals(other.paymentInstructions, paymentInstructions)&&(identical(other.whatsappGroup, whatsappGroup) || other.whatsappGroup == whatsappGroup)&&(identical(other.deskOpacity, deskOpacity) || other.deskOpacity == deskOpacity));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,countryCode,currencyCode,timezone,inviteCode,const DeepCollectionEquality().hash(featureFlags),const DeepCollectionEquality().hash(paymentInstructions),whatsappGroup,deskOpacity);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, countryCode: $countryCode, currencyCode: $currencyCode, timezone: $timezone, inviteCode: $inviteCode, featureFlags: $featureFlags, paymentInstructions: $paymentInstructions, whatsappGroup: $whatsappGroup, deskOpacity: $deskOpacity)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCopyWith<$Res>  {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) _then) = _$WorkspaceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String countryCode, String currencyCode, String timezone, String inviteCode, Map<String, dynamic> featureFlags, Map<String, dynamic> paymentInstructions, String whatsappGroup, int deskOpacity
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? inviteCode = null,Object? featureFlags = null,Object? paymentInstructions = null,Object? whatsappGroup = null,Object? deskOpacity = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self.featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,paymentInstructions: null == paymentInstructions ? _self.paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,whatsappGroup: null == whatsappGroup ? _self.whatsappGroup : whatsappGroup // ignore: cast_nullable_to_non_nullable
as String,deskOpacity: null == deskOpacity ? _self.deskOpacity : deskOpacity // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  int deskOpacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.paymentInstructions,_that.whatsappGroup,_that.deskOpacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  int deskOpacity)  $default,) {final _that = this;
switch (_that) {
case _Workspace():
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.paymentInstructions,_that.whatsappGroup,_that.deskOpacity);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String countryCode,  String currencyCode,  String timezone,  String inviteCode,  Map<String, dynamic> featureFlags,  Map<String, dynamic> paymentInstructions,  String whatsappGroup,  int deskOpacity)?  $default,) {final _that = this;
switch (_that) {
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.inviteCode,_that.featureFlags,_that.paymentInstructions,_that.whatsappGroup,_that.deskOpacity);case _:
  return null;

}
}

}

/// @nodoc


class _Workspace extends Workspace {
  const _Workspace({required this.id, required this.name, required this.countryCode, required this.currencyCode, required this.timezone, required this.inviteCode, final  Map<String, dynamic> featureFlags = const <String, dynamic>{}, final  Map<String, dynamic> paymentInstructions = const <String, dynamic>{}, this.whatsappGroup = '', this.deskOpacity = 100}): _featureFlags = featureFlags,_paymentInstructions = paymentInstructions,super._();
  

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
/// Desk fill opacity percentage (0040): 100 = solid (default), lower
/// makes desks translucent so a level's background photo shows through.
/// Clamped 20..100 by the column check.
@override@JsonKey() final  int deskOpacity;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCopyWith<_Workspace> get copyWith => __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&const DeepCollectionEquality().equals(other._featureFlags, _featureFlags)&&const DeepCollectionEquality().equals(other._paymentInstructions, _paymentInstructions)&&(identical(other.whatsappGroup, whatsappGroup) || other.whatsappGroup == whatsappGroup)&&(identical(other.deskOpacity, deskOpacity) || other.deskOpacity == deskOpacity));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,countryCode,currencyCode,timezone,inviteCode,const DeepCollectionEquality().hash(_featureFlags),const DeepCollectionEquality().hash(_paymentInstructions),whatsappGroup,deskOpacity);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, countryCode: $countryCode, currencyCode: $currencyCode, timezone: $timezone, inviteCode: $inviteCode, featureFlags: $featureFlags, paymentInstructions: $paymentInstructions, whatsappGroup: $whatsappGroup, deskOpacity: $deskOpacity)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(_Workspace value, $Res Function(_Workspace) _then) = __$WorkspaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String countryCode, String currencyCode, String timezone, String inviteCode, Map<String, dynamic> featureFlags, Map<String, dynamic> paymentInstructions, String whatsappGroup, int deskOpacity
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? inviteCode = null,Object? featureFlags = null,Object? paymentInstructions = null,Object? whatsappGroup = null,Object? deskOpacity = null,}) {
  return _then(_Workspace(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,inviteCode: null == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self._featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,paymentInstructions: null == paymentInstructions ? _self._paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,whatsappGroup: null == whatsappGroup ? _self.whatsappGroup : whatsappGroup // ignore: cast_nullable_to_non_nullable
as String,deskOpacity: null == deskOpacity ? _self.deskOpacity : deskOpacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
