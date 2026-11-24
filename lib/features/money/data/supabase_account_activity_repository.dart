// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_activity.dart';
import '../domain/finance_overview.dart';
import 'supabase_billing_access_repository.dart';

class SupabaseAccountActivityRepository implements AccountActivityRepository {
  const SupabaseAccountActivityRepository(this.client, {required this.installation});
  final SupabaseClient client;
  final Future<String> Function() installation;
  @override
  Future<FinanceOverview> overview() async {
    final identity = await installation();
    final result = await client.rpc<dynamic>('my_finance_overview_v2');
    return FinanceOverview.fromJson(
      Map<String, dynamic>.from(result as Map? ?? const <String, dynamic>{}),
    ).onInstallation(identity);
  }

  @override
  Future<List<AccountActivity>> list(
    AccountActivityKind kind, {
    ActivityCursor? before,
  }) async {
    final identity = await installation();
    // #4164 B2 — a row of a subject I read through a billing-access grant is
    // not my own activity: the held subjects are read first, and a read that
    // fails fails the page, so such a row is never shown as mine.
    final billing = await SupabaseBillingAccessRepository(client).heldSubjects();
    final result = await client.rpc<List<dynamic>>(
      'my_financial_activity_v2',
      params: {
        'p_kind': kind.name,
        'p_before_at': before?.at.toUtc().toIso8601String(),
        'p_before_id': before?.id,
      },
    );
    return [
      for (final row in result)
        if (!billing.contains((row as Map<String, dynamic>)['financial_subject_id']))
          AccountActivity.fromJson(row).onInstallation(identity),
    ];
  }
}
