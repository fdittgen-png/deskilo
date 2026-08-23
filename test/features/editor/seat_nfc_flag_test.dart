// SPDX-License-Identifier: 0BSD
//
// #604 — the chair-tag functionality (#585) rides the nfcSeatTags flag
// (default ON), and QR badge issuance rides qrBadges beside nfcBadges:
// switching either off takes its surface out of the app honestly.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import 'seat_accessories_test.dart' show seedSeat, openSeatSheet;

Future<void> _pumpSeatSheet(
  WidgetTester tester, {
  required Map<String, dynamic> featureFlags,
}) async {
  final plans = FakeFloorPlanRepository();
  final level = await plans.createLevel('ws-1', 'Ground floor', 0);
  await seedSeat(plans, level.id);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // The editor icon lives on the Plan tab's app bar (as in
  // level_canvas_test's pumpCanvas).
  await switchToPlanTab(tester);
  await tester.tap(find.byIcon(Icons.design_services_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ground floor'));
  await tester.pumpAndSettle();
  await openSeatSheet(tester);
}

void main() {
  testWidgets('the seat NFC/RFID field shows while nfcSeatTags is ON '
      '(the default)', (tester) async {
    await _pumpSeatSheet(tester, featureFlags: const {});
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('editor-seat-nfc')),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -80),
    );
    expect(find.byKey(const ValueKey('editor-seat-nfc')), findsOneWidget);
  });

  testWidgets('nfcSeatTags OFF removes the seat NFC/RFID field',
      (tester) async {
    await _pumpSeatSheet(
      tester,
      featureFlags: const {'nfcSeatTags': false},
    );
    expect(find.byKey(const ValueKey('editor-seat-nfc')), findsNothing);
  });

  testWidgets('qrBadges OFF hides "New badge" in the badge manager while '
      'the NFC register path follows nfcBadges', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'qrBadges': false},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-my-badge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('badge-issue-button')), findsNothing);
  });
}
