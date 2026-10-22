// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 — the overview's own figures: their repository (overridable in
// tests and the demonstration) and one read per figure and months.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_kpi_repository.dart';
import '../data/supabase_overview_kpi_repository.dart';
import '../domain/kpi_overview.dart';
import 'operation_context_providers.dart';

part 'overview_kpi_providers.g.dart';

@Riverpod(keepAlive: true)
OverviewKpiRepository overviewKpiRepository(Ref ref) =>
    SupabaseOverviewKpiRepository(ref.watch(selectedWorkspaceClientProvider));

/// One figure of [kpiId] for the whole months [fromMonth, toMonth].
@Riverpod(retry: kpiRetry)
Future<OverviewFigure> overviewFigure(
  Ref ref,
  String workspaceId,
  String kpiId,
  String fromMonth,
  String toMonth,
) => ref
    .watch(overviewKpiRepositoryProvider)
    .figure(workspaceId, kpiId, fromMonth: fromMonth, toMonth: toMonth);
