// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the vendor figures: their repository (overridable in tests
// and the demonstration) and one read per workspace and months, shared by
// the four cards.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_kpi_repository.dart';
import '../data/supabase_vendor_kpi_repository.dart';
import '../domain/kpi_vendors.dart';
import 'kpi_providers.dart';
import 'operation_context_providers.dart';

part 'vendor_kpi_providers.g.dart';

@Riverpod(keepAlive: true)
VendorKpiRepository vendorKpiRepository(Ref ref) =>
    SupabaseVendorKpiRepository(ref.watch(selectedWorkspaceClientProvider));

@Riverpod(retry: kpiRetry)
Future<VendorQualityKpi> vendorQuality(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) {
  watchReaderRights(ref);
  return ref
      .watch(vendorKpiRepositoryProvider)
      .quality(workspaceId, fromMonth: fromMonth, toMonth: toMonth);
}
