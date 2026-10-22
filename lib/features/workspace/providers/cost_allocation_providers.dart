// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the cost allocation: its repository (overridable in tests),
// the period's allocation shared by the card, and the rules for the editor.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_cost_allocation_repository.dart';
import '../data/supabase_kpi_repository.dart';
import '../domain/cost_allocation_rules.dart';
import 'operation_context_providers.dart';

part 'cost_allocation_providers.g.dart';

@Riverpod(keepAlive: true)
CostAllocationRepository costAllocationRepository(Ref ref) =>
    SupabaseCostAllocationRepository(
      ref.watch(selectedWorkspaceClientProvider),
    );

/// One read per workspace and months.
@Riverpod(retry: kpiRetry)
Future<CostAllocationKpi> costAllocation(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) => ref
    .watch(costAllocationRepositoryProvider)
    .summary(workspaceId, fromMonth: fromMonth, toMonth: toMonth);

/// Every revision of the workspace's rules; the editor invalidates it
/// after a save.
@Riverpod(retry: kpiRetry)
Future<List<AllocationRule>> allocationRules(Ref ref, String workspaceId) =>
    ref.watch(costAllocationRepositoryProvider).rules(workspaceId);
