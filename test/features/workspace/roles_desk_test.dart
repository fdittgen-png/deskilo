// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 — the roles at the desk: the roles beside the chosen role's
// permissions, module by module, with how many people hold each role and
// each permission. The same switches and the same writes as on a phone: an
// editor turns a permission on from the keyboard alone, someone who may not
// edit sees the switches and cannot move them, and nobody moves the owner's.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/permission_modules.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _ana = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: true,
  isOwner: false,
  status: MemberStatus.active,
);

Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..otherMembers.add(_ana)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        if (permissions != null)
          myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/roles');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  test('every permission sits in exactly one module', () {
    final placed = [
      for (final (_, permissions) in permissionsByModule()) ...permissions,
    ];
    expect(placed.toSet(), WorkspacePermission.values.toSet());
    expect(placed.length, WorkspacePermission.values.length);
  });

  testWidgets('the roles are listed with how many people hold each', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('roles-desk-list')), findsOneWidget);
    // Flo is the owner, Ana an administrator.
    final owner = find.byKey(const ValueKey('roles-desk-role-owner'));
    expect(
      find.descendant(of: owner, matching: find.text('1 person')),
      findsOneWidget,
    );
    final admin = find.byKey(const ValueKey('roles-desk-role-admin'));
    expect(
      find.descendant(of: admin, matching: find.text('1 person')),
      findsOneWidget,
    );
  });

  testWidgets('an editor turns a permission on from the keyboard alone', (
    tester,
  ) async {
    final workspace = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('roles-desk-role-admin')));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('perm-admin-issueInvoices'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(tile).value, isFalse);
    // Focus the switch, then Space: no pointer.
    Focus.of(
      tester.element(
        find.descendant(of: tile, matching: find.byType(Checkbox)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    final stored = workspace.workspaces.single.rolePermissions['admin'] as List;
    expect(stored, contains('issueInvoices'));
  });

  testWidgets('who holds a permission is listed by name', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('roles-desk-role-admin')));
    await tester.pumpAndSettle();
    final who = find.byKey(const ValueKey('perm-who-manageMembers'));
    await tester.ensureVisible(who);
    await tester.pumpAndSettle();
    // The owner holds everything; the administrators manage members.
    expect(
      find.descendant(of: who, matching: find.text('2 people')),
      findsOneWidget,
    );
    await tester.tap(who);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('perm-holder-member-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('perm-holder-member-2')), findsOneWidget);
  });

  testWidgets('without the right to edit, the switches do not move; the '
      'owner\'s never do', (tester) async {
    await _pump(tester, permissions: const {WorkspacePermission.viewDirectory});
    await tester.tap(find.byKey(const ValueKey('roles-desk-role-admin')));
    await tester.pumpAndSettle();
    final admin = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('perm-admin-issueInvoices')),
    );
    expect(admin.onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('roles-desk-role-owner')));
    await tester.pumpAndSettle();
    final owner = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('perm-owner-manageRoles')),
    );
    expect(owner.onChanged, isNull);
  });
}
