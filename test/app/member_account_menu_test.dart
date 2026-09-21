// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1598 — the Pézenas field report: an ordinary member should meet no
// "Membres" and no "Réglages". `membersDirectory` already answers for
// the directory; the gear did not.
//
// Two things are proved here, and the second matters more than the
// first. One: with `memberAccountMenu` on, a member whose effective
// permission set is EMPTY meets "My account" where the gear was — in
// the app bar, in the drawer, and on the screen it opens — while a
// member who administers something keeps Réglages, and a workspace that
// never asked keeps exactly what it had. Two: none of that is access
// control. The entry opens the same `/settings`; the administrative
// routes behind it keep their own guards, and a member who types
// `/workspace-settings` is refused after the rename exactly as before.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

const _ordinaryMember = Member(
  id: 'member-1',
  workspaceId: 'ws-1',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

FakeWorkspaceRepository _repo({
  required bool flag,
  Member member = _ordinaryMember,
  Map<String, dynamic> rolePermissions = const {},
}) {
  final repo = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'memberAccountMenu': flag},
  )..myMember = member;
  if (rolePermissions.isNotEmpty) {
    repo.workspaces[0] =
        repo.workspaces[0].copyWith(rolePermissions: rolePermissions);
  }
  return repo;
}

Future<void> _pump(WidgetTester tester, FakeWorkspaceRepository repo,
    {bool web = false}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: repo),
        webShellProvider.overrideWithValue(web),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Where the router SETTLES after pushing [route] — a guard that refuses
/// redirects, so the landing location is the refusal.
Future<String> _push(WidgetTester tester, String route) async {
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  unawaited(router.push(route));
  await tester.pumpAndSettle();
  return router.state.uri.toString();
}

Finder _appBarText(String text) => find.descendant(
    of: find.byType(AppBar), matching: find.text(text));

void main() {
  group('the entry a member meets', () {
    testWidgets('OFF: the gear is exactly what it was', (tester) async {
      await _pump(tester, _repo(flag: false));

      expect(find.byKey(const ValueKey('shell-settings-button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('shell-account-button')), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('ON: a member who administers nothing meets My account',
        (tester) async {
      await _pump(tester, _repo(flag: true));

      expect(find.byKey(const ValueKey('shell-account-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-settings-button')), findsNothing);
      expect(find.byTooltip('My account'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsNothing);
    });

    testWidgets('ON: an owner keeps the gear', (tester) async {
      // The fake's default membership is the owner of ws-1.
      await _pump(tester, _repo(flag: true, member: const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: true,
        isOwner: true,
        status: MemberStatus.active,
      )));

      expect(find.byKey(const ValueKey('shell-settings-button')),
          findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets(
        'ON: a member the MATRIX delegates something to keeps the gear',
        (tester) async {
      // Not an admin and not an owner — the role flags say "ordinary".
      // The stored matrix says otherwise, and the matrix is what decides:
      // an `isOwner` shortcut would have renamed this person's entry and
      // hidden the workspace settings they are entitled to open.
      await _pump(
        tester,
        _repo(flag: true, rolePermissions: const {
          'member': ['workspaceSettings'],
        }),
      );

      expect(find.byKey(const ValueKey('shell-settings-button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('shell-account-button')), findsNothing);
    });

    testWidgets('ON: the drawer says the same word as the app bar',
        (tester) async {
      await _pump(tester, _repo(flag: true), web: true);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final entry = find.byKey(const ValueKey('drawer-settings'));
      await tester.scrollUntilVisible(entry, 80,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('shell-drawer')),
              matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      expect(
          find.descendant(of: entry, matching: find.text('My account')),
          findsOneWidget);
      expect(find.descendant(of: entry, matching: find.text('Settings')),
          findsNothing);
    });
  });

  group('hiding an entry is not access control', () {
    testWidgets(
        'the renamed entry opens the SAME /settings, and it carries no '
        'administration', (tester) async {
      await _pump(tester, _repo(flag: true));

      expect(await _push(tester, '/settings'), '/settings',
          reason: 'the personal page is the member\'s own and is never '
              'refused — only its name changed');
      expect(_appBarText('My account'), findsOneWidget);
      expect(_appBarText('Settings'), findsNothing);
      // #1307 already asked the matrix for these; the rename must not have
      // conjured any of them back.
      expect(find.text('This workspace'), findsNothing);
      expect(find.text('Administration'), findsNothing);
      expect(find.text('Governance'), findsNothing);
      // …and the personal controls the issue lists stay reachable.
      expect(find.text('Profiles'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-linked-accounts')),
          findsOneWidget);
    });

    testWidgets(
        'a member who types /workspace-settings is refused, flag or no flag',
        (tester) async {
      await _pump(tester, _repo(flag: true));

      expect(await _push(tester, '/workspace-settings'), '/messages',
          reason: 'the route guard reads the permission matrix, not the '
              'menu — renaming the entry withdraws nothing and grants '
              'nothing');
    });

    testWidgets('an owner still opens /settings under its own name',
        (tester) async {
      await _pump(tester, _repo(flag: true, member: const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: true,
        isOwner: true,
        status: MemberStatus.active,
      )));

      expect(await _push(tester, '/settings'), '/settings');
      expect(_appBarText('Settings'), findsOneWidget);
      expect(find.text('This workspace'), findsOneWidget);
    });
  });

  group('the predicate reads the effective set, and nothing else', () {
    const on = {WorkspaceFeature.memberAccountMenu};

    test('the flag alone does not rename a manager\'s entry', () {
      expect(
          showsMemberAccountMenu(features: on, permissions: const {}), isTrue);
      expect(
          showsMemberAccountMenu(
              features: on,
              permissions: const {WorkspacePermission.viewFinances}),
          isFalse,
          reason: 'one delegated permission is an administration');
    });

    test('without the flag nothing is renamed', () {
      expect(
          showsMemberAccountMenu(features: const {}, permissions: const {}),
          isFalse);
    });

    test('a CUSTOM role is an administration too (#1287)', () {
      // The workspace\'s own roles grant additively into the same set, so
      // the predicate sees them without knowing they exist.
      const treasurer = {WorkspacePermission.issueInvoices};
      expect(showsMemberAccountMenu(features: on, permissions: treasurer),
          isFalse);
    });
  });
}
