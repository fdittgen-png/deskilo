// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_repository.dart';

// #2386 — part 2 of FakeWorkspaceRepository, split out of workspace_repository.dart so no
// file holds the whole class.
extension _FakeWorkspaceRepositoryPart2 on FakeWorkspaceRepository {

  Future<void> _setMemberReservationLimitImpl(String memberId, int? limit) async {
    if (myMember.id == memberId) {
      throw StateError('cannot set your own reservation limit');
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] =
          otherMembers[i].copyWith(maxActiveReservations: limit);
    }
  }

  Future<void> _setMemberCustomerCapacityImpl(
      String memberId, String? capacity) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(customerCapacity: capacity);
    }
  }

  Future<void> _setMemberVatTreatmentImpl(
      String memberId, String treatment, String reason) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i]
          .copyWith(vatTreatment: treatment, vatExemptionReason: reason);
    }
  }

  Future<void> _setMemberSimultaneousLimitImpl(String memberId, int? limit) async {
    // #628 — the 0119 RPC mirrors 0044's governance: never for oneself.
    if (myMember.id == memberId) {
      throw StateError('cannot set your own simultaneous limit');
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] =
          otherMembers[i].copyWith(maxSimultaneousReservations: limit);
    }
  }

  Future<void> _setMemberLevelPermissionImpl(
    String memberId, {
    required bool allowed,
  }) async {
    levelPermissions[memberId] = allowed;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      otherMembers[i] = otherMembers[i].copyWith(canReserveLevel: allowed);
    }
  }

  Future<void> _setMemberKioskImpl(String memberId, {required bool isKiosk}) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(isKiosk: isKiosk);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(isKiosk: isKiosk);
    }
  }

  Future<List<MemberBadge>> _fetchMemberBadgesImpl(String workspaceId) async =>
      List.of(badges);

  Future<IssuedBadge> _issueMemberBadgeImpl(
    String workspaceId,
    String memberId, {
    String label = '',
  }) async {
    final n = badges.length + 1;
    badges.add(MemberBadge(
      id: 'badge-$n',
      workspaceId: workspaceId,
      memberId: memberId,
      label: label,
      createdAt: kTestNow,
    ));
    return (badgeId: 'badge-$n', token: 'badge-token-$n');
  }

  Future<void> _registerNfcBadgeImpl(
    String workspaceId,
    String memberId, {
    required String uid,
    String label = '',
  }) async {
    // Duplicate-tag path (register_nfc_badge's pinned refusal, 0046).
    if (badges.any((b) => b.label == 'uid:$uid' && b.isActive)) {
      throw const PostgrestException(message: 'tag already registered');
    }
    badges.add(MemberBadge(
      id: 'badge-${badges.length + 1}',
      workspaceId: workspaceId,
      memberId: memberId,
      // The fake records the uid in the label so tests can assert it.
      label: label.isEmpty ? 'uid:$uid' : label,
      createdAt: kTestNow,
      kind: BadgeKind.nfc,
    ));
  }

  Future<void> _revokeMemberBadgeImpl(String badgeId) async {
    final i = badges.indexWhere((b) => b.id == badgeId);
    if (i >= 0) {
      badges[i] = badges[i].copyWith(revokedAt: kTestNow);
    }
  }

  /// (0053) Self-service paths — the fake reuses the admin bodies with
  /// the caller's own member id.
  Future<IssuedBadge> _issueMyBadgeImpl(
    String workspaceId, {
    String label = '',
  }) =>
      issueMemberBadge(workspaceId, myMember.id, label: label);

  Future<void> _registerMyNfcBadgeImpl(
    String workspaceId, {
    required String uid,
    String label = '',
  }) =>
      registerNfcBadge(workspaceId, myMember.id, uid: uid, label: label);

  Future<void> _revokeMyBadgeImpl(String badgeId) => revokeMemberBadge(badgeId);

  Future<void> _deleteRevokedBadgeImpl(String badgeId) async {
    final before = badges.length;
    badges.removeWhere((b) => b.id == badgeId && !b.isActive);
    // Server contract (0055): live or unknown badges refuse.
    if (badges.length == before) {
      throw const PostgrestException(message: 'unknown badge');
    }
  }

  Future<void> _setWorkspaceAddressImpl(String workspaceId, String address) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(address: address.trim());
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
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    // One copyWith, like the server's one row update: the identity and
    // the mentions that go on the invoice with it move together or not
    // at all (#1532).
    workspaces[i] = workspaces[i].copyWith(
      vatRegime: vatRegime,
      vatId: vatId.trim(),
      legalId: legalId.trim(),
      taxExemptionReason: taxExemptionReason.trim(),
      street: street.trim(),
      city: city.trim(),
      postalCode: postalCode.trim(),
      vatAccount: vatAccount.trim(),
      invoiceLegal: Map<String, dynamic>.from(invoiceLegal),
    );
  }

  Future<void> _setSubscriptionVatRateImpl(
    String workspaceId,
    String vatRateId,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] =
        workspaces[i].copyWith(subscriptionVatRateId: vatRateId);
  }

  Future<List<WorkspaceDocument>> _fetchDocumentsImpl(String workspaceId) async {
    // Mirror the RLS role gate so tests see honest visibility.
    bool visible(WorkspaceDocument d) => switch (d.minRole) {
          'owner' => myMember.isOwner,
          'admin' => myMember.isAdmin || myMember.isOwner,
          _ => true,
        };
    return documents
        .where((d) => d.workspaceId == workspaceId && visible(d))
        .toList();
  }

  Future<void> _addDocumentImpl(WorkspaceDocument document) async {
    documents.add(WorkspaceDocument(
      id: 'doc-${documents.length + 1}',
      workspaceId: document.workspaceId,
      title: document.title.trim(),
      category: document.category,
      provider: document.provider,
      url: document.url.trim(),
      minRole: document.minRole,
    ));
  }

  Future<void> _deleteDocumentImpl(String documentId) async {
    documents.removeWhere((d) => d.id == documentId);
  }

  Future<void> _setWorkspaceLanguageImpl(String workspaceId, String locale) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(defaultLocale: locale.trim());
  }

  Future<void> _setRolePermissionsImpl(
    String workspaceId,
    String role,
    List<String> permissions,
  ) async {
    // #513 — mirrors set_role_permissions: caller must hold manageRoles.
    if (!effectivePermissions(myMember, workspaces.firstOrNull)
        .contains(WorkspacePermission.manageRoles)) {
      throw StateError('only role managers may edit permissions');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(rolePermissions: {
      ...workspaces[i].rolePermissions,
      role: permissions,
    });
  }

  /// #1089 — mirrors `set_role_permission`: ONE permission, merged into
  /// the list as it stands. A fake that recomputed the whole list would
  /// pass a test the server would fail, which is how the defect survived.
  Future<void> _setRolePermissionImpl(
    String workspaceId,
    String role,
    String permission, {
    required bool enabled,
  }) async {
    if (!effectivePermissions(myMember, workspaces.firstOrNull)
        .contains(WorkspacePermission.manageRoles)) {
      throw StateError('only role managers may edit permissions');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    // rolePermissions is Map<String, dynamic>; strict-casts (#1060)
    // refuses to spread a dynamic, and the stored value is a JSON list.
    final stored = workspaces[i].rolePermissions[role] as List<Object?>?;
    final current = <String>[
      for (final p in stored ?? const <Object?>[]) '$p',
    ]
      ..remove(permission);
    if (enabled) current.add(permission);
    current.sort();
    workspaces[i] = workspaces[i].copyWith(rolePermissions: {
      ...workspaces[i].rolePermissions,
      role: current,
    });
  }

  Future<void> _setInvitationTemplatesImpl(
    String workspaceId,
    Map<String, String> templates,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(invitationTemplates: {
      for (final entry in templates.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    });
  }

  Future<void> _setCoOwnerImpl(String memberId, CoOwnerStatus status) async {
    // Server contract (0058): active co-owners also become admins.
    Member patch(Member m) => m.copyWith(
        coOwner: status,
        isAdmin: status == CoOwnerStatus.active || m.isAdmin);
    if (myMember.id == memberId) {
      myMember = patch(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = patch(otherMembers[i]);
  }

  Future<void> _activateCoOwnerImpl(String memberId) async {
    Member promote(Member m) =>
        m.copyWith(isOwner: true, isAdmin: true, coOwner: CoOwnerStatus.none);
    if (myMember.id == memberId) {
      myMember = promote(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = promote(otherMembers[i]);
  }

  Future<void> _unsetMyKioskImpl(String workspaceId) async {
    // Server contract (0056): only an actual kiosk membership reverts.
    if (!myMember.isKiosk || myMember.workspaceId != workspaceId) {
      throw const PostgrestException(
        message: 'not a kiosk of this workspace',
      );
    }
    myMember = myMember.copyWith(isKiosk: false);
  }

  Future<void> _requestRoleChangeImpl(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    lastRoleChange = (workspaceId, memberId, makeAdmin);
  }

  Future<String> _setWorkspaceCodeImpl(String workspaceId, String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalized)) {
      throw StateError('workspace ID must be 4-20 letters or digits');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(inviteCode: normalized);
    return normalized;
  }

  Future<void> _setFeatureFlagsImpl(
    String workspaceId,
    Map<String, bool> flags, {
    Map<String, bool>? expected,
  }) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) throw StateError('unknown workspace $workspaceId');
    flagExpectations.add(expected == null ? null : Map.of(expected));
    if (flagConflictNext) {
      flagConflictNext = false;
      throw FeatureFlagsConflict(expected?.keys.take(1).toList() ?? const []);
    }
    // #1329 — the server compares the read-set through the registry
    // defaults (feature_raw); the fake resolves the same way.
    if (expected != null) {
      final current = resolveEnabledFeatures(workspaces[i].featureFlags);
      final stale = [
        for (final e in expected.entries)
          if (current.any((WorkspaceFeature f) => f.dbKey == e.key) != e.value)
            e.key,
      ]..sort();
      if (stale.isNotEmpty) throw FeatureFlagsConflict(stale);
    }
    flagWrites.add(Map.of(flags));
    // A MERGE, like set_feature_flags (0176, #963).
    workspaces[i] = workspaces[i].copyWith(
      featureFlags: {...workspaces[i].featureFlags, ...flags},
    );
  }

  Future<List<int>> _fetchOpenWeekdaysImpl(String workspaceId) async =>
      List.of(openWeekdays[workspaceId] ?? const [1, 2, 3, 4, 5]);

  Future<void> _setOpenWeekdaysImpl(String workspaceId, List<int> weekdays) async {
    openWeekdays[workspaceId] = List.of(weekdays);
  }

  Future<BookingGranularity> _fetchBookingGranularityImpl(
    String workspaceId,
  ) async =>
      bookingGranularities[workspaceId] ?? BookingGranularity.flexible;

  Future<void> _setBookingGranularityImpl(
    String workspaceId,
    BookingGranularity granularity,
  ) async {
    bookingGranularities[workspaceId] = granularity;
  }

  Future<String?> _fetchDefaultPeriodImpl(String workspaceId) async =>
      workspaceDefaultPeriods[workspaceId];

  Future<void> _setDefaultPeriodImpl(String workspaceId, String? wire) async {
    workspaceDefaultPeriods[workspaceId] = (wire ?? '').isEmpty ? null : wire;
  }

  Future<NewMemberDefaults> _fetchNewMemberDefaultsImpl(String workspaceId) async =>
      newMemberDefaults[workspaceId] ?? const NewMemberDefaults();

  Future<void> _setNewMemberDefaultsImpl(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    newMemberDefaults[workspaceId] = defaults;
  }

  Future<void> _setWorkspaceEmblemImpl(String workspaceId, Uint8List png) async {
    emblems[workspaceId] = png;
  }

  Future<Uint8List?> _fetchWorkspaceEmblemImpl(String workspaceId) async =>
      emblems[workspaceId];
}
