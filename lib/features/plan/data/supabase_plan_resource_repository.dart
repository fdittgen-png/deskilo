// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/floor_plan_repository.dart';
import '../domain/grid_geometry.dart';
import '../domain/office.dart';
import '../domain/plan_resource_repository.dart';
import '../domain/seat.dart';

class SupabasePlanResourceRepository implements PlanResourceRepository {
  SupabasePlanResourceRepository(this._client, this._plan);

  final SupabaseClient _client;
  final FloorPlanRepository _plan;

  @override
  Future<void> createResource({
    required String workspaceId,
    required String deskId,
    required String name,
    required ({int x, int y}) anchor,
    required SeatOrientation orientation,
    required NewResource resource,
  }) async {
    await _client.from('seats').insert({
      'workspace_id': workspaceId,
      'desk_id': deskId,
      'name': name,
      'x': anchor.x,
      'y': anchor.y,
      'orientation': orientation.name,
      'resource_kind': resource.kind.name,
      'parking_kind': resource.parking?.name,
      'capacity': resource.capacity,
    });
    await _plan.invalidateCache();
  }

  @override
  Future<void> createParkingArea({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required GridRect rect,
  }) async {
    await _client.from('offices').insert({
      'workspace_id': workspaceId,
      'level_id': levelId,
      'name': name,
      'color': color,
      'bookable_as_whole': false,
      'area_kind': AreaKind.parking.name,
      'x': rect.x,
      'y': rect.y,
      'w': rect.w,
      'h': rect.h,
    });
    await _plan.invalidateCache();
  }
}
