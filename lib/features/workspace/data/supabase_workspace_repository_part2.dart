// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_workspace_repository.dart';

// #2386 — part 2 of SupabaseWorkspaceRepository, split out of supabase_workspace_repository.dart so no
// file holds the whole class.
extension _SupabaseWorkspaceRepositoryPart2 on SupabaseWorkspaceRepository {

  Future<Map<String, String>> _fetchMemberNamesImpl(String workspaceId) async {
    // members ↔ profiles share auth.users ids but carry no direct FK, so
    // PostgREST cannot embed — two queries, joined client-side.
    final memberRows = await _client
        .from('members')
        .select('id, user_id, managed_identity, managed_name, member_number, home_site_id')
        .eq('workspace_id', workspaceId);
    // #887 — a managed member has no profile: its name is the identity
    // the admin typed (company when the person is nameless).
    String managedName(Map<String, dynamic> r) {
      // #914 — the server derives the addressee line and stores it on
      // the row: the members list needs a name and may not read the
      // identity behind the rule.
      final derived = (r['managed_name'] as String? ?? '').trim();
      if (derived.isNotEmpty) return derived;
      final identity = PersonalInfo.fromDb(
          (r['managed_identity'] as Map?)?.cast<String, dynamic>() ??
              const {});
      return identity.fullName.isNotEmpty
          ? identity.fullName
          : identity.company;
    }
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
            for (final r in await _client.rpc<List<dynamic>>(
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
          (r['purposes'] as List<dynamic>? ?? const <dynamic>[])
                      .contains(purpose) &&
                  r[purpose] is Map
              ? (r[purpose] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
      final operational = group('operational');
      final first = (operational['first_name'] as String? ?? '').trim();
      final last =
          (operational['last_name'] as String? ?? '').trim().toUpperCase();
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

  Future<void> _setRolePermissionImpl(
    String workspaceId,
    String role,
    String permission, {
    required bool enabled,
  }) async {
    // #1089 — the DELTA, never a recomputed list. The server merges it
    // into the row as it stands, and a held change carries the same
    // delta so confirming it cannot undo whatever happened while it
    // waited.
    final answer =
        await _client.rpc<dynamic>('request_matrix_permission', params: {
      'p_workspace_id': workspaceId,
      'p_role': role,
      'p_permission': permission,
      'p_enabled': enabled,
    });
    applyOrPending(answer as Map);
  }

  Future<void> _setRolePermissionsImpl(
    String workspaceId,
    String role,
    List<String> permissions,
  ) async {
    // #982 — through the matrix_change policy: held or applied at once.
    final answer = await _client.rpc<dynamic>('request_matrix_change', params: {
      'p_workspace_id': workspaceId,
      'p_role': role,
      'p_permissions': permissions,
    });
    applyOrPending(answer as Map);
  }

  /// Every write to a `workspaces` row goes through here (#1269).
  ///
  /// `workspaces_update` is owner-only, and an UPDATE that RLS refuses
  /// does not raise — it matches no rows, silently. The settings form
  /// then said "Workspace saved." over a row that had not moved, and
  /// reopening it showed the old value. Reading the id back is what
  /// turns a refusal into an error the caller can show.
  Future<void> _updateWorkspaceRow(
    String workspaceId,
    Map<String, Object?> values,
  ) async {
    final rows = await _client
        .from('workspaces')
        .update(values)
        .eq('id', workspaceId)
        .select('id');
    if (rows.isEmpty) {
      throw StateError(
        'workspace $workspaceId not updated: the row is invisible, or '
        'workspaces_update refused the write (owners and active '
        'co-owners only)',
      );
    }
  }

  Workspace _workspaceFromRow(Map<String, dynamic> row) => Workspace(
        system: SystemColumns.fromRow(row),
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
        branding: row['branding'] as Map<String, dynamic>? ?? const {},
        devMode: row['dev_mode'] as bool? ?? false,
        // #917 — a row without the column is a space that predates
        // 0160, and those are development spaces.
        environment: row['environment'] as String? ?? 'dev',
        pairId: row['pair_id'] as String? ?? '',
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

  Future<void> _setFeatureFlagsImpl(
    String workspaceId,
    Map<String, bool> flags, {
    Map<String, bool>? expected,
  }) async {
    // #963 — a MERGE (0176): the row keeps every key this write does
    // not name, so a caller holding an older copy of the row can no
    // longer put the other switches back to what it remembered.
    // #1329 — with a read-set, the merge is refused if any of it moved.
    try {
      await _client.rpc<dynamic>('set_feature_flags', params: {
        'p_workspace_id': workspaceId,
        'p_flags': flags,
        'p_expected': ?expected,
      });
    } on PostgrestException catch (e, st) {
      // trace-exempt: a conflict is rethrown typed with its stack; the caller traces and explains it.
      if (e.code == FeatureFlagsConflict.sqlState) {
        final named = e.message.split(':').last;
        Error.throwWithStackTrace(
          FeatureFlagsConflict([
            for (final k in named.split(','))
              if (k.trim().isNotEmpty) k.trim(),
          ]),
          st,
        );
      }
      rethrow;
    }
  }

  // RPC because workspaces_update RLS is owner-only; 0081 admits admins.
  Future<void> _setDevModeImpl(String workspaceId, bool enabled) => _client.rpc(
      'set_dev_mode',
      params: {'p_workspace_id': workspaceId, 'p_enabled': enabled});

  Future<List<Member>> _fetchMembersImpl(String workspaceId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return rows.map(_memberFromRow).toList();
  }

  Future<void> _updateMemberSubscriptionImpl(String memberId, int pct) async {
    // #982 — through the subscription_change policy.
    final answer = await _client.rpc<dynamic>('request_subscription_change', params: {
      'p_member_id': memberId,
      'p_pct': pct,
    });
    applyOrPending(answer as Map);
  }

  Future<void> _updateMemberOveragePolicyImpl(
    String memberId,
    OveragePolicy policy,
  ) async {
    await _client
        .from('members')
        .update({'overage_policy': policy.name}).eq('id', memberId);
  }

  Future<void> _setMemberReservationLimitImpl(String memberId, int? limit) async {
    await _client.rpc<dynamic>('set_member_reservation_limit', params: {
      'p_member_id': memberId,
      'p_limit': limit,
    });
  }

  Future<void> _setMemberSimultaneousLimitImpl(String memberId, int? limit) async {
    await _client.rpc<dynamic>('set_member_simultaneous_limit', params: {
      'p_member_id': memberId,
      'p_limit': limit,
    });
  }

  Future<void> _setMemberVatTreatmentImpl(
      String memberId, String treatment, String reason) async {
    // #985 — the counterparty dimension, by whoever may issue invoices.
    await _client.rpc<dynamic>('set_member_vat_treatment', params: {
      'p_member_id': memberId,
      'p_treatment': treatment,
      'p_reason': reason,
    });
  }

  Future<void> _setMemberCustomerCapacityImpl(
      String memberId, String? capacity) async {
    // #1916 — stated by whoever may issue invoices; null = not stated.
    await _client.rpc<dynamic>('set_member_customer_capacity', params: {
      'p_member_id': memberId,
      'p_capacity': capacity,
    });
  }

  Future<void> _setMemberLevelPermissionImpl(
    String memberId, {
    required bool allowed,
  }) async {
    await _client.rpc<dynamic>('set_member_level_permission', params: {
      'p_member_id': memberId,
      'p_allowed': allowed,
    });
  }

  Future<void> _setMemberKioskImpl(String memberId, {required bool isKiosk}) async {
    await _client.rpc<dynamic>('set_member_kiosk', params: {
      'p_member_id': memberId,
      'p_is_kiosk': isKiosk,
    });
  }

  Future<List<MemberBadge>> _fetchMemberBadgesImpl(String workspaceId) async {
    final rows = await _client
        .from('member_badges')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows.map(MemberBadge.fromRow).toList();
  }

  Future<IssuedBadge> _issueMemberBadgeImpl(
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

  Future<IssuedBadge> _issueMyBadgeImpl(
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

  Future<void> _registerMyNfcBadgeImpl(
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

  Future<void> _revokeMyBadgeImpl(String badgeId) async {
    await _client.rpc<dynamic>('revoke_my_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  Future<void> _deleteRevokedBadgeImpl(String badgeId) async {
    await _client.rpc<dynamic>('delete_revoked_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  Future<void> _setCoOwnerImpl(String memberId, CoOwnerStatus status) async {
    await _client.rpc<dynamic>('set_co_owner', params: {
      'p_member_id': memberId,
      'p_status': status.name,
    });
  }

  Future<void> _activateCoOwnerImpl(String memberId) async {
    await _client.rpc<dynamic>('activate_co_owner', params: {
      'p_member_id': memberId,
    });
  }

  Future<void> _unsetMyKioskImpl(String workspaceId) async {
    await _client.rpc<dynamic>('unset_my_kiosk', params: {
      'p_workspace_id': workspaceId,
    });
  }

  Future<void> _registerNfcBadgeImpl(
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

  Future<void> _revokeMemberBadgeImpl(String badgeId) async {
    await _client.rpc<dynamic>('revoke_member_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  Future<void> _updateMemberStatusImpl(String memberId, MemberStatus status) async {
    // #982 — through the member_status_change policy.
    final answer = await _client.rpc<dynamic>('request_member_status_change', params: {
      'p_member_id': memberId,
      'p_status': status.name,
    });
    applyOrPending(answer as Map);
  }

  Future<List<Member>> _fetchMyMembersImpl() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows =
        await _client.from('members').select().eq('user_id', userId);
    return rows.map(_memberFromRow).toList();
  }
}
