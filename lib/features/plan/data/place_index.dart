// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a list of bookings needs to know of every place of one workspace,
// without loading each level's plan: its name, and the level it stands on.
// Every table is paged to the end, ordered by id (#2011): an unranged select
// stops at the server's cap and a place past it would lose its name or its
// level. A failed page fails the read (the provider shows it as
// unavailable), never a shorter map.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';

/// id → [column] of every row of [table] in [workspaceId].
Future<Map<String, String>> _column(
  SupabaseClient client,
  String workspaceId,
  String table,
  String column,
) async => {
  for (final r in await fetchAllPages(
    table: table,
    build: () => client
        .from(table)
        .select('id, $column')
        .eq('workspace_id', workspaceId)
        .order('id', ascending: true),
  ))
    r['id'] as String: r[column] as String,
};

/// seat/desk/office id → display name for [workspaceId]. Desks are named
/// too (0059): whole-desk reservations name their table.
Future<Map<String, String>> fetchPlaceNames(
  SupabaseClient client,
  String workspaceId,
) async => {
  for (final table in const ['seats', 'desks', 'offices'])
    ...await _column(client, workspaceId, table, 'name'),
};

/// seat/desk/office id → the id of the level it stands on, for
/// [workspaceId], read along offices → desks → seats.
Future<Map<String, String>> fetchPlaceLevels(
  SupabaseClient client,
  String workspaceId,
) async {
  final officeLevel = await _column(client, workspaceId, 'offices', 'level_id');
  final deskLevel = {
    for (final MapEntry(:key, :value) in (await _column(
      client,
      workspaceId,
      'desks',
      'office_id',
    )).entries)
      key: ?officeLevel[value],
  };
  return {
    ...officeLevel,
    ...deskLevel,
    for (final MapEntry(:key, :value) in (await _column(
      client,
      workspaceId,
      'seats',
      'desk_id',
    )).entries)
      key: ?deskLevel[value],
  };
}
