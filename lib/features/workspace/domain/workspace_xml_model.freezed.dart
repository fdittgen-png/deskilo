// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_xml_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkspaceXmlSettings {

 String get name; String get countryCode; String get currencyCode; String get timezone;/// Explicit per-workspace feature overrides. Absent key = registry
/// default, exactly like `Workspace.featureFlags`.
 Map<String, bool> get featureFlags;/// Owner payment instructions as opaque key/value pairs (`iban`,
/// `paypal_me`, `reference`, ...). Empty values are dropped.
 Map<String, String> get paymentInstructions;/// The brand seed as `#RRGGBB`, null when the document carries none.
/// The import writes it through `set_workspace_branding`, which
/// validates the shape; the contrast rule is the app's, at import too.
 String? get brandColor;
/// Create a copy of WorkspaceXmlSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlSettingsCopyWith<WorkspaceXmlSettings> get copyWith => _$WorkspaceXmlSettingsCopyWithImpl<WorkspaceXmlSettings>(this as WorkspaceXmlSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlSettings&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.countryCode, _this.countryCode) || other.countryCode == _this.countryCode)&&(identical(other.currencyCode, _this.currencyCode) || other.currencyCode == _this.currencyCode)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&const DeepCollectionEquality().equals(other.featureFlags, _this.featureFlags)&&const DeepCollectionEquality().equals(other.paymentInstructions, _this.paymentInstructions)&&(identical(other.brandColor, _this.brandColor) || other.brandColor == _this.brandColor));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlSettings;
  return Object.hash(runtimeType,_this.name,_this.countryCode,_this.currencyCode,_this.timezone,const DeepCollectionEquality().hash(_this.featureFlags),const DeepCollectionEquality().hash(_this.paymentInstructions),_this.brandColor);
}

@override
String toString() {
  final _this = this as WorkspaceXmlSettings;
  return 'WorkspaceXmlSettings(name: ${_this.name}, countryCode: ${_this.countryCode}, currencyCode: ${_this.currencyCode}, timezone: ${_this.timezone}, featureFlags: ${_this.featureFlags}, paymentInstructions: ${_this.paymentInstructions}, brandColor: ${_this.brandColor})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlSettingsCopyWith<$Res>  {
  factory $WorkspaceXmlSettingsCopyWith(WorkspaceXmlSettings value, $Res Function(WorkspaceXmlSettings) _then) = _$WorkspaceXmlSettingsCopyWithImpl;
@useResult
$Res call({
 String name, String countryCode, String currencyCode, String timezone, Map<String, bool> featureFlags, Map<String, String> paymentInstructions, String? brandColor
});




}
/// @nodoc
class _$WorkspaceXmlSettingsCopyWithImpl<$Res>
    implements $WorkspaceXmlSettingsCopyWith<$Res> {
  _$WorkspaceXmlSettingsCopyWithImpl(this._self, this._then);

  final WorkspaceXmlSettings _self;
  final $Res Function(WorkspaceXmlSettings) _then;

/// Create a copy of WorkspaceXmlSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? featureFlags = null,Object? paymentInstructions = null,Object? brandColor = freezed,}) {
  return _then(WorkspaceXmlSettings(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self.featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,paymentInstructions: null == paymentInstructions ? _self.paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,brandColor: freezed == brandColor ? _self.brandColor : brandColor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceXmlSettings].
extension WorkspaceXmlSettingsPatterns on WorkspaceXmlSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlSettings value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlSettings value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String countryCode,  String currencyCode,  String timezone,  Map<String, bool> featureFlags,  Map<String, String> paymentInstructions,  String? brandColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlSettings() when $default != null:
return $default(_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.featureFlags,_that.paymentInstructions,_that.brandColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String countryCode,  String currencyCode,  String timezone,  Map<String, bool> featureFlags,  Map<String, String> paymentInstructions,  String? brandColor)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlSettings():
return $default(_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.featureFlags,_that.paymentInstructions,_that.brandColor);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String countryCode,  String currencyCode,  String timezone,  Map<String, bool> featureFlags,  Map<String, String> paymentInstructions,  String? brandColor)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlSettings() when $default != null:
return $default(_that.name,_that.countryCode,_that.currencyCode,_that.timezone,_that.featureFlags,_that.paymentInstructions,_that.brandColor);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlSettings implements WorkspaceXmlSettings {
  const _WorkspaceXmlSettings({required this.name, required this.countryCode, required this.currencyCode, required this.timezone,  Map<String, bool> featureFlags = const <String, bool>{},  Map<String, String> paymentInstructions = const <String, String>{}, this.brandColor}): _featureFlags = featureFlags,_paymentInstructions = paymentInstructions;
  

@override final  String name;
@override final  String countryCode;
@override final  String currencyCode;
@override final  String timezone;
/// Explicit per-workspace feature overrides. Absent key = registry
/// default, exactly like `Workspace.featureFlags`.
 final  Map<String, bool> _featureFlags;
/// Explicit per-workspace feature overrides. Absent key = registry
/// default, exactly like `Workspace.featureFlags`.
@override@JsonKey() Map<String, bool> get featureFlags {
  if (_featureFlags is EqualUnmodifiableMapView) return _featureFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_featureFlags);
}

/// Owner payment instructions as opaque key/value pairs (`iban`,
/// `paypal_me`, `reference`, ...). Empty values are dropped.
 final  Map<String, String> _paymentInstructions;
/// Owner payment instructions as opaque key/value pairs (`iban`,
/// `paypal_me`, `reference`, ...). Empty values are dropped.
@override@JsonKey() Map<String, String> get paymentInstructions {
  if (_paymentInstructions is EqualUnmodifiableMapView) return _paymentInstructions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_paymentInstructions);
}

/// The brand seed as `#RRGGBB`, null when the document carries none.
/// The import writes it through `set_workspace_branding`, which
/// validates the shape; the contrast rule is the app's, at import too.
@override final  String? brandColor;

/// Create a copy of WorkspaceXmlSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlSettingsCopyWith<_WorkspaceXmlSettings> get copyWith => __$WorkspaceXmlSettingsCopyWithImpl<_WorkspaceXmlSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlSettings&&(identical(other.name, name) || other.name == name)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&const DeepCollectionEquality().equals(other.featureFlags, _featureFlags)&&const DeepCollectionEquality().equals(other.paymentInstructions, _paymentInstructions)&&(identical(other.brandColor, brandColor) || other.brandColor == brandColor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,countryCode,currencyCode,timezone,const DeepCollectionEquality().hash(_featureFlags),const DeepCollectionEquality().hash(_paymentInstructions),brandColor);
}

