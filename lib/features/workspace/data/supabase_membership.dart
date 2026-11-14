// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- members, their limits and status, joining, invitations and new-member defaults, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import '../../../core/validation/pending_validation.dart';
import '../domain/invitation_answer.dart';
import '../domain/member.dart';
import '../domain/member_term_change.dart';
import '../domain/membership_repository.dart';
import '../domain/new_member_defaults.dart';
import '../domain/overage_policy.dart';
import 'supabase_managed_identity.dart';
import 'supabase_workspace_rows.dart';

mixin SupabaseMembership on SupabaseWorkspaceRows, SupabaseManagedIdentity
    implements MembershipRepository {
  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final result = await client.rpc<dynamic>(
      'join_workspace',
      params: {'p_invite_code': inviteCode},
    );
    return result as String;
  }

  @override
  Future<InvitationAnswer> previewInvitation(String inviteCode) async =>
      InvitationAnswer.fromJson(
        await client.rpc<dynamic>(
          'invitation_preview',
          params: {'p_code': inviteCode},
        ),
      );
  @override
  Future<InvitationAnswer> joinByInvitation(String inviteCode) async =>
      InvitationAnswer.fromJson(
        await client.rpc<dynamic>(
          'join_by_invitation',
          params: {'p_code': inviteCode},
        ),
      );
  @override
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
    bool alsoProd = false,
  }) async {
    final result = await client.rpc<dynamic>(
      'create_invitation',
      params: {
        'p_workspace_id': workspaceId,
        'p_is_admin': isAdmin,
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_member_id': ?memberId,
        'p_also_prod': alsoProd,
      },
    );
    return result as String;
  }

  @override
  Future<void> setInvitationTemplates(
    String workspaceId,
    Map<String, String> templates,
  ) async {
    // Owner-only via workspaces_update RLS; empty entries are dropped so
    // the jsonb only carries real overrides (0096).
    await updateWorkspaceRow(workspaceId, {
      'invitation_templates': {
        for (final entry in templates.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      },
    });
  }

  @override
  Future<void> setInvitationTemplate(
    String workspaceId,
    String template,
  ) async {
    // Same shape as setWhatsappGroup — owner-only RLS, 0049 length check.
    await updateWorkspaceRow(workspaceId, {
      'invitation_template': template.trim(),
    });
  }

  @override
  Future<void> decideMemberJoin(
    String memberId, {
    required bool approve,
    String comment = '',
    String? expectedAccount,
  }) async {
    await client.rpc<dynamic>(
      'decide_workspace_application',
      params: {
        'p_member_id': memberId,
        'p_approve': approve,
        'p_comment': comment,
        'p_expected_account': expectedAccount ?? client.auth.currentUser?.id,
      },
    );
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return memberFromRow(row);
  }

  @override
  Future<Map<String, String>> fetchMemberEmails(String workspaceId) async {
    // Admin-gated on the server (0078): non-admin callers get [].
    final rows = await client.rpc<dynamic>(
      'member_emails',
      params: {'p_workspace_id': workspaceId},
    ) as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['member_id'] as String: r['email'] as String,
    };
  }

  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async {
    // members ↔ profiles share auth.users ids but carry no direct FK, so
    // PostgREST cannot embed — two queries, joined client-side.
    final memberRows = await client
        .from('members')
        .select(
          'id, user_id, managed_identity, managed_name, member_number, home_site_id',
        )
        .eq('workspace_id', workspaceId);
    // #887 — a managed member has no profile: its name is the identity
    // the admin typed (company when the person is nameless).
    String managedName(Map<String, dynamic> r) => managedDisplayName(r);

    // #962/#1030 — an empty id is not a uuid, and PostgREST answers
    // 22P02 for the WHOLE request: one managed member would blank every
    // name on the list. Null and empty are dropped the same way.
    final userIds = memberRows
        .map((r) => r['user_id'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    // #1833 — the purpose projection, never the profiles rows: a space
    // mate's legal name is operational data (0319/0320).
    final profileRows = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            for (final r in await client.rpc<List<dynamic>>(
              'member_profiles',
              params: {'p_workspace_id': workspaceId, 'p_user_ids': userIds},
            ))
              (r as Map).cast<String, dynamic>(),
          ];
    // #886 — a structured name outranks the display name on lists that
    // feed documents, for whoever may read it (the operational group);
    // the display name stays the fallback.
    String nameOf(Map<String, dynamic> r) {
      Map<String, dynamic> group(String purpose) =>
          (r['purposes'] as List<dynamic>? ?? const <dynamic>[]).contains(
                purpose,
              ) &&
              r[purpose] is Map
          ? (r[purpose] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final operational = group('operational');
      final first = (operational['first_name'] as String? ?? '').trim();
      final last = (operational['last_name'] as String? ?? '')
          .trim()
          .toUpperCase();
      final full = [first, last].where((s) => s.isNotEmpty).join(' ');
      return full.isNotEmpty
          ? full
          : group('community')['display_name'] as String? ?? '';
    }

    final nameByUser = {
      for (final r in profileRows) r['id'] as String: nameOf(r),
    };
    return {
      for (final r in memberRows)
        r['id'] as String: r['user_id'] == null
            ? managedName(r)
            : nameByUser[r['user_id'] as String] ?? '',
    };
  }

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async {
    final rows = await client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return rows.map(memberFromRow).toList();
  }

  @override
  Future<List<MemberTermChange>> fetchMemberTermChanges(
    String workspaceId,
  ) async {
    final rows = await client
        .from('member_term_changes')
        .select()
        .eq('workspace_id', workspaceId)
        .order('due_on', ascending: true)
        .order('seq', ascending: true);
    return rows.map(MemberTermChange.fromRow).toList();
  }

  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async {
    // #982 — through the subscription_change policy.
    final answer = await client.rpc<dynamic>(
      'request_subscription_change',
      params: {'p_member_id': memberId, 'p_pct': pct},
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<void> updateMemberOveragePolicy(
    String memberId,
    OveragePolicy policy,
  ) async {
    await client
        .from('members')
        .update({'overage_policy': policy.name})
        .eq('id', memberId);
  }

  @override
  Future<void> setMemberReservationLimit(String memberId, int? limit) async {
    await client.rpc<dynamic>(
      'set_member_reservation_limit',
      params: {'p_member_id': memberId, 'p_limit': limit},
    );
  }

  @override
  Future<void> setMemberSimultaneousLimit(String memberId, int? limit) async {
    await client.rpc<dynamic>(
      'set_member_simultaneous_limit',
      params: {'p_member_id': memberId, 'p_limit': limit},
    );
  }

  @override
  Future<void> setMemberVatTreatment(
    String memberId,
    String treatment,
    String reason,
  ) async {
    // #985 — the counterparty dimension, by whoever may issue invoices.
    await client.rpc<dynamic>(
      'set_member_vat_treatment',
      params: {
        'p_member_id': memberId,
        'p_treatment': treatment,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> setMemberCustomerCapacity(
    String memberId,
    String? capacity,
  ) async {
    // #1916 — stated by whoever may issue invoices; null = not stated.
    await client.rpc<dynamic>(
      'set_member_customer_capacity',
      params: {'p_member_id': memberId, 'p_capacity': capacity},
    );
  }

  @override
  Future<void> setMemberEInvoiceAddress(
    String memberId, {
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
  }) async {
    // #2358 — the customer's e-invoicing address, by whoever issues.
    await client.rpc<void>(
      'set_member_einvoice_address',
      params: {
        'p_member_id': memberId,
        'p_endpoint_id': endpointId.trim(),
        'p_endpoint_scheme': endpointScheme.trim().toUpperCase(),
        'p_subdivision': subdivision.trim().toUpperCase(),
      },
    );
  }

  @override
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  }) async {
    await client.rpc<dynamic>(
      'set_member_level_permission',
      params: {'p_member_id': memberId, 'p_allowed': allowed},
    );
  }

  @override
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) async {
    await client.rpc<dynamic>(
      'set_member_kiosk',
      params: {'p_member_id': memberId, 'p_is_kiosk': isKiosk},
    );
  }

  @override
  Future<void> setCoOwner(String memberId, CoOwnerStatus status) async {
    await client.rpc<dynamic>(
      'set_co_owner',
      params: {'p_member_id': memberId, 'p_status': status.name},
    );
  }

  @override
  Future<void> activateCoOwner(String memberId) async {
    await client.rpc<dynamic>(
      'activate_co_owner',
      params: {'p_member_id': memberId},
    );
  }

  @override
  Future<void> unsetMyKiosk(String workspaceId) async {
    await client.rpc<dynamic>(
      'unset_my_kiosk',
      params: {'p_workspace_id': workspaceId},
    );
  }

  @override
  Future<void> updateMemberStatus(String memberId, MemberStatus status) async {
    // #982 — through the member_status_change policy.
    final answer = await client.rpc<dynamic>(
      'request_member_status_change',
      params: {'p_member_id': memberId, 'p_status': status.name},
    );
    applyOrPendingVoid(answer);
  }

  @override
  Future<List<Member>> fetchMyMembers() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client.from('members').select().eq('user_id', userId);
    return rows.map(memberFromRow).toList();
  }

  @override
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    await client.rpc<dynamic>(
      'request_role_change',
      params: {
        'p_workspace_id': workspaceId,
        'p_target_member_id': memberId,
        'p_make_admin': makeAdmin,
      },
    );
  }

  @override
  Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return NewMemberDefaults.fromRules(
      row['billing_rules'] as Map<String, dynamic>?,
    );
  }

  @override
  Future<void> setNewMemberDefaults(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    // Keyed, so the merge happens in the database and a sibling billing
    // rule survives (#1089, and 0221's `set_billing_rule`).
    await client.rpc<dynamic>(
      'set_billing_rule',
      params: {
        'p_workspace_id': workspaceId,
        'p_key': newMemberDefaultsKey,
        'p_value': defaults.toValue(),
      },
    );
  }
}
