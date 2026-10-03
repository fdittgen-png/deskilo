// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — where a role is given, and what it gives.
//
// The invariants a person relies on:
//   * a member's page has ONE Roles section, and "Add a role" there gives
//     the workspace's own roles at once and asks for the Administrator
//     role through the validation quorum;
//   * a role somebody cannot give is shown with the reason, never as a
//     button that fails: nobody gives one to themselves, and a delegate
//     gives only what they hold;
//   * the role's editor lists the members holding it and gives it too;
//   * "What you can do here" lists what each role adds;
//   * with the flag off, the page keeps its single Administrator row.
import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/features/members/presentation/screens/member_page.dart';
import 'package:deskilo/features/workspace/domain/access_summary.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:deskilo/features/workspace/presentation/screens/roles_of_space_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/roles_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/role_editor_sheet.dart';
import 'package:deskilo/features/workspace/presentation/screens/what_you_can_do_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/member_roles_card.dart';
import 'package:deskilo/features/workspace/presentation/widgets/role_holders_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Member _member(String id, {bool admin = false, bool owner = false}) => Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'user-$id',
      isAdmin: admin,
      isOwner: owner,
      status: MemberStatus.active,
    );

const _treasurer = WorkspaceRole(
  id: 'role-t',
  key: 'tresorier',
  names: {'en': 'Treasurer'},
  permissions: {
    WorkspacePermission.viewFinances,
    WorkspacePermission.issueInvoices,
  },
  sortOrder: 1,
);

// #2085 PR3 — the built-in Administrator row every workspace carries.
const _administrator = WorkspaceRole(
  id: 'role-a',
  key: 'admin',
  names: {'en': 'Administrator'},
  builtin: true,
);

