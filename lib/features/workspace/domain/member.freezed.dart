// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Member {

 String get id; String get workspaceId; String get userId; bool get isAdmin; bool get isOwner; MemberStatus get status;/// Subscription percentage 1–100 (ADR 0008): the membership level the
/// fee band and the half-day entitlement derive from.
 int get subscriptionPct;/// What happens once the member has used their whole monthly
/// entitlement (migration 0041): blocked (default), pay-as-you-go, or
/// buy-a-package.
 OveragePolicy get overagePolicy;/// Wall-mounted tablet account (migration 0043): the app locks to the
/// plan view; real members act through it by presenting a badge.
 bool get isKiosk;/// Cap on simultaneous open reservations (migration 0044): at most
/// this many bookings with status reserved/checked-in that have not
/// ended yet. Null = unlimited. Set by owner/admins for OTHERS only —
/// never self-service.
 int? get maxActiveReservations;/// Explicit permission to hold OVERLAPPING bookings (#628, migration
/// 0119): how many active reservations may cover the same moment.
/// Null = follow `booking_rules.simultaneous_reservations`, itself
/// defaulting to 1 — the historical one place at a time. Set by
/// owner/admins for OTHERS only, never self-service.
 int? get maxSimultaneousReservations;/// #985 — who this member is for VAT (`members.vat_treatment`,
/// 0182): the wire of `VatTreatment`. 'auto' is today's rule.
 String get vatTreatment;/// #985 — the reason printed when the buyer is exempt.
 String get vatExemptionReason;/// Whether this member may reserve/check into a WHOLE level (0050);
/// granted by the owner or an admin, never self-set.
 bool get canReserveLevel;/// Co-ownership (0058): active = owner permissions now + automatic
/// succession; passive = successor-in-waiting.
 CoOwnerStatus get coOwner;/// When this member joined the workspace (`members.joined_at`).
///
/// #793 — it is what lets the avatar monograms be first-come,
/// first-served: the letters a member is given never move again
/// because someone with an earlier name joined later.
 DateTime? get joinedAt;/// #887 — the identity of a MANAGED member (no account yet): what
/// the admin typed, carried until the person claims the profile.
/// Empty once claimed — the data then lives on their profile.
/// The PUBLIC half of a managed identity (0161): name, company and
/// country — what a co-member legitimately sees. The contact and tax
/// fields live behind [ManagedProfileAccess] and arrive only through
/// `managed_identity_of`, which logs the read.
 PersonalInfo get managedIdentity;/// #914 — the addressee line, derived server-side, readable by every
/// member because the directory needs a name.
 String get managedName;/// #928 — "N° adhérent": drawn from the workspace's `member` series
/// when the membership is created, never changed, frozen into every
/// invoice's buyer party. '' only for rows older than 0165's backfill.
 String get memberNumber;/// #945 — the site whose address this member's documents carry; null
/// is the workspace's default site.
 String? get homeSiteId;/// #914 — who may administer this profile: roles, named members, or
/// both. Empty = the rule nobody narrowed (owner and admin).
 Map<String, dynamic> get managedAccess;/// #887 — when the person took the profile over; null while managed
/// and for members who joined by themselves.
 DateTime? get claimedAt;/// #881 — the member's own payment conditions (keys on top of the
/// workspace's); null = inherit everything. Changed only through a
/// validated payment_terms_change request.
 PaymentTerms? get paymentTerms;
