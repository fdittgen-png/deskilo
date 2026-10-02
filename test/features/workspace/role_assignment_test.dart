// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — who may give which role to whom, and what a member can do.
//
// The invariant: the client refuses exactly what the server refuses, for
// the reason a person can act on. Nobody gives a role to themselves; the
// Administrator role is the owner's to ask for; a workspace's own role is
// given by whoever manages roles, and someone who is not the owner gives
// only a role whose permissions they hold, never one carrying
// manageRoles. "What you can do here" adds up the same pieces the gates
// do, so it cannot promise more than they grant.
import 'package:deskilo/features/workspace/domain/access_summary.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/role_assignment.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(
  String id, {
  bool admin = false,
  bool owner = false,
  CoOwnerStatus coOwner = CoOwnerStatus.none,
  bool kiosk = false,
  MemberStatus status = MemberStatus.active,
}) =>
    Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'u-$id',
      isAdmin: admin,
      isOwner: owner,
      coOwner: coOwner,
      isKiosk: kiosk,
      status: status,
    );

Workspace _ws(Map<String, dynamic> flags) => Workspace(
      id: 'ws-1',
      name: 'Test Space',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'GOODCODE22',
      featureFlags: flags,
    );

const _treasurer = WorkspaceRole(
  id: 'r-t',
  key: 'tresorier',
  names: {'en': 'Treasurer', 'fr': 'Trésorier·ère'},
  permissions: {
    WorkspacePermission.viewFinances,
    WorkspacePermission.issueInvoices,
  },
  sortOrder: 1,
);

const _roleManager = WorkspaceRole(
  id: 'r-m',
  key: 'bureau',
  names: {'en': 'Board'},
  permissions: {WorkspacePermission.manageRoles},
  sortOrder: 2,
);

