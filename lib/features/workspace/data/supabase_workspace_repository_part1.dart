// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_workspace_repository.dart';

// #2386 — part 1 of SupabaseWorkspaceRepository, split out of supabase_workspace_repository.dart so no
// file holds the whole class.
extension _SupabaseWorkspaceRepositoryPart1 on SupabaseWorkspaceRepository {

  SupabaseClient get _clientImpl => _client;

  SupabaseClient get _conversationClientImpl => _client;

  Future<List<Workspace>> _fetchMyWorkspacesImpl() async {
    final rows = await _client.from('workspaces').select();
    return rows.map(_workspaceFromRow).toList();
  }

  Future<List<Site>> _fetchSitesImpl(String workspaceId) async {
    final rows = await _client
        .from('sites')
        .select()
        .eq('workspace_id', workspaceId)
        .order('is_default', ascending: false)
        .order('sort_order')
        .order('name');
    return rows.map((r) => Site.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  Future<String> _upsertSiteImpl(String workspaceId, Site site, {bool isNew = false}) async {
    final r = await _client.rpc<dynamic>('upsert_site', params: {
      'p_workspace_id': workspaceId,
      'p_id': isNew ? null : site.id,
      'p_name': site.name,
      'p_street': site.street,
      'p_postal_code': site.postalCode,
      'p_city': site.city,
      'p_country_code': site.countryCode,
      'p_legal_id': site.legalId,
      'p_sort_order': site.sortOrder,
      'p_vat_id': site.vatId,
      'p_tax_exemption_reason': site.taxExemptionReason,
    });
    return r as String;
  }

  Future<void> _deleteSiteImpl(String siteId) async {
    await _client.rpc<dynamic>('delete_site', params: {'p_site_id': siteId});
  }

  Future<void> _setMemberHomeSiteImpl(String memberId, String? siteId) async {
    await _client.rpc<dynamic>('set_member_home_site',
        params: {'p_member_id': memberId, 'p_site_id': siteId});
  }

  Future<bool> _isPlatformOwnerImpl() async {
    final r = await _client.rpc<dynamic>('is_platform_owner');
    return r == true;
  }

  Future<List<WorkspaceOverview>> _fetchAllWorkspacesImpl() async {
    final rows = await _client.rpc<dynamic>('list_all_workspaces') as List;
    return [
      for (final r in rows)
        WorkspaceOverview.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<List<WorkspaceOwner>> _fetchWorkspaceOwnersImpl(String workspaceId) async {
    final rows = await _client.rpc<dynamic>(
      'workspace_owners',
      params: {'p_workspace_id': workspaceId},
    ) as List;
    return [
      for (final r in rows)
        WorkspaceOwner.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<String> _createWorkspaceImpl({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = true,
    String? requestId,
    String? templateId,
  }) async {
    // #1303 — with a request id, creation and the first template are one
    // replayable act (0228).
    final once = requestId != null;
    final result = await _client.rpc<dynamic>(
        once ? 'create_workspace_once' : 'create_workspace',
        params: {
      if (once) 'p_client_request_id': requestId,
      if (once) 'p_template_id': templateId,
      'p_name': name,
      'p_country_code': countryCode,
      'p_currency_code': currencyCode,
      'p_timezone': timezone,
      'p_environment': environment.wire,
      // #987 — the dev and the prod, created together.
      'p_with_twin': withTwin,
      // #1063 — Core on, Platform off, written EXPLICITLY at creation.
      // The server takes the object rather than knowing the catalogue:
      // a second copy of it in SQL would disagree with this one within a
      // release.
      // #1550 — created WITH a twin means created showing the couple.
      'p_feature_flags': defaultFeatureFlagsForNewWorkspace(withTwin: withTwin),
    });
    return result as String;
  }

  Future<String> _createWorkspaceTwinImpl(String workspaceId) async {
    // #987 — the missing side of a lone workspace, configuration copied.
    final result = await _client.rpc<dynamic>('create_workspace_twin', params: {
      'p_workspace_id': workspaceId,
    });
    return result as String;
  }

  Future<void> _setWorkspaceEnvironmentImpl(
      String workspaceId, WorkspaceEnvironment environment) async {
    await _client.rpc<dynamic>('set_workspace_environment', params: {
      'p_workspace_id': workspaceId,
      'p_environment': environment.wire,
    });
  }

  Future<String> _joinWorkspaceImpl(String inviteCode) async {
    final result = await _client.rpc<dynamic>('join_workspace', params: {
      'p_invite_code': inviteCode,
    });
    return result as String;
  }

  Future<InvitationAnswer> _previewInvitationImpl(String inviteCode) async =>
      InvitationAnswer.fromJson(await _client.rpc<dynamic>(
          'invitation_preview', params: {'p_code': inviteCode}));

  Future<InvitationAnswer> _joinByInvitationImpl(String inviteCode) async =>
      InvitationAnswer.fromJson(await _client.rpc<dynamic>(
          'join_by_invitation', params: {'p_code': inviteCode}));

  Future<String> _createInvitationImpl(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
    bool alsoProd = false,
  }) async {
    final result = await _client.rpc<dynamic>('create_invitation', params: {
      'p_workspace_id': workspaceId,
      'p_is_admin': isAdmin,
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_member_id': ?memberId,
      'p_also_prod': alsoProd,
    });
    return result as String;
  }

  Future<String> _createManagedMemberImpl(
    String workspaceId,
    PersonalInfo identity, {
    ManagedAccess access = ManagedAccess.unnarrowed,
  }) async {
    final result =
        await _client.rpc<dynamic>('create_managed_member', params: {
      'p_workspace_id': workspaceId,
      'p_identity': identity.normalized().toDb(),
      'p_access': access.toJson(),
    });
    return result as String;
  }

  Future<PersonalInfo> _managedIdentityOfImpl(String memberId) async {
    final result = await _client.rpc<dynamic>('managed_identity_of', params: {
      'p_member_id': memberId,
    });
    return PersonalInfo.fromDb(
      (result as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> _setManagedAccessImpl(String memberId, ManagedAccess access) async {
    await _client.rpc<dynamic>('set_managed_access', params: {
      'p_member_id': memberId,
      'p_access': access.toJson(),
    });
  }

  Future<void> _updateManagedIdentityImpl(
      String memberId, PersonalInfo identity) async {
    await _client.rpc<dynamic>('update_managed_identity', params: {
      'p_member_id': memberId,
      'p_identity': identity.normalized().toDb(),
    });
  }

  Future<void> _revokeHandoverImpl(String memberId) async {
    await _client.rpc<dynamic>('revoke_handover', params: {
      'p_member_id': memberId,
    });
  }

  Future<void> _updateWorkspaceLocaleImpl(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    // Direct row update — workspaces_update RLS restricts it to owners,
    // and the 0001 column checks re-validate the ISO shapes (#153).
    await _updateWorkspaceRow(workspaceId, {
      'country_code': countryCode.toUpperCase(),
      'currency_code': currencyCode.toUpperCase(),
      'timezone': timezone,
    });
  }

  Future<void> _setPaymentInstructionsImpl(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    // Wholesale jsonb replace, like feature_flags (#155): the settings
    // form always writes the full three-field blob.
    await _updateWorkspaceRow(
        workspaceId, {'payment_instructions': instructions.toDb()});
  }

  Future<void> _setLegalIdentityImpl(
    String workspaceId, {
    required String vatRegime,
    required String vatId,
    required String legalId,
    required String taxExemptionReason,
    required String street,
    required String city,
    required String postalCode,
    required String vatAccount,
    required Map<String, Object?> invoiceLegal,
  }) async {
    // Owner-only via workspaces_update RLS; the 0069 column checks cap
    // every field. ONE row update, so an identity can never be
    // half-declared — and the statutory mentions ride in it, because a
    // VAT regime saved without them is the same half-declaration one
    // level up (#1532).
    await _updateWorkspaceRow(workspaceId, {
      'vat_regime': vatRegime,
      'vat_id': vatId.trim(),
      'legal_id': legalId.trim(),
      'tax_exemption_reason': taxExemptionReason.trim(),
      'street': street.trim(),
      'city': city.trim(),
      'postal_code': postalCode.trim(),
      'vat_account': vatAccount.trim(),
      'invoice_legal': invoiceLegal,
    });
  }

  Future<void> _setSubscriptionVatRateImpl(
    String workspaceId,
    String vatRateId,
  ) async {
    // Owner-only via workspaces_update RLS, like the legal identity.
    await _updateWorkspaceRow(workspaceId, {
      'subscription_vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
    });
  }

  Future<List<WorkspaceDocument>> _fetchDocumentsImpl(String workspaceId) async {
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

  Future<void> _addDocumentImpl(WorkspaceDocument document) async {
    await _client.from('workspace_documents').insert({
      'workspace_id': document.workspaceId,
      'title': document.title.trim(),
      'category': document.category,
      'provider': document.provider,
      'url': document.url.trim(),
      'min_role': document.minRole,
    });
  }

  Future<void> _deleteDocumentImpl(String documentId) async {
    await _client
        .from('workspace_documents')
        .delete()
        .eq('id', documentId);
  }

  Future<void> _setWorkspaceLanguageImpl(
    String workspaceId,
    String locale,
  ) async {
    // Owner-only via workspaces_update RLS; 0096 caps at 5 chars.
    await _updateWorkspaceRow(workspaceId, {'default_locale': locale.trim()});
  }

  Future<void> _setInvitationTemplatesImpl(
    String workspaceId,
    Map<String, String> templates,
  ) async {
    // Owner-only via workspaces_update RLS; empty entries are dropped so
    // the jsonb only carries real overrides (0096).
    await _updateWorkspaceRow(workspaceId, {
      'invitation_templates': {
        for (final entry in templates.entries)
          if (entry.value.trim().isNotEmpty)
            entry.key: entry.value.trim(),
      },
    });
  }

  
  Future<void> _setWorkspaceAddressImpl(String workspaceId, String address) async {
    // Owner-only via workspaces_update RLS; 0060 caps at 400 chars.
    await _updateWorkspaceRow(workspaceId, {'address': address.trim()});
  }

  Future<void> _setWhatsappGroupImpl(String workspaceId, String link) async {

    // Direct row update like setPaymentInstructions — workspaces_update
    // RLS restricts it to owners, and the 0029 column check re-validates
    // the chat.whatsapp.com prefix.
    await _updateWorkspaceRow(
        workspaceId, {'whatsapp_group': link.trim()});
  }

  Future<void> _setInvitationTemplateImpl(String workspaceId, String template) async {
    // Same shape as setWhatsappGroup — owner-only RLS, 0049 length check.
    await _updateWorkspaceRow(
        workspaceId, {'invitation_template': template.trim()});
  }

  Future<void> _decideMemberJoinImpl(
    String memberId, {
    required bool approve,
    String comment = '',
    String? expectedAccount,
  }) async {
    await _client.rpc<dynamic>('decide_workspace_application', params: {
      'p_member_id': memberId,
      'p_approve': approve,
      'p_comment': comment,
      'p_expected_account': expectedAccount ?? _client.auth.currentUser?.id,
    });
  }

  Future<Member?> _fetchMyMemberImpl(String workspaceId) async {
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

  Future<Map<String, String>> _fetchMemberEmailsImpl(String workspaceId) async {
    // Admin-gated on the server (0078): non-admin callers get [].
    final rows = await _client.rpc<dynamic>('member_emails', params: {
      'p_workspace_id': workspaceId,
    }) as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['member_id'] as String: r['email'] as String,
    };
  }
}