/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberCopyWith<Member> get copyWith => _$MemberCopyWithImpl<Member>(this as Member, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Member&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.status, status) || other.status == status)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.isKiosk, isKiosk) || other.isKiosk == isKiosk)&&(identical(other.maxActiveReservations, maxActiveReservations) || other.maxActiveReservations == maxActiveReservations)&&(identical(other.maxSimultaneousReservations, maxSimultaneousReservations) || other.maxSimultaneousReservations == maxSimultaneousReservations)&&(identical(other.vatTreatment, vatTreatment) || other.vatTreatment == vatTreatment)&&(identical(other.vatExemptionReason, vatExemptionReason) || other.vatExemptionReason == vatExemptionReason)&&(identical(other.canReserveLevel, canReserveLevel) || other.canReserveLevel == canReserveLevel)&&(identical(other.coOwner, coOwner) || other.coOwner == coOwner)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.managedIdentity, managedIdentity) || other.managedIdentity == managedIdentity)&&(identical(other.managedName, managedName) || other.managedName == managedName)&&(identical(other.memberNumber, memberNumber) || other.memberNumber == memberNumber)&&(identical(other.homeSiteId, homeSiteId) || other.homeSiteId == homeSiteId)&&const DeepCollectionEquality().equals(other.managedAccess, managedAccess)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.paymentTerms, paymentTerms) || other.paymentTerms == paymentTerms));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,userId,isAdmin,isOwner,status,subscriptionPct,overagePolicy,isKiosk,maxActiveReservations,maxSimultaneousReservations,vatTreatment,vatExemptionReason,canReserveLevel,coOwner,joinedAt,managedIdentity,managedName,memberNumber,homeSiteId,const DeepCollectionEquality().hash(managedAccess),claimedAt,paymentTerms]);

@override
String toString() {
  return 'Member(id: $id, workspaceId: $workspaceId, userId: $userId, isAdmin: $isAdmin, isOwner: $isOwner, status: $status, subscriptionPct: $subscriptionPct, overagePolicy: $overagePolicy, isKiosk: $isKiosk, maxActiveReservations: $maxActiveReservations, maxSimultaneousReservations: $maxSimultaneousReservations, vatTreatment: $vatTreatment, vatExemptionReason: $vatExemptionReason, canReserveLevel: $canReserveLevel, coOwner: $coOwner, joinedAt: $joinedAt, managedIdentity: $managedIdentity, managedName: $managedName, memberNumber: $memberNumber, homeSiteId: $homeSiteId, managedAccess: $managedAccess, claimedAt: $claimedAt, paymentTerms: $paymentTerms)';
}


}

/// @nodoc
abstract mixin class $MemberCopyWith<$Res>  {
  factory $MemberCopyWith(Member value, $Res Function(Member) _then) = _$MemberCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String userId, bool isAdmin, bool isOwner, MemberStatus status, int subscriptionPct, OveragePolicy overagePolicy, bool isKiosk, int? maxActiveReservations, int? maxSimultaneousReservations, String vatTreatment, String vatExemptionReason, bool canReserveLevel, CoOwnerStatus coOwner, DateTime? joinedAt, PersonalInfo managedIdentity, String managedName, String memberNumber, String? homeSiteId, Map<String, dynamic> managedAccess, DateTime? claimedAt, PaymentTerms? paymentTerms
});




}
/// @nodoc
class _$MemberCopyWithImpl<$Res>
    implements $MemberCopyWith<$Res> {
  _$MemberCopyWithImpl(this._self, this._then);

  final Member _self;
  final $Res Function(Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? userId = null,Object? isAdmin = null,Object? isOwner = null,Object? status = null,Object? subscriptionPct = null,Object? overagePolicy = null,Object? isKiosk = null,Object? maxActiveReservations = freezed,Object? maxSimultaneousReservations = freezed,Object? vatTreatment = null,Object? vatExemptionReason = null,Object? canReserveLevel = null,Object? coOwner = null,Object? joinedAt = freezed,Object? managedIdentity = null,Object? managedName = null,Object? memberNumber = null,Object? homeSiteId = freezed,Object? managedAccess = null,Object? claimedAt = freezed,Object? paymentTerms = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MemberStatus,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,isKiosk: null == isKiosk ? _self.isKiosk : isKiosk // ignore: cast_nullable_to_non_nullable
as bool,maxActiveReservations: freezed == maxActiveReservations ? _self.maxActiveReservations : maxActiveReservations // ignore: cast_nullable_to_non_nullable
as int?,maxSimultaneousReservations: freezed == maxSimultaneousReservations ? _self.maxSimultaneousReservations : maxSimultaneousReservations // ignore: cast_nullable_to_non_nullable
as int?,vatTreatment: null == vatTreatment ? _self.vatTreatment : vatTreatment // ignore: cast_nullable_to_non_nullable
as String,vatExemptionReason: null == vatExemptionReason ? _self.vatExemptionReason : vatExemptionReason // ignore: cast_nullable_to_non_nullable
as String,canReserveLevel: null == canReserveLevel ? _self.canReserveLevel : canReserveLevel // ignore: cast_nullable_to_non_nullable
as bool,coOwner: null == coOwner ? _self.coOwner : coOwner // ignore: cast_nullable_to_non_nullable
as CoOwnerStatus,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,managedIdentity: null == managedIdentity ? _self.managedIdentity : managedIdentity // ignore: cast_nullable_to_non_nullable
as PersonalInfo,managedName: null == managedName ? _self.managedName : managedName // ignore: cast_nullable_to_non_nullable
as String,memberNumber: null == memberNumber ? _self.memberNumber : memberNumber // ignore: cast_nullable_to_non_nullable
as String,homeSiteId: freezed == homeSiteId ? _self.homeSiteId : homeSiteId // ignore: cast_nullable_to_non_nullable
as String?,managedAccess: null == managedAccess ? _self.managedAccess : managedAccess // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentTerms: freezed == paymentTerms ? _self.paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as PaymentTerms?,
  ));
}

}