({FakeWorkspaceRepository workspace, FakeWorkspaceRoles roles}) _seed({
  bool viewerOwner = true,
  Map<String, dynamic> flags = const {'customRoles': true},
  Map<String, dynamic> rolePermissions = const {},
}) {
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..myMember = _member('me', owner: viewerOwner, admin: viewerOwner)
    ..otherMembers.addAll([_member('ben'), _member('cara')])
    ..memberNames = {'me': 'Flo', 'ben': 'Ben', 'cara': 'Cara'};
  if (rolePermissions.isNotEmpty) {
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(rolePermissions: rolePermissions);
  }
  final roles = FakeWorkspaceRoles()
    ..callerMemberId = 'me'
    ..roles.addAll([_administrator, _treasurer]);
  return (workspace: workspace, roles: roles);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required FakeWorkspaceRepository workspace,
  required FakeWorkspaceRoles roles,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        timeZoneMode: TimeZoneMode.device,
        workspace: workspace,
        roles: roles,
      ),
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAddSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(MemberRolesCard.addKey));
  await tester.tap(find.byKey(MemberRolesCard.addKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the owner gives a role on the member page; it takes effect at '
      'once and is taken back the same way', (tester) async {
    final s = _seed();
    await _pump(tester, const MemberPage(memberId: 'ben'),
        workspace: s.workspace, roles: s.roles);

    expect(find.byKey(MemberRolesCard.cardKey), findsOneWidget);
    expect(find.text('No role: everything a member can do.'), findsOneWidget);
    // The old single row is gone: the card is the one place.
    expect(find.byKey(const ValueKey('member-page-role')), findsNothing);

    await _openAddSheet(tester);
    expect(find.text('Give a role to Ben'), findsOneWidget);
    expect(find.text('Takes effect once validated.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('role-assign-tresorier')));
    await tester.pumpAndSettle();

    expect(s.roles.assignments['role-t'], ['ben']);
    expect(find.byKey(MemberRolesCard.chipKeyFor('tresorier')), findsOneWidget);
    expect(find.text('Role given.'), findsOneWidget);

    final chip = tester
        .widget<InputChip>(find.byKey(MemberRolesCard.chipKeyFor('tresorier')));
    chip.onDeleted!();
    await tester.pumpAndSettle();
    expect(s.roles.assignments['role-t'], isEmpty);
    expect(find.byKey(MemberRolesCard.chipKeyFor('tresorier')), findsNothing);
  });

  testWidgets('the Administrator role goes through the validation quorum',
      (tester) async {
    final s = _seed();
    await _pump(tester, const MemberPage(memberId: 'ben'),
        workspace: s.workspace, roles: s.roles);
    await _openAddSheet(tester);
    await tester.tap(find.byKey(const ValueKey('role-assign-administrator')));
    await tester.pumpAndSettle();
    expect(s.workspace.lastRoleChange, ('ws-1', 'ben', true));
    expect(find.text('Role change sent for validation.'), findsOneWidget);
  });

  testWidgets('on my own page nobody gives me a role, not even me',
      (tester) async {
    final s = _seed();
    await _pump(tester, const MemberPage(memberId: 'me'),
        workspace: s.workspace, roles: s.roles);
    expect(find.byKey(MemberRolesCard.cardKey), findsOneWidget);
    expect(find.byKey(MemberRolesCard.addKey), findsNothing);
    expect(find.text('You cannot give a role to yourself.'), findsOneWidget);
    expect(find.text('What you can do here'), findsOneWidget);
  });

  testWidgets('a delegate who manages roles sees why a role holding more '
      'than they do is not theirs to give', (tester) async {
    final s = _seed(
      viewerOwner: false,
      rolePermissions: const {
        'member': ['manageRoles', 'viewFinances', 'manageMembers'],
      },
    );
    await _pump(tester, const MemberPage(memberId: 'ben'),
        workspace: s.workspace, roles: s.roles);
    await _openAddSheet(tester);
    final tile = tester.widget<ListTile>(
        find.byKey(const ValueKey('role-assign-tresorier')));
    expect(tile.enabled, isFalse);
    expect(
      find.text('This role can do things you cannot, so only the owner '
          'gives it.'),
      findsOneWidget,
    );
    // The Administrator role is the owner's to ask for.
    expect(
      tester
          .widget<ListTile>(
              find.byKey(const ValueKey('role-assign-administrator')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('role-assign-tresorier')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(s.roles.assignments['role-t'], isNull);
  });

  testWidgets('with the flag off the page keeps its single Administrator row',
      (tester) async {
    final s = _seed(flags: const {'customRoles': true, 'roleAssignment': false});
    await _pump(tester, const MemberPage(memberId: 'ben'),
        workspace: s.workspace, roles: s.roles);
    expect(find.byKey(MemberRolesCard.cardKey), findsNothing);
    expect(find.byKey(const ValueKey('member-page-role')), findsOneWidget);
    expect(find.text('Give the Administrator role'), findsOneWidget);
  });

  testWidgets("the role's editor lists who holds it and gives it too",
      (tester) async {
    final s = _seed();
    s.roles.assignments['role-t'] = ['cara'];
    await _pump(tester, const RolesOfSpaceScreen(),
        workspace: s.workspace, roles: s.roles);
    await tester.tap(find.byKey(RolesOfSpaceScreen.rowKeyFor('tresorier')));
    await tester.pumpAndSettle();

    expect(find.text('Members in this role'), findsOneWidget);
    expect(find.byKey(RoleHoldersSection.holderKeyFor('cara')), findsOneWidget);

    await tester.ensureVisible(find.byKey(RoleHoldersSection.addKey));
    await tester.tap(find.byKey(RoleHoldersSection.addKey));
    await tester.pumpAndSettle();
    // Never yourself: the owner is not offered.
    expect(find.byKey(const ValueKey('role-holder-pick-me')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('role-holder-pick-ben')));
    await tester.pumpAndSettle();
    expect(s.roles.assignments['role-t'], ['cara', 'ben']);
    expect(find.byKey(RoleHoldersSection.holderKeyFor('ben')), findsOneWidget);
  });

  testWidgets('"What you can do here" lists what each role adds',
      (tester) async {
    final s = _seed(viewerOwner: false);
    s.roles.assignments['role-t'] = ['me'];
    await _pump(tester, const WhatYouCanDoScreen(),
        workspace: s.workspace, roles: s.roles);
    expect(find.text('What you can do here'), findsOneWidget);
    expect(
      find.byKey(WhatYouCanDoScreen.sourceKeyFor(
          AccessSourceKind.role, 'tresorier')),
      findsOneWidget,
    );
    expect(find.text('From the role Treasurer'), findsOneWidget);
    expect(find.text('View workspace finances'), findsOneWidget);
    expect(find.text('Issue invoices & match payments'), findsOneWidget);
  });

  testWidgets('a member without a role reads that they are a member, '
      'nothing more', (tester) async {
    final s = _seed(viewerOwner: false);
    await _pump(tester, const WhatYouCanDoScreen(),
        workspace: s.workspace, roles: s.roles);
    expect(find.text('Nothing more than a member.'), findsOneWidget);
  });

  testWidgets('the owner renames the Administrator, and every page reads the '
      'new name', (tester) async {
    final s = _seed();
    s.workspace.otherMembers
      ..removeWhere((m) => m.id == 'ben')
      ..add(_member('ben', admin: true));
    await _pump(tester, const RolesScreen(),
        workspace: s.workspace, roles: s.roles);
    // The matrix is long: the Administrator card is built once reached.
    await tester.scrollUntilVisible(
        find.byKey(RolesScreen.renameAdministratorKey), 400);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RolesScreen.renameAdministratorKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RoleEditorSheet.builtInNoteKey), findsOneWidget);
    // Only the name: no key, no permission switch.
    expect(find.byKey(RoleEditorSheet.keyFieldKey), findsNothing);
    expect(
        find.byKey(RoleEditorSheet.permissionKeyFor(
            WorkspacePermission.manageMembers)),
        findsNothing);
    await tester.enterText(
        find.byKey(RoleEditorSheet.nameKeyFor('en')), 'Board member');
    await tester.pump();
    await tester.tap(find.byKey(RoleEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(s.roles.roles.firstWhere((r) => r.builtin).names['en'],
        'Board member');
    expect(find.text('Board member'), findsOneWidget);

    await _pump(tester, const MemberPage(memberId: 'ben'),
        workspace: s.workspace, roles: s.roles);
    expect(
      find.descendant(
          of: find.byKey(MemberRolesCard.administratorKey),
          matching: find.text('Board member')),
      findsOneWidget,
    );
  });

  testWidgets("the space's own roles list the Administrator, whose holders "
      'are shown but given on the member page', (tester) async {
    final s = _seed();
    s.roles.assignments['role-a'] = ['ben'];
    await _pump(tester, const RolesOfSpaceScreen(),
        workspace: s.workspace, roles: s.roles);
    expect(find.text('Built in. What it may do is set in Roles.'),
        findsOneWidget);
    await tester.tap(find.byKey(RolesOfSpaceScreen.rowKeyFor('admin')));
    await tester.pumpAndSettle();
    expect(find.byKey(RoleHoldersSection.holderKeyFor('ben')), findsOneWidget);
    expect(find.byKey(RoleHoldersSection.addKey), findsNothing);
  });
}
