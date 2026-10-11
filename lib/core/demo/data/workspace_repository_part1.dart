// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_repository.dart';

// #2386 — part 1 of FakeWorkspaceRepository, split out of workspace_repository.dart so no
// file holds the whole class.
extension _FakeWorkspaceRepositoryPart1 on FakeWorkspaceRepository {

  /// Workspace-wide dev mode (#419): mirrors the 0081 column + RPC.
  /// Admin-gated like the server; [applyDevMode] seeds the initial state.
  void _applyDevModeImpl(bool enabled) {
    for (var i = 0; i < workspaces.length; i++) {
      workspaces[i] = workspaces[i].copyWith(devMode: enabled);
    }
  }

  Future<void> _setDevModeImpl(String workspaceId, bool enabled) async {
    if (!myMember.canAdminister) {
      throw const PostgrestException(
          message: 'not an admin of this workspace');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(devMode: enabled);
  }

  /// Mirrors the server rules (0051): admins mint member invites, only
  /// owners mint admin invites.
  Future<String> _createInvitationImpl(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
    bool alsoProd = false,
  }) async {
    if (isAdmin && !myMember.isOwner) {
      throw Exception('only owners may invite admins');
    }
    if (!isAdmin && !myMember.isAdmin) {
      throw Exception('only admins may invite members');
    }
    final code = 'INVITE${_nextInviteCode++}Z';
    mintedInvitations.add((
      code: code,
      isAdmin: isAdmin,
      firstName: firstName,
      lastName: lastName,
      memberId: memberId,
      alsoProd: alsoProd,
    ));
    return code;
  }

  Future<List<Workspace>> _fetchMyWorkspacesImpl() async {
    if (fetchFailure case final failure?) throw failure;
    return List.of(workspaces);
  }

  Future<List<Site>> _fetchSitesImpl(String workspaceId) async => [
        ...sites.where((s) => s.workspaceId == workspaceId && s.isDefault),
        ...sites.where((s) => s.workspaceId == workspaceId && !s.isDefault),
      ];

  Future<String> _upsertSiteImpl(String workspaceId, Site site, {bool isNew = false}) async {
    final id = isNew ? 'site-${sites.length + 1}' : site.id;
    sites.removeWhere((s) => s.id == id);
    sites.add(Site(
      id: id, workspaceId: workspaceId, name: site.name, street: site.street,
      postalCode: site.postalCode, city: site.city, countryCode: site.countryCode,
      legalId: site.legalId, vatId: site.vatId, taxExemptionReason: site.taxExemptionReason,
      isDefault: site.isDefault, sortOrder: site.sortOrder,
    ));
    siteWrites.add('${isNew ? 'new' : 'edit'}:${site.name}');
    return id;
  }

  Future<void> _deleteSiteImpl(String siteId) async {
    sites.removeWhere((s) => s.id == siteId && !s.isDefault);
    siteWrites.add('delete:$siteId');
  }

  Future<void> _setMemberHomeSiteImpl(String memberId, String? siteId) async {
    homeSites[memberId] = siteId;
  }

  Future<bool> _isPlatformOwnerImpl() async => platformOwner;

  Future<List<WorkspaceOverview>> _fetchAllWorkspacesImpl() async {
    if (!platformOwner) throw StateError('platform owners only');
    return List.of(allWorkspaces);
  }

  Future<List<WorkspaceOwner>> _fetchWorkspaceOwnersImpl(String workspaceId) async {
    if (!platformOwner) throw StateError('platform owners only');
    ownerReads.add(workspaceId);
    return List.of(ownersByWorkspace[workspaceId] ?? const []);
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
    // #1303 — the server's replay rule: one workspace per request id.
    final replayed = requestId == null ? null : createdByRequest[requestId];
    if (replayed != null) return replayed;
    createRequests.add((requestId: requestId, templateId: templateId, withTwin: withTwin));
    final failure = createFailure;
    if (failure != null) {
      createFailure = null;
      throw failure;
    }
    final workspace = Workspace(
      id: 'ws-created-${_nextId++}',
      rolePermissions: everydayMatrix(),
      name: name,
      countryCode: countryCode,
      currencyCode: currencyCode,
      timezone: timezone,
      inviteCode: 'NEWCODE$_nextId',
      // #917 — what the server's default does, mirrored here.
      environment: environment.wire,
    );
    workspaces.add(workspace);
    if (requestId != null) createdByRequest[requestId] = workspace.id;
    return workspace.id;
  }