/// Adds pattern-matching-related methods to [Member].
extension MemberPatterns on Member {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Member value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Member value)  $default,){
final _that = this;
switch (_that) {
case _Member():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Member value)?  $default,){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk,  int? maxActiveReservations,  int? maxSimultaneousReservations,  String vatTreatment,  String vatExemptionReason,  bool canReserveLevel,  CoOwnerStatus coOwner,  DateTime? joinedAt,  PersonalInfo managedIdentity,  String managedName,  String memberNumber,  String? homeSiteId,  Map<String, dynamic> managedAccess,  DateTime? claimedAt,  PaymentTerms? paymentTerms)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk,_that.maxActiveReservations,_that.maxSimultaneousReservations,_that.vatTreatment,_that.vatExemptionReason,_that.canReserveLevel,_that.coOwner,_that.joinedAt,_that.managedIdentity,_that.managedName,_that.memberNumber,_that.homeSiteId,_that.managedAccess,_that.claimedAt,_that.paymentTerms);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk,  int? maxActiveReservations,  int? maxSimultaneousReservations,  String vatTreatment,  String vatExemptionReason,  bool canReserveLevel,  CoOwnerStatus coOwner,  DateTime? joinedAt,  PersonalInfo managedIdentity,  String managedName,  String memberNumber,  String? homeSiteId,  Map<String, dynamic> managedAccess,  DateTime? claimedAt,  PaymentTerms? paymentTerms)  $default,) {final _that = this;
switch (_that) {
case _Member():
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk,_that.maxActiveReservations,_that.maxSimultaneousReservations,_that.vatTreatment,_that.vatExemptionReason,_that.canReserveLevel,_that.coOwner,_that.joinedAt,_that.managedIdentity,_that.managedName,_that.memberNumber,_that.homeSiteId,_that.managedAccess,_that.claimedAt,_that.paymentTerms);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String userId,  bool isAdmin,  bool isOwner,  MemberStatus status,  int subscriptionPct,  OveragePolicy overagePolicy,  bool isKiosk,  int? maxActiveReservations,  int? maxSimultaneousReservations,  String vatTreatment,  String vatExemptionReason,  bool canReserveLevel,  CoOwnerStatus coOwner,  DateTime? joinedAt,  PersonalInfo managedIdentity,  String managedName,  String memberNumber,  String? homeSiteId,  Map<String, dynamic> managedAccess,  DateTime? claimedAt,  PaymentTerms? paymentTerms)?  $default,) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.workspaceId,_that.userId,_that.isAdmin,_that.isOwner,_that.status,_that.subscriptionPct,_that.overagePolicy,_that.isKiosk,_that.maxActiveReservations,_that.maxSimultaneousReservations,_that.vatTreatment,_that.vatExemptionReason,_that.canReserveLevel,_that.coOwner,_that.joinedAt,_that.managedIdentity,_that.managedName,_that.memberNumber,_that.homeSiteId,_that.managedAccess,_that.claimedAt,_that.paymentTerms);case _:
  return null;

}
}

}

