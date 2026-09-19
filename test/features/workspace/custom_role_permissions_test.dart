// SPDX-License-Identifier: 0BSD
//
// #1287 — the client's half of the union that 0247 added to
// `has_permission_raw`. The rule is the same on both sides and stated
// twice on purpose: the server refuses the write, the client decides
// what to show, and a screen that disagrees with the database is a
// support call either way.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const member = Member(
    id: 'm',
    workspaceId: 'ws-1',
    userId: 'u',
    isAdmin: false,
    isOwner: false,
    status: MemberStatus.active,
  );

  Workspace workspaceWith(Map<String, dynamic> flags) => Workspace(
        id: 'ws-1',
        name: 'Test Space',
        countryCode: 'DE',
        currencyCode: 'EUR',
        timezone: 'Europe/Berlin',
        inviteCode: 'GOODCODE22',
        featureFlags: flags,
      );

  final on = workspaceWith(const {'customRoles': true});
  final off = workspaceWith(const {});

  group('a custom role is additive, and only while the feature is on', () {
    test('a plain member gains what the role holds', () {
      expect(
        effectivePermissions(member, on),
        isNot(contains(WorkspacePermission.issueInvoices)),
      );
      expect(
        effectivePermissions(
          member,
          on,
          custom: const {WorkspacePermission.issueInvoices},
        ),
        contains(WorkspacePermission.issueInvoices),
      );
    });

    test('the base role keeps everything it already held', () {
      const admin = Member(
        id: 'm',
        workspaceId: 'ws-1',
        userId: 'u',
        isAdmin: true,
        isOwner: false,
        status: MemberStatus.active,
      );
      final base = effectivePermissions(admin, on);
      final withRole = effectivePermissions(
        admin,
        on,
        custom: const {WorkspacePermission.manageBilling},
      );
      expect(withRole, containsAll(base));
      expect(withRole, contains(WorkspacePermission.manageBilling));
    });

    test('the flag off grants nothing, so the two sides withdraw together',
        () {
      expect(
        effectivePermissions(
          member,
          off,
          custom: const {WorkspacePermission.issueInvoices},
        ),
        isNot(contains(WorkspacePermission.issueInvoices)),
      );
    });

    test('an owner is unchanged — the owner branch comes first on the '
        'server too', () {
      const owner = Member(
        id: 'm',
        workspaceId: 'ws-1',
        userId: 'u',
        isAdmin: true,
        isOwner: true,
        status: MemberStatus.active,
      );
      expect(
        effectivePermissions(owner, on, custom: const {}),
        WorkspacePermission.values.toSet(),
      );
    });

    test('a member who is not active holds nothing, whatever a role says',
        () {
      expect(
        effectivePermissions(
          member.copyWith(status: MemberStatus.pending),
          on,
          custom: const {WorkspacePermission.issueInvoices},
        ),
        isEmpty,
      );
    });
  });
}
