// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guide links cross Me and Workspace, restore the right tab and highlight the referenced control without completing work.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets(
    'step links cross Me and Workspace, restore a Me tab, and highlight again',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...standardTestOverrides(),
          taskRecorderAvailableProvider.overrideWithValue(true),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/me?tab=messages');
      await tester.pumpAndSettle();
      final workspace = container.read(activeWorkspaceIdProvider).value;
      final session = container.read(guideSessionProvider.notifier);
      expect(
        session.start(
          TaskGuide(
            actionContractVersion: actionContractVersion,
            title: 'Book a place and review your account',
            steps: const [
              GuideStep(
                id: 'g1',
                kind: GuideStepKind.perform,
                action: RecorderActions.selectDate,
                destination: '/reserve',
              ),
              GuideStep(
                id: 'g2',
                kind: GuideStepKind.perform,
                action: RecorderActions.uiTap,
                target: 'me-profile-settings',
                destination: '/me?tab=me',
              ),
            ],
          ),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      final show = find.byKey(const ValueKey('guide-host-show-me'));
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/reserve');
      expect(find.byKey(const ValueKey('guide-host-ring')), findsOneWidget);
      expect(
        container.read(guideSessionProvider).run!.statusOf('g1'),
        GuideStepStatus.pending,
      );

      await tester.tap(find.byKey(const ValueKey('guide-host-steps')));
      await tester.pumpAndSettle();
      final second = find.byKey(const ValueKey('guide-host-list-g2'));
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/me?tab=me');
      expect(find.byKey(const ValueKey('me-account-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('guide-host-ring')), findsOneWidget);
      expect(container.read(activeWorkspaceIdProvider).value, workspace);
      expect(
        container.read(guideSessionProvider).run!.state,
        GuideRunState.running,
      );
      expect(
        container.read(guideSessionProvider).run!.statusOf('g1'),
        GuideStepStatus.pending,
      );

      // Leaving the target page doesn't remove the step's link.
      router.go('/reserve');
      await tester.pumpAndSettle();
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/me?tab=me');
      expect(find.byKey(const ValueKey('guide-host-ring')), findsOneWidget);
      expect(tester.takeException(), isNull);
      session.close();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    },
  );
}
