// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the Demo performs a house abroad through its real screens. Before,
// the house is nowhere. From Settings › Workspace › Organisation, Ada adds a
// house abroad (the Demo proposes Poland, the one house it can add). She lands
// in it, and its home shows once how it began. The new house's Money and
// Calendar open without a fault.
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../helpers/settings_sections.dart';
import '../helpers/shell_bar.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ada adds the Demo\'s house abroad and lands in it', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, openHub: false);
    final f = journey.fixture;
    expect(f.houseRevealed, isFalse);
    expect(find.text('Atelier Kraków'), findsNothing);
    expect(
      f.workspaces.workspaces.any((w) => w.id == demoHouseSpaceId),
      isFalse,
      reason: 'before, the house is nowhere',
    );

    await tapShellBarControl(tester, 'shell-settings-button');
    await tester.pumpAndSettle();
    await showWorkspaceSettings(tester);
    await revealInSettings(tester, find.text('Workspace'));
    await tester.ensureVisible(find.text('Workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    await _tap(tester, 'workspace-settings-organisation');
    await _tap(tester, 'organisation-add-house');

    await tester.enterText(
      find.byKey(const ValueKey('house-add-name')),
      'Atelier Kraków',
    );
    await _tap(tester, 'house-add-submit');
    await tester.pumpAndSettle();

    expect(f.houseRevealed, isTrue);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(
      container.read(currentWorkspaceProvider).value?.id,
      demoHouseSpaceId,
      reason: 'the visitor lands in the new house',
    );
    expect(find.byKey(const ValueKey('house-birth')), findsOneWidget);
    await _tap(tester, 'house-birth-ok');

    // Every per-space read of the new house answers: its money and its
    // calendar open, and its plan (none: the house has no place yet) answers,
    // without a fault.
    for (final route in ['/money', '/plan', '/calendar']) {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }

    // A reset of the Demo puts the house back to dormant.
    await tester.tap(find.byKey(DemoControls.resetKey));
    await tester.pumpAndSettle();
    expect(journey.fixture.houseRevealed, isFalse);
    expect(
      journey.fixture.workspaces.workspaces.any(
        (w) => w.id == demoHouseSpaceId,
      ),
      isFalse,
    );
  });
}
