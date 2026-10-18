// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/system_columns.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/ledger_entry.dart';
import '../domain/member_account.dart';
import '../domain/member_account_queries.dart';
import '../domain/statement.dart';
import '../domain/usage_record.dart';

/// #2591 C1 — the member's account, statement, ledger and usage records,
/// with their own client. The bodies are the ones that lived in the money
/// repository's part files.
class SupabaseMemberAccountQueries implements MemberAccountQueries {
  SupabaseMemberAccountQueries(this._client);

  final SupabaseClient _client;

  @override
  Future<MemberAccount> fetchMemberAccount(String memberId) async {
    final result = await _client.rpc<dynamic>(
      'member_account',
      params: {'p_member_id': memberId},
    );
    return MemberAccount.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<List<UsageRecord>> fetchUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async {
    final data = await _client.rpc<dynamic>(
      'usage_records_for',
      params: {
        'p_workspace_id': workspaceId,
        'p_period': period,
        'p_member_id': memberId,
      },
    );
    final rows = (data as Map)['records'] as List? ?? const [];
    return [
      for (final row in rows)
        UsageRecord.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<UsageRead> readUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async {
    final data = await _client.rpc<Object?>(
      'usage_records_read_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_period': period,
        'p_member_id': memberId,
      },
    );
    return UsageRead.fromRpc(data);
  }

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    final result = await _client.rpc<dynamic>(
      'member_statement',
      params: {'p_member_id': memberId, 'p_period': period},
    ) as Map<String, dynamic>;
    // Parsing lives in the domain (Statement.fromRpc) so the #170
    // supplement-field tolerance is pure-Dart testable.
    return Statement.fromRpc(result);
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return rows.map(_ledgerFromRow).whereType<LedgerEntry>().toList();
  }

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    // #1310 S2 — paged; the whole ledger is an export read.
    final rows = await fetchAllPages(
      table: 'ledger_entries',
      build: () => _client
          .from('ledger_entries')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .order('id', ascending: true),
    );
    return rows.map(_ledgerFromRow).whereType<LedgerEntry>().toList();
  }

  // #1148 — a ledger row whose kind or category this build does not
  // know is SKIPPED and traced, never mis-filed: reading a widened
  // category as "expense" would move money in the statement. Every
  // other list degrades to a fallback; money degrades to absence.
  LedgerEntry? _ledgerFromRow(Map<String, dynamic> row) {
    final kind = LedgerKind.values.asNameMap()[row['kind'] as String?];
    final category = LedgerCategory.values
        .asNameMap()[row['category'] as String?];
    if (kind == null || category == null) {
      TraceLogger.instance.warn(
        'money',
        "ledger row ${row['id']} skipped: unknown kind/category ${row['kind']}/${row['category']}",
      );
      return null;
    }
    return LedgerEntry(
      system: SystemColumns.fromRow(row),
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      kind: kind,
      category: category,
      amountCents: row['amount_cents'] as int,
      description: row['description'] as String,
      period: row['period'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      occurredOn: row['occurred_on'] == null
          ? null
          : DateTime.parse(row['occurred_on'] as String),
    );
  }
}
