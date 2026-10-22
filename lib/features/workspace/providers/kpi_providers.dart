// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the KPI repository, overridable in tests.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/time/workspace_time.dart';
import '../data/bi_query_coordinator.dart';
import '../data/fan_out_batch_reader.dart';
import '../data/supabase_kpi_repository.dart';
import '../domain/bi_batch.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_purchases.dart';
import 'workspace_providers.dart';

part 'kpi_providers.g.dart';

@Riverpod(keepAlive: true)
KpiRepository kpiRepository(Ref ref) =>
    SupabaseKpiRepository(ref.watch(selectedWorkspaceClientProvider));

/// #2578 — many figures in one read. The server's batch when the KPI
/// repository is the server's; otherwise (tests, the demonstration) each
/// figure is asked of the repository on its own.
@Riverpod(keepAlive: true)
KpiBatchReader biBatchReader(Ref ref) {
  final kpis = ref.watch(kpiRepositoryProvider);
  return BiQueryCoordinator(
    kpis is SupabaseKpiRepository
        ? SupabaseBiBatchReader(kpis.client)
        : FanOutBatchReader(kpis, ref.watch(financeKpiRepositoryProvider)),
  );
}

/// #1924 — the finance KPIs.
@Riverpod(keepAlive: true)
FinanceKpiRepository financeKpiRepository(Ref ref) =>
    SupabaseFinanceKpiRepository(ref.watch(selectedWorkspaceClientProvider));

/// One read per workspace and months, shared by every finance card.
@Riverpod(retry: kpiRetry)
Future<FinanceSummaryKpi> financeSummary(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) => ref
    .watch(financeKpiRepositoryProvider)
    .summary(workspaceId, fromMonth: fromMonth, toMonth: toMonth);

/// #2582 — the purchase figures.
@Riverpod(keepAlive: true)
PurchaseKpiRepository purchaseKpiRepository(Ref ref) =>
    SupabasePurchaseKpiRepository(ref.watch(selectedWorkspaceClientProvider));

/// One read per workspace and months, shared by every purchase card.
@Riverpod(retry: kpiRetry)
Future<PurchaseSummaryKpi> purchaseSummary(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) => ref
    .watch(purchaseKpiRepositoryProvider)
    .summary(workspaceId, fromMonth: fromMonth, toMonth: toMonth);

/// Seat utilisation of one calendar month, on the workspace clock: the
/// month starts at local midnight of its first day, whatever DST does.
@Riverpod(retry: kpiRetry)
Future<SeatCapacityKpi> seatCapacityMonth(
  Ref ref,
  String workspaceId,
  int year,
  int month,
) => ref
    .watch(kpiRepositoryProvider)
    .seatCapacity(
      workspaceId,
      from: WorkspaceTime.at(year, month, 1),
      to: WorkspaceTime.at(year, month + 1, 1),
    );
