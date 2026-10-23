// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — the Open steps end in a member who books, not in a status. The
// whole app runs five times over one in-memory server (the suite's fakes,
// shared between the mounts): the owner walks the guide's Open step pages,
// a second account joins with the invitation the owner sent, the owner
// approves the join, the member books a seat on the plan, and the owner's
// guide then counts the first booking.
//
// Three links are not driven through their own screen, and say so:
//  * the plan is SEEDED (one level, room, desk and seat): drawing it is the
//    plan editor's gesture work, which the places page only links to;
//  * the owner reaches the guide and the members list by pushing their
//    routes: the space is seeded, not created, and the guide opening on
//    creation is the onboarding recipe's (tool/bench);
//  * the guide's status is computed here from what the fakes hold, by the
//    detectors `workspace_setup_status` (0539) applies on the server — the
//    in-memory repository has no server to compute it. The guide screen
//    renders it; nothing here sets a step ready by hand.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/core/share/text_sharer.dart';
import 'package:deskilo/features/auth/domain/auth_repository.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/application/grant_member_essentials.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _space = 'ws-1';
const _ownerAccount = 'user-1';
const _memberAccount = 'user-2';

/// The server as two accounts see it: each reads only its own
/// memberships and its own default space, an invitation remembers the
/// space it was minted in, and redeeming it makes the joining account a
/// PENDING member of that space (every join waits for validation, 0052).
class _Server extends FakeWorkspaceRepository {
  _Server() : super.withWorkspace() {
    final ws = workspaces.single;
    // A space created today: members may do nothing yet (0373).
    workspaces[0] = ws.copyWith(
      rolePermissions: {...ws.rolePermissions, 'member': <String>[]},
    );
    openWeekdays[_space] = const [];
  }

  String _account = _ownerAccount;
  final _defaults = <String, String?>{_ownerAccount: _space};
  final _invitedTo = <String, String>{};

  /// The person signed in from now on: [myMember] is their membership,
  /// [otherMembers] everybody else's.
  void signInAs(String account) {
    final everyone = [if (myMember.id.isNotEmpty) myMember, ...otherMembers];
    final mine = everyone.where((m) => m.userId == account).firstOrNull;
    otherMembers
      ..clear()
      ..addAll(everyone.where((m) => m.userId != account));
    myMember =
        mine ??
        Member(
          id: '',
          workspaceId: '',
          userId: account,
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.exited,
        );
    _account = account;
  }

  Member? get _membership => myMember.id.isEmpty ? null : myMember;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async => [
    for (final w in workspaces)
      if (_membership?.workspaceId == w.id) w,
  ];

  @override
  Future<Member?> fetchMyMember(String workspaceId) async =>
      _membership?.workspaceId == workspaceId ? _membership : null;

  @override
  Future<List<Member>> fetchMyMembers() async => [?_membership];

  @override
  Future<String?> fetchDefaultWorkspaceId() async => _defaults[_account];

  @override
  Future<void> setDefaultWorkspaceId(String? workspaceId) async =>
      _defaults[_account] = workspaceId;

  @override
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
    bool alsoProd = false,
  }) async {
    final code = await super.createInvitation(
      workspaceId,
      isAdmin: isAdmin,
      firstName: firstName,
      lastName: lastName,
      memberId: memberId,
      alsoProd: alsoProd,
    );
    _invitedTo[code] = workspaceId;
    return code;
  }

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final workspaceId = _invitedTo[inviteCode];
    if (workspaceId == null) return super.joinWorkspace(inviteCode);
    if (!redeemedInvitations.add(inviteCode)) {
      throw StateError('invalid invite code');
    }
    final invitation = mintedInvitations.firstWhere(
      (i) => i.code == inviteCode,
    );
    myMember = Member(
      id: 'member-2',
      workspaceId: workspaceId,
      userId: _account,
      isAdmin: invitation.isAdmin,
      isOwner: false,
      status: MemberStatus.pending,
    );
    memberNames['member-2'] = '${invitation.firstName} ${invitation.lastName}';
    return workspaceId;
  }
}

/// The guide's status from what the fakes hold, step by step as the
/// server's detectors read it.
class _GuideEvidence extends FakeLocalSetupRepository {
  _GuideEvidence(this.server, this.plans, this.reservations);
  final _Server server;
  final FakeFloorPlanRepository plans;
  final FakeReservationRepository reservations;

