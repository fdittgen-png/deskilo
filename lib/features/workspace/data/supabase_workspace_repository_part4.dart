// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_workspace_repository.dart';

// #2386 — part 4 of SupabaseWorkspaceRepository, split out of supabase_workspace_repository.dart so no
// file holds the whole class.
extension _SupabaseWorkspaceRepositoryPart4 on SupabaseWorkspaceRepository {

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        // #887 — a managed member has no user yet.
        userId: row['user_id'] as String? ?? '', personId: row['person_id'] as String?,
        preferredLocaleOverride: row['preferred_locale_override'] as String?,
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        coOwner: CoOwnerStatus.fromWire(row['co_owner'] as String?),
        // #1148 — an unknown status reads as PAUSED: visible, never a
        // grant. A throw here emptied the whole member list.
        status: enumOr(MemberStatus.values, row['status'] as String?,
            MemberStatus.paused, area: 'members'),
        subscriptionPct: row['subscription_pct'] as int? ?? 100,
        managedIdentity: PersonalInfo.fromDb(
          (row['managed_identity'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        // #914/#915 — the name is a column now, and the rule rides
        // beside it; the contact fields arrive through the RPC.
        managedName: row['managed_name'] as String? ?? '',
        memberNumber: row['member_number'] as String? ?? '',
        homeSiteId: row['home_site_id'] as String?,
        managedAccess:
            (row['managed_access'] as Map?)?.cast<String, dynamic>() ??
                const {},
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
        overagePolicy:
            OveragePolicy.fromName(row['overage_policy'] as String?),
        isKiosk: row['is_kiosk'] as bool? ?? false,
        maxActiveReservations: row['max_active_reservations'] as int?,
        maxSimultaneousReservations:
            row['max_simultaneous_reservations'] as int?,
        canReserveLevel: row['can_reserve_level'] as bool? ?? false,
        vatTreatment: row['vat_treatment'] as String? ?? 'auto',
        vatExemptionReason: row['vat_exemption_reason'] as String? ?? '',
        customerCapacity: row['customer_capacity'] as String?,
      );
}
