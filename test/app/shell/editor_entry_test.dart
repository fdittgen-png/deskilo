// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2137 — editing the floor plan is delegable through manageSites: a
// member who holds it through one of the space's own roles finds the
// editor (the drawer entry on the web, the app-bar button on the Reserve
// tab natively) and the /editor route lets them in; a member without it
// finds neither.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/features/editor/presentation/screens/editor_screen.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

FakeWorkspaceRepository _workspace() =>
    FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'customRoles': true},
      )
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );

FakeWorkspaceRoles _facilities() => FakeWorkspaceRoles()
  ..callerMemberId = 'member-1'
  ..roles.add(
    const WorkspaceRole(
      id: 'role-f',
      key: 'facilities',
      names: {'en': 'Facilities'},
      permissions: {WorkspacePermission.manageSites},
    ),
  )
  ..assignments['role-f'] = ['member-1'];

Future<void> _pump(
  WidgetTester tester, {
  required bool web,
  required FakeWorkspaceRoles roles,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: _workspace(), roles: roles),
        webShellProvider.overrideWithValue(web),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The drawer's list builds lazily: bring [key] into view.
Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.tap(find.text('Workspace setup'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    80,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('shell-drawer')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a manageSites role holder opens the editor from the drawer', (
    tester,
  ) async {
    await _pump(tester, web: true, roles: _facilities());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'drawer-editor');
    await tester.tap(find.byKey(const ValueKey('drawer-editor')));
    await tester.pumpAndSettle();
    expect(
      find.byType(EditorScreen),
      findsOneWidget,
      reason: 'the /editor route lets a manageSites holder in',
    );
  });

  testWidgets('natively the Reserve tab shows them the editor button', (
    tester,
  ) async {
    await _pump(tester, web: false, roles: _facilities());
    expect(find.byKey(const ValueKey('shell-editor-button')), findsOneWidget);
  });

  testWidgets('a member without manageSites finds no way to the editor', (
    tester,
  ) async {
    await _pump(tester, web: false, roles: FakeWorkspaceRoles());
    expect(find.byKey(const ValueKey('shell-editor-button')), findsNothing);
    // The door, not only the entry: a typed /editor bounces.
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/editor'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);

    await _pump(tester, web: true, roles: FakeWorkspaceRoles());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drawer-editor')), findsNothing);
  });
}