  @override
  Future<SetupStatus> setupStatus(String workspaceId) async {
    final ws = server.workspaces.firstWhere((w) => w.id == workspaceId);
    final member = permissionsForRole(PermissionRole.member, ws);
    return demoSetupStatus(
      ws.featureFlags,
      ready: {
        if (server.lastLocaleUpdate?.first == workspaceId) 'basics',
        if ((server.openWeekdays[workspaceId] ?? const []).isNotEmpty) 'hours',
        if (plans.seats.any((s) => s.workspaceId == workspaceId)) 'places',
        if (member.contains(WorkspacePermission.makeReservations))
          'member_rights',
        if (server.mintedInvitations.isNotEmpty) 'invite',
        if (reservations.reservations.any((r) => r.workspaceId == workspaceId))
          'first_booking',
      },
    );
  }
}

/// Pumps frames until [finder] finds something; fails after ten seconds
/// of fake time instead of waiting on a condition that never comes.
Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('never shown: $finder');
}

/// Pumps frames until [done] holds.
Future<void> _untilTrue(
  WidgetTester tester,
  bool Function() done,
  String what,
) async {
  for (var i = 0; i < 200; i++) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('never happened: $what');
}

/// Pumps frames until [finder] is under the pointer and has not moved
/// for a frame: a page still sliding in is found, and even hit, but the
/// navigator drops a tap that lands during its transition.
Future<void> _still(WidgetTester tester, Finder finder) async {
  Rect? last;
  for (var i = 0; i < 200; i++) {
    final hit = finder.hitTestable();
    if (hit.evaluate().isNotEmpty) {
      final rect = tester.getRect(hit.first);
      if (rect == last) return;
      last = rect;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('never still: $finder');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump();
  await _still(tester, finder);
  // An expanding section above may have moved it since.
  await tester.ensureVisible(finder);
  await _still(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

Finder _key(String key) => find.byKey(ValueKey(key));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

/// Centre of the small plan's only seat (cell 5,4), transform-aware.
Offset _seat(WidgetTester tester) {
  final canvas = _key('reserve-plan-canvas');
  final topLeft = tester.getTopLeft(canvas);
  final scale =
      (tester.getTopRight(canvas).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  return topLeft +
      const Offset(
            5 * PlanCanvasMetrics.cellSize,
            4 * PlanCanvasMetrics.cellSize,
          ) *
          scale;
}

/// Opens [step] from the guide: its Next card when it is the next step,
/// its row in the to-do list, else its row in the folded section that
/// holds it ([status] is what the guide shows).
Future<void> _openFromGuide(
  WidgetTester tester,
  String step,
  SetupStatus status,
) async {
  await _still(tester, _key('setup-guide-list'));
  if (status.nextStep?.step == step) {
    return _tap(tester, _key('setup-guide-next-$step'));
  }
  bool holds(List<SetupStepStatus> steps) => steps.any((s) => s.step == step);
  final section = holds(status.toDo)
      ? null
      : holds(status.waiting)
      ? 'waiting'
      : holds(status.later)
      ? 'later'
      : holds(status.optional)
      ? 'optional'
      : holds(status.deferred)
      ? 'deferred'
      : 'done';
  if (section != null) await _tap(tester, _key('setup-guide-$section'));
  await _tap(tester, _key('setup-step-$step'));
}

/// Back from a step page to the guide, which reads the status again.
Future<void> _backToGuide(WidgetTester tester) async {
  // The guide's own back button is still in the tree, under the page.
  // The guide's own back button is still in the tree, under the page.
  await _tap(tester, find.byType(BackButton).hitTestable());
  await _still(tester, _key('setup-guide-list'));
}

void main() {
  testWidgets('after the Open steps a second account joins through the '
      'invitation and books a seat of the space', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final server = _Server();
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.single;
    final reservations = FakeReservationRepository(
      actor: () => server.myMember.id,
    );
    final guide = _GuideEvidence(server, plans, reservations);
    final shared = <String>[];

    Future<void> mount(String account) async {
      server.signInAs(account);
      final AuthRepository auth = FakeAuthRepository(userId: account);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ...standardTestOverrides(
              auth: auth,
              workspace: server,
              floorPlan: plans,
              reservations: reservations,
              localSetup: guide,
            ),
            textSharerProvider.overrideWithValue((text) async {
              shared.add(text);
            }),
          ],
          child: const DeskiloApp(),
        ),
      );
      await tester.pump();
    }

    // ── The owner walks the Open steps from the guide ────────────────
    await mount(_ownerAccount);
    await _until(tester, _key('reserve-plan-canvas'));
    unawaited(_router(tester).push('/setup'));

    await _openFromGuide(tester, 'basics', await guide.setupStatus(_space));
    await _tap(tester, _key('setup-basics-save'));
    await _untilTrue(
      tester,
      () => server.lastLocaleUpdate?.first == _space,
      'the basics saved',
    );
    await _backToGuide(tester);

    await _openFromGuide(tester, 'hours', await guide.setupStatus(_space));
    for (final day in [1, 2, 3, 4, 5]) {
      await _tap(tester, _key('availability-filter-chip-$day'));
      await _untilTrue(
        tester,
        () => server.openWeekdays[_space]!.contains(day),
        'weekday $day opened',
      );
    }
    expect(server.openWeekdays[_space], [1, 2, 3, 4, 5]);
    await _backToGuide(tester);

    await _openFromGuide(tester, 'places', await guide.setupStatus(_space));
    await _until(tester, _key('setup-places-bookable-seat-${seat.id}'));
    await _backToGuide(tester);

    await _openFromGuide(
      tester,
      'member_rights',
      await guide.setupStatus(_space),
    );
    await _tap(tester, _key('setup-rights-apply'));
    await _until(tester, _key('setup-rights-applied'));
    expect(
      server.workspaces.single.rolePermissions['member'],
      unorderedEquals([for (final p in memberEssentials) p.wireName]),
    );
    await _backToGuide(tester);

    await _openFromGuide(tester, 'invite', await guide.setupStatus(_space));
    await _tap(tester, _key('setup-invite-someone'));
    await _until(tester, _key('invite-first-name'));
    await tester.enterText(_key('invite-first-name'), 'Ben');
    await tester.enterText(_key('invite-last-name'), 'Weber');
    await _tap(tester, _key('invite-share'));
    await _untilTrue(tester, () => shared.isNotEmpty, 'the invitation sent');
    final invitation = server.mintedInvitations.single;
    expect(invitation.isAdmin, isFalse);
    final message = shared.single;
    expect(message, contains(invitation.code));
    await _backToGuide(tester);
    SetupStepState firstBooking(SetupStatus status) =>
        status.steps.firstWhere((s) => s.step == 'first_booking').state;
    expect(
      firstBooking(await guide.setupStatus(_space)),
      isNot(SetupStepState.ready),
      reason: 'nobody has booked yet',
    );

    // ── A second account joins with the message it received ──────────
    await mount(_memberAccount);
    await _tap(tester, _key('me-home-join'));
    await _until(tester, _key('invitation-input'));
    await tester.enterText(_key('invitation-input'), message);
    await _tap(tester, _key('invitation-review-button'));
    await _tap(tester, _key('invitation-join'));
    await _until(tester, find.byType(PendingApprovalScreen));
    expect(server.joinByInvitationCalls, 1);
    expect(server.redeemedInvitations, {invitation.code});
    expect(server.myMember.workspaceId, _space);
    expect(server.myMember.status, MemberStatus.pending);

    // ── The owner approves the join ──────────────────────────────────
    await mount(_ownerAccount);
    await _until(tester, _key('reserve-plan-canvas'));
    unawaited(_router(tester).push('/members'));
    await _tap(tester, find.text('Ben Weber'));
    await _tap(tester, _key('member-page-approve'));
    await _untilTrue(
      tester,
      () => server.otherMembers.any(
        (m) => m.id == 'member-2' && m.status == MemberStatus.active,
      ),
      'the join approved',
    );

    // ── The member books a seat of the space ─────────────────────────
    // A space is entered, never assumed (#1823): the member opens it
    // from Me.
    await mount(_memberAccount);
    await _tap(tester, _key('me-space-$_space'));
    await _until(tester, _key('reserve-plan-canvas'));
    // The shell's page transition and the plan's first fit.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(_seat(tester));
    await _until(tester, find.byType(BookingSheet));
    await _tap(tester, _key('booking-confirm'));
    await _untilTrue(
      tester,
      () => reservations.reservations.isNotEmpty,
      'the booking stored',
    );
    final booked = reservations.reservations.single;
    expect(booked.workspaceId, _space);
    expect(booked.memberId, 'member-2');
    expect(booked.seatId, seat.id);

    // ── The owner's guide counts the first booking ───────────────────
    await mount(_ownerAccount);
    await _until(tester, _key('reserve-plan-canvas'));
    unawaited(_router(tester).push('/setup'));
    await _until(tester, _key('setup-guide-list'));
    expect(firstBooking(await guide.setupStatus(_space)), SetupStepState.ready);
    final row = _key('setup-step-first_booking');
    if (row.evaluate().isEmpty) await _tap(tester, _key('setup-guide-done'));
    await _until(
      tester,
      find.descendant(of: _key('setup-guide-done'), matching: row),
    );
  });
}
