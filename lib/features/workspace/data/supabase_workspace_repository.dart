// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/work_hours.dart';
import '../domain/booking_granularity.dart';
import '../domain/booking_policies.dart';
import '../domain/closure_day.dart';
import '../../money/domain/payment_terms.dart';
import '../../profile/domain/personal_info.dart';
import '../domain/member.dart';
import '../domain/member_badge.dart';
import '../domain/overage_policy.dart';
import '../domain/payment_instructions.dart';
import '../domain/workspace.dart';
import '../domain/workspace_repository.dart';
import 'conversation_api.dart';
import '../domain/workspace_document.dart';

class SupabaseWorkspaceRepository
    with ConversationApi
    implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get conversationClient => _client;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    final rows = await _client.from('workspaces').select();
    return rows.map(_workspaceFromRow).toList();
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
  }) async {
    final result = await _client.rpc<dynamic>('create_workspace', params: {
      'p_name': name,
      'p_country_code': countryCode,
      'p_currency_code': currencyCode,
      'p_timezone': timezone,
      'p_environment': environment.wire,
    });
    return result as String;
  }

  @override
  Future<void> setWorkspaceEnvironment(
      String workspaceId, WorkspaceEnvironment environment) async {
    await _client.rpc<dynamic>('set_workspace_environment', params: {
      'p_workspace_id': workspaceId,
      'p_environment': environment.wire,
    });
  }

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final result = await _client.rpc<dynamic>('join_workspace', params: {
      'p_invite_code': inviteCode,
    });
    return result as String;
  }

  @override
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
  }) async {
    final result = await _client.rpc<dynamic>('create_invitation', params: {
      'p_workspace_id': workspaceId,
      'p_is_admin': isAdmin,
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_member_id': ?memberId,
    });
    return result as String;
  }

  @override
  Future<String> createManagedMember(
      String workspaceId, PersonalInfo identity) async {
    final result =
        await _client.rpc<dynamic>('create_managed_member', params: {
      'p_workspace_id': workspaceId,
      'p_identity': identity.normalized().toDb(),
    });
    return result as String;
  }

  @override
  Future<void> updateManagedIdentity(
      String memberId, PersonalInfo identity) async {
    await _client.rpc<dynamic>('update_managed_identity', params: {
      'p_member_id': memberId,
      'p_identity': identity.normalized().toDb(),
    });
  }

  @override
  Future<void> revokeHandover(String memberId) async {
    await _client.rpc<dynamic>('revoke_handover', params: {
      'p_member_id': memberId,
    });
  }

  @override
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    // Direct row update — workspaces_update RLS restricts it to owners,
    // and the 0001 column checks re-validate the ISO shapes (#153).
    await _client.from('workspaces').update({
      'country_code': countryCode.toUpperCase(),
      'currency_code': currencyCode.toUpperCase(),
      'timezone': timezone,
    }).eq('id', workspaceId);
  }

  @override
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    // Wholesale jsonb replace, like feature_flags (#155): the settings
    // form always writes the full three-field blob.
    await _client.from('workspaces').update(
        {'payment_instructions': instructions.toDb()}).eq('id', workspaceId);
  }

  @override
  Future<void> setLegalIdentity(
    String workspaceId, {
    required String vatRegime,
    required String vatId,
    required String legalId,
    required String taxExemptionReason,
    required String street,
    required String city,
    required String postalCode,
    required String vatAccount,
  }) async {
    // Owner-only via workspaces_update RLS; the 0069 column checks cap
    // every field. Written as one row update so an identity can never be
    // half-declared.
    await _client.from('workspaces').update({
      'vat_regime': vatRegime,
      'vat_id': vatId.trim(),
      'legal_id': legalId.trim(),
      'tax_exemption_reason': taxExemptionReason.trim(),
      'street': street.trim(),
      'city': city.trim(),
      'postal_code': postalCode.trim(),
      'vat_account': vatAccount.trim(),
    }).eq('id', workspaceId);
  }

  @override
  Future<void> setSubscriptionVatRate(
    String workspaceId,
    String vatRateId,
  ) async {
    // Owner-only via workspaces_update RLS, like the legal identity.
    await _client.from('workspaces').update({
      'subscription_vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
    }).eq('id', workspaceId);
  }

  @override
  Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) async {
    final rows = await _client
        .from('workspace_documents')
        .select()
        .eq('workspace_id', workspaceId)
        .order('category')
        .order('title');
    return [
      for (final row in rows)
        WorkspaceDocument.fromRow(row),
    ];
  }

  @override
  Future<void> addDocument(WorkspaceDocument document) async {
    await _client.from('workspace_documents').insert({
      'workspace_id': document.workspaceId,
      'title': document.title.trim(),
      'category': document.category,
      'provider': document.provider,
      'url': document.url.trim(),
      'min_role': document.minRole,
    });
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _client
        .from('workspace_documents')
        .delete()
        .eq('id', documentId);
  }

  @override
  Future<void> setWorkspaceLanguage(
    String workspaceId,
    String locale,
  ) async {
    // Owner-only via workspaces_update RLS; 0096 caps at 5 chars.
    await _client
        .from('workspaces')
        .update({'default_locale': locale.trim()}).eq('id', workspaceId);
  }

  @override
  Future<void> setInvitationTemplates(
    String workspaceId,
    Map<String, String> templates,
  ) async {
    // Owner-only via workspaces_update RLS; empty entries are dropped so
    // the jsonb only carries real overrides (0096).
    await _client.from('workspaces').update({
      'invitation_templates': {
        for (final entry in templates.entries)
          if (entry.value.trim().isNotEmpty)
            entry.key: entry.value.trim(),
      },
    }).eq('id', workspaceId);
  }

  @override
  Future<void> setInvoiceLegal(
    String workspaceId,
    Map<String, Object?> legal,
  ) async {
    // Owner-only via workspaces_update RLS; the whole jsonb is replaced
    // (0094) — the mentions are one coherent statement, not a delta.
    await _client
        .from('workspaces')
        .update({'invoice_legal': legal}).eq('id', workspaceId);
  }

  @override
  Future<void> setWorkspaceAddress(String workspaceId, String address) async {
    // Owner-only via workspaces_update RLS; 0060 caps at 400 chars.
    await _client
        .from('workspaces')
        .update({'address': address.trim()}).eq('id', workspaceId);
  }

  @override
