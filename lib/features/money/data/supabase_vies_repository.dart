// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vies_check.dart';
import '../domain/vies_repository.dart';

/// #2354 — the member's VIES columns and the `vies-check` edge function.
class SupabaseViesRepository implements ViesRepository {
  const SupabaseViesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ViesCheck> fetchViesCheck(String memberId) async {
    final row = await _client
        .from('members')
        .select(
          'vies_vat_id, vies_status, vies_consultation, vies_checked_at, '
          'vies_detail',
        )
        .eq('id', memberId)
        .maybeSingle();
    return row == null ? ViesCheck.none : ViesCheck.fromRow(row);
  }

  @override
  Future<ViesCheck> checkVies(String workspaceId, String memberId) async {
    final response = await _client.functions.invoke(
      'vies-check',
      body: {'workspace_id': workspaceId, 'member_id': memberId},
    );
    final data = response.data;
    return data is Map
        ? ViesCheck.fromRow(Map<String, dynamic>.from(data))
        : ViesCheck.none;
  }
}
