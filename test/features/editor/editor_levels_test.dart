// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<FakeFloorPlanRepository> pumpAsOwner(
  WidgetTester tester, {
  FakeFloorPlanRepository? plans,
}) async {
  plans ??= FakeFloorPlanRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
  return plans;
}

Future<void> pumpAsWorker(WidgetTester tester) async {
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..myMember = const Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
}

void main() {
  testWidgets('owner sees the editor icon on the Plan tab and opens it',
      (tester) async {
    await pumpAsOwner(tester);

    final editorIcon = find.byIcon(Icons.design_services_outlined);
    expect(editorIcon, findsOneWidget);

    await tester.tap(editorIcon);
    await tester.pumpAndSettle();
    expect(find.text('Workspace editor'), findsOneWidget);
    expect(
      find.text('No levels yet. Add the first floor of your workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('worker does not get the editor affordance', (tester) async {
    await pumpAsWorker(tester);

    expect(find.byIcon(Icons.design_services_outlined), findsNothing);
  });

  testWidgets('owner adds a level via the FAB dialog', (tester) async {
    final plans = await pumpAsOwner(tester);
    await tester.tap(find.byIcon(Icons.design_services_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add level'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ground floor');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(plans.levels, hasLength(1));
    expect(plans.levels.single.name, 'Ground floor');
    expect(find.text('Ground floor'), findsOneWidget);
  });

  testWidgets('owner renames a level', (tester) async {
    final seeded = FakeFloorPlanRepository();
    await seeded.createLevel('ws-1', 'Old name', 0);
    final plans = await pumpAsOwner(tester, plans: seeded);
    await tester.tap(find.byIcon(Icons.design_services_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First floor');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(plans.levels.single.name, 'First floor');
  });

  testWidgets('owner deletes a level after confirmation', (tester) async {
    final seeded = FakeFloorPlanRepository();
    await seeded.createLevel('ws-1', 'Doomed floor', 0);
    final plans = await pumpAsOwner(tester, plans: seeded);
    await tester.tap(find.byIcon(Icons.design_services_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(plans.levels, isEmpty);
    expect(find.text('Doomed floor'), findsNothing);
  });

  testWidgets(
      'owner marks a level bookable as a whole with a half-day price '
      '(0050)', (tester) async {
    final seeded = FakeFloorPlanRepository();
    await seeded.createLevel('ws-1', 'Ground floor', 0);
    final plans = await pumpAsOwner(tester, plans: seeded);
    await tester.tap(find.byIcon(Icons.design_services_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookable as a whole'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('level-bookable-switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('level-price-field')),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey('level-booking-save')));
    await tester.pumpAndSettle();

    expect(plans.levels.single.bookableAsWhole, isTrue);
    expect(plans.levels.single.priceCents, 2500);
  });
}
