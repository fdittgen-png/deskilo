// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpSettings(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  return workspace;
}

Future<FakeWorkspaceRepository> pumpFeatures(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  // Nine manifest features no longer fit the default 800×600 surface and
  // the lazy list drops off-screen tiles; keep every switch mounted.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      await pumpSettings(tester, featureFlags: featureFlags);
  await tester.tap(find.text('Features'));
  await tester.pumpAndSettle();
  return workspace;
}

SwitchListTile switchTitled(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchListTile),
      ),
    );

void main() {
  testWidgets('features screen lists a switch per manifest feature',
      (tester) async {
    await pumpFeatures(tester);

    expect(
      find.byType(SwitchListTile),
      findsNWidgets(featureManifest.length),
    );
    // Everything defaults ON — except adminSeatBlocking (#161), which the
    // owner must explicitly delegate.
    expect(switchTitled(tester, 'Admins can block seats').value, isFalse);
    final onCount = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .where((t) => t.value)
        .length;
    expect(onCount, featureManifest.length - 1);
  });

  testWidgets('toggling a feature persists the full map and flips the switch',
      (tester) async {
    final workspace = await pumpFeatures(tester);

    await tester.tap(find.text('Money tab'));
    await tester.pumpAndSettle();

    // The fake row now carries the FULL map with moneyTab off (and the
    // default-OFF adminSeatBlocking, #161, still off).
    final flags = workspace.workspaces.single.featureFlags;
    expect(flags['moneyTab'], isFalse);
    expect(flags.length, WorkspaceFeature.values.length);
    expect(
      flags.entries.where((e) => e.value == false).map((e) => e.key),
      unorderedEquals(['moneyTab', 'adminSeatBlocking']),
    );
    expect(switchTitled(tester, 'Money tab').value, isFalse);

    // Toggling back re-enables it.
    await tester.tap(find.text('Money tab'));
    await tester.pumpAndSettle();
    expect(
      workspace.workspaces.single.featureFlags['moneyTab'],
      isTrue,
    );
    expect(switchTitled(tester, 'Money tab').value, isTrue);
  });

  testWidgets('stored overrides seed the switches', (tester) async {
    await pumpFeatures(
      tester,
      featureFlags: const {'seriesBooking': false},
    );

    expect(switchTitled(tester, 'Series booking').value, isFalse);
    expect(switchTitled(tester, 'Calendar tab').value, isTrue);
  });

  testWidgets('settings hides the Services tile when services is disabled',
      (tester) async {
    await pumpSettings(tester, featureFlags: const {'services': false});

    expect(find.text('Services'), findsNothing);
    // The owner tiles around it stay.
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
  });

  testWidgets('settings shows the Services tile when services is enabled',
      (tester) async {
    await pumpSettings(tester);

    expect(find.text('Services'), findsOneWidget);
  });
}