@override
String toString() {
    return 'WorkspaceXmlSettings(name: $name, countryCode: $countryCode, currencyCode: $currencyCode, timezone: $timezone, featureFlags: $featureFlags, paymentInstructions: $paymentInstructions, brandColor: $brandColor)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlSettingsCopyWith<$Res> implements $WorkspaceXmlSettingsCopyWith<$Res> {
  factory _$WorkspaceXmlSettingsCopyWith(_WorkspaceXmlSettings value, $Res Function(_WorkspaceXmlSettings) _then) = __$WorkspaceXmlSettingsCopyWithImpl;
@override @useResult
$Res call({
 String name, String countryCode, String currencyCode, String timezone, Map<String, bool> featureFlags, Map<String, String> paymentInstructions, String? brandColor
});




}
/// @nodoc
class __$WorkspaceXmlSettingsCopyWithImpl<$Res>
    implements _$WorkspaceXmlSettingsCopyWith<$Res> {
  __$WorkspaceXmlSettingsCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlSettings _self;
  final $Res Function(_WorkspaceXmlSettings) _then;

/// Create a copy of WorkspaceXmlSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? countryCode = null,Object? currencyCode = null,Object? timezone = null,Object? featureFlags = null,Object? paymentInstructions = null,Object? brandColor = freezed,}) {
  return _then(_WorkspaceXmlSettings(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,featureFlags: null == featureFlags ? _self._featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,paymentInstructions: null == paymentInstructions ? _self._paymentInstructions : paymentInstructions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,brandColor: freezed == brandColor ? _self.brandColor : brandColor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$WorkspaceXmlAccessory {

 String get name; int get supplementCents; bool get active; int get sortOrder;/// The VAT rate's LABEL (v3) — empty when the accessory carries none
/// or the file predates v3.
 String get vatRate;
/// Create a copy of WorkspaceXmlAccessory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlAccessoryCopyWith<WorkspaceXmlAccessory> get copyWith => _$WorkspaceXmlAccessoryCopyWithImpl<WorkspaceXmlAccessory>(this as WorkspaceXmlAccessory, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlAccessory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlAccessory&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.supplementCents, _this.supplementCents) || other.supplementCents == _this.supplementCents)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.vatRate, _this.vatRate) || other.vatRate == _this.vatRate));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlAccessory;
  return Object.hash(runtimeType,_this.name,_this.supplementCents,_this.active,_this.sortOrder,_this.vatRate);
}

@override
String toString() {
  final _this = this as WorkspaceXmlAccessory;
  return 'WorkspaceXmlAccessory(name: ${_this.name}, supplementCents: ${_this.supplementCents}, active: ${_this.active}, sortOrder: ${_this.sortOrder}, vatRate: ${_this.vatRate})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlAccessoryCopyWith<$Res>  {
  factory $WorkspaceXmlAccessoryCopyWith(WorkspaceXmlAccessory value, $Res Function(WorkspaceXmlAccessory) _then) = _$WorkspaceXmlAccessoryCopyWithImpl;
@useResult
$Res call({
 String name, int supplementCents, bool active, int sortOrder, String vatRate
});




}
/// @nodoc
class _$WorkspaceXmlAccessoryCopyWithImpl<$Res>
    implements $WorkspaceXmlAccessoryCopyWith<$Res> {
  _$WorkspaceXmlAccessoryCopyWithImpl(this._self, this._then);

  final WorkspaceXmlAccessory _self;
  final $Res Function(WorkspaceXmlAccessory) _then;

/// Create a copy of WorkspaceXmlAccessory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? supplementCents = null,Object? active = null,Object? sortOrder = null,Object? vatRate = null,}) {
  return _then(WorkspaceXmlAccessory(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supplementCents: null == supplementCents ? _self.supplementCents : supplementCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,vatRate: null == vatRate ? _self.vatRate : vatRate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceXmlAccessory].
extension WorkspaceXmlAccessoryPatterns on WorkspaceXmlAccessory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlAccessory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlAccessory value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlAccessory value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int supplementCents,  bool active,  int sortOrder,  String vatRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory() when $default != null:
return $default(_that.name,_that.supplementCents,_that.active,_that.sortOrder,_that.vatRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int supplementCents,  bool active,  int sortOrder,  String vatRate)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory():
return $default(_that.name,_that.supplementCents,_that.active,_that.sortOrder,_that.vatRate);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int supplementCents,  bool active,  int sortOrder,  String vatRate)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlAccessory() when $default != null:
return $default(_that.name,_that.supplementCents,_that.active,_that.sortOrder,_that.vatRate);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlAccessory implements WorkspaceXmlAccessory {
  const _WorkspaceXmlAccessory({required this.name, this.supplementCents = 0, this.active = true, this.sortOrder = 0, this.vatRate = ''});
  

@override final  String name;
@override@JsonKey() final  int supplementCents;
@override@JsonKey() final  bool active;
@override@JsonKey() final  int sortOrder;
/// The VAT rate's LABEL (v3) — empty when the accessory carries none
/// or the file predates v3.
@override@JsonKey() final  String vatRate;

/// Create a copy of WorkspaceXmlAccessory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlAccessoryCopyWith<_WorkspaceXmlAccessory> get copyWith => __$WorkspaceXmlAccessoryCopyWithImpl<_WorkspaceXmlAccessory>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlAccessory&&(identical(other.name, name) || other.name == name)&&(identical(other.supplementCents, supplementCents) || other.supplementCents == supplementCents)&&(identical(other.active, active) || other.active == active)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.vatRate, vatRate) || other.vatRate == vatRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,supplementCents,active,sortOrder,vatRate);
}

@override
String toString() {
    return 'WorkspaceXmlAccessory(name: $name, supplementCents: $supplementCents, active: $active, sortOrder: $sortOrder, vatRate: $vatRate)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlAccessoryCopyWith<$Res> implements $WorkspaceXmlAccessoryCopyWith<$Res> {
  factory _$WorkspaceXmlAccessoryCopyWith(_WorkspaceXmlAccessory value, $Res Function(_WorkspaceXmlAccessory) _then) = __$WorkspaceXmlAccessoryCopyWithImpl;
@override @useResult
$Res call({
 String name, int supplementCents, bool active, int sortOrder, String vatRate
});




}
/// @nodoc
class __$WorkspaceXmlAccessoryCopyWithImpl<$Res>
    implements _$WorkspaceXmlAccessoryCopyWith<$Res> {
  __$WorkspaceXmlAccessoryCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlAccessory _self;
  final $Res Function(_WorkspaceXmlAccessory) _then;

/// Create a copy of WorkspaceXmlAccessory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? supplementCents = null,Object? active = null,Object? sortOrder = null,Object? vatRate = null,}) {
  return _then(_WorkspaceXmlAccessory(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,supplementCents: null == supplementCents ? _self.supplementCents : supplementCents // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,vatRate: null == vatRate ? _self.vatRate : vatRate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$WorkspaceXmlSeat {

 String get name; int get x; int get y; SeatOrientation get orientation; String get chair; List<String> get amenities;/// Catalog references by name (v2) — always empty in a v1 file.
 List<String> get accessoryNames; DateTime? get blockedFrom; DateTime? get blockedTo;/// The seat's NFC tag identifier (v3), empty when untagged.
 String get nfcUid;/// v4: a desk seat, a meeting room or a parking bay; a room's
/// capacity, a bay's kind, the place's own booking slot.
 ResourceKind get resourceKind; int? get capacity; ParkingKind? get parkingKind; int? get slotMinutes;
/// Create a copy of WorkspaceXmlSeat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlSeatCopyWith<WorkspaceXmlSeat> get copyWith => _$WorkspaceXmlSeatCopyWithImpl<WorkspaceXmlSeat>(this as WorkspaceXmlSeat, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlSeat;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlSeat&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.orientation, _this.orientation) || other.orientation == _this.orientation)&&(identical(other.chair, _this.chair) || other.chair == _this.chair)&&const DeepCollectionEquality().equals(other.amenities, _this.amenities)&&const DeepCollectionEquality().equals(other.accessoryNames, _this.accessoryNames)&&(identical(other.blockedFrom, _this.blockedFrom) || other.blockedFrom == _this.blockedFrom)&&(identical(other.blockedTo, _this.blockedTo) || other.blockedTo == _this.blockedTo)&&(identical(other.nfcUid, _this.nfcUid) || other.nfcUid == _this.nfcUid)&&(identical(other.resourceKind, _this.resourceKind) || other.resourceKind == _this.resourceKind)&&(identical(other.capacity, _this.capacity) || other.capacity == _this.capacity)&&(identical(other.parkingKind, _this.parkingKind) || other.parkingKind == _this.parkingKind)&&(identical(other.slotMinutes, _this.slotMinutes) || other.slotMinutes == _this.slotMinutes));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlSeat;
  return Object.hash(runtimeType,_this.name,_this.x,_this.y,_this.orientation,_this.chair,const DeepCollectionEquality().hash(_this.amenities),const DeepCollectionEquality().hash(_this.accessoryNames),_this.blockedFrom,_this.blockedTo,_this.nfcUid,_this.resourceKind,_this.capacity,_this.parkingKind,_this.slotMinutes);
}

@override
String toString() {
  final _this = this as WorkspaceXmlSeat;
  return 'WorkspaceXmlSeat(name: ${_this.name}, x: ${_this.x}, y: ${_this.y}, orientation: ${_this.orientation}, chair: ${_this.chair}, amenities: ${_this.amenities}, accessoryNames: ${_this.accessoryNames}, blockedFrom: ${_this.blockedFrom}, blockedTo: ${_this.blockedTo}, nfcUid: ${_this.nfcUid}, resourceKind: ${_this.resourceKind}, capacity: ${_this.capacity}, parkingKind: ${_this.parkingKind}, slotMinutes: ${_this.slotMinutes})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlSeatCopyWith<$Res>  {
  factory $WorkspaceXmlSeatCopyWith(WorkspaceXmlSeat value, $Res Function(WorkspaceXmlSeat) _then) = _$WorkspaceXmlSeatCopyWithImpl;
@useResult
$Res call({
 String name, int x, int y, SeatOrientation orientation, String chair, List<String> amenities, List<String> accessoryNames, DateTime? blockedFrom, DateTime? blockedTo, String nfcUid, ResourceKind resourceKind, int? capacity, ParkingKind? parkingKind, int? slotMinutes
});




}
/// @nodoc
class _$WorkspaceXmlSeatCopyWithImpl<$Res>
    implements $WorkspaceXmlSeatCopyWith<$Res> {
  _$WorkspaceXmlSeatCopyWithImpl(this._self, this._then);

  final WorkspaceXmlSeat _self;
  final $Res Function(WorkspaceXmlSeat) _then;

/// Create a copy of WorkspaceXmlSeat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? x = null,Object? y = null,Object? orientation = null,Object? chair = null,Object? amenities = null,Object? accessoryNames = null,Object? blockedFrom = freezed,Object? blockedTo = freezed,Object? nfcUid = null,Object? resourceKind = null,Object? capacity = freezed,Object? parkingKind = freezed,Object? slotMinutes = freezed,}) {
  return _then(WorkspaceXmlSeat(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as SeatOrientation,chair: null == chair ? _self.chair : chair // ignore: cast_nullable_to_non_nullable
as String,amenities: null == amenities ? _self.amenities : amenities // ignore: cast_nullable_to_non_nullable
as List<String>,accessoryNames: null == accessoryNames ? _self.accessoryNames : accessoryNames // ignore: cast_nullable_to_non_nullable
as List<String>,blockedFrom: freezed == blockedFrom ? _self.blockedFrom : blockedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,blockedTo: freezed == blockedTo ? _self.blockedTo : blockedTo // ignore: cast_nullable_to_non_nullable
as DateTime?,nfcUid: null == nfcUid ? _self.nfcUid : nfcUid // ignore: cast_nullable_to_non_nullable
as String,resourceKind: null == resourceKind ? _self.resourceKind : resourceKind // ignore: cast_nullable_to_non_nullable
as ResourceKind,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,parkingKind: freezed == parkingKind ? _self.parkingKind : parkingKind // ignore: cast_nullable_to_non_nullable
as ParkingKind?,slotMinutes: freezed == slotMinutes ? _self.slotMinutes : slotMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceXmlSeat].
extension WorkspaceXmlSeatPatterns on WorkspaceXmlSeat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlSeat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlSeat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlSeat value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlSeat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlSeat value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlSeat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  List<String> accessoryNames,  DateTime? blockedFrom,  DateTime? blockedTo,  String nfcUid,  ResourceKind resourceKind,  int? capacity,  ParkingKind? parkingKind,  int? slotMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlSeat() when $default != null:
return $default(_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.accessoryNames,_that.blockedFrom,_that.blockedTo,_that.nfcUid,_that.resourceKind,_that.capacity,_that.parkingKind,_that.slotMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  List<String> accessoryNames,  DateTime? blockedFrom,  DateTime? blockedTo,  String nfcUid,  ResourceKind resourceKind,  int? capacity,  ParkingKind? parkingKind,  int? slotMinutes)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlSeat():
return $default(_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.accessoryNames,_that.blockedFrom,_that.blockedTo,_that.nfcUid,_that.resourceKind,_that.capacity,_that.parkingKind,_that.slotMinutes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int x,  int y,  SeatOrientation orientation,  String chair,  List<String> amenities,  List<String> accessoryNames,  DateTime? blockedFrom,  DateTime? blockedTo,  String nfcUid,  ResourceKind resourceKind,  int? capacity,  ParkingKind? parkingKind,  int? slotMinutes)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlSeat() when $default != null:
return $default(_that.name,_that.x,_that.y,_that.orientation,_that.chair,_that.amenities,_that.accessoryNames,_that.blockedFrom,_that.blockedTo,_that.nfcUid,_that.resourceKind,_that.capacity,_that.parkingKind,_that.slotMinutes);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlSeat extends WorkspaceXmlSeat {
  const _WorkspaceXmlSeat({required this.name, required this.x, required this.y, required this.orientation, this.chair = '',  List<String> amenities = const <String>[],  List<String> accessoryNames = const <String>[], this.blockedFrom, this.blockedTo, this.nfcUid = '', this.resourceKind = ResourceKind.seat, this.capacity, this.parkingKind, this.slotMinutes}): _amenities = amenities,_accessoryNames = accessoryNames,super._();
  

@override final  String name;
@override final  int x;
@override final  int y;
@override final  SeatOrientation orientation;
@override@JsonKey() final  String chair;
 final  List<String> _amenities;
@override@JsonKey() List<String> get amenities {
  if (_amenities is EqualUnmodifiableListView) return _amenities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_amenities);
}

/// Catalog references by name (v2) — always empty in a v1 file.
 final  List<String> _accessoryNames;
/// Catalog references by name (v2) — always empty in a v1 file.
@override@JsonKey() List<String> get accessoryNames {
  if (_accessoryNames is EqualUnmodifiableListView) return _accessoryNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accessoryNames);
}

@override final  DateTime? blockedFrom;
@override final  DateTime? blockedTo;
/// The seat's NFC tag identifier (v3), empty when untagged.
@override@JsonKey() final  String nfcUid;
/// v4: a desk seat, a meeting room or a parking bay; a room's
/// capacity, a bay's kind, the place's own booking slot.
@override@JsonKey() final  ResourceKind resourceKind;
@override final  int? capacity;
@override final  ParkingKind? parkingKind;
@override final  int? slotMinutes;

/// Create a copy of WorkspaceXmlSeat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlSeatCopyWith<_WorkspaceXmlSeat> get copyWith => __$WorkspaceXmlSeatCopyWithImpl<_WorkspaceXmlSeat>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlSeat&&(identical(other.name, name) || other.name == name)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.orientation, orientation) || other.orientation == orientation)&&(identical(other.chair, chair) || other.chair == chair)&&const DeepCollectionEquality().equals(other.amenities, _amenities)&&const DeepCollectionEquality().equals(other.accessoryNames, _accessoryNames)&&(identical(other.blockedFrom, blockedFrom) || other.blockedFrom == blockedFrom)&&(identical(other.blockedTo, blockedTo) || other.blockedTo == blockedTo)&&(identical(other.nfcUid, nfcUid) || other.nfcUid == nfcUid)&&(identical(other.resourceKind, resourceKind) || other.resourceKind == resourceKind)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.parkingKind, parkingKind) || other.parkingKind == parkingKind)&&(identical(other.slotMinutes, slotMinutes) || other.slotMinutes == slotMinutes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,x,y,orientation,chair,const DeepCollectionEquality().hash(_amenities),const DeepCollectionEquality().hash(_accessoryNames),blockedFrom,blockedTo,nfcUid,resourceKind,capacity,parkingKind,slotMinutes);
}

@override
String toString() {
    return 'WorkspaceXmlSeat(name: $name, x: $x, y: $y, orientation: $orientation, chair: $chair, amenities: $amenities, accessoryNames: $accessoryNames, blockedFrom: $blockedFrom, blockedTo: $blockedTo, nfcUid: $nfcUid, resourceKind: $resourceKind, capacity: $capacity, parkingKind: $parkingKind, slotMinutes: $slotMinutes)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlSeatCopyWith<$Res> implements $WorkspaceXmlSeatCopyWith<$Res> {
  factory _$WorkspaceXmlSeatCopyWith(_WorkspaceXmlSeat value, $Res Function(_WorkspaceXmlSeat) _then) = __$WorkspaceXmlSeatCopyWithImpl;
@override @useResult
$Res call({
 String name, int x, int y, SeatOrientation orientation, String chair, List<String> amenities, List<String> accessoryNames, DateTime? blockedFrom, DateTime? blockedTo, String nfcUid, ResourceKind resourceKind, int? capacity, ParkingKind? parkingKind, int? slotMinutes
});




}
/// @nodoc
class __$WorkspaceXmlSeatCopyWithImpl<$Res>
    implements _$WorkspaceXmlSeatCopyWith<$Res> {
  __$WorkspaceXmlSeatCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlSeat _self;
  final $Res Function(_WorkspaceXmlSeat) _then;

/// Create a copy of WorkspaceXmlSeat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? x = null,Object? y = null,Object? orientation = null,Object? chair = null,Object? amenities = null,Object? accessoryNames = null,Object? blockedFrom = freezed,Object? blockedTo = freezed,Object? nfcUid = null,Object? resourceKind = null,Object? capacity = freezed,Object? parkingKind = freezed,Object? slotMinutes = freezed,}) {
  return _then(_WorkspaceXmlSeat(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,orientation: null == orientation ? _self.orientation : orientation // ignore: cast_nullable_to_non_nullable
as SeatOrientation,chair: null == chair ? _self.chair : chair // ignore: cast_nullable_to_non_nullable
as String,amenities: null == amenities ? _self._amenities : amenities // ignore: cast_nullable_to_non_nullable
as List<String>,accessoryNames: null == accessoryNames ? _self._accessoryNames : accessoryNames // ignore: cast_nullable_to_non_nullable
as List<String>,blockedFrom: freezed == blockedFrom ? _self.blockedFrom : blockedFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,blockedTo: freezed == blockedTo ? _self.blockedTo : blockedTo // ignore: cast_nullable_to_non_nullable
as DateTime?,nfcUid: null == nfcUid ? _self.nfcUid : nfcUid // ignore: cast_nullable_to_non_nullable
as String,resourceKind: null == resourceKind ? _self.resourceKind : resourceKind // ignore: cast_nullable_to_non_nullable
as ResourceKind,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int?,parkingKind: freezed == parkingKind ? _self.parkingKind : parkingKind // ignore: cast_nullable_to_non_nullable
as ParkingKind?,slotMinutes: freezed == slotMinutes ? _self.slotMinutes : slotMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$WorkspaceXmlDesk {

 String get name; GridRect get rect; List<WorkspaceXmlSeat> get seats;/// v3: the desk's own price and whether it books as a whole.
 int get priceCents; bool get bookableAsWhole;
/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlDeskCopyWith<WorkspaceXmlDesk> get copyWith => _$WorkspaceXmlDeskCopyWithImpl<WorkspaceXmlDesk>(this as WorkspaceXmlDesk, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlDesk;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlDesk&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.rect, _this.rect) || other.rect == _this.rect)&&const DeepCollectionEquality().equals(other.seats, _this.seats)&&(identical(other.priceCents, _this.priceCents) || other.priceCents == _this.priceCents)&&(identical(other.bookableAsWhole, _this.bookableAsWhole) || other.bookableAsWhole == _this.bookableAsWhole));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlDesk;
  return Object.hash(runtimeType,_this.name,_this.rect,const DeepCollectionEquality().hash(_this.seats),_this.priceCents,_this.bookableAsWhole);
}

@override
String toString() {
  final _this = this as WorkspaceXmlDesk;
  return 'WorkspaceXmlDesk(name: ${_this.name}, rect: ${_this.rect}, seats: ${_this.seats}, priceCents: ${_this.priceCents}, bookableAsWhole: ${_this.bookableAsWhole})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlDeskCopyWith<$Res>  {
  factory $WorkspaceXmlDeskCopyWith(WorkspaceXmlDesk value, $Res Function(WorkspaceXmlDesk) _then) = _$WorkspaceXmlDeskCopyWithImpl;
@useResult
$Res call({
 String name, GridRect rect, List<WorkspaceXmlSeat> seats, int priceCents, bool bookableAsWhole
});


$GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class _$WorkspaceXmlDeskCopyWithImpl<$Res>
    implements $WorkspaceXmlDeskCopyWith<$Res> {
  _$WorkspaceXmlDeskCopyWithImpl(this._self, this._then);

  final WorkspaceXmlDesk _self;
  final $Res Function(WorkspaceXmlDesk) _then;

/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? rect = null,Object? seats = null,Object? priceCents = null,Object? bookableAsWhole = null,}) {
  return _then(WorkspaceXmlDesk(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlSeat>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceXmlDesk].
extension WorkspaceXmlDeskPatterns on WorkspaceXmlDesk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlDesk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlDesk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlDesk value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlDesk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlDesk value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlDesk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  GridRect rect,  List<WorkspaceXmlSeat> seats,  int priceCents,  bool bookableAsWhole)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlDesk() when $default != null:
return $default(_that.name,_that.rect,_that.seats,_that.priceCents,_that.bookableAsWhole);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  GridRect rect,  List<WorkspaceXmlSeat> seats,  int priceCents,  bool bookableAsWhole)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlDesk():
return $default(_that.name,_that.rect,_that.seats,_that.priceCents,_that.bookableAsWhole);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  GridRect rect,  List<WorkspaceXmlSeat> seats,  int priceCents,  bool bookableAsWhole)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlDesk() when $default != null:
return $default(_that.name,_that.rect,_that.seats,_that.priceCents,_that.bookableAsWhole);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlDesk implements WorkspaceXmlDesk {
  const _WorkspaceXmlDesk({required this.name, required this.rect,  List<WorkspaceXmlSeat> seats = const <WorkspaceXmlSeat>[], this.priceCents = 0, this.bookableAsWhole = false}): _seats = seats;
  

@override final  String name;
@override final  GridRect rect;
 final  List<WorkspaceXmlSeat> _seats;
@override@JsonKey() List<WorkspaceXmlSeat> get seats {
  if (_seats is EqualUnmodifiableListView) return _seats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seats);
}

/// v3: the desk's own price and whether it books as a whole.
@override@JsonKey() final  int priceCents;
@override@JsonKey() final  bool bookableAsWhole;

/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlDeskCopyWith<_WorkspaceXmlDesk> get copyWith => __$WorkspaceXmlDeskCopyWithImpl<_WorkspaceXmlDesk>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlDesk&&(identical(other.name, name) || other.name == name)&&(identical(other.rect, rect) || other.rect == rect)&&const DeepCollectionEquality().equals(other.seats, _seats)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.bookableAsWhole, bookableAsWhole) || other.bookableAsWhole == bookableAsWhole));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,rect,const DeepCollectionEquality().hash(_seats),priceCents,bookableAsWhole);
}

@override
String toString() {
    return 'WorkspaceXmlDesk(name: $name, rect: $rect, seats: $seats, priceCents: $priceCents, bookableAsWhole: $bookableAsWhole)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlDeskCopyWith<$Res> implements $WorkspaceXmlDeskCopyWith<$Res> {
  factory _$WorkspaceXmlDeskCopyWith(_WorkspaceXmlDesk value, $Res Function(_WorkspaceXmlDesk) _then) = __$WorkspaceXmlDeskCopyWithImpl;
@override @useResult
$Res call({
 String name, GridRect rect, List<WorkspaceXmlSeat> seats, int priceCents, bool bookableAsWhole
});


@override $GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class __$WorkspaceXmlDeskCopyWithImpl<$Res>
    implements _$WorkspaceXmlDeskCopyWith<$Res> {
  __$WorkspaceXmlDeskCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlDesk _self;
  final $Res Function(_WorkspaceXmlDesk) _then;

/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? rect = null,Object? seats = null,Object? priceCents = null,Object? bookableAsWhole = null,}) {
  return _then(_WorkspaceXmlDesk(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,seats: null == seats ? _self._seats : seats // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlSeat>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of WorkspaceXmlDesk
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}

/// @nodoc
mixin _$WorkspaceXmlOffice {

 String get name; int get color; bool get bookableAsWhole; GridRect get rect; List<WorkspaceXmlDesk> get desks;/// v3: the office's own price.
 int get priceCents;/// v4: the area's kind by its stored word (`workspace`, `parking`);
/// the server's check refuses any other.
 String get areaKind;
/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlOfficeCopyWith<WorkspaceXmlOffice> get copyWith => _$WorkspaceXmlOfficeCopyWithImpl<WorkspaceXmlOffice>(this as WorkspaceXmlOffice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlOffice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlOffice&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.bookableAsWhole, _this.bookableAsWhole) || other.bookableAsWhole == _this.bookableAsWhole)&&(identical(other.rect, _this.rect) || other.rect == _this.rect)&&const DeepCollectionEquality().equals(other.desks, _this.desks)&&(identical(other.priceCents, _this.priceCents) || other.priceCents == _this.priceCents)&&(identical(other.areaKind, _this.areaKind) || other.areaKind == _this.areaKind));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlOffice;
  return Object.hash(runtimeType,_this.name,_this.color,_this.bookableAsWhole,_this.rect,const DeepCollectionEquality().hash(_this.desks),_this.priceCents,_this.areaKind);
}

@override
String toString() {
  final _this = this as WorkspaceXmlOffice;
  return 'WorkspaceXmlOffice(name: ${_this.name}, color: ${_this.color}, bookableAsWhole: ${_this.bookableAsWhole}, rect: ${_this.rect}, desks: ${_this.desks}, priceCents: ${_this.priceCents}, areaKind: ${_this.areaKind})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlOfficeCopyWith<$Res>  {
  factory $WorkspaceXmlOfficeCopyWith(WorkspaceXmlOffice value, $Res Function(WorkspaceXmlOffice) _then) = _$WorkspaceXmlOfficeCopyWithImpl;
@useResult
$Res call({
 String name, int color, bool bookableAsWhole, GridRect rect, List<WorkspaceXmlDesk> desks, int priceCents, String areaKind
});


$GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class _$WorkspaceXmlOfficeCopyWithImpl<$Res>
    implements $WorkspaceXmlOfficeCopyWith<$Res> {
  _$WorkspaceXmlOfficeCopyWithImpl(this._self, this._then);

  final WorkspaceXmlOffice _self;
  final $Res Function(WorkspaceXmlOffice) _then;

/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? color = null,Object? bookableAsWhole = null,Object? rect = null,Object? desks = null,Object? priceCents = null,Object? areaKind = null,}) {
  return _then(WorkspaceXmlOffice(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,desks: null == desks ? _self.desks : desks // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlDesk>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,areaKind: null == areaKind ? _self.areaKind : areaKind // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceXmlOffice].
extension WorkspaceXmlOfficePatterns on WorkspaceXmlOffice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlOffice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlOffice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlOffice value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlOffice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlOffice value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlOffice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int color,  bool bookableAsWhole,  GridRect rect,  List<WorkspaceXmlDesk> desks,  int priceCents,  String areaKind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlOffice() when $default != null:
return $default(_that.name,_that.color,_that.bookableAsWhole,_that.rect,_that.desks,_that.priceCents,_that.areaKind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int color,  bool bookableAsWhole,  GridRect rect,  List<WorkspaceXmlDesk> desks,  int priceCents,  String areaKind)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlOffice():
return $default(_that.name,_that.color,_that.bookableAsWhole,_that.rect,_that.desks,_that.priceCents,_that.areaKind);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int color,  bool bookableAsWhole,  GridRect rect,  List<WorkspaceXmlDesk> desks,  int priceCents,  String areaKind)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlOffice() when $default != null:
return $default(_that.name,_that.color,_that.bookableAsWhole,_that.rect,_that.desks,_that.priceCents,_that.areaKind);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlOffice implements WorkspaceXmlOffice {
  const _WorkspaceXmlOffice({required this.name, required this.color, required this.bookableAsWhole, required this.rect,  List<WorkspaceXmlDesk> desks = const <WorkspaceXmlDesk>[], this.priceCents = 0, this.areaKind = 'workspace'}): _desks = desks;
  

@override final  String name;
@override final  int color;
@override final  bool bookableAsWhole;
@override final  GridRect rect;
 final  List<WorkspaceXmlDesk> _desks;
@override@JsonKey() List<WorkspaceXmlDesk> get desks {
  if (_desks is EqualUnmodifiableListView) return _desks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_desks);
}

/// v3: the office's own price.
@override@JsonKey() final  int priceCents;
/// v4: the area's kind by its stored word (`workspace`, `parking`);
/// the server's check refuses any other.
@override@JsonKey() final  String areaKind;

/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlOfficeCopyWith<_WorkspaceXmlOffice> get copyWith => __$WorkspaceXmlOfficeCopyWithImpl<_WorkspaceXmlOffice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlOffice&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.bookableAsWhole, bookableAsWhole) || other.bookableAsWhole == bookableAsWhole)&&(identical(other.rect, rect) || other.rect == rect)&&const DeepCollectionEquality().equals(other.desks, _desks)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.areaKind, areaKind) || other.areaKind == areaKind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,color,bookableAsWhole,rect,const DeepCollectionEquality().hash(_desks),priceCents,areaKind);
}

