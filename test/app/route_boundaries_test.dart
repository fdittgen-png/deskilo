// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the real router, the real screens, the boundaries the policy
// corrected: a signed-out person reaches the server chooser and the
// help; an account with no workspace reaches its own pages; a pending
// membership keeps the help and the switcher; a failed membership fetch
// is a retry, not a demand to create a space; a failed profile fetch is
// a retry, not a fresh legal acceptance. The policy table says what the
// rule is; this says the app does it.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_profile_repository.dart';
import '../helpers/mock_providers.dart';

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeWorkspaceRepository? workspace,
  FakeProfileRepository? profile,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: auth,
        workspace: workspace,
        profile: profile,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

/// Where the router settles after asking for [route].
Future<String> goTo(WidgetTester tester, GoRouter router, String route) async {
  unawaited(router.push(route));
  await tester.pumpAndSettle();
  return router.state.uri.toString();
}

void main() {
  group('signed out', () {
    testWidgets('the server chooser opens without an account',
        (tester) async {
      final router = await pumpApp(tester, auth: FakeAuthRepository());
      expect(await goTo(tester, router, '/server'), '/server');
      expect(find.byKey(const ValueKey('backend-status')), findsOneWidget);
    });

    testWidgets('the help opens without an account', (tester) async {
      final router = await pumpApp(tester, auth: FakeAuthRepository());
      expect(await goTo(tester, router, '/help'), '/help');
      expect(find.byKey(const ValueKey('help-toc-button')), findsOneWidget);
    });

    testWidgets('a workspace route still asks to sign in', (tester) async {
      final router = await pumpApp(tester, auth: FakeAuthRepository());
      expect(await goTo(tester, router, '/money'), '/auth');
    });
  });

  group('no workspace', () {
    testWidgets('boots into onboarding, keeps the account pages and the '
        'server and help reachable', (tester) async {
      final router = await pumpApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      expect(router.state.uri.toString(), '/onboarding?first=1');
      expect(await goTo(tester, router, '/profiles'), '/profiles');
      expect(await goTo(tester, router, '/server'), '/server');
      expect(await goTo(tester, router, '/help'), '/help');
      expect(await goTo(tester, router, '/linked-accounts'),
          '/linked-accounts');
      expect(await goTo(tester, router, '/reserve'), '/onboarding?first=1');
    });

    testWidgets('the instance wizard opens with no workspace to gate it',
        (tester) async {
      final router = await pumpApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
      );
      expect(await goTo(tester, router, '/server/new-instance'),
          '/server/new-instance');
    });
  });

  group('pending membership', () {
    FakeWorkspaceRepository pending() => FakeWorkspaceRepository.withWorkspace()
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.pending,
      );

    testWidgets('waits on the waiting room and keeps help, account and '
        'the switcher', (tester) async {
      final router = await pumpApp(tester, workspace: pending());
      expect(router.state.uri.toString(), '/pending');
      expect(await goTo(tester, router, '/help'), '/help');
      expect(await goTo(tester, router, '/profiles'), '/profiles');
      expect(await goTo(tester, router, '/linked-accounts'),
          '/linked-accounts');
      expect(await goTo(tester, router, '/money'), '/pending');
    });
  });

  group('a failed fetch is not an empty answer', () {
    testWidgets('memberships unavailable: the chooser with a retry, never '
        'onboarding', (tester) async {
      final workspace = FakeWorkspaceRepository.withWorkspace()
        ..fetchFailure = StateError('server down');
      final router = await pumpApp(tester, workspace: workspace);
      expect(router.state.uri.toString(), '/profiles');
      expect(find.byKey(const ValueKey('profiles-unavailable')),
          findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing,
          reason: 'no "add a profile" over an unknown list');

      // The server answers now: the list is back, the person stays on
      // the chooser they were sent to — it is theirs, not a detour.
      workspace.fetchFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/profiles');
      expect(find.byKey(const ValueKey('profiles-unavailable')), findsNothing);
      expect(find.text('Test Space'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('profile unavailable: the consent shows a retry, not the '
        'acceptance', (tester) async {
      final profile = FakeProfileRepository()..fetchFailing = true;
      final router = await pumpApp(tester, profile: profile);
      expect(router.state.uri.toString(), '/consent');
      expect(find.byKey(const ValueKey('consent-unavailable')), findsOneWidget);
      expect(find.byKey(const ValueKey('consent-accept')), findsNothing);
      expect(find.byKey(const ValueKey('consent-checkbox')), findsNothing);
      expect(profile.acceptedPolicyVersions, isEmpty);

      profile.fetchFailing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/reserve');
    });
  });
}
