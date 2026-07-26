// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cached_fetch.dart';
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
  SupabaseFloorPlanRepository(this._client, this._cache);

  final SupabaseClient _client;

  /// Tankstellen-style cache: fresh entries answer reads instantly,
  /// stale ones back the offline fallback, and every mutation in this
  /// repo busts the plan/levels prefixes so a fresh read is
  /// network-true.
  final CacheStore _cache;

  static const Duration _ttl = Duration(minutes: 10);

  /// Bust every cached read this repo serves. Prefix-coarse on purpose:
  /// delete-by-id mutations don't know their level, and correctness
  /// beats keeping a sibling floor's 10-minute entry warm.
  Future<void> _bust() async {
    await _cache.invalidatePrefix('levels:');
    await _cache.invalidatePrefix('plan:');
  }

  @override
  Future<List<Level>> fetchLevels(String workspaceId) =>
      cachedFetch<List<Level>>(
        cache: _cache,
        key: 'levels:$workspaceId',
        ttl: _ttl,
        mode: CacheReadMode.cacheFirst,
        fetchRaw: () => _client
            .from('levels')
            .select()
            .eq('workspace_id', workspaceId)
            .order('sort_order', ascending: true),
        parse: (payload) => [
          for (final row in payload as List)
            _levelFromRow(Map<String, dynamic>.from(row as Map)),
        ],
      );

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
    await _bust();
    return _levelFromRow(row);
  }

  @override
  Future<void> renameLevel(String levelId, String name) async {
    await _client.from('levels').update({'name': name}).eq('id', levelId);
    await _bust();
  }

  @override
  Future<void> setLevelBooking(
    String levelId, {
    required bool bookableAsWhole,
    required int priceCents,
  }) async {
    // Owner-only levels RLS (0003); the 0050 check keeps the price >= 0.
    await _client.from('levels').update({
      'bookable_as_whole': bookableAsWhole,
      'price_cents': priceCents,
    }).eq('id', levelId);
    await _bust();
  }

  @override
  Future<void> deleteLevel(String levelId) async {
    await _client.from('levels').delete().eq('id', levelId);
    await _bust();
  }

  @override
  Future<void> reorderLevels(List<String> orderedLevelIds) async {
    for (var i = 0; i < orderedLevelIds.length; i++) {
      await _client
          .from('levels')
          .update({'sort_order': i}).eq('id', orderedLevelIds[i]);
    }
    await _bust();
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
    await _bust();
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
    await _bust();
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
    // Desks joined (0059): whole-desk reservations name their table.
    final deskRows = await _client
        .from('desks')
        .select('id, name')
        .eq('workspace_id', workspaceId);
    return {
      for (final r in [...seatRows, ...deskRows, ...officeRows])
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
  Future<FloorPlan> fetchPlan(String levelId) =>
      cachedFetch<FloorPlan>(
        cache: _cache,
        key: 'plan:$levelId',
        ttl: _ttl,
        mode: CacheReadMode.cacheFirst,
        // The raw four-table bundle is what gets cached; parsing always
        // runs with current code.
        fetchRaw: () => _fetchPlanRows(levelId),
        parse: (payload) => _planFromRows(
          levelId,
          Map<String, dynamic>.from(payload as Map),
        ),
      );

  Future<Map<String, dynamic>> _fetchPlanRows(String levelId) async {
    final officeRows =
        await _client.from('offices').select().eq('level_id', levelId);
    final officeIds =
        officeRows.map((row) => row['id'] as String).toList();

    var deskRows = const <Map<String, dynamic>>[];
    var seatRows = const <Map<String, dynamic>>[];
    if (officeIds.isNotEmpty) {
      deskRows = await _client
          .from('desks')
          .select()
          .inFilter('office_id', officeIds);
      final deskIds = deskRows.map((row) => row['id'] as String).toList();
      if (deskIds.isNotEmpty) {
        seatRows =
            await _client.from('seats').select().inFilter('desk_id', deskIds);
      }
    }
    final imageRows =
        await _client.from('plan_images').select().eq('level_id', levelId);
    return {
      'offices': officeRows,
      'desks': deskRows,
      'seats': seatRows,
      'images': imageRows,
    };
  }

  FloorPlan _planFromRows(String levelId, Map<String, dynamic> rows) {
    List<Map<String, dynamic>> section(String name) => [
          for (final row in (rows[name] as List? ?? const []))
            Map<String, dynamic>.from(row as Map),
        ];
    return FloorPlan(
      levelId: levelId,
      offices: section('offices').map(_officeFromRow).toList(),
      desks: section('desks').map(_deskFromRow).toList(),
      seats: section('seats').map(_seatFromRow).toList(),
      images: section('images').map(_planImageFromRow).toList(),
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
    await _bust();
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
    await _bust();
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
    await _bust();
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
    await _bust();
    return _officeFromRow(row);
  }

  @override
  Future<void> updateOffice(Office office) async {
    await _client.from('offices').update({
      'name': office.name,
      'color': office.color,
      'bookable_as_whole': office.bookableAsWhole,
      'price_cents': office.priceCents,
      'x': office.rect.x,
      'y': office.rect.y,
      'w': office.rect.w,
      'h': office.rect.h,
    }).eq('id', office.id);
    await _bust();
  }

  @override
  Future<void> deleteOffice(String officeId) async {
    await _client.from('offices').delete().eq('id', officeId);
    await _bust();
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
    await _bust();
    return _deskFromRow(row);
  }

  @override
  Future<void> updateDesk(Desk desk) async {
    await _client.from('desks').update({
      'name': desk.name,
      'bookable_as_whole': desk.bookableAsWhole,
      'price_cents': desk.priceCents,
      'x': desk.rect.x,
      'y': desk.rect.y,
      'w': desk.rect.w,
      'h': desk.rect.h,
    }).eq('id', desk.id);
    await _bust();
  }

  @override
  Future<void> deleteDesk(String deskId) async {
    await _client.from('desks').delete().eq('id', deskId);
    await _bust();
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
    await _bust();
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
    await _bust();
  }

  @override
  Future<void> deleteSeat(String seatId) async {
    await _client.from('seats').delete().eq('id', seatId);
    await _bust();
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
    await _bust();
  }

  Level _levelFromRow(Map<String, dynamic> row) => Level(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        sortOrder: row['sort_order'] as int,
        backgroundPath: row['background_path'] as String?,
        bookableAsWhole: row['bookable_as_whole'] as bool? ?? false,
        priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
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
        priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
        rect: _rectFromRow(row),
      );

  Desk _deskFromRow(Map<String, dynamic> row) => Desk(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        officeId: row['office_id'] as String,
        name: row['name'] as String,
        bookableAsWhole: row['bookable_as_whole'] as bool? ?? false,
        priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
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
