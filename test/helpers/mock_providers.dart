// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart' show Widget, ColoredBox, Color, Center, Text;

import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/domain/badge_sign_in.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/core/badge/app_badge.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'package:deskilo/core/notifications/notification_providers.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/core/storage/active_workspace_store.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/core/storage/note_seen_store.dart';
import 'package:deskilo/core/storage/notification_filter_store.dart';
import 'package:deskilo/core/time/clock.dart';

import 'fake_realtime_sync.dart';
import 'test_clock.dart';
export 'test_clock.dart' show kTestNow, kTestPeriod;
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/domain/accessory_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/providers/accessory_providers.dart';
import 'package:deskilo/features/plan/providers/default_level_controller.dart';
import 'package:deskilo/features/reservations/providers/default_period_controller.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/profile/domain/profile_repository.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import 'fake_accessory_repository.dart';
import 'fake_event_repository.dart';
import 'fake_floor_plan_repository.dart';
import 'fake_money_repository.dart';
import 'fake_notification_service.dart';
import 'fake_profile_repository.dart';
import 'fake_reservation_repository.dart';
import 'in_memory_default_level_store.dart';

/// In-memory [AuthRepository] for widget/unit tests (fakes over mocks).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId}) : _userId = userId;

  FakeAuthRepository.signedIn() : this(userId: 'user-1');

  String? _userId;
  final _controller = StreamController<String?>.broadcast();

  /// Social sign-in/link calls, for assertions (0051).
  final socialSignIns = <SocialProvider>[];
  final socialLinks = <SocialProvider>[];
  final unlinked = <LinkedIdentity>[];

  /// Identities the fake reports; seeded by tests.
  List<LinkedIdentity> identities = [
    (id: 'ident-email', provider: 'email'),
  ];

  /// When set, social calls throw (models a provider not enabled).
  Object? socialError;

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {
    if (socialError != null) throw socialError!;
    socialSignIns.add(provider);
  }

  @override
  Future<List<LinkedIdentity>> linkedIdentities() async => identities;

  @override
  Future<void> linkSocial(SocialProvider provider) async {
    if (socialError != null) throw socialError!;
    socialLinks.add(provider);
    identities = [
      ...identities,
      (id: 'ident-${provider.wireName}', provider: provider.wireName),
    ];
  }

  @override
  Future<void> unlinkIdentity(LinkedIdentity identity) async {
    unlinked.add(identity);
    identities =
        identities.where((i) => i.id != identity.id).toList();
  }

  // ── badge sign-in (#662) ────────────────────────────────────────────

  /// Badge uid -> who it identifies. A uid absent from the map is an
  /// unknown badge, which the real server refuses.
  final Map<String, BadgeIdentity> badges = {};

  /// The PIN [signInWithBadge] accepts. Any other value is refused.
  String? badgePin;

  /// When set, both badge steps report this instead of consulting the
  /// map — models a lockout or an undeployed function.
  BadgeSignInFailure? badgeFailure;

  /// Every PIN written through [setBadgePin], in order.
  final List<String> setPins = [];
  bool badgePinCleared = false;
  final List<({String badgeId, bool enabled})> badgeAuthToggles = [];

  @override
  Future<BadgeStepResult<BadgeIdentity>> identifyBadge(String uid) async {
    if (badgeFailure != null) return BadgeStepResult.failed(badgeFailure!);
    final who = badges[uid];
    return who == null
        ? const BadgeStepResult.failed(BadgeSignInFailure.refused)
        : BadgeStepResult.ok(who);
  }

  @override
  Future<BadgeStepResult<void>> signInWithBadge({
    required String uid,
    required String pin,
  }) async {
    if (badgeFailure != null) return BadgeStepResult.failed(badgeFailure!);
    if (badges[uid] == null || badgePin == null || pin != badgePin) {
      return const BadgeStepResult.failed(BadgeSignInFailure.refused);
    }
    _setUser(badges[uid]!.userId);
    return const BadgeStepResult.ok(null);
  }

  @override
  Future<bool> hasBadgePin() async => badgePin != null;

  @override
  Future<void> setBadgePin(String pin) async {
    setPins.add(pin);
    badgePin = pin;
  }

  @override
  Future<void> clearBadgePin() async {
    badgePinCleared = true;
    badgePin = null;
  }

  @override
  Future<void> setBadgeAuthEnabled({
    required String badgeId,
    required bool enabled,
  }) async =>
      badgeAuthToggles.add((badgeId: badgeId, enabled: enabled));

  /// Emails for which [signInWithPassword]/[signUp] should throw.
  final Set<String> failingEmails = {};

  @override
  Stream<String?> authStateChanges() async* {
    yield _userId;
    yield* _controller.stream;
  }

  @override
  String? get currentUserId => _userId;

  void _setUser(String? id) {
    _userId = id;
    _controller.add(id);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (failingEmails.contains(email)) {
      throw const AuthException('invalid credentials');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (failingEmails.contains(email)) {
      throw const AuthException('sign up failed');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signOut() async => _setUser(null);

  /// Emails passed to [requestPasswordReset], in call order.
  final resetRequests = <String>[];

  /// (email, code, newPassword) tuples of successful confirmations.
  final confirmedResets = <(String, String, String)>[];

  /// Codes for which [confirmPasswordReset] throws (invalid/expired).
  final Set<String> failingCodes = {};

  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests.add(email);
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (failingCodes.contains(code)) {
      throw const AuthException('otp_expired');
    }
    confirmedResets.add((email, code, newPassword));
    _setUser('user-1');
  }
}

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
  final List<({String code, bool isAdmin, String firstName, String lastName})>
      mintedInvitations = [];

  var _nextInviteCode = 1;

  /// Mirrors the server rules (0051): admins mint member invites, only
  /// owners mint admin invites.
  @override
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
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
    ));
    return code;
  }

  var _nextId = 1;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async => List.of(workspaces);

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    final workspace = Workspace(
      id: 'ws-created-${_nextId++}',
      name: name,
      countryCode: countryCode,
      currencyCode: currencyCode,
      timezone: timezone,
      inviteCode: 'NEWCODE$_nextId',
    );
    workspaces.add(workspace);
    return workspace.id;
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
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async =>
      Map.of(memberNames);

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
    if (pct < 1 || pct > 100) throw StateError('pct out of range');
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
  }) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(
      vatRegime: vatRegime,
      vatId: vatId.trim(),
      legalId: legalId.trim(),
      taxExemptionReason: taxExemptionReason.trim(),
      street: street.trim(),
      city: city.trim(),
      postalCode: postalCode.trim(),
      vatAccount: vatAccount.trim(),
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
  Future<void> setInvoiceLegal(
    String workspaceId,
    Map<String, Object?> legal,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] =
        workspaces[i].copyWith(invoiceLegal: Map<String, dynamic>.from(legal));
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
    Map<String, bool> flags,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) throw StateError('unknown workspace $workspaceId');
    workspaces[i] = workspaces[i]
        .copyWith(featureFlags: Map<String, dynamic>.of(flags));
  }

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

  @override
  Future<List<Conversation>> fetchConversations(String workspaceId) async =>
      [...conversations]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

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
      for (final p in participants[conversationId] ?? const [])
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
    String conversationId,
  ) async =>
      conversationMessages[conversationId] ?? const [];

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

  @override
  Future<void> deleteMemberNote(String noteId) async {
    memberNotes.removeWhere((n) => n.id == noteId);
  }

  /// Whether the WhatsApp mirror channel is configured (0106 probe) —
  /// defaults true so the settings switch shows no warning in tests
  /// that don't care.
  bool whatsappMirrorConfigured = true;

  /// #552 — the owner-saved channel credentials, keyed by workspace.
  final whatsappChannels = <String, Map<String, String>>{};

  @override
  Future<bool> fetchWhatsappMirrorConfigured({String? workspaceId}) async =>
      whatsappMirrorConfigured ||
      (whatsappChannels[workspaceId]?['token']?.isNotEmpty ?? false) &&
          (whatsappChannels[workspaceId]?['phone_id']?.isNotEmpty ?? false);

  @override
  Future<void> setWhatsappChannel(
    String workspaceId, {
    required String token,
    required String phoneId,
  }) async {
    // Merge semantics like set_whatsapp_channel: blank keeps stored.
    final channel = whatsappChannels.putIfAbsent(workspaceId, () => {});
    if (token.trim().isNotEmpty) channel['token'] = token.trim();
    if (phoneId.trim().isNotEmpty) channel['phone_id'] = phoneId.trim();
  }

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

  /// One-off closure days across workspaces (#127).
  final List<ClosureDay> closureDays = [];

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async =>
      closureDays.where((c) => c.workspaceId == workspaceId).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

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
}