  Future<String> _createWorkspaceTwinImpl(String workspaceId) async {
    final index = workspaces.indexWhere((w) => w.id == workspaceId);
    if (index < 0) throw StateError('unknown workspace');
    final source = workspaces[index];
    if (source.pairId.isNotEmpty) {
      throw StateError('this workspace already has its twin');
    }
    final pair = 'pair-${twinsCreated.length + 1}';
    workspaces[index] = source.copyWith(pairId: pair);
    final twin = source.copyWith(
      id: '${source.id}-twin',
      pairId: pair,
      environment: source.environment == 'prod' ? 'dev' : 'prod',
    );
    workspaces.add(twin);
    twinsCreated.add(twin.id);
    return twin.id;
  }

  Future<void> _setWorkspaceEnvironmentImpl(
      String workspaceId, WorkspaceEnvironment environment) async {
    lastEnvironment = environment.wire;
    final index = workspaces.indexWhere((w) => w.id == workspaceId);
    if (index >= 0) {
      workspaces[index] =
          workspaces[index].copyWith(environment: environment.wire);
    }
  }

  Future<void> _decideMemberJoinImpl(
    String memberId, {
    required bool approve,
    String comment = '',
    String? expectedAccount,
  }) async {
    joinDecisions[memberId] = approve;
    joinComments[memberId] = comment;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      otherMembers[i] = otherMembers[i].copyWith(
        status: approve ? MemberStatus.active : MemberStatus.exited,
      );
    }
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(
        status: approve ? MemberStatus.active : MemberStatus.exited,
      );
    }
  }

  Future<String> _joinWorkspaceImpl(String inviteCode) async {
    final invitation = mintedInvitations
        .where((i) => i.code == inviteCode)
        .firstOrNull;
    var joinAsAdmin = false;
    if (invitation != null) {
      if (!redeemedInvitations.add(inviteCode)) {
        throw StateError('invalid invite code');
      }
      joinAsAdmin = invitation.isAdmin;
    } else if (inviteCode != 'GOODCODE22') {
      throw StateError('invalid invite code');
    }
    final workspace = Workspace(
      id: 'ws-joined-${_nextId++}',
      rolePermissions: everydayMatrix(),
      name: 'Joined Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: inviteCode,
    );
    workspaces.add(workspace);
    if (joinsArePending) {
      // Server truth since 0052: the joined membership awaits validation.
      myMember = myMember.copyWith(
        workspaceId: workspace.id,
        status: MemberStatus.pending,
        isAdmin: joinAsAdmin,
        isOwner: false,
      );
    }
    return workspace.id;
  }

  Future<InvitationAnswer> _previewInvitationImpl(String inviteCode) async {
    previewCalls++;
    return _invitationState(inviteCode.trim().toUpperCase());
  }

  InvitationAnswer _invitationState(String code) {
    final fixed = invitationAnswers[code];
    if (fixed != null) return fixed;
    final joined = joinedByCode[code];
    if (joined != null) {
      return InvitationAnswer(InvitationState.alreadyMember,
          workspaceId: joined, workspaceName: 'Joined Space',
          memberStatus: myMember.workspaceId == joined ? myMember.status : MemberStatus.active);
    }
    final minted = mintedInvitations.where((i) => i.code == code).firstOrNull;
    if (minted != null && redeemedInvitations.contains(code)) {
      return const InvitationAnswer(InvitationState.wrongAccount);
    }
    if (minted == null && code != 'GOODCODE22') {
      return const InvitationAnswer(InvitationState.invalid);
    }
    return InvitationAnswer(InvitationState.valid,
        workspaceName: 'Joined Space', environment: 'dev',
        offeredRole: minted?.isAdmin ?? false ? InviteRole.admin : InviteRole.user,
        requiresApproval: true);
  }

  Future<InvitationAnswer> _joinByInvitationImpl(String inviteCode) async {
    joinByInvitationCalls++;
    final code = inviteCode.trim().toUpperCase();
    final before = _invitationState(code);
    if (before.state != InvitationState.valid) return before;
    final id = await joinWorkspace(code);
    joinedByCode[code] = id;
    final status = myMember.workspaceId == id ? myMember.status : MemberStatus.active;
    return InvitationAnswer(
        status == MemberStatus.pending ? InvitationState.joinedPending : InvitationState.joinedActive,
        workspaceId: id, workspaceName: 'Joined Space', environment: 'dev',
        offeredRole: before.offeredRole, memberStatus: status);
  }

  Future<void> _updateWorkspaceLocaleImpl(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    lastLocaleUpdate = [workspaceId, countryCode, currencyCode, timezone];
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(
        countryCode: countryCode,
        currencyCode: currencyCode,
        timezone: timezone,
      );
    }
  }

  Future<void> _setPaymentInstructionsImpl(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    lastPaymentInstructions = instructions;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] =
          workspaces[i].copyWith(paymentInstructions: instructions.toDb());
    }
  }

  Future<void> _setWhatsappGroupImpl(String workspaceId, String link) async {
    lastWhatsappGroup = link;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(whatsappGroup: link);
    }
  }

  Future<void> _setInvitationTemplateImpl(String workspaceId, String template) async {
    lastInvitationTemplate = template;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(invitationTemplate: template);
    }
  }

  Future<Member?> _fetchMyMemberImpl(String workspaceId) async =>
      [myMember, ...extraMyMemberships]
          .where((m) => m.workspaceId == workspaceId)
          .firstOrNull ??
      myMember.copyWith(workspaceId: workspaceId);

  Future<Map<String, String>> _fetchMemberNamesImpl(String workspaceId) async => {
        ...memberNames,
        // #887 — a managed member is named from its identity, as the
        // server does.
        for (final m in otherMembers)
          if (m.isManaged) m.id: m.managedIdentity.fullName,
      };

  Future<Map<String, String>> _fetchMemberEmailsImpl(String workspaceId) async =>
      (myMember.isAdmin || myMember.isOwner) &&
              myMember.status == MemberStatus.active
          ? Map.of(memberEmails)
          : const {};

  Future<String> _createManagedMemberImpl(
    String workspaceId,
    PersonalInfo identity, {
    ManagedAccess access = ManagedAccess.unnarrowed,
  }) async {
    final id = 'managed-${_nextManagedId++}';
    otherMembers.add(Member(
      id: id,
      workspaceId: workspaceId,
      userId: '',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
      // #915 — the row carries the PUBLIC half only, as the server does.
      managedIdentity: PersonalInfo(
        courtesy: identity.courtesy,
        firstName: identity.firstName.trim(),
        lastName: identity.lastName.trim(),
        company: identity.company.trim(),
        countryCode: identity.countryCode.trim().toUpperCase(),
      ),
      managedName: identity.normalized().fullName,
      managedAccess: access.toJson(),
    ));
    managedIdentities[id] = identity.normalized();
    return id;
  }

  Future<PersonalInfo> _managedIdentityOfImpl(String memberId) async =>
      managedIdentities[memberId] ?? PersonalInfo.empty;

  Future<void> _setManagedAccessImpl(String memberId, ManagedAccess access) async {
    lastManagedAccess = access;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] =
          otherMembers[i].copyWith(managedAccess: access.toJson());
    }
  }

  Future<void> _updateManagedIdentityImpl(
      String memberId, PersonalInfo identity) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i < 0) throw StateError('member not found');
    otherMembers[i] =
        otherMembers[i].copyWith(managedIdentity: identity.normalized());
  }

  Future<void> _revokeHandoverImpl(String memberId) async {
    revokedHandovers.add(memberId);
    mintedInvitations.removeWhere((i) => i.memberId == memberId);
  }

  Future<List<Member>> _fetchMembersImpl(String workspaceId) async =>
      [myMember, ...otherMembers];

  Future<List<Member>> _fetchMyMembersImpl() async =>
      [myMember, ...extraMyMemberships];

  Future<void> _updateMemberSubscriptionImpl(String memberId, int pct) async {
    if (pct < 0 || pct > 100) throw StateError('pct out of range');
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(subscriptionPct: pct);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(subscriptionPct: pct);
    }
  }

  Future<void> _updateMemberOveragePolicyImpl(
    String memberId,
    OveragePolicy policy,
  ) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(overagePolicy: policy);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(overagePolicy: policy);
    }
  }
}
