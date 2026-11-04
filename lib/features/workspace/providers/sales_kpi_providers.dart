// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales figures: their repository (overridable in tests
// and the demonstration) and one read per workspace and months, shared by
// the three cards.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_kpi_repository.dart';
import '../data/supabase_sales_kpi_repository.dart';
import '../domain/kpi_sales.dart';
import 'kpi_providers.dart';
import 'operation_context_providers.dart';

part 'sales_kpi_providers.g.dart';

@Riverpod(keepAlive: true)
SalesKpiRepository salesKpiRepository(Ref ref) =>
    SupabaseSalesKpiRepository(ref.watch(selectedWorkspaceClientProvider));

@Riverpod(retry: kpiRetry)
Future<SalesQualityKpi> salesQuality(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) {
  watchReaderRights(ref);
  return ref
      .watch(salesKpiRepositoryProvider)
      .quality(workspaceId, fromMonth: fromMonth, toMonth: toMonth);
}
