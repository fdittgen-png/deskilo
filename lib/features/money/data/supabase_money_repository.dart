// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/statement.dart';

class SupabaseMoneyRepository implements MoneyRepository {
  SupabaseMoneyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    final result = await _client.rpc<dynamic>('member_statement', params: {
      'p_member_id': memberId,
      'p_period': period,
    }) as Map<String, dynamic>;
    return Statement(
      period: result['period'] as String,
      planName: result['plan_name'] as String,
      baseFeeCents: result['base_fee_cents'] as int,
      includedHalfDays: result['included_half_days'] as int?,
      usedHalfDays: result['used_half_days'] as int,
      extraHalfDays: result['extra_half_days'] as int,
      overageCents: result['overage_cents'] as int,
      creditsCents: result['credits_cents'] as int,
      balanceCents: result['balance_cents'] as int,
    );
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => LedgerEntry(
            id: row['id'] as String,
            memberId: row['member_id'] as String,
            kind: LedgerKind.values.byName(row['kind'] as String),
            category:
                LedgerCategory.values.byName(row['category'] as String),
            amountCents: row['amount_cents'] as int,
            description: row['description'] as String,
            period: row['period'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
  }) async {
    final result = await _client.rpc<dynamic>('record_payment', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_amount_cents': amountCents,
      'p_note': note,
    });
    return result as String;
  }
}