void main() {
  final owner = _m('owner', owner: true, admin: true);
  final lea = _m('lea');
  final delegate = _m('delegate');

  group('the Administrator role', () {
    test('the owner asks for it for somebody else', () {
      expect(administratorRefusal(caller: owner, subject: lea), isNull);
      expect(
        administratorRefusal(
          caller: _m('co', coOwner: CoOwnerStatus.active, admin: true),
          subject: lea,
        ),
        isNull,
        reason: 'an active co-owner acts as the owner (is_owner_of)',
      );
    });

    test('nobody asks for it for themselves, and only the owner asks', () {
      expect(administratorRefusal(caller: owner, subject: owner),
          RoleRefusal.yourself);
      expect(administratorRefusal(caller: _m('admin', admin: true), subject: lea),
          RoleRefusal.notPermitted);
    });

    test('the owner, an active co-owner, a kiosk or someone paused cannot '
        'hold it', () {
      for (final subject in [
        _m('o2', owner: true),
        _m('co', coOwner: CoOwnerStatus.active, admin: true),
        _m('k', kiosk: true),
        _m('p', status: MemberStatus.paused),
      ]) {
        expect(administratorRefusal(caller: owner, subject: subject),
            RoleRefusal.notAssignable,
            reason: subject.id);
      }
    });

    test('holding it means the admin flag without owner permissions', () {
      expect(holdsAdministrator(_m('a', admin: true)), isTrue);
      expect(holdsAdministrator(owner), isFalse);
      expect(
          holdsAdministrator(
              _m('co', admin: true, coOwner: CoOwnerStatus.active)),
          isFalse);
      expect(holdsAdministrator(lea), isFalse);
    });
  });

  group("a workspace's own role", () {
    test('the owner gives any role, even one that manages roles', () {
      for (final role in [_treasurer, _roleManager]) {
        expect(
          customRoleRefusal(
            caller: owner,
            callerPermissions: WorkspacePermission.values.toSet(),
            subject: lea,
            role: role,
          ),
          isNull,
          reason: role.key,
        );
      }
    });

    test('nobody gives a role to themselves, the owner included', () {
      expect(
        customRoleRefusal(
          caller: owner,
          callerPermissions: WorkspacePermission.values.toSet(),
          subject: owner,
          role: _treasurer,
        ),
        RoleRefusal.yourself,
      );
    });

    test('without manageRoles nothing is given', () {
      expect(
        customRoleRefusal(
          caller: delegate,
          callerPermissions: const {WorkspacePermission.viewFinances},
          subject: lea,
          role: _treasurer,
        ),
        RoleRefusal.notPermitted,
      );
    });

    test('a delegate gives only what they hold themselves', () {
      const delegatePerms = {
        WorkspacePermission.manageRoles,
        WorkspacePermission.viewFinances,
      };
      expect(
        customRoleRefusal(
          caller: delegate,
          callerPermissions: delegatePerms,
          subject: lea,
          role: _treasurer,
        ),
        RoleRefusal.exceedsYours,
        reason: 'the treasurer issues invoices, the delegate does not',
      );
      expect(
        customRoleRefusal(
          caller: delegate,
          callerPermissions: {...delegatePerms, WorkspacePermission.issueInvoices},
          subject: lea,
          role: _treasurer,
        ),
        isNull,
      );
    });

    test('a role carrying manageRoles is the owner\'s to give, whatever '
        'the delegate holds', () {
      expect(
        customRoleRefusal(
          caller: delegate,
          callerPermissions: WorkspacePermission.values.toSet(),
          subject: lea,
          role: _roleManager,
        ),
        RoleRefusal.ownerOnly,
      );
    });

    test('a role put aside cannot be given, but can be taken back', () {
      const aside = WorkspaceRole(
        id: 'r-x',
        key: 'old',
        names: {'en': 'Old'},
        active: false,
      );
      expect(
        customRoleRefusal(
          caller: owner,
          callerPermissions: WorkspacePermission.values.toSet(),
          subject: lea,
          role: aside,
        ),
        RoleRefusal.notAssignable,
      );
      expect(
        customRoleRefusal(
          caller: owner,
          callerPermissions: WorkspacePermission.values.toSet(),
          subject: lea,
          role: aside,
          granting: false,
        ),
        isNull,
      );
    });

    test('the roles a member holds come back in display order', () {
      final held = rolesHeldBy(
        'lea',
        const [_roleManager, _treasurer],
        const {
          'lea': {'r-m', 'r-t'},
          'ben': {'r-t'},
        },
      );
      expect(held.map((r) => r.key), ['tresorier', 'bureau']);
      expect(rolesHeldBy('nobody', const [_treasurer], const {}), isEmpty);
    });
  });

  group('what you can do here', () {
    final on = _ws(const {'customRoles': true});
    final off = _ws(const {});

    test('a plain member reads "every member", then each role they hold', () {
      final sources = accessSources(
        member: lea,
        workspace: on,
        roles: const [_treasurer, _roleManager],
        heldRoleIds: const {'r-t'},
      );
      expect(sources.map((s) => s.kind),
          [AccessSourceKind.everyMember, AccessSourceKind.role]);
      expect(sources.last.role?.key, 'tresorier');
      expect(grantedBy(sources), _treasurer.permissions);
      expect(
        grantedBy(sources),
        effectivePermissions(lea, on, custom: _treasurer.permissions),
        reason: 'the screen adds up exactly what the gates add up',
      );
    });

    test('with customRoles off a held role grants nothing and is not shown',
        () {
      final sources = accessSources(
        member: lea,
        workspace: off,
        roles: const [_treasurer],
        heldRoleIds: const {'r-t'},
      );
      expect(sources.map((s) => s.kind), [AccessSourceKind.everyMember]);
      expect(grantedBy(sources), isEmpty);
    });

    test('a role put aside grants nothing', () {
      const aside = WorkspaceRole(
        id: 'r-x',
        key: 'old',
        names: {'en': 'Old'},
        permissions: {WorkspacePermission.exportData},
        active: false,
      );
      expect(
        grantedBy(accessSources(
          member: lea,
          workspace: on,
          roles: const [aside],
          heldRoleIds: const {'r-x'},
        )),
        isEmpty,
      );
    });

    test('the base is exactly one of owner, co-owner, Administrator or every '
        'member', () {
      expect(accessSources(member: owner, workspace: on).single.kind,
          AccessSourceKind.owner);
      expect(
          accessSources(
                  member: _m('co', coOwner: CoOwnerStatus.active, admin: true),
                  workspace: on)
              .single
              .kind,
          AccessSourceKind.coOwner);
      final admin = accessSources(member: _m('a', admin: true), workspace: on);
      expect(admin.single.kind, AccessSourceKind.administrator);
      expect(admin.single.permissions,
          defaultPermissionsFor(PermissionRole.admin));
    });

    test('someone who is not active holds nothing', () {
      expect(
        accessSources(
          member: _m('p', status: MemberStatus.paused),
          workspace: on,
          roles: const [_treasurer],
          heldRoleIds: const {'r-t'},
        ),
        isEmpty,
      );
      expect(accessSources(member: null, workspace: on), isEmpty);
    });
  });
}