@override
String toString() {
    return 'WorkspaceXmlOffice(name: $name, color: $color, bookableAsWhole: $bookableAsWhole, rect: $rect, desks: $desks, priceCents: $priceCents, areaKind: $areaKind)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlOfficeCopyWith<$Res> implements $WorkspaceXmlOfficeCopyWith<$Res> {
  factory _$WorkspaceXmlOfficeCopyWith(_WorkspaceXmlOffice value, $Res Function(_WorkspaceXmlOffice) _then) = __$WorkspaceXmlOfficeCopyWithImpl;
@override @useResult
$Res call({
 String name, int color, bool bookableAsWhole, GridRect rect, List<WorkspaceXmlDesk> desks, int priceCents, String areaKind
});


@override $GridRectCopyWith<$Res> get rect;

}
/// @nodoc
class __$WorkspaceXmlOfficeCopyWithImpl<$Res>
    implements _$WorkspaceXmlOfficeCopyWith<$Res> {
  __$WorkspaceXmlOfficeCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlOffice _self;
  final $Res Function(_WorkspaceXmlOffice) _then;

/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? color = null,Object? bookableAsWhole = null,Object? rect = null,Object? desks = null,Object? priceCents = null,Object? areaKind = null,}) {
  return _then(_WorkspaceXmlOffice(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,rect: null == rect ? _self.rect : rect // ignore: cast_nullable_to_non_nullable
as GridRect,desks: null == desks ? _self._desks : desks // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlDesk>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,areaKind: null == areaKind ? _self.areaKind : areaKind // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of WorkspaceXmlOffice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridRectCopyWith<$Res> get rect {
  
  return $GridRectCopyWith<$Res>(_self.rect, (value) {
    return _then(_self.copyWith(rect: value));
  });
}
}

/// @nodoc
mixin _$WorkspaceXmlLevel {

 String get name; int get sortOrder; List<WorkspaceXmlOffice> get offices;/// v3: the level's price, whether it books as a whole, and the NAME of
/// the site it belongs to ('' = the workspace's default).
 int get priceCents; bool get bookableAsWhole; String get site;
/// Create a copy of WorkspaceXmlLevel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlLevelCopyWith<WorkspaceXmlLevel> get copyWith => _$WorkspaceXmlLevelCopyWithImpl<WorkspaceXmlLevel>(this as WorkspaceXmlLevel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlLevel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlLevel&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&const DeepCollectionEquality().equals(other.offices, _this.offices)&&(identical(other.priceCents, _this.priceCents) || other.priceCents == _this.priceCents)&&(identical(other.bookableAsWhole, _this.bookableAsWhole) || other.bookableAsWhole == _this.bookableAsWhole)&&(identical(other.site, _this.site) || other.site == _this.site));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlLevel;
  return Object.hash(runtimeType,_this.name,_this.sortOrder,const DeepCollectionEquality().hash(_this.offices),_this.priceCents,_this.bookableAsWhole,_this.site);
}

@override
String toString() {
  final _this = this as WorkspaceXmlLevel;
  return 'WorkspaceXmlLevel(name: ${_this.name}, sortOrder: ${_this.sortOrder}, offices: ${_this.offices}, priceCents: ${_this.priceCents}, bookableAsWhole: ${_this.bookableAsWhole}, site: ${_this.site})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlLevelCopyWith<$Res>  {
  factory $WorkspaceXmlLevelCopyWith(WorkspaceXmlLevel value, $Res Function(WorkspaceXmlLevel) _then) = _$WorkspaceXmlLevelCopyWithImpl;
@useResult
$Res call({
 String name, int sortOrder, List<WorkspaceXmlOffice> offices, int priceCents, bool bookableAsWhole, String site
});




}
/// @nodoc
class _$WorkspaceXmlLevelCopyWithImpl<$Res>
    implements $WorkspaceXmlLevelCopyWith<$Res> {
  _$WorkspaceXmlLevelCopyWithImpl(this._self, this._then);

  final WorkspaceXmlLevel _self;
  final $Res Function(WorkspaceXmlLevel) _then;

/// Create a copy of WorkspaceXmlLevel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? sortOrder = null,Object? offices = null,Object? priceCents = null,Object? bookableAsWhole = null,Object? site = null,}) {
  return _then(WorkspaceXmlLevel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,offices: null == offices ? _self.offices : offices // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlOffice>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceXmlLevel].
extension WorkspaceXmlLevelPatterns on WorkspaceXmlLevel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlLevel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlLevel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlLevel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlLevel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlLevel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlLevel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int sortOrder,  List<WorkspaceXmlOffice> offices,  int priceCents,  bool bookableAsWhole,  String site)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlLevel() when $default != null:
return $default(_that.name,_that.sortOrder,_that.offices,_that.priceCents,_that.bookableAsWhole,_that.site);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int sortOrder,  List<WorkspaceXmlOffice> offices,  int priceCents,  bool bookableAsWhole,  String site)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlLevel():
return $default(_that.name,_that.sortOrder,_that.offices,_that.priceCents,_that.bookableAsWhole,_that.site);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int sortOrder,  List<WorkspaceXmlOffice> offices,  int priceCents,  bool bookableAsWhole,  String site)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlLevel() when $default != null:
return $default(_that.name,_that.sortOrder,_that.offices,_that.priceCents,_that.bookableAsWhole,_that.site);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlLevel implements WorkspaceXmlLevel {
  const _WorkspaceXmlLevel({required this.name, required this.sortOrder,  List<WorkspaceXmlOffice> offices = const <WorkspaceXmlOffice>[], this.priceCents = 0, this.bookableAsWhole = false, this.site = ''}): _offices = offices;
  

@override final  String name;
@override final  int sortOrder;
 final  List<WorkspaceXmlOffice> _offices;
@override@JsonKey() List<WorkspaceXmlOffice> get offices {
  if (_offices is EqualUnmodifiableListView) return _offices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_offices);
}

