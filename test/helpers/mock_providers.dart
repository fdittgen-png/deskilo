// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

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

  /// Admin invite code (0030); like the owner-only RLS, [adminInviteCode]
  /// only hands it out when [myMember] is an owner.
  String adminCode = 'ADMINCODE33';

  @override
  Future<String?> adminInviteCode(String workspaceId) async =>
      myMember.isOwner ? adminCode : null;

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

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    if (inviteCode != 'GOODCODE22') {
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
  Future<void> revokeMemberBadge(String badgeId) async {
    final i = badges.indexWhere((b) => b.id == badgeId);
    if (i >= 0) {
      badges[i] = badges[i].copyWith(revokedAt: DateTime.now());
    }
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
  DefaultLevelStore? defaultLevel,
  ProfileRepository? profile,
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
    defaultLevelStoreProvider
        .overrideWithValue(defaultLevel ?? InMemoryDefaultLevelStore()),
    profileRepositoryProvider
        .overrideWithValue(profile ?? FakeProfileRepository()),
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
