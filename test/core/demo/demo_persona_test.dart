// SPDX-License-Identifier: 0BSD
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
}
