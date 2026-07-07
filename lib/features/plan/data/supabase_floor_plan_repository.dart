// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/desk.dart';
import '../domain/floor_plan.dart';
import '../domain/floor_plan_repository.dart';
import '../domain/grid_geometry.dart';
import '../domain/level.dart';
import '../domain/office.dart';
import '../domain/seat.dart';

class SupabaseFloorPlanRepository implements FloorPlanRepository {
  SupabaseFloorPlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Level>> fetchLevels(String workspaceId) async {
    final rows = await _client
        .from('levels')
        .select()
        .eq('workspace_id', workspaceId)
        .order('sort_order', ascending: true);
    return rows.map(_levelFromRow).toList();
  }

  @override
  Future<Level> createLevel(
    String workspaceId,
    String name,
    int sortOrder,
  ) async {
    final row = await _client
        .from('levels')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return _levelFromRow(row);
  }

  @override
  Future<void> renameLevel(String levelId, String name) async {
    await _client.from('levels').update({'name': name}).eq('id', levelId);
  }

  @override
  Future<void> deleteLevel(String levelId) async {
    await _client.from('levels').delete().eq('id', levelId);
  }

  @override
  Future<void> reorderLevels(List<String> orderedLevelIds) async {
    for (var i = 0; i < orderedLevelIds.length; i++) {
      await _client
          .from('levels')
          .update({'sort_order': i}).eq('id', orderedLevelIds[i]);
    }
  }

  @override
  Future<FloorPlan> fetchPlan(String levelId) async {
    final officeRows =
        await _client.from('offices').select().eq('level_id', levelId);
    final offices = officeRows.map(_officeFromRow).toList();
    final officeIds = offices.map((o) => o.id).toList();

    var desks = <Desk>[];
    var seats = <Seat>[];
    if (officeIds.isNotEmpty) {
      final deskRows = await _client
          .from('desks')
          .select()
          .inFilter('office_id', officeIds);
      desks = deskRows.map(_deskFromRow).toList();
      final deskIds = desks.map((d) => d.id).toList();
      if (deskIds.isNotEmpty) {
        final seatRows =
            await _client.from('seats').select().inFilter('desk_id', deskIds);
        seats = seatRows.map(_seatFromRow).toList();
      }
    }
    return FloorPlan(
      levelId: levelId,
      offices: offices,
      desks: desks,
      seats: seats,
    );
  }

  @override
  Future<Office> createOffice({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required bool bookableAsWhole,
    required GridRect rect,
  }) async {
    final row = await _client
        .from('offices')
        .insert({
          'workspace_id': workspaceId,
          'level_id': levelId,
          'name': name,
          'color': color,
          'bookable_as_whole': bookableAsWhole,
          'x': rect.x,
          'y': rect.y,
          'w': rect.w,
          'h': rect.h,
        })
        .select()
        .single();
    return _officeFromRow(row);
  }

  @override
  Future<void> updateOffice(Office office) async {
    await _client.from('offices').update({
      'name': office.name,
      'color': office.color,
      'bookable_as_whole': office.bookableAsWhole,
      'x': office.rect.x,
      'y': office.rect.y,
      'w': office.rect.w,
      'h': office.rect.h,
    }).eq('id', office.id);
  }

  @override
  Future<void> deleteOffice(String officeId) async {
    await _client.from('offices').delete().eq('id', officeId);
  }

  @override
  Future<Desk> createDesk({
    required String workspaceId,
    required String officeId,
    required String name,
    required GridRect rect,
  }) async {
    final row = await _client
        .from('desks')
        .insert({
          'workspace_id': workspaceId,
          'office_id': officeId,
          'name': name,
          'x': rect.x,
          'y': rect.y,
          'w': rect.w,
          'h': rect.h,
        })
        .select()
        .single();
    return _deskFromRow(row);
  }

  @override
  Future<void> updateDesk(Desk desk) async {
    await _client.from('desks').update({
      'name': desk.name,
      'x': desk.rect.x,
      'y': desk.rect.y,
      'w': desk.rect.w,
      'h': desk.rect.h,
    }).eq('id', desk.id);
  }

  @override
  Future<void> deleteDesk(String deskId) async {
    await _client.from('desks').delete().eq('id', deskId);
  }

  @override
  Future<Seat> createSeat({
    required String workspaceId,
    required String deskId,
    required String name,
    required int x,
    required int y,
    required SeatOrientation orientation,
  }) async {
    final row = await _client
        .from('seats')
        .insert({
          'workspace_id': workspaceId,
          'desk_id': deskId,
          'name': name,
          'x': x,
          'y': y,
          'orientation': orientation.name,
        })
        .select()
        .single();
    return _seatFromRow(row);
  }

  @override
  Future<void> updateSeat(Seat seat) async {
    await _client.from('seats').update({
      'name': seat.name,
      'x': seat.x,
      'y': seat.y,
      'orientation': seat.orientation.name,
      'chair': seat.chair,
      'amenities': seat.amenities,
      'blocked_from': seat.blockedFrom?.toUtc().toIso8601String(),
      'blocked_to': seat.blockedTo?.toUtc().toIso8601String(),
    }).eq('id', seat.id);
  }

  @override
  Future<void> deleteSeat(String seatId) async {
    await _client.from('seats').delete().eq('id', seatId);
  }

  Level _levelFromRow(Map<String, dynamic> row) => Level(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        sortOrder: row['sort_order'] as int,
      );

  GridRect _rectFromRow(Map<String, dynamic> row) => GridRect(
        x: row['x'] as int,
        y: row['y'] as int,
        w: row['w'] as int,
        h: row['h'] as int,
      );

  Office _officeFromRow(Map<String, dynamic> row) => Office(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        levelId: row['level_id'] as String,
        name: row['name'] as String,
        color: row['color'] as int,
        bookableAsWhole: row['bookable_as_whole'] as bool,
        rect: _rectFromRow(row),
      );

  Desk _deskFromRow(Map<String, dynamic> row) => Desk(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        officeId: row['office_id'] as String,
        name: row['name'] as String,
        rect: _rectFromRow(row),
      );

  Seat _seatFromRow(Map<String, dynamic> row) => Seat(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        deskId: row['desk_id'] as String,
        name: row['name'] as String,
        x: row['x'] as int,
        y: row['y'] as int,
        orientation: SeatOrientation.values.byName(row['orientation'] as String),
        chair: row['chair'] as String,
        amenities: (row['amenities'] as List<dynamic>).cast<String>(),
        blockedFrom: row['blocked_from'] == null
            ? null
            : DateTime.parse(row['blocked_from'] as String),
        blockedTo: row['blocked_to'] == null
            ? null
            : DateTime.parse(row['blocked_to'] as String),
      );
}
