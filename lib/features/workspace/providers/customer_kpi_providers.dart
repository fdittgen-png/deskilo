// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the customer figures: their repository (overridable in tests and
// the demonstration) and one read per workspace and months, shared by the
// four cards.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_customer_kpi_repository.dart';
import '../data/supabase_kpi_repository.dart';
import '../domain/kpi_customers.dart';
import 'kpi_providers.dart';
import 'operation_context_providers.dart';

part 'customer_kpi_providers.g.dart';

@Riverpod(keepAlive: true)
CustomerKpiRepository customerKpiRepository(Ref ref) =>
    SupabaseCustomerKpiRepository(ref.watch(selectedWorkspaceClientProvider));

@Riverpod(retry: kpiRetry)
Future<CustomerQualityKpi> customerQuality(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) {
  watchReaderRights(ref);
  return ref
      .watch(customerKpiRepositoryProvider)
      .quality(workspaceId, fromMonth: fromMonth, toMonth: toMonth);
}
