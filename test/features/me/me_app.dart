// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the whole app, pumped for the Me-layer tests: the real router,
// the real chrome, in-memory repositories.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// ws-1 (owner) and ws-2 (a plain member, a development space);
/// [serverDefault] is where the person was last.
FakeWorkspaceRepository twoSpaces({String? serverDefault = 'ws-1'}) {
  final repo = FakeWorkspaceRepository.withWorkspace()
    ..serverDefaultWorkspaceId = serverDefault;
  repo.workspaces.add(
    const Workspace(
      id: 'ws-2',
      name: 'Second Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: 'SECOND9999',
    ),
  );
  repo.extraMyMemberships.add(
    const Member(
      id: 'member-b',
      workspaceId: 'ws-2',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ),
  );
  return repo;
}

Future<GoRouter> pumpMeApp(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
  FakeAuthRepository? auth,
  FakeMeRepository? me,
  FakePersonalPreferencesRepository? preferences,
  FakeDirectoryRepository? directory,
  List<ConnectedInstallation> connectedSources = const [],
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        auth: auth,
        me: me,
        personalPreferences: preferences,
        directory: directory,
        connectedSources: connectedSources,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Future<String> goTo(WidgetTester tester, GoRouter router, String to) async {
  router.go(to);
  await tester.pumpAndSettle();
  return router.state.uri.toString();
}

Future<void> pushTo(WidgetTester tester, GoRouter router, String to) async {
  unawaited(router.push(to));
  await tester.pumpAndSettle();
}

/// Brings [finder] into view in the list keyed [list], then taps it.
Future<void> tapIn(WidgetTester tester, String list, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(of: find.byKey(ValueKey(list)), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