/// @nodoc


class _Member extends Member {
  const _Member({required this.id, required this.workspaceId, required this.userId, required this.isAdmin, required this.isOwner, required this.status, this.subscriptionPct = 100, this.overagePolicy = OveragePolicy.blocked, this.isKiosk = false, this.maxActiveReservations, this.maxSimultaneousReservations, this.vatTreatment = 'auto', this.vatExemptionReason = '', this.canReserveLevel = false, this.coOwner = CoOwnerStatus.none, this.joinedAt, this.managedIdentity = PersonalInfo.empty, this.managedName = '', this.memberNumber = '', this.homeSiteId, final  Map<String, dynamic> managedAccess = const <String, dynamic>{}, this.claimedAt, this.paymentTerms}): _managedAccess = managedAccess,super._();
  

@override final  String id;
@override final  String workspaceId;
@override final  String userId;
@override final  bool isAdmin;
@override final  bool isOwner;
@override final  MemberStatus status;
/// Subscription percentage 1–100 (ADR 0008): the membership level the
/// fee band and the half-day entitlement derive from.
@override@JsonKey() final  int subscriptionPct;
/// What happens once the member has used their whole monthly
/// entitlement (migration 0041): blocked (default), pay-as-you-go, or
/// buy-a-package.
@override@JsonKey() final  OveragePolicy overagePolicy;
/// Wall-mounted tablet account (migration 0043): the app locks to the
/// plan view; real members act through it by presenting a badge.
@override@JsonKey() final  bool isKiosk;
/// Cap on simultaneous open reservations (migration 0044): at most
/// this many bookings with status reserved/checked-in that have not
/// ended yet. Null = unlimited. Set by owner/admins for OTHERS only —
/// never self-service.
@override final  int? maxActiveReservations;
/// Explicit permission to hold OVERLAPPING bookings (#628, migration
/// 0119): how many active reservations may cover the same moment.
/// Null = follow `booking_rules.simultaneous_reservations`, itself
/// defaulting to 1 — the historical one place at a time. Set by
/// owner/admins for OTHERS only, never self-service.
@override final  int? maxSimultaneousReservations;
/// #985 — who this member is for VAT (`members.vat_treatment`,
/// 0182): the wire of `VatTreatment`. 'auto' is today's rule.
@override@JsonKey() final  String vatTreatment;
/// #985 — the reason printed when the buyer is exempt.
@override@JsonKey() final  String vatExemptionReason;
/// Whether this member may reserve/check into a WHOLE level (0050);
/// granted by the owner or an admin, never self-set.
@override@JsonKey() final  bool canReserveLevel;
/// Co-ownership (0058): active = owner permissions now + automatic
/// succession; passive = successor-in-waiting.
@override@JsonKey() final  CoOwnerStatus coOwner;
/// When this member joined the workspace (`members.joined_at`).
///
/// #793 — it is what lets the avatar monograms be first-come,
/// first-served: the letters a member is given never move again
/// because someone with an earlier name joined later.
@override final  DateTime? joinedAt;
/// #887 — the identity of a MANAGED member (no account yet): what
/// the admin typed, carried until the person claims the profile.
/// Empty once claimed — the data then lives on their profile.
/// The PUBLIC half of a managed identity (0161): name, company and
/// country — what a co-member legitimately sees. The contact and tax
/// fields live behind [ManagedProfileAccess] and arrive only through
/// `managed_identity_of`, which logs the read.
@override@JsonKey() final  PersonalInfo managedIdentity;
/// #914 — the addressee line, derived server-side, readable by every
/// member because the directory needs a name.
@override@JsonKey() final  String managedName;
/// #928 — "N° adhérent": drawn from the workspace's `member` series
/// when the membership is created, never changed, frozen into every
/// invoice's buyer party. '' only for rows older than 0165's backfill.
@override@JsonKey() final  String memberNumber;
/// #945 — the site whose address this member's documents carry; null
/// is the workspace's default site.
@override final  String? homeSiteId;
/// #914 — who may administer this profile: roles, named members, or
/// both. Empty = the rule nobody narrowed (owner and admin).
 final  Map<String, dynamic> _managedAccess;
/// #914 — who may administer this profile: roles, named members, or
/// both. Empty = the rule nobody narrowed (owner and admin).
@override@JsonKey() Map<String, dynamic> get managedAccess {
  if (_managedAccess is EqualUnmodifiableMapView) return _managedAccess;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_managedAccess);
}

