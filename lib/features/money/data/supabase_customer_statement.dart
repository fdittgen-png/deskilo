// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement read from the server: one call, one
// snapshot with its cutoff (customer_statement_v1, 0731).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer_statement.dart';

class SupabaseCustomerStatementReader implements CustomerStatementReader {
  SupabaseCustomerStatementReader(this._client);

  final SupabaseClient _client;

  @override
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  ) async => CustomerStatement.fromJson(
    await _client.rpc<Object?>(
      'customer_statement_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_as_of': isoDay(asOf),
      },
    ),
  );
}
