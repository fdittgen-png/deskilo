// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 (desk F2, first part) — the business on a desk. From the expanded
// window class the navigation stays beside the page on every platform: the
// rail at 1024, the sidebar at 1440 (narrowed to the rail by choice, kept
// per device); a phone keeps its bar. The kiosk's routes are workspace
// routes for authorization and get no desk. Tab reaches the navigation,
// then the top bar, then the page.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/data/workspace_roles_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  bool web = false,
  InMemoryShellFlagStore? rail,
  FakeWorkspaceRepository? workspace,
  FakeWorkspaceRoles? roles,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: workspace,
          roles: roles,
          deskRailCollapsed: rail,
        ),
        webShellProvider.overrideWithValue(web),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the chrome is declared apart from authorization: the kiosk keeps '
      'its workspace class and gets no desk', () {
    for (final kiosk in ['/kiosk', '/kiosk-gate']) {
      expect(classifyRoute(kiosk), RouteClass.workspace);
      expect(chromeOf(kiosk), RouteChrome.kiosk);
    }
    for (final rule in routeRules) {
      // The account's settings render a business's sections: on the desk.
      if (workspaceChromeAccountRoutes.contains(rule.pattern)) {
        expect(rule.chrome, RouteChrome.desk, reason: rule.pattern);
        continue;
      }
      final expected = switch (rule.kind) {
        // A membership still pending reaches no destination: no desk.
        RouteClass.workspace when rule.pattern == '/pending' =>
          RouteChrome.account,
        RouteClass.workspace =>
          rule.pattern.startsWith('/kiosk')
              ? RouteChrome.kiosk
              : RouteChrome.desk,
        RouteClass.nativeAccount || RouteClass.operator => RouteChrome.account,
        RouteClass.publicEntry || RouteClass.unknown => RouteChrome.public,
      };
      expect(rule.chrome, expected, reason: rule.pattern);
    }
  });

  for (final web in [false, true]) {
    testWidgets('at 1440 the sidebar and the top bar, no bottom bar '
        '(web=$web)', (tester) async {
      await _pump(tester, size: const Size(1440, 900), web: web);
      expect(_key('shell-sidebar'), findsOneWidget);
      expect(_key('desk-top-bar'), findsOneWidget);
      expect(_key('desk-breadcrumb'), findsOneWidget);
      expect(find.byType(ShellBottomBar), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('at 1024 the rail: its groups open as flyouts', (tester) async {
    await _pump(tester, size: const Size(1024, 768));
    expect(_key('desk-rail'), findsOneWidget);
    expect(_key('shell-sidebar'), findsNothing);
    expect(_key('desk-navigation-toggle'), findsNothing,
        reason: 'an expanded window always shows the rail');
    await tester.tap(_key('rail-group-people'));
    await tester.pumpAndSettle();
    expect(_key('rail-drawer-members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 390 nothing changes: the bar, no desk', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(_key('desk-top-bar'), findsNothing);
    expect(_key('desk-rail'), findsNothing);
  });

  testWidgets('the sidebar narrows to the rail and the choice is kept on '
      'the device', (tester) async {
    final rail = InMemoryShellFlagStore();
    await _pump(tester, size: const Size(1440, 900), rail: rail);
    await tester.tap(_key('desk-navigation-toggle'));
    await tester.pumpAndSettle();
    expect(_key('desk-rail'), findsOneWidget);
    expect(_key('shell-sidebar'), findsNothing);
    expect(rail.value, isTrue);
    expect(rail.writes, 1);
  });

  testWidgets('a destination hidden by a permission today is hidden on the '
      'desk', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {
        'customRoles': true,
        'moneyTab': true,
        'invoicing': true,
      },
    )..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );
    final roles = FakeWorkspaceRoles()
      ..callerMemberId = 'member-1'
      ..roles.add(const WorkspaceRole(
        id: 'role-m',
        key: 'members',
        names: {'en': 'Members'},
        permissions: {WorkspacePermission.manageMembers},
      ))
      ..assignments['role-m'] = ['member-1'];
    await _pump(
      tester,
      size: const Size(1024, 768),
      workspace: workspace,
      roles: roles,
    );
    expect(_key('rail-group-people'), findsOneWidget);
    expect(_key('rail-group-sales'), findsNothing);
    expect(_key('rail-group-finance'), findsNothing);
  });

  testWidgets('Tab reaches the navigation, then the top bar, then the page',
      (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    String? region() {
      String? found;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        final key = e.widget.key;
        if (key == const ValueKey('desk-navigation') ||
            key == const ValueKey('desk-top-bar')) {
          found = (key! as ValueKey<String>).value;
          return false;
        }
        return true;
      });
      return found ?? 'page';
    }

    final seen = <String>[];
    for (var step = 0; step < 200 && seen.length < 3; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final now = region()!;
      // From the first stop in the navigation (focus starts on the page).
      if (seen.isEmpty && now != 'desk-navigation') continue;
      if (seen.isEmpty || seen.last != now) seen.add(now);
    }
    expect(seen, ['desk-navigation', 'desk-top-bar', 'page']);
  });
}
