// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- managed (handed-over) members and their identity, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enum_wire.dart';
import '../../profile/domain/personal_info.dart';
import '../domain/managed_access.dart';
import '../domain/managed_identity_repository.dart';
import '../domain/member.dart';
import '../domain/overage_policy.dart';

mixin SupabaseManagedIdentity implements ManagedIdentityRepository {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  @override
  Future<String> createManagedMember(
    String workspaceId,
    PersonalInfo identity, {
    ManagedAccess access = ManagedAccess.unnarrowed,
  }) async {
    final result = await client.rpc<dynamic>(
      'create_managed_member',
      params: {
        'p_workspace_id': workspaceId,
        'p_identity': identity.normalized().toDb(),
        'p_access': access.toJson(),
      },
    );
    return result as String;
  }

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) async {
    final result = await client.rpc<dynamic>(
      'managed_identity_of',
      params: {'p_member_id': memberId},
    );
    return PersonalInfo.fromDb(
      (result as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @override
  Future<void> setManagedAccess(String memberId, ManagedAccess access) async {
    await client.rpc<dynamic>(
      'set_managed_access',
      params: {'p_member_id': memberId, 'p_access': access.toJson()},
    );
  }

  @override
  Future<void> updateManagedIdentity(
    String memberId,
    PersonalInfo identity,
  ) async {
    await client.rpc<dynamic>(
      'update_managed_identity',
      params: {
        'p_member_id': memberId,
        'p_identity': identity.normalized().toDb(),
      },
    );
  }

  @override
  Future<void> revokeHandover(String memberId) async {
    await client.rpc<dynamic>(
      'revoke_handover',
      params: {'p_member_id': memberId},
    );
  }

  /// The name a members list shows for a managed member: the server-derived
  /// addressee line (#914), else the typed identity (company when nameless).
  String managedDisplayName(Map<String, dynamic> row) {
    final derived = (row['managed_name'] as String? ?? '').trim();
    if (derived.isNotEmpty) return derived;
    final identity = PersonalInfo.fromDb(
      (row['managed_identity'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return identity.fullName.isNotEmpty ? identity.fullName : identity.company;
  }

  Member memberFromRow(Map<String, dynamic> row) => Member(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    // #887 — a managed member has no user yet.
    userId: row['user_id'] as String? ?? '',
    personId: row['person_id'] as String?,
    preferredLocaleOverride: row['preferred_locale_override'] as String?,
    isAdmin: row['is_admin'] as bool,
    isOwner: row['is_owner'] as bool,
    coOwner: CoOwnerStatus.fromWire(row['co_owner'] as String?),
    // #1148 — an unknown status reads as PAUSED: visible, never a
    // grant. A throw here emptied the whole member list.
    status: enumOr(
      MemberStatus.values,
      row['status'] as String?,
      MemberStatus.paused,
      area: 'members',
    ),
    subscriptionPct: row['subscription_pct'] as int? ?? 100,
    managedIdentity: PersonalInfo.fromDb(
      (row['managed_identity'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    // #914/#915 — the name is a column now, and the rule rides
    // beside it; the contact fields arrive through the RPC.
    managedName: row['managed_name'] as String? ?? '',
    memberNumber: row['member_number'] as String? ?? '',
    homeSiteId: row['home_site_id'] as String?,
    managedAccess:
        (row['managed_access'] as Map?)?.cast<String, dynamic>() ?? const {},
    paymentTerms: row['payment_terms'] is Map
        ? PaymentTerms.fromJson(row['payment_terms'] as Map)
        : null,
    claimedAt: row['claimed_at'] == null
        ? null
        : DateTime.parse(row['claimed_at'] as String),
    origin: MemberOrigin.fromDb(row['origin'] as String?),
    joinedAt: row['joined_at'] == null
        ? null
        : DateTime.parse(row['joined_at'] as String).toUtc(),
    overagePolicy: OveragePolicy.fromName(row['overage_policy'] as String?),
    isKiosk: row['is_kiosk'] as bool? ?? false,
    maxActiveReservations: row['max_active_reservations'] as int?,
    maxSimultaneousReservations: row['max_simultaneous_reservations'] as int?,
    canReserveLevel: row['can_reserve_level'] as bool? ?? false,
    vatTreatment: row['vat_treatment'] as String? ?? 'auto',
    vatExemptionReason: row['vat_exemption_reason'] as String? ?? '',
    customerCapacity: row['customer_capacity'] as String?,
    einvoiceEndpointId: JsonReader.of(row).stringOr('einvoice_endpoint_id'),
    einvoiceEndpointScheme: JsonReader.of(row)
        .stringOr('einvoice_endpoint_scheme'),
    billingSubdivision: JsonReader.of(row).stringOr('billing_subdivision'),
  );
}
