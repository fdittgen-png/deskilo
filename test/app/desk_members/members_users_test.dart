// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 — the users on the members' table: who can sign in is a chip, the
// roles a column (the set a person holds, never one string), and a role is
// given to a selection member by member with the role card's rule: one who
// cannot be given it (oneself) is listed with the reason, the others get it
// through the same command.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:deskilo/features/workspace/domain/workspace_roles_repository.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

const _bob = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

const _managed = Member(
  id: 'member-3',
  workspaceId: 'ws-1',
  // No account yet: an administrator runs the profile.
  userId: '',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
  managedName: 'Zoé',
);

const _treasurer = WorkspaceRole(
  id: 'r-t',
  key: 'treasurer',
  names: {'en': 'Treasurer'},
  permissions: {WorkspacePermission.viewFinances},
  sortOrder: 1,
);

/// Records what is given; answers the reads.
class _Roles implements WorkspaceRolesRepository {
  final given = <String>[];

  @override
  Future<List<WorkspaceRole>> fetchRoles(String workspaceId) async => const [
    _treasurer,
  ];

  @override
  Future<Map<String, Set<String>>> fetchAssignments(String workspaceId) async =>
      {
        'member-2': {'r-t'},
      };

  @override
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    required bool assign,
  }) async => given.add('$memberId:$roleId:$assign');

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Roles> _open(WidgetTester tester) async {
  final roles = _Roles();
  final space = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {for (final f in WorkspaceFeature.values) f.name: true},
  )..otherMembers.addAll([_bob, _managed]);
  await pumpRoute(
    tester,
    '/members',
    size: const Size(1440, 900),
    overrides: [
      ...standardTestOverrides(workspace: space, roles: roles),
      enabledFeaturesSyncProvider.overrideWithValue(
        WorkspaceFeature.values.toSet(),
      ),
    ],
  );
  return roles;
}

void main() {
  testWidgets('the roles are a column: each person\'s set', (tester) async {
    await _open(tester);
    expect(find.text('ROLES'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-row-member-2')),
        matching: find.text('Treasurer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('who can sign in, and the managed profiles, are chips', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('records-chip-managed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('records-row-member-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-row-member-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('records-chip-users')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('records-row-member-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-row-member-3')), findsNothing);
  });

  testWidgets('a role given to a selection: oneself is refused with the '
      'reason, the holder is said, the rest are given it', (tester) async {
    final roles = await _open(tester);
    for (final id in ['member-1', 'member-2', 'member-3']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('records-row-$id')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('records-bulk-give-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('give-role-treasurer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('give-role-apply')));
    await tester.pumpAndSettle();
    expect(roles.given, ['member-3:r-t:true']);
    String outcome(String id) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(ValueKey('give-role-outcome-$id')),
                matching: find.byType(Text),
              )
              .last,
        )
        .data!;
    expect(outcome('member-1'), 'You cannot give a role to yourself.');
    expect(outcome('member-2'), 'Already holds this role');
    expect(outcome('member-3'), 'Role given');
  });
}
