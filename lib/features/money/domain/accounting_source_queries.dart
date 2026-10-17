// SPDX-License-Identifier: AGPL-3.0-or-later
import 'accounting_source_snapshot.dart';

/// #2365 — the one fiscal source of an export. Read only: nothing is
/// written, created or re-read later.
abstract interface class AccountingSourceQueries {
  /// The books of [workspaceId] for the calendar year [year], read in one
  /// server response (`accounting_source_snapshot_v1`). Throws
  /// [AccountingSourceException] for an over-budget scope or an answer that
  /// is not the one asked for.
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  });
}
