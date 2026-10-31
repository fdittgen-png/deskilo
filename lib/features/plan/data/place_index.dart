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
/// too (0059): whole-desk reservations name their table. #3100 — the three
/// reads run together, not one after another.
Future<Map<String, String>> fetchPlaceNames(
  SupabaseClient client,
  String workspaceId,
) async {
  final parts = await Future.wait([
    for (final table in const ['seats', 'desks', 'offices'])
      _column(client, workspaceId, table, 'name'),
  ]);
  return {for (final part in parts) ...part};
}

/// seat/desk/office id → the id of the level it stands on, for
/// [workspaceId], read along offices → desks → seats (#3100: the three
/// reads together, composed afterwards).
Future<Map<String, String>> fetchPlaceLevels(
  SupabaseClient client,
  String workspaceId,
) async {
  final [officeLevel, deskOffice, seatDesk] = await Future.wait([
    _column(client, workspaceId, 'offices', 'level_id'),
    _column(client, workspaceId, 'desks', 'office_id'),
    _column(client, workspaceId, 'seats', 'desk_id'),
  ]);
  final deskLevel = {
    for (final MapEntry(:key, :value) in deskOffice.entries)
      key: ?officeLevel[value],
  };
  return {
    ...officeLevel,
    ...deskLevel,
    for (final MapEntry(:key, :value) in seatDesk.entries)
      key: ?deskLevel[value],
  };
}
