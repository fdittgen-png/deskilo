// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_activity.dart';
import '../domain/finance_overview.dart';

class SupabaseAccountActivityRepository implements AccountActivityRepository {
  const SupabaseAccountActivityRepository(this.client);
  final SupabaseClient client;
  @override
  Future<FinanceOverview> overview() async {
    final result = await client.rpc<dynamic>('my_finance_overview');
    return FinanceOverview.fromJson(
      Map<String, dynamic>.from(result as Map? ?? const <String, dynamic>{}),
    );
  }

  @override
  Future<List<AccountActivity>> list(
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) async {
    final result = await client.rpc<List<dynamic>>(
      'my_financial_activity',
      params: {
        'p_kind': kind.name,
        'p_before_at': before?.at.toUtc().toIso8601String(),
        'p_before_id': before?.id,
      },
    );
    return result
        .map((row) => AccountActivity.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
