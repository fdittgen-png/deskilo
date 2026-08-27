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

  // #667 — the Flutter 3.44 bump forced onReorder -> onReorderItem, and the
  // two differ in exactly one way: onReorderItem ALREADY applies the
  // removed-item adjustment, so the historical
  // `newIndex > oldIndex ? newIndex - 1 : newIndex` correction had to be
  // deleted with it. Keeping both would shift every DOWNWARD drag by one —
  // silently, and only downward, which is precisely the bug that survives
  // manual testing. There was no reorder coverage at all before this.
  group('#667 level reordering after the onReorderItem migration', () {
    Future<FakeFloorPlanRepository> seedThreeLevels(WidgetTester tester) async {
      final seeded = FakeFloorPlanRepository();
      await seeded.createLevel('ws-1', 'Ground', 0);
      await seeded.createLevel('ws-1', 'First', 1);
      await seeded.createLevel('ws-1', 'Second', 2);
      final plans = await pumpAsOwner(tester, plans: seeded);
      await tester.tap(find.byIcon(Icons.design_services_outlined));
      await tester.pumpAndSettle();
      return plans;
    }

    /// Names in persisted sortOrder — what the user actually sees.
    List<String> order(FakeFloorPlanRepository plans) {
      final sorted = [...plans.levels]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return sorted.map((l) => l.name).toList();
    }

    testWidgets('dragging the first level DOWN to the end lands it last',
        (tester) async {
      final plans = await seedThreeLevels(tester);
      final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView));

      // onReorderItem's newIndex is already adjusted, so moving item 0 to
      // the end is (0 -> 2), not the raw (0 -> 3) the old callback took.
      list.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      expect(order(plans), ['First', 'Second', 'Ground'],
          reason: 'a stale -1 correction would leave Ground in the middle');
    });

    testWidgets('dragging the last level UP to the front lands it first',
        (tester) async {
      final plans = await seedThreeLevels(tester);
      final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView));

      // The upward direction never needed the correction, so it is the
      // control: it must behave identically before and after the migration.
      list.onReorderItem!(2, 0);
      await tester.pumpAndSettle();

      expect(order(plans), ['Second', 'Ground', 'First']);
    });

    testWidgets('the deprecated onReorder callback is no longer wired',
        (tester) async {
      await seedThreeLevels(tester);
      final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView));
      // ReorderableListView asserts exactly one of the two is non-null:
      //   (onReorderItem != null && onReorder == null) ||
      //   (onReorderItem == null && onReorder != null)
      // so a non-null onReorderItem PROVES onReorder is null. Asserting the
      // positive half deliberately: naming `onReorder` here would itself
      // raise the deprecated_member_use info that fails CI's analyze — the
      // very failure this test exists to prevent.
      expect(list.onReorderItem, isNotNull);
    });
  });
}
