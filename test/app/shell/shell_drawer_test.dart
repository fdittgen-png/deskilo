// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The web shell: a hamburger drawer carries every destination and the
// bottom bar with its raised Reserve button is gone — web only.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';

import '../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool web,
  FakeWorkspaceRepository? workspace,
  FakeWorkspaceRoles? roles,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace, roles: roles),
        webShellProvider.overrideWithValue(web),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The drawer's list builds lazily: bring [key] into view from wherever
/// the list currently sits — scrolling down first, then back up.
Future<void> _reveal(WidgetTester tester, String key) async {
  final scrollable = find.descendant(
      of: find.byKey(const ValueKey('shell-drawer')),
      matching: find.byType(Scrollable));
  try {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 80,
        scrollable: scrollable);
  } on StateError {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), -80,
        scrollable: scrollable);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on the web the bar is gone and the drawer carries every '
      'destination', (tester) async {
    await _pump(tester, web: true);
    expect(find.byType(ShellBottomBar), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-drawer')), findsOneWidget);
    for (final key in [
      'drawer-reserve', 'drawer-tab-1', 'drawer-tab-2',
      'drawer-tab-3', 'drawer-workspace-settings',
      'drawer-members', 'drawer-roles', 'drawer-invoices', 'drawer-billing',
      'drawer-features', 'drawer-settings', 'drawer-privacy',
    ]) {
      await _reveal(tester, key);
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    // The calendar holds the alerts and events: the drawer has no Events entry.
    expect(find.byKey(const ValueKey('drawer-events')), findsNothing);
    await _reveal(tester, 'drawer-tab-1');
    await tester.tap(find.byKey(const ValueKey('drawer-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-drawer')), findsNothing);
    expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'drawer-members');
    await tester.tap(find.byKey(const ValueKey('drawer-members')));
    await tester.pumpAndSettle();
    expect(find.text('Members & plans'), findsWidgets);
  });

  testWidgets('native keeps the bar and has no drawer', (tester) async {
    await _pump(tester, web: false);
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsNothing);
  });

  // #2137 — every administration entry asks the permission its route
  // asks, so a member given it through one of the space's own roles finds
  // the way there, and a member without it does not.
  testWidgets('a member holding permissions through a role finds their '
      'entries; a plain member finds none', (tester) async {
    FakeWorkspaceRepository workspaceAs() =>
        FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'customRoles': true},
        )..myMember = const Member(
            id: 'member-1',
            workspaceId: 'ws-1',
            userId: 'user-1',
            isAdmin: false,
            isOwner: false,
            status: MemberStatus.active,
          );
    const entries = [
      'drawer-workspace-settings', 'drawer-members', 'drawer-availability',
      'drawer-services', 'drawer-billing', 'drawer-payment-methods',
    ];
    final roles = FakeWorkspaceRoles()
      ..callerMemberId = 'member-1'
      ..roles.add(const WorkspaceRole(
        id: 'role-o',
        key: 'office',
        names: {'en': 'Office'},
        permissions: {
          WorkspacePermission.workspaceSettings,
          WorkspacePermission.manageMembers,
          WorkspacePermission.manageServices,
          WorkspacePermission.manageBilling,
          WorkspacePermission.manageIntegrations,
        },
      ))
      ..assignments['role-o'] = ['member-1'];
    await _pump(tester, web: true, workspace: workspaceAs(), roles: roles);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    for (final key in entries) {
      await _reveal(tester, key);
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }

    await _pump(tester, web: true, workspace: workspaceAs(),
        roles: FakeWorkspaceRoles());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    for (final key in entries) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
  });
}
