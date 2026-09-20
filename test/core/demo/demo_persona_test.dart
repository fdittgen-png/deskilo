// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1376 — a persona is an identity, not a pretend role.
//
// The claim worth proving is that nothing Demo-specific decides what a
// persona may do: the answers below come from `effectivePermissions`,
// the same function the live app calls, applied to the member the
// fixture hands back. If that ever stopped being true, these would still
// pass against a hard-coded table — so each one reads the permissions
// through the production function and never through the persona.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  DemoSession session() => container.read(demoSessionControllerProvider);
  DemoSessionController controller() =>
      container.read(demoSessionControllerProvider.notifier);

  Future<Set<WorkspacePermission>> permissions() async {
    final fixture = session().fixture;
    final member = await fixture.workspaces.fetchMyMember('ws-1');
    final workspace = (await fixture.workspaces.fetchMyWorkspaces()).first;
    return effectivePermissions(member, workspace);
  }

  test('a visitor lands as the owner, so every surface has something to '
      'show', () {
    expect(session().persona, DemoPersona.owner);
  });

  test('the owner holds everything, and a member holds nothing the matrix '
      'did not grant', () async {
    expect(await permissions(), WorkspacePermission.values.toSet());

    controller().viewAs(DemoPersona.member);
    final asMember = await permissions();
    expect(asMember, isNot(contains(WorkspacePermission.manageRoles)));
    expect(asMember, isNot(contains(WorkspacePermission.workspaceSettings)));
  });

  test('the administrator runs the day without owning the space', () async {
    controller().viewAs(DemoPersona.admin);
    final asAdmin = await permissions();

    expect(asAdmin, contains(WorkspacePermission.manageMembers));
    expect(asAdmin, contains(WorkspacePermission.manageReservations));
    expect(
      asAdmin,
      isNot(contains(WorkspacePermission.manageRoles)),
      reason: 'defining the roles belongs to the owner, here as in live '
          'mode — the same defaultPermissionsFor(admin) answers both',
    );
  });

  test('each persona is a real person in the dataset, with the identity '
      'the app signs in as', () async {
    for (final persona in DemoPersona.values) {
      controller().viewAs(persona);
      final member = await session().fixture.workspaces.fetchMyMember('ws-1');
      expect(member?.id, persona.memberId);
      expect(session().fixture.auth.currentUserId, persona.userId);
    }
  });

  test('the person a visitor is looking through is not also in the list of '
      'other members', () async {
    controller().viewAs(DemoPersona.member);
    final others = session().fixture.workspaces.otherMembers;
    expect(others.map((m) => m.id), isNot(contains(DemoPersona.member.memberId)));
    expect(others.map((m) => m.id), contains(DemoPersona.owner.memberId));
  });

  test('switching persona keeps the data — a viewpoint changes, a dataset '
      'does not', () async {
    await session().fixture.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    controller().viewAs(DemoPersona.member);

    final levels = await session().fixture.floorPlan.fetchLevels('ws-1');
    expect(levels.map((l) => l.name), contains('Mezzanine'));
  });

  test('the scope key carries the persona, so no privileged screen '
      'survives the switch', () {
    final asOwner = session().scopeKey;
    controller().viewAs(DemoPersona.member);
    expect(session().scopeKey, isNot(asOwner));
    expect(session().generation, 0, reason: 'the data was not reset');
  });

  test('switching to the persona already active changes nothing', () {
    final before = session();
    controller().viewAs(before.persona);
    expect(identical(session(), before), isTrue);
  });

  test('a reset returns the viewpoint as well as the data — the persona is '
      'session state', () {
    controller().viewAs(DemoPersona.member);
    controller().reset();
    expect(session().persona, initialDemoPersona);
  });

  // ── #1565 — a persona is who ACTS, not only who is displayed ───────

  test('#1565 — a booking made as a member belongs to that member', () async {
    controller().viewAs(DemoPersona.member);
    final fixture = session().fixture;
    final day = fixture.seededAt;

    final id = await fixture.reservations.create(
      workspaceId: 'ws-1',
      seatId: fixture.floorPlan.seats.first.id,
      startsAt: HalfDayWindows.morning(day).start,
      endsAt: HalfDayWindows.morning(day).end,
    );

    final booking = await fixture.reservations.fetchById(id);
    expect(
      booking?.memberId,
      DemoPersona.member.memberId,
      reason: 'the booking action calls create() with no explicit member '
          'because the repository owns the signed-in identity. It had '
          'captured member-1 at build time, so every demonstration '
          'booking belonged to Ada however the persona had moved',
    );
    expect(booking?.status, ReservationStatus.reserved);
  });

  test('#1565 — a decision taken as the administrator is recorded as '
      'hers', () async {
    controller().viewAs(DemoPersona.admin);
    final fixture = session().fixture;
    final pending = fixture.events.events.single;

    await fixture.events.respond(pending.id, accept: true);

    expect(
      fixture.events.decisions.single.memberId,
      DemoPersona.admin.memberId,
      reason: 'the decision trail must name member-3; an audit that '
          'credits the owner for somebody else\'s decision demonstrates '
          'the opposite of what the validation workflow is for',
    );
  });

  test('#1565 — a request the session raises is raised by the active '
      'persona', () async {
    controller().viewAs(DemoPersona.member);
    final fixture = session().fixture;

    final id = await fixture.events.requestReservationDeletion(
      'demo-next-week',
      reason: 'a demonstration',
    );

    expect(
      fixture.events.events.singleWhere((e) => e.id == id).actorMemberId,
      DemoPersona.member.memberId,
      reason: 'the implicit actor of an event REQUEST follows the '
          'persona for the same reason its decision does',
    );
  });

  test('#1565 — the actor moves back with the persona, in both '
      'directions', () async {
    final fixture = session().fixture;
    expect(fixture.activeMemberId, DemoPersona.owner.memberId);

    for (final persona in [
      DemoPersona.member,
      DemoPersona.admin,
      DemoPersona.owner,
      DemoPersona.member,
    ]) {
      controller().viewAs(persona);
      expect(session().fixture.activeMemberId, persona.memberId);
    }
  });

  test('#1565 — an edited subscription survives a persona switch', () async {
    final fixture = session().fixture;
    await fixture.workspaces.updateMemberSubscription('member-2', 75);
    await fixture.workspaces.updateMemberStatus('member-5', MemberStatus.active);

    controller().viewAs(DemoPersona.admin);
    controller().viewAs(DemoPersona.owner);

    final members = [
      session().fixture.workspaces.myMember,
      ...session().fixture.workspaces.otherMembers,
    ];
    expect(
      members.singleWhere((m) => m.id == 'member-2').subscriptionPct,
      75,
      reason: 'switching persona used to RESEED the cast from demoCast, '
          'so a successful edit was silently undone by looking at the '
          'space through somebody else',
    );
    expect(members.singleWhere((m) => m.id == 'member-5').status,
        MemberStatus.active);
  });

  test('#1565 — a member created during the session survives a persona '
      'switch, and Reset takes them away', () async {
    final id = await session().fixture.workspaces.createManagedMember(
          'ws-1',
          const PersonalInfo(firstName: 'Nino', lastName: 'Bosco'),
        );

    controller().viewAs(DemoPersona.member);
    expect(
      session().fixture.workspaces.otherMembers.map((m) => m.id),
      contains(id),
      reason: 'a viewpoint change is not a reseed',
    );

    controller().reset();
    expect(
      session().fixture.workspaces.otherMembers.map((m) => m.id),
      isNot(contains(id)),
      reason: 'canonical seeding belongs to session creation and Reset — '
          'that is the whole of what Reset promises',
    );
  });
}
