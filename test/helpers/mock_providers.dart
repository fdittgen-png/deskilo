// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'package:deskilo/core/notifications/notification_providers.dart';
import 'package:deskilo/core/notifications/notification_service.dart';
import 'package:deskilo/core/storage/active_workspace_store.dart';
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/misc.dart';

import 'fake_event_repository.dart';
import 'fake_floor_plan_repository.dart';
import 'fake_money_repository.dart';
import 'fake_notification_service.dart';
import 'fake_reservation_repository.dart';

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
      throw StateError('invalid credentials');
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
      throw StateError('sign up failed');
    }
    _setUser('user-1');
  }

  @override
  Future<void> signOut() async => _setUser(null);
}

/// In-memory [WorkspaceRepository] for tests.
class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({List<Workspace>? workspaces})
      : workspaces = workspaces ?? [];

  FakeWorkspaceRepository.withWorkspace()
      : workspaces = [
          const Workspace(
            id: 'ws-1',
            name: 'Test Space',
            countryCode: 'DE',
            currencyCode: 'EUR',
            timezone: 'Europe/Berlin',
            inviteCode: 'GOODCODE22',
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
  Future<void> updateMemberPlan(String memberId, String? planId) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(planId: planId);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = otherMembers[i].copyWith(planId: planId);
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
  ReservationRepository? reservations,
  EventRepository? events,
  MoneyRepository? money,
  NotificationService? notifications,
  ActiveWorkspaceStore? activeWorkspace,
}) {
  return [
    authRepositoryProvider
        .overrideWithValue(auth ?? FakeAuthRepository.signedIn()),
    workspaceRepositoryProvider.overrideWithValue(
      workspace ?? FakeWorkspaceRepository.withWorkspace(),
    ),
    floorPlanRepositoryProvider
        .overrideWithValue(floorPlan ?? FakeFloorPlanRepository()),
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
