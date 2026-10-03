// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1884 A — a management form through its real screen: switching a
// workspace feature records an attempt naming the feature (a public
// product key) and on/off BEFORE the save, and the save's real result
// after; the stored flags are the same with the recorder on and off;
// and the feature key set the recorder accepts is exactly the enum's.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'fixtures/recording_fixtures.dart';

Future<({ProviderContainer c, FakeWorkspaceRepository ws})> _pump(
  WidgetTester tester, {
  required bool record,
}) async {
  tester.view.physicalSize = const Size(800, 24000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ws = FakeWorkspaceRepository.withWorkspace();
  final c = ProviderContainer(
    overrides: [
      ...standardTestOverrides(workspace: ws),
      recorderStoreProvider.overrideWithValue(
        RecorderStore(
          backend: MemoryRecorderLogBackend(),
          namespace: canaryNamespace,
        ),
      ),
      recorderScopeProvider.overrideWithValue(canaryScope),
    ],
  );
  if (record) {
    expect(
      await c.read(recorderControllerProvider).start(scope: canaryScope),
      isTrue,
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byIcon(Icons.toggle_on_outlined), 200);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.toggle_on_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('features-view-switches')));
  await tester.pumpAndSettle();
  return (c: c, ws: ws);
}

Future<void> _done(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  test('the accepted feature keys are exactly the enum', () {
    expect(
      workspaceFeatureKeys,
      WorkspaceFeature.values.map((f) => f.name).toSet(),
    );
  });

  testWidgets('a feature switch: attempt, then the real save', (tester) async {
    final p = await _pump(tester, record: true);
    await tester.tap(find.text('Accessory supplements'));
    await tester.pumpAndSettle();
    final r = (await p.c.read(recorderControllerProvider).stop())!;
    final attempt = r.steps.firstWhere(
      (s) => s.action == RecorderActions.switchFeature,
    );
    expect(attempt.target, 'accessorySupplements');
    expect(attempt.payload.values, {'switch_to': 'on'});
    final outcome = r.steps.firstWhere(
      (s) => s.op == attempt.op && !s.isAttempt,
    );
    expect(outcome.outcome, RecorderOutcomes.settingSaved);
    expect(p.ws.workspaces.single.featureFlags['accessorySupplements'], isTrue);
    await _done(tester, p.c);
  });

  testWidgets('the same flags with the recorder off', (tester) async {
    final p = await _pump(tester, record: false);
    await tester.tap(find.text('Accessory supplements'));
    await tester.pumpAndSettle();
    expect(p.ws.workspaces.single.featureFlags['accessorySupplements'], isTrue);
    expect(p.c.read(recorderControllerProvider).state, RecorderState.idle);
    await _done(tester, p.c);
  });
}
