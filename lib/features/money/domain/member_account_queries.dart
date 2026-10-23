// SPDX-License-Identifier: AGPL-3.0-or-later
import 'ledger_entry.dart';
import 'member_account.dart';
import 'statement.dart';
import 'usage_record.dart';

/// #2591 C1 — the member's position as the server states it: account,
/// statement, ledger and usage records. Read only; the usage correction
/// and delete requests stay commands of the money boundary.
abstract interface class MemberAccountQueries {
  /// The member's real cross-month position (#512): credit on account,
  /// open remainders, refunds due, net.
  Future<MemberAccount> fetchMemberAccount(String memberId);

  /// #833, #2590 — one month's usage records as a PURE read (RPC
  /// `usage_records_read_v1`, 0477): it writes nothing and says how many past
  /// bookings have no record yet. Recording them is `UsagePreparation`.
  /// [memberId] null = everyone the caller may see.
  Future<UsageRead> readUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  });

  Future<Statement> fetchStatement(String memberId, String period);

  Future<List<LedgerEntry>> fetchLedger(String memberId);

  /// EVERY member's ledger of the workspace — the payments/services tabs
  /// of the data export (#395). RLS already grants admins the full table
  /// (0008); a worker calling this gets only their own rows back.
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId);

  /// Whether the space has issued a document or recorded money: from then
  /// on its country and currency are fixed (0399's guard, SQLSTATE DK423).
  /// A caller who may not read the money rows sees false; the server still
  /// refuses the change.
  Future<bool> hasRecordedMoney(String workspaceId);
}
