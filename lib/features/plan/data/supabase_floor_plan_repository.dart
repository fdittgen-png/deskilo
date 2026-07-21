// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/desk.dart';
import '../domain/floor_plan.dart';
import '../domain/floor_plan_repository.dart';
import '../domain/grid_geometry.dart';
import '../domain/level.dart';
import '../domain/office.dart';
import '../domain/plan_image.dart';
import '../domain/seat.dart';
import '../domain/seat_context.dart';

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

  static String _bgPath(String workspaceId, String levelId) =>
      '$workspaceId/$levelId';

  @override
  Future<void> setLevelBackground(
    String workspaceId,
    String levelId, {
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = _bgPath(workspaceId, levelId);
    await _client.storage.from('floor-plans').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _client
        .from('levels')
        .update({'background_path': path}).eq('id', levelId);
  }

  @override
  Future<void> clearLevelBackground(
    String workspaceId,
    String levelId,
  ) async {
    await _client.storage.from('floor-plans').remove([
      _bgPath(workspaceId, levelId),
    ]);
    await _client
        .from('levels')
        .update({'background_path': null}).eq('id', levelId);
  }

  @override
  Future<Uint8List?> fetchLevelBackground(
    String workspaceId,
    String levelId,
  ) async {
    final row = await _client
        .from('levels')
        .select('background_path')
        .eq('id', levelId)
        .maybeSingle();
    final path = row?['background_path'] as String?;
    if (path == null) return null;
    return _client.storage.from('floor-plans').download(path);
  }

  @override
  Future<Map<String, String>> fetchTargetNames(String workspaceId) async {
    final seatRows = await _client
        .from('seats')
        .select('id, name')
        .eq('workspace_id', workspaceId);
    final officeRows = await _client
        .from('offices')
        .select('id, name')
        .eq('workspace_id', workspaceId);
    return {
      for (final r in [...seatRows, ...officeRows])
        r['id'] as String: r['name'] as String,
    };
  }

  // #182: four small keyed reads along seats → desks → offices → levels
  // instead of one PostgREST FK-embedded select — the plain form is
  // obviously covered by the existing is_member_of RLS selects and needs
  // no assumptions about the embed syntax of the postgrest version.
  @override
  Future<SeatContext?> fetchSeatContext(String seatId) async {
    final seatRow = await _client
        .from('seats')
        .select('name, desk_id')
        .eq('id', seatId)
        .maybeSingle();
    if (seatRow == null) return null;
    final deskRow = await _client
        .from('desks')
        .select('name, office_id')
        .eq('id', seatRow['desk_id'] as String)
        .maybeSingle();
    if (deskRow == null) return null;
    final officeContext =
        await fetchOfficeContext(deskRow['office_id'] as String);
    if (officeContext == null) return null;
    return SeatContext(
      levelId: officeContext.levelId,
      levelName: officeContext.levelName,
      officeName: officeContext.officeName,
      deskName: deskRow['name'] as String,
      seatName: seatRow['name'] as String,
    );
  }

  @override
  Future<SeatContext?> fetchOfficeContext(String officeId) async {
    final officeRow = await _client
        .from('offices')
        .select('name, level_id')
        .eq('id', officeId)
        .maybeSingle();
    if (officeRow == null) return null;
    final levelRow = await _client
        .from('levels')
        .select('id, name')
        .eq('id', officeRow['level_id'] as String)
        .maybeSingle();
    if (levelRow == null) return null;
    return SeatContext(
      levelId: levelRow['id'] as String,
      levelName: levelRow['name'] as String,
      officeName: officeRow['name'] as String,
    );
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
    final imageRows =
        await _client.from('plan_images').select().eq('level_id', levelId);
    final images = imageRows.map(_planImageFromRow).toList();
    return FloorPlan(
      levelId: levelId,
      offices: offices,
      desks: desks,
      seats: seats,
      images: images,
    );
  }

  static String _imgPath(String workspaceId, String imageId) =>
      '$workspaceId/img/$imageId';

  @override
  Future<PlanImage> createPlanImage({
    required String workspaceId,
    required String levelId,
    required GridRect rect,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final row = await _client
        .from('plan_images')
        .insert({
          'workspace_id': workspaceId,
          'level_id': levelId,
          'x': rect.x,
          'y': rect.y,
          'w': rect.w,
          'h': rect.h,
          'storage_path': 'pending',
        })
        .select()
        .single();
    final id = row['id'] as String;
    final path = _imgPath(workspaceId, id);
    await _client.storage.from('floor-plans').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _client
        .from('plan_images')
        .update({'storage_path': path}).eq('id', id);
    return _planImageFromRow({...row, 'storage_path': path});
  }

  @override
  Future<void> updatePlanImageRect(String imageId, GridRect rect) async {
    await _client.from('plan_images').update({
      'x': rect.x,
      'y': rect.y,
      'w': rect.w,
      'h': rect.h,
    }).eq('id', imageId);
  }

  @override
  Future<void> deletePlanImage(String imageId) async {
    final row = await _client
        .from('plan_images')
        .select('storage_path')
        .eq('id', imageId)
        .maybeSingle();
    final path = row?['storage_path'] as String?;
    if (path != null && path != 'pending') {
      await _client.storage.from('floor-plans').remove([path]);
    }
    await _client.from('plan_images').delete().eq('id', imageId);
  }

  @override
  Future<Uint8List?> fetchPlanImageBytes(String imageId) async {
    final row = await _client
        .from('plan_images')
        .select('storage_path')
        .eq('id', imageId)
        .maybeSingle();
    final path = row?['storage_path'] as String?;
    if (path == null || path == 'pending') return null;
    return _client.storage.from('floor-plans').download(path);
  }

  PlanImage _planImageFromRow(Map<String, dynamic> row) => PlanImage(
        id: row['id'] as String,
        levelId: row['level_id'] as String,
        rect: _rectFromRow(row),
        storagePath: row['storage_path'] as String,
      );

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

  @override
  Future<void> setSeatBlock(
    String seatId, {
    DateTime? from,
    DateTime? to,
  }) async {
    await _client.rpc<dynamic>('set_seat_block', params: {
      'p_seat_id': seatId,
      'p_blocked_from': from?.toUtc().toIso8601String(),
      'p_blocked_to': to?.toUtc().toIso8601String(),
    });
  }

  Level _levelFromRow(Map<String, dynamic> row) => Level(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        sortOrder: row['sort_order'] as int,
        backgroundPath: row['background_path'] as String?,
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
