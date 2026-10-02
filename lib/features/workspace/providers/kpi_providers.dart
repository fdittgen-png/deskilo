// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the KPI repository, overridable in tests.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/workspace_time.dart';
import '../data/supabase_kpi_repository.dart';
import '../domain/kpi_contract.dart';

part 'kpi_providers.g.dart';

@Riverpod(keepAlive: true)
KpiRepository kpiRepository(Ref ref) =>
    SupabaseKpiRepository(Supabase.instance.client);

/// Seat utilisation of one calendar month, on the workspace clock: the
/// month starts at local midnight of its first day, whatever DST does.
@riverpod
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
