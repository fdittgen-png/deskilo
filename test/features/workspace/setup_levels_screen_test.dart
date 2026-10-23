// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the levels screen: nothing changes before the owner answers; an
// answer sets each process's level with its reason and applying writes
// exactly the planned change; switching anything off asks first, and a
// "no" writes nothing.
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<FakeWorkspaceRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeWorkspaceRepository.withWorkspace();
  await pumpApp(
    tester,
    const SetupLevelsScreen(),
    overrides: standardTestOverrides(workspace: repo),
  );
  await tester.pumpAndSettle();
  return repo;
}

SetupLevelChange _planFor(FakeWorkspaceRepository repo, SetupLevelVector v) {
  final stored = resolveEnabledFeatures(repo.workspaces.first.featureFlags);
  final current = currentSetupLevels(stored);
  return planSetupLevels(
    stored: stored,
    current: current,
    chosen: {...current, ...v},
  );
}

void main() {
  testWidgets('before an answer, nothing changes', (tester) async {
    await _pump(tester);
    expect(
      find.text('Nothing changes: the space already does this.'),
      findsOneWidget,
    );
    final apply = tester.widget<FilledButton>(
      find.byKey(const ValueKey('setup-levels-apply')),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('a quick start writes exactly the planned change', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.complet]!);
    expect(expected.isEmpty, isFalse, reason: 'the fixture must move');
    await tester.tap(find.byKey(const ValueKey('setup-preset-complet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-levels-on')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-levels-apply')));
    await tester.pumpAndSettle();
    if (expected.switchOff.isNotEmpty) {
      await tester.tap(
        find.byKey(const ValueKey('setup-levels-confirm-off-yes')),
      );
      await tester.pumpAndSettle();
    }
    expect(repo.flagWrites, [expected.flags]);
  });

  testWidgets('switching off asks first, and a no writes nothing', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final expected = _planFor(repo, setupPresets[SetupPreset.essentiel]!);
    expect(expected.switchOff, isNotEmpty, reason: 'the fixture must lower');
    await tester.tap(find.byKey(const ValueKey('setup-preset-essentiel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-levels-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('setup-levels-confirm-off')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.flagWrites, isEmpty);
  });

  testWidgets('an answer gives its process a level and says why', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('setup-question-issue_invoices')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Because you issue invoices'), findsOneWidget);
  });
}