/// v3: the level's price, whether it books as a whole, and the NAME of
/// the site it belongs to ('' = the workspace's default).
@override@JsonKey() final  int priceCents;
@override@JsonKey() final  bool bookableAsWhole;
@override@JsonKey() final  String site;

/// Create a copy of WorkspaceXmlLevel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlLevelCopyWith<_WorkspaceXmlLevel> get copyWith => __$WorkspaceXmlLevelCopyWithImpl<_WorkspaceXmlLevel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlLevel&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&const DeepCollectionEquality().equals(other.offices, _offices)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.bookableAsWhole, bookableAsWhole) || other.bookableAsWhole == bookableAsWhole)&&(identical(other.site, site) || other.site == site));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,sortOrder,const DeepCollectionEquality().hash(_offices),priceCents,bookableAsWhole,site);
}

@override
String toString() {
    return 'WorkspaceXmlLevel(name: $name, sortOrder: $sortOrder, offices: $offices, priceCents: $priceCents, bookableAsWhole: $bookableAsWhole, site: $site)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlLevelCopyWith<$Res> implements $WorkspaceXmlLevelCopyWith<$Res> {
  factory _$WorkspaceXmlLevelCopyWith(_WorkspaceXmlLevel value, $Res Function(_WorkspaceXmlLevel) _then) = __$WorkspaceXmlLevelCopyWithImpl;
@override @useResult
$Res call({
 String name, int sortOrder, List<WorkspaceXmlOffice> offices, int priceCents, bool bookableAsWhole, String site
});




}
/// @nodoc
class __$WorkspaceXmlLevelCopyWithImpl<$Res>
    implements _$WorkspaceXmlLevelCopyWith<$Res> {
  __$WorkspaceXmlLevelCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlLevel _self;
  final $Res Function(_WorkspaceXmlLevel) _then;

/// Create a copy of WorkspaceXmlLevel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? sortOrder = null,Object? offices = null,Object? priceCents = null,Object? bookableAsWhole = null,Object? site = null,}) {
  return _then(_WorkspaceXmlLevel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,offices: null == offices ? _self._offices : offices // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlOffice>,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,bookableAsWhole: null == bookableAsWhole ? _self.bookableAsWhole : bookableAsWhole // ignore: cast_nullable_to_non_nullable
as bool,site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$WorkspaceXmlData {

 WorkspaceXmlSettings get settings; List<WorkspaceXmlAccessory> get accessories; List<WorkspaceXmlLevel> get levels;/// The v3 `<configuration>` tree; null for a v1/v2 document or a v3
/// document without one. Compared structurally, nested maps and lists
/// included.
 Map<String, Object?>? get configuration;
/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceXmlDataCopyWith<WorkspaceXmlData> get copyWith => _$WorkspaceXmlDataCopyWithImpl<WorkspaceXmlData>(this as WorkspaceXmlData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkspaceXmlData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceXmlData&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&const DeepCollectionEquality().equals(other.accessories, _this.accessories)&&const DeepCollectionEquality().equals(other.levels, _this.levels)&&const DeepCollectionEquality().equals(other.configuration, _this.configuration));
}


@override
int get hashCode {
  final _this = this as WorkspaceXmlData;
  return Object.hash(runtimeType,_this.settings,const DeepCollectionEquality().hash(_this.accessories),const DeepCollectionEquality().hash(_this.levels),const DeepCollectionEquality().hash(_this.configuration));
}

@override
String toString() {
  final _this = this as WorkspaceXmlData;
  return 'WorkspaceXmlData(settings: ${_this.settings}, accessories: ${_this.accessories}, levels: ${_this.levels}, configuration: ${_this.configuration})';
}


}

/// @nodoc
abstract mixin class $WorkspaceXmlDataCopyWith<$Res>  {
  factory $WorkspaceXmlDataCopyWith(WorkspaceXmlData value, $Res Function(WorkspaceXmlData) _then) = _$WorkspaceXmlDataCopyWithImpl;
@useResult
$Res call({
 WorkspaceXmlSettings settings, List<WorkspaceXmlAccessory> accessories, List<WorkspaceXmlLevel> levels, Map<String, Object?>? configuration
});


$WorkspaceXmlSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$WorkspaceXmlDataCopyWithImpl<$Res>
    implements $WorkspaceXmlDataCopyWith<$Res> {
  _$WorkspaceXmlDataCopyWithImpl(this._self, this._then);

  final WorkspaceXmlData _self;
  final $Res Function(WorkspaceXmlData) _then;

/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? settings = null,Object? accessories = null,Object? levels = null,Object? configuration = freezed,}) {
  return _then(WorkspaceXmlData(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as WorkspaceXmlSettings,accessories: null == accessories ? _self.accessories : accessories // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlAccessory>,levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlLevel>,configuration: freezed == configuration ? _self.configuration : configuration // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,
  ));
}
/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceXmlSettingsCopyWith<$Res> get settings {
  
  return $WorkspaceXmlSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceXmlData].
extension WorkspaceXmlDataPatterns on WorkspaceXmlData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceXmlData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceXmlData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceXmlData value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceXmlData value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceXmlData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceXmlSettings settings,  List<WorkspaceXmlAccessory> accessories,  List<WorkspaceXmlLevel> levels,  Map<String, Object?>? configuration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceXmlData() when $default != null:
return $default(_that.settings,_that.accessories,_that.levels,_that.configuration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceXmlSettings settings,  List<WorkspaceXmlAccessory> accessories,  List<WorkspaceXmlLevel> levels,  Map<String, Object?>? configuration)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlData():
return $default(_that.settings,_that.accessories,_that.levels,_that.configuration);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceXmlSettings settings,  List<WorkspaceXmlAccessory> accessories,  List<WorkspaceXmlLevel> levels,  Map<String, Object?>? configuration)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceXmlData() when $default != null:
return $default(_that.settings,_that.accessories,_that.levels,_that.configuration);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceXmlData implements WorkspaceXmlData {
  const _WorkspaceXmlData({required this.settings,  List<WorkspaceXmlAccessory> accessories = const <WorkspaceXmlAccessory>[],  List<WorkspaceXmlLevel> levels = const <WorkspaceXmlLevel>[],  Map<String, Object?>? configuration}): _accessories = accessories,_levels = levels,_configuration = configuration;
  

@override final  WorkspaceXmlSettings settings;
 final  List<WorkspaceXmlAccessory> _accessories;
@override@JsonKey() List<WorkspaceXmlAccessory> get accessories {
  if (_accessories is EqualUnmodifiableListView) return _accessories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accessories);
}

 final  List<WorkspaceXmlLevel> _levels;