/// Baseline overrides for widget tests: a signed-in user who is the owner
/// of one workspace. Always start from these and add feature-specific
/// overrides on top.
/// In-memory [DevModeStore] — the settings toggle without the platform
/// channel. Default OFF, like a fresh install; tests exercising

List<Override> standardTestOverrides({
  Clock? clock,
  bool devMode = false,
  AuthRepository? auth,
  WorkspaceRepository? workspace,
  FloorPlanRepository? floorPlan,
  AccessoryRepository? accessories,
  ReservationRepository? reservations,
  EventRepository? events,
  MoneyRepository? money,
  NotificationService? notifications,
  ActiveWorkspaceStore? activeWorkspace,
  FakeQrScanner? qrScan,
  DefaultWorkspaceStore? defaultWorkspace,
  DefaultLevelStore? defaultLevel,
  DefaultPeriodStore? defaultPeriod,
  ProfileRepository? profile,
  NfcUidReader? nfc,
  FrontCameraStore? frontCamera,
  FileSharer? fileSharer,
  RealtimeSync? realtime,
  FakeAppBadge? badge,
  NoteSeenStore? noteSeen,
  NotificationFilterStore? notificationFilters,
  HelpHintStore? helpHints,
}) {
  return [
    // No-op realtime by default: the real impl touches Supabase.instance,
    // which does not exist under flutter_test (#413).
    realtimeSyncProvider.overrideWithValue(realtime ?? FakeRealtimeSync()),
    appBadgeProvider.overrideWithValue(badge ?? FakeAppBadge()),
    // The clock is defaulted here rather than per-test so a screen that
    // starts reading it does not quietly re-arm the time bomb.
    clockProvider.overrideWithValue(clock ?? FixedClock(kTestNow)),

    authRepositoryProvider
        .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
    workspaceRepositoryProvider.overrideWithValue(() {
      final repo = workspace ?? FakeWorkspaceRepository.withWorkspace();
      if (devMode && repo is FakeWorkspaceRepository) repo.applyDevMode(true);
      return repo;
    }()),
    floorPlanRepositoryProvider
        .overrideWithValue(floorPlan ?? FakeFloorPlanRepository()),
    accessoryRepositoryProvider
        .overrideWithValue(accessories ?? FakeAccessoryRepository()),
    reservationRepositoryProvider
        .overrideWithValue(reservations ?? FakeReservationRepository()),
    eventRepositoryProvider
        .overrideWithValue(events ?? FakeEventRepository()),
    moneyRepositoryProvider
        .overrideWithValue(money ?? FakeMoneyRepository()),
    notificationServiceProvider
        .overrideWithValue(notifications ?? FakeNotificationService()),
    activeWorkspaceStoreProvider
        .overrideWithValue(activeWorkspace ?? InMemoryActiveWorkspaceStore()),
    // Camera scanner seam (K3): widget tests can't run a camera — the
    // fake renders a placeholder and lets tests emit codes on demand.
    qrScanWidgetBuilderProvider
        .overrideWithValue((qrScan ?? FakeQrScanner()).build),
    defaultWorkspaceStoreProvider
        .overrideWithValue(defaultWorkspace ?? InMemoryDefaultWorkspaceStore()),
    defaultLevelStoreProvider
        .overrideWithValue(defaultLevel ?? InMemoryDefaultLevelStore()),
    // #586: the default booking period persists on-device.
    defaultPeriodStoreProvider
        .overrideWithValue(defaultPeriod ?? InMemoryDefaultPeriodStore()),
    // #464: an in-memory read state — the prefs impl would need a
    // SharedPreferences mock in every widget test.
    noteSeenStoreProvider
        .overrideWithValue(noteSeen ?? InMemoryNoteSeenStore()),
    // #581: the bell filter persists on-device — in-memory for tests.
    notificationFilterStoreProvider.overrideWithValue(
        notificationFilters ?? InMemoryNotificationFilterStore()),
    // #606: dismissed help hints persist on-device — in-memory for tests.
    helpHintStoreProvider
        .overrideWithValue(helpHints ?? InMemoryHelpHintStore()),
    profileRepositoryProvider
        .overrideWithValue(profile ?? FakeProfileRepository()),
    nfcUidReaderProvider.overrideWithValue(nfc ?? FakeNfcUidReader()),
    frontCameraStoreProvider
        .overrideWithValue(frontCamera ?? InMemoryFrontCameraStore()),
    // File cache would touch path_provider channels in tests — and boot
    // eviction runs on every app pump.
    cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
    // Share seam (0060): the real one opens a system share sheet.
    fileSharerProvider.overrideWithValue(
      fileSharer ??
          ({required bytes, required fileName, required mimeType, text})
              async {},
    ),
  ];
}

