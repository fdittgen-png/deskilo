// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures: their repository (overridable in tests
// and the demonstration) and one read per workspace and months, shared by
// the three cards.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_item_kpi_repository.dart';
import '../data/supabase_kpi_repository.dart';
import '../domain/kpi_items.dart';
import 'kpi_providers.dart';
import 'operation_context_providers.dart';

part 'item_kpi_providers.g.dart';

@Riverpod(keepAlive: true)
ItemKpiRepository itemKpiRepository(Ref ref) =>
    SupabaseItemKpiRepository(ref.watch(selectedWorkspaceClientProvider));

@Riverpod(retry: kpiRetry)
Future<ItemMarginsKpi> itemMargins(
  Ref ref,
  String workspaceId,
  String fromMonth,
  String toMonth,
) {
  watchReaderRights(ref);
  return ref
      .watch(itemKpiRepositoryProvider)
      .quality(workspaceId, fromMonth: fromMonth, toMonth: toMonth);
}
