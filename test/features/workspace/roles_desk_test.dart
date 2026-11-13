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
import 'package:deskilo/features/workspace/presentation/screens/roles_screen_labels.dart';
import 'package:deskilo/features/workspace/presentation/widgets/roles_desk.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
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
    expect(tester.widget<CheckboxListTile>(tile).value, isFalse);
    // From the filter, Tab walks the page in reading order until it stands
    // on the switch; then Space turns it on: no pointer after the first
    // focus.
    await tester.tap(find.byKey(const ValueKey('roles-desk-filter')));
    await tester.pump();
    var reached = false;
    for (var i = 0; i < 120 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<CheckboxListTile>()
              ?.key ==
          const ValueKey('perm-admin-issueInvoices');
    }
    expect(reached, isTrue, reason: 'Tab reaches the switch');
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
    // The route is for those who hold manageRoles, so the read-only desk is
    // pumped as the widget the page builds.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RolesDesk(
              workspace: workspace.workspaces.single,
              canEdit: false,
              myRole: PermissionRole.admin,
              intro: '',
              roles: [
                for (final r in PermissionRole.values)
                  (id: r.wireName, name: r.wireName, base: r, own: null),
              ],
              onToggle: (_, _, _) => fail('a read-only desk writes nothing'),
              onEditOwn: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  test('every permission has its line of what it allows', () {
    // permissionAllows is a lookup: a permission with no entry would throw.
    final l10n = AppLocalizationsEn();
    for (final p in WorkspacePermission.values) {
      expect(permissionAllows(l10n, p), isNotEmpty, reason: '$p');
    }
  });

  testWidgets('the filter keeps the permissions whose name or line matches, '
      'module headings with nothing left are gone', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('roles-desk-role-admin')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('roles-desk-filter')),
      'invoices',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('perm-admin-issueInvoices')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('perm-admin-manageRoles')), findsNothing);
    expect(find.text('Stock'), findsNothing);
    // Each permission says what it allows.
    expect(
      find.text('Issue invoices, match payments and send reminders.'),
      findsOneWidget,
    );
  });
}