/// In-memory [CacheStore] so widget tests never touch the filesystem.
class InMemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> entries = {};

  @override
  Future<CacheEntry?> get(String key) async => entries[key];

  @override
  Future<void> put(String key, Object? payload,
      {required Duration ttl}) async {
    entries[key] =
        // Real clock on purpose: freshness is measured against the wall
        // clock inside CacheStore, so a pinned storedAt would make every
        // entry read as expired.
        CacheEntry(payload: payload, storedAt: DateTime.now(), ttl: ttl);
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> evictExpired() async {
    final before = entries.length;
    entries.removeWhere((_, e) => e.age > e.ttl * 3);
    return before - entries.length;
  }
}

/// In-memory [FrontCameraStore] so widget tests never touch
/// SharedPreferences; front camera by default, like production.
class InMemoryFrontCameraStore implements FrontCameraStore {
  bool value = true;

  @override
  Future<bool> read() async => value;

  @override
  Future<void> write(bool enabled) async => value = enabled;
}

/// In-memory [ActiveWorkspaceStore] so widget tests never touch
/// SharedPreferences platform channels.
class InMemoryActiveWorkspaceStore implements ActiveWorkspaceStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? workspaceId) async => value = workspaceId;
}

/// Fake RFID/NFC reader: [available] toggles the tap path ([deviceStatus]
/// pins a precise state instead); [startFails] simulates a session that
/// will not start; [tap] drives a card presentation without hardware.
class FakeNfcUidReader extends NfcUidReader {
  FakeNfcUidReader({
    this.available = false,
    this.deviceStatus,
    this.startFails = false,
  });

