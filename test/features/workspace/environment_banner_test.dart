// SPDX-License-Identifier: 0BSD
//
// #917 — the strip that says a workspace is not real, and the one
// control that can take it away.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  String environment = 'dev',
  bool owner = true,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] =
      workspace.workspaces[0].copyWith(environment: environment);
  if (!owner) {
    workspace.myMember = workspace.myMember.copyWith(isOwner: false);
  }
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('a development workspace carries the strip', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('development-banner')), findsOneWidget);
  });

  testWidgets('a production workspace carries nothing — the absence is '
      'what makes the strip mean something', (tester) async {
    await _pump(tester, environment: 'prod');
    expect(find.byKey(const ValueKey('development-banner')), findsNothing);
  });

  testWidgets('the strip follows the route: it is above the navigator, so '
      'a pushed screen cannot escape it', (tester) async {
    await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('development-banner')), findsOneWidget);
  });

  testWidgets('the OWNER declares the space production, through a '
      'confirmation that says what stops happening', (tester) async {
    final workspace = await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/settings');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('workspace-environment')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-environment-switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workspace-environment-confirm')),
        findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('workspace-environment-confirm-yes')));
    await tester.pumpAndSettle();

    expect(workspace.lastEnvironment, 'prod');
  });

  testWidgets('#917 — the switcher paints each space its environment '
      'colour: orange for development, green for real', (tester) async {
    await _pump(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/profiles');
    await tester.pumpAndSettle();
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('profile-env-ws-1')),
    );
    expect(avatar.backgroundColor, AppEnvironmentColors.development,
        reason: 'a development space is orange');
  });

  testWidgets('a plain member never sees the control — only an owner may '
      'take the development mark off the documents', (tester) async {
    await _pump(tester, owner: false);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-environment')), findsNothing);
    expect(find.byKey(const ValueKey('development-banner')), findsOneWidget,
        reason: 'they still see WHERE they are');
  });
}
