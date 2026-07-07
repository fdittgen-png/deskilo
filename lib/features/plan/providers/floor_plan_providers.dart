// SPDX-License-Identifier: MIT
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_floor_plan_repository.dart';
import '../domain/floor_plan.dart';
import '../domain/floor_plan_repository.dart';
import '../domain/level.dart';

part 'floor_plan_providers.g.dart';

@Riverpod(keepAlive: true)
FloorPlanRepository floorPlanRepository(Ref ref) =>
    SupabaseFloorPlanRepository(Supabase.instance.client);

/// Levels of the active workspace, sorted by sort_order.
@Riverpod(keepAlive: true)
Future<List<Level>> levels(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(floorPlanRepositoryProvider).fetchLevels(workspace.id);
}

/// Everything drawn on one level. Family-keyed by level id.
@riverpod
Future<FloorPlan> floorPlan(Ref ref, String levelId) {
  return ref.watch(floorPlanRepositoryProvider).fetchPlan(levelId);
}

/// seat/office id → display name for the active workspace (labels in the
/// calendar and event feeds without loading every level's plan).
@Riverpod(keepAlive: true)
Future<Map<String, String>> targetNames(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref
      .watch(floorPlanRepositoryProvider)
      .fetchTargetNames(workspace.id);
}
