// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layouts on the server: the rows of `till_layouts` the person may read, and the two commands.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/till_layout.dart';
import '../domain/till_layout_port.dart';

/// The table of the till layouts.
const tillLayoutsTable = 'till_layouts';

class SupabaseTillLayouts implements TillLayoutPort {
  const SupabaseTillLayouts(this._client);

  final SupabaseClient _client;

  Future<TillLayout?> _read(String workspaceId, String tillId, TillLayoutStatus status) async {
    final rows = await _client
        .from(tillLayoutsTable)
        .select('name, version, status, layout')
        .eq('workspace_id', workspaceId)
        .eq('till_id', tillId)
        .eq('status', status.wire)
        .order('version', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    final r = JsonReader.of(rows.first, context: tillLayoutsTable);
    return TillLayout.fromJson(
      r.objectOrAbsent('layout').json,
      name: r.string('name'),
      version: r.intOrNull('version') ?? 0,
      status: TillLayoutStatus.of(r.string('status')),
    );
  }

  @override
  Future<TillLayout?> draft(String workspaceId, String tillId) => _read(workspaceId, tillId, TillLayoutStatus.draft);

  @override
  Future<TillLayout?> published(String workspaceId, String tillId) => _read(workspaceId, tillId, TillLayoutStatus.published);

  int _version(Object? answer) => JsonReader.of(answer, context: 'till_layout').intOrNull('version') ?? 0;

  @override
  Future<int> save(String workspaceId, {required String requestId, required String tillId, required TillLayout layout, required int expectedVersion}) async =>
      _version(await _client.rpc('till_layout_save_v1', params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_name': layout.name,
        'p_expected_version': expectedVersion,
        'p_layout': layout.toJson(),
      }));

  @override
  Future<int> publish(String workspaceId, {required String requestId, required String tillId, required int expectedVersion}) async =>
      _version(await _client.rpc('till_layout_publish_v1', params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_expected_version': expectedVersion,
      }));
}
