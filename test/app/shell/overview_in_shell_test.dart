// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3060 — the workspace overview opens INSIDE the navigation shell from
// every entry (a deep link included): the drawer or the sidebar is there,
// and a refused feature lands on a real route, never on "no routes for /".
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'the overview deep link shows the shell at ${width.toInt()}dp',
      (tester) async {
        tester.view.physicalSize = Size(width * 2, 900 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final workspace = FakeWorkspaceRepository.withWorkspace();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...standardTestOverrides(workspace: workspace),
              enabledFeaturesSyncProvider.overrideWithValue(
                WorkspaceFeature.values.toSet(),
              ),
              attentionProvider.overrideWith((ref) async => const []),
            ],
            child: const DeskiloApp(),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DeskiloApp)),
        );
        container.read(routerProvider).go('/workspace-overview');
        await tester.pumpAndSettle();

        expect(find.byType(WorkspaceOverviewScreen), findsOneWidget);
        expect(find.byType(ShellScreen), findsOneWidget);
        // One app bar: the shell's own.
        expect(find.byType(AppBar), findsOneWidget);
      },
    );
  }

  testWidgets('a space without the overview refuses to a real route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            workspace: FakeWorkspaceRepository.withWorkspace(),
          ),
          enabledFeaturesSyncProvider.overrideWithValue(
            WorkspaceFeature.values
                .where((f) => f != WorkspaceFeature.workspaceOverview)
                .toSet(),
          ),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
        .read(routerProvider)
        .go('/workspace-overview');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WorkspaceOverviewScreen), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });
}
