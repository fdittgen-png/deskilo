// SPDX-License-Identifier: 0BSD
//
// Hierarchy pass: the member directory is feature-gated (default ON) —
// off removes the tab; whatsappIntegration strips every WhatsApp
// affordance while the directory itself stays.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('membersDirectory OFF hides the Members tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'membersDirectory': false},
          ),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.people_outline), findsNothing);
  });

  testWidgets('membersDirectory ON (default) keeps the Members tab',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.people_outline), findsWidgets);
  });
}