/// #887 — when the person took the profile over; null while managed
/// and for members who joined by themselves.
@override final  DateTime? claimedAt;
/// #881 — the member's own payment conditions (keys on top of the
/// workspace's); null = inherit everything. Changed only through a
/// validated payment_terms_change request.
@override final  PaymentTerms? paymentTerms;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberCopyWith<_Member> get copyWith => __$MemberCopyWithImpl<_Member>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Member&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.status, status) || other.status == status)&&(identical(other.subscriptionPct, subscriptionPct) || other.subscriptionPct == subscriptionPct)&&(identical(other.overagePolicy, overagePolicy) || other.overagePolicy == overagePolicy)&&(identical(other.isKiosk, isKiosk) || other.isKiosk == isKiosk)&&(identical(other.maxActiveReservations, maxActiveReservations) || other.maxActiveReservations == maxActiveReservations)&&(identical(other.maxSimultaneousReservations, maxSimultaneousReservations) || other.maxSimultaneousReservations == maxSimultaneousReservations)&&(identical(other.vatTreatment, vatTreatment) || other.vatTreatment == vatTreatment)&&(identical(other.vatExemptionReason, vatExemptionReason) || other.vatExemptionReason == vatExemptionReason)&&(identical(other.canReserveLevel, canReserveLevel) || other.canReserveLevel == canReserveLevel)&&(identical(other.coOwner, coOwner) || other.coOwner == coOwner)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.managedIdentity, managedIdentity) || other.managedIdentity == managedIdentity)&&(identical(other.managedName, managedName) || other.managedName == managedName)&&(identical(other.memberNumber, memberNumber) || other.memberNumber == memberNumber)&&(identical(other.homeSiteId, homeSiteId) || other.homeSiteId == homeSiteId)&&const DeepCollectionEquality().equals(other._managedAccess, _managedAccess)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.paymentTerms, paymentTerms) || other.paymentTerms == paymentTerms));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,workspaceId,userId,isAdmin,isOwner,status,subscriptionPct,overagePolicy,isKiosk,maxActiveReservations,maxSimultaneousReservations,vatTreatment,vatExemptionReason,canReserveLevel,coOwner,joinedAt,managedIdentity,managedName,memberNumber,homeSiteId,const DeepCollectionEquality().hash(_managedAccess),claimedAt,paymentTerms]);

@override
String toString() {
  return 'Member(id: $id, workspaceId: $workspaceId, userId: $userId, isAdmin: $isAdmin, isOwner: $isOwner, status: $status, subscriptionPct: $subscriptionPct, overagePolicy: $overagePolicy, isKiosk: $isKiosk, maxActiveReservations: $maxActiveReservations, maxSimultaneousReservations: $maxSimultaneousReservations, vatTreatment: $vatTreatment, vatExemptionReason: $vatExemptionReason, canReserveLevel: $canReserveLevel, coOwner: $coOwner, joinedAt: $joinedAt, managedIdentity: $managedIdentity, managedName: $managedName, memberNumber: $memberNumber, homeSiteId: $homeSiteId, managedAccess: $managedAccess, claimedAt: $claimedAt, paymentTerms: $paymentTerms)';
}


}

