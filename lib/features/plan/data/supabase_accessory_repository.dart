// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/accessory.dart';
import '../domain/accessory_repository.dart';

class SupabaseAccessoryRepository implements AccessoryRepository {
  SupabaseAccessoryRepository(this._client);

  final SupabaseClient _client;

  Accessory _accessoryFromRow(Map<String, dynamic> row) => Accessory(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        supplementCents: row['supplement_cents'] as int,
        active: row['active'] as bool,
        sortOrder: row['sort_order'] as int,
      );

  @override
  Future<List<Accessory>> fetchAccessories(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    var query =
        _client.from('accessories').select().eq('workspace_id', workspaceId);
    if (!includeInactive) query = query.eq('active', true);
    final rows = await query
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(_accessoryFromRow).toList();
  }

  @override
  Future<Accessory> createAccessory(
    String workspaceId, {
    required String name,
    int supplementCents = 0,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('accessories')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'supplement_cents': supplementCents,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return _accessoryFromRow(row);
  }

  @override
  Future<Accessory> updateAccessory(
    String accessoryId, {
    String? name,
    int? supplementCents,
    bool? active,
    int? sortOrder,
  }) async {
    final row = await _client
        .from('accessories')
        .update({
          'name': ?name,
          'supplement_cents': ?supplementCents,
          'active': ?active,
          'sort_order': ?sortOrder,
        })
        .eq('id', accessoryId)
        .select()
        .single();
    return _accessoryFromRow(row);
  }

  @override
  Future<Map<String, Set<String>>> fetchSeatAccessories(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('seat_accessories')
        .select('seat_id, accessory_id')
        .eq('workspace_id', workspaceId);
    final result = <String, Set<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['seat_id'] as String, () => <String>{})
          .add(row['accessory_id'] as String);
    }
    return result;
  }

  @override
  Future<void> setSeatAccessories(
    String seatId,
    Set<String> accessoryIds,
  ) async {
    // Replace-set semantics: clear, then bulk-insert. The database trigger
    // fills workspace_id from the seat and rejects cross-workspace links.
    await _client.from('seat_accessories').delete().eq('seat_id', seatId);
    if (accessoryIds.isEmpty) return;
    await _client.from('seat_accessories').insert([
      for (final accessoryId in accessoryIds)
        {'seat_id': seatId, 'accessory_id': accessoryId},
    ]);
  }
}
