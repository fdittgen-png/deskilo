// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C — saved Web-BI views through their definer RPCs. The server
// checks viewAnalytics, ownership, workspaceSettings for team views and
// the revision; this class only asks and types the refusals.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bi_saved_view.dart';

class SupabaseBiViewRepository implements BiViewRepository {
  SupabaseBiViewRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<dynamic>(fn, params: params);
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the views bar says which refusal.
      final failure = switch (e.code) {
        '40001' => BiViewFailure.stale,
        '42501' => BiViewFailure.forbidden,
        '23505' => BiViewFailure.nameTaken,
        '22023' => BiViewFailure.invalid,
        _ => null,
      };
      if (failure == null) rethrow;
      Error.throwWithStackTrace(BiViewRefused(failure), st);
    }
  }

  @override
  Future<List<BiSavedView>> list(String workspaceId) async {
    final rows = await _call('bi_views_list', {'p_workspace_id': workspaceId});
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map) ?BiSavedView.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
  }) async {
    final row = await _call('bi_view_save', {
      'p_workspace_id': workspaceId,
      'p_id': id,
      'p_scope': scope.name,
      'p_name': name,
      'p_definition': definition.toJson(),
      'p_expected_revision': expectedRevision,
    });
    final view = row is Map
        ? BiSavedView.fromJson(Map<String, dynamic>.from(row))
        : null;
    if (view == null) throw const BiViewRefused(BiViewFailure.invalid);
    return view;
  }

  @override
  Future<void> delete(String workspaceId, String id, int expectedRevision) =>
      _call('bi_view_delete', {
        'p_workspace_id': workspaceId,
        'p_id': id,
        'p_expected_revision': expectedRevision,
      });

  @override
  Future<void> setDefault(String workspaceId, BiViewScope scope, String? id) =>
      _call('bi_view_set_default', {
        'p_workspace_id': workspaceId,
        'p_scope': scope.name,
        'p_id': id,
      });
}