@override@JsonKey() List<WorkspaceXmlLevel> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}

/// The v3 `<configuration>` tree; null for a v1/v2 document or a v3
/// document without one. Compared structurally, nested maps and lists
/// included.
 final  Map<String, Object?>? _configuration;
/// The v3 `<configuration>` tree; null for a v1/v2 document or a v3
/// document without one. Compared structurally, nested maps and lists
/// included.
@override Map<String, Object?>? get configuration {
  final value = _configuration;
  if (value == null) return null;
  if (_configuration is EqualUnmodifiableMapView) return _configuration;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceXmlDataCopyWith<_WorkspaceXmlData> get copyWith => __$WorkspaceXmlDataCopyWithImpl<_WorkspaceXmlData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceXmlData&&(identical(other.settings, settings) || other.settings == settings)&&const DeepCollectionEquality().equals(other.accessories, _accessories)&&const DeepCollectionEquality().equals(other.levels, _levels)&&const DeepCollectionEquality().equals(other.configuration, _configuration));
}


@override
int get hashCode {
    return Object.hash(runtimeType,settings,const DeepCollectionEquality().hash(_accessories),const DeepCollectionEquality().hash(_levels),const DeepCollectionEquality().hash(_configuration));
}

@override
String toString() {
    return 'WorkspaceXmlData(settings: $settings, accessories: $accessories, levels: $levels, configuration: $configuration)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceXmlDataCopyWith<$Res> implements $WorkspaceXmlDataCopyWith<$Res> {
  factory _$WorkspaceXmlDataCopyWith(_WorkspaceXmlData value, $Res Function(_WorkspaceXmlData) _then) = __$WorkspaceXmlDataCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceXmlSettings settings, List<WorkspaceXmlAccessory> accessories, List<WorkspaceXmlLevel> levels, Map<String, Object?>? configuration
});


@override $WorkspaceXmlSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$WorkspaceXmlDataCopyWithImpl<$Res>
    implements _$WorkspaceXmlDataCopyWith<$Res> {
  __$WorkspaceXmlDataCopyWithImpl(this._self, this._then);

  final _WorkspaceXmlData _self;
  final $Res Function(_WorkspaceXmlData) _then;

/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? settings = null,Object? accessories = null,Object? levels = null,Object? configuration = freezed,}) {
  return _then(_WorkspaceXmlData(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as WorkspaceXmlSettings,accessories: null == accessories ? _self._accessories : accessories // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlAccessory>,levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<WorkspaceXmlLevel>,configuration: freezed == configuration ? _self._configuration : configuration // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,
  ));
}

/// Create a copy of WorkspaceXmlData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceXmlSettingsCopyWith<$Res> get settings {
  
  return $WorkspaceXmlSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
