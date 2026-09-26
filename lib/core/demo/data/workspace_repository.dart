// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0028 (#1373) — moved out of test/helpers/mock_providers.dart so the
// Demo environment can run the real app against it. The suite reaches it
// through the same import as before.

import 'dart:typed_data' show Uint8List;
import 'dart:async';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/domain/public_holidays.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/feature_flags_write.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'fixture_clock.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/features/workspace/domain/managed_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/template_publication.dart';
import 'package:deskilo/features/workspace/domain/work_hours_provenance.dart';
import 'package:deskilo/features/workspace/domain/workspace_settings_save.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';

/// In-memory [WorkspaceRepository] for tests.
class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({List<Workspace>? workspaces})
      : workspaces = workspaces ?? [];

  /// One seeded workspace; [featureFlags] seeds its feature overrides
  /// (#146) — absent keys keep their registry default (ON).
  FakeWorkspaceRepository.withWorkspace({
    Map<String, dynamic> featureFlags = const {},
  }) : workspaces = [
          Workspace(
            id: 'ws-1',
            name: 'Test Space',
            countryCode: 'DE',
            currencyCode: 'EUR',
            timezone: 'Europe/Berlin',
            inviteCode: 'GOODCODE22',
            featureFlags: featureFlags,
            // #917 — the shared fixture is a PRODUCTION workspace, so the
            // development strip does not steal a row from every layout
            // assertion in the suite. The strip has its own tests
            // (environment_banner_test.dart), which pump the whole app on
            // a development one and walk a pushed route under it; a test
            // that is about the environment says so by setting it.
            environment: 'prod',
          ),
        ];

  final List<Workspace> workspaces;

  /// Workspace-wide dev mode (#419): mirrors the 0081 column + RPC.
  /// Admin-gated like the server; [applyDevMode] seeds the initial state.
  void applyDevMode(bool enabled) {
    for (var i = 0; i < workspaces.length; i++) {
      workspaces[i] = workspaces[i].copyWith(devMode: enabled);
    }
  }

  @override
  Future<void> setDevMode(String workspaceId, bool enabled) async {
    if (!myMember.canAdminister) {
      throw const PostgrestException(
          message: 'not an admin of this workspace');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(devMode: enabled);
  }

  /// Membership returned by [fetchMyMember]; owner of ws-1 by default.
  Member myMember = const Member(
    id: 'member-1',
    workspaceId: 'ws-1',
    userId: 'user-1',
    isAdmin: true,
    isOwner: true,
    status: MemberStatus.active,
  );

  /// Personal invitations minted through [createInvitation] (0051), in
  /// mint order — tests read the codes and roles back from here.
  final List<
      ({
        String code,
        bool isAdmin,
        String firstName,
        String lastName,
        String? memberId,
        // #1119 — whether the invitation also grants the prod twin.
        bool alsoProd
      })> mintedInvitations = [];

  var _nextInviteCode = 1;

  /// Mirrors the server rules (0051): admins mint member invites, only
  /// owners mint admin invites.
  @override
  Future<String> createInvitation(
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

  var _nextId = 1;

  /// #1650 — when set, [fetchMyWorkspaces] throws it: a server that could
  /// not answer, as opposed to one that answered "none".
  Object? fetchFailure;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    if (fetchFailure case final failure?) throw failure;
    return List.of(workspaces);
  }

  /// #937 — the platform-owner view as the fake holds it.
  bool platformOwner = false;
  final allWorkspaces = <WorkspaceOverview>[];
  final ownersByWorkspace = <String, List<WorkspaceOwner>>{};
  final ownerReads = <String>[];

  /// #945 — the sites as the fake holds them.
  final sites = <Site>[];
  final siteWrites = <String>[];
  final homeSites = <String, String?>{};

  @override
  Future<List<Site>> fetchSites(String workspaceId) async => [
        ...sites.where((s) => s.workspaceId == workspaceId && s.isDefault),
        ...sites.where((s) => s.workspaceId == workspaceId && !s.isDefault),
      ];

  @override
  Future<String> upsertSite(String workspaceId, Site site, {bool isNew = false}) async {
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

  @override
  Future<void> deleteSite(String siteId) async {
    sites.removeWhere((s) => s.id == siteId && !s.isDefault);
    siteWrites.add('delete:$siteId');
  }

  @override
  Future<void> setMemberHomeSite(String memberId, String? siteId) async {
    homeSites[memberId] = siteId;
  }

  @override
  Future<bool> isPlatformOwner() async => platformOwner;

  @override
  Future<List<WorkspaceOverview>> fetchAllWorkspaces() async {
    if (!platformOwner) throw StateError('platform owners only');
    return List.of(allWorkspaces);
  }

  @override
  Future<List<WorkspaceOwner>> fetchWorkspaceOwners(String workspaceId) async {
    if (!platformOwner) throw StateError('platform owners only');
    ownerReads.add(workspaceId);
    return List.of(ownersByWorkspace[workspaceId] ?? const []);
  }

  @override
  Future<String> createWorkspace({
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

  /// #1303 — every creation asked for, and the request ids it answered.
  final createRequests = <({String? requestId, String? templateId, bool withTwin})>[];
  final createdByRequest = <String, String>{};

  /// #1303 — the next creation throws this once (a lost response, say).
  Object? createFailure;

  /// #917 — the last environment written, for assertions.
  String? lastEnvironment;

  /// #987 — the twin the fake created last, and how many.
  final List<String> twinsCreated = [];

  @override
  Future<String> createWorkspaceTwin(String workspaceId) async {
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

  @override
  Future<void> setWorkspaceEnvironment(
      String workspaceId, WorkspaceEnvironment environment) async {
    lastEnvironment = environment.wire;
    final index = workspaces.indexWhere((w) => w.id == workspaceId);
    if (index >= 0) {
      workspaces[index] =
          workspaces[index].copyWith(environment: environment.wire);
    }
  }

  /// (0052) member id → last join decision, for assertions.
  final joinDecisions = <String, bool>{};

  @override
  Future<void> decideMemberJoin(
    String memberId, {
    required bool approve,
  }) async {
    joinDecisions[memberId] = approve;
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

  /// (0052) Whether the fake's joins land pending (the server default).
  /// Tests that predate the validation flow keep instant-active joins.
  bool joinsArePending = false;

  /// (0051) codes already redeemed — a second use is refused like the
  /// server's atomic latch.
  final redeemedInvitations = <String>{};

  @override
  Future<String> joinWorkspace(String inviteCode) async {
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

  /// (#153) Arguments of the last [updateWorkspaceLocale] call, for
  /// assertions: `[workspaceId, countryCode, currencyCode, timezone]`.
  List<String>? lastLocaleUpdate;

  @override
  Future<void> updateWorkspaceLocale(
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

  /// (#155) The last saved instructions, for assertions.
  PaymentInstructions? lastPaymentInstructions;

  @override
  Future<void> setPaymentInstructions(
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

  /// (#231) The last saved WhatsApp group link, for assertions.
  String? lastWhatsappGroup;

  @override
  Future<void> setWhatsappGroup(String workspaceId, String link) async {
    lastWhatsappGroup = link;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(whatsappGroup: link);
    }
  }

  /// (0049) The last saved invitation template, for assertions.
  String? lastInvitationTemplate;

  @override
  Future<void> setInvitationTemplate(String workspaceId, String template) async {
    lastInvitationTemplate = template;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(invitationTemplate: template);
    }
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async =>
      [myMember, ...extraMyMemberships]
          .where((m) => m.workspaceId == workspaceId)
          .firstOrNull ??
      myMember.copyWith(workspaceId: workspaceId);

  /// memberId → display name; seeded with the default member.
  Map<String, String> memberNames = {'member-1': 'Flo'};

  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async => {
        ...memberNames,
        // #887 — a managed member is named from its identity, as the
        // server does.
        for (final m in otherMembers)
          if (m.isManaged) m.id: m.managedIdentity.fullName,
      };

  /// memberId → email; served only to admin/owner callers, mirroring
  /// the member_emails RPC gate (0078, #410).
  Map<String, String> memberEmails = {};

  @override
  Future<Map<String, String>> fetchMemberEmails(String workspaceId) async =>
      (myMember.isAdmin || myMember.isOwner) &&
              myMember.status == MemberStatus.active
          ? Map.of(memberEmails)
          : const {};

  /// Extra members beyond [myMember] for the management screen.
  final List<Member> otherMembers = [];

  /// #887 — managed members created through the fake, and the
  /// handovers revoked, for assertions.
  final List<String> revokedHandovers = [];
  var _nextManagedId = 1;

  @override
  Future<String> createManagedMember(
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

  /// #915 — the identities behind the rule, as the gated table holds them.
  final managedIdentities = <String, PersonalInfo>{};

  /// #914 — the last rule written, for assertions.
  ManagedAccess? lastManagedAccess;

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) async =>
      managedIdentities[memberId] ?? PersonalInfo.empty;

  @override
  Future<void> setManagedAccess(String memberId, ManagedAccess access) async {
    lastManagedAccess = access;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] =
          otherMembers[i].copyWith(managedAccess: access.toJson());
    }
  }

  @override
  Future<void> updateManagedIdentity(
      String memberId, PersonalInfo identity) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i < 0) throw StateError('member not found');
    otherMembers[i] =
        otherMembers[i].copyWith(managedIdentity: identity.normalized());
  }

  @override
  Future<void> revokeHandover(String memberId) async {
    revokedHandovers.add(memberId);
    mintedInvitations.removeWhere((i) => i.memberId == memberId);
  }

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async =>
      [myMember, ...otherMembers];

  /// My memberships across workspaces (profiles, #89); defaults to just
  /// [myMember]. Tests add more for multi-profile scenarios.
  final List<Member> extraMyMemberships = [];

  @override
  Future<List<Member>> fetchMyMembers() async =>
      [myMember, ...extraMyMemberships];

  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async {
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

  @override
  Future<void> updateMemberOveragePolicy(
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

  @override
  Future<void> setMemberReservationLimit(String memberId, int? limit) async {
    if (myMember.id == memberId) {
      throw StateError('cannot set your own reservation limit');
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] =
          otherMembers[i].copyWith(maxActiveReservations: limit);
    }
  }

  @override
  Future<void> setMemberVatTreatment(
      String memberId, String treatment, String reason) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i]
          .copyWith(vatTreatment: treatment, vatExemptionReason: reason);
    }
  }

  @override
  Future<void> setMemberSimultaneousLimit(String memberId, int? limit) async {
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

  /// (0050) member id → last level-permission written, for assertions.
  final levelPermissions = <String, bool>{};

  @override
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  }) async {
    levelPermissions[memberId] = allowed;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      otherMembers[i] = otherMembers[i].copyWith(canReserveLevel: allowed);
    }
  }

  @override
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(isKiosk: isKiosk);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(isKiosk: isKiosk);
    }
  }

  /// Issued badges; tokens are deterministic 'badge-token-N'.
  final badges = <MemberBadge>[];

  @override
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) async =>
      List.of(badges);

  @override
  Future<IssuedBadge> issueMemberBadge(
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

  @override
  Future<void> registerNfcBadge(
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

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    final i = badges.indexWhere((b) => b.id == badgeId);
    if (i >= 0) {
      badges[i] = badges[i].copyWith(revokedAt: kTestNow);
    }
  }

  /// (0053) Self-service paths — the fake reuses the admin bodies with
  /// the caller's own member id.
  @override
  Future<IssuedBadge> issueMyBadge(
    String workspaceId, {
    String label = '',
  }) =>
      issueMemberBadge(workspaceId, myMember.id, label: label);

  @override
  Future<void> registerMyNfcBadge(
    String workspaceId, {
    required String uid,
    String label = '',
  }) =>
      registerNfcBadge(workspaceId, myMember.id, uid: uid, label: label);

  @override
  Future<void> revokeMyBadge(String badgeId) => revokeMemberBadge(badgeId);

  @override
  Future<void> deleteRevokedBadge(String badgeId) async {
    final before = badges.length;
    badges.removeWhere((b) => b.id == badgeId && !b.isActive);
    // Server contract (0055): live or unknown badges refuse.
    if (badges.length == before) {
      throw const PostgrestException(message: 'unknown badge');
    }
  }

  @override
  Future<void> setWorkspaceAddress(String workspaceId, String address) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(address: address.trim());
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

  @override
  Future<void> setSubscriptionVatRate(
    String workspaceId,
    String vatRateId,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] =
        workspaces[i].copyWith(subscriptionVatRateId: vatRateId);
  }

  /// #500 — the in-memory document library.
  final List<WorkspaceDocument> documents = [];

  @override
  Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) async {
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

  @override
  Future<void> addDocument(WorkspaceDocument document) async {
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

  @override
  Future<void> deleteDocument(String documentId) async {
    documents.removeWhere((d) => d.id == documentId);
  }

  @override
  Future<void> setWorkspaceLanguage(String workspaceId, String locale) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(defaultLocale: locale.trim());
  }

  @override
  Future<void> setRolePermissions(
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
  @override
  Future<void> setRolePermission(
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
    ];
    current.remove(permission);
    if (enabled) current.add(permission);
    current.sort();
    workspaces[i] = workspaces[i].copyWith(rolePermissions: {
      ...workspaces[i].rolePermissions,
      role: current,
    });
  }

  @override
  Future<void> setInvitationTemplates(
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

  @override
  Future<void> setCoOwner(String memberId, CoOwnerStatus status) async {
    // Server contract (0058): active co-owners also become admins.
    Member patch(Member m) => m.copyWith(
        coOwner: status,
        isAdmin: status == CoOwnerStatus.active ? true : m.isAdmin);
    if (myMember.id == memberId) {
      myMember = patch(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = patch(otherMembers[i]);
  }

  @override
  Future<void> activateCoOwner(String memberId) async {
    Member promote(Member m) =>
        m.copyWith(isOwner: true, isAdmin: true, coOwner: CoOwnerStatus.none);
    if (myMember.id == memberId) {
      myMember = promote(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = promote(otherMembers[i]);
  }

  @override
  Future<void> unsetMyKiosk(String workspaceId) async {
    // Server contract (0056): only an actual kiosk membership reverts.
    if (!myMember.isKiosk || myMember.workspaceId != workspaceId) {
      throw const PostgrestException(
        message: 'not a kiosk of this workspace',
      );
    }
    myMember = myMember.copyWith(isKiosk: false);
  }

  /// (workspaceId, memberId, makeAdmin) of the last role-change request.
  (String, String, bool)? lastRoleChange;

  @override
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    lastRoleChange = (workspaceId, memberId, makeAdmin);
  }

  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalized)) {
      throw StateError('workspace ID must be 4-20 letters or digits');
    }
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(inviteCode: normalized);
    return normalized;
  }

  @override
  Future<void> setFeatureFlags(
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

  /// #1329 — the read-set of every write (null for an unconditional one),
  /// and a switch to answer the next write with a conflict.
  final flagExpectations = <Map<String, bool>?>[];
  bool flagConflictNext = false;

  /// Every flag map handed to [setFeatureFlags], in order (#963 pins
  /// that a toggle writes only what it changes).
  final List<Map<String, bool>> flagWrites = [];

  /// ISO open weekdays (1=Mon..7=Sun) per workspace; Mon–Fri when unseeded.
  final Map<String, List<int>> openWeekdays = {};

  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async =>
      List.of(openWeekdays[workspaceId] ?? const [1, 2, 3, 4, 5]);

  @override
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) async {
    openWeekdays[workspaceId] = List.of(weekdays);
  }

  /// Booking granularity per workspace (#200); flexible when unseeded —
  /// stored beside [openWeekdays] like the separate booking_rules keys.
  final Map<String, BookingGranularity> bookingGranularities = {};

  @override
  Future<BookingGranularity> fetchBookingGranularity(
    String workspaceId,
  ) async =>
      bookingGranularities[workspaceId] ?? BookingGranularity.flexible;

  @override
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  ) async {
    bookingGranularities[workspaceId] = granularity;
  }

  /// The #600 policy switches per workspace; all OFF when unseeded.
  final Map<String, BookingPolicies> bookingPolicies = {};

  /// #1294 — what each workspace says a new member starts with.
  final Map<String, NewMemberDefaults> newMemberDefaults = {};

  /// #1294 — the workspace's fallback default period, by workspace.
  final Map<String, String?> workspaceDefaultPeriods = {};

  @override
  Future<String?> fetchDefaultPeriod(String workspaceId) async =>
      workspaceDefaultPeriods[workspaceId];

  @override
  Future<void> setDefaultPeriod(String workspaceId, String? wire) async {
    workspaceDefaultPeriods[workspaceId] = (wire ?? '').isEmpty ? null : wire;
  }

  @override
  Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) async =>
      newMemberDefaults[workspaceId] ?? const NewMemberDefaults();

  @override
  Future<void> setNewMemberDefaults(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    newMemberDefaults[workspaceId] = defaults;
  }

  /// #1277 — workspaceId -> locale -> key -> the workspace's word.
  /// #1289 — branding as the server would store it, by workspace id.
  final Map<String, Map<String, dynamic>> brandings = {};

  /// #1289 — the emblem's bytes by workspace id; absent is a space with
  /// no emblem, which is almost all of them.
  final Map<String, Uint8List> emblems = {};

  @override
  Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) async {
    emblems[workspaceId] = png;
  }

  @override
  Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) async =>
      emblems[workspaceId];

  @override
  Future<void> clearWorkspaceEmblem(String workspaceId) async {
    emblems.remove(workspaceId);
  }

  @override
  Future<Map<String, dynamic>> setWorkspaceBranding(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    // The server merges into the row, so the fake starts from what the
    // workspace carries — not from an empty map, which would make a
    // reset of one key look like a reset of all of them.
    final stored = workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final current = Map<String, dynamic>.from(
        brandings[workspaceId] ?? stored?.branding ?? const {});
    for (final e in delta.entries) {
      if (e.value == null) {
        current.remove(e.key);
      } else {
        current[e.key] = e.value;
      }
    }
    brandings[workspaceId] = current;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(branding: current);
    return current;
  }

  final Map<String, Map<String, Map<String, String>>> lexicons = {};

  @override
  Future<Map<String, dynamic>> fetchLexicon(String workspaceId) async =>
      {for (final e in (lexicons[workspaceId] ?? {}).entries) e.key: e.value};

  @override
  Future<void> setLexiconTerm(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    final byLocale = lexicons.putIfAbsent(workspaceId, () => {});
    final terms = byLocale.putIfAbsent(locale, () => {});
    if (text == null) {
      terms.remove(key);
    } else {
      terms[key] = text;
    }
  }

  @override
  Future<BookingPolicies> fetchBookingPolicies(String workspaceId) async =>
      bookingPolicies[workspaceId] ?? const BookingPolicies();

  @override
  Future<void> setBookingPolicy(
    String workspaceId,
    String key, {
    required bool enabled,
  }) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.allowPastBookingsKey =>
        p.copyWith(allowPastBookings: enabled),
      // #634: grid_within_hours is read-only legacy — no writer.
      BookingPolicies.adminCheckOutKey => p.copyWith(adminCheckOut: enabled),
      _ => p,
    };
  }

  @override
  Future<void> setSimultaneousReservations(
    String workspaceId,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] =
        p.copyWith(simultaneousReservations: value);
  }

  @override
  Future<void> setBookingLimit(
    String workspaceId,
    String key,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.advanceHorizonDaysKey =>
        p.copyWith(advanceHorizonDays: value),
      BookingPolicies.minDurationMinutesKey =>
        p.copyWith(minDurationMinutes: value),
      BookingPolicies.maxDurationMinutesKey =>
        p.copyWith(maxDurationMinutes: value),
      _ => p,
    };
  }

  @override
  Future<void> setLegendProfile(
    String workspaceId,
    LegendProfile profile,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(legendProfile: profile);
  }

  @override
  Future<void> setOutsideHoursMode(
    String workspaceId,
    OutsideHoursMode mode,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(outsideHoursMode: mode);
  }

  /// Working day per workspace (#446); defaults like the real repo.
  final Map<String, WorkHours> workHours = {};

  /// Sent member notes (#456), newest last; myNotes returns them
  /// newest-first like the real query.
  final List<MemberNote> memberNotes = [];

  // ── conversations (#687) ────────────────────────────────────────────

  /// Threads the fake knows about, in no particular order — the fake
  /// SORTS on read, exactly as `my_conversations` does, so a test that
  /// depends on ordering exercises the ordering rather than the seed
  /// order.
  final List<Conversation> conversations = [];

  /// Messages per conversation id, oldest first.
  final Map<String, List<MemberNote>> conversationMessages = {};
  final Map<String, List<ConversationParticipant>> participants = {};

  final List<({String conversationId, String body})> sentMessages = [];
  final List<String> readConversations = [];
  final List<({String conversationId, String memberId})> addedParticipants = [];
  final List<({String conversationId, String memberId})> removedParticipants =
      [];
  final List<String> leftConversations = [];
  final List<({String id, String? title, String? avatarPath})> metaWrites = [];

  /// The id [createGroupConversation] hands back; tests that navigate on
  /// it need to know it in advance.
  String nextGroupId = 'conv-group';

  /// #821 — prefs writes and unread marks, in order.
  final List<({String id, bool? pinned, bool? muted, bool? archived})>
      prefsWrites = [];
  final List<String> unreadMarks = [];

  @override
  Future<List<Conversation>> fetchConversations(
    String workspaceId, {
    bool includeArchived = false,
  }) async =>
      [
        for (final c in conversations)
          if (includeArchived || !c.isArchived) c,
      ]..sort((a, b) {
          // Pinned first, then newest — my_conversations v3 (0146).
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.lastAt.compareTo(a.lastAt);
        });

  @override
  Future<void> setConversationPrefs(
    String conversationId, {
    bool? pinned,
    bool? muted,
    bool? archived,
  }) async {
    prefsWrites.add(
        (id: conversationId, pinned: pinned, muted: muted, archived: archived));
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    final c = conversations[i];
    conversations[i] = Conversation(
      id: c.id,
      kind: c.kind,
      lastAt: c.lastAt,
      title: c.title,
      avatarPath: c.avatarPath,
      otherMemberId: c.otherMemberId,
      lastBody: c.lastBody,
      lastFromMemberId: c.lastFromMemberId,
      unread: c.unread,
      participantCount: c.participantCount,
      pinnedAt: pinned == null
          ? c.pinnedAt
          : (pinned ? (c.pinnedAt ?? DateTime.utc(2026, 9, 2)) : null),
      muted: muted ?? c.muted,
      archivedAt: archived == null
          ? c.archivedAt
          : (archived ? (c.archivedAt ?? DateTime.utc(2026, 9, 2)) : null),
    );
  }

  @override
  Future<void> markConversationUnread(String conversationId) async {
    unreadMarks.add(conversationId);
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    final c = conversations[i];
    conversations[i] = Conversation(
      id: c.id,
      kind: c.kind,
      lastAt: c.lastAt,
      title: c.title,
      avatarPath: c.avatarPath,
      otherMemberId: c.otherMemberId,
      lastBody: c.lastBody,
      lastFromMemberId: c.lastFromMemberId,
      unread: c.unread == 0 ? 1 : c.unread,
      participantCount: c.participantCount,
      pinnedAt: c.pinnedAt,
      muted: c.muted,
      archivedAt: c.archivedAt,
    );
  }

  @override
  Future<String> openDirectConversation(
    String workspaceId, {
    required String otherMemberId,
  }) async {
    // Idempotent like the RPC: the same pair must not yield two threads.
    final existing = conversations
        .where((c) => !c.isGroup && c.otherMemberId == otherMemberId)
        .firstOrNull;
    if (existing != null) return existing.id;
    final created = Conversation(
      id: 'conv-direct-$otherMemberId',
      kind: ConversationKind.direct,
      otherMemberId: otherMemberId,
      lastAt: DateTime.utc(2026, 8, 27),
    );
    conversations.add(created);
    // #702 / migration 0130 — the thread INHERITS the pair's existing
    // notes. On the server those notes were written before conversations
    // existed and the backfill stamps them into this one; a fake that
    // hands back an empty thread instead would let the app lose every
    // message older than 0125 without a single test noticing.
    conversationMessages.putIfAbsent(
      created.id,
      () => memberNotes
          .where((n) =>
              !n.isBroadcast &&
              (n.fromMemberId == otherMemberId ||
                  n.toMemberId == otherMemberId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    );
    return created.id;
  }

  @override
  Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  }) async {
    conversations.add(Conversation(
      id: nextGroupId,
      kind: ConversationKind.group,
      title: title,
      lastAt: DateTime.utc(2026, 8, 27),
      participantCount: memberIds.length + 1,
    ));
    participants[nextGroupId] = [
      const ConversationParticipant(memberId: 'member-1', isAdmin: true),
      for (final id in memberIds)
        ConversationParticipant(memberId: id, isAdmin: false),
    ];
    return nextGroupId;
  }

  @override
  Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  ) async =>
      participants[conversationId] ?? const [];

  @override
  Future<void> addParticipant(String conversationId, String memberId) async {
    addedParticipants.add((conversationId: conversationId, memberId: memberId));
    participants.putIfAbsent(conversationId, () => []).add(
          ConversationParticipant(memberId: memberId, isAdmin: false),
        );
  }

  @override
  Future<void> removeParticipant(
    String conversationId,
    String memberId,
  ) async {
    removedParticipants
        .add((conversationId: conversationId, memberId: memberId));
    participants[conversationId] = [
      for (final p in participants[conversationId] ??
          const <ConversationParticipant>[])
        if (p.memberId == memberId)
          ConversationParticipant(
            memberId: p.memberId,
            isAdmin: p.isAdmin,
            leftAt: DateTime.utc(2026, 8, 27),
          )
        else
          p,
    ];
  }

  @override
  Future<void> leaveConversation(String conversationId) async =>
      leftConversations.add(conversationId);

  @override
  Future<void> setConversationMeta(
    String conversationId, {
    String? title,
    String? avatarPath,
  }) async =>
      metaWrites
          .add((id: conversationId, title: title, avatarPath: avatarPath));

  @override
  Future<void> sendConversationMessage(
    String conversationId,
    String body,
  ) async {
    sentMessages.add((conversationId: conversationId, body: body));
    // #702 — a conversation message IS a member note, as it is on the
    // server: `send_conversation_message` inserts into `member_notes`
    // with the conversation stamped on it. The fake used to write only
    // into its own thread map, so a caller that checked what was SENT
    // saw nothing — and the direct thread's recipient was lost, which
    // is the one field a 1:1 message is about.
    final direct = conversations
        .where((c) => c.id == conversationId && !c.isGroup)
        .firstOrNull;
    final note = MemberNote(
      id: 'msg-${sentMessages.length}',
      workspaceId: 'workspace-1',
      fromMemberId: 'member-1',
      toMemberId: direct?.otherMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 27, 12, sentMessages.length),
    );
    memberNotes.add(note);
    conversationMessages.putIfAbsent(conversationId, () => []).add(note);
  }

  @override
  Future<List<MemberNote>> fetchConversationMessages(
    String conversationId, {
    int limit = 200,
    DateTime? before,
  }) async {
    final all = conversationMessages[conversationId] ?? const <MemberNote>[];
    final older = before == null
        ? all
        : [for (final n in all) if (n.createdAt.isBefore(before)) n];
    // The newest [limit], oldest first — like the paged query.
    return older.length <= limit
        ? List.of(older)
        : older.sublist(older.length - limit);
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    readConversations.add(conversationId);
    // Mirrors mark_conversation_read (0126): messages addressed TO me
    // get their receipt, and only once — re-opening must not move a
    // stamp that already exists, or the sender watches the read time
    // drift every time the reader glances at the thread.
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == 'member-1' && n.readAt == null) {
        memberNotes[i] = MemberNote(
          id: n.id,
          workspaceId: n.workspaceId,
          fromMemberId: n.fromMemberId,
          toMemberId: n.toMemberId,
          body: n.body,
          createdAt: n.createdAt,
          readAt: DateTime.utc(2026, 5, 12, 10),
          conversationId: n.conversationId,
        );
      }
    }
  }

  @override
  Future<List<MemberNote>> searchMessages(
    String workspaceId,
    String query,
  ) async {
    // Blank is nothing, not everything — the same call the real one
    // makes, and the one a test for "empty box shows nothing" needs.
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    return [
      for (final list in conversationMessages.values)
        for (final note in list)
          if (note.body.toLowerCase().contains(trimmed)) note,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> sendMemberNote(
    String workspaceId, {
    required String? toMemberId,
    required String body,
  }) async {
    memberNotes.add(MemberNote(
      id: 'note-${memberNotes.length + 1}',
      workspaceId: workspaceId,
      fromMemberId: 'member-1',
      toMemberId: toMemberId,
      body: body,
      createdAt: DateTime.utc(2026, 8, 4, 12, memberNotes.length),
    ));
  }

  @override
  Future<List<MemberNote>> fetchMyNotes(String workspaceId) async =>
      memberNotes.reversed.toList();

  /// Ids passed to [deleteMemberNote], in order (#798).
  final List<String> deletedNotes = [];

  @override
  Future<void> deleteMemberNote(String noteId) async {
    deletedNotes.add(noteId);
    memberNotes.removeWhere((n) => n.id == noteId);
    // A deleted note leaves its THREAD too — the server deletes the row,
    // and a fake that kept it there would let the thread show a message
    // the database no longer has.
    for (final thread in conversationMessages.values) {
      thread.removeWhere((n) => n.id == noteId);
    }
  }

  /// Whether the WhatsApp mirror channel is configured (0106 probe) —
  /// defaults true so the settings switch shows no warning in tests
  /// that don't care.
  /// Read receipts (0105): notes addressed to me ('member-1', the
  /// fake's signed-in member) get their read stamp.
  @override
  Future<void> markMyNotesRead(String workspaceId,
      {String? fromMemberId}) async {
    for (var i = 0; i < memberNotes.length; i++) {
      final n = memberNotes[i];
      if (n.toMemberId == 'member-1' &&
          n.readAt == null &&
          (fromMemberId == null || n.fromMemberId == fromMemberId)) {
        memberNotes[i] = MemberNote(
          id: n.id,
          workspaceId: n.workspaceId,
          fromMemberId: n.fromMemberId,
          toMemberId: n.toMemberId,
          body: n.body,
          createdAt: n.createdAt,
          readAt: DateTime.utc(2026, 8, 9, 12),
        );
      }
    }
  }

  /// Server-side default workspace (#458).
  String? serverDefaultWorkspaceId;

  @override
  Future<String?> fetchDefaultWorkspaceId() async =>
      serverDefaultWorkspaceId;

  @override
  Future<void> setDefaultWorkspaceId(String? workspaceId) async {
    serverDefaultWorkspaceId = workspaceId;
  }

  @override
  Future<WorkHours> fetchWorkHours(String workspaceId) async =>
      workHours[workspaceId] ?? WorkHours.defaults;

  @override
  Future<void> setWorkHours(String workspaceId, WorkHours hours) async {
    workHours[workspaceId] = hours;
  }

  /// #1307 S4 — provenance per workspace; unset reads as the product default.
  final workHoursProvenance = <String, WorkHoursProvenance>{};
  final workHoursResets = <String>[];

  @override
  Future<WorkHoursProvenance> fetchWorkHoursProvenance(String workspaceId) async =>
      workHoursProvenance[workspaceId] ?? WorkHoursProvenance.productDefault;

  @override
  Future<void> resetWorkHoursToDefault(String workspaceId) async {
    workHoursResets.add(workspaceId);
    workHours.remove(workspaceId);
    workHoursProvenance[workspaceId] = WorkHoursProvenance.productDefault;
  }

  /// One-off closure days across workspaces (#127).
  final List<ClosureDay> closureDays = [];

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async =>
      closureDays.where((c) => c.workspaceId == workspaceId).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

  /// #1274 — what `generate_closure_days` hands back. Tests seed this;
  /// the fake never recomputes the calendar.
  HolidayGeneration holidayGeneration = HolidayGeneration.empty;

  /// Every generate call, in order, so a test can prove a preview did
  /// not write and an apply did.
  final holidayCalls =
      <({String country, int year, bool apply})>[];

  @override
  Future<HolidayGeneration> generateClosureDays(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  }) async {
    holidayCalls.add((country: country, year: year, apply: apply));
    if (!apply) {
      return HolidayGeneration(
        days: holidayGeneration.days,
        lockedMonths: holidayGeneration.lockedMonths,
        created: 0,
      );
    }
    var created = 0;
    for (final d in holidayGeneration.creatable) {
      closureDays.add(ClosureDay(
        id: 'closure-${_nextId++}',
        workspaceId: workspaceId,
        day: d.day,
        reason: d.key,
      ));
      created++;
    }
    return HolidayGeneration(
      days: holidayGeneration.days,
      lockedMonths: holidayGeneration.lockedMonths,
      created: created,
    );
  }

  @override
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final closure = ClosureDay(
      id: 'closure-${_nextId++}',
      workspaceId: workspaceId,
      day: DateTime(day.year, day.month, day.day),
      reason: reason,
    );
    closureDays.add(closure);
    return closure;
  }

  @override
  Future<void> removeClosureDay(String closureDayId) async {
    closureDays.removeWhere((c) => c.id == closureDayId);
  }

  /// Workspace ids passed to [resetWorkspace], for assertions.
  final resetWorkspaceCalls = <String>[];

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    resetWorkspaceCalls.add(workspaceId);
  }

  /// Last opacity passed to [setDeskOpacity]; also updates the seeded row.
  int? lastDeskOpacity;

  /// #1451 — every Save sent as one command, and a conflict to raise next.
  final settingsSaves = <WorkspaceSettingsSave>[];
  bool settingsConflictNext = false;
  Object? settingsFailure;

  @override
  Future<Workspace> saveWorkspaceSettings(
      String workspaceId, WorkspaceSettingsSave save) async {
    settingsSaves.add(save);
    if (settingsConflictNext) {
      settingsConflictNext = false;
      throw const WorkspaceSettingsConflict();
    }
    if (settingsFailure case final failure?) throw failure;
    // One transaction on the server; here the setters the older tests pin.
    await updateWorkspaceLocale(workspaceId,
        countryCode: save.countryCode,
        currencyCode: save.currencyCode,
        timezone: save.timezone);
    await setWhatsappGroup(workspaceId, save.whatsappGroup.trim());
    await setWorkspaceAddress(workspaceId, save.address.trim());
    await setInvitationTemplates(workspaceId, save.invitationTemplates);
    await setInvitationTemplate(workspaceId, '');
    await setWorkspaceLanguage(workspaceId, save.defaultLocale);
    await setDeskOpacity(workspaceId, save.deskOpacity);
    if (save.newMemberDefaults case final d?) await setNewMemberDefaults(workspaceId, d); // #1563 — absent means "never loaded": the server leaves the key alone
    return workspaces.firstWhere((w) => w.id == workspaceId);
  }

  @override
  Future<void> setDeskOpacity(String workspaceId, int opacity) async {
    lastDeskOpacity = opacity;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(deskOpacity: opacity);
  }

  @override
  Future<void> updateMemberStatus(
    String memberId,
    MemberStatus status,
  ) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(status: status);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = otherMembers[i].copyWith(status: status);
  }

  // ── #1120 — the workspace library, as the fake holds it ─────────
  final templates = <WorkspaceTemplate>[
    const WorkspaceTemplate(
      id: 'tpl-tiny',
      key: 'tiny',
      name: 'A tiny space',
      description: 'Two levels, four desks, eight seats.',
      visibility: TemplateVisibility.builtin,
      floorPlan: <Object?>[
        <String, Object?>{'name': 'Ground', 'offices': <Object?>[<String, Object?>{'name': 'Room 1', 'desks': <Object?>[<String, Object?>{'name': 'Desk 1', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}, <String, Object?>{'name': 'Desk 2', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}]}]},
        <String, Object?>{'name': 'First', 'offices': <Object?>[<String, Object?>{'name': 'Room 2', 'desks': <Object?>[<String, Object?>{'name': 'Desk 3', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}, <String, Object?>{'name': 'Desk 4', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}]}]},
      ],
    ),
  ];
  final templateGrants = <String, List<String>>{};
  final appliedTemplates =
      <({String workspaceId, String templateId, List<String>? groups})>[];

  @override
  Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates() async =>
      List.of(templates);

  @override
  Future<void> applyWorkspaceTemplate(String workspaceId, String templateId,
      {List<String>? groups}) async {
    if (!templates.any((t) => t.id == templateId)) {
      throw Exception('unknown template');
    }
    appliedTemplates.add(
        (workspaceId: workspaceId, templateId: templateId, groups: groups));
  }

  /// #1280 S3 — the groups each save asked for (null = everything allowed).
  final savedTemplateGroups = <List<String>?>[];

  /// #1280 S3 — what the fake server says publishing would carry.
  TemplatePublication publication = const TemplatePublication(
    published: [
      PublishedEntity(entity: 'floor_plan', group: TemplateGroup.space),
      PublishedEntity(
          entity: 'identity',
          group: TemplateGroup.wording,
          stripped: ['address', 'vat_id']),
      PublishedEntity(entity: 'booking_rules', group: TemplateGroup.hoursBooking),
    ],
    neverPublished: [
      NeverPublished(entity: 'payment_instructions', reason: 'bank details'),
      NeverPublished(entity: 'sites', reason: 'addresses'),
    ],
    planNames: ['Ground floor', 'Desk 1'],
  );

  @override
  Future<TemplatePublication> templatePublicationPreview(String workspaceId,
      {List<String>? groups}) async {
    if (groups == null) return publication;
    return TemplatePublication(
      published: [
        for (final p in publication.published)
          if (groups.contains(p.group.wire)) p,
      ],
      neverPublished: publication.neverPublished,
      planNames: groups.contains('space') ? publication.planNames : const [],
    );
  }

  /// #1280 — the preview a test wants the server to answer, by template id.
  /// Without one, each entity group the template carries previews as new.
  final templatePreviews = <String, TemplatePreview>{};

  @override
  Future<TemplatePreview> previewWorkspaceTemplate(
      String workspaceId, String templateId, {List<String>? groups}) async {
    final set = templatePreviews[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    return TemplatePreview(
      compatibility: TemplateCompatibility.supported,
      groups: [
        if (t.entities.contains('floor_plan'))
          TemplateGroupPreview(
            group: TemplateGroup.space,
            wire: 'space',
            state: TemplateGroupState.isNew,
            itemCount: t.counts.seats + t.counts.desks + t.counts.levels,
          ),
      ],
    );
  }

  /// #1303 — outlines by template id; unset ids outline their plan.
  final templateOutlines = <String, TemplateOutline>{};

  /// #1655 — inspections by template id; unset ids inspect as a usable
  /// legacy plan whose outline is [workspaceTemplateOutline]'s.
  final templateInspections = <String, TemplateInspection>{};

  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String templateId) async {
    final set = templateInspections[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    // A seeded outline refusal (#1303 tests) refuses here too.
    final outline = await workspaceTemplateOutline(templateId);
    return TemplateInspection(
      templateId: t.id,
      key: t.key,
      name: t.name,
      entities: t.entities,
      status: TemplateInspectionStatus.ok,
      profile: t.carriesConfiguration ? TemplateProfile.partial : TemplateProfile.legacy,
      compatibility: outline.compatibility,
      outline: outline,
    );
  }

  @override
  Future<TemplateOutline> workspaceTemplateOutline(String templateId) async {
    final set = templateOutlines[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    return TemplateOutline(
      compatibility: TemplateCompatibility.supported,
      groups: [
        if (t.entities.contains('floor_plan')) TemplateGroup.space,
      ],
    );
  }

  @override
  Future<String> saveWorkspaceAsTemplate(
    String workspaceId, {
    required String key,
    required String name,
    String description = '',
    TemplateVisibility visibility = TemplateVisibility.private,
    List<String> tags = const [],
    List<String>? groups,
  }) async {
    savedTemplateGroups.add(groups);
    if (visibility == TemplateVisibility.builtin) {
      throw Exception('a workspace cannot publish a builtin template');
    }
    templates.removeWhere((t) => t.ownerWorkspaceId == workspaceId && t.key == key);
    final id = 'tpl-$key';
    templates.add(WorkspaceTemplate(
      id: id, key: key, name: name, description: description,
      visibility: visibility, ownerWorkspaceId: workspaceId, tags: tags,
      floorPlan: const <Object?>[<String, Object?>{'name': 'Snapshot', 'offices': <Object?>[]}],
    ));
    return id;
  }

  @override
  Future<void> setWorkspaceTemplateVisibility(
      String templateId, TemplateVisibility visibility) async {
    final i = templates.indexWhere((t) => t.id == templateId);
    if (i < 0) throw Exception('unknown template');
    final t = templates[i];
    templates[i] = WorkspaceTemplate(
      id: t.id, key: t.key, name: t.name, description: t.description,
      visibility: visibility, ownerWorkspaceId: t.ownerWorkspaceId, floorPlan: t.floorPlan,
    );
  }

  @override
  Future<void> deleteWorkspaceTemplate(String templateId) async {
    templates.removeWhere((t) => t.id == templateId);
    templateGrants.remove(templateId);
  }

  @override
  Future<void> grantWorkspaceTemplate(String templateId, String email) async {
    final list = templateGrants.putIfAbsent(templateId, () => []);
    final e = email.trim().toLowerCase();
    if (!list.contains(e)) list.add(e);
  }

  @override
  Future<void> revokeWorkspaceTemplateGrant(String templateId, String email) async {
    templateGrants[templateId]?.remove(email.trim().toLowerCase());
  }

  @override
  Future<List<String>> workspaceTemplateGrantees(String templateId) async =>
      List.of(templateGrants[templateId] ?? const []);
}
