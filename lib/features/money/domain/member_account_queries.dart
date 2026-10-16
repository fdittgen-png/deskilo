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

  /// #833 — one month's usage records (RPC `usage_records_for`, 0151).
  /// The server backfills the month's no-shows before answering, so
  /// reading a month is what makes its uncounted bookings appear.
  /// [memberId] null = everyone the caller may see.
  Future<List<UsageRecord>> fetchUsageRecords({
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
}
