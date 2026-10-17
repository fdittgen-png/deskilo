// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/resource_commands.dart';
import '../data/supabase_charging_station_repository.dart';
import '../data/supabase_plan_resource_repository.dart';
import '../domain/charging_station.dart';
import '../domain/charging_station_repository.dart';
import '../domain/plan_resource_repository.dart';
import 'floor_plan_providers.dart';

part 'charging_station_providers.g.dart';

@Riverpod(keepAlive: true)
ChargingStationRepository chargingStationRepository(Ref ref) =>
    SupabaseChargingStationRepository(ref.watch(planClientProvider));

@Riverpod(keepAlive: true)
PlanResourceRepository planResourceRepository(Ref ref) =>
    SupabasePlanResourceRepository(
      ref.watch(planClientProvider),
      ref.watch(floorPlanRepositoryProvider),
    );

@Riverpod(keepAlive: true)
ResourceCommands resourceCommands(Ref ref) => ResourceCommands(
  ref.watch(chargingStationRepositoryProvider),
  ref.watch(planResourceRepositoryProvider),
);

/// seat id → the charging station of that EV slot (#2631), across the
/// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
/// list.
@riverpod
Future<Map<String, ChargingStation>> chargingStations(
  Ref ref,
  String workspaceId,
) => ref.watch(chargingStationRepositoryProvider).fetchStations(workspaceId);
