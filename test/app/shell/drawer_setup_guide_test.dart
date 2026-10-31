// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3077 — the invariant: the sidebar offers the setup guide's door only for
// someone who configures the space, while the guide has a milestone open;
// once every milestone is reached the door is gone.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

SetupStatus _status({required bool done}) => SetupStatus.fromJson({
  'steps': [
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': done ? 'ready' : 'needs_configuration',
      'route': '/editor',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': done ? 1 : 0,
      'reached': done,
    },
  ],
});

Future<void> _open(WidgetTester tester, {required bool done}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'setupGuide': true},
          ),
          localSetup: FakeLocalSetupRepository(status: _status(done: done)),
        ),
        webShellProvider.overrideWithValue(true),
      ],
      child: const DeskiloApp(),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _reveal(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('shell-drawer')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.text('Workspace setup'),
    80,
    scrollable: scrollable,
  );
  await tester.tap(find.text('Workspace setup'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the guide has a door while a milestone is open', (tester) async {
    await _open(tester, done: false);
    await _reveal(tester);
    expect(find.byKey(const ValueKey('drawer-setup-guide')), findsOneWidget);
  });

  testWidgets('the door is gone once every milestone is reached', (
    tester,
  ) async {
    await _open(tester, done: true);
    await _reveal(tester);
    expect(find.byKey(const ValueKey('drawer-setup-guide')), findsNothing);
  });
}