  final bool available;
  final NfcStatus? deviceStatus;
  final bool startFails;
  ValueChanged<String>? _onUid;

  @override
  Future<NfcStatus> status() async =>
      deviceStatus ??
      (available ? NfcStatus.ready : NfcStatus.unsupported);

  @override
  Future<bool> startRead({required ValueChanged<String> onUid}) async {
    if (startFails) return false;
    _onUid = onUid;
    return true;
  }

  @override
  Future<void> stop() async => _onUid = null;

  /// Simulates a physical card tap with UID [uid] (already normalized).
  void tap(String uid) => _onUid?.call(uid);
}

/// In-memory [DefaultWorkspaceStore] (#322) so widget tests never touch
/// SharedPreferences.
class InMemoryDefaultWorkspaceStore implements DefaultWorkspaceStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? workspaceId) async => value = workspaceId;
}

/// Fake camera QR scanner (K3): [build] renders a keyed placeholder and
/// captures the sheet's onCode callback; [emit] simulates a decoded QR.
class FakeQrScanner {
  ValueChanged<String>? _onCode;

  Widget build({required ValueChanged<String> onCode}) {
    _onCode = onCode;
    return const ColoredBox(
      color: Color(0xFF222222),
      child: Center(child: Text('camera')),
    );
  }

  /// Simulates the camera decoding [code].
  void emit(String code) => _onCode?.call(code);
}

/// App-icon badge fake (#426): records every count written.
class FakeAppBadge implements AppBadge {
  final counts = <int>[];

  @override
  Future<void> update(int count) async => counts.add(count);
}