Future<void> setWhatsappGroup(String workspaceId, String link) async {

    // Direct row update like setPaymentInstructions — workspaces_update
    // RLS restricts it to owners, and the 0029 column check re-validates
    // the chat.whatsapp.com prefix.
    await _client
        .from('workspaces')
        .update({'whatsapp_group': link.trim()}).eq('id', workspaceId);
  }

  @override
  Future<void> setInvitationTemplate(String workspaceId, String template) async {
    // Same shape as setWhatsappGroup — owner-only RLS, 0049 length check.
    await _client
        .from('workspaces')
        .update({'invitation_template': template.trim()}).eq('id', workspaceId);
  }

  @override
  Future<void> decideMemberJoin(
    String memberId, {
    required bool approve,
  }) async {
    await _client.rpc<dynamic>('decide_member_join', params: {
      'p_member_id': memberId,
      'p_approve': approve,
    });
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _memberFromRow(row);
  }

  @override
  Future<Map<String, String>> fetchMemberEmails(String workspaceId) async {
    // Admin-gated on the server (0078): non-admin callers get [].
    final rows = await _client.rpc<dynamic>('member_emails', params: {
      'p_workspace_id': workspaceId,
    }) as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['member_id'] as String: r['email'] as String,
    };
  }

  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async {
    // members ↔ profiles share auth.users ids but carry no direct FK, so
    // PostgREST cannot embed — two queries, joined client-side.
    final memberRows = await _client
        .from('members')
        .select('id, user_id, managed_identity')
        .eq('workspace_id', workspaceId);
    // #887 — a managed member has no profile: its name is the identity
    // the admin typed (company when the person is nameless).
    String managedName(Map<String, dynamic> r) {
      final identity = PersonalInfo.fromDb(
          (r['managed_identity'] as Map?)?.cast<String, dynamic>() ??
              const {});
      return identity.fullName.isNotEmpty
          ? identity.fullName
          : identity.company;
    }
    final userIds = memberRows
        .map((r) => r['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profileRows = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
        .from('profiles')
        .select('id, display_name, first_name, last_name')
        .inFilter('id', userIds);
    // #886 — a structured name outranks the display name on lists that
    // feed documents; the display name stays the fallback.
    String nameOf(Map<String, dynamic> r) {
      final first = (r['first_name'] as String? ?? '').trim();
      final last = (r['last_name'] as String? ?? '').trim().toUpperCase();
      final full = [first, last].where((s) => s.isNotEmpty).join(' ');
      return full.isNotEmpty ? full : r['display_name'] as String;
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
  Future<void> setRolePermissions(
    String workspaceId,
    String role,
    List<String> permissions,
  ) async {
    await _client.rpc<void>('set_role_permissions', params: {
      'p_workspace_id': workspaceId,
      'p_role': role,
      'p_permissions': permissions,
    });
  }

  Workspace _workspaceFromRow(Map<String, dynamic> row) => Workspace(
        id: row['id'] as String,
        name: row['name'] as String,
        countryCode: row['country_code'] as String,
        currencyCode: row['currency_code'] as String,
        timezone: row['timezone'] as String,
        inviteCode: row['invite_code'] as String,
        featureFlags:
            row['feature_flags'] as Map<String, dynamic>? ?? const {},
        rolePermissions:
            row['role_permissions'] as Map<String, dynamic>? ?? const {},
        devMode: row['dev_mode'] as bool? ?? false,
        // #917 — a row without the column is a space that predates
        // 0160, and those are development spaces.
        environment: row['environment'] as String? ?? 'dev',
        paymentInstructions:
            row['payment_instructions'] as Map<String, dynamic>? ?? const {},
        whatsappGroup: row['whatsapp_group'] as String? ?? '',
        address: row['address'] as String? ?? '',
        deskOpacity: (row['desk_opacity'] as num?)?.toInt() ?? 100,
        invitationTemplate: row['invitation_template'] as String? ?? '',
        vatRegime: row['vat_regime'] as String? ?? 'not_subject',
        vatId: row['vat_id'] as String? ?? '',
        legalId: row['legal_id'] as String? ?? '',
        taxExemptionReason: row['tax_exemption_reason'] as String? ?? '',
        street: row['street'] as String? ?? '',
        city: row['city'] as String? ?? '',
        postalCode: row['postal_code'] as String? ?? '',
        vatAccount: row['vat_account'] as String? ?? '',
        subscriptionVatRateId:
            row['subscription_vat_rate_id'] as String? ?? '',
        invoiceLegal:
            row['invoice_legal'] as Map<String, dynamic>? ?? const {},
        defaultLocale: row['default_locale'] as String? ?? '',
        invitationTemplates:
            row['invitation_templates'] as Map<String, dynamic>? ??
                const {},
      );

  @override
  Future<void> setFeatureFlags(
    String workspaceId,
    Map<String, bool> flags,
  ) async {
    // The whole jsonb is replaced (unlike booking_rules there are no
    // foreign keys inside it): the Features screen always writes the
    // full current map.
    await _client
        .from('workspaces')
        .update({'feature_flags': flags}).eq('id', workspaceId);
  }

  @override
  // RPC because workspaces_update RLS is owner-only; 0081 admits admins.
  Future<void> setDevMode(String workspaceId, bool enabled) => _client.rpc(
      'set_dev_mode',
      params: {'p_workspace_id': workspaceId, 'p_enabled': enabled});

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return rows.map(_memberFromRow).toList();
  }

  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async {
    await _client
        .from('members')
        .update({'subscription_pct': pct}).eq('id', memberId);
  }

  @override
  Future<void> updateMemberOveragePolicy(
    String memberId,
    OveragePolicy policy,
  ) async {
    await _client
        .from('members')
        .update({'overage_policy': policy.name}).eq('id', memberId);
  }

  @override
  Future<void> setMemberReservationLimit(String memberId, int? limit) async {
    await _client.rpc<dynamic>('set_member_reservation_limit', params: {
      'p_member_id': memberId,
      'p_limit': limit,
    });
  }

  @override
  Future<void> setMemberSimultaneousLimit(String memberId, int? limit) async {
    await _client.rpc<dynamic>('set_member_simultaneous_limit', params: {
      'p_member_id': memberId,
      'p_limit': limit,
    });
  }

  @override
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  }) async {
    await _client.rpc<dynamic>('set_member_level_permission', params: {
      'p_member_id': memberId,
      'p_allowed': allowed,
    });
  }

  @override
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) async {
    await _client.rpc<dynamic>('set_member_kiosk', params: {
      'p_member_id': memberId,
      'p_is_kiosk': isKiosk,
    });
  }

  @override
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) async {
    final rows = await _client
        .from('member_badges')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows.map(MemberBadge.fromRow).toList();
  }

  @override
  Future<IssuedBadge> issueMemberBadge(
    String workspaceId,
    String memberId, {
    String label = '',
  }) async {
    final result = await _client.rpc<dynamic>('issue_member_badge', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_label': label,
    }) as Map<String, dynamic>;
    return (
      badgeId: result['badge_id'] as String,
      token: result['token'] as String,
    );
  }

  @override
  Future<IssuedBadge> issueMyBadge(
    String workspaceId, {
    String label = '',
  }) async {
    final result = await _client.rpc<dynamic>('issue_my_badge', params: {
      'p_workspace_id': workspaceId,
      'p_label': label,
    }) as Map<String, dynamic>;
    return (
      badgeId: result['badge_id'] as String,
      token: result['token'] as String,
    );
  }

  @override
  Future<void> registerMyNfcBadge(
    String workspaceId, {
    required String uid,
    String label = '',
  }) async {
    await _client.rpc<dynamic>('register_my_nfc_badge', params: {
      'p_workspace_id': workspaceId,
      'p_uid': uid,
      'p_label': label,
    });
  }

  @override
  Future<void> revokeMyBadge(String badgeId) async {
    await _client.rpc<dynamic>('revoke_my_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  @override
  Future<void> deleteRevokedBadge(String badgeId) async {
    await _client.rpc<dynamic>('delete_revoked_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  @override
  Future<void> setCoOwner(String memberId, CoOwnerStatus status) async {
    await _client.rpc<dynamic>('set_co_owner', params: {
      'p_member_id': memberId,
      'p_status': status.name,
    });
  }

  @override
  Future<void> activateCoOwner(String memberId) async {
    await _client.rpc<dynamic>('activate_co_owner', params: {
      'p_member_id': memberId,
    });
  }

  @override
  Future<void> unsetMyKiosk(String workspaceId) async {
    await _client.rpc<dynamic>('unset_my_kiosk', params: {
      'p_workspace_id': workspaceId,
    });
  }

  @override
  Future<void> registerNfcBadge(
    String workspaceId,
    String memberId, {
    required String uid,
    String label = '',
  }) async {
    await _client.rpc<dynamic>('register_nfc_badge', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_uid': uid,
      'p_label': label,
    });
  }

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    await _client.rpc<dynamic>('revoke_member_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  @override
  Future<void> updateMemberStatus(String memberId, MemberStatus status) async {
    await _client
        .from('members')
        .update({'status': status.name}).eq('id', memberId);
  }

  @override
  Future<List<Member>> fetchMyMembers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows =
        await _client.from('members').select().eq('user_id', userId);
    return rows.map(_memberFromRow).toList();
  }

  @override
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    await _client.rpc<dynamic>('request_role_change', params: {
      'p_workspace_id': workspaceId,
      'p_target_member_id': memberId,
      'p_make_admin': makeAdmin,
    });
  }

  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final result = await _client.rpc<dynamic>('set_workspace_code', params: {
      'p_workspace_id': workspaceId,
      'p_code': code,
    });
    return result as String;
  }

  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    final raw = rules['open_weekdays'] as List<dynamic>?;
    if (raw == null) return const [1, 2, 3, 4, 5];
    return raw.map((e) => (e as num).toInt()).toList();
  }

  @override
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) async {
    // booking_rules is one jsonb column; merge client-side so the other
    // keys (horizon, durations, …) survive the write.
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      'open_weekdays': weekdays,
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<BookingGranularity> fetchBookingGranularity(
    String workspaceId,
  ) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    return BookingGranularity.fromWire(
      rules[BookingRulesKeys.granularity] as String?,
    );
  }

  @override
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  ) async {
    // booking_rules is one jsonb column; merge client-side so the other
    // keys (open_weekdays, horizon, durations, …) survive the write.
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      BookingRulesKeys.granularity: granularity.wireName,
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<WorkHours> fetchWorkHours(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return WorkHours.fromRules(
      row['booking_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<BookingPolicies> fetchBookingPolicies(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return BookingPolicies.fromRules(
        row['booking_rules'] as Map<String, dynamic>?);
  }

  /// THE merge-preserving policy write (#600/#624): one booking_rules
  /// key changes, every other key survives — the same jsonb merge as
  /// setBookingGranularity.
  Future<void> _mergeBookingRule(
    String workspaceId,
    String key,
    Object value,
  ) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      key: value,
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<void> setBookingPolicy(
    String workspaceId,
    String key, {
    required bool enabled,
  }) =>
      _mergeBookingRule(workspaceId, key, enabled);

  @override
  Future<void> setOutsideHoursMode(
    String workspaceId,
    OutsideHoursMode mode,
  ) =>
      _mergeBookingRule(
          workspaceId, BookingPolicies.outsideHoursModeKey, mode.wire);

  @override
  Future<void> setSimultaneousReservations(String workspaceId, int value) =>
      _mergeBookingRule(workspaceId,
          BookingPolicies.simultaneousReservationsKey, value);

  @override
  Future<void> setBookingLimit(String workspaceId, String key, int value) =>
      _mergeBookingRule(workspaceId, key, value);

  @override
  Future<void> setWorkHours(String workspaceId, WorkHours hours) async {
    // Same merge-preserving jsonb write as setBookingGranularity.
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      ...hours.toRules(),
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<String?> fetchDefaultWorkspaceId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('default_workspace_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['default_workspace_id'] as String?;
  }

  @override
  Future<void> setDefaultWorkspaceId(String? workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'default_workspace_id': workspaceId}).eq('id', userId);
  }

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async {
    final rows = await _client
        .from('closure_days')
        .select()
        .eq('workspace_id', workspaceId)
        .order('day', ascending: true);
    return rows.map(_closureDayFromRow).toList();
  }

  @override
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final row = await _client
        .from('closure_days')
        .insert({
          'workspace_id': workspaceId,
          'day': _isoDate(day),
          'reason': reason,
        })
        .select()
        .single();
    return _closureDayFromRow(row);
  }

  @override
  Future<void> removeClosureDay(String closureDayId) async {
    await _client.from('closure_days').delete().eq('id', closureDayId);
  }

  @override
  Future<void> setDeskOpacity(String workspaceId, int opacity) async {
    await _client
        .from('workspaces')
        .update({'desk_opacity': opacity}).eq('id', workspaceId);
  }

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    // SECURITY DEFINER RPC (0039); the owner check + all deletes are atomic
    // server-side.
    await _client.rpc<dynamic>('reset_workspace', params: {
      'p_workspace_id': workspaceId,
    });
  }

  /// Postgres `date` wire format for [day]'s date part.
  String _isoDate(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  ClosureDay _closureDayFromRow(Map<String, dynamic> row) => ClosureDay(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        day: DateTime.parse(row['day'] as String),
        reason: row['reason'] as String? ?? '',
      );

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        // #887 — a managed member has no user yet.
        userId: row['user_id'] as String? ?? '',
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        coOwner: CoOwnerStatus.fromWire(row['co_owner'] as String?),
        status: MemberStatus.values.byName(row['status'] as String),
        subscriptionPct: row['subscription_pct'] as int? ?? 100,
        managedIdentity: PersonalInfo.fromDb(
          (row['managed_identity'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        paymentTerms: row['payment_terms'] is Map
            ? PaymentTerms.fromJson(row['payment_terms'] as Map)
            : null,
        claimedAt: row['claimed_at'] == null
            ? null
            : DateTime.parse(row['claimed_at'] as String),
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
      );
}
