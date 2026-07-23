// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'package:deskilo/core/notifications/notification_providers.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/storage/active_workspace_store.dart';
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/domain/accessory_repository.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/providers/accessory_providers.dart';
import 'package:deskilo/features/plan/providers/default_level_controller.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/profile/domain/profile_repository.dart';
import 'package:deskilo/features/profile/providers/profile_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
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
      createdAt: DateTime.now(),
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
      createdAt: DateTime.now(),
      kind: BadgeKind.nfc,
    ));
  }

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    final i = badges.indexWhere((b) => b.id == badgeId);
    if (i >= 0) {
      badges[i] = badges[i].copyWith(revokedAt: DateTime.now());
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
List<Override> standardTestOverrides({
  AuthRepository? auth,
  WorkspaceRepository? workspace,
  FloorPlanRepository? floorPlan,
  AccessoryRepository? accessories,
  ReservationRepository? reservations,
  EventRepository? events,
  MoneyRepository? money,
  NotificationService? notifications,
  ActiveWorkspaceStore? activeWorkspace,
  DefaultWorkspaceStore? defaultWorkspace,
  DefaultLevelStore? defaultLevel,
  ProfileRepository? profile,
  NfcUidReader? nfc,
}) {
  return [
    authRepositoryProvider
        .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
    workspaceRepositoryProvider.overrideWithValue(
      workspace ?? FakeWorkspaceRepository.withWorkspace(),
    ),
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
    defaultWorkspaceStoreProvider
        .overrideWithValue(defaultWorkspace ?? InMemoryDefaultWorkspaceStore()),
    defaultLevelStoreProvider
        .overrideWithValue(defaultLevel ?? InMemoryDefaultLevelStore()),
    profileRepositoryProvider
        .overrideWithValue(profile ?? FakeProfileRepository()),
    nfcUidReaderProvider.overrideWithValue(nfc ?? FakeNfcUidReader()),
  ];
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

/// Fake RFID/NFC reader: [available] toggles the tap path; [tap] drives a
/// card presentation without hardware.
class FakeNfcUidReader extends NfcUidReader {
  FakeNfcUidReader({this.available = false});

  final bool available;
  ValueChanged<String>? _onUid;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> startRead({required ValueChanged<String> onUid}) async {
    _onUid = onUid;
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