/// @nodoc
abstract mixin class _$MemberCopyWith<$Res> implements $MemberCopyWith<$Res> {
  factory _$MemberCopyWith(_Member value, $Res Function(_Member) _then) = __$MemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String userId, bool isAdmin, bool isOwner, MemberStatus status, int subscriptionPct, OveragePolicy overagePolicy, bool isKiosk, int? maxActiveReservations, int? maxSimultaneousReservations, String vatTreatment, String vatExemptionReason, bool canReserveLevel, CoOwnerStatus coOwner, DateTime? joinedAt, PersonalInfo managedIdentity, String managedName, String memberNumber, String? homeSiteId, Map<String, dynamic> managedAccess, DateTime? claimedAt, PaymentTerms? paymentTerms
});




}
/// @nodoc
class __$MemberCopyWithImpl<$Res>
    implements _$MemberCopyWith<$Res> {
  __$MemberCopyWithImpl(this._self, this._then);

  final _Member _self;
  final $Res Function(_Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? userId = null,Object? isAdmin = null,Object? isOwner = null,Object? status = null,Object? subscriptionPct = null,Object? overagePolicy = null,Object? isKiosk = null,Object? maxActiveReservations = freezed,Object? maxSimultaneousReservations = freezed,Object? vatTreatment = null,Object? vatExemptionReason = null,Object? canReserveLevel = null,Object? coOwner = null,Object? joinedAt = freezed,Object? managedIdentity = null,Object? managedName = null,Object? memberNumber = null,Object? homeSiteId = freezed,Object? managedAccess = null,Object? claimedAt = freezed,Object? paymentTerms = freezed,}) {
  return _then(_Member(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MemberStatus,subscriptionPct: null == subscriptionPct ? _self.subscriptionPct : subscriptionPct // ignore: cast_nullable_to_non_nullable
as int,overagePolicy: null == overagePolicy ? _self.overagePolicy : overagePolicy // ignore: cast_nullable_to_non_nullable
as OveragePolicy,isKiosk: null == isKiosk ? _self.isKiosk : isKiosk // ignore: cast_nullable_to_non_nullable
as bool,maxActiveReservations: freezed == maxActiveReservations ? _self.maxActiveReservations : maxActiveReservations // ignore: cast_nullable_to_non_nullable
as int?,maxSimultaneousReservations: freezed == maxSimultaneousReservations ? _self.maxSimultaneousReservations : maxSimultaneousReservations // ignore: cast_nullable_to_non_nullable
as int?,vatTreatment: null == vatTreatment ? _self.vatTreatment : vatTreatment // ignore: cast_nullable_to_non_nullable
as String,vatExemptionReason: null == vatExemptionReason ? _self.vatExemptionReason : vatExemptionReason // ignore: cast_nullable_to_non_nullable
as String,canReserveLevel: null == canReserveLevel ? _self.canReserveLevel : canReserveLevel // ignore: cast_nullable_to_non_nullable
as bool,coOwner: null == coOwner ? _self.coOwner : coOwner // ignore: cast_nullable_to_non_nullable
as CoOwnerStatus,joinedAt: freezed == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,managedIdentity: null == managedIdentity ? _self.managedIdentity : managedIdentity // ignore: cast_nullable_to_non_nullable
as PersonalInfo,managedName: null == managedName ? _self.managedName : managedName // ignore: cast_nullable_to_non_nullable
as String,memberNumber: null == memberNumber ? _self.memberNumber : memberNumber // ignore: cast_nullable_to_non_nullable
as String,homeSiteId: freezed == homeSiteId ? _self.homeSiteId : homeSiteId // ignore: cast_nullable_to_non_nullable
as String?,managedAccess: null == managedAccess ? _self._managedAccess : managedAccess // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentTerms: freezed == paymentTerms ? _self.paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as PaymentTerms?,
  ));
}


}

// dart format on
