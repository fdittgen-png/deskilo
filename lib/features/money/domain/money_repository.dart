// SPDX-License-Identifier: MIT
import 'ledger_entry.dart';
import 'plan.dart';
import 'statement.dart';

/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [recordPayment] must be confirmed by the other side
/// before a ledger credit exists.
abstract class MoneyRepository {
  Future<Statement> fetchStatement(String memberId, String period);

  Future<List<LedgerEntry>> fetchLedger(String memberId);

  /// Returns the pending event id.
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note,
  });

  /// Active plans of the workspace (member-readable).
  Future<List<Plan>> fetchPlans(String workspaceId);
}
