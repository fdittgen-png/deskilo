// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/accounting_source_queries.dart';
import '../domain/accounting_source_snapshot.dart';

/// #2365 — `accounting_source_snapshot_v1` behind the port.
class SupabaseAccountingSourceQueries implements AccountingSourceQueries {
  SupabaseAccountingSourceQueries(this._client);

  final SupabaseClient _client;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async {
    final principal = _client.auth.currentUser?.id ?? '';
    final from = '$year-01-01';
    final to = '$year-12-31';
    final answer = await _client.rpc<Object?>(
      'accounting_source_snapshot_v1',
      params: {'p_workspace_id': workspaceId, 'p_from': from, 'p_to': to},
    );
    // A delayed completion is fenced: the person who asked must still be
    // the person signed in when the answer lands.
    if (principal.isEmpty || _client.auth.currentUser?.id != principal) {
      throw const AccountingSourceException(
        AccountingSourceFailure.inconsistent,
        'the signed-in person changed while the source was read',
      );
    }
    return AccountingSourceSnapshot.fromRpc(
      answer,
      workspaceId: workspaceId,
      from: from,
      to: to,
      principal: principal,
    );
  }
}
