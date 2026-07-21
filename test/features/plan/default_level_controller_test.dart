// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/providers/default_level_controller.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/in_memory_default_level_store.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

/// Two levels in ws-1: 'level-1' (Ground floor, sortOrder 0, seeded by
/// [FakeFloorPlanRepository.seedSmallPlan]) and 'level-upper' (sortOrder 1).
FakeFloorPlanRepository twoLevelPlans() {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  plans.levels.add(
    const Level(
      id: 'level-upper',
      workspaceId: 'ws-1',
      name: 'First floor',
      sortOrder: 1,
    ),
  );
  return plans;
}

ProviderContainer containerWith(
  FakeFloorPlanRepository plans,
  InMemoryDefaultLevelStore store,
) {
  final container = ProviderContainer(
    overrides: [
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      floorPlanRepositoryProvider.overrideWithValue(plans),
      defaultLevelStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('nothing stored resolves to the first level by sort order', () async {
    final container =
        containerWith(twoLevelPlans(), InMemoryDefaultLevelStore());

    expect(await container.read(selectedLevelIdProvider.future), 'level-1');
  });

  test('a stored level that still exists resolves to that level', () async {
    final store = InMemoryDefaultLevelStore()..values['ws-1'] = 'level-upper';
    final container = containerWith(twoLevelPlans(), store);

    expect(
      await container.read(selectedLevelIdProvider.future),
      'level-upper',
    );
  });

  test('a stored level missing from the list falls back to the first level',
      () async {
    final store = InMemoryDefaultLevelStore()..values['ws-1'] = 'level-gone';
    final container = containerWith(twoLevelPlans(), store);

    expect(await container.read(selectedLevelIdProvider.future), 'level-1');
  });

  test('select() applies immediately and persists per workspace', () async {
    final store = InMemoryDefaultLevelStore();
    final container = containerWith(twoLevelPlans(), store);
    await container.read(selectedLevelIdProvider.future);

    await container
        .read(selectedLevelIdProvider.notifier)
        .select('level-upper');

    expect(container.read(selectedLevelIdProvider).value, 'level-upper');
    expect(store.values['ws-1'], 'level-upper');
    expect(store.writes, 1);
  });

  test('a workspace with no levels resolves to null', () async {
    final container = containerWith(
      FakeFloorPlanRepository(),
      InMemoryDefaultLevelStore(),
    );

    expect(await container.read(selectedLevelIdProvider.future), isNull);
  });
}
